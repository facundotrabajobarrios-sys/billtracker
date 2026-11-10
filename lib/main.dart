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
bool _initialEmailChangeLink = false;
bool _initialEmailVerificationSuccess = false;
String? _webAuthError;

Future<void> _exchangeWebAuthCode() async {
  final isCallbackRoute = Uri.base.path.endsWith('/auth/callback');
  final isRecoveryRoute = Uri.base.path.endsWith('/auth/reset-password');
  if (!kIsWeb || (!isCallbackRoute && !isRecoveryRoute)) {
    return;
  }

  try {
    final fragment = Uri.base.fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(Uri.base.fragment);
    final parameters = {...Uri.base.queryParameters, ...fragment};
    final auth = Supabase.instance.client.auth;
    final linkError = parameters['error_description'] ?? parameters['error'];
    if (linkError != null) {
      _webAuthError = linkError;
      return;
    }

    final linkType = parameters['type'];
    final tokenHash = parameters['token_hash'] ?? parameters['token'];
    if (tokenHash != null) {
      if (linkType != 'recovery' &&
          linkType != 'signup' &&
          linkType != 'email_change') {
        _webAuthError = 'El tipo de enlace de autenticación no es válido.';
        return;
      }
      await auth.verifyOTP(
        tokenHash: tokenHash,
        type: switch (linkType) {
          'recovery' => OtpType.recovery,
          'email_change' => OtpType.emailChange,
          _ => OtpType.signup,
        },
      );
      _initialPasswordRecoveryLink = linkType == 'recovery';
      _initialEmailChangeLink = linkType == 'email_change';
      _initialEmailVerificationSuccess = linkType == 'signup';
      if (isRecoveryRoute &&
          (!_initialPasswordRecoveryLink || auth.currentSession == null)) {
        _webAuthError =
            'No se pudo validar el enlace de recuperación. Solicita uno nuevo.';
      }
      return;
    }

    final code = parameters['code'];
    if (code != null) {
      final response = await auth.exchangeCodeForSession(code);
      if (response.redirectType == AuthChangeEvent.passwordRecovery.name ||
          linkType == 'recovery') {
        _initialPasswordRecoveryLink = true;
      }
      _initialEmailChangeLink =
          response.redirectType == AuthChangeEvent.userUpdated.name ||
          linkType == 'email_change';
      _initialEmailVerificationSuccess =
          linkType == 'signup' ||
          (!_initialEmailChangeLink &&
              auth.currentUser?.emailConfirmedAt != null);
      if (isRecoveryRoute &&
          (!_initialPasswordRecoveryLink || auth.currentSession == null)) {
        _webAuthError =
            'No se pudo validar el enlace de recuperación. Solicita uno nuevo.';
      }
      return;
    }

    final accessToken = parameters['access_token'];
    final refreshToken = parameters['refresh_token'];
    if ((linkType == 'recovery' ||
            linkType == 'email_change' ||
            linkType == 'signup') &&
        accessToken != null &&
        refreshToken != null) {
      await auth.setSession(refreshToken, accessToken: accessToken);
      _initialPasswordRecoveryLink =
          linkType == 'recovery' && auth.currentSession != null;
      _initialEmailChangeLink = linkType == 'email_change';
      _initialEmailVerificationSuccess = linkType == 'signup';
      if (linkType == 'recovery' && !_initialPasswordRecoveryLink) {
        _webAuthError =
            'No se pudo validar el enlace de recuperación. Solicita uno nuevo.';
      }
      return;
    }

    if (isRecoveryRoute || isCallbackRoute) {
      _webAuthError =
          'El enlace no contiene una verificación válida. Solicita uno nuevo.';
    }
  } catch (error) {
    debugPrint('Error procesando el enlace de recuperación: $error');
    _webAuthError = error is AuthException
        ? _friendlyAuthError(error.message)
        : 'No se pudo validar el enlace. Puede haber vencido o ya haber sido utilizado.';
  }
}

String _friendlyAuthError(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('expired') ||
      normalized.contains('invalid') ||
      normalized.contains('otp')) {
    return 'El enlace no es válido o ya venció. Solicita un enlace nuevo y ábrelo una sola vez.';
  }
  if (normalized.contains('code verifier')) {
    return 'No se encontró la verificación de este navegador. Solicita un enlace nuevo y ábrelo en el mismo navegador donde comenzaste el proceso.';
  }
  return message;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  try {
    await _exchangeWebAuthCode().timeout(const Duration(seconds: 15));
  } on TimeoutException {
    _webAuthError =
        'La verificación tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.';
  }

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
    if (uri == null || uri.scheme != 'miapp' || uri.host != 'auth-callback') {
      return;
    }
    final fragment = uri.fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    final parameters = {...fragment, ...uri.queryParameters};
    final linkType = parameters['type'];
    var isRecovery = linkType == 'recovery';
    final isEmailChange = parameters['type'] == 'email_change';
    final linkError = parameters['error_description'] ?? parameters['error'];
    if (linkError != null) {
      _showMobileAuthCallback(
        isEmailChange: isEmailChange,
        processingError: _friendlyAuthError(linkError),
      );
      return;
    }
    if (parameters['verified'] == 'true') {
      _showMobileAuthCallback(isEmailVerification: true);
      return;
    }

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
      if (isRecovery) return;
      _showMobileAuthCallback(
        isEmailVerification: linkType == 'signup',
        isEmailChange: isEmailChange,
      );
      return;
    }

    final tokenHash = parameters['token_hash'] ?? parameters['token'];
    if ((isRecovery || isEmailChange || linkType == 'signup') &&
        tokenHash != null) {
      await client.verifyOTP(
        tokenHash: tokenHash,
        type: switch (linkType) {
          'recovery' => OtpType.recovery,
          'email_change' => OtpType.emailChange,
          _ => OtpType.signup,
        },
      );
      if (isRecovery) return;
      _showMobileAuthCallback(
        isEmailVerification: linkType == 'signup',
        isEmailChange: isEmailChange,
      );
      return;
    }

    final accessToken = parameters['access_token'];
    final refreshToken = parameters['refresh_token'];
    if ((isRecovery || isEmailChange || linkType == 'signup') &&
        accessToken != null &&
        refreshToken != null) {
      await client.setSession(refreshToken, accessToken: accessToken);
      if (isRecovery) return;
      _showMobileAuthCallback(
        isEmailVerification: linkType == 'signup',
        isEmailChange: isEmailChange,
      );
      return;
    }
    if (isRecovery || isEmailChange || linkType == 'signup') {
      _showMobileAuthCallback(
        isEmailChange: isEmailChange,
        processingError:
            'El enlace no contiene una verificación válida. Solicita uno nuevo.',
      );
    }
  }

  try {
    await exchange(
      await appLinks.getInitialLink().timeout(const Duration(seconds: 10)),
    );
  } catch (error) {
    debugPrint('Error procesando el enlace de autenticación: $error');
    _showMobileAuthCallback(processingError: _friendlyAuthError('$error'));
  }
  appLinks.uriLinkStream.listen(
    (uri) async {
      try {
        await exchange(uri);
      } catch (error) {
        debugPrint('Error procesando el enlace de autenticación: $error');
        _showMobileAuthCallback(processingError: _friendlyAuthError('$error'));
      }
    },
    onError: (Object error) {
      debugPrint('Error leyendo deep link de autenticación: $error');
    },
  );
}

void _showMobileAuthCallback({
  bool isEmailVerification = false,
  bool isEmailChange = false,
  String? processingError,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthCallbackScreen(
          isEmailVerification: isEmailVerification,
          isEmailChange: isEmailChange,
          processingError: processingError,
        ),
      ),
      (_) => false,
    );
  });
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
          final bool hasRecoverySession =
              Supabase.instance.client.auth.currentSession != null &&
              authProvider.isPasswordRecovery;

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'BillTracker',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: hasRecoverySession
                ? const UpdatePasswordScreen()
                : isWebPasswordRecovery
                ? AuthCallbackScreen(
                    isRecovery: true,
                    processingError:
                        _webAuthError ??
                        'El enlace no se validó. Solicita uno nuevo para cambiar tu contraseña.',
                  )
                : isWebCallback
                ? AuthCallbackScreen(
                    processingError: _webAuthError,
                    isEmailChange: _initialEmailChangeLink,
                    isEmailVerification: _initialEmailVerificationSuccess,
                  )
                : authProvider.isPasswordRecovery
                ? const UpdatePasswordScreen()
                : isAuth
                ? const AuthenticatedHomeScreen()
                : const LoginScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const AuthenticatedHomeScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/update-password': (context) =>
                  hasRecoverySession || authProvider.isPasswordRecovery
                  ? const UpdatePasswordScreen()
                  : const AuthCallbackScreen(
                      isRecovery: true,
                      processingError:
                          'No hay una sesión de recuperación válida. Solicita un enlace nuevo.',
                    ),
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
