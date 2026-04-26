import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../models/models.dart';
import '../../../widgets/glass/glass_card.dart';

const Map<String, Map<String, dynamic>> widgetDefs = {
  'streaming':     {'label': 'Jetzt gestreamt',  'icon': '▶️', 'size': WidgetSize.large},
  'newsletter':    {'label': 'Newsletter',        'icon': '✉️', 'size': WidgetSize.tall},
  'recently':      {'label': 'Neu in Jellyfin',  'icon': '🎬', 'size': WidgetSize.large},
  'watchtime':     {'label': 'Watchtime',         'icon': '📊', 'size': WidgetSize.large},
  'containers':    {'label': 'Container',         'icon': '🐳', 'size': WidgetSize.small},
  'streams_count': {'label': 'Aktive Streams',    'icon': '📡', 'size': WidgetSize.small},
  'uptime':        {'label': 'Uptime Kuma',       'icon': '✅', 'size': WidgetSize.small},
  'nas':           {'label': 'NAS Speicher',      'icon': '💾', 'size': WidgetSize.small},
  'proxmox':       {'label': 'Proxmox CPU',       'icon': '🖥️', 'size': WidgetSize.small},
  'requests':      {'label': 'Jellyseerr',        'icon': '🎥', 'size': WidgetSize.small},
  'sonarr':        {'label': 'Sonarr Upcoming',   'icon': '📺', 'size': WidgetSize.small},
  'radarr':        {'label': 'Radarr Missing',    'icon': '🎬', 'size': WidgetSize.small},
  'immich':        {'label': 'Immich Fotos',      'icon': '📷', 'size': WidgetSize.small},
  'navidrome':     {'label': 'Navidrome',         'icon': '🎵', 'size': WidgetSize.small},
};

class WidgetEditorSheet extends StatelessWidget {
  final List<String> activeIds;
  final Function(WidgetSlot) onAdd;

  const WidgetEditorSheet({
    super.key,
    required this.activeIds,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final available = widgetDefs.entries
        .where((e) => !activeIds.contains(e.key))
        .toList();

    return GlassCard(
      borderRadius: 28,
      weight: GlassWeight.thick,
      rimColor: AppColors.white22,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Widget hinzufügen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text('Tippe auf ein Widget um es hinzuzufügen',
              style: TextStyle(fontSize: 13, color: AppColors.white40)),
            const SizedBox(height: 20),
            if (available.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Alle Widgets sind aktiv ✓',
                    style: TextStyle(color: AppColors.white35, fontSize: 14)),
                ),
              )
            else
              ...available.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final def = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    borderRadius: 20,
                    weight: GlassWeight.mid,
                    onTap: () {
                      onAdd(WidgetSlot(id: e.key, size: def['size'] as WidgetSize));
                      Navigator.pop(context);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(def['icon'] as String, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(def['label'] as String,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('Größe: ${(def['size'] as WidgetSize).name}',
                              style: TextStyle(fontSize: 11, color: AppColors.white40)),
                          ]),
                        ),
                        Text('+', style: TextStyle(fontSize: 22, color: AppColors.cyan)),
                      ],
                    ),
                  ).animate()
                    .fadeIn(delay: Duration(milliseconds: i * 50), duration: 300.ms)
                    .slideX(begin: 0.05, end: 0),
                );
              }),
          ],
        ),
      ),
    );
  }
}
