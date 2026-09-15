import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<String?> _getCurrentUserId() async {
    try {
      final userResponse = await _client.auth.getUser();
      final sessionUserId = userResponse.user?.id;
      if (sessionUserId != null && sessionUserId.isNotEmpty) {
        return sessionUserId;
      }
    } catch (e) {
      print('❌ Error al obtener el usuario autenticado: $e');
    }

    final sessionUserId = _client.auth.currentSession?.user.id;
    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      return sessionUserId;
    }

    return null;
  }

  Future<List<NotificationModel>> getNotifications(String? userId) async {
    try {
      final resolvedUserId = userId ?? await _getCurrentUserId();
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para cargar notificaciones',
        );
      }

      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', resolvedUserId)
          .order('created_at', ascending: false);

      return response.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener notificaciones: $e');
      return [];
    }
  }

  Future<List<NotificationModel>> getUnreadNotifications(String? userId) async {
    try {
      final resolvedUserId = userId ?? await _getCurrentUserId();
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para cargar notificaciones',
        );
      }

      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', resolvedUserId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return response.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener notificaciones no leídas: $e');
      return [];
    }
  }

  // ✅ CREAR NOTIFICACIÓN - CORREGIDO
  Future<NotificationModel?> createNotification(
    NotificationModel notification,
  ) async {
    try {
      final resolvedUserId = notification.userId.isNotEmpty
          ? notification.userId
          : await _getCurrentUserId();

      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para crear notificaciones',
        );
      }

      final payload = notification.toJson();
      payload['user_id'] = resolvedUserId;

      final response = await _client
          .from('notifications')
          .insert(payload)
          .select()
          .single();

      return NotificationModel.fromJson(response);
    } catch (e) {
      print('❌ Error al crear notificación: $e');
      return null;
    }
  }

  Future<bool> markAsRead(String notificationId, {String? userId}) async {
    try {
      final resolvedUserId = userId ?? await _getCurrentUserId();
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para marcar notificaciones',
        );
      }

      final response = await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', resolvedUserId)
          .select();

      final updatedCount = response.length;
      print('📝 Notificaciones marcadas como leídas: $updatedCount');
      return updatedCount > 0;
    } catch (e) {
      print('❌ Error al marcar notificación como leída: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String? userId) async {
    try {
      final resolvedUserId = userId ?? await _getCurrentUserId();
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para marcar notificaciones',
        );
      }

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', resolvedUserId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('❌ Error al marcar todas como leídas: $e');
      return false;
    }
  }

  // ✅ ELIMINAR NOTIFICACIÓN - CORREGIDO
  Future<bool> deleteNotification(
    String notificationId, {
    String? userId,
  }) async {
    try {
      if (notificationId.isEmpty) {
        print('⚠️ ID de notificación vacío, no se puede eliminar');
        return false;
      }

      final resolvedUserId = userId ?? await _getCurrentUserId();
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        throw Exception(
          'No hay un usuario autenticado para eliminar notificaciones',
        );
      }

      final response = await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', resolvedUserId)
          .select();

      final deletedCount = response.length;
      print(
        '🗑️ Notificación eliminada: $notificationId (filas: $deletedCount)',
      );
      return deletedCount > 0;
    } catch (e) {
      print('❌ Error al eliminar notificación: $e');
      return false;
    }
  }

  // ✅ CREAR RECORDATORIO - CORREGIDO
  Future<NotificationModel?> createBillReminder(
    String userId,
    String? billId,
    String title,
    String message,
  ) async {
    final notification = NotificationModel(
      id: '', // ← Supabase generará el ID
      userId: userId,
      billId: billId,
      title: title,
      message: message,
      type: 'reminder',
    );
    return await createNotification(
      notification,
    ); // ✅ Devuelve la notificación con ID
  }

  Future<int> countUnread(String userId) async {
    try {
      final notifications = await getUnreadNotifications(userId);
      return notifications.length;
    } catch (e) {
      return 0;
    }
  }
}
