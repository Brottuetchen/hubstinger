import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/colors.dart';
import '../../models/models.dart';
import '../../widgets/glass/glass_card.dart';
import 'widgets/streaming_widget.dart';
import 'widgets/newsletter_widget.dart';
import 'widgets/recently_widget.dart';
import 'widgets/watchtime_widget.dart';
import 'widgets/stat_widget.dart';
import 'widgets/widget_editor_sheet.dart';

// ─── Default widget layout ────────────────────────────────────────────────────
const List<WidgetSlot> _defaultLayout = [
  WidgetSlot(id: 'streaming',      size: WidgetSize.large),
  WidgetSlot(id: 'newsletter',     size: WidgetSize.tall),
  WidgetSlot(id: 'containers',     size: WidgetSize.small),
  WidgetSlot(id: 'streams_count',  size: WidgetSize.small),
  WidgetSlot(id: 'recently',       size: WidgetSize.large),
  WidgetSlot(id: 'watchtime',      size: WidgetSize.large),
  WidgetSlot(id: 'uptime',         size: WidgetSize.small),
  WidgetSlot(id: 'nas',            size: WidgetSize.small),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WidgetSlot> _layout = List.from(_defaultLayout);
  bool _editing = false;

  void _toggleEdit() => setState(() => _editing = !_editing);

  void _removeWidget(int index) {
    setState(() => _layout.removeAt(index));
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final tmp = _layout[index];
      _layout[index] = _layout[index - 1];
      _layout[index - 1] = tmp;
    });
  }

  void _moveDown(int index) {
    if (index >= _layout.length - 1) return;
    setState(() {
      final tmp = _layout[index];
      _layout[index] = _layout[index + 1];
      _layout[index + 1] = tmp;
    });
  }

  void _addWidget(WidgetSlot slot) {
    setState(() => _layout.add(slot));
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WidgetEditorSheet(
        activeIds: _layout.map((w) => w.id).toList(),
        onAdd: _addWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIPad = MediaQuery.of(context).size.shortestSide > 600;

    return isIPad
        ? _buildIPadLayout()
        : _buildPhoneLayout();
  }

  // ── Phone Layout ────────────────────────────────────────────────────────────
  Widget _buildPhoneLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _buildWidgetRows(),
            ),
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
              _editing ? '' : 'Gedrückt halten zum Bearbeiten',
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
    );
  }

  // ── iPad Layout ─────────────────────────────────────────────────────────────
  Widget _buildIPadLayout() {
    return Row(
      children: [
        // Sidebar
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
        // Content - wider grid on iPad
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.violet, AppColors.cyan],
              ),
            ),
            child: const Center(
              child: Text('C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Constantin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('Admin', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSidebarItems() {
    final items = [
      ('⌂', 'Home'),
      ('◈', 'Services'),
      ('✉', 'Newsletter'),
      ('⚙', 'Einstellungen'),
    ];
    return items.map((item) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GlassCard(
        borderRadius: 14,
        weight: GlassWeight.thin,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(item.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Text(item.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    )).toList();
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Guten Morgen'
        : hour < 18 ? 'Guten Tag'
        : 'Guten Abend';
    final now = DateTime.now();
    final weekdays = ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
    final months = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final dateStr = '${weekdays[now.weekday-1]}, ${now.day}. ${months[now.month-1]}';

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
                    Text(dateStr.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11, color: Colors.white38,
                        letterSpacing: 1.0, fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$greeting 👋',
                      style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        letterSpacing: -1.0, height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Constantin',
                          style: TextStyle(fontSize: 13, color: Colors.white38),
                        ),
                        if (_editing) ...[
                          const SizedBox(width: 8),
                          const Text('· Bearbeiten',
                            style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w600),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: const Text('Fertig',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  GlassCard(
                    borderRadius: 50,
                    weight: GlassWeight.mid,
                    onTap: () {},
                    width: 40, height: 40,
                    child: const Center(child: Text('🔔', style: TextStyle(fontSize: 17))),
                  ),
                const SizedBox(height: 10),
                StreamBuilder<DateTime>(
                  stream: Stream.periodic(
                    const Duration(seconds: 1), (_) => DateTime.now(),
                  ),
                  builder: (_, snap) {
                    final t = snap.data ?? DateTime.now();
                    final time = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
                    return Text(time,
                      style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w200,
                        letterSpacing: -1.5, color: Colors.white88,
                        fontFeatures: [FontFeature.tabularFigures()],
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

  // ── Widget rows ──────────────────────────────────────────────────────────────
  List<Widget> _buildWidgetRows() {
    final rows = <Widget>[];
    int i = 0;
    while (i < _layout.length) {
      final w = _layout[i];
      if (w.size == WidgetSize.large) {
        rows.add(_animatedRow(i, _buildWidget(w, i)));
        i++;
      } else if (w.size == WidgetSize.tall) {
        // tall + smalls beside
        final smalls = <WidgetSlot>[];
        final smallIdxs = <int>[];
        int j = i + 1;
        while (j < _layout.length && _layout[j].size == WidgetSize.small && smalls.length < 2) {
          smalls.add(_layout[j]);
          smallIdxs.add(j);
          j++;
        }
        if (smalls.isNotEmpty) {
          rows.add(_animatedRow(i, Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildWidget(w, i)),
              const SizedBox(width: 12),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 28 - 12) / 2,
                child: Column(
                  children: [
                    for (int k = 0; k < smalls.length; k++) ...[
                      if (k > 0) const SizedBox(height: 12),
                      SizedBox(height: 120, child: _buildWidget(smalls[k], smallIdxs[k])),
                    ],
                  ],
                ),
              ),
            ],
          )));
          i = j;
        } else {
          rows.add(_animatedRow(i, _buildWidget(w, i)));
          i++;
        }
      } else if (w.size == WidgetSize.small) {
        final pair = [MapEntry(i, w)];
        if (i + 1 < _layout.length && _layout[i+1].size == WidgetSize.small) {
          pair.add(MapEntry(i+1, _layout[i+1]));
          i += 2;
        } else {
          i++;
        }
        rows.add(_animatedRow(i, Row(
          children: [
            for (int k = 0; k < pair.length; k++) ...[
              if (k > 0) const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 120, child: _buildWidget(pair[k].value, pair[k].key))),
            ],
          ],
        )));
      } else {
        rows.add(_animatedRow(i, _buildWidget(w, i)));
        i++;
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
    Widget widget = switch (slot.id) {
      'streaming'     => const StreamingWidget(),
      'newsletter'    => const NewsletterWidget(),
      'recently'      => const RecentlyWidget(),
      'watchtime'     => const WatchtimeWidget(),
      'containers'    => const StatWidget(emoji: '🐳', value: '23', label: 'Container', sub: 'Proxmox', color: AppColors.violet),
      'streams_count' => const StatWidget(emoji: '▶️', value: '2',  label: 'Streams',   sub: 'Aktiv',   color: AppColors.cyan),
      'uptime'        => const StatWidget(emoji: '✅', value: '99.8%', label: 'Uptime', sub: '23 Services', color: AppColors.green),
      'nas'           => const StatWidget(emoji: '💾', value: '4.1TB', label: 'NAS frei', sub: '44% belegt', color: AppColors.amber),
      'proxmox'       => const StatWidget(emoji: '🖥️', value: '23%', label: 'CPU', sub: 'Ryzen 9 7900X3D', color: AppColors.orange),
      'requests'      => const StatWidget(emoji: '🎥', value: '3', label: 'Requests', sub: 'Jellyseerr', color: AppColors.rose),
      _ => const SizedBox(),
    };

    if (!_editing) return widget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.008, end: 0.008, duration: 300.ms, curve: Curves.easeInOut),
        // Remove X
        Positioned(
          top: -10, left: -10,
          child: GestureDetector(
            onTap: () => _removeWidget(index),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.9),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8)],
              ),
              child: const Center(child: Text('×', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
        // Move buttons
        Positioned(
          top: 6, right: -12,
          child: Column(children: [
            _moveBtn('▲', index > 0, () => _moveUp(index)),
            const SizedBox(height: 4),
            _moveBtn('▼', index < _layout.length - 1, () => _moveDown(index)),
          ]),
        ),
      ],
    );
  }

  Widget _moveBtn(String icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: GlassCard(
        borderRadius: 8,
        weight: GlassWeight.thick,
        width: 24, height: 24,
        child: Center(
          child: Text(icon, style: TextStyle(
            fontSize: 10,
            color: enabled ? Colors.white : Colors.white24,
          )),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddSheet,
      child: GlassCard(
        borderRadius: 24,
        weight: GlassWeight.thin,
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('+', style: TextStyle(fontSize: 24, color: AppColors.cyan)),
            const SizedBox(width: 12),
            const Text('Widget hinzufügen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white60),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
