import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../widgets/glass/glass_card.dart';

// Static stat (kein API-Call, für feste Werte wie Container-Count)
class StatWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? sub;
  final Color color;

  const StatWidget({
    super.key,
    required this.icon,
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
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1)),
            const SizedBox(height: 3),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9, color: Colors.white38, letterSpacing: 0.8)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: const TextStyle(fontSize: 9, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}

// Live stat from /api/stats
class LiveStatWidget extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String statsKey;
  final String? sub;
  final Color color;
  final String Function(dynamic value)? formatter;

  const LiveStatWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.statsKey,
    this.sub,
    required this.color,
    this.formatter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return GlassCard(
      borderRadius: 24,
      weight: GlassWeight.mid,
      rimColor: color.withOpacity(0.4),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            statsAsync.when(
              loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const Text('–',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              data: (data) {
                final raw = data[statsKey];
                final display = formatter != null
                    ? formatter!(raw)
                    : raw?.toString() ?? '–';
                return Text(display,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1));
              },
            ),
            const SizedBox(height: 3),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9, color: Colors.white38, letterSpacing: 0.8)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: const TextStyle(fontSize: 9, color: Colors.white24)),
            ],
          ],
        ),
      ),
    );
  }
}
