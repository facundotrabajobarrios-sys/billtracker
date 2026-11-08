import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'models/bill.dart';
import 'providers/auth_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/add_bill_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/auth_callback_screen.dart';
import 'screens/admin_screen.dart';
import 'config/supabase_config.dart';
import 'services/push_notification_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_navigator.dart';

bool _initialPasswordRecoveryLink = false;

Future<void> _exchangeWebAuthCode() async {
  if (!kIsWeb ||
      (!Uri.base.path.endsWith('/auth/callback') &&
          !Uri.base.path.endsWith('/auth/reset-password'))) {
    return;
  }

  try {
    final fragment = Uri.base.fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(Uri.base.fragment);
    final parameters = {...Uri.base.queryParameters, ...fragment};
    final auth = Supabase.instance.client.auth;
    final code = parameters['code'];
    if (code != null) {
      final response = await auth.exchangeCodeForSession(code);
      if (response.redirectType == AuthChangeEvent.passwordRecovery.name ||
          parameters['type'] == 'recovery') {
        _initialPasswordRecoveryLink = true;
      }
      return;
    }

    final tokenHash = parameters['token_hash'];
    if (parameters['type'] == 'recovery' && tokenHash != null) {
      await auth.verifyOTP(tokenHash: tokenHash, type: OtpType.recovery);
      _initialPasswordRecoveryLink = true;
      return;
    }

    final accessToken = parameters['access_token'];
    final refreshToken = parameters['refresh_token'];
    if (parameters['type'] == 'recovery' &&
        accessToken != null &&
        refreshToken != null) {
      await auth.setSession(refreshToken, accessToken: accessToken);
      _initialPasswordRecoveryLink = true;
    }
  } catch (error) {
    debugPrint('Error procesando el enlace de recuperación: $error');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await _exchangeWebAuthCode();

  final supportsLocalNotifications =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  runApp(const MyApp());

  if (supportsLocalNotifications) {
    unawaited(_initializeMobileServices());
  }
}

Future<void> _initializeMobileServices() async {
  try {
    await _initAuthDeepLinks();
  } catch (error, stackTrace) {
    debugPrint(
      'No se pudieron inicializar los enlaces de autenticación: '
      '$error\n$stackTrace',
    );
  }

  try {
    await PushNotificationService().init(navigatorKey: navigatorKey);
  } catch (error, stackTrace) {
    debugPrint(
      'No se pudo inicializar las notificaciones del dispositivo: '
      '$error\n$stackTrace',
    );
  }
}

Future<void> _initAuthDeepLinks() async {
  final appLinks = AppLinks();

  Future<void> exchange(Uri? uri) async {
    if (uri == null) return;
    final fragment = uri.fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    final parameters = {...fragment, ...uri.queryParameters};
    var isRecovery = parameters['type'] == 'recovery';
    void markRecovery() {
      _initialPasswordRecoveryLink = true;
      final context = navigatorKey.currentContext;
      if (context != null) {
        context.read<AuthProvider>().markPasswordRecovery();
      }
    }

    if (isRecovery) markRecovery();

    final client = Supabase.instance.client.auth;
    final code = parameters['code'];
    if (code != null) {
      final response = await client.exchangeCodeForSession(code);
      if (response.redirectType == AuthChangeEvent.passwordRecovery.name) {
        isRecovery = true;
        markRecovery();
      }
      return;
    }

    final tokenHash = parameters['token_hash'];
    if (isRecovery && tokenHash != null) {
      await client.verifyOTP(tokenHash: tokenHash, type: OtpType.recovery);
      return;
    }

    final accessToken = parameters['access_token'];
    final refreshToken = parameters['refresh_token'];
    if (isRecovery && accessToken != null && refreshToken != null) {
      await client.setSession(refreshToken, accessToken: accessToken);
    }
  }

  try {
    await exchange(await appLinks.getInitialLink());
  } catch (error) {
    debugPrint('Error procesando el enlace de autenticación: $error');
  }
  appLinks.uriLinkStream.listen(
    (uri) async {
      try {
        await exchange(uri);
      } catch (error) {
        debugPrint('Error procesando el enlace de autenticación: $error');
      }
    },
    onError: (Object error) {
      debugPrint('Error leyendo deep link de autenticación: $error');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(isPasswordRecovery: _initialPasswordRecoveryLink)
                ..loadUser(),
        ),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          if (authProvider.isInitializing || !themeProvider.isLoaded) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
              debugShowCheckedModeBanner: false,
            );
          }

          final bool isAuth = authProvider.isAuthenticated;
          final bool isWebCallback =
              kIsWeb && Uri.base.path.endsWith('/auth/callback');
          final bool isWebPasswordRecovery =
              kIsWeb && Uri.base.path.endsWith('/auth/reset-password');

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'BillTracker',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home:
                authProvider.isPasswordRecovery ||
                    (isWebPasswordRecovery && !isAuth)
                ? const UpdatePasswordScreen()
                : isWebCallback
                ? const AuthCallbackScreen()
                : isAuth
                ? const AuthenticatedHomeScreen()
                : const LoginScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const AuthenticatedHomeScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/update-password': (context) => const UpdatePasswordScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/bill-detail': (context) {
                final bill =
                    ModalRoute.of(context)?.settings.arguments as Bill?;
                return AddBillScreen(bill: bill);
              },
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
