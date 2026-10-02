import 'package:billtracker/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bill notification settings', () {
    test('round-trips reminder channels and exact scheduled time', () {
      final reminderAt = DateTime.utc(2026, 10, 5, 12, 30);
      final bill = Bill(
        id: 'bill-id',
        userId: 'user-id',
        serviceId: 'service-id',
        categoryId: 'category-id',
        amount: 100000,
        dueDate: DateTime(2026, 10, 8),
        reminderAt: reminderAt,
        reminderPushEnabled: false,
        reminderEmailEnabled: true,
        reminderInAppEnabled: false,
      );

      final restored = Bill.fromJson(bill.toJson());

      expect(restored.reminderAt!.isAtSameMomentAs(reminderAt), isTrue);
      expect(restored.reminderPushEnabled, isFalse);
      expect(restored.reminderEmailEnabled, isTrue);
      expect(restored.reminderInAppEnabled, isFalse);
    });

    test('defaults reminder channels to enabled for existing bills', () {
      final bill = Bill.fromJson({
        'id': 'bill-id',
        'user_id': 'user-id',
        'service_id': 'service-id',
        'category_id': 'category-id',
        'amount': 100000,
        'due_date': '2026-10-08',
      });

      expect(bill.reminderPushEnabled, isTrue);
      expect(bill.reminderEmailEnabled, isTrue);
      expect(bill.reminderInAppEnabled, isTrue);
    });
  });
}
