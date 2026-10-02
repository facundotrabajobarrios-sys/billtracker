import '../models/bill.dart';

List<Bill> filterBillsForReport(
  Iterable<Bill> bills, {
  required DateTime startDate,
  required DateTime endDate,
  String? category,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final endExclusive = DateTime(endDate.year, endDate.month, endDate.day + 1);

  bool isWithinRange(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return !localDate.isBefore(start) && localDate.isBefore(endExclusive);
  }

  return bills.where((bill) {
    final dueDateInRange = isWithinRange(bill.dueDate);
    final paidDateInRange =
        bill.isPaid && bill.paidDate != null && isWithinRange(bill.paidDate!);
    final matchesCategory = category == null || bill.category?.name == category;
    return (dueDateInRange || paidDateInRange) && matchesCategory;
  }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}
