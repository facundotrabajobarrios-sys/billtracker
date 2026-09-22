// ignore_for_file: unused_import

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/auth_provider.dart';
import '../services/bill_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
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

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const _HomeContent();
      case 1:
        return const BillsScreen();
      case 2:
        return const AchievementsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const _HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screenForIndex(_selectedIndex),
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

  int _pending = 0;
  int _paid = 0;
  int _overdue = 0;
  int _total = 0;
  List<Bill> _allBills = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  // Filtros: por defecto últimos 30 días
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _loadData();
    _loadUnreadCount();
  }

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
        _allBills = bills;
      } catch (e) {
        print('❌ Error cargando datos: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadUnreadCount() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      _unreadCount = await _notiService.countUnread(userId);
      setState(() {});
    }
  }

  List<Bill> get _filteredBills {
    return _allBills.where((b) {
      final due = b.dueDate;
      final inRange =
          (due.isAtSameMomentAs(_startDate) || due.isAfter(_startDate)) &&
          (due.isAtSameMomentAs(_endDate) || due.isBefore(_endDate));
      final matchesCategory =
          _selectedCategory == null || b.category?.name == _selectedCategory;
      return inRange && matchesCategory;
    }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Datos agrupados por mes (últimos 6 meses)
  List<double> get _monthlySpending {
    final now = DateTime.now();
    const months = 6;
    final List<double> sums = List.filled(months, 0.0);

    for (int i = 0; i < months; i++) {
      final m = DateTime(now.year, now.month - (months - 1 - i), 1);
      final monthStart = DateTime(m.year, m.month, 1);
      final monthEnd = DateTime(
        m.year,
        m.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
      final total = _allBills
          .where((b) {
            return b.dueDate.isAfter(
                  monthStart.subtract(const Duration(seconds: 1)),
                ) &&
                b.dueDate.isBefore(monthEnd.add(const Duration(seconds: 1)));
          })
          .fold<double>(0.0, (prev, b) => prev + (b.amount ?? 0.0));
      sums[i] = total;
    }

    return sums;
  }

  List<String> get _monthlyLabels {
    final now = DateTime.now();
    const months = 6;
    return List.generate(months, (i) {
      final m = DateTime(now.year, now.month - (months - 1 - i), 1);
      return DateFormat('MMM').format(m);
    });
  }

  Widget _buildMonthlyBarChart() {
    final data = _monthlySpending;
    final labels = _monthlyLabels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (data.isNotEmpty
                ? (data.reduce((a, b) => a > b ? a : b) * 1.2)
                : 100.0),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox();
                    }
                    return Text(
                      labels[index],
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
            ),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(toY: data[i], color: Colors.green, width: 14),
                ],
              );
            }),
            gridData: FlGridData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyLineChart() {
    final data = _monthlySpending;
    final labels = _monthlyLabels;

    final spots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i]),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (data.isNotEmpty
                ? (data.reduce((a, b) => a > b ? a : b) * 1.2)
                : 100.0),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox();
                    }
                    return Text(
                      labels[index],
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
            ],
            gridData: FlGridData(show: false),
          ),
        ),
      ),
    );
  }

  // Genera CSV simple a partir de los bills filtrados y lo copia al portapapeles
  Future<void> _exportCsvToClipboard() async {
    final bills = _filteredBills;
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('id,service,category,due_date,amount,status');
    for (final b in bills) {
      final id = b.id;
      final service = b.service?.name.replaceAll(',', ' ') ?? '';
      final category = b.category?.name.replaceAll(',', ' ') ?? '';
      final due = DateFormat('yyyy-MM-dd').format(b.dueDate);
      final amount = b.amount.toStringAsFixed(2);
      final status = b.status;
      buffer.writeln('$id,$service,$category,$due,$amount,$status');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copiado al portapapeles')),
    );
  }

  // Genera un PDF sencillo con los bills filtrados y abre el diálogo para compartir
  Future<void> _exportPdfAndShare() async {
    final bills = _filteredBills;
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Resumen de facturas',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Paragraph(
              text:
                  'Periodo: ${DateFormat('yyyy-MM-dd').format(_startDate)} — ${DateFormat('yyyy-MM-dd').format(_endDate)}',
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'ID',
                'Servicio',
                'Categoría',
                'Vence',
                'Monto',
                'Estado',
              ],
              data: bills
                  .map(
                    (b) => [
                      b.id,
                      b.service?.name ?? '',
                      b.category?.name ?? '',
                      DateFormat('yyyy-MM-dd').format(b.dueDate),
                      b.amount.toStringAsFixed(2),
                      b.status,
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Paragraph(
              text:
                  'Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
          ];
        },
      ),
    );

    final pdfBytes = await doc.save();

    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'billtracker_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      // Fallback: guardar en portapapeles como base64 (no ideal) o mostrar error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error compartiendo PDF: $e')));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    // Datos para la gráfica (pie simple)
    final pendingCount = _allBills.where((b) => b.status == 'pending').length;
    final paidCount = _allBills.where((b) => b.status == 'paid').length;
    final overdueCount = _allBills
        .where((b) => b.status == 'overdue' || b.isOverdue)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillTracker'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
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
              // Usar ListView para evitar BottomOverflow y permitir desplazamiento
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                  const SizedBox(height: 16),

                  // Filtros y Export
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickStartDate,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Desde: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickEndDate,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hasta: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _exportCsvToClipboard,
                            icon: const Icon(Icons.download),
                            label: const Text('Export CSV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _exportPdfAndShare,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Cards
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

                  const Text(
                    'Facturas pendientes vs pagadas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: pendingCount.toDouble(),
                                  color: Colors.orange,
                                  title: pendingCount.toString(),
                                  radius: 50,
                                ),
                                PieChartSectionData(
                                  value: paidCount.toDouble(),
                                  color: Colors.green,
                                  title: paidCount.toString(),
                                  radius: 50,
                                ),
                                PieChartSectionData(
                                  value: overdueCount.toDouble(),
                                  color: Colors.red,
                                  title: overdueCount.toString(),
                                  radius: 50,
                                ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Evolución de pagos mensuales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: 200, child: _buildMonthlyBarChart()),
                  const SizedBox(height: 12),
                  const Text(
                    'Tendencia del gasto mensual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: 180, child: _buildMonthlyLineChart()),

                  const SizedBox(height: 20),

                  // Próximos vencimientos
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

                  const SizedBox(height: 8),

                  _filteredBills.isEmpty
                      ? const Text(
                          '🎉 No hay facturas en el periodo seleccionado',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Column(
                          children: _filteredBills
                              .map((b) => _buildBillItem(b))
                              .toList(),
                        ),
                ],
              ),
            ),
    );
  }

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
