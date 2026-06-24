import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

// 🎭 Proveedor de autenticación (maneja el estado)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

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
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
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

  // 🔄 Cargar usuario actual
  Future<void> loadUser() async {
    final user = await _authService.getCurrentUser();
    _user = user;
    notifyListeners();
  }
}
