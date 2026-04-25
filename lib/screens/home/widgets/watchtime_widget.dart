// streaming_widget.dart
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../widgets/glass/glass_card.dart';

class StreamingWidget extends StatelessWidget {
  const StreamingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final streams = [
      ('Dune: Part Two', 'Lena', 0.62, AppColors.amber, '🏜️'),
      ('Severance S02', 'Constantin', 0.34, AppColors.cyan, '🏢'),
    ];

    return GlassCard(
      weight: GlassWeight.thick,
      rimColor: AppColors.cyan.withOpacity(0.4),
      tint: AppColors.cyan.withOpacity(0.08),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(online: true),
              const SizedBox(width: 8),
              const Text('JETZT GESTREAMT',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2,
                    color: Colors.white45, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GlassCard(
                borderRadius: 10, weight: GlassWeight.thin,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: const Text('Jellyfin',
                  style: TextStyle(fontSize: 11, color: Colors.white45)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...streams.asMap().entries.map((entry) {
            final i = entry.key; final s = entry.value;
            return Column(
              children: [
                if (i > 0) ...[
                  Divider(color: Colors.white.withOpacity(0.06), height: 28),
                ],
                Row(
                  children: [
                    // Mini poster
                    Container(
                      width: 44, height: 62, decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: s.$4.withOpacity(0.15),
                        border: Border.all(color: s.$4.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: s.$4.withOpacity(0.3), blurRadius: 20)],
                      ),
                      child: Center(child: Text(s.$5, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.3)),
                        const SizedBox(height: 3),
                        Text('${s.$2} · ${(s.$3 * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, color: Colors.white40)),
                        const SizedBox(height: 7),
                        GlassProgressBar(value: s.$3, color: s.$4),
                      ],
                    )),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// newsletter_widget.dart
class NewsletterWidget extends StatelessWidget {
  const NewsletterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final films = [
      ('Dune: Part Two', '8.4', '🏜️', AppColors.amber),
      ('The Brutalist', '8.1', '🏛️', AppColors.blue),
      ('Adolescence', '8.9', '👦', AppColors.rose),
    ];
    return GlassCard(
      weight: GlassWeight.thick,
      tint: AppColors.violet.withOpacity(0.18),
      rimColor: AppColors.violet.withOpacity(0.5),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            borderRadius: 10, weight: GlassWeight.thin,
            rimColor: AppColors.violet.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('KW 17',
              style: TextStyle(fontSize: 10, letterSpacing: 1.0,
                  color: AppColors.violet.withOpacity(0.9).withAlpha(230), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          const Text('April Picks 🎬',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Dune 2, The Brutalist und 6 weitere Empfehlungen.',
            style: TextStyle(fontSize: 12, color: Colors.white45, height: 1.5)),
          const Spacer(),
          Column(
            children: films.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                    color: f.$4.withOpacity(0.15), border: Border.all(color: f.$4.withOpacity(0.3))),
                  child: Center(child: Text(f.$3, style: const TextStyle(fontSize: 14)))),
                const SizedBox(width: 8),
                Expanded(child: Text(f.$1, style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                Text('★${f.$2}', style: TextStyle(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w700)),
              ]),
            )).toList(),
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

// recently_widget.dart
class RecentlyWidget extends StatelessWidget {
  const RecentlyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('A Complete Unknown', 'Film · Heute', '🎸', AppColors.blue),
      ('Adolescence', 'Serie · Gestern', '👦', AppColors.rose),
      ('Black Bag', 'Film · Mo', '🕵️', AppColors.violet),
      ('The Brutalist', 'Film · So', '🏛️', AppColors.amber),
    ];
    return GlassCard(
      weight: GlassWeight.mid,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEU IN JELLYFIN',
            style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.white35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final i = entry.key; final item = entry.value;
            return Column(children: [
              if (i > 0) Divider(color: Colors.white.withOpacity(0.06), height: 18),
              Row(children: [
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                    color: item.$4.withOpacity(0.15), border: Border.all(color: item.$4.withOpacity(0.3))),
                  child: Center(child: Text(item.$3, style: const TextStyle(fontSize: 18)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(item.$2, style: const TextStyle(fontSize: 11, color: Colors.white35)),
                ])),
                GlassCard(borderRadius: 8, weight: GlassWeight.thin,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Text('›', style: TextStyle(fontSize: 16, color: Colors.white30))),
              ]),
            ]);
          }),
        ],
      ),
    );
  }
}

// watchtime_widget.dart
class WatchtimeWidget extends StatelessWidget {
  const WatchtimeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      ('Constantin', 'C', 8.3, AppColors.violet),
      ('Lena',       'L', 5.8, AppColors.cyan),
      ('Emma',       'E', 2.2, AppColors.green),
    ];
    final max = users.map((u) => u.$3).reduce((a, b) => a > b ? a : b);
    return GlassCard(
      weight: GlassWeight.mid,
      rimColor: AppColors.green.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('WATCHTIME · KW 17',
              style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: Colors.white35, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(8.3+5.8+2.2).toStringAsFixed(1)}h',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ]),
          const SizedBox(height: 14),
          ...users.asMap().entries.map((entry) {
            final i = entry.key; final u = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < users.length - 1 ? 12 : 0),
              child: Column(children: [
                Row(children: [
                  Container(width: 22, height: 22,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: u.$4.withOpacity(0.2), border: Border.all(color: u.$4.withOpacity(0.4))),
                    child: Center(child: Text(u.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: u.$4)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(u.$1, style: const TextStyle(fontSize: 12))),
                  Text('${u.$3}h', style: TextStyle(fontSize: 12, color: u.$4, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: GlassProgressBar(value: u.$3 / max, color: u.$4),
                ),
              ]),
            );
          }),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 8),
          const Row(children: [
            Text('🏆', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text('Meist gesehen: ', style: TextStyle(fontSize: 11, color: Colors.white35)),
            Text('Severance S02', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white60)),
          ]),
        ],
      ),
    );
  }
}

// stat_widget.dart
class StatWidget extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final String? sub;
  final Color color;

  const StatWidget({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      weight: GlassWeight.mid,
      rimColor: color.withOpacity(0.4),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
            const SizedBox(height: 3),
            Text(label.toUpperCase(), style: const TextStyle(
              fontSize: 9, color: Colors.white38, letterSpacing: 0.8)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: const TextStyle(fontSize: 9, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
