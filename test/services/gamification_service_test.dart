import 'package:flutter_test/flutter_test.dart';
import 'package:billtracker/services/gamification_service.dart';

void main() {
  group('GamificationService.calculateSnapshot', () {
    test('derives earned badges from paid bills only', () {
      final bills = [
        for (var day = 1; day <= 4; day++)
          {
            'id': 'paid-$day',
            'status': 'paid',
            'due_date': '2026-01-0$day',
            'paid_date': '2026-01-0${day}T08:00:00.000Z',
          },
        {
          'id': 'upcoming',
          'status': 'pending',
          'due_date': '2026-12-01',
          'paid_date': null,
        },
      ];

      final snapshot = GamificationService.calculateSnapshot(
        bills,
        registeredAt: DateTime(2025, 11, 1),
        now: DateTime(2026, 1, 6),
      );

      expect(snapshot.totalPaidBills, 4);
      expect(snapshot.onTimePayments, 4);
      expect(snapshot.streakDays, 4);
      expect(
        snapshot.unlockedBadges,
        containsAll(['first_payment', 'on_time_3']),
      );
      expect(snapshot.unlockedBadges, isNot(contains('paid_10')));
      expect(snapshot.unlockedBadges, contains('no_overdue_30'));
    });

    test('does not count the same paid bill twice', () {
      final bills = [
        {
          'id': 'bill-1',
          'status': 'paid',
          'due_date': '2026-01-01',
          'paid_date': '2026-01-01T08:00:00.000Z',
        },
        {
          'id': 'bill-1',
          'status': 'paid',
          'due_date': '2026-01-01',
          'paid_date': '2026-01-01T08:00:00.000Z',
        },
      ];

      final snapshot = GamificationService.calculateSnapshot(bills);

      expect(snapshot.totalPaidBills, 1);
      expect(snapshot.totalPoints, 15);
    });

    test('an active overdue bill blocks the no-overdue badge', () {
      final snapshot = GamificationService.calculateSnapshot(
        [
          {
            'id': 'overdue',
            'status': 'pending',
            'due_date': '2026-01-05',
            'paid_date': null,
          },
        ],
        registeredAt: DateTime(2025, 11, 1),
        now: DateTime(2026, 1, 6),
      );

      expect(snapshot.unlockedBadges, isNot(contains('no_overdue_30')));
      expect(snapshot.totalPaidBills, 0);
    });

    test('a late payment resets the consecutive on-time payment streak', () {
      final snapshot = GamificationService.calculateSnapshot([
        {
          'id': 'on-time-1',
          'status': 'paid',
          'due_date': '2026-01-01',
          'paid_date': '2026-01-01T08:00:00.000Z',
        },
        {
          'id': 'on-time-2',
          'status': 'paid',
          'due_date': '2026-01-02',
          'paid_date': '2026-01-02T08:00:00.000Z',
        },
        {
          'id': 'late',
          'status': 'paid',
          'due_date': '2026-01-03',
          'paid_date': '2026-01-04T08:00:00.000Z',
        },
      ]);

      expect(snapshot.onTimePayments, 2);
      expect(snapshot.streakDays, 0);
      expect(snapshot.unlockedBadges, isNot(contains('on_time_3')));
    });
  });
}
