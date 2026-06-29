import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/bill_service.dart';
import '../services/notification_service.dart';
import '../models/bill.dart';
import 'bills_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

// 🏠 Pantalla principal con navegación inferior
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 📋 Lista de pantallas
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const _HomeContent(),
      const BillsScreen(),
      const AchievementsScreen(),
      const ProfileScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Facturas'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Logros',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// 📊 Contenido del Dashboard
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final _billService = BillService();
  final _notiService = NotificationService();

  // 📊 Datos del dashboard
  int _pending = 0;
  int _paid = 0;
  int _overdue = 0;
  int _total = 0;
  List<Bill> _upcomingBills = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
  }

  // 📥 Cargar datos
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      try {
        final summary = await _billService.getSummary(userId);
        _pending = summary['pending'] ?? 0;
        _paid = summary['paid'] ?? 0;
        _overdue = summary['overdue'] ?? 0;
        _total = summary['total'] ?? 0;

        final bills = await _billService.getBills(userId);
        _upcomingBills = bills
            .where((b) => b.status != 'paid')
            .take(3)
            .toList();
      } catch (e) {
        print('❌ Error cargando datos: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  // 🔔 Cargar notificaciones no leídas
  Future<void> _loadUnreadCount() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      _unreadCount = await _notiService.countUnread(userId);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillTracker'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // 🔔 Notificaciones con contador
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              _loadUnreadCount();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadData();
                await _loadUnreadCount();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👋 Saludo
                    Text(
                      '¡Hola ${user?.name ?? 'Usuario'}! 👋',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nivel: ${user?.level ?? 0} | Puntos: ${user?.points ?? 0}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // 📊 Tarjetas de resumen
                    Row(
                      children: [
                        _buildCard(
                          'Pendientes',
                          _pending,
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                        const SizedBox(width: 12),
                        _buildCard(
                          'Pagadas',
                          _paid,
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildCard(
                          'Vencidas',
                          _overdue,
                          Colors.red,
                          Icons.warning,
                        ),
                        const SizedBox(width: 12),
                        _buildCard(
                          'Total',
                          _total,
                          Colors.blue,
                          Icons.receipt_long,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 📋 Próximos vencimientos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📋 Próximos vencimientos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final homeState = context
                                .findAncestorStateOfType<_HomeScreenState>();
                            homeState?.setState(() {
                              homeState._selectedIndex = 1;
                            });
                          },
                          child: const Text(
                            'Ver todas',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _upcomingBills.isEmpty
                          ? const Center(
                              child: Text(
                                '🎉 No hay facturas próximas',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _upcomingBills.length,
                              itemBuilder: (_, i) =>
                                  _buildBillItem(_upcomingBills[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🃏 Tarjeta de resumen
  Widget _buildCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🃏 Item de factura próxima
  Widget _buildBillItem(Bill bill) {
    final serviceName = bill.service?.name ?? 'Sin servicio';
    final categoryIcon = bill.category?.icon ?? '📌';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bill.statusColor.withOpacity(0.2),
          child: Text(categoryIcon, style: const TextStyle(fontSize: 16)),
        ),
        title: Text(
          serviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Vence: ${bill.formattedDueDate}'),
        trailing: Text(
          bill.formattedAmount,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
