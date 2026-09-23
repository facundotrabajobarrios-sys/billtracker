import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/password_strength_indicator.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().updatePassword(
        _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la contraseña: $error')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  'Escribe tu nueva contraseña',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Mostrar contraseña',
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: PasswordRules.validate,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: _passwordController,
                  builder: (_, value, __) =>
                      PasswordStrengthIndicator(password: value.text),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmationController,
                  obscureText: !_showConfirmation,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Mostrar confirmación',
                      icon: Icon(
                        _showConfirmation
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _showConfirmation = !_showConfirmation,
                      ),
                    ),
                  ),
                  validator: (value) => value == _passwordController.text
                      ? null
                      : 'Las contraseñas no coinciden',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Guardar contraseña'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
