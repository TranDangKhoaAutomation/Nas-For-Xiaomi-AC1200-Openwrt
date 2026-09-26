import 'package:flutter_test/flutter_test.dart';
import 'package:nas_client/smb_service.dart';

void main() {
  test('NasConnection preserves connection fields', () {
    const connection = NasConnection(
      host: '100.91.1.101',
      share: 'NAS1',
      username: 'user',
      password: 'secret',
    );

    expect(connection.host, '100.91.1.101');
    expect(connection.share, 'NAS1');
    expect(connection.username, 'user');
    expect(connection.password, 'secret');
  });
}
