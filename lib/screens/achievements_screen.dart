import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/gamification_provider.dart';
import '../models/gamification.dart';
import '../widgets/simple_confetti.dart';

// 🏆 Pantalla de logros y gamificación
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    print('🔄 AchievementsScreen: _loadData invoked');

    if (userId != null) {
      final gamificationProvider = context.read<GamificationProvider>();
      // Mostrar indicador de carga al recargar para que el usuario vea actividad
      await gamificationProvider.loadGamification(userId, silent: false);
      print('✅ AchievementsScreen: _loadData completed');
    } else {
      print('⚠️ AchievementsScreen: usuario nulo, no se cargan logros');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamificationProvider = context.watch<GamificationProvider>();
    final gamification = gamificationProvider.gamification;
    final isLoading = gamificationProvider.isLoading;
    final showCelebration = gamificationProvider.showCelebration;
    final newBadges = gamificationProvider.getNewBadgeDetails();
    final badges = gamificationProvider.getBadgesWithStatus();
    final unlockedBadges = badges.where((badge) => badge.isUnlocked).toList();

    return SimpleConfetti(
      trigger: gamificationProvider.showConfetti,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Logros'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Recargar',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: Colors.green,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : gamification == null
              ? gamificationProvider.loadError == null
                    ? _buildEmptyState()
                    : _buildLoadError(gamificationProvider.loadError!)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(gamification),
                      const SizedBox(height: 24),
                      _buildProgressBar(gamification),
                      const SizedBox(height: 24),
                      const Text(
                        '🏆 Trofeos ganados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildUnlockedBadges(
                        unlockedBadges,
                        gamification.totalPaidBills,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '🏅 Todas las insignias',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBadgesGrid(badges),
                    ],
                  ),
                ),
        ),
        floatingActionButton: showCelebration && newBadges.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () {
                  _showCelebrationDialog(newBadges);
                  gamificationProvider.resetCelebration();
                },
                backgroundColor: Colors.amber,
                icon: const Icon(Icons.emoji_events),
                label: Text('🎉 ${newBadges.length} nueva(s) insignia(s)!'),
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryCard(Gamification gamification) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 360
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            Widget stat(
              String label,
              String value,
              String subtitle,
              Color color,
            ) => SizedBox(
              width: width,
              child: _buildStatItem(label, value, subtitle, color),
            );

            return Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    stat(
                      '🏆 Nivel',
                      '${gamification.currentLevel}',
                      Gamification.getLevelName(gamification.currentLevel),
                      Colors.amber,
                    ),
                    stat(
                      '⭐ Puntos',
                      '${gamification.totalPoints}',
                      '${gamification.pointsToNextLevel} pts para subir',
                      Colors.green,
                    ),
                    stat(
                      '🔥 Racha',
                      '${gamification.streakDays} pagos',
                      'Pagos consecutivos',
                      Colors.orange,
                    ),
                  ],
                ),
                const Divider(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    stat(
                      '📄 Pagadas',
                      '${gamification.totalPaidBills}',
                      'Facturas pagadas',
                      Colors.blue,
                    ),
                    stat(
                      '✅ A tiempo',
                      '${gamification.onTimePayments}',
                      'Pagos puntuales',
                      Colors.green,
                    ),
                    stat(
                      '🏅 Logros',
                      '${gamification.unlockedBadges.length}',
                      'Insignias desbloqueadas',
                      Colors.purple,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(Gamification gamification) {
    final progress = gamification.progressToNextLevel.clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nivel ${gamification.currentLevel} → ${gamification.currentLevel + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${gamification.totalPoints} pts',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 0.8 ? Colors.green : Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}% completado',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid(List<AchievementBadge> badges) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _buildBadgeCard(badge);
      },
    );
  }

  Widget _buildUnlockedBadges(
    List<AchievementBadge> badges,
    int totalPaidBills,
  ) {
    if (badges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            totalPaidBills > 0
                ? 'Ya registramos tus pagos. Sigue cumpliendo metas para '
                      'desbloquear insignias.'
                : 'Todavía no has desbloqueado trofeos. Paga una factura para '
                      'obtener tu primera insignia.',
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: badges
            .map(
              (badge) => ListTile(
                leading: Text(badge.icon, style: const TextStyle(fontSize: 30)),
                title: Text(
                  badge.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(badge.description),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBadgeCard(AchievementBadge badge) {
    return Card(
      elevation: badge.isUnlocked ? 2 : 0,
      color: badge.isUnlocked
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: badge.isUnlocked
              ? Border.all(color: badge.colorValue, width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badge.isUnlocked ? badge.icon : '🔒',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                badge.isUnlocked ? badge.name : '???',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: badge.isUnlocked
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                badge.isUnlocked ? '✅ Desbloqueado' : '🔒 Bloqueado',
                style: TextStyle(
                  fontSize: 10,
                  color: badge.isUnlocked ? Colors.green : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!badge.isUnlocked) ...[
                const SizedBox(height: 4),
                Text(
                  badge.requirement,
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '🏆 ¡Comienza a pagar facturas para desbloquear logros!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Cada pago a tiempo suma puntos y te acerca a nuevas insignias',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar tus recompensas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCelebrationDialog(List<AchievementBadge> newBadges) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text('🎉 ¡Nuevas Insignias!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Has desbloqueado nuevas insignias:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...newBadges.map(
              (badge) => ListTile(
                leading: Text(badge.icon, style: const TextStyle(fontSize: 30)),
                title: Text(
                  badge.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(badge.description),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('¡Increíble!'),
          ),
        ],
      ),
    );
  }
}
