import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/gamification.dart';
import '../models/bill.dart';
import '../services/notification_service.dart';

// 🏆 Servicio de Gamificación
class GamificationSnapshot {
  const GamificationSnapshot({
    required this.totalPaidBills,
    required this.onTimePayments,
    required this.streakDays,
    required this.totalPoints,
    required this.lastPaymentDate,
    required this.unlockedBadges,
  });

  final int totalPaidBills;
  final int onTimePayments;
  final int streakDays;
  final int totalPoints;
  final DateTime? lastPaymentDate;
  final List<String> unlockedBadges;
}

class GamificationService {
  // 📦 Instancia única (Singleton)
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  // 🔗 Conexión a Supabase
  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  // 📥 Obtener gamificación del usuario
  Future<Gamification?> getGamification(String userId) async {
    try {
      final response = await _client
          .from('gamifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final gamification = response == null
          ? await _createInitialGamification(userId)
          : Gamification.fromJson(response);
      if (gamification == null) return null;
      return await _reconcileWithBills(gamification);
    } catch (e) {
      print('❌ Error al obtener gamificación: $e');
      return null;
    }
  }

  // 📝 Crear gamificación inicial
  Future<Gamification?> _createInitialGamification(String userId) async {
    try {
      final response = await _client
          .from('gamifications')
          .insert({
            'user_id': userId,
            'total_points': 0,
            'current_level': 1,
            'streak_days': 0,
            'total_paid_bills': 0,
            'on_time_payments': 0,
            'unlocked_badges': <String>[],
          })
          .select()
          .single();

      return Gamification.fromJson(response);
    } catch (e) {
      print('❌ Error al crear gamificación inicial: $e');
      return null;
    }
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
    try {
      if (bill.userId != userId) return null;
      final current = await getGamification(userId);
      return current;
    } catch (e) {
      print('❌ Error al procesar pago: $e');
      return null;
    }
  }

  Future<Gamification> _reconcileWithBills(Gamification current) async {
    final rows = await _client
        .from('bills')
        .select('id,status,due_date,paid_date')
        .eq('user_id', current.userId);
    final user = await _client
        .from('users')
        .select('created_at')
        .eq('id', current.userId)
        .maybeSingle();
    final snapshot = calculateSnapshot(
      List<Map<String, dynamic>>.from(rows),
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
    DateTime? registeredAt,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final seenIds = <String>{};
    final paid = <({DateTime? paidAt, bool onTime})>[];
    var paidCount = 0;
    var hasActiveOverdue = false;
    DateTime? latestLatePayment;
    for (final bill in bills) {
      final status = bill['status'];
      final dueAt = DateTime.tryParse(bill['due_date']?.toString() ?? '');
      final paidAt = DateTime.tryParse(bill['paid_date']?.toString() ?? '');
      if (status != 'paid' &&
          (status == 'overdue' ||
              (dueAt != null &&
                  DateTime(
                    dueAt.year,
                    dueAt.month,
                    dueAt.day,
                  ).isBefore(DateTime(today.year, today.month, today.day))))) {
        hasActiveOverdue = true;
      }
      if (status == 'paid' &&
          dueAt != null &&
          paidAt != null &&
          DateTime(
            paidAt.year,
            paidAt.month,
            paidAt.day,
          ).isAfter(DateTime(dueAt.year, dueAt.month, dueAt.day)) &&
          (latestLatePayment == null || paidAt.isAfter(latestLatePayment))) {
        latestLatePayment = paidAt;
      }
      if (status != 'paid') continue;
      final id = bill['id']?.toString();
      if (id != null && !seenIds.add(id)) continue;
      paidCount++;
      paid.add((
        paidAt: paidAt,
        onTime:
            paidAt != null &&
            dueAt != null &&
            !DateTime(
              paidAt.year,
              paidAt.month,
              paidAt.day,
            ).isAfter(DateTime(dueAt.year, dueAt.month, dueAt.day)),
      ));
    }
    paid.sort((a, b) {
      if (a.paidAt == null) return b.paidAt == null ? 0 : -1;
      if (b.paidAt == null) return 1;
      return a.paidAt!.compareTo(b.paidAt!);
    });

    var onTimePayments = 0;
    var streak = 0;
    var points = 0;
    var previousWasOnTime = false;
    DateTime? previousPaidAt;
    DateTime? lastPaymentDate;
    for (final payment in paid) {
      if (payment.paidAt != null) lastPaymentDate = payment.paidAt;
      points += 10;
      if (payment.onTime) {
        onTimePayments++;
        streak++;
        points += 5;
        if (previousWasOnTime &&
            previousPaidAt != null &&
            payment.paidAt != null &&
            payment.paidAt!.difference(previousPaidAt).inDays <= 1) {
          points += 5;
        }
      } else {
        streak = 0;
      }
      previousWasOnTime = payment.onTime;
      previousPaidAt = payment.paidAt;
    }

    final badges = <String>[
      if (paidCount >= 1) 'first_payment',
      if (streak >= 3) 'on_time_3',
      if (streak >= 7) 'on_time_7',
      if (streak >= 30) 'on_time_30',
      if (paidCount >= 10) 'paid_10',
      if (paidCount >= 50) 'paid_50',
      if (!hasActiveOverdue &&
          _hasThirtyOverdueFreeDays(registeredAt, latestLatePayment, today))
        'no_overdue_30',
    ];
    return GamificationSnapshot(
      totalPaidBills: paidCount,
      onTimePayments: onTimePayments,
      streakDays: streak,
      totalPoints: points,
      lastPaymentDate: lastPaymentDate,
      unlockedBadges: badges,
    );
  }

  static bool _hasThirtyOverdueFreeDays(
    DateTime? registeredAt,
    DateTime? latestLatePayment,
    DateTime today,
  ) {
    final start = latestLatePayment == null
        ? registeredAt
        : registeredAt == null || latestLatePayment.isAfter(registeredAt)
        ? latestLatePayment
        : registeredAt;
    if (start == null) return false;
    final startDate = DateTime(start.year, start.month, start.day);
    final currentDate = DateTime(today.year, today.month, today.day);
    return currentDate.difference(startDate).inDays >= 30;
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

      // ✅ Si no hay billId, pasar null
      await notificationService.createBillReminder(
        userId,
        null, // ✅ Pasar null en lugar de ''
        '🎉 ¡Nueva Insignia Desbloqueada!',
        'Has obtenido "${badge.name}" - ${badge.description}',
      );
      print('🔍 createBillReminder llamado con null');
    }
  }
}
