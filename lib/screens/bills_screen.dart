import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';
import 'add_bill_screen.dart';

// 📄 Pantalla de lista de facturas
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final _billService = BillService();
  List<Bill> _bills = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'pending', 'paid', 'overdue'

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  // 📥 Cargar facturas
  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      final bills = await _billService.getBills(userId);
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🗑️ Eliminar factura
  Future<void> _deleteBill(Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar factura'),
        content: Text('¿Eliminar factura de ${bill.service?.name ?? ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _billService.deleteBill(bill.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Factura eliminada'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadBills();
      }
    }
  }

  // ✅ Marcar como pagada
  Future<void> _markAsPaid(Bill bill) async {
    final updated = await _billService.markAsPaid(bill.id);
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Factura marcada como pagada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBills();
    }
  }

  // 📊 Facturas filtradas
  List<Bill> get _filteredBills {
    if (_filterStatus == 'all') return _bills;
    return _bills.where((b) => b.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Facturas'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // 🔄 Botón de recargar
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBills),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todas', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pendientes', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pagadas', 'paid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Vencidas', 'overdue'),
                ],
              ),
            ),
          ),
          // 📄 Lista de facturas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBills.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredBills.length,
                    itemBuilder: (context, index) {
                      final bill = _filteredBills[index];
                      return _buildBillCard(bill);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBillScreen()),
          );
          if (result == true) {
            _loadBills(); // Recargar si se agregó una factura
          }
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 🏷️ Chip de filtro
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[700],
      backgroundColor: Colors.grey[200],
    );
  }

  // 📄 Estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay facturas ${_filterStatus == 'all' ? '' : _filterStatus}',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para agregar una',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // 🃏 Tarjeta de factura
  Widget _buildBillCard(Bill bill) {
    final serviceName = bill.service?.name ?? 'Sin servicio';
    final categoryIcon = bill.category?.icon ?? '📌';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bill.statusColor.withOpacity(0.2),
          child: Text(categoryIcon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          serviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vence: ${bill.formattedDueDate}'),
            if (bill.description != null)
              Text(
                bill.description!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              bill.formattedAmount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bill.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bill.statusText,
                style: TextStyle(
                  fontSize: 10,
                  color: bill.statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          // TODO: Editar factura
        },
        onLongPress: () {
          // Menú de acciones al presionar largo
          _showActionMenu(bill);
        },
      ),
    );
  }

  // 📋 Menú de acciones
  void _showActionMenu(Bill bill) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bill.status != 'paid')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Marcar como pagada'),
                onTap: () {
                  Navigator.pop(context);
                  _markAsPaid(bill);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Editar factura
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.pop(context);
                _deleteBill(bill);
              },
            ),
          ],
        ),
      ),
    );
  }
}
