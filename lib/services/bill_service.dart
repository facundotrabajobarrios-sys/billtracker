import 'gamification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/bill.dart';
import 'audit_log_service.dart';

// 📄 Servicio de facturas (CRUD)
class BillService {
  // 📦 Instancia única (Singleton)
  static final BillService _instance = BillService._internal();
  factory BillService() => _instance;
  BillService._internal();

  // 🔗 Conexión a Supabase
  supabase.SupabaseClient get client => supabase.Supabase.instance.client;

  // 📥 Obtener todas las facturas del usuario
  Future<List<Bill>> getBills(String userId) async {
    try {
      // ✅ CAMBIAR `!inner` por `()`
      final response = await client
          .from('bills')
          .select('''
            *,
            services (
              id,
              name,
              description
            ),
            categories (
              id,
              name,
              icon,
              color
            )
          ''')
          .eq('user_id', userId)
          .order('due_date', ascending: true);

      print('📊 Facturas obtenidas: ${response.length}');

      if (response is List) {
        return response.map((json) {
          print('📄 Factura: ${json['id']} - Servicio: ${json['services']}');
          return Bill.fromJson(json);
        }).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener facturas: $e');
      return [];
    }
  }

  // 📥 Obtener una factura por ID
  Future<Bill?> getBillById(String billId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await client
          .from('bills')
          .select('''
             *,
             services (
               id,
               name,
               description
             ),
             categories (
               id,
               name,
               icon,
               color
             )
           ''')
          .eq('id', billId)
          .eq('user_id', userId)
          .single();

      return Bill.fromJson(response);
      return null;
    } catch (e) {
      print('❌ Error al obtener factura por ID: $e');
      return null;
    }
  }

  // 📥 Obtener facturas por estado
  Future<List<Bill>> getBillsByStatus(String userId, String status) async {
    try {
      final response = await client
          .from('bills')
          .select('''
            *,
            services (
              id,
              name,
              description
            ),
            categories (
              id,
              name,
              icon,
              color
            )
          ''')
          .eq('user_id', userId)
          .eq('status', status)
          .order('due_date', ascending: true);

      if (response is List) {
        return response.map((json) => Bill.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener facturas por estado: $e');
      return [];
    }
  }

  // 📝 Crear una factura
  Future<Bill?> createBill(Bill bill) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || bill.userId != userId) return null;
      final response = await client.from('bills').insert(bill.toJson()).select(
        '''
            *,
            services (
              id,
              name,
              description
            ),
            categories (
              id,
              name,
              icon,
              color
            )
          ''',
      ).single();

      final created = Bill.fromJson(response);
      await AuditLogService().record(
        'bill_created',
        entityType: 'bill',
        entityId: created.id,
      );
      return created;
    } catch (e) {
      print('❌ Error al crear factura: $e');
      return null;
    }
  }

  // ✏️ Actualizar una factura
  Future<Bill?> updateBill(Bill bill) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null || bill.userId != userId) return null;
      final response = await client
          .from('bills')
          .update(bill.toJson())
          .eq('id', bill.id)
          .eq('user_id', userId)
          .select('''
            *,
            services (
              id,
              name,
              description
            ),
            categories (
              id,
              name,
              icon,
              color
            )
          ''')
          .single();

      final updated = Bill.fromJson(response);
      await AuditLogService().record(
        'bill_updated',
        entityType: 'bill',
        entityId: updated.id,
      );
      return updated;
    } catch (e) {
      print('❌ Error al actualizar factura: $e');
      return null;
    }
  }

  // 🗑️ Eliminar una factura
  Future<bool> deleteBill(String billId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;
      final deleted = await client
          .from('bills')
          .delete()
          .eq('id', billId)
          .eq('user_id', userId)
          .select('id');
      if (deleted.isEmpty) return false;
      await AuditLogService().record(
        'bill_deleted',
        entityType: 'bill',
        entityId: billId,
      );
      return true;
    } catch (e) {
      print('❌ Error al eliminar factura: $e');
      return false;
    }
  }

  // ✅ Marcar factura como pagada
  Future<Bill?> markAsPaid(String billId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await client
          .from('bills')
          .update({
            'status': 'paid',
            'paid_date': DateTime.now().toIso8601String(),
          })
          .eq('id', billId)
          .eq('user_id', userId)
          .select('''
            *,
            services (
              id,
              name,
              description
            ),
            categories (
              id,
              name,
              icon,
              color
            )
          ''')
          .single();

      final paid = Bill.fromJson(response);
      await AuditLogService().record(
        'bill_marked_paid',
        entityType: 'bill',
        entityId: paid.id,
      );
      return paid;
    } catch (e) {
      print('❌ Error al marcar como pagada: $e');
      return null;
    }
  }

  // 📊 Obtener resumen de facturas
  Future<Map<String, int>> getSummary(String userId) async {
    try {
      final allBills = await getBills(userId);

      int pending = allBills.where((b) => b.status == 'pending').length;
      int paid = allBills.where((b) => b.status == 'paid').length;
      int overdue = allBills
          .where((b) => b.status == 'overdue' || b.isOverdue)
          .length;
      int total = allBills.length;

      return {
        'pending': pending,
        'paid': paid,
        'overdue': overdue,
        'total': total,
      };
    } catch (e) {
      print('❌ Error al obtener resumen: $e');
      return {'pending': 0, 'paid': 0, 'overdue': 0, 'total': 0};
    }
  }

  // 📥 Obtener servicios (para el selector)
  Future<List<Map<String, dynamic>>> getServices() async {
    try {
      final response = await client.from('services').select();
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener servicios: $e');
      return [];
    }
  }

  // 📝 Crear servicio (asociado al usuario)
  Future<Map<String, dynamic>?> createService(
    String userId,
    String name,
    String? description,
  ) async {
    try {
      final response = await client
          .from('services')
          .insert({'name': name, 'description': description, 'user_id': userId})
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error al crear servicio: $e');
      return null;
    }
  }

  // 📥 Obtener categorías (para el selector)
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await client.from('categories').select();
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener categorías: $e');
      return [];
    }
  }

  // 🏆 Procesar pago con gamificación
  Future<Bill?> markAsPaidWithGamification(String billId) async {
    try {
      // 1. Marcar factura como pagada
      final bill = await markAsPaid(billId);
      if (bill == null) return null;

      // 2. Verificar si fue a tiempo
      final wasOnTime =
          bill.dueDate.isAfter(DateTime.now()) ||
          bill.dueDate.isAtSameMomentAs(DateTime.now());

      // 3. Procesar gamificación
      final gamificationService = GamificationService();

      // Obtener gamificación anterior (para notificaciones)
      final oldGamification = await gamificationService.getGamification(
        bill.userId,
      );
      final oldBadges = oldGamification?.unlockedBadges ?? [];

      // Procesar pago
      final updatedGamification = await gamificationService.processPayment(
        bill.userId,
        bill,
        wasOnTime,
      );

      // 4. Notificar nuevas insignias
      if (updatedGamification != null) {
        await gamificationService.notifyNewBadges(
          bill.userId,
          oldBadges,
          updatedGamification.unlockedBadges,
        );
      }

      return bill;
    } catch (e) {
      print('❌ Error al marcar como pagada con gamificación: $e');
      return null;
    }
  }
}
