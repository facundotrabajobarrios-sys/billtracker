import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';

// 🔔 Pantalla de notificaciones
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // 📥 Cargar notificaciones
  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() => _isLoading = true);
    }

    final freshNotifications = await _notificationService.getNotifications(
      null,
    );
    if (!mounted) return;
    setState(() {
      _notifications = freshNotifications;
    });

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ✅ Marcar como leída
  Future<void> _markAsRead(String notificationId) async {
    final success = await _notificationService.markAsRead(notificationId);

    if (success) {
      await _loadNotifications();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo marcar la notificación como leída'),
        ),
      );
    }
  }

  // ✅ Marcar todas como leídas
  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead(null);
    await _loadNotifications();
  }

  // 🗑️ Eliminar notificación
  Future<void> _deleteNotification(String notificationId) async {
    final previousNotifications = List<NotificationModel>.from(_notifications);
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });

    final success = await _notificationService.deleteNotification(
      notificationId,
    );

    if (!success) {
      if (!mounted) return;
      setState(() {
        _notifications = previousNotifications;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la notificación')),
      );
    } else {
      await _loadNotifications(showLoading: false);
    }
  }

  // 🎨 Color según tipo
  Color _getTypeColor(String type) {
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

  // 🎨 Icono según tipo
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'reminder':
        return Icons.notifications_active;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Marcar todas como leídas',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        // ✅ PULL-TO-REFRESH
        onRefresh: _loadNotifications,
        color: Colors.green,
        backgroundColor: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return Card(
                    elevation: notification.isRead ? 0 : 2,
                    color: notification.isRead ? Colors.grey[50] : Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTypeColor(
                          notification.type,
                        ).withValues(alpha: 0.2),
                        child: Icon(
                          _getTypeIcon(notification.type),
                          color: _getTypeColor(notification.type),
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.message),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!notification.isRead)
                            IconButton(
                              icon: const Icon(Icons.mark_as_unread, size: 20),
                              onPressed: () => _markAsRead(notification.id),
                              tooltip: 'Marcar como leída',
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () =>
                                _deleteNotification(notification.id),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                      onTap: () => _markAsRead(notification.id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // 📄 Estado vacío
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Aquí aparecerán tus recordatorios y alertas',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 📅 Formatear fecha
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} días';
    } else if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} horas';
    } else if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} minutos';
    } else {
      return 'Ahora mismo';
    }
  }
}
