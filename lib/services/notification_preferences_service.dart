import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferencesService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> getForUser(String userId) async {
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row ??
        {
          'user_id': userId,
          'email_enabled': true,
          'due_date_reminders': true,
          'payment_confirmations': true,
          'weekly_summary': false,
        };
  }

  Future<void> save(String userId, Map<String, bool> values) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      ...values,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
