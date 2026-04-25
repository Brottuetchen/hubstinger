import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/glass/glass_card.dart';

const _typeColors = {
  'Movie':   AppColors.blue,
  'Episode': AppColors.rose,
};

const _typeEmoji = {
  'Movie':   '🎬',
  'Episode': '📺',
};

class RecentlyWidget extends ConsumerWidget {
  const RecentlyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyAddedProvider);

    return GlassCard(
      weight: GlassWeight.mid,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEU IN JELLYFIN',
            style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.white35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          recentAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)),
            error: (e, _) => Text('Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
            data: (data) {
              final items = (data['items'] as List?) ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text('Keine neuen Medien',
                    style: TextStyle(fontSize: 13, color: Colors.white30)));
              }
              return Column(
                children: items.take(4).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  final type = item['type'] as String? ?? 'Movie';
                  final color = _typeColors[type] ?? AppColors.violet;
                  final emoji = _typeEmoji[type] ?? '🎬';
                  final added = item['added'] as String? ?? '';
                  return Column(children: [
                    if (i > 0) Divider(color: Colors.white.withOpacity(0.06), height: 18),
                    Row(children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                          color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3))),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['title'] ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                        Text('$type${added.isNotEmpty ? ' · $added' : ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.white35)),
                      ])),
                      GlassCard(borderRadius: 8, weight: GlassWeight.thin,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: const Text('›', style: TextStyle(fontSize: 16, color: Colors.white30))),
                    ]),
                  ]);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
