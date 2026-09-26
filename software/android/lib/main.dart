import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'smb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NasApp());
}

class NasApp extends StatelessWidget {
  const NasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Khoa NAS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const NasHomePage(),
    );
  }
}

class NasHomePage extends StatefulWidget {
  const NasHomePage({super.key});

  @override
  State<NasHomePage> createState() => _NasHomePageState();
}

class _NasHomePageState extends State<NasHomePage> {
  static const storage = FlutterSecureStorage();
  static const shares = ['NAS1', 'NAS2', 'PRIVATE'];

  final service = NasService();
  final host = TextEditingController(text: '100.64.0.1');
  final user = TextEditingController();
  final password = TextEditingController();

  String share = 'NAS1';
  String path = '';
  List<Smb2DirEntry> entries = const [];
  Smb2StatVfs? vfs;
  bool busy = false;
  bool hidePassword = true;
  double? progress;
  String? error;

  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    service.disconnect();
    host.dispose();
    user.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    final values = await Future.wait([
      storage.read(key: 'host'),
      storage.read(key: 'user'),
      storage.read(key: 'password'),
      storage.read(key: 'share'),
    ]);
    if (!mounted) return;
    setState(() {
      if ((values[0] ?? '').isNotEmpty) host.text = values[0]!;
      if ((values[1] ?? '').isNotEmpty) user.text = values[1]!;
      if ((values[2] ?? '').isNotEmpty) password.text = values[2]!;
      if (shares.contains(values[3])) share = values[3]!;
    });
  }

  Future<void> saveSettings() async {
    await Future.wait([
      storage.write(key: 'host', value: host.text.trim()),
      storage.write(key: 'user', value: user.text.trim()),
      storage.write(key: 'password', value: password.text),
      storage.write(key: 'share', value: share),
    ]);
  }

  String remotePath(String name) => path.isEmpty ? name : '$path/$name';

  Future<void> runTask(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  Future<void> connect() => runTask(() async {
    await service.connect(
      NasConnection(
        host: host.text,
        share: share,
        username: user.text,
        password: password.text,
      ),
    );
    await saveSettings();
    path = '';
    await refreshCore();
  });

  Future<void> refresh() => runTask(refreshCore);

  Future<void> refreshCore() async {
    final result = await Future.wait([
      service.listDirectory(path),
      service.storageInfo(),
    ]);
    if (!mounted) return;
    setState(() {
      entries = result[0] as List<Smb2DirEntry>;
      vfs = result[1] as Smb2StatVfs;
    });
  }

  Future<void> switchShare(String value) async {
    setState(() => share = value);
    if (service.isConnected) await connect();
  }

  Future<void> goUp() async {
    if (path.isEmpty || busy) return;
    final parts = path.split('/');
    parts.removeLast();
    setState(() => path = parts.join('/'));
    await refresh();
  }

  Future<void> upload() async {
    final item = await FilePicker.pickFile();
    if (item == null || item.path == null) return;
    final localFile = File(item.path!);
    await runTask(() async {
      await service.uploadFile(
        localFile,
        remotePath(item.name),
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => progress = sent / total);
        },
      );
      await refreshCore();
    });
  }

  Future<void> download(Smb2DirEntry entry) async {
    String? directory;
    if (Platform.isWindows) {
      directory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Chọn thư mục lưu file',
      );
      if (directory == null) return;
    } else {
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      directory = dir.path;
    }
    final destination = directory + Platform.pathSeparator + entry.name;

    await runTask(() async {
      final finalFile = File(destination);
      final partFile = File('$destination.part');
      if (await partFile.exists()) await partFile.delete();
      await service.downloadFile(
        remotePath(entry.name),
        partFile,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => progress = received / total);
          }
        },
      );
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đã tải: ${finalFile.path}')));
      }
    });
  }

  Future<void> createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo thư mục'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên thư mục'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await runTask(() async {
      await service.createDirectory(remotePath(name.trim()));
      await refreshCore();
    });
  }

  Future<void> deleteEntry(Smb2DirEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          entry.isDirectory
              ? 'Xóa thư mục rỗng "${entry.name}"?'
              : 'Xóa file "${entry.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await runTask(() async {
      await service.deleteEntry(
        remotePath(entry.name),
        isDirectory: entry.isDirectory,
      );
      await refreshCore();
    });
  }

  String bytes(int value) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    final connected = service.isConnected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoa NAS'),
        actions: [
          if (connected)
            IconButton(
              tooltip: 'Làm mới',
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          if (connected)
            IconButton(
              tooltip: 'Ngắt kết nối',
              onPressed: busy
                  ? null
                  : () => runTask(() async {
                      await service.disconnect();
                      if (mounted) {
                        setState(() {
                          entries = const [];
                          vfs = null;
                          path = '';
                        });
                      }
                    }),
              icon: const Icon(Icons.link_off),
            ),
        ],
      ),
      body: Column(
        children: [
          connectionPanel(),
          if (progress != null)
            LinearProgressIndicator(value: progress!.clamp(0.0, 1.0)),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          if (connected) pathBar(),
          if (connected) Expanded(child: fileList()),
          if (!connected)
            const Expanded(
              child: Center(
                child: Text(
                  'Hãy bật Tailscale trên thiết bị rồi đăng nhập NAS.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: connected && !busy
          ? FloatingActionButton.extended(
              onPressed: upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Tải lên'),
            )
          : null,
    );
  }

  Widget connectionPanel() {
    final connected = service.isConnected;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: host,
                enabled: !connected && !busy,
                decoration: const InputDecoration(
                  labelText: 'Tailscale IP / Host',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String>(
                initialValue: share,
                decoration: const InputDecoration(
                  labelText: 'Share',
                  border: OutlineInputBorder(),
                ),
                items: shares
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) switchShare(value);
                      },
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: user,
                enabled: !connected && !busy,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản SMB',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: TextField(
                controller: password,
                enabled: !connected && !busy,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
                    icon: Icon(
                      hidePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: connected || busy ? null : connect,
              icon: const Icon(Icons.link),
              label: Text(busy ? 'Đang xử lý...' : 'Kết nối'),
            ),
          ],
        ),
      ),
    );
  }

  Widget pathBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Lên thư mục cha',
            onPressed: path.isEmpty || busy ? null : goUp,
            icon: const Icon(Icons.arrow_upward),
          ),
          Expanded(
            child: SelectableText(
              '/$share${path.isEmpty ? '' : '/$path'}',
              maxLines: 1,
            ),
          ),
          if (vfs != null)
            Text(
              '${bytes(vfs!.availableSize)} trống / ${bytes(vfs!.totalSize)}',
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Tạo thư mục',
            onPressed: busy ? null : createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
    );
  }

  Widget fileList() {
    if (busy && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return const Center(child: Text('Thư mục trống'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
          ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            entry.isDirectory
                ? 'Thư mục'
                : '${bytes(entry.size)} • ${entry.stat.modified.toLocal()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: entry.isDirectory
              ? () async {
                  setState(() => path = remotePath(entry.name));
                  await refresh();
                }
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!entry.isDirectory)
                IconButton(
                  tooltip: 'Tải xuống',
                  onPressed: busy ? null : () => download(entry),
                  icon: const Icon(Icons.download),
                ),
              IconButton(
                tooltip: 'Xóa',
                onPressed: busy ? null : () => deleteEntry(entry),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}
