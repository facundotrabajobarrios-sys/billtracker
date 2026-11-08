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

  Future<Map<String, dynamic>> _getAdminStatus() async {
    try {
      final result = await _client.rpc('get_admin_status');
      if (result.isEmpty) return const {};
      return Map<String, dynamic>.from(result.first as Map);
    } on supabase.PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') {
        return const {};
      }
      rethrow;
    }
  }

  // 📝 Registrar nuevo usuario
  Future<User?> register(String email, String password, String name) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUri,
      data: {'name': name},
    );

    final authUser = response.user;
    if (authUser == null) {
      throw StateError('Supabase no devolvió una cuenta después del registro.');
    }

    final user = User.fromJson({
      'id': authUser.id,
      'email': email,
      'name': name,
      'level': 0,
      'points': 0,
    });

    // Supabase no crea una sesión hasta que el enlace de confirmación se
    // consume. Nunca se debe tratar al usuario como autenticado antes.
    if (response.session != null && authUser.emailConfirmedAt != null) {
      await _ensureProfile(authUser, name: name);
      await _saveSession(user);
      await AuditLogService().record('register');
    }
    return user;
  }

  // 🔑 Iniciar sesión
  Future<User?> login(String email, String password) async {
    final loginEmail =
        email.trim().toLowerCase() == SupabaseConfig.adminUsername
        ? SupabaseConfig.adminLoginEmail
        : email.trim();
    final response = await _client.auth.signInWithPassword(
      email: loginEmail,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) return null;
    if (authUser.emailConfirmedAt == null) {
      await _client.auth.signOut();
      throw StateError(
        'Confirma tu correo electrónico antes de iniciar sesión.',
      );
    }

    try {
      await _ensureProfile(authUser);
      final userData = await _client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      final role = await _getAdminStatus();
      final user = User.fromJson({
        ...userData,
        'is_admin': role['is_admin'] == true,
        'must_change_password': role['must_change_password'] == true,
      });
      await _saveSession(user);
      await AuditLogService().record('login');
      return user;
    } catch (_) {
      await _client.auth.signOut();
      rethrow;
    }
  }

  Future<void> _ensureProfile(supabase.User authUser, {String? name}) async {
    final existing = await _client
        .from('users')
        .select('id,email')
        .eq('id', authUser.id)
        .maybeSingle();
    if (existing != null) {
      if (authUser.email != null && existing['email'] != authUser.email) {
        await _client
            .from('users')
            .update({'email': authUser.email})
            .eq('id', authUser.id);
      }
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
  Future<void> logout({bool revokeAllSessions = false}) async {
    await AuditLogService().record('logout');
    Object? remoteError;
    Object? localError;
    try {
      await _client.auth.signOut(
        scope: revokeAllSessions
            ? supabase.SignOutScope.global
            : supabase.SignOutScope.local,
      );
    } catch (error) {
      remoteError = error;
      if (revokeAllSessions) {
        try {
          await _client.auth.signOut(scope: supabase.SignOutScope.local);
        } catch (error) {
          localError = error;
          debugPrint('No se pudo limpiar la sesión local de Supabase: $error');
        }
      }
    } finally {
      await _clearSession();
    }

    if (remoteError != null) {
      throw StateError(
        'Supabase no confirmó ${revokeAllSessions ? 'la revocación remota' : 'el cierre local'}: $remoteError'
        '${localError == null ? '' : '; tampoco se pudo limpiar la sesión local: $localError'}',
      );
    }
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
        final role = await _getAdminStatus();
        final user = User.fromJson({
          ...userData,
          'is_admin': role['is_admin'] == true,
          'must_change_password': role['must_change_password'] == true,
        });
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
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb
          ? SupabaseConfig.webPasswordRecoveryUri
          : SupabaseConfig.mobileCallbackUri,
    );
    return true;
  }

  Future<void> resendSignupConfirmation(String email) async {
    await _client.auth.resend(
      type: supabase.OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.authRedirectUri,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(supabase.UserAttributes(password: password));
    await AuditLogService().record('password_changed');
  }

  Future<void> completeInitialAdminPasswordChange(String password) async {
    await _client.functions.invoke(
      'admin-password',
      body: {'password': password},
    );
  }

  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut(scope: supabase.SignOutScope.local);
    await _clearSession();
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
