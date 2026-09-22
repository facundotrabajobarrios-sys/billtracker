import 'package:flutter/foundation.dart';

// Configuración de Supabase
class SupabaseConfig {
  // 🔑 Reemplaza con tus credenciales de Supabase
  // URL de tu proyecto Supabase
  static const String url = 'https://zvvvkkekxlokpajrpggv.supabase.co';
  //publishable key
  static const String anonKey =
      'sb_publishable_xencDyrZUxpDheObUKg2Tw_O8OkvraH';

  static const String webCallbackUri =
      'https://facundotrabajobarrios-sys.github.io/billtracker/auth/callback';
  static const String mobileCallbackUri = 'miapp://auth-callback';
  static const String localDevelopmentUri = 'http://localhost:3000';

  static String get authRedirectUri {
    if (kIsWeb) return webCallbackUri;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return mobileCallbackUri;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return webCallbackUri;
      case TargetPlatform.fuchsia:
        return mobileCallbackUri;
    }
  }
}
