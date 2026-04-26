import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/glass/glass_card.dart';

class WatchtimeWidget extends ConsumerWidget {
  const WatchtimeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return GlassCard(
      weight: GlassWeight.mid,
      rimColor: AppColors.green.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('WATCHTIME',
              style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: AppColors.white35, fontWeight: FontWeight.w600)),
            const Spacer(),
            statsAsync.when(
              loading: () => const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.green)),
              error: (_, __) => const SizedBox(),
              data: (data) {
                final total = (data['total_watchtime_hours'] as num?)?.toStringAsFixed(1) ?? '–';
                return Text('${total}h',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.5));
              },
            ),
          ]),
          const SizedBox(height: 14),
          statsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)),
            error: (e, _) => Text('Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
            data: (data) {
              final users = (data['watchtime_users'] as List?) ?? [];
              if (users.isEmpty) {
                return const Text('Keine Daten verfügbar',
                  style: TextStyle(fontSize: 12, color: Colors.white30));
              }
              final maxH = users.map((u) => (u['hours'] as num).toDouble())
                  .reduce((a, b) => a > b ? a : b);
              final palette = [AppColors.violet, AppColors.cyan, AppColors.green,
                               AppColors.amber, AppColors.rose];
              return Column(
                children: users.asMap().entries.map((entry) {
                  final i = entry.key;
                  final u = entry.value as Map<String, dynamic>;
                  final hours = (u['hours'] as num).toDouble();
                  final color = palette[i % palette.length];
                  final name = u['name'] as String? ?? '';
                  final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < users.length - 1 ? 12 : 0),
                    child: Column(children: [
                      Row(children: [
                        Container(width: 22, height: 22,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: color.withOpacity(0.2), border: Border.all(color: color.withOpacity(0.4))),
                          child: Center(child: Text(avatar, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
                        Text('${hours.toStringAsFixed(1)}h',
                          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: GlassProgressBar(value: hours / maxH, color: color),
                      ),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
