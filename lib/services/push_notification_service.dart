import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'bill_service.dart';

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final BillService _billService = BillService();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingPayload;
  bool _isInitialized = false;

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (kIsWeb || isDesktop) {
      _navigatorKey = navigatorKey ?? _navigatorKey;
      _isInitialized = true;
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

    await _requestPermissions();

    final appLaunchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    if (appLaunchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = appLaunchDetails!.notificationResponse?.payload;
    }

    _isInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handlePendingPayload(),
    );
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

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
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
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }

  int generateId(String billId) {
    return billId.hashCode;
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
