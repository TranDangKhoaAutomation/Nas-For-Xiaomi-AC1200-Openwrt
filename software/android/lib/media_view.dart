import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'smb_service.dart';

class NasPreview extends StatelessWidget {
  const NasPreview({
    super.key,
    required this.service,
    required this.entry,
    required this.path,
    this.large = false,
  });
  final NasService service;
  final NasEntry entry;
  final String path;
  final bool large;
  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Center(
      child: Icon(
        entry.isDirectory
            ? Icons.folder
            : isVideo(entry.name)
            ? Icons.movie_outlined
            : isImage(entry.name)
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined,
        size: large ? 54 : 30,
        color: entry.isDirectory
            ? const Color(0xffdfa439)
            : const Color(0xff07898d),
      ),
    );
    if (entry.isDirectory || (!isImage(entry.name) && !isVideo(entry.name))) {
      return placeholder();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: service.preview(path, entry),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final file = data['thumbnail'] as String?;
        final duration = (data['durationMs'] as num?)?.toInt() ?? 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (file != null)
              Image.file(
                File(file),
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorBuilder: (_, _, _) => placeholder(),
              )
            else
              placeholder(),
            if (isVideo(entry.name) && large)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    duration > 0
                        ? formatDuration(Duration(milliseconds: duration))
                        : 'Video',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.url,
    required this.name,
    required this.video,
    required this.download,
    this.edit,
  });
  final String url, name;
  final bool video;
  final VoidCallback download;
  final Future<void> Function()? edit;
  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? player;
  String? error;
  bool editing = false;
  @override
  void initState() {
    super.initState();
    if (widget.video) start();
  }

  Future<void> start() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    player = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {});
        await controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa phát được video này. Kiểm tra kết nối hoặc dùng Tải xuống.',
        );
      }
    }
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !editing,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.edit != null)
            IconButton(
              tooltip: 'Cắt và xoay ảnh',
              icon: const Icon(Icons.edit_outlined),
              onPressed: editing
                  ? null
                  : () async {
                      setState(() => editing = true);
                      try {
                        await widget.edit!();
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Chưa lưu được ảnh chỉnh sửa. Kiểm tra kết nối và quyền ghi NAS.',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => editing = false);
                      }
                    },
            ),
          IconButton(
            tooltip: 'Tải xuống',
            icon: const Icon(Icons.download),
            onPressed: editing
                ? null
                : () {
                    Navigator.pop(context);
                    widget.download();
                  },
          ),
        ],
      ),
      body: editing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Đang xử lý ảnh…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : widget.video
          ? video()
          : Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  widget.url,
                  cacheWidth: 2048,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa xem được ảnh này. Kiểm tra kết nối hoặc dùng Tải xuống.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
  Widget video() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final controller = player;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return const Center(
            child: Text(
              'Định dạng này chưa phát được. Bạn có thể tải xuống.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        if (!value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            if (value.isBuffering) const LinearProgressIndicator(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    Row(
                      children: [
                        IconButton(
                          color: Colors.white,
                          tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                          onPressed: () => value.isPlaying
                              ? controller.pause()
                              : controller.play(),
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        Text(
                          '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          color: Colors.white,
                          tooltip: 'Phát lại',
                          onPressed: () => controller.seekTo(Duration.zero),
                          icon: const Icon(Icons.replay),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
