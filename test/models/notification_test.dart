import 'package:billtracker/models/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationModel', () {
    test('keeps announcement type and lets the database set timestamps', () {
      final notification = NotificationModel(
        id: '',
        userId: 'user-id',
        title: 'Aviso',
        message: 'Mensaje',
        type: 'announcement',
      );

      final json = notification.toJson();

      expect(json['type'], 'announcement');
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('sent_at'), isFalse);
      expect(json.containsKey('scheduled_at'), isFalse);
    });

    test(
      'serializes a level-up notification with the supported success type',
      () {
        final notification = NotificationModel(
          id: '',
          userId: 'user-id',
          title: '¡Subiste de nivel!',
          message: 'Nivel 2',
          type: 'success',
        );

        expect(notification.toJson()['type'], 'success');
      },
    );

    test('serializes a system notice for the notification history', () {
      final notification = NotificationModel(
        id: '',
        userId: 'user-id',
        title: 'Aviso del sistema',
        message: 'Mantenimiento programado',
        type: 'system',
      );

      expect(notification.toJson()['type'], 'system');
      expect(notification.typeColor, Colors.teal);
    });
  });
}
