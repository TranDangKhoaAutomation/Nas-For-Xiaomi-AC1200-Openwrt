import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'smb_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    this.host = '',
    this.user = '',
    this.share = '',
    this.remote = true,
  });
  final String host, user, share;
  final bool remote;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final host = TextEditingController(),
      user = TextEditingController(),
      share = TextEditingController();
  final password = TextEditingController(),
      path = TextEditingController(text: 'Anh-sao-luu');
  List<Map<String, dynamic>> sources = [];
  Map<String, dynamic> status = {};
  bool enabled = false,
      wifi = true,
      charging = false,
      images = true,
      videos = true;
  bool remote = true,
      saving = false,
      loaded = false,
      hasPassword = false,
      saved = false;
  int minutes = 60;
  String? error;
  Timer? timer;
  bool dirty = false;
  void edit(VoidCallback change) => setState(() {
    dirty = true;
    change();
  });
  @override
  void initState() {
    super.initState();
    host.text = widget.host;
    user.text = widget.user;
    share.text = widget.share;
    remote = widget.remote;
    for (final c in [host, user, share, password, path]) {
      c.addListener(() {
        if (loaded && mounted) {
          setState(() => dirty = true);
        }
      });
    }
    refresh(initial: true);
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> refresh({bool initial = false}) async {
    try {
      final raw = await NasService.channel.invokeMethod<String>('backupGet');
      final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        status = Map<String, dynamic>.from(data['status'] as Map? ?? {});
        if (initial) {
          final p = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
          saved = (p['id'] as String? ?? '').isNotEmpty;
          if (saved) {
            host.text = p['host'] ?? '';
            user.text = p['user'] ?? '';
            share.text = p['share'] ?? '';
            path.text = p['path'] ?? 'Anh-sao-luu';
            enabled = p['enabled'] == true;
            remote = p['remote'] != false;
            wifi = p['wifi'] != false;
            charging = p['charging'] == true;
            images = p['images'] != false;
            videos = p['videos'] != false;
            minutes = p['minutes'] as int? ?? 60;
            hasPassword = p['hasPassword'] == true;
            sources = (p['sources'] as List? ?? [])
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList();
          }
          loaded = true;
        }
      });
    } catch (_) {
      if (mounted && initial) {
        setState(() {
          loaded = true;
          error = 'Chưa đọc được thiết lập sao lưu trên thiết bị này.';
        });
      }
    }
  }

  Future<void> action(Future<void> Function() run) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await run();
      await refresh();
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? 'Chưa hoàn tất thao tác.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Chưa hoàn tất thao tác. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> addFolder() => action(() async {
    final value = await NasService.channel.invokeMapMethod<String, dynamic>(
      'backupPickFolder',
    );
    if (value == null || !mounted) return;
    edit(() {
      if (!sources.any((v) => v['uri'] == value['uri'])) {
        sources.add(Map<String, dynamic>.from(value));
      }
    });
  });

  Future<void> save() => action(() async {
    await NasService.channel.invokeMethod<void>('backupSave', {
      'profile': jsonEncode({
        'host': host.text.trim(),
        'user': user.text.trim(),
        'share': share.text.trim(),
        'path': path.text.trim(),
        'password': password.text,
        'remote': remote,
        'enabled': enabled,
        'wifi': wifi,
        'charging': charging,
        'images': images,
        'videos': videos,
        'minutes': minutes,
        'sources': sources,
      }),
    });
    password.clear();
    if (mounted) {
      setState(() {
        saved = true;
        hasPassword = true;
        dirty = false;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thiết lập sao lưu')));
    }
  });

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [host, user, share, password, path]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: !secret,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());
    final running = status['running'] == true;
    final transfer = Map<String, dynamic>.from(
      status['transfer'] as Map? ?? {},
    );
    final total = (transfer['total'] as num? ?? 0).toDouble();
    final done = (transfer['done'] as num? ?? 0).toDouble();
    final color = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.primaryContainer,
                      child: Icon(
                        running ? Icons.cloud_upload : Icons.backup_outlined,
                        color: color.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sao lưu ảnh và video',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            enabled && saved
                                ? 'Tự động • ${wifi ? 'Wi-Fi không tính phí' : 'Wi-Fi và dữ liệu di động'}'
                                : 'Tự sao lưu đang tắt',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  status['message'] as String? ??
                      'Chọn thư mục để giữ ảnh trên NAS.',
                ),
                if ((status['file'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      status['file'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (running)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (done / total).clamp(0.0, 1.0) : null,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: saving || !saved || dirty || running
                          ? null
                          : () => action(() async {
                              await NasService.channel.invokeMethod<void>(
                                'backupRun',
                              );
                            }),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Sao lưu ngay'),
                    ),
                    if (running || status['queued'] == true || enabled)
                      OutlinedButton(
                        onPressed: saving
                            ? null
                            : () => action(() async {
                                await NasService.channel.invokeMethod<void>(
                                  'backupStop',
                                );
                                if (mounted) setState(() => enabled = false);
                              }),
                        child: const Text('Dừng'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Thư mục trên điện thoại',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Thêm thư mục',
                      onPressed: saving || running || sources.length >= 16
                          ? null
                          : addFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                  ],
                ),
                if (sources.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Thêm Camera, Screenshots hoặc thư mục bạn chọn.',
                    ),
                  ),
                for (final source in sources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(
                      source['name'] as String? ?? 'Thư mục ảnh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Bỏ thư mục',
                      onPressed: saving || running
                          ? null
                          : () => edit(() => sources.remove(source)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Ảnh'),
                      selected: images,
                      onSelected: running
                          ? null
                          : (v) => edit(() => images = v),
                    ),
                    FilterChip(
                      label: const Text('Video'),
                      selected: videos,
                      onSelected: running
                          ? null
                          : (v) => edit(() => videos = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: !saved,
            title: const Text('Thiết lập sao lưu'),
            subtitle: Text(
              saved
                  ? '${host.text} / ${share.text}'
                  : 'Nơi lưu và lịch sao lưu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tự động sao lưu'),
                value: enabled,
                onChanged: running ? null : (v) => edit(() => enabled = v),
              ),
              field(host, 'IP router'),
              field(share, 'Tên chia sẻ SMB', hint: 'Ví dụ: DANGKHOA'),
              field(path, 'Thư mục lưu trên NAS'),
              field(user, 'Tài khoản SMB'),
              field(
                password,
                'Mật khẩu SMB',
                secret: true,
                hint: hasPassword ? 'Để trống để giữ mật khẩu đã lưu' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kết nối từ xa qua Tailscale'),
                value: remote,
                onChanged: running ? null : (v) => edit(() => remote = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chỉ mạng Wi-Fi không tính phí'),
                value: wifi,
                onChanged: running ? null : (v) => edit(() => wifi = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chỉ khi đang sạc'),
                value: charging,
                onChanged: running ? null : (v) => edit(() => charging = v),
              ),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(
                  labelText: 'Kiểm tra ảnh mới',
                ),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('Mỗi 15 phút')),
                  DropdownMenuItem(value: 60, child: Text('Mỗi giờ')),
                  DropdownMenuItem(value: 360, child: Text('Mỗi 6 giờ')),
                  DropdownMenuItem(value: 1440, child: Text('Mỗi ngày')),
                ],
                onChanged: running
                    ? null
                    : (v) => edit(() => minutes = v ?? 60),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: TextStyle(color: color.error)),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saving || running ? null : save,
          icon: const Icon(Icons.check),
          label: Text(saving ? 'Đang lưu…' : 'Lưu thiết lập'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Giữ ảnh gốc trên điện thoại. Ảnh đã sửa được lưu thành phiên bản mới. Android có thể lùi lịch để tiết kiệm pin.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}
