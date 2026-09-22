import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';
import '../services/auth_service.dart';

// 🎭 Proveedor de autenticación (maneja el estado)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  bool _registrationNeedsConfirmation = false;
  bool _isPasswordRecovery = false;
  late final StreamSubscription _authSubscription;

  AuthProvider() {
    _authSubscription = _authService.authStateChanges.listen((state) async {
      if (state.event == supabase.AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _user = null;
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
  bool get isAuthenticated => _user != null;
  bool get registrationNeedsConfirmation => _registrationNeedsConfirmation;
  bool get isPasswordRecovery => _isPasswordRecovery;

  // 🔐 Iniciar sesión
  Future<bool> login(String email, String password) async {
    _isLoading = true;
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
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Error en login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 📝 Registrar usuario
  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.register(email, password, name);
      if (user != null) {
        _registrationNeedsConfirmation =
            !_authService.isCurrentUserEmailConfirmed;
        _user = _registrationNeedsConfirmation ? null : user;
        _isLoading = false;
        notifyListeners();
        return !_registrationNeedsConfirmation;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Error en registro: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🚪 Cerrar sesión
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> updatePassword(String password) async {
    await _authService.updatePassword(password);
    _isPasswordRecovery = false;
    await logout();
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
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getCurrentUser();
      _user = user;
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
    notifyListeners();
  }

  // ✅ Verificar si el usuario está autenticado y cargado
  bool get hasValidSession => _user != null;
}
