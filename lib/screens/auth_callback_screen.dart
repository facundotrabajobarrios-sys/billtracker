import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({
    super.key,
    this.isRecovery = false,
    this.processingError,
  });

  final bool isRecovery;
  final String? processingError;

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  final _authService = AuthService();
  bool _isResending = false;

  Map<String, String> get _callbackParameters {
    final parameters = <String, String>{...Uri.base.queryParameters};
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      parameters.addAll(Uri.splitQueryString(fragment));
    }
    return parameters;
  }

  Future<void> _resendConfirmation() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reenviar confirmación'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo electrónico'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    setState(() => _isResending = true);
    try {
      await _authService.resendSignupConfirmation(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si la cuenta necesita confirmación, enviaremos un nuevo enlace.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reenviar la confirmación: $error')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _friendlyError(String error) {
    final normalized = error.toLowerCase();
    if (normalized.contains('expired') ||
        normalized.contains('invalid') ||
        normalized.contains('otp_expired')) {
      return 'El enlace no es válido o ya venció. Solicita uno nuevo y ábrelo una sola vez.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final parameters = _callbackParameters;
    final error =
        widget.processingError ??
        parameters['error_description'] ??
        parameters['error'];
    final isRecovery = widget.isRecovery || parameters['type'] == 'recovery';
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;

    final title = error != null
        ? 'No se pudo completar la autenticación'
        : isRecovery
        ? 'Enlace de recuperación confirmado'
        : '¡Correo verificado correctamente!';
    final message = error != null
        ? _friendlyError(error)
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
                          isRecovery && error != null
                              ? '/reset-password'
                              : isAuthenticated
                              ? '/home'
                              : '/login',
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          isRecovery && error != null
                              ? 'Solicitar otro enlace'
                              : isAuthenticated
                              ? 'Ir al inicio'
                              : 'Iniciar sesión',
                        ),
                      ),
                    ),
                    if (error != null && !isRecovery) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isResending ? null : _resendConfirmation,
                        child: _isResending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Reenviar verificación'),
                      ),
                    ],
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
