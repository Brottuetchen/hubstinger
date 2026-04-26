import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_icons.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBoundedHeight = constraints.maxHeight.isFinite;

          final content = archiveAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.violet),
            ),
            error: (e, _) => Text(
              'Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            data: (data) {
              final newsletters = ((data['newsletters'] as List?) ?? [])
                  .cast<Map<String, dynamic>>();
              if (newsletters.isEmpty) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noch kein Newsletter',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Wird jeden Freitag via n8n generiert.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.white45, height: 1.5),
                    ),
                  ],
                );
              }

              final latest = newsletters.first;
              final title = latest['title'] as String? ?? 'Newsletter';
              final items = ((latest['items'] as List?) ?? [])
                  .cast<Map<String, dynamic>>();
              final count = latest['count'] as int? ?? items.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count Empfehlungen diese Woche',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.white45, height: 1.5),
                  ),
                  if (items.isNotEmpty) ...[
                    const Spacer(),
                    Column(
                      children: items.take(3).map((item) {
                        final rating =
                            (item['rating'] as num?)?.toStringAsFixed(1) ?? '–';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.amber.withOpacity(0.15),
                                  border: Border.all(
                                      color: AppColors.amber.withOpacity(0.3)),
                                ),
                                child: const Center(
                                  child: Icon(AppIcons.movie,
                                      size: 14, color: AppColors.amber),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['title'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '★$rating',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              );
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              archiveAsync.when(
                loading: () => GlassCard(
                  borderRadius: 10,
                  weight: GlassWeight.thin,
                  rimColor: AppColors.violet.withOpacity(0.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: const Text('…',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                error: (_, __) => const SizedBox(),
                data: (data) {
                  final newsletters = ((data['newsletters'] as List?) ?? [])
                      .cast<Map<String, dynamic>>();
                  final latest =
                      newsletters.isNotEmpty ? newsletters.first : null;
                  final week = latest?['week'] as int?;
                  return GlassCard(
                    borderRadius: 10,
                    weight: GlassWeight.thin,
                    rimColor: AppColors.violet.withOpacity(0.4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      week != null ? 'KW $week' : 'Newsletter',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.violet.withOpacity(0.9).withAlpha(230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (isBoundedHeight) Expanded(child: content) else content,
              const SizedBox(height: 8),
              GlassCard(
                borderRadius: 14,
                weight: GlassWeight.mid,
                rimColor: AppColors.violet.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Öffnen',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(AppIcons.forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
