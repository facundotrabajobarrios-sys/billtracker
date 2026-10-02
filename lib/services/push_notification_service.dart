import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'bill_service.dart';
import '../models/bill.dart';

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _androidNotificationChannel = MethodChannel(
    'billtracker/notifications',
  );
  final BillService _billService = BillService();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingPayload;
  bool _isInitialized = false;
  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (!_isSupportedPlatform) {
      return;
    }
    if (_isInitialized) {
      _navigatorKey = navigatorKey ?? _navigatorKey;
      return;
    }

    _navigatorKey = navigatorKey ?? _navigatorKey;
    tz.initializeTimeZones();

    const androidInitializationSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response.payload);
      },
    );

    await _pendingNotificationRequestsWithRepair();
    await _requestPermissions();

    _isInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handlePendingPayload(),
    );
  }

  Future<List<PendingNotificationRequest>>
  _pendingNotificationRequestsWithRepair() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } on PlatformException catch (error) {
      if (defaultTargetPlatform != TargetPlatform.android ||
          !error.message.toString().contains('Missing type parameter')) {
        rethrow;
      }
      debugPrint(
        'Se detectaron recordatorios Android incompatibles; se limpiarán y '
        'se recuperarán desde las facturas guardadas: $error',
      );
      await _androidNotificationChannel.invokeMethod<void>(
        'repairScheduledNotifications',
      );
      return _notifications.pendingNotificationRequests();
    }
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _ensureAndroidSchedulePermissions();
    const androidChannel = AndroidNotificationDetails(
      'billtracker_channel',
      'BillTracker',
      channelDescription: 'Recordatorios de pago de BillTracker',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(
      android: androidChannel,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleBillReminder(Bill bill) async {
    final notificationId = generateId(bill.id);
    await cancelNotification(notificationId);
    if (bill.status != 'pending' || !bill.reminderPushEnabled) return;

    final reminderDate = _reminderDateFor(bill);
    if (!reminderDate.isAfter(DateTime.now())) return;

    await scheduleNotification(
      id: notificationId,
      title: '📋 Recordatorio de pago',
      body:
          '${bill.service?.name ?? 'Factura'} · ${bill.formattedAmount} · '
          'vence ${bill.formattedDueDate}'
          '${bill.category?.name == null ? '' : ' · ${bill.category!.name}'}',
      scheduledDate: reminderDate,
      payload: bill.id,
    );
  }

  DateTime _reminderDateFor(Bill bill) {
    return bill.reminderAt?.toLocal() ??
        bill.dueDate
            .subtract(Duration(days: bill.reminderDays ?? 3))
            .copyWith(
              hour: bill.reminderTimeMinutes ~/ 60,
              minute: bill.reminderTimeMinutes % 60,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
  }

  Future<void> reconcileBillReminders(Iterable<Bill> bills) async {
    if (!_isSupportedPlatform) return;

    final billsList = bills.toList();
    final eligibleBills = billsList
        .where(
          (bill) =>
              bill.status == 'pending' &&
              bill.reminderPushEnabled &&
              _reminderDateFor(bill).isAfter(DateTime.now()),
        )
        .toList();
    if (eligibleBills.isNotEmpty) {
      await _ensureAndroidSchedulePermissions();
    }
    final pending = await _pendingNotificationRequestsWithRepair();
    final billsById = {for (final bill in billsList) bill.id: bill};
    final eligibleIds = eligibleBills.map((bill) => bill.id).toSet();
    final pendingIds = <int>{};
    for (final request in pending) {
      final billId = request.payload;
      final bill = billId == null ? null : billsById[billId];
      if (bill == null) continue;

      final expectedId = generateId(bill.id);
      if (!eligibleIds.contains(bill.id)) {
        await cancelNotification(request.id);
      } else if (request.id != expectedId) {
        await cancelNotification(request.id);
      } else {
        pendingIds.add(request.id);
      }
    }

    for (final bill in eligibleBills) {
      final id = generateId(bill.id);
      if (pendingIds.contains(id)) continue;
      await scheduleBillReminder(bill);
    }
  }

  Future<void> _ensureAndroidSchedulePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final androidNotifications = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidNotifications == null) {
      throw StateError('No se pudo inicializar el servicio de notificaciones.');
    }

    var notificationsEnabled =
        await androidNotifications.areNotificationsEnabled() ?? false;
    if (!notificationsEnabled) {
      notificationsEnabled =
          await androidNotifications.requestNotificationsPermission() ?? false;
    }
    if (!notificationsEnabled) {
      throw StateError(
        'Android no tiene permiso para mostrar notificaciones de BillTracker.',
      );
    }

    var exactAlarmsEnabled =
        await androidNotifications.canScheduleExactNotifications() ?? false;
    if (!exactAlarmsEnabled) {
      await androidNotifications.requestExactAlarmsPermission();
      exactAlarmsEnabled =
          await androidNotifications.canScheduleExactNotifications() ?? false;
    }
    if (!exactAlarmsEnabled) {
      throw StateError(
        'Habilita las alarmas exactas de BillTracker en los ajustes de Android.',
      );
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }
    const androidChannel = AndroidNotificationDetails(
      'billtracker_channel',
      'BillTracker',
      channelDescription: 'Notificaciones inmediatas de BillTracker',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(
      android: androidChannel,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isSupportedPlatform) {
      return [];
    }
    return _pendingNotificationRequestsWithRepair();
  }

  int generateId(String billId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in billId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _handleNotificationResponse(String? payload) async {
    if (payload == null || payload.isEmpty) {
      return;
    }

    _pendingPayload = payload;
    await _handlePendingPayload();
  }

  Future<void> _handlePendingPayload() async {
    final payload = _pendingPayload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final navigatorContext = _navigatorKey?.currentContext;
    if (navigatorContext == null) {
      return;
    }

    _pendingPayload = null;

    if (!navigatorContext.mounted) {
      return;
    }

    final bill = await _billService.getBillById(payload);
    if (!navigatorContext.mounted) {
      return;
    }

    if (bill != null) {
      await Navigator.of(
        navigatorContext,
      ).pushNamed('/bill-detail', arguments: bill);
    } else {
      await Navigator.of(navigatorContext).pushNamed('/home');
    }
  }
}
