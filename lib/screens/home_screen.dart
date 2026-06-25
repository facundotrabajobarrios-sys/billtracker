import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'bills_screen.dart';
import '../services/notification_service.dart';
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

  static const List<Widget> _screens = [
    _HomeContent(),
    BillsScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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

// 📊 Contenido de la pantalla de inicio (Dashboard)
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  // 🔔 Stream de notificaciones no leídas
  Stream<int> _getUnreadCountStream(BuildContext context) async* {
    // ✅ Recibe context
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      final notificationService = NotificationService();
      while (true) {
        final count = await notificationService.countUnread(userId);
        yield count;
        await Future.delayed(const Duration(seconds: 10));
      }
    }
    yield 0;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillTracker'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // 🔔 Botón de notificaciones con contador
          StreamBuilder<int>(
            stream: _getUnreadCountStream(context), // ✅ Pasas context
            initialData: 0,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
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
                          count > 99 ? '99+' : '$count',
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
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Saludo
            Text(
              '¡Hola ${user?.name ?? 'Usuario'}! 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nivel: ${user?.level ?? 0} | Puntos: ${user?.points ?? 0}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 📊 Tarjetas de resumen
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Pendientes',
                    '5',
                    Colors.orange,
                    Icons.pending_actions,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Pagadas',
                    '12',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Vencidas',
                    '2',
                    Colors.red,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total',
                    '19',
                    Colors.blue,
                    Icons.receipt_long,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              '📋 Próximos vencimientos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 📄 Lista de facturas próximas (ejemplo)
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.lightbulb, color: Colors.amber),
                    title: Text('Factura de Luz'),
                    subtitle: Text('Vence: 25/06/2026'),
                    trailing: Text('₲ 120.000'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.water, color: Colors.blue),
                    title: Text('Factura de Agua'),
                    subtitle: Text('Vence: 28/06/2026'),
                    trailing: Text('₲ 85.000'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.wifi, color: Colors.purple),
                    title: Text('Internet'),
                    subtitle: Text('Vence: 30/06/2026'),
                    trailing: Text('₲ 150.000'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🃏 Widget para tarjetas de resumen
  Widget _buildSummaryCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Card(
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
              count,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
} // aqui termina la clase _HomeContent
