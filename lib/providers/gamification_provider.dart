import 'package:flutter/material.dart';
import '../models/gamification.dart';
import '../models/bill.dart';
import '../services/gamification_service.dart';

// 🏆 Proveedor de Gamificación
class GamificationProvider extends ChangeNotifier {
  final GamificationService _service = GamificationService();
  Gamification? _gamification;
  bool _isLoading = false;

  Gamification? get gamification => _gamification;
  bool get isLoading => _isLoading;

  // 📥 Cargar gamificación
  Future<void> loadGamification(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _gamification = await _service.getGamification(userId);
    } catch (e) {
      print('❌ Error al cargar gamificación: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // 🎯 Procesar pago
  Future<Gamification?> processPayment(
    String userId,
    Bill bill,
    bool wasOnTime,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final oldBadges = _gamification?.unlockedBadges ?? [];

      _gamification = await _service.processPayment(userId, bill, wasOnTime);

      if (_gamification != null) {
        // Notificar nuevas insignias
        final newBadges = _gamification!.unlockedBadges;
        final unlocked = newBadges
            .where((b) => !oldBadges.contains(b))
            .toList();

        if (unlocked.isNotEmpty) {
          await _service.notifyNewBadges(userId, oldBadges, newBadges);
        }
      }

      _isLoading = false;
      notifyListeners();
      return _gamification;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // 🔄 Actualizar gamificación local
  void updateGamification(Gamification newGamification) {
    _gamification = newGamification;
    notifyListeners();
  }

  // 📊 Obtener insignias con estado
  List<AchievementBadge> getBadgesWithStatus() {
    // ✅ AchievementBadge
    final allBadges = Gamification.getAvailableBadges();
    final unlocked = _gamification?.unlockedBadges ?? [];

    return allBadges.map((badge) {
      return badge.copyWith(isUnlocked: unlocked.contains(badge.id));
    }).toList();
  }
}
