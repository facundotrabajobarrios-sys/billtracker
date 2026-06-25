import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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

        return User.fromJson({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'level': 0,
          'points': 0,
        });
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

        return User.fromJson(userData);
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
  }

  // 👤 Obtener usuario actual
  Future<User?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    try {
      final userData = await _client
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
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
}
