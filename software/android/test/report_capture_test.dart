// Opt-in visual documentation: synthetic data, never the user's photo library.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/file_browser.dart';
import 'package:nas_client/smb_service.dart';

class FixtureService extends NasService {
  @override
  Future<Map<String, dynamic>> preview(String path, NasEntry entry) async => {
    'thumbnail':
        '${Platform.environment['KHOANAS_VISUAL_OUTPUT']}/fixture-${entry.name.contains('Bien') ? 'sea' : 'mountain'}.png',
    if (isVideo(entry.name)) 'durationMs': 125000,
  };
}

void main() {
  testWidgets('Generate clearly labeled media grid documentation', (
    tester,
  ) async {
    final output = Platform.environment['KHOANAS_VISUAL_OUTPUT'];
    if (output == null) return;
    tester.view.physicalSize = const Size(432, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final loader = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
      await Directory(output).create(recursive: true);
      for (final sea in [true, false]) {
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 300),
          Paint()
            ..color = sea ? const Color(0xff91dbeb) : const Color(0xffccdef0),
        );
        canvas.drawCircle(
          const Offset(310, 65),
          35,
          Paint()..color = const Color(0xffffd77b),
        );
        if (sea) {
          canvas.drawRect(
            const Rect.fromLTWH(0, 165, 400, 135),
            Paint()..color = const Color(0xff178ca5),
          );
          canvas.drawPath(
            Path()
              ..moveTo(0, 250)
              ..quadraticBezierTo(170, 180, 400, 280)
              ..lineTo(400, 300)
              ..lineTo(0, 300)
              ..close(),
            Paint()..color = const Color(0xfff2d9a6),
          );
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(0, 300)
              ..lineTo(140, 70)
              ..lineTo(280, 300)
              ..close(),
            Paint()..color = const Color(0xff507d78),
          );
          canvas.drawPath(
            Path()
              ..moveTo(160, 300)
              ..lineTo(310, 115)
              ..lineTo(430, 300)
              ..close(),
            Paint()..color = const Color(0xff2f5c62),
          );
        }
        final img = await rec.endRecording().toImage(400, 300);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/fixture-${sea ? 'sea' : 'mountain'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      }
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final imageContext = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      for (final kind in ['sea', 'mountain']) {
        await precacheImage(
          ResizeImage(FileImage(File('$output/fixture-$kind.png')), width: 320),
          imageContext,
        );
      }
    });
    final key = GlobalKey();
    final entries =
        [
              'Bien-xanh.jpg',
              'Nui-va-may.jpg',
              'Bien-hoang-hon.mp4',
              'Nui-mua-he.mp4',
            ]
            .map(
              (name) => NasEntry.fromJson({
                'name': name,
                'directory': false,
                'size': 1048576,
                'modified': 0,
              }),
            )
            .toList();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff07898d)),
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Ảnh và video')),
            body: Column(
              children: [
                Container(
                  color: Colors.amber.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'MINH HỌA • dữ liệu giả lập',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: NasFileBrowser(
                    service: FixtureService(),
                    shares: const ['PHOTOS'],
                    share: 'PHOTOS',
                    path: 'Album',
                    entries: entries,
                    busy: false,
                    onShare: (_) {},
                    onOpen: (_) {},
                    onDownload: (_) {},
                    onRename: (_) {},
                    onRemove: (_) {},
                    onUp: () {},
                    onNewFolder: () {},
                    onUpload: () {},
                    onRefresh: () async {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/05-media-grid-illustration.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
