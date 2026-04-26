import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/glass/glass_card.dart';

class StreamingWidget extends ConsumerWidget {
  const StreamingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return GlassCard(
      weight: GlassWeight.thick,
      rimColor: AppColors.cyan.withOpacity(0.4),
      tint: AppColors.cyan.withOpacity(0.08),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBoundedHeight = constraints.maxHeight.isFinite;

          Widget buildRow(Map<String, dynamic> session) {
            final progress = (session['progress'] as num? ?? 0) / 100.0;
            return Row(
              children: [
                Container(
                  width: 44,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: AppColors.cyan.withOpacity(0.15),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.cyan.withOpacity(0.3),
                          blurRadius: 20)
                    ],
                  ),
                  child: const Center(
                    child: Icon(AppIcons.streaming,
                        size: 22, color: AppColors.cyan),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${session['user'] ?? ''} · ${session['progress'] ?? 0}%',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.white40),
                      ),
                      const SizedBox(height: 7),
                      GlassProgressBar(value: progress, color: AppColors.cyan),
                    ],
                  ),
                ),
              ],
            );
          }

          final content = sessionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.cyan),
            ),
            error: (e, _) => Text(
              'Fehler: $e',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            data: (data) {
              final sessions = ((data['sessions'] as List?) ?? [])
                  .cast<Map<String, dynamic>>();
              if (sessions.isEmpty) {
                return const Center(
                  child: Text(
                    'Keine aktiven Streams',
                    style: TextStyle(fontSize: 13, color: Colors.white30),
                  ),
                );
              }

              if (isBoundedHeight) {
                return ListView.separated(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withOpacity(0.06),
                    height: 28,
                  ),
                  itemBuilder: (context, index) => buildRow(sessions[index]),
                );
              }

              return Column(
                children: sessions.asMap().entries.map((entry) {
                  return Column(
                    children: [
                      if (entry.key > 0)
                        Divider(
                            color: Colors.white.withOpacity(0.06), height: 28),
                      buildRow(entry.value),
                    ],
                  );
                }).toList(),
              );
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusDot(online: sessionsAsync.hasValue),
                  const SizedBox(width: 8),
                  const Text(
                    'JETZT GESTREAMT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.white45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const GlassCard(
                    borderRadius: 10,
                    weight: GlassWeight.thin,
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      'Jellyfin',
                      style: TextStyle(fontSize: 11, color: AppColors.white45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isBoundedHeight) Expanded(child: content) else content,
            ],
          );
        },
      ),
    );
  }
}
