import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_links/uni_links.dart';
import 'models/bill.dart';
import 'providers/auth_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/add_bill_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/auth_callback_screen.dart';
import 'config/supabase_config.dart';
import 'services/push_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, String> _webAuthParameters() {
  final parameters = <String, String>{...Uri.base.queryParameters};
  if (Uri.base.fragment.isNotEmpty) {
    parameters.addAll(Uri.splitQueryString(Uri.base.fragment));
  }
  return parameters;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final supportsLocalNotifications =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (supportsLocalNotifications) {
    await PushNotificationService().init(navigatorKey: navigatorKey);
    await _initAuthDeepLinks();
  }

  runApp(const MyApp());
}

Future<void> _initAuthDeepLinks() async {
  Future<void> exchange(Uri? uri) async {
    if (uri == null || uri.queryParameters['code'] == null) return;
    await Supabase.instance.client.auth.exchangeCodeForSession(
      uri.queryParameters['code']!,
    );
  }

  await getInitialUri().then(exchange);
  uriLinkStream.listen(
    exchange,
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
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          if (authProvider.isLoading || !themeProvider.isLoaded) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
              debugShowCheckedModeBanner: false,
            );
          }

          final bool isAuth = authProvider.isAuthenticated;
          final bool isWebCallback =
              kIsWeb && Uri.base.path.endsWith('/auth/callback');
          final bool isWebPasswordRecovery =
              isWebCallback && _webAuthParameters()['type'] == 'recovery';

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'BillTracker',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF66BB6A),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: authProvider.isPasswordRecovery || isWebPasswordRecovery
                ? const UpdatePasswordScreen()
                : isWebCallback
                ? const AuthCallbackScreen()
                : isAuth
                ? const HomeScreen()
                : const LoginScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
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
