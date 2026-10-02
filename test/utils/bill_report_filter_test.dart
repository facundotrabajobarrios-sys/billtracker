import 'package:billtracker/models/bill.dart';
import 'package:billtracker/utils/bill_report_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterBillsForReport', () {
    final reportDay = DateTime(2026, 10, 2);

    test('includes the complete selected day and excludes the next day', () {
      final lateBill = _bill(
        id: 'late',
        dueDate: DateTime(2026, 10, 2, 23, 59, 59),
      );
      final nextDayBill = _bill(id: 'next-day', dueDate: DateTime(2026, 10, 3));

      final result = filterBillsForReport(
        [lateBill, nextDayBill],
        startDate: reportDay,
        endDate: reportDay,
      );

      expect(result.map((bill) => bill.id), ['late']);
    });

    test('includes a paid bill by its payment date', () {
      final paidBill = _bill(
        id: 'paid',
        dueDate: DateTime(2026, 9, 20),
        paidDate: DateTime(2026, 10, 2, 18),
        status: 'paid',
      );

      final result = filterBillsForReport(
        [paidBill],
        startDate: reportDay,
        endDate: reportDay,
      );

      expect(result, [paidBill]);
    });
  });
}

Bill _bill({
  required String id,
  required DateTime dueDate,
  DateTime? paidDate,
  String status = 'pending',
}) {
  return Bill(
    id: id,
    userId: 'user',
    serviceId: 'service',
    categoryId: 'category',
    amount: 100,
    dueDate: dueDate,
    paidDate: paidDate,
    status: status,
  );
}
