import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';

void main() {
  group('UserRole Verification Tests', () {
    test('UserRole contains only admin and client', () {
      expect(UserRole.values.length, 2);
      expect(UserRole.values, containsAll([UserRole.admin, UserRole.client]));
    });

    test('UserRole values and display names match expected format', () {
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.client.value, 'client');
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.client.displayName, 'Client');
    });

    test('UserRole boolean helpers verify roles accurately', () {
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.admin.isClient, isFalse);
      expect(UserRole.client.isClient, isTrue);
      expect(UserRole.client.isAdmin, isFalse);
    });

    test('UserRole.fromString parses valid roles and defaults safely', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('super_admin'), UserRole.admin);
      expect(UserRole.fromString('client'), UserRole.client);
      expect(UserRole.fromString('CLIENT'), UserRole.client);
      // Deprecated coach/trainer inputs must default to client
      expect(UserRole.fromString('coach'), UserRole.client);
      expect(UserRole.fromString('trainer'), UserRole.client);
      expect(UserRole.fromString(null), UserRole.client);
      expect(UserRole.fromString('unknown_role'), UserRole.client);
    });
  });
}
