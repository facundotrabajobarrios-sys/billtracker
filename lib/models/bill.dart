import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'category.dart';
import 'service.dart';
import 'user.dart';

// 📄 Modelo de Factura
class Bill {
  final String id;
  final String userId;
  final String serviceId;
  final String categoryId;
  final double amount;
  final String currency;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // 'pending', 'paid', 'overdue'
  final String? description;
  final bool isRecurring;
  final int? reminderDays;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // 🔗 Relaciones (cargados desde la base de datos)
  Service? service;
  Category? category;
  User? user;

  Bill({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.categoryId,
    required this.amount,
    required this.dueDate,
    this.currency = 'PYG',
    this.paidDate,
    this.status = 'pending',
    this.description,
    this.isRecurring = false,
    this.reminderDays = 3,
    this.createdAt,
    this.updatedAt,
    this.service,
    this.category,
    this.user,
  });

  // 📥 Crear desde JSON
  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      serviceId: json['service_id'] ?? '',
      categoryId: json['category_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'PYG',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : DateTime.now(),
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'])
          : null,
      status: json['status'] ?? 'pending',
      description: json['description'],
      isRecurring: json['is_recurring'] ?? false,
      reminderDays: json['reminder_days'] ?? 3,
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
      // ✅ SOLO enviar ID si NO está vacío (Supabase genera UUID automáticamente)
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'service_id': serviceId,
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'due_date': dueDate.toIso8601String(),
      'paid_date': paidDate?.toIso8601String(),
      'status': status,
      'description': description,
      'is_recurring': isRecurring,
      'reminder_days': reminderDays,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ✅ Getters útiles
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue =>
      status == 'overdue' || (!isPaid && dueDate.isBefore(DateTime.now()));

  // 📊 Formatear monto
  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: '₲ ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // 📅 Formatear fecha
  String get formattedDueDate {
    return DateFormat('dd/MM/yyyy').format(dueDate);
  }

  // 📊 Días restantes
  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  // 🎨 Color según estado
  Color get statusColor {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // 📝 Texto de estado
  String get statusText {
    switch (status) {
      case 'paid':
        return 'Pagada ✅';
      case 'overdue':
        return 'Vencida ❌';
      default:
        return 'Pendiente ⏳';
    }
  }
}
