import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/main.dart';
import 'package:nas_client/smb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
