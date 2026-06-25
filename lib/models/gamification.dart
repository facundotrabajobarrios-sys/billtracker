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

  // 📤 Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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

  // 🏆 Calcular nivel basado en puntos
  int calculateLevel(int points) {
    if (points < 100) return 1;
    if (points < 300) return 2;
    if (points < 600) return 3;
    if (points < 1000) return 4;
    if (points < 1500) return 5;
    if (points < 2100) return 6;
    if (points < 2800) return 7;
    return 8;
  }

  // 🏅 Insignias disponibles
  static List<Badge> getAvailableBadges() {
    return [
      Badge(
        id: 'first_payment',
        name: 'Primer Pago',
        description: '¡Pagaste tu primera factura!',
        icon: '🎉',
        requirement: 'Pagar 1 factura',
      ),
      Badge(
        id: 'on_time_3',
        name: 'Puntual',
        description: '3 pagos a tiempo consecutivos',
        icon: '⏰',
        requirement: '3 pagos a tiempo seguidos',
      ),
      Badge(
        id: 'on_time_7',
        name: 'Súper Puntual',
        description: '7 pagos a tiempo consecutivos',
        icon: '⭐',
        requirement: '7 pagos a tiempo seguidos',
      ),
      Badge(
        id: 'on_time_30',
        name: 'Leyenda',
        description: '30 pagos a tiempo consecutivos',
        icon: '👑',
        requirement: '30 pagos a tiempo seguidos',
      ),
      Badge(
        id: 'paid_10',
        name: 'Experto en Pagos',
        description: '10 facturas pagadas',
        icon: '💰',
        requirement: 'Pagar 10 facturas',
      ),
      Badge(
        id: 'paid_50',
        name: 'Maestro Financiero',
        description: '50 facturas pagadas',
        icon: '💎',
        requirement: 'Pagar 50 facturas',
      ),
      Badge(
        id: 'no_overdue_30',
        name: 'Sin Retrasos',
        description: '30 días sin facturas vencidas',
        icon: '🏆',
        requirement: '30 días sin vencimientos',
      ),
    ];
  }

  // 🎯 Verificar si una insignia está desbloqueada
  bool hasBadge(String badgeId) {
    return unlockedBadges.contains(badgeId);
  }

  // 📊 Progreso al siguiente nivel
  int get pointsToNextLevel {
    final nextLevel = currentLevel + 1;
    final pointsNeeded = _pointsForLevel(nextLevel);
    return pointsNeeded - totalPoints;
  }

  int _pointsForLevel(int level) {
    // Fórmula: nivel 1 = 0pts, nivel 2 = 100pts, nivel 3 = 300pts, etc.
    if (level <= 1) return 0;
    return level * level * 25; // 1:25, 2:100, 3:225, 4:400...
  }
}

// 🏅 Modelo de Insignia
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String requirement;
  final bool isUnlocked;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requirement,
    this.isUnlocked = false,
  });

  // Crear copia con estado desbloqueado
  Badge copyWith({bool? isUnlocked}) {
    return Badge(
      id: id,
      name: name,
      description: description,
      icon: icon,
      requirement: requirement,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}
