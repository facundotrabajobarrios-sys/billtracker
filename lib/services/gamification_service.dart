import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/gamification.dart';
import '../models/bill.dart';
import '../services/notification_service.dart';
import '../config/supabase_config.dart';

// 🏆 Servicio de Gamificación
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

      if (response != null) {
        return Gamification.fromJson(response);
      }

      // Si no existe, crear una nueva
      return await _createInitialGamification(userId);
    } catch (e) {
      print('❌ Error al obtener gamificación: $e');
      return null;
    }
  }

  // 📝 Crear gamificación inicial
  Future<Gamification?> _createInitialGamification(String userId) async {
    try {
      final initial = Gamification.createInitial(userId);
      final response = await _client
          .from('gamifications')
          .insert(initial.toJson())
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
  Future<Gamification?> processPayment(
    String userId,
    Bill bill,
    bool wasOnTime,
  ) async {
    try {
      // Obtener gamificación actual
      final current = await getGamification(userId);
      if (current == null) return null;

      // Calcular puntos
      int pointsToAdd = 10; // Base por pagar

      // Bonus por pago a tiempo
      if (wasOnTime) {
        pointsToAdd += 5; // Bonus extra
      }

      // Bonus por racha
      final today = DateTime.now();
      final lastPayment = current.lastPaymentDate;
      if (lastPayment != null) {
        final diff = today.difference(lastPayment).inDays;
        if (diff <= 1) {
          // Pago consecutivo
          pointsToAdd += 5;
        }
      }

      // Nuevos valores
      final newPoints = current.totalPoints + pointsToAdd;
      final newLevel = Gamification.calculateLevel(newPoints);
      final newStreak = _calculateStreak(current, wasOnTime);
      final newPaidBills = current.totalPaidBills + 1;
      final newOnTime = current.onTimePayments + (wasOnTime ? 1 : 0);

      // Verificar insignias desbloqueadas
      final newBadges = _checkUnlockedBadges(
        current.unlockedBadges,
        newPaidBills,
        newStreak,
        current.streakDays,
      );

      // Crear versión actualizada
      final updated = current.copyWith(
        totalPoints: newPoints,
        currentLevel: newLevel,
        streakDays: newStreak,
        totalPaidBills: newPaidBills,
        onTimePayments: newOnTime,
        unlockedBadges: newBadges,
        lastPaymentDate: today,
        updatedAt: today,
      );

      // Guardar en Supabase
      return await updateGamification(updated);
    } catch (e) {
      print('❌ Error al procesar pago: $e');
      return null;
    }
  }

  // 📊 Calcular racha
  int _calculateStreak(Gamification current, bool wasOnTime) {
    if (!wasOnTime) return 0;

    final today = DateTime.now();
    final lastPayment = current.lastPaymentDate;

    if (lastPayment == null) return 1;

    final diff = today.difference(lastPayment).inDays;
    if (diff <= 1) {
      return current.streakDays + 1;
    }
    return 1;
  }

  // 🏅 Verificar insignias desbloqueadas
  List<String> _checkUnlockedBadges(
    List<String> currentBadges,
    int totalPaid,
    int streak,
    int previousStreak,
  ) {
    final newBadges = List<String>.from(currentBadges);

    // Lista de verificaciones
    final checks = [
      {'id': 'first_payment', 'condition': totalPaid >= 1},
      {'id': 'on_time_3', 'condition': streak >= 3},
      {'id': 'on_time_7', 'condition': streak >= 7},
      {'id': 'on_time_30', 'condition': streak >= 30},
      {'id': 'paid_10', 'condition': totalPaid >= 10},
      {'id': 'paid_50', 'condition': totalPaid >= 50},
    ];

    for (final check in checks) {
      final id = check['id'] as String;
      final condition = check['condition'] as bool;
      if (condition && !newBadges.contains(id)) {
        newBadges.add(id);
      }
    }

    return newBadges;
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

      await notificationService.createBillReminder(
        userId,
        '',
        '🎉 ¡Nueva Insignia Desbloqueada!',
        'Has obtenido "${badge.name}" - ${badge.description}',
      );
    }
  }
}
