import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    // The mobile email uses miapp://auth-callback directly. This page is the
    // safe web fallback when the app is not installed.
    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Correo verificado exitosamente',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Serás enviado al inicio de sesión. Si tienes la aplicación móvil instalada, abre el enlace desde tu teléfono para continuar allí.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Ir al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
