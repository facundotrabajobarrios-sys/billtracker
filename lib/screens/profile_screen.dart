import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/theme_provider.dart';
import '../services/bill_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _billService = BillService();
  int _totalBills = 0;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userId = context.read<AuthProvider>().user?.id;
    _loadError = null;
    try {
      if (userId != null) {
        await context.read<GamificationProvider>().loadGamification(userId);
        final summary = await _billService.getSummary(userId);
        _totalBills = summary['total'] ?? 0;
      }
    } catch (error) {
      _loadError = 'No se pudo cargar el perfil: $error';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (_loadError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loadError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final gamification = context.watch<GamificationProvider>().gamification;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  child: Text(
                    user?.name?.isNotEmpty == true
                        ? user!.name![0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 40, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user?.name ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(child: Text(user?.email ?? '')),
                const SizedBox(height: 24),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      theme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: const Text('Modo oscuro'),
                    subtitle: const Text(
                      'Usar una apariencia oscura en la aplicación',
                    ),
                    value: theme.isDarkMode,
                    onChanged: theme.setDarkMode,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat(
                          'Nivel',
                          '${gamification?.currentLevel ?? user?.level ?? 0}',
                        ),
                        _stat(
                          'Puntos',
                          '${gamification?.totalPoints ?? user?.points ?? 0}',
                        ),
                        _stat('Facturas', '$_totalBills'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: user == null ? null : _confirmDeleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Eliminar cuenta'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await auth.logout();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                ),
              ],
            ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(value, style: const TextStyle(fontSize: 24, color: Colors.green)),
      Text(label),
    ],
  );

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
      );
    }
  }
}
