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
      // refreshUi no es necesario ya que loadGamification notifica cuando silent=false
      // pero lo dejamos para asegurar que la UI se actualiza
      gamificationProvider.refreshUi();
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

    return SimpleConfetti(
      trigger: gamificationProvider.showConfetti,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Logros'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
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
          backgroundColor: Colors.white,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : gamification == null
              ? _buildEmptyState()
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
                        '🏅 Insignias',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBadgesGrid(
                        gamificationProvider.getBadgesWithStatus(),
                      ),
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
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '🏆 Nivel',
                  '${gamification.currentLevel}',
                  Gamification.getLevelName(gamification.currentLevel),
                  Colors.amber,
                ),
                _buildStatItem(
                  '⭐ Puntos',
                  '${gamification.totalPoints}',
                  '${gamification.pointsToNextLevel} pts para subir',
                  Colors.green,
                ),
                _buildStatItem(
                  '🔥 Racha',
                  '${gamification.streakDays} días',
                  'Pagos consecutivos',
                  Colors.orange,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '📄 Pagadas',
                  '${gamification.totalPaidBills}',
                  'Facturas pagadas',
                  Colors.blue,
                ),
                _buildStatItem(
                  '✅ A tiempo',
                  '${gamification.onTimePayments}',
                  'Pagos puntuales',
                  Colors.green,
                ),
                _buildStatItem(
                  '🏅 Logros',
                  '${gamification.unlockedBadges.length}',
                  'Insignias desbloqueadas',
                  Colors.purple,
                ),
              ],
            ),
          ],
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
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                backgroundColor: Colors.grey[200],
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
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

  Widget _buildBadgeCard(AchievementBadge badge) {
    return Card(
      elevation: badge.isUnlocked ? 2 : 0,
      color: badge.isUnlocked ? Colors.white : Colors.grey[100],
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
                  color: badge.isUnlocked ? Colors.black : Colors.grey[500],
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
