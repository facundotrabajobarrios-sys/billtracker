import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'push_notification_service.dart';

class NotificationTestResult {
  const NotificationTestResult({
    required this.inAppError,
    required this.emailError,
    required this.pushError,
  });

  final String? inAppError;
  final String? emailError;
  final String? pushError;
}

class NotificationTestService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get _supportsLocalPush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<NotificationTestResult> sendAll(String userId) async {
    final authenticatedUserId = _client.auth.currentUser?.id;
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      throw StateError('Inicia sesión para probar las notificaciones.');
    }

    String? inAppError;
    String? emailError;
    String? pushError;

    try {
      final notification = await NotificationService().createTestNotification(
        userId,
      );
      if (notification == null) {
        throw StateError('No se pudo guardar la notificación en BillTracker.');
      }
    } on Object catch (error) {
      inAppError = error.toString();
    }

    try {
      await _client.functions.invoke('send-test-notification');
    } on FunctionException catch (error) {
      final details = error.details;
      emailError = details is Map && details['error'] is String
          ? details['error'] as String
          : 'No se pudo enviar el correo de prueba.';
    } on Object catch (error) {
      emailError = error.toString();
    }

    if (_supportsLocalPush) {
      try {
        await PushNotificationService().showImmediateNotification(
          title: 'Prueba de notificación',
          body: 'Las notificaciones de BillTracker están funcionando.',
        );
      } on Object catch (error) {
        pushError = error.toString();
      }
    }

    return NotificationTestResult(
      inAppError: inAppError,
      emailError: emailError,
      pushError: pushError,
    );
  }
}
