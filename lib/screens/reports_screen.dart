import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/auth_provider.dart';
import '../services/bill_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _billService = BillService();
  List<Bill> _bills = [];
  bool _isLoading = true;
  String? _error;

  static const _chartColors = [
    Color(0xFF087F63),
    Color(0xFF4386D8),
    Color(0xFFF0AD3D),
    Color(0xFFE46E66),
    Color(0xFF8A76CE),
    Color(0xFF48A9B6),
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final userId = context.read<AuthProvider>().user?.id;
    try {
      _bills = userId == null ? [] : await _billService.getBills(userId);
    } catch (error) {
      _error = 'No se pudieron cargar los reportes: $error';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final bill in _bills) {
      final name = bill.category?.name ?? 'Sin categoría';
      totals.update(
        name,
        (total) => total + bill.amount,
        ifAbsent: () => bill.amount,
      );
    }
    return totals;
  }

  List<double> get _monthlyTotals {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index, 1);
      return _bills
          .where(
            (bill) =>
                bill.dueDate.year == month.year &&
                bill.dueDate.month == month.month,
          )
          .fold<double>(0, (total, bill) => total + bill.amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final paid = _bills.where((bill) => bill.status == 'paid').length;
    final overdue = _bills
        .where((bill) => bill.status == 'overdue' || bill.isOverdue)
        .length;
    final pending = _bills.length - paid - overdue;
    final totalAmount = _bills.fold<double>(
      0,
      (total, bill) => total + bill.amount,
    );
    final paidAmount = _bills
        .where((bill) => bill.status == 'paid')
        .fold<double>(0, (total, bill) => total + bill.amount);
    final currency = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs. ',
      decimalDigits: 0,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y estadísticas'),
        actions: [
          IconButton(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar reportes',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _bills.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = (constraints.maxWidth - 48)
                      .clamp(0.0, 1272.0)
                      .toDouble();
                  final columns = contentWidth >= 800
                      ? 3
                      : contentWidth >= 500
                      ? 2
                      : 1;
                  final metricWidth =
                      (contentWidth - (columns - 1) * 14) / columns;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            'Tu panorama financiero',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Resumen calculado a partir de tus facturas registradas',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _metricCard(
                                context,
                                metricWidth,
                                'Total registrado',
                                currency.format(totalAmount),
                                Icons.account_balance_wallet_outlined,
                                colorScheme.primary,
                              ),
                              _metricCard(
                                context,
                                metricWidth,
                                'Pagado',
                                currency.format(paidAmount),
                                Icons.check_circle_outline,
                                const Color(0xFF188B6D),
                              ),
                              _metricCard(
                                context,
                                metricWidth,
                                'Facturas',
                                '${_bills.length}',
                                Icons.receipt_long_outlined,
                                const Color(0xFF4386D8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (constraints.maxWidth >= 850)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildMonthlyChart(context, currency),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatusChart(
                                    context,
                                    pending,
                                    paid,
                                    overdue,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildMonthlyChart(context, currency),
                            const SizedBox(height: 16),
                            _buildStatusChart(context, pending, paid, overdue),
                          ],
                          const SizedBox(height: 16),
                          _buildCategories(context, currency),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _metricCard(
    BuildContext context,
    double width,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context, NumberFormat currency) {
    final totals = _monthlyTotals;
    final maximum = totals.fold<double>(
      0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );
    final now = DateTime.now();
    final labels = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index, 1).month;
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
      ][month - 1];
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolución mensual',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Importe de facturas por mes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 230,
              child: BarChart(
                BarChartData(
                  maxY: maximum == 0 ? 1 : maximum * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, _) => Text(
                          _compactAmount(value),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[index],
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    totals.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: totals[index],
                          width: 16,
                          color: _chartColors[0],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total del período: ${currency.format(totals.fold<double>(0, (sum, value) => sum + value))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChart(
    BuildContext context,
    int pending,
    int paid,
    int overdue,
  ) {
    final total = pending + paid + overdue;
    final values = [
      ('Pendientes', pending, const Color(0xFFF0AD3D)),
      ('Pagadas', paid, const Color(0xFF188B6D)),
      ('Vencidas', overdue, const Color(0xFFE46E66)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de facturas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$total facturas registradas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 208,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 48,
                        sectionsSpace: 3,
                        sections: [
                          for (final entry in values)
                            if (entry.$2 > 0)
                              PieChartSectionData(
                                value: entry.$2.toDouble(),
                                color: entry.$3,
                                title: '${(entry.$2 * 100 / total).round()}%',
                                radius: 24,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ],
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
                                const SizedBox(width: 8),
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
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildCategories(BuildContext context, NumberFormat currency) {
    final entries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximum = entries.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gasto por categoría',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Distribución según tus facturas registradas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < entries.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entries[index].key,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          currency.format(entries[index].value),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: maximum == 0
                            ? 0
                            : entries[index].value / maximum,
                        minHeight: 8,
                        color: _chartColors[index % _chartColors.length],
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
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

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no hay datos para mostrar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando registres facturas, aquí verás tus estadísticas reales.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  String _compactAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)} mil';
    return amount.toStringAsFixed(0);
  }
}
