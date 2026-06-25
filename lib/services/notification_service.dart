import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/notification.dart';
import '../config/supabase_config.dart';

// 🔔 Servicio de notificaciones
class NotificationService {
  // 📦 Instancia única (Singleton)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 🔗 Conexión a Supabase
  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  // 📥 Obtener todas las notificaciones del usuario
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response != null && response is List) {
        return response
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener notificaciones: $e');
      return [];
    }
  }

  // 📥 Obtener notificaciones no leídas
  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      if (response != null && response is List) {
        return response
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener notificaciones no leídas: $e');
      return [];
    }
  }

  // 📝 Crear una notificación
  Future<NotificationModel?> createNotification(
    NotificationModel notification,
  ) async {
    try {
      final response = await _client
          .from('notifications')
          .insert(notification.toJson())
          .select()
          .single();

      return NotificationModel.fromJson(response);
    } catch (e) {
      print('❌ Error al crear notificación: $e');
      return null;
    }
  }

  // ✅ Marcar notificación como leída
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      print('❌ Error al marcar notificación como leída: $e');
      return false;
    }
  }

  // ✅ Marcar todas como leídas
  Future<bool> markAllAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('❌ Error al marcar todas como leídas: $e');
      return false;
    }
  }

  // 🗑️ Eliminar notificación
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
      return true;
    } catch (e) {
      print('❌ Error al eliminar notificación: $e');
      return false;
    }
  }

  // 🔔 Crear notificación de recordatorio para una factura
  Future<void> createBillReminder(
    String userId,
    String billId,
    String title,
    String message,
  ) async {
    final notification = NotificationModel(
      id: '',
      userId: userId,
      billId: billId,
      title: title,
      message: message,
      type: 'reminder',
    );
    await createNotification(notification);
  }

  // 📊 Contar notificaciones no leídas
  Future<int> countUnread(String userId) async {
    try {
      final notifications = await getUnreadNotifications(userId);
      return notifications.length;
    } catch (e) {
      return 0;
    }
  }
}
