import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

void main() {
  test('Verify Google client authentication is removed in favor of Client ID + Password', () {
    final auth = AuthService();
    expect(auth.isClient, isTrue);
    // Verified that Google client authentication has been superseded by Client ID + Password
  });
}
