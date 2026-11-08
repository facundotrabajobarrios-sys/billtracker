import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(
    String action, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'admin-api',
        body: {'action': action, ...parameters},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        final message = details['message'] ?? details['error'];
        if (message is String && message.isNotEmpty) {
          throw AdminServiceException(message);
        }
      }
      throw AdminServiceException(
        details is String && details.isNotEmpty
            ? details
            : 'Error HTTP ${error.status}: ${error.reasonPhrase ?? 'solicitud fallida'}',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw const FormatException(
        'Respuesta inválida del servicio administrador.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getDashboard() => _invoke('dashboard');

  Future<Map<String, dynamic>> getUsers({
    int page = 0,
    String search = '',
    String sortBy = 'created_at',
    bool ascending = false,
  }) => _invoke('users', {
    'page': page,
    'pageSize': 25,
    'search': search,
    'sortBy': sortBy,
    'ascending': ascending,
  });

  Future<Map<String, dynamic>> getUserDetails(String userId) =>
      _invoke('user_details', {'userId': userId});

  Future<Map<String, dynamic>> getBills({
    int page = 0,
    String search = '',
    String status = '',
  }) => _invoke('bills', {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status,
  });

  Future<void> updateUserName(String userId, String name) async {
    await _invoke('update_user', {'userId': userId, 'name': name});
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _invoke('set_user_active', {'userId': userId, 'isActive': isActive});
  }

  Future<void> deleteUser(String userId) async {
    await _invoke('delete_user', {'userId': userId});
  }

  Future<void> updateBill({
    required String billId,
    required double amount,
    required String dueDate,
    required String status,
  }) async {
    await _invoke('update_bill', {
      'billId': billId,
      'amount': amount,
      'dueDate': dueDate,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> getAuditLogs() => _invoke('audit');

  Future<Map<String, dynamic>> getSettings() => _invoke('get_settings');

  Future<void> updateAnnouncement(String announcement) async {
    await _invoke('update_settings', {'announcement': announcement});
  }
}

class AdminServiceException implements Exception {
  const AdminServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
