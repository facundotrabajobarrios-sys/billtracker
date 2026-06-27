import 'package:flutter/material.dart'; //importa la librería de Flutter para construir la interfaz de usuario
import 'package:provider/provider.dart'; // sirve para manejar el estado de la aplicación y compartir datos entre widgets
import '../providers/auth_provider.dart'; //importa el proveedor de autenticación personalizado
import 'package:supabase_flutter/supabase_flutter.dart'; //conecta la aplicación con Supabase, una plataforma backend como servicio
import 'providers/gamification_provider.dart'; //guarda la información de gamificación del usuario
//Importa las pantallas (vistas) de nuestra app. Cada pantalla es como una "habitación" donde el usuario interactúa.
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notifications_screen.dart';
//Importa la configuración de Supabase, que contiene la URL y la clave anónima para conectarse a la base de datos.
import 'config/supabase_config.dart';

//main() es la función que se ejecuta primero cuando abres la app.
//async significa que puede hacer cosas que toman tiempo (como conectarse a internet) sin congelar la app.
void main() async {
  // Asegura que los bindings de Flutter estén inicializados antes de usar Supabase
  WidgetsFlutterBinding.ensureInitialized();
  //conecta la app con Supabase usando la URL y la clave anónima de la configuración.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  //arranca la app
  runApp(const MyApp());
}

//define la clase principal de la app, que es un widget sin estado (StatelessWidget).
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  }); //constructor que permite pasar una clave única al widget, útil para optimizar la reconstrucción de widgets en Flutter.
  //build() es un método que dibuja la interfaz de usario.
  //@override indica que estamos sobrescribiendo un método de la clase padre (StatelessWidget).
  //BuildContext es un objeto que contiene información sobre dónde está este widget en el árbol de widgets y permite acceder a otros widgets y datos.
  @override
  Widget build(BuildContext context) {
    // MultiProvider permite usar varios proveedores de estado en la app, para que diferentes partes de la app puedan acceder a datos compartidos.
    return MultiProvider(
      providers: [
        // 🔐 Proveedor de autenticación
        //ChangeNotifierProvider crea un proveedor que notifica a los widgets cuando cambian los datos.
        //create: (_) => AuthProvider()..loadUser() crea una instancia de AuthProvider y llama a loadUser() para cargar los datos del usuario al iniciar la app.
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
        // 🏆 Proveedor de gamificación ← ¡AGREGAR ESTO!
        //registra el GamificationProvider para manejar la lógica de gamificación en la app.
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
      ],
      //aquí empieza la parte de la app que depende de los proveedores de estado.
      //MaterialApp es el widget principal que configura la app, como el tema, las rutas y la pantalla inicial.
      child: MaterialApp(
        title: 'BillTracker',
        theme: ThemeData(
          // Configura el tema de la app usando un color base (verde) y habilita Material 3.
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        initialRoute:
            '/login', //define la ruta inicial de la app, que es la pantalla de login.
        // 🔒 Rutas con protección
        //onGenerateRoute permite definir rutas dinámicas y protegerlas según el estado de autenticación del usuario.
        onGenerateRoute: (settings) {
          //switch revisa la ruta solicitada y decide qué pantalla mostrar.
          switch (settings.name) {
            //si la ruta es '/login', muestra la pantalla de login.
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/home':
              // ✅ Solo permite entrar si está autenticado
              //todo esto lo que hace es verificar si el usuario está autenticado antes de mostrar la pantalla de inicio (HomeScreen).
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
} // final de MyApp
