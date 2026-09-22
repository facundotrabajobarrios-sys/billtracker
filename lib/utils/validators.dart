class PasswordRules {
  static bool hasMinLength(String value) => value.length >= 8;
  static bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  static bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  static bool hasNumber(String value) => RegExp(r'[0-9]').hasMatch(value);
  static bool hasSpecial(String value) =>
      RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-/\[\];'+]''').hasMatch(value);

  static bool isStrong(String value) =>
      hasMinLength(value) &&
      hasUppercase(value) &&
      hasLowercase(value) &&
      hasNumber(value) &&
      hasSpecial(value);

  static String? validate(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (!isStrong(value)) {
      return 'Usa 8+ caracteres, mayúscula, minúscula, número y símbolo';
    }
    return null;
  }
}