import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/constants/colors.dart';
import '../../providers/providers.dart';
import '../../widgets/glass/glass_card.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String _filter = 'Alle';

  Color _serviceColor(Map<String, dynamic> service) {
    final category = service['category'] as String? ?? '';
    switch (category) {
      case 'Media':
        return AppColors.cyan;
      case 'Storage':
        return AppColors.blue;
      case 'Monitor':
        return AppColors.green;
      case 'Infra':
        return AppColors.orange;
      case 'Dev':
        return AppColors.rose;
      case 'Security':
        return AppColors.amber;
      default:
        return AppColors.violet;
    }
  }

  List<Map<String, dynamic>> _servicesFromBootstrap(Map<String, dynamic> data) {
    final rawServices = (data['services'] as List?) ?? const [];
    return rawServices
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(appBootstrapProvider);

    return bootstrapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Services konnten nicht geladen werden.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (bootstrap) {
        final services = _servicesFromBootstrap(bootstrap);
        final categories = [
          'Alle',
          ...{
            ...services
                .map((service) => service['category'] as String? ?? 'Tools')
          },
        ];
        final filtered = _filter == 'Alle'
            ? services
            : services
                .where((service) => service['category'] == _filter)
                .toList();
        final online =
            services.where((service) => service['online'] == true).length;

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusDot(online: online == services.length),
                        const SizedBox(width: 8),
                        Text(
                          '$online von ${services.length} verbunden',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GlassPill(
                              label: category,
                              active: _filter == category,
                              onTap: () => setState(() => _filter = category),
                              activeColor: AppColors.violet,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final service = filtered[index];
                    final color = _serviceColor(service);
                    final online = service['online'] == true;
                    final label = service['label'] as String? ??
                        service['name'] as String? ??
                        'Service';
                    final description = service['description'] as String? ?? '';

                    return GlassCard(
                      borderRadius: 22,
                      weight: GlassWeight.mid,
                      rimColor: color.withOpacity(online ? 0.4 : 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: color.withOpacity(0.15),
                                border: Border.all(
                                  color: color.withOpacity(online ? 0.4 : 0.15),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  AppIcons.resolve(
                                    service['icon_key'] as String?,
                                  ),
                                  size: 24,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    online ? AppColors.white75 : Colors.white30,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.white40,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                StatusDot(online: online, size: 6),
                                const SizedBox(width: 6),
                                Text(
                                  online ? 'Live' : 'Nicht aktiv',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: index * 30),
                          duration: 300.ms,
                        );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
