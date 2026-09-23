import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogService {
  static final AuditLogService _instance = AuditLogService._internal();
  factory AuditLogService() => _instance;
  AuditLogService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> record(
    String action, {
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      await _client.from('audit_logs').insert({
        'user_id': userId,
        'action': action,
        if (entityType != null) 'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        'metadata': metadata,
      });
    } on PostgrestException catch (error) {
      // Auditing must not make the user's primary operation fail.
      debugPrint(
        'Error al registrar auditoría (${error.code}): ${error.message}',
      );
    }
  }
}
