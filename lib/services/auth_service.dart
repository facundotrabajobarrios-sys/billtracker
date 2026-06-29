import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';

// 🔐 Servicio de autenticación
class AuthService {
  // 📦 Instancia única (Singleton)
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ✅ Forma CORRECTA de obtener el cliente de Supabase
  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  // 📝 Registrar nuevo usuario
  Future<User?> register(String email, String password, String name) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user != null) {
        await _client.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'level': 0,
          'points': 0,
        });

        final user = User.fromJson({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'level': 0,
          'points': 0,
        });

        // ✅ Guardar sesión
        await _saveSession(user);
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Error en registro: $e');
      return null;
    }
  }

  // 🔑 Iniciar sesión
  Future<User?> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userData = await _client
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        final user = User.fromJson(userData);

        // ✅ Guardar sesión
        await _saveSession(user);
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Error en login: $e');
      return null;
    }
  }

  // 🚪 Cerrar sesión
  Future<void> logout() async {
    await _client.auth.signOut();
    // ✅ Eliminar sesión guardada
    await _clearSession();
  }

  // 👤 Obtener usuario actual (primero de Supabase, luego de caché)
  Future<User?> getCurrentUser() async {
    // 1️⃣ Intentar obtener sesión de Supabase
    final session = _client.auth.currentSession;
    if (session != null) {
      try {
        final userData = await _client
            .from('users')
            .select()
            .eq('id', session.user.id)
            .single();
        final user = User.fromJson(userData);
        await _saveSession(user);
        return user;
      } catch (e) {
        // Si falla, intentar con caché
        return await _getCachedUser();
      }
    }

    // 2️⃣ Si no hay sesión en Supabase, buscar en caché
    return await _getCachedUser();
  }

  // 🔑 Recuperar contraseña
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('❌ Error al enviar correo de recuperación: $e');
      return false;
    }
  }

  // 💾 Guardar sesión en SharedPreferences
  Future<void> _saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_name', user.name ?? '');
      await prefs.setInt('user_level', user.level ?? 0);
      await prefs.setInt('user_points', user.points ?? 0);
      print('✅ Sesión guardada para: ${user.email}');
    } catch (e) {
      print('❌ Error al guardar sesión: $e');
    }
  }

  // 📖 Obtener usuario de caché
  Future<User?> _getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('user_id');
      final email = prefs.getString('user_email');
      final name = prefs.getString('user_name');
      final level = prefs.getInt('user_level') ?? 0;
      final points = prefs.getInt('user_points') ?? 0;

      if (id != null && email != null) {
        print('✅ Usuario cargado de caché: $email');
        return User(
          id: id,
          email: email,
          name: name ?? 'Usuario',
          level: level,
          points: points,
        );
      }
      return null;
    } catch (e) {
      print('❌ Error al cargar caché: $e');
      return null;
    }
  }

  // 🗑️ Eliminar sesión guardada
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_level');
      await prefs.remove('user_points');
      print('✅ Sesión eliminada');
    } catch (e) {
      print('❌ Error al eliminar sesión: $e');
    }
  }
}
