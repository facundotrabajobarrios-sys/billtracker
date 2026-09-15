import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/bill.dart';
import 'providers/auth_provider.dart';
import 'providers/gamification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/auth_callback_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/add_bill_screen.dart';
import 'config/supabase_config.dart';
import 'services/push_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await PushNotificationService().init(navigatorKey: navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const MaterialApp(
              title: 'BillTracker',
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
              debugShowCheckedModeBanner: false,
            );
          }

          final bool isAuth = authProvider.isAuthenticated;
          final bool isAuthCallback = Uri.base.path.endsWith('/auth/callback');

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'BillTracker',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
              ),
              useMaterial3: true,
            ),
            home: isAuthCallback
                ? const AuthCallbackScreen()
                : isAuth
                ? const HomeScreen()
                : const LoginScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/auth/callback': (context) => const AuthCallbackScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/bill-detail': (context) {
                final bill =
                    ModalRoute.of(context)?.settings.arguments as Bill?;
                return AddBillScreen(bill: bill);
              },
            },
            onUnknownRoute: (settings) {
              if (settings.name?.contains('/auth/callback') ?? false) {
                return MaterialPageRoute(
                  builder: (_) => const AuthCallbackScreen(),
                );
              }
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
