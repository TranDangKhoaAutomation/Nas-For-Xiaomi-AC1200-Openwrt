import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'smb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Tailscale, SMB và Go',
    ], await rootBundle.loadString('assets/native-licenses.txt'));
  });
  runApp(const NasApp());
}

const brand = Color(0xff07898d);

class NasApp extends StatelessWidget {
  const NasApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Khoa NAS',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: const Color(0xfff4f7f9),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    ),
    home: const NasHome(),
  );
}

class NasHome extends StatefulWidget {
  const NasHome({super.key});
  @override
  State<NasHome> createState() => _NasHomeState();
}

class _NasHomeState extends State<NasHome> with WidgetsBindingObserver {
  final service = NasService();
  static const storage = FlutterSecureStorage();
  final host = TextEditingController(),
      user = TextEditingController(),
      password = TextEditingController();
  final adminUser = TextEditingController(text: 'root'),
      adminPassword = TextEditingController();
  int tab = 2;
  bool remote = true, remember = false, busy = false, hidden = true;
  String network = 'Stopped', share = '', path = '', rootSession = '';
  String? message;
  List<String> shares = [];
  List<NasEntry> entries = [];
  Map<String, dynamic>? files, disks;
  double? progress;
  Timer? networkTimer, transferTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore().then((_) => receiveInitialLink());
    NasService.channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingLink') receiveLink(call.arguments as String?);
    });
    networkTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refreshNetwork(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshNetwork();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    networkTimer?.cancel();
    transferTimer?.cancel();
    NasService.channel.setMethodCallHandler(null);
    for (final c in [host, user, password, adminUser, adminPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final value = await storage.read(key: 'connection-v2');
      if (!mounted || value == null) return;
      final data = jsonDecode(value) as Map<String, dynamic>;
      setState(() {
        host.text = data['host'] ?? '';
        user.text = data['user'] ?? '';
        password.text = data['password'] ?? '';
        remote = data['remote'] != false;
        share = data['share'] ?? '';
        remember = password.text.isNotEmpty;
      });
      if (remote) {
        await service.startNetwork();
        await refreshNetwork();
      }
    } catch (_) {
      /* A corrupt saved connection does not block setup. */
    }
  }

  Future<void> receiveInitialLink() async {
    try {
      receiveLink(await NasService.channel.invokeMethod<String>('initialLink'));
    } catch (_) {
      /* No link when launched from the app icon. */
    }
  }

  void receiveLink(String? value) {
    if (value == null || !mounted || busy) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'smb' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.pathSegments.length > 1) {
      return;
    }
    final octets = uri.host.split('.').map(int.tryParse).toList();
    if (octets.length != 4 ||
        octets.any((n) => n == null || n < 0 || n > 255)) {
      return;
    }
    final tail = octets[0] == 100 && octets[1]! >= 64 && octets[1]! <= 127;
    final lan =
        octets[0] == 10 ||
        (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31) ||
        (octets[0] == 192 && octets[1] == 168);
    if (!tail && !lan) return;
    final nextShare = uri.pathSegments.isEmpty ? '' : uri.pathSegments.single;
    if (nextShare.isNotEmpty && !validEntryName(nextShare)) return;
    setState(() {
      if (host.text.trim() != uri.host || remote != tail) {
        password.clear();
        rootSession = '';
        disks = null;
      }
      host.text = uri.host;
      remote = tail;
      share = nextShare;
      tab = 2;
      message = 'Đã nhận địa chỉ NAS. Kiểm tra rồi nhấn Kết nối.';
    });
  }

  Future<void> refreshNetwork() async {
    try {
      final state = await service.networkState();
      if (mounted) setState(() => network = state['state'] ?? 'Stopped');
    } catch (_) {
      /* The native transport is not available in desktop widget tests. */
    }
  }

  Future<void> task(
    Future<void> Function() action, {
    bool transfer = false,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      progress = null;
    });
    if (transfer) {
      transferTimer = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) async {
        try {
          final p = await service.transferState();
          if (!mounted) return;
          final total = (p['total'] as num?)?.toDouble() ?? 0;
          setState(
            () => progress = total > 0
                ? ((p['done'] as num).toDouble() / total).clamp(0, 1)
                : null,
          );
        } catch (_) {}
      });
    }
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = readableError(e));
    } finally {
      transferTimer?.cancel();
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  Future<void> loginNetwork() => task(() async {
    await service.startNetwork();
    await service.loginNetwork();
    await refreshNetwork();
  });
  Future<void> connect() => task(() async {
    if (host.text.trim().isEmpty ||
        user.text.trim().isEmpty ||
        password.text.isEmpty) {
      throw StateError('Nhập địa chỉ router, tài khoản và mật khẩu SMB.');
    }
    files = null;
    shares = await service.connect(
      NasConnection(
        host: host.text,
        username: user.text,
        password: password.text,
        remote: remote,
      ),
    );
    if (shares.isEmpty) throw StateError('Router chưa có thư mục chia sẻ SMB.');
    if (!shares.contains(share)) share = shares.first;
    Object? mountError;
    for (final candidate in [share, ...shares.where((item) => item != share)]) {
      try {
        files = await service.mount(candidate);
        share = candidate;
        break;
      } catch (error) {
        mountError = error;
      }
    }
    if (files == null) {
      throw mountError ?? StateError('Chưa mở được thư mục chia sẻ.');
    }
    path = '';
    parseFiles();
    try {
      await storage.write(
        key: 'connection-v2',
        value: jsonEncode({
          'host': host.text.trim(),
          'user': user.text.trim(),
          'password': remember ? password.text : '',
          'remote': remote,
          'share': share,
        }),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Đã kết nối. Chưa lưu được đăng nhập trên thiết bị này.',
        );
      }
    }
    if (!remember) password.clear();
    if (mounted) setState(() => tab = 0);
  });
  void parseFiles() {
    entries = ((files?['entries'] as List?) ?? [])
        .map((e) => NasEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> reloadFiles() async {
    files = await service.list(path);
    if (mounted) setState(parseFiles);
  }

  String child(String name) => path.isEmpty ? name : '$path/$name';
  Future<void> openFolder(NasEntry entry) => task(() async {
    final next = child(entry.name);
    final result = await service.list(next);
    path = next;
    files = result;
    if (mounted) setState(parseFiles);
  });
  Future<void> goUp() => task(() async {
    final p = path.split('/')..removeLast();
    final next = p.join('/');
    final result = await service.list(next);
    path = next;
    files = result;
    if (mounted) setState(parseFiles);
  });

  Future<String?> askName(String title, {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (context) => NameDialog(title: title, initial: initial),
      );
  Future<void> newFolder() async {
    final name = await askName('Tạo thư mục');
    if (name == null) return;
    await task(() async {
      await service.mkdir(child(name));
      await reloadFiles();
    });
  }

  Future<void> rename(NasEntry entry) async {
    final name = await askName('Đổi tên', initial: entry.name);
    if (name == null || name == entry.name) return;
    await task(() async {
      await service.rename(child(entry.name), child(name));
      await reloadFiles();
    });
  }

  Future<void> remove(NasEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khỏi NAS?'),
        content: Text(entry.name),
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
    if (yes != true) return;
    await task(() async {
      await service.remove(child(entry.name));
      await reloadFiles();
    });
  }

  Future<void> upload() async {
    final picked = await FilePicker.pickFile();
    if (picked?.path == null) return;
    final item = picked!;
    await task(() async {
      await service.upload(item.path!, child(item.name));
      await reloadFiles();
    }, transfer: true);
  }

  Future<void> download(NasEntry entry) => task(() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/nas-${DateTime.now().microsecondsSinceEpoch}.download',
    );
    try {
      await service.download(child(entry.name), file.path);
      final saved = await service.exportFile(file.path, entry.name);
      if (mounted && saved) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu tệp')));
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }, transfer: true);

  Future<Map<String, dynamic>> call(
    String object,
    String method,
    Map<String, dynamic> args,
  ) => service.rpc(host.text, remote, rootSession, object, method, args);
  Future<void> adminLogin() => task(() async {
    final result = await service.rpc(
      host.text,
      remote,
      '0' * 32,
      'session',
      'login',
      {'username': adminUser.text, 'password': adminPassword.text},
    );
    adminPassword.clear();
    rootSession = result['ubus_rpc_session'] as String;
    disks = await call('nas.disks', 'status', {});
    if (mounted) setState(() {});
  });
  Future<void> loadDisks() => task(() async {
    disks = await call('nas.disks', 'status', {});
    if (mounted) setState(() {});
  });
  Future<void> diskAction(Map<String, dynamic> part, String operation) async {
    String secret = '';
    if (operation == 'mount' &&
        part['fstype'] == 'BitLocker' &&
        part['key_saved'] != true) {
      final value = await showDialog<String>(
        context: context,
        builder: (context) => const PasswordDialog(),
      );
      if (value == null) return;
      secret = value;
    }
    if (operation == 'unmount') {
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tháo gắn phân vùng?'),
          content: const Text('Đóng các tệp đang dùng trước khi tiếp tục.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tháo gắn'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    await task(() async {
      final settings = Map<String, dynamic>.from(part['settings'] as Map);
      if (operation == 'mount' && settings['configured'] != true) {
        final reply = await call('nas.disks', 'configure', {
          'uuid': part['uuid'],
          'name': settings['name'],
          'path': settings['path'],
          'readonly': settings['readonly'] != false,
          'enabled': settings['enabled'] == true,
        });
        if (reply['error'] != null) {
          throw StateError('Chưa lưu được cấu hình phân vùng.');
        }
      }
      final result = await call('nas.disks', 'action', {
        'uuid': part['uuid'],
        'operation': operation,
        'password': secret,
      });
      secret = '';
      if (result['error'] != null) {
        throw StateError(
          'Router chưa thực hiện được thao tác: ${result['error']}',
        );
      }
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        disks = await call('nas.disks', 'status', {});
        if (mounted) setState(() {});
        if (disks?['busy'] != true) break;
      }
    });
  }

  Widget panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget gap([double height = 14]) => SizedBox(height: height);
  Widget empty(String title, String text, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: brand),
          gap(),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          gap(8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          gap(),
          FilledButton(
            onPressed: () => setState(() => tab = 2),
            child: const Text('Thiết lập kết nối'),
          ),
        ],
      ),
    ),
  );

  Widget connections() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      panel(
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tailscale',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    network == 'Running' ? 'Đã kết nối' : 'Chưa kết nối',
                    style: TextStyle(
                      color: network == 'Running' ? brand : Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (network != 'Running')
              TextButton.icon(
                onPressed: busy ? null : loginNetwork,
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập'),
              ),
            if (network == 'Running')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => task(() async {
                          await service.logoutNetwork();
                          rootSession = '';
                          disks = null;
                          files = null;
                          shares = [];
                          await refreshNetwork();
                        }),
                  child: const Text('Đăng xuất'),
                ),
              ),
          ],
        ),
      ),
      gap(),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Từ xa'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Trong nhà'),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {remote},
              onSelectionChanged: busy
                  ? null
                  : (value) => setState(() {
                      remote = value.first;
                      rootSession = '';
                      disks = null;
                    }),
            ),
            gap(20),
            TextField(
              controller: host,
              enabled: !busy,
              onChanged: (_) => setState(() {
                rootSession = '';
                disks = null;
              }),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'IP router',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            gap(),
            TextField(
              controller: user,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Tài khoản SMB',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            gap(),
            TextField(
              controller: password,
              obscureText: hidden,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Mật khẩu SMB',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => hidden = !hidden),
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhớ đăng nhập'),
              value: remember,
              onChanged: busy
                  ? null
                  : (v) => setState(() => remember = v ?? false),
            ),
            FilledButton.icon(
              onPressed: busy ? null : connect,
              icon: const Icon(Icons.link),
              label: const Text('Kết nối NAS'),
            ),
            if (service.isConnected)
              TextButton(
                onPressed: busy
                    ? null
                    : () => task(() async {
                        await service.disconnect();
                        files = null;
                        rootSession = '';
                        disks = null;
                        setState(() {});
                      }),
                child: const Text('Ngắt kết nối NAS'),
              ),
          ],
        ),
      ),
      gap(),
      const Text(
        'Tailscale chỉ hoạt động trong Khoa NAS.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
      ),
    ],
  );

  Widget fileBrowser() {
    if (!service.isConnected || files == null) {
      return empty(
        'Tệp trên NAS',
        'Kết nối router để mở thư mục chia sẻ.',
        Icons.folder_outlined,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  isExpanded: true,
                  value: shares.contains(share) ? share : null,
                  items: shares
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: busy
                      ? null
                      : (name) => task(() async {
                          share = name!;
                          path = '';
                          files = await service.mount(share);
                          setState(parseFiles);
                        }),
                ),
                if (files?['available'] != null)
                  Text(
                    '${formatBytes(files?['available'] as num?)} trống / ${formatBytes(files?['total'] as num?)}',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: path.isEmpty || busy ? null : goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(
                child: Text(
                  path.isEmpty ? '/' : path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Tạo thư mục',
                onPressed: busy ? null : newFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                tooltip: 'Tải lên',
                onPressed: busy ? null : upload,
                icon: const Icon(Icons.upload_outlined),
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: busy ? null : () => task(reloadFiles),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('Thư mục trống'))
              : RefreshIndicator(
                  onRefresh: () => task(reloadFiles),
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      return ListTile(
                        leading: Icon(
                          e.isDirectory
                              ? Icons.folder
                              : Icons.insert_drive_file_outlined,
                          color: e.isDirectory
                              ? const Color(0xffdfa439)
                              : brand,
                          size: 30,
                        ),
                        title: Text(
                          e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          e.isDirectory ? 'Thư mục' : formatBytes(e.size),
                        ),
                        onTap: busy
                            ? null
                            : () => e.isDirectory ? openFolder(e) : download(e),
                        trailing: PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (value) {
                            if (value == 'download') download(e);
                            if (value == 'rename') rename(e);
                            if (value == 'delete') remove(e);
                          },
                          itemBuilder: (_) => [
                            if (!e.isDirectory)
                              const PopupMenuItem(
                                value: 'download',
                                child: Text('Tải xuống'),
                              ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Đổi tên'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget diskManager() {
    if (host.text.trim().isEmpty) {
      return empty(
        'Ổ đĩa của router',
        'Nhập địa chỉ router trong Kết nối.',
        Icons.storage_outlined,
      );
    }
    if (rootSession.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Quản trị router',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                gap(),
                TextField(
                  controller: adminUser,
                  decoration: const InputDecoration(
                    labelText: 'Tài khoản LuCI',
                  ),
                ),
                gap(),
                TextField(
                  controller: adminPassword,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu router',
                  ),
                ),
                gap(),
                FilledButton(
                  onPressed: busy ? null : adminLogin,
                  child: const Text('Đăng nhập router'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final all = (disks?['disks'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: loadDisks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ổ đĩa trên router',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: busy ? null : loadDisks,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Đăng xuất quản trị',
                onPressed: busy
                    ? null
                    : () => setState(() {
                        rootSession = '';
                        disks = null;
                      }),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Chưa tìm thấy ổ dữ liệu.'),
            ),
          for (final disk in all) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${disk['model']} · ${formatBytes(disk['size'] as num?)}',
              ),
            ),
            if (disk['io_warning'] == true)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Đã có lỗi I/O trong phiên khởi động. Kiểm tra cáp và nguồn ổ.',
                  style: TextStyle(color: Color(0xff9b6500)),
                ),
              ),
            for (final raw in (disk['partitions'] as List))
              Builder(
                builder: (context) {
                  final p = Map<String, dynamic>.from(raw as Map);
                  final settings = p['settings'] as Map;
                  final mount = p['mount'] as Map?;
                  if (p['uuid'] == '') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          dense: true,
                          title: Text('${settings['name']}'),
                          trailing: Text(formatBytes(p['size'] as num?)),
                          subtitle: const Text('Chưa xác định hệ thống tệp'),
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${settings['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          gap(6),
                          Text(
                            '${formatBytes(p['size'] as num?)} · ${p['fstype']}',
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mount == null
                                      ? (p['fstype'] == 'BitLocker'
                                            ? 'Đang khóa'
                                            : 'Chưa gắn')
                                      : (mount['mode'] == 'rw'
                                            ? 'Đọc / ghi'
                                            : 'Chỉ đọc'),
                                  style: const TextStyle(color: brand),
                                ),
                              ),
                              if (p['uuid'] != '')
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => diskAction(
                                          p,
                                          mount == null ? 'mount' : 'unmount',
                                        ),
                                  child: Text(
                                    mount == null
                                        ? (p['fstype'] == 'BitLocker'
                                              ? 'Mở khóa'
                                              : 'Gắn')
                                        : 'Tháo gắn',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Image.asset('assets/github-avatar.png', width: 34, height: 34),
          const SizedBox(width: 10),
          const Text('Khoa NAS'),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Trợ giúp',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Khoa NAS'),
              content: const Text(
                'Dùng tài khoản SMB để mở tệp. Tài khoản router chỉ dùng trong mục Ổ đĩa.\n\nKết nối từ xa qua Tailscale tích hợp, không cần app VPN riêng.',
              ),
              actions: [
                TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Khoa NAS',
                    applicationVersion: '2.0.0',
                  ),
                  child: const Text('Giấy phép'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.help_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        if (busy) LinearProgressIndicator(value: progress),
        if (message != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(message!)),
                IconButton(
                  onPressed: () => setState(() => message = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (transferTimer?.isActive == true)
          TextButton(
            onPressed: service.cancelTransfer,
            child: const Text('Hủy truyền tệp'),
          ),
        Expanded(
          child: switch (tab) {
            0 => fileBrowser(),
            1 => diskManager(),
            _ => connections(),
          },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'Tệp',
        ),
        NavigationDestination(
          icon: Icon(Icons.storage_outlined),
          selectedIcon: Icon(Icons.storage),
          label: 'Ổ đĩa',
        ),
        NavigationDestination(icon: Icon(Icons.link), label: 'Kết nối'),
      ],
    ),
  );
}

class NameDialog extends StatefulWidget {
  const NameDialog({super.key, required this.title, required this.initial});
  final String title, initial;
  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Tên'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (validEntryName(controller.text)) {
            Navigator.pop(context, controller.text);
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mở khóa BitLocker'),
    content: TextField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(labelText: 'Mật khẩu phân vùng'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Mở khóa'),
      ),
    ],
  );
}
