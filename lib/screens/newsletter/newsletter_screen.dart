import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../providers/providers.dart';
import '../../widgets/glass/glass_card.dart';

class NewsletterScreen extends ConsumerStatefulWidget {
  const NewsletterScreen({super.key});
  @override ConsumerState<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends ConsumerState<NewsletterScreen> {
  Map<String, dynamic>? _openNewsletter;

  @override
  Widget build(BuildContext context) {
    if (_openNewsletter != null) return _buildDetail(_openNewsletter!);

    final archiveAsync = ref.watch(newsletterArchiveProvider);

    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(14,16,14,100), children: [
      const Text('Newsletter', style: TextStyle(fontSize:30,fontWeight:FontWeight.w800,letterSpacing:-1)),
      const SizedBox(height:4),
      const Text('Wöchentlich · automatisch via n8n', style: TextStyle(fontSize:13,color:Colors.white38)),
      const SizedBox(height:16),

      // Next issue card
      archiveAsync.when(
        loading: () => GlassCard(
          weight: GlassWeight.thick, tint: AppColors.violet.withOpacity(0.18),
          rimColor: AppColors.violet.withOpacity(0.5),
          padding: const EdgeInsets.all(20),
          child: const Center(child: CircularProgressIndicator(strokeWidth:2, color: AppColors.violet)),
        ),
        error: (e, _) => GlassCard(
          weight: GlassWeight.thick, padding: const EdgeInsets.all(20),
          child: Text('Fehler: $e', style: const TextStyle(color: Colors.white38)),
        ),
        data: (data) {
          final newsletters = (data['newsletters'] as List?) ?? [];
          final now = DateTime.now();
          final week = now.isocalendar()[1];
          return GlassCard(
            weight: GlassWeight.thick, tint: AppColors.violet.withOpacity(0.18),
            rimColor: AppColors.violet.withOpacity(0.5), padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NÄCHSTE AUSGABE', style: TextStyle(fontSize:10, letterSpacing:1.1,
                  color: AppColors.violet.withOpacity(0.85), fontWeight:FontWeight.w700)),
              const SizedBox(height:10),
              Text('KW ${week + 1}', style: const TextStyle(fontSize:22, fontWeight:FontWeight.w800, letterSpacing:-0.5)),
              const SizedBox(height:6),
              Text('${newsletters.length} Ausgaben im Archiv', style: TextStyle(fontSize:13, color:AppColors.white40)),
            ]),
          );
        },
      ),

      const SizedBox(height:20),
      const Text('ARCHIV', style: TextStyle(fontSize:10, letterSpacing:1.1, color:Colors.white30, fontWeight:FontWeight.w600)),
      const SizedBox(height:10),

      archiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth:2, color: AppColors.violet)),
        error: (e, _) => Text('Fehler: $e', style: const TextStyle(color: Colors.white38)),
        data: (data) {
          final newsletters = (data['newsletters'] as List?) ?? [];
          if (newsletters.isEmpty) {
            return GlassCard(
              weight: GlassWeight.mid, padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Text('📬', style: TextStyle(fontSize:32)),
                const SizedBox(height:12),
                const Text('Noch keine Newsletter',
                  style: TextStyle(fontSize:15, fontWeight:FontWeight.w600)),
                const SizedBox(height:6),
                const Text('Der erste wird freitags via n8n generiert.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize:12, color:Colors.white38)),
              ]),
            );
          }
          final palette = [AppColors.violet, AppColors.blue, AppColors.green, AppColors.amber];
          return Column(
            children: newsletters.asMap().entries.map((entry) {
              final i = entry.key;
              final n = entry.value as Map<String, dynamic>;
              final color = palette[i % palette.length];
              final title = n['title'] as String? ?? 'Newsletter';
              final date  = n['date'] as String? ?? '';
              final count = n['count'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom:10),
                child: GlassCard(
                  borderRadius:22, weight:GlassWeight.mid,
                  rimColor: color.withOpacity(0.3), tint: color.withOpacity(0.08),
                  onTap: () => setState(() => _openNewsletter = n),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(width:44, height:44,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                        color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3))),
                      child: const Center(child: Text('📬', style: TextStyle(fontSize:22)))),
                    const SizedBox(width:12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize:14, fontWeight:FontWeight.w600)),
                      Text('$date · $count Empfehlungen', style: TextStyle(fontSize:11, color:AppColors.white35)),
                    ])),
                    const Text('›', style: TextStyle(fontSize:18, color:AppColors.white22)),
                  ]),
                ).animate().fadeIn(delay: Duration(milliseconds: i*80), duration: 300.ms),
              );
            }).toList(),
          );
        },
      ),
    ]));
  }

  Widget _buildDetail(Map<String, dynamic> n) {
    final title = n['title'] as String? ?? 'Newsletter';
    final count = n['count'] as int? ?? 0;
    final week  = n['week'] as int? ?? 0;
    final media = (n['media'] as List?) ?? [];

    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14,16,14,12),
        child: Row(children: [
          GlassCard(borderRadius:14, weight:GlassWeight.mid,
            onTap: () => setState(() => _openNewsletter = null),
            padding: const EdgeInsets.symmetric(horizontal:14, vertical:9),
            child: const Text('‹ Zurück', style: TextStyle(fontSize:13, color:Colors.white60))),
          const SizedBox(width:14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize:18, fontWeight:FontWeight.w800, letterSpacing:-0.5)),
            Text('KW $week · $count Empfehlungen', style: const TextStyle(fontSize:11, color:Colors.white38)),
          ])),
        ])),
      if (media.isEmpty)
        const Expanded(child: Center(
          child: Text('Keine Mediendaten', style: TextStyle(color: Colors.white38))))
      else
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14,0,14,100),
          itemCount: media.length,
          itemBuilder: (ctx, i) {
            final f = media[i] as Map<String, dynamic>;
            final name   = f['name'] as String? ?? '';
            final type   = f['type'] as String? ?? '';
            final poster = f['poster'] as String?;
            return Padding(padding: const EdgeInsets.only(bottom:12),
              child: GlassCard(weight:GlassWeight.mid, rimColor:AppColors.violet.withOpacity(0.3),
                tint: AppColors.violet.withOpacity(0.08), padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(width:56, height:80,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                      color: AppColors.violet.withOpacity(0.15),
                      border: Border.all(color: AppColors.violet.withOpacity(0.3))),
                    child: poster != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.network(
                            'https://image.tmdb.org/t/p/w154$poster',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                              const Center(child: Text('🎬', style: TextStyle(fontSize:28))),
                          ))
                      : const Center(child: Text('🎬', style: TextStyle(fontSize:28)))),
                  const SizedBox(width:14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize:16, fontWeight:FontWeight.w700, letterSpacing:-0.3)),
                    const SizedBox(height:4),
                    Text(type, style: TextStyle(fontSize:12, color:AppColors.white40)),
                  ])),
                ])).animate().fadeIn(delay: Duration(milliseconds: i*60), duration: 300.ms));
          })),
    ]));
  }
}

extension _DateTimeIso on DateTime {
  List<int> isocalendar() {
    final jan4 = DateTime(year, 1, 4);
    final startOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    final daysDiff = difference(startOfWeek1).inDays;
    if (daysDiff < 0) {
      final prevYear = DateTime(year - 1, 1, 4);
      final startOfPrevWeek1 = prevYear.subtract(Duration(days: prevYear.weekday - 1));
      final w = difference(startOfPrevWeek1).inDays ~/ 7 + 1;
      return [year - 1, w, weekday];
    }
    final w = daysDiff ~/ 7 + 1;
    return [year, w, weekday];
  }
}
