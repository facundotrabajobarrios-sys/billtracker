import 'package:flutter/material.dart';

// 🏆 Modelo de Gamificación
class Gamification {
  final String id;
  final String userId;
  final int totalPoints;
  final int currentLevel;
  final int streakDays; // Días seguidos pagando a tiempo
  final int totalPaidBills;
  final int onTimePayments;
  final List<String> unlockedBadges;
  final DateTime? lastPaymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Gamification({
    required this.id,
    required this.userId,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.streakDays = 0,
    this.totalPaidBills = 0,
    this.onTimePayments = 0,
    this.unlockedBadges = const [],
    this.lastPaymentDate,
    this.createdAt,
    this.updatedAt,
  });

  // 📥 Crear desde JSON
  factory Gamification.fromJson(Map<String, dynamic> json) {
    return Gamification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      totalPoints: json['total_points'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      streakDays: json['streak_days'] ?? 0,
      totalPaidBills: json['total_paid_bills'] ?? 0,
      onTimePayments: json['on_time_payments'] ?? 0,
      unlockedBadges: json['unlocked_badges'] is List
          ? List<String>.from(json['unlocked_badges'])
          : [],
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // 📤 Convertir a JSON ← 🔧 CORREGIDO
  Map<String, dynamic> toJson() {
    return {
      // ✅ SOLO enviar ID si NO está vacío
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'total_points': totalPoints,
      'current_level': currentLevel,
      'streak_days': streakDays,
      'total_paid_bills': totalPaidBills,
      'on_time_payments': onTimePayments,
      'unlocked_badges': unlockedBadges,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // 📋 Crear gamificación inicial para nuevo usuario
  static Gamification createInitial(String userId) {
    return Gamification(
      id: '',
      userId: userId,
      totalPoints: 0,
      currentLevel: 1,
      streakDays: 0,
      totalPaidBills: 0,
      onTimePayments: 0,
      unlockedBadges: [],
    );
  }

  // 🏆 Calcular nivel basado en puntos
  static int calculateLevel(int points) {
    if (points < 100) return 1;
    if (points < 300) return 2;
    if (points < 600) return 3;
    if (points < 1000) return 4;
    if (points < 1500) return 5;
    if (points < 2100) return 6;
    if (points < 2800) return 7;
    return 8;
  }

  // 🏅 Obtener nombre del nivel
  static String getLevelName(int level) {
    const levels = {
      1: '🌱 Novato',
      2: '📊 Aprendiz',
      3: '💪 Esforzado',
      4: '🎯 Organizado',
      5: '⭐ Confiable',
      6: '🏅 Experto',
      7: '💎 Maestro',
      8: '👑 Leyenda',
    };
    return levels[level] ?? '🌱 Novato';
  }

  // 📊 Progreso al siguiente nivel
  int get pointsToNextLevel {
    final nextLevel = currentLevel + 1;
    final pointsNeeded = _pointsForLevel(nextLevel);
    return pointsNeeded - totalPoints;
  }

  int _pointsForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * 100 + ((level - 1) * (level - 2) * 50) ~/ 2;
  }

  // 📊 Porcentaje de progreso al siguiente nivel
  double get progressToNextLevel {
    final currentLevelPoints = _pointsForLevel(currentLevel);
    final nextLevelPoints = _pointsForLevel(currentLevel + 1);
    if (nextLevelPoints == currentLevelPoints) return 1.0;
    return (totalPoints - currentLevelPoints) /
        (nextLevelPoints - currentLevelPoints);
  }

  // 🏅 Insignias disponibles
  static List<AchievementBadge> getAvailableBadges() {
    return [
      AchievementBadge(
        id: 'first_payment',
        name: 'Primer Pago',
        description: '¡Pagaste tu primera factura!',
        icon: '🎉',
        requirement: 'Pagar 1 factura',
        color: '#FF6B6B',
      ),
      AchievementBadge(
        id: 'on_time_3',
        name: 'Puntual',
        description: '3 pagos a tiempo consecutivos',
        icon: '⏰',
        requirement: '3 pagos a tiempo seguidos',
        color: '#4ECDC4',
      ),
      AchievementBadge(
        id: 'on_time_7',
        name: 'Súper Puntual',
        description: '7 pagos a tiempo consecutivos',
        icon: '⭐',
        requirement: '7 pagos a tiempo seguidos',
        color: '#45B7D1',
      ),
      AchievementBadge(
        id: 'on_time_30',
        name: 'Leyenda de la Puntualidad',
        description: '30 pagos a tiempo consecutivos',
        icon: '👑',
        requirement: '30 pagos a tiempo seguidos',
        color: '#FFD700',
      ),
      AchievementBadge(
        id: 'paid_10',
        name: 'Experto en Pagos',
        description: '10 facturas pagadas',
        icon: '💰',
        requirement: 'Pagar 10 facturas',
        color: '#96CEB4',
      ),
      AchievementBadge(
        id: 'paid_50',
        name: 'Maestro Financiero',
        description: '50 facturas pagadas',
        icon: '💎',
        requirement: 'Pagar 50 facturas',
        color: '#DDA0DD',
      ),
      AchievementBadge(
        id: 'no_overdue_30',
        name: 'Sin Retrasos',
        description: '30 días sin facturas vencidas',
        icon: '🏆',
        requirement: '30 días sin vencimientos',
        color: '#FFD700',
      ),
    ];
  }

  // 🎯 Verificar si una insignia está desbloqueada
  bool hasBadge(String badgeId) {
    return unlockedBadges.contains(badgeId);
  }

  // 🎯 Obtener insignias desbloqueadas
  List<AchievementBadge> getUnlockedBadges() {
    final allBadges = Gamification.getAvailableBadges();
    return allBadges.where((b) => unlockedBadges.contains(b.id)).toList();
  }

  // 🎯 Obtener insignias bloqueadas
  List<AchievementBadge> getLockedBadges() {
    final allBadges = Gamification.getAvailableBadges();
    return allBadges.where((b) => !unlockedBadges.contains(b.id)).toList();
  }

  // 📋 Copia con cambios (para actualizar)
  Gamification copyWith({
    String? id,
    String? userId,
    int? totalPoints,
    int? currentLevel,
    int? streakDays,
    int? totalPaidBills,
    int? onTimePayments,
    List<String>? unlockedBadges,
    DateTime? lastPaymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Gamification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      currentLevel: currentLevel ?? this.currentLevel,
      streakDays: streakDays ?? this.streakDays,
      totalPaidBills: totalPaidBills ?? this.totalPaidBills,
      onTimePayments: onTimePayments ?? this.onTimePayments,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// 🏅 Modelo de Insignia
class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String requirement;
  final String color;
  final bool isUnlocked;

  AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requirement,
    this.color = '#4CAF50',
    this.isUnlocked = false,
  });

  // Crear copia con estado desbloqueado
  AchievementBadge copyWith({bool? isUnlocked}) {
    return AchievementBadge(
      id: id,
      name: name,
      description: description,
      icon: icon,
      requirement: requirement,
      color: color,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  // Color como Color de Flutter
  Color get colorValue {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.green;
    }
  }
}
