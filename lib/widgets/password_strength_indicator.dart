import 'package:flutter/material.dart';
import '../utils/validators.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      '8 caracteres': PasswordRules.hasMinLength(password),
      'Mayúscula': PasswordRules.hasUppercase(password),
      'Minúscula': PasswordRules.hasLowercase(password),
      'Número': PasswordRules.hasNumber(password),
      'Símbolo (!@#...)': PasswordRules.hasSpecial(password),
    };
    final score = rules.values.where((value) => value).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: score / rules.length,
          color: score == rules.length ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: rules.entries
              .map(
                (entry) => Text(
                  '${entry.value ? '✓' : '○'} ${entry.key}',
                  style: TextStyle(
                    color: entry.value ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
