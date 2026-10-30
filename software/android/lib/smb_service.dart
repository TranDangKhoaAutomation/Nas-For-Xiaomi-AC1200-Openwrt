import 'dart:convert';

import 'package:flutter/services.dart';

class NasConnection {
  const NasConnection({
    required this.host,
    this.share = '',
    required this.username,
    required this.password,
    this.domain = '',
    this.remote = true,
  });
  final String host, share, username, password, domain;
  final bool remote;
}

class NasEntry {
  NasEntry.fromJson(Map<String, dynamic> data)
    : name = data['name'] as String,
      isDirectory = data['directory'] as bool,
      size = (data['size'] as num).toInt(),
      modified = DateTime.fromMillisecondsSinceEpoch(
        (data['modified'] as num).toInt() * 1000,
      );
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
}

class NasService {
  static const channel = MethodChannel('com.trandangkhoa.nas/native');
  NasConnection? connection;
  String _mountedShare = '';
  final Map<String, Future<Map<String, dynamic>>> _previews = {};
  bool get isConnected => connection != null;

  Future<Map<String, dynamic>> _json(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    final value = await channel.invokeMethod<String>(method, args);
    return jsonDecode(value ?? '{}') as Map<String, dynamic>;
  }

  Future<void> startNetwork() => channel.invokeMethod<void>('networkStart');
  Future<void> loginNetwork() => channel.invokeMethod<void>('networkLogin');
  Future<void> logoutNetwork() async {
    _previews.clear();
    try {
      await channel.invokeMethod<void>('networkLogout');
    } finally {
      connection = null;
    }
  }

  Future<Map<String, dynamic>> networkState() => _json('networkState');
  Future<List<TailnetDevice>> discoverDevices() async {
    final result = await _json('networkDiscover');
    return (result['devices'] as List? ?? [])
        .map((d) => TailnetDevice.fromJson(Map<String, dynamic>.from(d as Map)))
        .where((d) => d.ip.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> transferState() => _json('transferState');
  Future<void> cancelTransfer() => channel.invokeMethod<void>('cancelTransfer');
  Future<List<String>> connect(NasConnection config) async {
    _previews.clear();
    connection = null;
    final result = await _json('connect', {
      'host': config.host.trim(),
      'user': config.username.trim(),
      'password': config.password,
      'domain': config.domain.trim(),
      'remote': config.remote,
    });
    connection = NasConnection(
      host: config.host.trim(),
      username: config.username.trim(),
      password: '',
      domain: config.domain.trim(),
      remote: config.remote,
    );
    return (result['shares'] as List).cast<String>();
  }

  Future<void> disconnect() async {
    _previews.clear();
    await channel.invokeMethod<void>('disconnect');
    connection = null;
  }

  Future<Map<String, dynamic>> mount(String share) {
    _previews.clear();
    _mountedShare = share;
    return _json('mount', {'share': share});
  }

  Future<String> mediaUrl(String path) async {
    final value =
        await channel.invokeMethod<String>('mediaURL', {'path': path}) ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        !uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      throw StateError('Đường dẫn xem trực tuyến không hợp lệ.');
    }
    return value;
  }

  Future<Map<String, dynamic>> preview(String path, NasEntry entry) {
    final key =
        '${connection?.host}:${connection?.username}:${connection?.remote}:$_mountedShare:$path:${entry.size}:${entry.modified.millisecondsSinceEpoch}';
    if (_previews.length > 160) _previews.remove(_previews.keys.first);
    return _previews.putIfAbsent(key, () async {
      try {
        final result = await channel
            .invokeMapMethod<String, dynamic>('mediaPreview', {
              'path': path,
              'kind': isVideo(entry.name) ? 'video' : 'image',
              'cacheKey': key,
            })
            .timeout(const Duration(seconds: 20));
        return result ?? {};
      } catch (_) {
        return {};
      }
    });
  }

  Future<Map<String, dynamic>> list(String path) =>
      _json('list', {'path': path});
  Future<void> mkdir(String path) =>
      channel.invokeMethod<void>('mkdir', {'path': path});
  Future<void> rename(String from, String to) =>
      channel.invokeMethod<void>('rename', {'from': from, 'to': to});
  Future<void> remove(String path) =>
      channel.invokeMethod<void>('remove', {'path': path});
  Future<void> upload(String source, String path) =>
      channel.invokeMethod<void>('upload', {'source': source, 'path': path});
  Future<void> download(String path, String destination) =>
      channel.invokeMethod<void>('download', {
        'path': path,
        'destination': destination,
      });
  Future<bool> exportFile(String path, String name) async =>
      await channel.invokeMethod<bool>('exportFile', {
        'path': path,
        'name': name,
      }) ??
      false;
  Future<Map<String, dynamic>> rpc(
    String host,
    bool remote,
    String session,
    String object,
    String method,
    Map<String, dynamic> params,
  ) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'call',
      'params': [session, object, method, params],
    });
    final response = await _json('routerRequest', {
      'host': host.trim(),
      'body': body,
      'remote': remote,
    });
    final result = response['result'];
    if (response['error'] != null ||
        result is! List ||
        result.isEmpty ||
        result.first != 0) {
      throw StateError(
        'Router từ chối yêu cầu. Kiểm tra đăng nhập và quyền truy cập.',
      );
    }
    return result.length > 1 && result[1] is Map
        ? Map<String, dynamic>.from(result[1] as Map)
        : {};
  }
}

class TailnetDevice {
  TailnetDevice.fromJson(Map<String, dynamic> data)
    : name = data['name'] as String? ?? '',
      ip = data['ip'] as String? ?? '',
      online = data['online'] == true;
  final String name, ip;
  final bool online;
}

String readableError(Object error) {
  if (error is PlatformException) {
    return error.message ?? 'Chưa hoàn tất thao tác';
  }
  return error.toString().replaceFirst(RegExp(r'^(Bad state|Exception): '), '');
}

bool isVideo(String name) => const {
  'mp4',
  'm4v',
  'mov',
  'webm',
  'mkv',
  '3gp',
  'avi',
  'ts',
  'm2ts',
  'mpeg',
  'mpg',
}.contains(name.toLowerCase().split('.').last);
bool isImage(String name) => const {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'avif',
}.contains(name.toLowerCase().split('.').last);
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = (seconds ~/ 60) % 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:${minutes.toString().padLeft(2, '0')}:$s'
      : '${seconds ~/ 60}:$s';
}

String formatBytes(num? value) {
  if (value == null) return '—';
  var n = value.toDouble();
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return '${n.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

bool validEntryName(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    name.trim() == name &&
    !name.endsWith('.') &&
    !RegExp(r'[\\/:*?"<>|\x00-\x1f]').hasMatch(name);
