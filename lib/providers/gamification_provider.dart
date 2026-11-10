import 'package:flutter/material.dart';
import '../models/gamification.dart';
import '../models/bill.dart';
import '../services/gamification_service.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationService _service = GamificationService();
  Gamification? _gamification;
  bool _isLoading = false;
  String? _loadError;
  List<String> _newBadges = [];
  bool _showCelebration = false;
  bool _showConfetti = false;

  Gamification? get gamification => _gamification;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  List<String> get newBadges => _newBadges;
  bool get showCelebration => _showCelebration;
  bool get showConfetti => _showConfetti;

  void refreshUi() {
    notifyListeners();
  }

  Future<void> loadGamification(String userId, {bool silent = false}) async {
    _loadError = null;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _gamification = await _service.getGamification(userId);
    } catch (error) {
      _loadError = error.toString();
      debugPrint('No se pudo cargar la gamificación: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Gamification?> processPayment(String userId, Bill bill) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final oldBadges = _gamification?.unlockedBadges ?? [];

      _gamification = await _service.processPayment(userId, bill);

      if (_gamification != null) {
        final newBadges = _gamification!.unlockedBadges;
        final unlocked = newBadges
            .where((b) => !oldBadges.contains(b))
            .toList();

        if (unlocked.isNotEmpty) {
          _newBadges = unlocked;
          _showCelebration = true;
          _showConfetti = true;
          print('🎉 Confeti activado para: ${unlocked.first}');
        } else {
          _newBadges = [];
          _showCelebration = false;
          _showConfetti = false;
        }
      }

      _isLoading = false;
      notifyListeners();
      return _gamification;
    } catch (error) {
      _loadError = error.toString();
      debugPrint('No se pudieron actualizar las recompensas: $error');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void setCelebrationState(List<String> unlockedBadges) {
    _newBadges = unlockedBadges;
    _showCelebration = unlockedBadges.isNotEmpty;
    _showConfetti = unlockedBadges.isNotEmpty;
    notifyListeners();
  }

  void resetCelebration() {
    _showCelebration = false;
    _newBadges = [];
    _showConfetti = false;
    notifyListeners();
  }

  void updateGamification(Gamification newGamification) {
    _gamification = newGamification;
    notifyListeners();
  }

  List<AchievementBadge> getBadgesWithStatus() {
    final allBadges = Gamification.getAvailableBadges();
    final unlocked = _gamification?.unlockedBadges ?? [];
    return allBadges.map((badge) {
      return badge.copyWith(isUnlocked: unlocked.contains(badge.id));
    }).toList();
  }

  List<AchievementBadge> getNewBadgeDetails() {
    final allBadges = Gamification.getAvailableBadges();
    return allBadges
        .where((b) => _newBadges.contains(b.id))
        .map((b) => b.copyWith(isUnlocked: true))
        .toList();
  }
}
