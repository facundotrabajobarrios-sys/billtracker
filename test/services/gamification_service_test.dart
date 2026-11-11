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

    test(
      'preserves paid rewards from deleted bills without double counting',
      () {
        final snapshot = GamificationService.calculateSnapshot(
          [
            {
              'id': 'still-paid',
              'status': 'paid',
              'due_date': '2026-01-03',
              'paid_date': '2026-01-03T08:00:00Z',
            },
          ],
          archivedPaidBills: [
            {
              'bill_id': 'deleted-paid',
              'due_date': '2026-01-01',
              'paid_at': '2026-01-01T08:00:00Z',
            },
            {
              'bill_id': 'still-paid',
              'due_date': '2026-01-03',
              'paid_at': '2026-01-03T08:00:00Z',
            },
          ],
          registeredAt: DateTime(2025, 11, 1),
          now: DateTime(2026, 1, 6),
        );

        expect(snapshot.totalPaidBills, 2);
        expect(snapshot.onTimePayments, 2);
        expect(snapshot.totalPoints, 30);
        expect(snapshot.streakDays, 2);
      },
    );

    test('compares date-only due and paid values as Asuncion civil dates', () {
      final snapshot = GamificationService.calculateSnapshot([
        {
          'id': 'same-day',
          'status': 'paid',
          'due_date': '2026-01-01',
          'paid_date': '2026-01-01',
        },
      ]);

      expect(snapshot.onTimePayments, 1);
      expect(snapshot.streakDays, 1);
      expect(snapshot.totalPoints, 15);
    });

    test('recovers paid bills without inventing a payment date', () {
      final bills = [
        for (var day = 1; day <= 30; day++)
          {
            'id': 'paid-$day',
            'status': 'paid',
            'due_date': DateTime(2026, 1, day).toIso8601String(),
            'paid_date': null,
          },
      ];

      final snapshot = GamificationService.calculateSnapshot(bills);

      expect(snapshot.totalPaidBills, 30);
      expect(snapshot.totalPoints, 300);
      expect(snapshot.onTimePayments, 0);
      expect(snapshot.streakDays, 0);
      expect(
        snapshot.unlockedBadges,
        containsAll(['first_payment', 'paid_10']),
      );
      expect(snapshot.unlockedBadges, isNot(contains('on_time_3')));
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
      expect(snapshot.hasOverdueBills, isTrue);
      expect(snapshot.daysWithoutOverdue, 0);
    });

    test('preserves no-overdue days for an account without current bills', () {
      final snapshot = GamificationService.calculateSnapshot(
        const [],
        registeredAt: DateTime.utc(2025, 11, 1, 12),
        now: DateTime.utc(2026, 1, 6, 15),
      );

      expect(snapshot.daysWithoutOverdue, 66);
      expect(snapshot.unlockedBadges, contains('no_overdue_30'));
    });

    test('tracks days since the latest late payment', () {
      final snapshot = GamificationService.calculateSnapshot(
        [
          {
            'id': 'late',
            'status': 'paid',
            'due_date': '2026-01-01',
            'paid_date': '2026-01-03T08:00:00Z',
          },
          {
            'id': 'pending',
            'status': 'pending',
            'due_date': '2026-01-10',
            'paid_date': null,
          },
        ],
        registeredAt: DateTime(2025, 12, 1),
        now: DateTime.utc(2026, 1, 6, 15),
      );

      expect(snapshot.hasOverdueBills, isFalse);
      expect(snapshot.daysWithoutOverdue, 3);
      expect(snapshot.unlockedBadges, isNot(contains('no_overdue_30')));
    });

    test('does not award the consecutive-payment bonus beyond one day', () {
      final snapshot = GamificationService.calculateSnapshot([
        {
          'id': 'first',
          'status': 'paid',
          'due_date': '2026-01-01',
          'paid_date': '2026-01-01T08:00:00Z',
        },
        {
          'id': 'second',
          'status': 'paid',
          'due_date': '2026-01-03',
          'paid_date': '2026-01-03T07:00:00Z',
        },
      ]);

      expect(snapshot.onTimePayments, 2);
      expect(snapshot.streakDays, 2);
      expect(snapshot.totalPoints, 30);
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
