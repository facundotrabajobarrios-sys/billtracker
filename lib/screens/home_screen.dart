import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// 🏠 Pantalla de inicio (dashboard)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillTracker'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // 🚪 Botón de cerrar sesión
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              // Volver al Login
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
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
              '¡Hola ${authProvider.user?.name ?? 'Usuario'}! 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nivel: ${authProvider.user?.level ?? 0} | Puntos: ${authProvider.user?.points ?? 0}',
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
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Facturas'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Logros',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.green[700],
        onTap: (index) {
          // Aquí navegaremos después
        },
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
}
