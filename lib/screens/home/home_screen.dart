import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/constants/colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../widgets/glass/glass_card.dart';
import 'widgets/newsletter_widget.dart';
import 'widgets/recently_widget.dart';
import 'widgets/stat_widget.dart';
import 'widgets/streaming_widget.dart';
import 'widgets/watchtime_widget.dart';
import 'widgets/widget_editor_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<WidgetSlot> _layout = const [];
  List<Map<String, dynamic>> _widgetCatalog = const [];
  bool _layoutHydrated = false;
  bool _editing = false;

  List<WidgetSlot> _parseSlots(List<dynamic>? rawSlots) {
    if (rawSlots == null) {
      return const [];
    }
    return rawSlots
        .whereType<Map>()
        .map((slot) => WidgetSlot.fromJson(slot.cast<String, dynamic>()))
        .toList();
  }

  List<Map<String, dynamic>> _parseCatalog(Map<String, dynamic> bootstrap) {
    final rawCatalog = ((bootstrap['widgets']
            as Map<String, dynamic>?)?['catalog'] as List?) ??
        const [];
    return rawCatalog
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  List<WidgetSlot> _parseLayout(Map<String, dynamic> bootstrap) {
    final rawLayout =
        ((bootstrap['widgets'] as Map<String, dynamic>?)?['layout'] as List?) ??
            const [];
    return _parseSlots(rawLayout);
  }

  bool _sameLayout(List<WidgetSlot> a, List<WidgetSlot> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id || a[index].size != b[index].size) {
        return false;
      }
    }
    return true;
  }

  bool _sameCatalog(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index]['id'] != b[index]['id']) {
        return false;
      }
    }
    return true;
  }

  void _hydrateFromBootstrap(Map<String, dynamic> bootstrap) {
    final nextLayout = _parseLayout(bootstrap);
    final nextCatalog = _parseCatalog(bootstrap);
    final shouldUpdate = !_layoutHydrated ||
        !_sameLayout(_layout, nextLayout) ||
        !_sameCatalog(_widgetCatalog, nextCatalog);

    if (!shouldUpdate) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _layout = nextLayout;
        _widgetCatalog = nextCatalog;
        _layoutHydrated = true;
      });
    });
  }

  void _toggleEdit() => setState(() => _editing = !_editing);

  Future<void> _persistLayout() async {
    try {
      final saved = await ApiService.instance.saveDashboardLayout(
        _layout.map((slot) => slot.toJson()).toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _layout = _parseSlots(saved));
      ref.invalidate(appBootstrapProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dashboard-Layout konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  void _removeWidget(int index) {
    setState(() => _layout.removeAt(index));
    _persistLayout();
  }

  void _moveUp(int index) {
    if (index == 0) {
      return;
    }
    setState(() {
      final tmp = _layout[index];
      _layout[index] = _layout[index - 1];
      _layout[index - 1] = tmp;
    });
    _persistLayout();
  }

  void _moveDown(int index) {
    if (index >= _layout.length - 1) {
      return;
    }
    setState(() {
      final tmp = _layout[index];
      _layout[index] = _layout[index + 1];
      _layout[index + 1] = tmp;
    });
    _persistLayout();
  }

  void _addWidget(WidgetSlot slot) {
    setState(() => _layout.add(slot));
    _persistLayout();
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WidgetEditorSheet(
        activeIds: _layout.map((widget) => widget.id).toList(),
        widgetCatalog: _widgetCatalog,
        onAdd: _addWidget,
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(appBootstrapProvider);
    ref.invalidate(sessionsProvider);
    ref.invalidate(recentlyAddedProvider);
    ref.invalidate(statsProvider);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(appBootstrapProvider);
    final isTablet = MediaQuery.of(context).size.shortestSide > 600;

    return bootstrapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Dashboard konnte nicht geladen werden.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (bootstrap) {
        _hydrateFromBootstrap(bootstrap);
        if (!_layoutHydrated) {
          return const Center(child: CircularProgressIndicator());
        }
        return isTablet ? _buildTabletLayout() : _buildPhoneLayout();
      },
    );
  }

  Widget _buildPhoneLayout() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.violet,
      backgroundColor: const Color(0xFF12141F),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList(
              delegate: SliverChildListDelegate(_buildWidgetRows()),
            ),
          ),
          if (_editing)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              sliver: SliverToBoxAdapter(child: _buildAddButton()),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 110, top: 8),
              child: Text(
                _editing ? '' : 'Gedrueckt halten zum Bearbeiten',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white24,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: GlassCard(
            borderRadius: 0,
            weight: GlassWeight.thick,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildSidebarHeader(),
                  const SizedBox(height: 32),
                  ..._buildSidebarItems(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.violet,
            backgroundColor: const Color(0xFF12141F),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildWidget(_layout[index], index),
                      childCount: _layout.length,
                    ),
                  ),
                ),
                if (_editing)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverToBoxAdapter(child: _buildAddButton()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    final user = ref.watch(authProvider).user;
    final name =
        user?['full_name'] as String? ?? user?['username'] as String? ?? '-';
    final isAdmin = user?['is_admin'] as bool? ?? false;
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.violet, AppColors.cyan],
              ),
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                isAdmin ? 'Admin' : 'User',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSidebarItems() {
    final items = [
      (AppIcons.home, 'Home'),
      (AppIcons.services, 'Services'),
      (AppIcons.newsletter, 'Newsletter'),
      (AppIcons.settings, 'Einstellungen'),
    ];
    final currentTab = ref.watch(tabIndexProvider);

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final active = currentTab == index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: GlassCard(
          borderRadius: 14,
          weight: active ? GlassWeight.mid : GlassWeight.thin,
          rimColor: active ? AppColors.violet.withOpacity(0.4) : null,
          tint: active ? AppColors.violet.withOpacity(0.12) : null,
          onTap: () => ref.read(tabIndexProvider.notifier).state = index,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.$1,
                size: 18,
                color: active ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Guten Morgen'
        : hour < 18
            ? 'Guten Tag'
            : 'Guten Abend';
    final now = DateTime.now();
    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mrz',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day}. ${months[now.month - 1]}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: _toggleEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          AppIcons.wavingHand,
                          size: 28,
                          color: AppColors.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          ref.watch(authProvider).user?['full_name']
                                  as String? ??
                              ref.watch(authProvider).user?['username']
                                  as String? ??
                              'Family Hub',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white38,
                          ),
                        ),
                        if (_editing) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '. Bearbeiten',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.rose,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_editing)
                  GlassCard(
                    borderRadius: 16,
                    weight: GlassWeight.mid,
                    rimColor: AppColors.violet.withOpacity(0.5),
                    onTap: _toggleEdit,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: const Text(
                      'Fertig',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  GlassCard(
                    borderRadius: 50,
                    weight: GlassWeight.mid,
                    onTap: () {},
                    width: 40,
                    height: 40,
                    child: const Center(
                      child: Icon(
                        AppIcons.notification,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                StreamBuilder<DateTime>(
                  stream: Stream.periodic(
                    const Duration(seconds: 1),
                    (_) => DateTime.now(),
                  ),
                  builder: (_, snapshot) {
                    final time = snapshot.data ?? DateTime.now();
                    final label =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    return Text(
                      label,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1.5,
                        color: AppColors.white88,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWidgetRows() {
    final rows = <Widget>[];
    var index = 0;

    while (index < _layout.length) {
      final slot = _layout[index];
      if (slot.size == WidgetSize.large) {
        rows.add(_animatedRow(index, _buildWidget(slot, index)));
        index++;
      } else if (slot.size == WidgetSize.tall) {
        final smalls = <WidgetSlot>[];
        final smallIndexes = <int>[];
        var search = index + 1;
        while (search < _layout.length &&
            _layout[search].size == WidgetSize.small &&
            smalls.length < 2) {
          smalls.add(_layout[search]);
          smallIndexes.add(search);
          search++;
        }

        if (smalls.isNotEmpty) {
          rows.add(
            _animatedRow(
              index,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWidget(slot, index)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 28 - 12) / 2,
                    child: Column(
                      children: [
                        for (var smallIndex = 0;
                            smallIndex < smalls.length;
                            smallIndex++) ...[
                          if (smallIndex > 0) const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: _buildWidget(
                              smalls[smallIndex],
                              smallIndexes[smallIndex],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          index = search;
        } else {
          rows.add(_animatedRow(index, _buildWidget(slot, index)));
          index++;
        }
      } else if (slot.size == WidgetSize.small) {
        final pair = [MapEntry(index, slot)];
        if (index + 1 < _layout.length &&
            _layout[index + 1].size == WidgetSize.small) {
          pair.add(MapEntry(index + 1, _layout[index + 1]));
          index += 2;
        } else {
          index++;
        }

        rows.add(
          _animatedRow(
            index,
            Row(
              children: [
                for (var pairIndex = 0;
                    pairIndex < pair.length;
                    pairIndex++) ...[
                  if (pairIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildWidget(
                        pair[pairIndex].value,
                        pair[pairIndex].key,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        rows.add(_animatedRow(index, _buildWidget(slot, index)));
        index++;
      }
      rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  Widget _animatedRow(int index, Widget child) {
    return child
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 50), duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildWidget(WidgetSlot slot, int index) {
    final widget = switch (slot.id) {
      'streaming' => const StreamingWidget(),
      'newsletter' => const NewsletterWidget(),
      'recently' => const RecentlyWidget(),
      'watchtime' => const WatchtimeWidget(),
      'containers' => LiveStatWidget(
          icon: AppIcons.containers,
          label: 'Container',
          statsKey: 'portainer_running',
          sub: 'Laufend',
          color: AppColors.violet,
          formatter: (value) => value?.toString() ?? '-',
        ),
      'streams_count' => LiveStatWidget(
          icon: AppIcons.activeStreams,
          label: 'Streams',
          statsKey: 'active_streams',
          sub: 'Aktiv',
          color: AppColors.cyan,
          formatter: (value) => value?.toString() ?? '-',
        ),
      'uptime' => LiveStatWidget(
          icon: AppIcons.uptime,
          label: 'Uptime',
          statsKey: 'uptime_kuma_pct',
          sub: 'Services',
          color: AppColors.green,
          formatter: (value) =>
              value != null ? '${(value as num).toStringAsFixed(1)}%' : '-',
        ),
      'nas' => LiveStatWidget(
          icon: AppIcons.nas,
          label: 'NAS frei',
          statsKey: 'nextcloud_used_gb',
          sub: 'Nextcloud',
          color: AppColors.amber,
          formatter: (value) =>
              value != null ? '${(value as num).toStringAsFixed(1)} GB' : '-',
        ),
      'proxmox' => LiveStatWidget(
          icon: AppIcons.proxmox,
          label: 'CPU',
          statsKey: 'proxmox_cpu_pct',
          sub: 'Proxmox',
          color: AppColors.orange,
          formatter: (value) =>
              value != null ? '${(value as num).toStringAsFixed(0)}%' : '-',
        ),
      'requests' => LiveStatWidget(
          icon: AppIcons.requests,
          label: 'Anfragen',
          statsKey: 'jellyseerr_pending',
          sub: 'Jellyseerr',
          color: AppColors.rose,
          formatter: (value) => value?.toString() ?? '-',
        ),
      'sonarr' => LiveStatWidget(
          icon: AppIcons.episode,
          label: 'Upcoming',
          statsKey: 'sonarr_upcoming',
          sub: 'Sonarr',
          color: AppColors.cyan,
          formatter: (value) => value?.toString() ?? '-',
        ),
      'radarr' => LiveStatWidget(
          icon: AppIcons.movie,
          label: 'Fehlend',
          statsKey: 'radarr_missing',
          sub: 'Radarr',
          color: AppColors.amber,
          formatter: (value) => value?.toString() ?? '-',
        ),
      'immich' => LiveStatWidget(
          icon: AppIcons.immich,
          label: 'Fotos',
          statsKey: 'immich_photos',
          sub: 'Immich',
          color: AppColors.green,
          formatter: (value) =>
              value is int ? _formatCount(value) : value?.toString() ?? '-',
        ),
      'navidrome' => LiveStatWidget(
          icon: AppIcons.navidrome,
          label: 'Kuenstler',
          statsKey: 'navidrome_artists',
          sub: 'Navidrome',
          color: AppColors.violet,
          formatter: (value) => value?.toString() ?? '-',
        ),
      _ => const SizedBox.shrink(),
    };

    if (!_editing) {
      return widget;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .rotate(
              begin: -0.008,
              end: 0.008,
              duration: 300.ms,
              curve: Curves.easeInOut,
            ),
        Positioned(
          top: -10,
          left: -10,
          child: GestureDetector(
            onTap: () => _removeWidget(index),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.9),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: -12,
          child: Column(
            children: [
              _moveButton(AppIcons.up, index > 0, () => _moveUp(index)),
              const SizedBox(height: 4),
              _moveButton(
                AppIcons.down,
                index < _layout.length - 1,
                () => _moveDown(index),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moveButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: GlassCard(
        borderRadius: 8,
        weight: GlassWeight.thick,
        width: 24,
        height: 24,
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddSheet,
      child: const GlassCard(
        borderRadius: 24,
        weight: GlassWeight.thin,
        padding: EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 24, color: AppColors.cyan),
            SizedBox(width: 12),
            Text(
              'Widget hinzufuegen',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
