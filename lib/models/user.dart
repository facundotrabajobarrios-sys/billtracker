import 'gamification.dart';

// Modelo de Usuario para BillTracker
class User {
  final String id;
  final String email;
  final String? name;
  final int? level;
  final int? points;
  final DateTime? createdAt;
  final Gamification? gamification;

  User({
    required this.id,
    required this.email,
    this.name,
    this.level = 0,
    this.points = 0,
    this.createdAt,
    this.gamification,
  });

  // 🔄 Crear desde JSON (viene de Supabase)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'Usuario',
      level: json['level'] ?? 0,
      points: json['points'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      gamification: json['gamification'] != null
          ? Gamification.fromJson(json['gamification'])
          : null,
    );
  }

  // 📤 Convertir a JSON (para enviar a Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'level': level,
      'points': points,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
