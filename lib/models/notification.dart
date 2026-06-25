import 'package:flutter/material.dart';

// 🔔 Modelo de Notificación
class NotificationModel {
  final String id;
  final String userId;
  final String? billId;
  final String title;
  final String message;
  final String type; // 'reminder', 'warning', 'success', 'info'
  final bool isRead;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.billId,
    required this.title,
    required this.message,
    this.type = 'info',
    this.isRead = false,
    this.scheduledAt,
    this.sentAt,
    this.createdAt,
  });

  // 📥 Crear desde JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      billId: json['bill_id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['is_read'] ?? false,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'])
          : null,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  // 📤 Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bill_id': billId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // 🎨 Color según tipo
  Color get typeColor {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'reminder':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
