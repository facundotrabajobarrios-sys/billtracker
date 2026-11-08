// ignore_for_file: unused_import

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/auth_provider.dart';
import '../providers/gamification_provider.dart';
import '../services/bill_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../models/bill.dart';
import '../utils/bill_report_filter.dart';
import 'bills_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import '../widgets/user_avatar.dart';

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
        return const ReportsScreen();
      case 3:
        return const AchievementsScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const _HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: isWide
          ? Row(
              children: [
                _buildSidebar(context),
                Expanded(child: _screenForIndex(_selectedIndex)),
              ],
            )
          : _screenForIndex(_selectedIndex),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Facturas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Reportes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events),
                  label: 'Logros',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    const destinations = [
      (Icons.space_dashboard_outlined, 'Panel'),
      (Icons.receipt_long_outlined, 'Facturas'),
      (Icons.bar_chart_outlined, 'Reportes'),
      (Icons.emoji_events_outlined, 'Logros'),
      (Icons.person_outline, 'Perfil'),
    ];

    return Container(
      width: 244,
      color: const Color(0xFF0B3028),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/icons/billtracker.png',
                  width: 36,
                  height: 36,
                  semanticLabel: 'BillTracker',
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'BillTracker',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 10),
            child: Text(
              'MENÚ',
              style: TextStyle(
                color: Color(0xFF9AB7AE),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: InkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == index
                        ? const Color(0xFF174B40)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        destinations[index].$1,
                        size: 19,
                        color: _selectedIndex == index
                            ? const Color(0xFF68D4B5)
                            : const Color(0xFFD4E4DF),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        destinations[index].$2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: _selectedIndex == index
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          const Divider(color: Color(0xFF254A40), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              UserAvatar(
                name: user?.name,
                imageUrl: user?.avatarUrl,
                radius: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Usuario',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Cuenta personal',
                      style: TextStyle(color: Color(0xFF9AB7AE), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  String? _loadError;
  String? _systemAnnouncement;
  Timer? _systemNoticeExpiryTimer;

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
    _loadSystemAnnouncement();
  }

  Future<void> _loadSystemAnnouncement() async {
    try {
      final notice = await _notiService.getActiveSystemNotice();
      if (!mounted) return;
      _systemNoticeExpiryTimer?.cancel();
      setState(() {
        _systemAnnouncement = notice?['message'] as String?;
      });
      final secondsRemaining = notice?['expires_in_seconds'] as int?;
      if (_systemAnnouncement != null &&
          secondsRemaining != null &&
          secondsRemaining > 0) {
        _systemNoticeExpiryTimer = Timer(
          Duration(seconds: secondsRemaining),
          () {
            if (mounted) setState(() => _systemAnnouncement = null);
          },
        );
      }
    } catch (error) {
      debugPrint('No se pudo cargar el aviso del sistema: $error');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      try {
        await context.read<GamificationProvider>().loadGamification(
          userId,
          silent: true,
        );
        final summary = await _billService.getSummary(userId);
        _pending = summary['pending'] ?? 0;
        _paid = summary['paid'] ?? 0;
        _overdue = summary['overdue'] ?? 0;
        _total = summary['total'] ?? 0;

        final bills = await _billService.getBills(userId);
        _allBills = bills;
        try {
          await PushNotificationService().reconcileBillReminders(bills);
        } catch (error) {
          debugPrint(
            'No se pudieron restaurar los recordatorios locales: $error',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudieron activar los recordatorios del dispositivo: '
                  '$error',
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error cargando el resumen financiero: $e');
        _loadError = 'No se pudieron cargar tus facturas: $e';
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadUnreadCount() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      _unreadCount = await _notiService.countUnread(userId);
      if (!mounted) return;
      setState(() {});
    }
  }

  List<Bill> get _filteredBills {
    return filterBillsForReport(
      _allBills,
      startDate: _startDate,
      endDate: _endDate,
      category: _selectedCategory,
    );
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
          .fold<double>(0.0, (prev, b) => prev + b.amount);
      sums[i] = total;
    }

    return sums;
  }

  List<String> get _monthlyLabels {
    final now = DateTime.now();
    const months = 6;
    return List.generate(months, (i) {
      final m = DateTime(now.year, now.month - (months - 1 - i), 1);
      return const [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ][m.month - 1];
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
            maxY: _chartMaxY(data),
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
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, _) => Text(
                    _compactAmount(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i],
                    color: const Color(0xFF087F63),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ],
              );
            }),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
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
            maxY: _chartMaxY(data),
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
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, _) => Text(
                    _compactAmount(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF4386D8),
                barWidth: 3,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF4386D8).withValues(alpha: 0.1),
                ),
              ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
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
    if (!mounted) return;
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
      if (!mounted) return;
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
  void dispose() {
    _systemNoticeExpiryTimer?.cancel();
    super.dispose();
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
        title: Row(
          children: [
            Image.asset(
              'assets/icons/billtracker.png',
              width: 32,
              height: 32,
              semanticLabel: 'Logo de BillTracker',
            ),
            const SizedBox(width: 10),
            const Text('BillTracker'),
          ],
        ),
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
              _loadSystemAnnouncement();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadData();
                await _loadUnreadCount();
                await _loadSystemAnnouncement();
              },
              // Usar ListView para evitar BottomOverflow y permitir desplazamiento
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            name: user?.name,
                            imageUrl: user?.avatarUrl,
                            radius: 25,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, ${user?.name ?? 'Usuario'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Aquí tienes el resumen de tus facturas y pagos.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_systemAnnouncement != null) ...[
                        const SizedBox(height: 18),
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.campaign_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _systemAnnouncement!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Filtros y Export
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickStartDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              'Desde ${DateFormat('dd/MM/yyyy').format(_startDate)}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickEndDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              'Hasta ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _exportCsvToClipboard,
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Exportar CSV'),
                          ),
                          FilledButton.icon(
                            onPressed: _exportPdfAndShare,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Exportar PDF'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1000
                              ? 4
                              : constraints.maxWidth >= 540
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildCard(
                                'Pendientes',
                                _pending,
                                const Color(0xFFF0AD3D),
                                Icons.pending_actions_outlined,
                                width,
                              ),
                              _buildCard(
                                'Pagadas',
                                _paid,
                                const Color(0xFF188B6D),
                                Icons.check_circle_outline,
                                width,
                              ),
                              _buildCard(
                                'Vencidas',
                                _overdue,
                                const Color(0xFFE46E66),
                                Icons.warning_amber_outlined,
                                width,
                              ),
                              _buildCard(
                                'Total',
                                _total,
                                const Color(0xFF4386D8),
                                Icons.receipt_long_outlined,
                                width,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      Consumer<GamificationProvider>(
                        builder: (context, gamificationProvider, _) {
                          final gamification =
                              gamificationProvider.gamification;
                          if (gamification == null) {
                            return const SizedBox.shrink();
                          }
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AchievementsScreen(),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events_outlined,
                                      size: 32,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tus logros',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${gamification.unlockedBadges.length} insignias · ${gamification.streakDays} pagos puntuales consecutivos',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${gamification.totalPoints} pts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 850 ? 2 : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns;
                          final charts = [
                            _buildStatusChart(
                              pendingCount,
                              paidCount,
                              overdueCount,
                            ),
                            _buildMonthlyChartPanel(
                              'Evolución mensual',
                              'Importe de facturas por mes',
                              _buildMonthlyBarChart(),
                            ),
                            _buildMonthlyChartPanel(
                              'Tendencia del gasto',
                              'Comparación de los últimos seis meses',
                              _buildMonthlyLineChart(),
                            ),
                          ];
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final chart in charts)
                                SizedBox(
                                  width: width,
                                  height: 286,
                                  child: chart,
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Próximos vencimientos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Próximos vencimientos',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () {
                              final homeState = context
                                  .findAncestorStateOfType<_HomeScreenState>();
                              homeState?.setState(() {
                                homeState._selectedIndex = 1;
                              });
                            },
                            child: const Text('Ver todas'),
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
                                  .take(5)
                                  .map((b) => _buildBillItem(b))
                                  .toList(),
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _buildCard(
    String title,
    int count,
    Color color,
    IconData icon,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'facturas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChart(int pending, int paid, int overdue) {
    final values = [
      ('Pendientes', pending, const Color(0xFFF0AD3D)),
      ('Pagadas', paid, const Color(0xFF188B6D)),
      ('Vencidas', overdue, const Color(0xFFE46E66)),
    ];
    final total = pending + paid + overdue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de facturas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              '$total en total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (final entry in values)
                            if (entry.$2 > 0)
                              PieChartSectionData(
                                value: entry.$2.toDouble(),
                                color: entry.$3,
                                title: '${entry.$2}',
                                radius: 24,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ],
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                      ),
                      duration: const Duration(milliseconds: 350),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: entry.$3,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    entry.$1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Text(
                                  '${entry.$2}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChartPanel(String title, String subtitle, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: chart),
      ],
    );
  }

  double _chartMaxY(List<double> data) {
    final maximum = data.reduce((a, b) => a > b ? a : b);
    return maximum == 0 ? 1 : maximum * 1.2;
  }

  String _compactAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)} mil';
    return amount.toStringAsFixed(0);
  }

  Widget _buildBillItem(Bill bill) {
    final serviceName = bill.service?.name ?? 'Sin servicio';
    final categoryIcon = bill.category?.icon ?? '📌';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bill.statusColor.withValues(alpha: 0.16),
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
