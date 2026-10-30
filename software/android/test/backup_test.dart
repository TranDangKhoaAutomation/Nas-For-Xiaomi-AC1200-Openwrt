import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/backup_page.dart';
import 'package:nas_client/smb_service.dart';

void main() {
  testWidgets(
    'Backup defaults off, scopes folders and saves editable settings before running',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      Map<String, dynamic>? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NasService.channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'backupGet':
                return jsonEncode({'profile': {}, 'status': {}});
              case 'backupPickFolder':
                return {'uri': 'content://test/tree/camera', 'name': 'Camera'};
              case 'backupSave':
                saved = jsonDecode(
                  (call.arguments as Map)['profile'] as String,
                ) as Map<String, dynamic>;
                return null;
              default:
                return null;
            }
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const BackupPage(
              host: '192.168.1.1',
              user: 'nas',
              share: 'PHOTOS',
              remote: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tự sao lưu đang tắt'), findsOneWidget);
      expect(calls, ['backupGet']);
      final run = find.widgetWithText(FilledButton, 'Sao lưu ngay');
      expect(tester.widget<FilledButton>(run).onPressed, isNull);
      await tester.tap(find.byTooltip('Thêm thư mục'));
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
      final password = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Mật khẩu SMB',
      );
      await tester.ensureVisible(password);
      await tester.enterText(password, 'fixture-password-not-a-real-secret');
      final save = find.widgetWithText(FilledButton, 'Lưu thiết lập');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?['enabled'], false);
      expect(saved?['wifi'], true);
      expect(saved?['sources'], [
        {'uri': 'content://test/tree/camera', 'name': 'Camera'},
      ]);
      expect(saved?['share'], 'PHOTOS');
      expect(saved?['password'], 'fixture-password-not-a-real-secret');
      expect(calls.where((c) => c == 'backupRun'), isEmpty);
      expect(tester.widget<TextField>(password).controller?.text, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
