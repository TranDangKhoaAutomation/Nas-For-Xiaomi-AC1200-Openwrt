import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/main.dart';
import 'package:nas_client/smb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Late native connection cannot restore a canceled session', () async {
    final pending = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NasService.channel,
          (call) async => call.method == 'connect' ? pending.future : null,
        );
    final service = NasService();
    final connection = service.connect(
      const NasConnection(
        host: '192.168.1.1',
        username: 'fixture',
        password: 'fixture',
        remote: false,
      ),
    );
    final result = expectLater(connection, throwsStateError);
    await service.cancelConnection();
    pending.complete('{"shares":["PHOTOS"]}');
    await result;
    expect(service.isConnected, false);
  });

  Future<Completer<String>> startPending(
    WidgetTester tester,
    List<String> calls,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NasService.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'networkState') return '{"state":"Running"}';
          if (call.method == 'connect') return pending.future;
          return null;
        });
    await tester.pumpWidget(const NasApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'IP router'),
      '100.64.1.2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tài khoản SMB'),
      'fixture',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Mật khẩu SMB'),
      'fixture',
    );
    final connect = find.widgetWithText(FilledButton, 'Kết nối NAS');
    await tester.ensureVisible(connect);
    await tester.pumpAndSettle();
    await tester.tap(connect);
    await tester.pump();
    return pending;
  }

  testWidgets('Stalled NAS has Cancel and exits after an overall deadline', (
    tester,
  ) async {
    final calls = <String>[];
    final pending = await startPending(tester, calls);
    expect(find.text('Hủy kết nối'), findsOneWidget);
    await tester.pump(const Duration(seconds: 36));
    await tester.pump();
    expect(find.textContaining('35 giây'), findsOneWidget);
    expect(find.text('Hủy kết nối'), findsNothing);
    expect(calls, contains('cancelConnection'));
    pending.complete('{"shares":["PHOTOS"]}');
    await tester.pump();
    expect(calls.where((c) => c == 'mount'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Cancel releases spinner and ignores a late successful reply', (
    tester,
  ) async {
    final calls = <String>[];
    final pending = await startPending(tester, calls);
    await tester.tap(find.text('Hủy kết nối'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đã hủy kết nối NAS.'), findsOneWidget);
    expect(find.text('Hủy kết nối'), findsNothing);
    pending.complete('{"shares":["PHOTOS"]}');
    await tester.pump();
    expect(calls.where((c) => c == 'mount'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
