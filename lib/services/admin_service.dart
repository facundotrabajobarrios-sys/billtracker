import 'dart:typed_data';

import 'package:http/http.dart' as http;
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

  Future<String> startSystemBackup() async {
    final result = await _invoke('start_system_backup');
    final backupId = result['backupId'];
    if (backupId is! String || backupId.isEmpty) {
      throw const FormatException('No se recibió el identificador del backup.');
    }
    return backupId;
  }

  Future<Map<String, dynamic>> getSystemBackupStatus(String backupId) =>
      _invoke('system_backup_status', {'backupId': backupId});

  Future<Uint8List> downloadSystemBackup(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      throw AdminServiceException(
        'No se pudo descargar el backup (HTTP ${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> getUsers({
    int page = 0,
    String search = '',
    String sortBy = 'created_at',
    bool ascending = false,
    int pageSize = 25,
  }) => _invoke('users', {
    'page': page,
    'pageSize': pageSize,
    'search': search,
    'sortBy': sortBy,
    'ascending': ascending,
  });

  Future<List<Map<String, dynamic>>> getRecipientUsers() async {
    final result = await _invoke('recipient_users');
    final rows = result['rows'];
    if (rows is! List) {
      throw const FormatException(
        'Respuesta inválida al cargar destinatarios.',
      );
    }
    return rows.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>> getUserDetails(String userId) =>
      _invoke('user_details', {'userId': userId});

  Future<Map<String, dynamic>> getBills({
    int page = 0,
    String search = '',
    String status = '',
    String sortBy = 'due_date',
    bool ascending = true,
  }) => _invoke('bills', {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status,
    'sortBy': sortBy,
    'ascending': ascending,
  });

  Future<void> updateUserName(String userId, String name) async {
    await _invoke('update_user', {'userId': userId, 'name': name});
  }

  Future<void> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) async {
    await _invoke('update_user', {
      'userId': userId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (role != null) 'role': role,
    });
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String role,
    String? temporaryPassword,
  }) => _invoke('create_user', {
    'name': name,
    'email': email,
    'role': role,
    if (temporaryPassword != null && temporaryPassword.isNotEmpty)
      'temporaryPassword': temporaryPassword,
  });

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

  Future<Map<String, dynamic>> updateAnnouncement(String announcement) =>
      _invoke('update_settings', {'announcement': announcement});

  Future<List<Map<String, dynamic>>> getCatalog(String entity) async {
    final result = await _invoke('catalog', {'entity': entity});
    final rows = result['rows'];
    if (rows is! List) {
      throw const FormatException('Respuesta inválida al cargar el catálogo.');
    }
    return rows.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> saveCatalogItem({
    required String entity,
    String? id,
    required String name,
    String? description,
    bool isActive = true,
    String? icon,
    String? color,
    String? categoryId,
    String? price,
  }) async {
    await _invoke('save_catalog_item', {
      'entity': entity,
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (categoryId != null) 'categoryId': categoryId,
      if (price != null) 'price': price,
    });
  }

  Future<void> setCatalogItemActive({
    required String entity,
    required String id,
    required bool isActive,
  }) async {
    await _invoke('set_catalog_item_active', {
      'entity': entity,
      'id': id,
      'isActive': isActive,
    });
  }

  Future<void> deleteCatalogItem({
    required String entity,
    required String id,
  }) async {
    await _invoke('delete_catalog_item', {'entity': entity, 'id': id});
  }

  Future<Map<String, dynamic>> publishAnnouncement({
    required String title,
    required String message,
    required bool allUsers,
    List<String> userIds = const [],
  }) => _invoke('publish_announcement', {
    'title': title,
    'message': message,
    'recipientMode': allUsers ? 'all' : 'selected',
    if (!allUsers) 'userIds': userIds,
  });

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final result = await _invoke('announcements');
    final rows = result['rows'];
    if (rows is! List) {
      throw const FormatException('Respuesta inválida al cargar comunicados.');
    }
    return rows.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}

class AdminServiceException implements Exception {
  const AdminServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
