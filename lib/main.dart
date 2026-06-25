import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notifications_screen.dart';
import 'config/supabase_config.dart';

void main() async {
  // Asegura que los bindings de Flutter estén inicializados antes de usar Supabase
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
      ],
      child: MaterialApp(
        title: 'BillTracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        // 🔒 Rutas con protección
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());

            case '/home':
              // ✅ Solo permite entrar si está autenticado
              return MaterialPageRoute(
                builder: (_) => Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    if (authProvider.isAuthenticated) {
                      return const HomeScreen();
                    } else {
                      // 🔄 Si no está autenticado, redirige al login
                      Future.microtask(() {
                        Navigator.pushReplacementNamed(context, '/login');
                      });
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                  },
                ),
              );

            case '/reset-password':
              // 🔑 Pantalla de recuperación (pública)
              return MaterialPageRoute(
                builder: (_) => const ResetPasswordScreen(),
              );

            case '/notifications':
              // 🔔 Pantalla de notificaciones (solo autenticados)
              return MaterialPageRoute(
                builder: (_) => Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    if (authProvider.isAuthenticated) {
                      return const NotificationsScreen();
                    } else {
                      Future.microtask(() {
                        Navigator.pushReplacementNamed(context, '/login');
                      });
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                  },
                ),
              );

            default:
              // 🏠 Si la ruta no existe, va al login
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
