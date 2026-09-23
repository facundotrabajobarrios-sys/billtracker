import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';
import 'audit_log_service.dart';

// 🔐 Servicio de autenticación
class AuthService {
  // 📦 Instancia única (Singleton)
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ✅ Forma CORRECTA de obtener el cliente de Supabase
  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;
  Stream<supabase.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
  bool get isCurrentUserEmailConfirmed =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  // 📝 Registrar nuevo usuario
  Future<User?> register(String email, String password, String name) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: SupabaseConfig.authRedirectUri,
        data: {'name': name},
      );

      if (response.user != null) {
        final user = User.fromJson({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'level': 0,
          'points': 0,
        });

        // Supabase no crea una sesión hasta que el enlace de confirmación se
        // consume. Nunca se debe tratar al usuario como autenticado antes.
        if (response.session != null &&
            response.user!.emailConfirmedAt != null) {
          await _ensureProfile(response.user!, name: name);
          await _saveSession(user);
          await AuditLogService().record('register');
        }
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
        if (response.user!.emailConfirmedAt == null) {
          await _client.auth.signOut();
          return null;
        }
        await _ensureProfile(response.user!);
        final userData = await _client
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        final user = User.fromJson(userData);

        // ✅ Guardar sesión
        await _saveSession(user);
        await AuditLogService().record('login');
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Error en login: $e');
      return null;
    }
  }

  Future<void> _ensureProfile(supabase.User authUser, {String? name}) async {
    final existing = await _client
        .from('users')
        .select('id')
        .eq('id', authUser.id)
        .maybeSingle();
    if (existing != null) {
      return;
    }
    await _client.from('users').insert({
      'id': authUser.id,
      'email': authUser.email,
      'name': name ?? authUser.userMetadata?['name'] ?? 'Usuario',
      'level': 0,
      'points': 0,
    });
  }

  // 🚪 Cerrar sesión
  Future<void> logout() async {
    await AuditLogService().record('logout');
    await _client.auth.signOut();
    // ✅ Eliminar sesión guardada
    await _clearSession();
  }

  // 👤 Obtener usuario actual (primero de Supabase, luego de caché)
  Future<User?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session != null && session.user.emailConfirmedAt != null) {
      try {
        await _ensureProfile(session.user);
        final userData = await _client
            .from('users')
            .select()
            .eq('id', session.user.id)
            .single();
        final user = User.fromJson(userData);
        await _saveSession(user);
        return user;
      } catch (e) {
        print('❌ Error al cargar el perfil autenticado: $e');
        return null;
      }
    }

    // La caché nunca concede acceso: la sesión vigente de Supabase es la
    // única fuente de autenticación y además debe estar confirmada.
    return null;
  }

  // 🔑 Recuperar contraseña
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? SupabaseConfig.webPasswordRecoveryUri
            : SupabaseConfig.mobileCallbackUri,
      );
      // This action is intentionally not logged here because no authenticated
      // user exists when a password reset is requested.
      return true;
    } catch (e) {
      print('❌ Error al enviar correo de recuperación: $e');
      return false;
    }
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(supabase.UserAttributes(password: password));
    await AuditLogService().record('password_changed');
  }

  Future<void> deleteAccount() async {
    await AuditLogService().record('account_deleted');
    await _client.functions.invoke('delete-account');
    await logout();
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
