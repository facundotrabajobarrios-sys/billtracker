import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AuthCallbackScreen extends StatelessWidget {
  const AuthCallbackScreen({super.key});

  Map<String, String> get _callbackParameters {
    final parameters = <String, String>{...Uri.base.queryParameters};
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      parameters.addAll(Uri.splitQueryString(fragment));
    }
    return parameters;
  }

  @override
  Widget build(BuildContext context) {
    final parameters = _callbackParameters;
    final error = parameters['error_description'] ?? parameters['error'];
    final isRecovery = parameters['type'] == 'recovery';
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;

    final title = error != null
        ? 'No se pudo completar la autenticación'
        : isRecovery
        ? 'Enlace de recuperación confirmado'
        : '¡Correo verificado correctamente!';
    final message = error != null
        ? error
        : isRecovery
        ? 'El enlace es válido. Ya puedes continuar con el restablecimiento de tu contraseña.'
        : 'Tu cuenta está activa y tu correo electrónico ha sido confirmado.';

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación de autenticación')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      error != null ? Icons.error_outline : Icons.check_circle,
                      size: 80,
                      color: error != null ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          isAuthenticated ? '/home' : '/login',
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          isAuthenticated ? 'Ir al inicio' : 'Iniciar sesión',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
