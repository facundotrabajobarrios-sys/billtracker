import 'package:billtracker/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips an optional profile photo URL', () {
    final user = User(
      id: 'user-id',
      email: 'user@example.com',
      name: 'Usuario',
      avatarUrl: 'https://storage.example/avatars/user-id/photo.webp',
    );

    final restored = User.fromJson(user.toJson());

    expect(restored.avatarUrl, user.avatarUrl);
  });

  test('keeps existing users without an avatar compatible', () {
    final user = User.fromJson({
      'id': 'user-id',
      'email': 'user@example.com',
      'name': 'Usuario',
    });

    expect(user.avatarUrl, isNull);
  });

  test(
    'reads administrator status without serializing it into the profile',
    () {
      final user = User.fromJson({
        'id': 'admin-id',
        'email': 'admin@billtracker.invalid',
        'is_admin': true,
        'must_change_password': true,
      });

      expect(user.isAdmin, isTrue);
      expect(user.mustChangePassword, isTrue);
      expect(user.toJson().containsKey('is_admin'), isFalse);
      expect(user.toJson().containsKey('must_change_password'), isFalse);
    },
  );
}
