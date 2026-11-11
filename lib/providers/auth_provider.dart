import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

// 🎭 Proveedor de autenticación (maneja el estado)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  User? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _registrationNeedsConfirmation = false;
  bool _isPasswordRecovery = false;
  String? _loginError;
  String? _registrationError;
  late final StreamSubscription _authSubscription;

  AuthProvider({bool isPasswordRecovery = false})
    : _isPasswordRecovery = isPasswordRecovery {
    _authSubscription = _authService.authStateChanges.listen((state) async {
      if (state.event == supabase.AuthChangeEvent.initialSession) {
        return;
      }
      if (state.event == supabase.AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _user = null;
        notifyListeners();
        return;
      }
      if (state.event == supabase.AuthChangeEvent.signedIn && _isLoading) {
        return;
      }
      if (state.event == supabase.AuthChangeEvent.signedOut) {
        _user = null;
        _isPasswordRecovery = false;
        notifyListeners();
        return;
      }
      if (_authService.isCurrentUserEmailConfirmed) {
        await loadUser();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin == true;
  bool get mustChangeAdminPassword => _user?.mustChangePassword == true;
  String? get loginError => _loginError;
  String? get registrationError => _registrationError;
  bool get registrationNeedsConfirmation => _registrationNeedsConfirmation;
  bool get isPasswordRecovery => _isPasswordRecovery;

  Future<AvatarUpdateResult> uploadAvatar(
    Uint8List bytes,
    String fileName,
  ) async {
    final result = await _profileService.uploadAvatar(bytes, fileName);
    _user = _user?.copyWith(avatarUrl: result.imageUrl);
    notifyListeners();
    return result;
  }

  Future<AvatarUpdateResult> deleteAvatar() async {
    final result = await _profileService.deleteAvatar();
    _user = _user?.copyWith(clearAvatarUrl: true);
    notifyListeners();
    return result;
  }

  Future<ProfileUpdateResult> updateProfile({
    required String name,
    required String email,
    String? currentPassword,
  }) async {
    final result = await _profileService.updateProfile(
      name: name,
      email: email,
      currentPassword: currentPassword,
    );
    final refreshedUser = await _authService.getCurrentUser();
    _user = refreshedUser ?? _user?.copyWith(name: name.trim());
    notifyListeners();
    return result;
  }

  void markPasswordRecovery() {
    _isPasswordRecovery = true;
    _user = null;
    notifyListeners();
  }

  // 🔐 Iniciar sesión
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      _loginError =
          'No se pudo iniciar sesión. Verifica tus datos e inténtalo de nuevo.';
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Error en login: $e');
      _loginError = switch (e) {
        supabase.AuthException() => e.message,
        StateError() => e.message,
        _ => e.toString(),
      };
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 📝 Registrar usuario
  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _registrationError = null;
    _registrationNeedsConfirmation = false;
    notifyListeners();

    try {
      final user = await _authService.register(email, password, name);
      if (user != null) {
        _registrationNeedsConfirmation =
            !_authService.isCurrentUserEmailConfirmed;
        _user = _registrationNeedsConfirmation ? null : user;
        _isLoading = false;
        _isInitializing = false;
        notifyListeners();
        return !_registrationNeedsConfirmation;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Error en registro: $e');
      _registrationError = switch (e) {
        supabase.AuthException() => e.message,
        StateError() => e.message,
        _ => e.toString(),
      };
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🚪 Cerrar sesión
  Future<void> logout({bool revokeAllSessions = false}) async {
    _user = null;
    notifyListeners();
    try {
      await _authService.logout(revokeAllSessions: revokeAllSessions);
    } finally {
      _user = null;
      notifyListeners();
    }
  }

  Future<void> completePasswordRecovery(String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.completePasswordRecovery(password);
      _isPasswordRecovery = false;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeInitialAdminPasswordChange(String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.completeInitialAdminPasswordChange(password);
      await loadUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // 🔄 Cargar usuario actual (desde caché o Supabase)
  Future<void> loadUser() async {
    if (_isPasswordRecovery) {
      _user = null;
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 15),
      );
      _user = _isPasswordRecovery ? null : user;
      if (user != null) {
        print('👤 Usuario cargado: ${user.email}');
      } else {
        print('👤 No hay usuario logueado');
        _user = null;
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      _user = null;
    }

    _isLoading = false;
    _isInitializing = false;
    notifyListeners();
  }

  // ✅ Verificar si el usuario está autenticado y cargado
  bool get hasValidSession => _user != null;
}
