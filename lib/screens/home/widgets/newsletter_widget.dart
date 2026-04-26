import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/glass/glass_card.dart';

class NewsletterWidget extends ConsumerWidget {
  const NewsletterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(newsletterArchiveProvider);

    return GlassCard(
      weight: GlassWeight.thick,
      tint: AppColors.violet.withOpacity(0.18),
      rimColor: AppColors.violet.withOpacity(0.5),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          archiveAsync.when(
            loading: () => GlassCard(
              borderRadius: 10, weight: GlassWeight.thin,
              rimColor: AppColors.violet.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: const Text('…', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            error: (_, __) => const SizedBox(),
            data: (data) {
              final newsletters = (data['newsletters'] as List?) ?? [];
              final latest = newsletters.isNotEmpty
                  ? newsletters.first as Map<String, dynamic> : null;
              final week = latest?['week'] as int?;
              return GlassCard(
                borderRadius: 10, weight: GlassWeight.thin,
                rimColor: AppColors.violet.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(week != null ? 'KW $week' : 'Newsletter',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.0,
                      color: AppColors.violet.withOpacity(0.9).withAlpha(230), fontWeight: FontWeight.w700)),
              );
            },
          ),
          const SizedBox(height: 12),
          archiveAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet)),
            error: (e, _) => Text('Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
            data: (data) {
              final newsletters = (data['newsletters'] as List?) ?? [];
              if (newsletters.isEmpty) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Noch kein Newsletter',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    SizedBox(height: 8),
                    Text('Wird jeden Freitag via n8n generiert.',
                      style: TextStyle(fontSize: 12, color: AppColors.white45, height: 1.5)),
                  ],
                );
              }
              final latest = newsletters.first as Map<String, dynamic>;
              final title = latest['title'] as String? ?? 'Newsletter';
              final items = (latest['items'] as List?) ?? [];
              final count = latest['count'] as int? ?? items.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('$count Empfehlungen diese Woche',
                    style: TextStyle(fontSize: 12, color: AppColors.white45, height: 1.5)),
                  if (items.isNotEmpty) ...[
                    const Spacer(),
                    Column(
                      children: items.take(3).toList().asMap().entries.map((e) {
                        final f = e.value as Map<String, dynamic>;
                        final rating = (f['rating'] as num?)?.toStringAsFixed(1) ?? '–';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Container(width: 28, height: 28,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                                color: AppColors.amber.withOpacity(0.15),
                                border: Border.all(color: AppColors.amber.withOpacity(0.3))),
                              child: const Center(child: Text('🎬', style: TextStyle(fontSize: 14)))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f['title'] ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                              overflow: TextOverflow.ellipsis)),
                            Text('★$rating',
                              style: TextStyle(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w700)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          GlassCard(
            borderRadius: 14, weight: GlassWeight.mid,
            rimColor: AppColors.violet.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: const Center(child: Text('Öffnen ›',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
    );
  }
}
