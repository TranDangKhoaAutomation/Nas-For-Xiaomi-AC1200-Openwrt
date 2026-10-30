import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/main.dart';
import 'package:nas_client/smb_service.dart';
import 'package:nas_client/file_browser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Media browser switches grid/list and shows video duration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NasService.channel,
          (call) async =>
              call.method == 'mediaPreview' ? {'durationMs': 120000} : null,
        );
    final entries = ['Folder', 'photo.jpg', 'clip.mp4']
        .map(
          (name) => NasEntry.fromJson({
            'name': name,
            'directory': name == 'Folder',
            'size': 1000,
            'modified': 0,
          }),
        )
        .toList();
    var opens = 0, downloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NasFileBrowser(
            service: NasService(),
            shares: const ['TEST'],
            share: 'TEST',
            path: '',
            entries: entries,
            busy: false,
            onShare: (_) {},
            onOpen: (_) => opens++,
            onDownload: (_) => downloads++,
            onRename: (_) {},
            onRemove: (_) {},
            onUp: () {},
            onNewFolder: () {},
            onUpload: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
    await tester.tap(find.text('Danh sách'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
    await tester.tap(find.text('photo.jpg'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(downloads, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('Media playback only accepts authenticated loopback URLs', () async {
    final service = NasService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NasService.channel,
          (_) async => 'http://8.8.8.8/file',
        );
    await expectLater(service.mediaUrl('clip.mp4'), throwsStateError);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NasService.channel,
          (_) async => 'http://127.0.0.1:1234/token/file',
        );
    expect(
      await service.mediaUrl('clip.mp4'),
      'http://127.0.0.1:1234/token/file',
    );
  });
  testWidgets('Tailscale discovery selects an IP without sending credentials', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NasService.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'networkState') return '{"state":"Running"}';
          if (call.method == 'networkDiscover') {
            return '{"devices":[{"name":"OpenWrt-test","ip":"100.64.1.2","online":true},{"name":"Laptop-test","ip":"100.64.1.3","online":false}]}';
          }
          return null;
        });
    await tester.pumpWidget(const NasApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Mật khẩu SMB'),
      'test-only-old-secret',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('OpenWrt-test'), findsOneWidget);
    await tester.tap(find.text('OpenWrt-test'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'IP router'))
          .controller!
          .text,
      '100.64.1.2',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Mật khẩu SMB'))
          .controller!
          .text,
      isEmpty,
    );
    expect(calls, contains('networkDiscover'));
    expect(calls, isNot(contains('connect')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Connection form fits a small phone and obscures credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NasService.channel, (_) async => null);
    await tester.pumpWidget(const NasApp());
    await tester.pumpAndSettle();
    final smb = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Mật khẩu SMB'),
    );
    expect(smb.obscureText, isTrue);
    expect(find.text('Nhớ đăng nhập'), findsOneWidget);
    await tester.tap(find.text('Ổ đĩa'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập địa chỉ router trong Kết nối.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'Failed reconnect clears the previous authenticated connection',
    () async {
      final service = NasService();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NasService.channel, (_) async {
            throw PlatformException(code: 'AUTH', message: 'Rejected');
          });
      service.connection = const NasConnection(
        host: '192.168.1.1',
        username: 'nas',
        password: '',
      );
      await expectLater(
        service.connect(
          const NasConnection(
            host: '192.168.1.2',
            username: 'nas',
            password: 'test-only',
          ),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(service.isConnected, isFalse);
    },
  );
  for (final link in [
    'smb://100.114.53.95/BITLOCKER',
    'smb://user:secret@100.114.53.95/BITLOCKER',
    'smb://8.8.8.8/share',
  ]) {
    testWidgets(
      'Incoming link requires review: ${link.contains('@') ? 'credentials rejected' : link}',
      (tester) async {
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(
                'plugins.it_nomads.com/flutter_secure_storage',
              ),
              (_) async => null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(NasService.channel, (call) async {
              calls.add(call.method);
              return call.method == 'initialLink' ? link : null;
            });
        await tester.pumpWidget(const NasApp());
        await tester.pumpAndSettle();
        final address = tester.widget<TextField>(
          find.widgetWithText(TextField, 'IP router'),
        );
        expect(
          address.controller!.text,
          link == 'smb://100.114.53.95/BITLOCKER' ? '100.114.53.95' : '',
        );
        expect(calls, isNot(contains('connect')));
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Mật khẩu SMB'))
              .controller!
              .text,
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
