import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/gamification.dart';
import '../models/bill.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

// 🏆 Servicio de Gamificación
class GamificationSnapshot {
  const GamificationSnapshot({
    required this.totalPaidBills,
    required this.onTimePayments,
    required this.streakDays,
    required this.daysWithoutOverdue,
    required this.hasOverdueBills,
    required this.totalPoints,
    required this.lastPaymentDate,
    required this.unlockedBadges,
  });

  final int totalPaidBills;
  final int onTimePayments;
  final int streakDays;
  final int daysWithoutOverdue;
  final bool hasOverdueBills;
  final int totalPoints;
  final DateTime? lastPaymentDate;
  final List<String> unlockedBadges;
}

class GamificationService {
  // 📦 Instancia única (Singleton)
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static final tz.Location _paraguayLocation = _loadParaguayLocation();

  static tz.Location _loadParaguayLocation() {
    tzdata.initializeTimeZones();
    return tz.getLocation('America/Asuncion');
  }

  // 🔗 Conexión a Supabase
  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  // 📥 Obtener gamificación del usuario
  Future<Gamification?> getGamification(String userId) async {
    final response = await _client
        .from('gamifications')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final gamification = response == null
        ? await _createInitialGamification(userId)
        : Gamification.fromJson(response);
    if (gamification == null) return null;
    return _reconcileWithBills(gamification);
  }

  // 📝 Crear gamificación inicial
  Future<Gamification?> _createInitialGamification(String userId) async {
    final response = await _client
        .from('gamifications')
        .upsert({'user_id': userId}, onConflict: 'user_id')
        .select()
        .single();

    return Gamification.fromJson(response);
  }

  // 📤 Actualizar gamificación
  Future<Gamification?> updateGamification(Gamification gamification) async {
    try {
      final response = await _client
          .from('gamifications')
          .update(gamification.toJson())
          .eq('id', gamification.id)
          .select()
          .single();

      return Gamification.fromJson(response);
    } catch (e) {
      print('❌ Error al actualizar gamificación: $e');
      return null;
    }
  }

  // 🎯 Procesar pago de factura (actualizar gamificación)
  Future<Gamification?> processPayment(String userId, Bill bill) async {
    if (bill.userId != userId) {
      throw StateError('La factura no pertenece al usuario autenticado.');
    }
    return getGamification(userId);
  }

  Future<Gamification> _reconcileWithBills(Gamification current) async {
    final rows = await _client
        .from('bills')
        .select('id,status,due_date,paid_date')
        .eq('user_id', current.userId);
    final historyRows = await _client
        .from('paid_bill_history')
        .select('bill_id,due_date,paid_at')
        .eq('user_id', current.userId);
    final user = await _client
        .from('users')
        .select('created_at')
        .eq('id', current.userId)
        .maybeSingle();
    final snapshot = calculateSnapshot(
      List<Map<String, dynamic>>.from(rows),
      archivedPaidBills: List<Map<String, dynamic>>.from(historyRows),
      registeredAt: DateTime.tryParse(user?['created_at']?.toString() ?? ''),
    );
    final badges = {
      ...current.unlockedBadges,
      ...snapshot.unlockedBadges,
    }.toList();
    final level = Gamification.calculateLevel(snapshot.totalPoints);
    final changed =
        current.totalPaidBills != snapshot.totalPaidBills ||
        current.onTimePayments != snapshot.onTimePayments ||
        current.streakDays != snapshot.streakDays ||
        current.daysWithoutOverdue != snapshot.daysWithoutOverdue ||
        current.hasOverdueBills != snapshot.hasOverdueBills ||
        current.totalPoints != snapshot.totalPoints ||
        current.currentLevel != level ||
        current.lastPaymentDate != snapshot.lastPaymentDate ||
        current.unlockedBadges.length != badges.length ||
        !current.unlockedBadges.toSet().containsAll(badges);
    if (!changed) return current;

    final response = await _client
        .from('gamifications')
        .update({
          'total_paid_bills': snapshot.totalPaidBills,
          'on_time_payments': snapshot.onTimePayments,
          'streak_days': snapshot.streakDays,
          'days_without_overdue': snapshot.daysWithoutOverdue,
          'has_overdue_bills': snapshot.hasOverdueBills,
          'total_points': snapshot.totalPoints,
          'current_level': level,
          'last_payment_date': snapshot.lastPaymentDate?.toIso8601String(),
          'unlocked_badges': badges,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', current.id)
        .select()
        .single();
    return Gamification.fromJson(response);
  }

  @visibleForTesting
  static GamificationSnapshot calculateSnapshot(
    List<Map<String, dynamic>> bills, {
    List<Map<String, dynamic>> archivedPaidBills = const [],
    DateTime? registeredAt,
    DateTime? now,
  }) {
    final today = _localCivilDate(now ?? DateTime.now());
    final allBills = [
      ...bills,
      ...archivedPaidBills.map(
        (history) => <String, dynamic>{
          'id': history['bill_id'],
          'status': 'paid',
          'due_date': history['due_date'],
          'paid_date': history['paid_at'],
        },
      ),
    ];
    final seenIds = <String>{};
    final paid =
        <({String id, DateTime? paidAt, DateTime? paidDay, bool onTime})>[];
    var paidCount = 0;
    var hasActiveOverdue = false;
    DateTime? latestLatePaymentDay;
    for (final bill in allBills) {
      final status = bill['status'];
      final dueDay = _parseCivilDate(bill['due_date']);
      final paidAt = _parsePaymentInstant(bill['paid_date']);
      final paidDay = _parseCivilDate(bill['paid_date']);
      if (status != 'paid' &&
          (status == 'overdue' || (dueDay != null && dueDay.isBefore(today)))) {
        hasActiveOverdue = true;
      }
      if (status == 'paid' &&
          dueDay != null &&
          paidDay != null &&
          paidDay.isAfter(dueDay) &&
          (latestLatePaymentDay == null ||
              paidDay.isAfter(latestLatePaymentDay))) {
        latestLatePaymentDay = paidDay;
      }
      if (status != 'paid') continue;
      final id = bill['id']?.toString();
      if (id != null && !seenIds.add(id)) continue;
      paidCount++;
      paid.add((
        id: id ?? '',
        paidAt: paidAt,
        paidDay: paidDay,
        onTime: paidDay != null && dueDay != null && !paidDay.isAfter(dueDay),
      ));
    }
    paid.sort((a, b) {
      if (a.paidAt == null && b.paidAt != null) return -1;
      if (a.paidAt != null && b.paidAt == null) return 1;
      if (a.paidAt != null && b.paidAt != null) {
        final dateOrder = a.paidAt!.compareTo(b.paidAt!);
        if (dateOrder != 0) return dateOrder;
      }
      return a.id.compareTo(b.id);
    });

    var onTimePayments = 0;
    var streak = 0;
    var points = 0;
    var previousWasOnTime = false;
    DateTime? previousPaidAt;
    DateTime? lastPaymentDate;
    for (final payment in paid) {
      if (payment.paidAt != null) lastPaymentDate = payment.paidDay;
      points += 10;
      if (payment.onTime) {
        onTimePayments++;
        streak++;
        points += 5;
        if (previousWasOnTime &&
            previousPaidAt != null &&
            payment.paidAt != null &&
            payment.paidAt!.difference(previousPaidAt) <=
                const Duration(days: 1)) {
          points += 5;
        }
      } else {
        streak = 0;
      }
      previousWasOnTime = payment.onTime;
      previousPaidAt = payment.paidAt;
    }

    final registeredDay = registeredAt == null
        ? null
        : _localCivilDate(registeredAt);
    final daysWithoutOverdue = hasActiveOverdue || registeredDay == null
        ? 0
        : today
              .difference(
                latestLatePaymentDay != null &&
                        latestLatePaymentDay.isAfter(registeredDay)
                    ? latestLatePaymentDay
                    : registeredDay,
              )
              .inDays
              .clamp(0, 0x7fffffff)
              .toInt();
    final badges = <String>[
      if (paidCount >= 1) 'first_payment',
      if (streak >= 3) 'on_time_3',
      if (streak >= 7) 'on_time_7',
      if (streak >= 30) 'on_time_30',
      if (paidCount >= 10) 'paid_10',
      if (paidCount >= 50) 'paid_50',
      if (daysWithoutOverdue >= 30) 'no_overdue_30',
    ];
    return GamificationSnapshot(
      totalPaidBills: paidCount,
      onTimePayments: onTimePayments,
      streakDays: streak,
      daysWithoutOverdue: daysWithoutOverdue,
      hasOverdueBills: hasActiveOverdue,
      totalPoints: points,
      lastPaymentDate: lastPaymentDate,
      unlockedBadges: badges,
    );
  }

  static DateTime _localCivilDate(DateTime instant) {
    final local = tz.TZDateTime.from(instant, _paraguayLocation);
    return DateTime.utc(local.year, local.month, local.day);
  }

  static DateTime? _parseCivilDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime.utc(year, month, day);
    }
    final hasTimezone = RegExp(
      r'[T ]\d{2}:\d{2}.*(Z|[+-]\d{2}(:?\d{2})?)$',
      caseSensitive: false,
    ).hasMatch(raw);
    if (!hasTimezone) return DateTime.utc(year, month, day);

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _localCivilDate(parsed);
  }

  static DateTime? _parsePaymentInstant(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      final date = _parseCivilDate(raw);
      if (date == null) return null;
      return tz.TZDateTime(
        _paraguayLocation,
        date.year,
        date.month,
        date.day,
      ).toUtc();
    }
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?)?',
    ).firstMatch(raw);
    if (match == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final hasTimezone = RegExp(
      r'[T ]\d{2}:\d{2}.*(Z|[+-]\d{2}(:?\d{2})?)$',
      caseSensitive: false,
    ).hasMatch(raw);
    if (hasTimezone) return parsed.toUtc();

    final fraction = match.group(7) ?? '';
    final microseconds = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(6, '0').substring(0, 6));
    return tz.TZDateTime(
      _paraguayLocation,
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      microseconds % 1000,
    ).toUtc();
  }

  // 🔔 Crear notificaciones para insignias desbloqueadas
  Future<void> notifyNewBadges(
    String userId,
    List<String> oldBadges,
    List<String> newBadges,
  ) async {
    final unlocked = newBadges.where((b) => !oldBadges.contains(b)).toList();

    if (unlocked.isEmpty) return;

    final allBadges = Gamification.getAvailableBadges();
    final notificationService = NotificationService();

    for (final badgeId in unlocked) {
      final badge = allBadges.firstWhere(
        (b) => b.id == badgeId,
        orElse: () => AchievementBadge(
          id: badgeId,
          name: 'Nueva Insignia',
          description: '¡Has desbloqueado una nueva insignia!',
          icon: '🏅',
          requirement: '',
        ),
      );

      final notification = await notificationService.createNotification(
        NotificationModel(
          id: '',
          userId: userId,
          title: '¡Nueva insignia desbloqueada!',
          message: 'Has obtenido "${badge.name}" - ${badge.description}',
          type: 'success',
        ),
      );
      if (notification == null) {
        debugPrint(
          'No se pudo guardar la notificación de la insignia $badgeId.',
        );
      }
    }
  }
}
