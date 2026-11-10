import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/gamification.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../utils/backup_download_stub.dart'
    if (dart.library.js_interop) '../utils/backup_download_web.dart'
    as web_backup;
import '../widgets/user_avatar.dart';
import 'admin_password_change_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/app_navigator.dart';

class AuthenticatedHomeScreen extends StatelessWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const LoginScreen();
    if (auth.isAdmin) {
      return auth.mustChangeAdminPassword
          ? const AdminPasswordChangeScreen()
          : const AdminScreen();
    }
    return const HomeScreen();
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _sections = [
    ('Resumen', Icons.space_dashboard_outlined),
    ('Usuarios', Icons.people_outline),
    ('Facturas', Icons.receipt_long_outlined),
    ('Gestión', Icons.tune_outlined),
    ('Backup', Icons.backup_outlined),
  ];
  int _selectedIndex = 0;
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    String? warning;
    try {
      await context.read<AuthProvider>().logout(revokeAllSessions: true);
    } catch (error) {
      warning =
          'La sesión local se cerró, pero no se pudo revocar todo: $error';
    }
    if (mounted) setState(() => _loggingOut = false);
    returnToLogin(message: warning);
  }

  Widget _selectedScreen() {
    switch (_selectedIndex) {
      case 1:
        return const _AdminUsersScreen();
      case 2:
        return const _AdminBillsScreen();
      case 3:
        return const _AdminManagementScreen();
      case 4:
        return const _AdminBackupScreen();
      default:
        return const _AdminDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const LoginScreen();
    if (!auth.isAdmin) return const HomeScreen();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        title: Text(wide ? 'Administración' : _sections[_selectedIndex].$1),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  user.name ?? 'Admin',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final section in _sections)
                  NavigationRailDestination(
                    icon: Icon(section.$2),
                    label: Text(section.$1),
                  ),
              ],
            ),
          Expanded(child: _selectedScreen()),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: [
                for (final section in _sections)
                  NavigationDestination(
                    icon: Icon(section.$2),
                    label: section.$1,
                  ),
              ],
            ),
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  final _service = AdminService();
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = _service.getDashboard();
  }

  void _reload() => setState(() => _data = _service.getDashboard());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminError(error: snapshot.error, onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final totalUsers = _asInt(data['totalUsers']);
        final activeUsers = _asInt(data['activeUsers']);
        final pending = _asInt(data['pendingBills']);
        final paid = _asInt(data['paidBills']);
        final overdue = _asInt(data['overdueBills']);
        final recent = _asMapList(data['recentUsers']);
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Resumen del sistema',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Datos actuales de usuarios y facturas de BillTracker.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.2 : 1.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MetricCard(
                        label: 'Usuarios registrados',
                        value: '$totalUsers',
                        icon: Icons.people_alt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'Activos (30 días)',
                        value: '$activeUsers',
                        icon: Icons.verified_user_outlined,
                        color: Colors.teal,
                      ),
                      _MetricCard(
                        label: 'Facturas totales',
                        value: '${_asInt(data['totalBills'])}',
                        icon: Icons.receipt_long_outlined,
                        color: Colors.indigo,
                      ),
                      _MetricCard(
                        label: 'Acciones administrativas',
                        value: '${_asInt(data['adminActions'])}',
                        icon: Icons.manage_history_outlined,
                        color: Colors.deepOrange,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de facturas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY:
                                [
                                  pending,
                                  paid,
                                  overdue,
                                  1,
                                ].reduce((a, b) => a > b ? a : b).toDouble() *
                                1.2,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    const labels = [
                                      'Pendientes',
                                      'Pagadas',
                                      'Vencidas',
                                    ];
                                    final index = value.toInt();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        index >= 0 && index < labels.length
                                            ? labels[index]
                                            : '',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            barGroups: [
                              _bar(0, pending, Colors.orange),
                              _bar(1, paid, Colors.green),
                              _bar(2, overdue, Colors.red),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _Legend(
                            label: 'Pendientes: $pending',
                            color: Colors.orange,
                          ),
                          _Legend(label: 'Pagadas: $paid', color: Colors.green),
                          _Legend(
                            label: 'Vencidas: $overdue',
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Registros recientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('Todavía no hay usuarios registrados.'),
                  ),
                )
              else
                for (final item in recent)
                  Card(
                    child: ListTile(
                      leading: UserAvatar(
                        name: item['name'] as String?,
                        imageUrl: item['avatar_url'] as String?,
                        radius: 21,
                      ),
                      title: Text((item['name'] as String?) ?? 'Usuario'),
                      subtitle: Text((item['email'] as String?) ?? ''),
                      trailing: Text(_formatDate(item['created_at'])),
                    ),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

BarChartGroupData _bar(int index, int value, Color color) {
  return BarChartGroupData(
    x: index,
    barRods: [
      BarChartRodData(
        toY: value.toDouble(),
        color: color,
        width: 34,
        borderRadius: BorderRadius.circular(5),
      ),
    ],
  );
}

class _AdminUsersScreen extends StatefulWidget {
  const _AdminUsersScreen();

  @override
  State<_AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<_AdminUsersScreen> {
  final _service = AdminService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  Object? _error;
  String _sort = 'created_at';
  final Set<String> _deletingUserIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getUsers(
        page: _page,
        search: _search.text,
        sortBy: _sort,
      );
      _users = _asMapList(result['rows']);
      _total = _asInt(result['total']);
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _details(Map<String, dynamic> user) async {
    try {
      final data = await _service.getUserDetails(user['id'] as String);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(data['user'] as Map);
      final bills = _asMapList(data['bills']);
      final badgeNames = {
        for (final badge in Gamification.getAvailableBadges())
          badge.id: badge.name,
      };
      final unlockedBadges = (profile['unlocked_badges'] as List? ?? const [])
          .map((id) => badgeNames[id] ?? id.toString())
          .join(', ');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text((profile['name'] as String?) ?? 'Detalle del usuario'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Correo: ${profile['email'] ?? '—'}'),
                  Text('Registro: ${_formatDate(profile['created_at'])}'),
                  Text(
                    'Último acceso: ${_formatDate(profile['lastSignInAt'])}',
                  ),
                  Text(
                    'Nivel: ${profile['level'] ?? 0} · Puntos: ${profile['points'] ?? 0}',
                  ),
                  Text(
                    'Insignias: ${unlockedBadges.isEmpty ? 'Ninguna' : unlockedBadges}',
                  ),
                  const Divider(height: 24),
                  Text('Facturas registradas (${data['billsTotal'] ?? 0})'),
                  for (final bill in bills)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${bill['status']} · ${bill['amount']} ${bill['currency'] ?? ''}',
                      ),
                      subtitle: Text('Vence ${_formatDate(bill['due_date'])}'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('No se pudieron cargar los detalles: $error');
    }
  }

  Future<void> _editUser([Map<String, dynamic>? user]) async {
    final nameController = TextEditingController(
      text: user?['name'] as String? ?? '',
    );
    final emailController = TextEditingController(
      text: user?['email'] as String? ?? '',
    );
    final passwordController = TextEditingController();
    var role = user?['isAdmin'] == true ? 'admin' : 'user';
    var saving = false;
    final canChangeRole =
        user == null || user['id'] != context.read<AuthProvider>().user?.id;
    Map<String, dynamic>? result;
    try {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(user == null ? 'Crear usuario' : 'Editar usuario'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    if (user == null)
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña temporal (opcional)',
                          helperText:
                              'Si se deja vacía, el sistema generará una segura.',
                        ),
                      ),
                    if (canChangeRole)
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: const [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('Usuario'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Administrador'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => role = value);
                                }
                              },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();
                        if (name.isEmpty ||
                            name.length > 100 ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email)) {
                          _showMessage('Ingresa un nombre y correo válidos.');
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          if (user == null) {
                            final created = await _service.createUser(
                              name: name,
                              email: email,
                              role: role,
                              temporaryPassword: passwordController.text.isEmpty
                                  ? null
                                  : passwordController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, {
                                ...created,
                                'created': true,
                              });
                            }
                          } else {
                            await _service.updateUser(
                              userId: user['id'] as String,
                              name: name,
                              email: email,
                              role: canChangeRole ? role : null,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, {'created': false});
                            }
                          }
                        } catch (error) {
                          _showMessage('No se pudo guardar el usuario: $error');
                          setDialogState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(user == null ? 'Crear' : 'Guardar'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      await _load();
      if (result['created'] == true && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Usuario creado'),
            content: SelectableText(
              'Cuenta: ${result!['email']}\n'
              'Contraseña temporal: ${result['temporaryPassword']}\n\n'
              'Guárdala y compártela con el usuario por un canal seguro. '
              'No volverá a mostrarse.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      } else {
        _showMessage('Usuario actualizado correctamente.');
      }
    } catch (error) {
      _showMessage('No se pudo guardar el usuario: $error');
    } finally {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['isActive'] != true;
    final confirmed = await _confirm(
      isActive ? 'Activar cuenta' : 'Desactivar cuenta',
      '¿Confirmas que quieres ${isActive ? 'activar' : 'desactivar'} la cuenta de ${user['email']}?',
    );
    if (!confirmed) return;
    try {
      await _service.setUserActive(user['id'] as String, isActive);
      await _load();
    } catch (error) {
      _showMessage('No se pudo cambiar el estado de la cuenta: $error');
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    if (_deletingUserIds.contains(userId)) return;
    final confirmed = await _confirm(
      'Eliminar cuenta y datos',
      'Esta acción eliminará la cuenta y sus facturas. No se puede deshacer. ¿Continuar?',
    );
    if (!confirmed) return;
    if (mounted) setState(() => _deletingUserIds.add(userId));
    try {
      await _service.deleteUser(userId);
      if (!mounted) return;
      setState(() {
        _users.removeWhere((item) => item['id'] == userId);
        if (_total > 0) _total--;
      });
      _showMessage('Usuario eliminado correctamente.');
      await _refreshAfterDelete();
    } catch (error) {
      await _reconcileDeleteError(userId, error);
    } finally {
      if (mounted) setState(() => _deletingUserIds.remove(userId));
    }
  }

  Future<void> _reconcileDeleteError(String userId, Object deleteError) async {
    try {
      final result = await _service.getUsers(
        page: _page,
        search: _search.text,
        sortBy: _sort,
      );
      if (!mounted) return;
      final users = _asMapList(result['rows']);
      final stillExists = users.any((user) => user['id'] == userId);
      setState(() {
        _users = users;
        _total = _asInt(result['total']);
        _error = null;
      });
      _showMessage(
        stillExists
            ? 'No se pudo eliminar la cuenta: $deleteError'
            : 'Usuario eliminado correctamente.',
      );
    } catch (refreshError) {
      _showMessage(
        'No se pudo confirmar la eliminación: $deleteError. '
        'Tampoco se pudo actualizar la lista: $refreshError',
      );
    }
  }

  Future<void> _refreshAfterDelete() async {
    try {
      final result = await _service.getUsers(
        page: _page,
        search: _search.text,
        sortBy: _sort,
      );
      if (!mounted) return;
      setState(() {
        _users = _asMapList(result['rows']);
        _total = _asInt(result['total']);
        _error = null;
      });
    } catch (error) {
      _showMessage(
        'El usuario fue eliminado, pero no se pudo actualizar la lista: $error',
      );
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _AdminError(error: _error, onRetry: _load);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Buscar nombre o correo',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: () {
                        _page = 0;
                        _load();
                      },
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                  onSubmitted: (_) {
                    _page = 0;
                    _load();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Crear usuario',
                onPressed: _loading ? null : () => _editUser(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Ordenar',
                initialValue: _sort,
                onSelected: (value) {
                  setState(() => _sort = value);
                  _load();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'created_at', child: Text('Registro')),
                  PopupMenuItem(value: 'name', child: Text('Nombre')),
                  PopupMenuItem(value: 'email', child: Text('Correo')),
                ],
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('$_total usuarios'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? const Center(child: Text('No se encontraron usuarios.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final active = user['isActive'] == true;
                      return Card(
                        child: ListTile(
                          onTap: _deletingUserIds.contains(user['id'])
                              ? null
                              : () => _details(user),
                          leading: UserAvatar(
                            name: user['name'] as String?,
                            imageUrl: user['avatar_url'] as String?,
                            radius: 22,
                          ),
                          title: Text(user['name'] as String? ?? 'Usuario'),
                          subtitle: Text(
                            '${user['email'] ?? ''}\n'
                            '${user['isAdmin'] == true ? 'Administrador' : 'Usuario'} · '
                            'Nivel ${user['level'] ?? 1} · ${user['points'] ?? 0} pts · '
                            '${(user['unlocked_badges'] as List? ?? const []).length} insignias\n'
                            'Registro: ${_formatDate(user['created_at'])} · '
                            '${active ? 'Activo' : 'Desactivado'}',
                          ),
                          isThreeLine: true,
                          trailing: _deletingUserIds.contains(user['id'])
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'details':
                                        _details(user);
                                      case 'edit':
                                        _editUser(user);
                                      case 'toggle':
                                        _toggleActive(user);
                                      case 'delete':
                                        _delete(user);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Text('Ver actividad'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar usuario'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        active ? 'Desactivar' : 'Activar',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar cuenta y datos'),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page == 0 || _loading
                    ? null
                    : () {
                        setState(() => _page--);
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Página ${_page + 1}'),
              IconButton(
                onPressed: (_page + 1) * 25 >= _total || _loading
                    ? null
                    : () {
                        setState(() => _page++);
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminBillsScreen extends StatefulWidget {
  const _AdminBillsScreen();

  @override
  State<_AdminBillsScreen> createState() => _AdminBillsScreenState();
}

class _AdminBillsScreenState extends State<_AdminBillsScreen> {
  final _service = AdminService();
  final _search = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _bills = [];
  String _status = '';
  String _sortBy = 'due_date';
  bool _ascending = true;
  bool _loading = true;
  Object? _error;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getBills(
        page: _page,
        search: _search.text,
        status: _status,
        sortBy: _sortBy,
        ascending: _ascending,
      );
      _bills = _asMapList(result['rows']);
      _total = _asInt(result['total']);
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editBill(Map<String, dynamic> bill) async {
    final amount = TextEditingController(text: '${bill['amount'] ?? ''}');
    var status = bill['status'] as String? ?? 'pending';
    final dueDate =
        (bill['due_date'] as String?)?.substring(0, 10) ??
        DateTime.now().toIso8601String().substring(0, 10);
    final selectedDate = TextEditingController(text: dueDate);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar factura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuario: ${(bill['user'] as Map?)?['email'] ?? '—'}'),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              TextField(
                controller: selectedDate,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Vencimiento'),
                onTap: () async {
                  final current =
                      DateTime.tryParse(selectedDate.text) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: current,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    selectedDate.text = picked.toIso8601String().substring(
                      0,
                      10,
                    );
                  }
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                  DropdownMenuItem(value: 'paid', child: Text('Pagada')),
                  DropdownMenuItem(value: 'overdue', child: Text('Vencida')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => status = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await _service.updateBill(
          billId: bill['id'] as String,
          amount: double.parse(amount.text),
          dueDate: selectedDate.text,
          status: status,
        );
        await _load();
      } catch (error) {
        _message('No se pudo actualizar la factura: $error');
      }
    }
    amount.dispose();
    selectedDate.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _AdminError(error: _error, onRetry: _load);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre de usuario, descripción o ID',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      _page = 0;
                      _load();
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  DropdownButton<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem(value: 'paid', child: Text('Pagadas')),
                      DropdownMenuItem(
                        value: 'overdue',
                        child: Text('Vencidas'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? '';
                        _page = 0;
                      });
                      _load();
                    },
                  ),
                  DropdownButton<String>(
                    value: _sortBy == 'amount'
                        ? (_ascending ? 'amount_asc' : 'amount_desc')
                        : 'due_date',
                    items: const [
                      DropdownMenuItem(
                        value: 'due_date',
                        child: Text('Ordenar: vencimiento'),
                      ),
                      DropdownMenuItem(
                        value: 'amount_asc',
                        child: Text('Monto: menor a mayor'),
                      ),
                      DropdownMenuItem(
                        value: 'amount_desc',
                        child: Text('Monto: mayor a menor'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sortBy = value == 'due_date' ? 'due_date' : 'amount';
                        _ascending = switch (value) {
                          'amount_asc' => true,
                          'amount_desc' => false,
                          _ => true,
                        };
                        _page = 0;
                      });
                      _load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('$_total facturas'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bills.isEmpty
              ? const Center(child: Text('No se encontraron facturas.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final owner = bill['user'] as Map?;
                    return Card(
                      child: ListTile(
                        title: Text(
                          (bill['description'] as String?)?.isNotEmpty == true
                              ? bill['description'] as String
                              : (bill['serviceName'] as String? ?? 'Factura'),
                        ),
                        subtitle: Text(
                          '${owner?['name'] ?? 'Usuario'} · ${owner?['email'] ?? '—'}\n'
                          '${bill['status']} · Vence ${_formatDate(bill['due_date'])} · ${bill['amount']} ${bill['currency'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Editar factura',
                          onPressed: () => _editBill(bill),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page == 0 || _loading
                    ? null
                    : () {
                        setState(() => _page--);
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Página ${_page + 1}'),
              IconButton(
                onPressed: (_page + 1) * 25 >= _total || _loading
                    ? null
                    : () {
                        setState(() => _page++);
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminAuditScreen extends StatefulWidget {
  const _AdminAuditScreen();

  @override
  State<_AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<_AdminAuditScreen> {
  late Future<Map<String, dynamic>> _data;
  final _service = AdminService();

  @override
  void initState() {
    super.initState();
    _data = _service.getAuditLogs();
  }

  void _reload() => setState(() => _data = _service.getAuditLogs());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminError(error: snapshot.error, onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = _asMapList(snapshot.data!['rows']);
        if (logs.isEmpty) {
          return const Center(
            child: Text('Todavía no hay acciones administrativas.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(_auditAction(log['action'] as String? ?? '')),
                  subtitle: Text(
                    'Objetivo: ${log['target_user_id'] ?? log['target_bill_id'] ?? '—'}\n'
                    '${_formatDate(log['created_at'])}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AdminBackupScreen extends StatefulWidget {
  const _AdminBackupScreen();

  @override
  State<_AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<_AdminBackupScreen> {
  final _service = AdminService();
  bool _isRunning = false;
  String _status = 'Aún no se ha generado un backup en esta sesión.';

  Future<void> _createAndDownloadBackup() async {
    setState(() {
      _isRunning = true;
      _status = 'Solicitando backup seguro…';
    });

    try {
      final backupId = await _service.startSystemBackup();
      Map<String, dynamic>? backup;
      for (var attempt = 0; attempt < 600; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        backup = await _service.getSystemBackupStatus(backupId);
        final status = backup['status'] as String?;
        if (status == 'failed') {
          throw StateError(
            backup['error'] as String? ??
                'El proceso de backup falló. Revisa GitHub Actions.',
          );
        }
        if (status == 'completed') break;

        setState(() {
          _status = status == 'running'
              ? 'Exportando la base de datos y empaquetando las funciones…'
              : 'El backup está en cola…';
        });
      }

      if (backup == null || backup['status'] != 'completed') {
        throw TimeoutException(
          'El backup tardó más de 30 minutos. Revisa GitHub Actions antes de volver a intentarlo.',
        );
      }

      final url = backup['downloadUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw const FormatException(
          'El backup terminó, pero no se recibió el enlace de descarga.',
        );
      }

      setState(() => _status = 'Descargando el backup…');
      final bytes = await _service.downloadSystemBackup(url);
      if (!mounted) return;

      final fileName =
          backup['fileName'] as String? ??
          'billtracker-backup-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.zip';
      final String? savedFile;
      if (kIsWeb) {
        web_backup.downloadBackup(bytes, fileName);
        savedFile = fileName;
      } else if (Platform.isAndroid) {
        savedFile = await const MethodChannel(
          'billtracker/backup',
        ).invokeMethod<String>('saveBackup', {
          'fileName': fileName,
          'bytes': bytes,
        });
      } else {
        savedFile = await FilePicker.saveFile(
          dialogTitle: 'Elige dónde guardar el backup de BillTracker',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['zip'],
          bytes: bytes,
        );
      }
      if (!mounted) return;

      setState(() {
        _status = savedFile == null
            ? 'El backup se generó, pero se canceló la selección de ubicación.'
            : 'Backup descargado correctamente.';
      });
      if (savedFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup guardado correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'No se pudo completar el backup.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear el backup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Backup del sistema',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Genera una copia descargable de la base de datos pública (estructura, datos, funciones SQL, triggers y políticas) y del código de las Edge Functions.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No incluye cuentas de Supabase Auth, archivos de Storage (como fotos), ni secretos del proyecto.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'El archivo contiene datos privados. En la app podrás elegir dónde guardarlo. En web, la ubicación depende de la configuración de descargas del navegador; activa "Preguntar dónde guardar cada archivo" para elegirla.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isRunning) ...[
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(_status)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _isRunning ? null : _createAndDownloadBackup,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              _isRunning ? 'Creando backup…' : 'Crear y descargar backup',
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminSettingsScreen extends StatefulWidget {
  const _AdminSettingsScreen();

  @override
  State<_AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<_AdminSettingsScreen> {
  final _service = AdminService();
  final _announcement = TextEditingController();
  Timer? _noticeExpiryTimer;
  String? _activeAnnouncement;
  DateTime? _activeAnnouncementExpiresAt;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noticeExpiryTimer?.cancel();
    _announcement.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _service.getSettings();
      _setActiveAnnouncement(
        settings['announcement'] as String?,
        settings['updatedAt'],
      );
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _setActiveAnnouncement(String? message, Object? updatedAt) {
    _noticeExpiryTimer?.cancel();
    final trimmedMessage = message?.trim();
    final publishedAt = updatedAt is String
        ? DateTime.tryParse(updatedAt)?.toLocal()
        : null;
    if (trimmedMessage == null ||
        trimmedMessage.isEmpty ||
        publishedAt == null) {
      _activeAnnouncement = null;
      _activeAnnouncementExpiresAt = null;
      return;
    }

    final expiresAt = publishedAt.add(const Duration(hours: 24));
    if (!expiresAt.isAfter(DateTime.now())) {
      _activeAnnouncement = null;
      _activeAnnouncementExpiresAt = null;
      return;
    }

    _activeAnnouncement = trimmedMessage;
    _activeAnnouncementExpiresAt = expiresAt;
    _noticeExpiryTimer = Timer(expiresAt.difference(DateTime.now()), () {
      if (!mounted) return;
      setState(() {
        _activeAnnouncement = null;
        _activeAnnouncementExpiresAt = null;
      });
      _load();
    });
  }

  Future<void> _save() async {
    final message = _announcement.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el aviso antes de guardarlo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.updateAnnouncement(message);
      _announcement.clear();
      _setActiveAnnouncement(message, result['updatedAt']);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso del sistema publicado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar la configuración: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteActiveAnnouncement() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar aviso activo'),
        content: const Text(
          'El aviso dejará de mostrarse en el dashboard de los usuarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _service.updateAnnouncement('');
      _noticeExpiryTimer?.cancel();
      if (mounted) {
        setState(() {
          _activeAnnouncement = null;
          _activeAnnouncementExpiresAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso activo eliminado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el aviso: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _AdminError(error: _error, onRetry: _load);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Configuración del sistema',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Publica un aviso operativo que aparecerá en el dashboard durante 24 horas. Un aviso nuevo reemplaza al actual; también puedes eliminarlo antes.',
        ),
        const SizedBox(height: 20),
        if (_activeAnnouncement != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aviso activo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _deleteActiveAnnouncement,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_activeAnnouncement!),
                  if (_activeAnnouncementExpiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Expira ${DateFormat('dd/MM/yyyy HH:mm').format(_activeAnnouncementExpiresAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _announcement,
          maxLength: 500,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Aviso para los usuarios',
            hintText: 'Escribe un aviso del sistema…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Guardar aviso'),
          ),
        ),
      ],
    );
  }
}

class _AdminManagementScreen extends StatelessWidget {
  const _AdminManagementScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Aviso del sistema', icon: Icon(Icons.info_outline)),
                Tab(text: 'Catálogo', icon: Icon(Icons.category_outlined)),
                Tab(text: 'Comunicados', icon: Icon(Icons.campaign_outlined)),
                Tab(text: 'Auditoría', icon: Icon(Icons.history_outlined)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AdminSettingsScreen(),
                _AdminCatalogScreen(),
                _AdminAnnouncementsScreen(),
                _AdminAuditScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCatalogScreen extends StatefulWidget {
  const _AdminCatalogScreen();

  @override
  State<_AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<_AdminCatalogScreen> {
  final _service = AdminService();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  bool _showServices = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getCatalog('service'),
        _service.getCatalog('category'),
      ]);
      _services = results[0];
      _categories = results[1];
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editItem([String? entity, Map<String, dynamic>? item]) async {
    final selectedEntity = entity ?? (_showServices ? 'service' : 'category');
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final description = TextEditingController(
      text: item?['description'] as String? ?? '',
    );
    final price = TextEditingController(text: item?['price']?.toString() ?? '');
    final icon = TextEditingController(text: item?['icon'] as String? ?? '');
    final color = TextEditingController(
      text: item?['color'] as String? ?? '#3D7A6B',
    );
    var categoryId = item?['category_id'] as String?;
    var isActive = item?['is_active'] != false;
    var saving = false;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              item == null
                  ? 'Crear ${selectedEntity == 'service' ? 'servicio' : 'categoría'}'
                  : 'Editar ${selectedEntity == 'service' ? 'servicio' : 'categoría'}',
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: description,
                      maxLength: 1000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    if (selectedEntity == 'service') ...[
                      TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio de referencia (opcional)',
                        ),
                      ),
                      DropdownButtonFormField<String?>(
                        initialValue: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin categoría'),
                          ),
                          for (final category in _categories.where(
                            (entry) => entry['is_active'] != false,
                          ))
                            DropdownMenuItem<String?>(
                              value: category['id'] as String,
                              child: Text(category['name'] as String),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => categoryId = value),
                      ),
                    ] else ...[
                      TextField(
                        controller: icon,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'Icono o emoji (opcional)',
                        ),
                      ),
                      TextField(
                        controller: color,
                        decoration: const InputDecoration(
                          labelText: 'Color hexadecimal',
                          hintText: '#3D7A6B',
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('El nombre es obligatorio.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _service.saveCatalogItem(
                            entity: selectedEntity,
                            id: item?['id'] as String?,
                            name: name.text.trim(),
                            description: description.text.trim(),
                            isActive: isActive,
                            icon: selectedEntity == 'category'
                                ? icon.text.trim()
                                : null,
                            color: selectedEntity == 'category'
                                ? color.text.trim()
                                : null,
                            categoryId: selectedEntity == 'service'
                                ? categoryId
                                : null,
                            price: selectedEntity == 'service'
                                ? price.text.trim()
                                : null,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo guardar el elemento: $error',
                                ),
                              ),
                            );
                          }
                          setDialogState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) {
        await _load();
        _message('Elemento del catálogo guardado correctamente.');
      }
    } finally {
      name.dispose();
      description.dispose();
      price.dispose();
      icon.dispose();
      color.dispose();
    }
  }

  Future<void> _setActive(String entity, Map<String, dynamic> item) async {
    try {
      await _service.setCatalogItemActive(
        entity: entity,
        id: item['id'] as String,
        isActive: item['is_active'] == false,
      );
      await _load();
    } catch (error) {
      _message('No se pudo cambiar el estado: $error');
    }
  }

  Future<void> _delete(String entity, Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar elemento'),
        content: Text(
          '¿Eliminar "${item['name']}"? Si está asociado a facturas, primero debes desactivarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteCatalogItem(
        entity: entity,
        id: item['id'] as String,
      );
      await _load();
      _message('Elemento eliminado correctamente.');
    } catch (error) {
      _message('No se pudo eliminar: $error');
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entity = _showServices ? 'service' : 'category';
    final items = _showServices ? _services : _categories;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Servicios'),
                    icon: Icon(Icons.receipt_long_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Categorías'),
                    icon: Icon(Icons.category_outlined),
                  ),
                ],
                selected: {_showServices},
                onSelectionChanged: (value) =>
                    setState(() => _showServices = value.first),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading ? null : () => _editItem(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _AdminError(error: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text('No hay elementos en el catálogo.'),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = item['is_active'] != false;
                            final details = selectedEntityDescription(
                              _showServices,
                              item,
                            );
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    _showServices
                                        ? Icons.receipt_long_outlined
                                        : Icons.category_outlined,
                                  ),
                                ),
                                title: Text(item['name'] as String? ?? ''),
                                subtitle: Text(
                                  '$details · ${active ? 'Activo' : 'Inactivo'}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _editItem(entity, item);
                                    } else if (action == 'toggle') {
                                      _setActive(entity, item);
                                    } else {
                                      _delete(entity, item);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        active ? 'Desactivar' : 'Activar',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  String selectedEntityDescription(bool isService, Map<String, dynamic> item) {
    if (!isService) return item['description'] as String? ?? 'Categoría';
    final price = item['price'];
    final category = _categories.cast<Map<String, dynamic>?>().firstWhere(
      (entry) => entry?['id'] == item['category_id'],
      orElse: () => null,
    );
    final pieces = <String>[
      if (price != null) 'Precio: $price',
      if (category != null) 'Categoría: ${category['name']}',
      if ((item['description'] as String?)?.isNotEmpty == true)
        item['description'] as String,
    ];
    return pieces.isEmpty ? 'Servicio' : pieces.join(' · ');
  }
}

class _AdminAnnouncementsScreen extends StatefulWidget {
  const _AdminAnnouncementsScreen();

  @override
  State<_AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<_AdminAnnouncementsScreen> {
  final _service = AdminService();
  final _title = TextEditingController();
  final _message = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _announcements = [];
  final Set<String> _selectedUsers = {};
  bool _allUsers = true;
  bool _loading = true;
  bool _publishing = false;
  Object? _error;
  String _userSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getRecipientUsers(),
        _service.getAnnouncements(),
      ]);
      _users = results[0];
      _announcements = results[1];
      _selectedUsers.removeWhere(
        (id) => !_users.any((user) => user['id'] == id),
      );
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      _showMessage('Completa el título y el mensaje.');
      return;
    }
    if (!_allUsers && _selectedUsers.isEmpty) {
      _showMessage('Selecciona al menos un destinatario.');
      return;
    }
    setState(() => _publishing = true);
    try {
      await _service.publishAnnouncement(
        title: _title.text.trim(),
        message: _message.text.trim(),
        allUsers: _allUsers,
        userIds: _selectedUsers.toList(),
      );
      _title.clear();
      _message.clear();
      await _load();
      _showMessage('Comunicado publicado y notificaciones creadas.');
    } catch (error) {
      _showMessage('No se pudo publicar el comunicado: $error');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _AdminError(error: _error, onRetry: _load);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filteredUsers = _users.where((user) {
      final needle = _userSearch.trim().toLowerCase();
      if (needle.isEmpty) return true;
      return '${user['name'] ?? ''} ${user['email'] ?? ''}'
          .toLowerCase()
          .contains(needle);
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Publicar comunicado',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          TextField(
            controller: _message,
            maxLength: 5000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              alignLabelWithHint: true,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enviar a todos los usuarios'),
            value: _allUsers,
            onChanged: (value) => setState(() => _allUsers = value),
          ),
          if (!_allUsers) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar destinatarios',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _userSearch = value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: Card(
                child: filteredUsers.isEmpty
                    ? const Center(child: Text('No hay usuarios coincidentes.'))
                    : ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final id = user['id'] as String;
                          return CheckboxListTile(
                            value: _selectedUsers.contains(id),
                            title: Text(user['name'] as String? ?? 'Usuario'),
                            subtitle: Text(user['email'] as String? ?? ''),
                            onChanged: (selected) => setState(() {
                              if (selected == true) {
                                _selectedUsers.add(id);
                              } else {
                                _selectedUsers.remove(id);
                              }
                            }),
                          );
                        },
                      ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selectedUsers.length} destinatario(s) elegido(s)',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Publicar y notificar'),
            ),
          ),
          const Divider(height: 36),
          Text(
            'Historial de comunicados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_announcements.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavía no se han publicado comunicados.'),
              ),
            ),
          for (final announcement in _announcements)
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(announcement['title'] as String? ?? ''),
                subtitle: Text(
                  '${announcement['message'] ?? ''}\n'
                  '${_formatDate(announcement['published_at'])} · '
                  '${announcement['recipient_count'] ?? 0} destinatarios · '
                  'Correo: ${announcement['emailSent'] ?? 0} enviados, '
                  '${announcement['emailPending'] ?? 0} pendientes, '
                  '${announcement['emailFailed'] ?? 0} fallidos',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'No se pudieron cargar los datos administrativos.\n$error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

int _asInt(Object? value) => value is num ? value.toInt() : 0;

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

String _formatDate(Object? value) {
  if (value is! String || value.isEmpty) return '—';
  final date = DateTime.tryParse(value);
  if (date == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

String _auditAction(String action) => switch (action) {
  'initial_password_changed' => 'Contraseña inicial cambiada',
  'user_name_updated' => 'Nombre de usuario actualizado',
  'user_updated' => 'Datos o rol de usuario actualizados',
  'user_created' => 'Usuario creado',
  'user_enabled' => 'Cuenta de usuario activada',
  'user_disabled' => 'Cuenta de usuario desactivada',
  'user_deleted' => 'Cuenta y datos de usuario eliminados',
  'bill_updated' => 'Factura modificada',
  'system_announcement_updated' => 'Aviso del sistema actualizado',
  'catalog_item_created' => 'Elemento de catálogo creado',
  'catalog_item_updated' => 'Elemento de catálogo modificado',
  'catalog_item_deleted' => 'Elemento de catálogo eliminado',
  'catalog_item_status_changed' => 'Estado de catálogo modificado',
  'announcement_published' => 'Comunicado publicado',
  _ => action,
};
