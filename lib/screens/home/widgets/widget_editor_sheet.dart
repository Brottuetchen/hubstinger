import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../models/models.dart';
import '../../../widgets/glass/glass_card.dart';

class WidgetEditorSheet extends StatelessWidget {
  final List<String> activeIds;
  final List<Map<String, dynamic>> widgetCatalog;
  final void Function(WidgetSlot) onAdd;

  const WidgetEditorSheet({
    super.key,
    required this.activeIds,
    required this.widgetCatalog,
    required this.onAdd,
  });

  WidgetSize _parseSize(String? value) {
    return WidgetSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => WidgetSize.small,
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = widgetCatalog
        .where((entry) => !activeIds.contains(entry['id']))
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Widget hinzufuegen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tippe auf ein Widget, um es hinzuzufuegen.',
              style: TextStyle(fontSize: 13, color: AppColors.white40),
            ),
            const SizedBox(height: 20),
            if (available.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Alle verfuegbaren Widgets sind bereits aktiv.',
                    style: TextStyle(color: AppColors.white35, fontSize: 14),
                  ),
                ),
              )
            else
              ...available.asMap().entries.map((entry) {
                final index = entry.key;
                final widgetDef = entry.value;
                final size = _parseSize(widgetDef['default_size'] as String?);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    borderRadius: 20,
                    weight: GlassWeight.mid,
                    onTap: () {
                      onAdd(WidgetSlot(
                        id: widgetDef['id'] as String,
                        size: size,
                      ));
                      Navigator.pop(context);
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.resolve(widgetDef['icon_key'] as String?),
                          size: 24,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widgetDef['label'] as String? ?? 'Widget',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Groesse: ${size.name}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.white40,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: AppColors.cyan,
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: index * 50),
                        duration: 300.ms,
                      )
                      .slideX(begin: 0.05, end: 0),
                );
              }),
          ],
        ),
      ),
    );
  }
}
