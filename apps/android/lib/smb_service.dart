import 'dart:io';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';

class NasConnection {
  const NasConnection({
    required this.host,
    required this.share,
    required this.username,
    required this.password,
    this.domain = '',
  });

  final String host;
  final String share;
  final String username;
  final String password;
  final String domain;
}

class NasService {
  Smb2Pool? _pool;
  NasConnection? _connection;

  bool get isConnected => _pool != null;
  NasConnection? get connection => _connection;

  Future<void> connect(NasConnection connection) async {
    await disconnect();
    final pool = await Smb2Pool.connect(
      host: connection.host.trim(),
      share: connection.share.trim(),
      user: connection.username.trim().isEmpty
          ? null
          : connection.username.trim(),
      password: connection.password.isEmpty ? null : connection.password,
      domain: connection.domain.trim().isEmpty
          ? null
          : connection.domain.trim(),
      workers: 2,
      timeoutSeconds: 15,
      signing: true,
      version: Smb2Version.any,
    );
    _pool = pool;
    _connection = connection;
    await pool.listDirectory('');
  }

  Future<void> disconnect() async {
    final pool = _pool;
    _pool = null;
    _connection = null;
    if (pool != null) await pool.disconnect();
  }

  Smb2Pool get _requirePool {
    final pool = _pool;
    if (pool == null) throw StateError('Chưa kết nối NAS');
    return pool;
  }

  Future<List<Smb2DirEntry>> listDirectory(String path) async {
    final items = await _requirePool.listDirectory(path);
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  Future<Smb2StatVfs> storageInfo() => _requirePool.statvfs('');
  Future<void> createDirectory(String path) => _requirePool.mkdir(path);

  Future<void> deleteEntry(String path, {required bool isDirectory}) =>
      isDirectory ? _requirePool.rmdir(path) : _requirePool.deleteFile(path);

  Future<void> uploadFile(
    File localFile,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final total = await localFile.length();
    var sent = 0;
    final source = localFile.openRead().map((chunk) {
      final data = Uint8List.fromList(chunk);
      sent += data.length;
      onProgress?.call(sent, total);
      return data;
    });
    await _requirePool.streamWrite(remotePath, source);
  }

  Future<int> downloadFile(
    String remotePath,
    File destination, {
    void Function(int received, int total)? onProgress,
  }) {
    return _requirePool.downloadToFile(
      remotePath,
      destination,
      onProgress: onProgress,
    );
  }
}
