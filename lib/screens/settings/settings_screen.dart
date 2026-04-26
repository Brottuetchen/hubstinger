import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_icons.dart';
import '../../core/constants/colors.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _notifs = {
    'newsletter': true,
    'media': true,
    'alerts': false,
    'watchtime': false,
  };

  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await AuthService.instance.getBaseUrl();
    if (mounted) {
      _urlCtrl.text = url;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        weight: GlassWeight.mid,
        borderRadius: 24,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                color: AppColors.white35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String sub,
    Widget right, {
    bool last = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14)),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.white35,
                        ),
                      ),
                  ],
                ),
              ),
              right,
            ],
          ),
        ),
        if (!last) Divider(color: Colors.white.withOpacity(0.07), height: 1),
      ],
    );
  }

  Widget _toggle(bool on, VoidCallback onToggle) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: on
              ? const LinearGradient(colors: [AppColors.violet, AppColors.cyan])
              : null,
          color: on ? null : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: on
                ? AppColors.violet.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: AppColors.violet.withOpacity(0.5),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: 3,
              left: on ? 22 : 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12141F),
        title: const Text('Abmelden?'),
        content: const Text('Du wirst aus Family Hub abgemeldet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Abmelden',
              style: TextStyle(color: AppColors.rose),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  List<Map<String, dynamic>> _integrationsFromBootstrap(
    Map<String, dynamic> bootstrap,
  ) {
    final raw = (bootstrap['integrations'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final bootstrapAsync = ref.watch(appBootstrapProvider);
    final fullName =
        user?['full_name'] as String? ?? user?['username'] as String? ?? '-';
    final email = user?['email'] as String? ?? '';
    final isAdmin = user?['is_admin'] as bool? ?? false;
    final avatarChar = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 100),
        children: [
          const Text(
            'Einstellungen',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            weight: GlassWeight.thick,
            rimColor: AppColors.violet.withOpacity(0.3),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.violet, AppColors.cyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withOpacity(0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      avatarChar,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.white40,
                          ),
                        ),
                      const SizedBox(height: 7),
                      if (isAdmin)
                        GlassCard(
                          borderRadius: 8,
                          weight: GlassWeight.thin,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.violet.withOpacity(0.9),
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GlassCard(
                  borderRadius: 12,
                  weight: GlassWeight.thin,
                  onTap: _confirmLogout,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Abmelden',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.rose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            'Server',
            Column(
              children: [
                _row(
                  'Server URL',
                  '',
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'https://your-server.com',
                        hintStyle: TextStyle(
                          color: AppColors.white20,
                          fontSize: 12,
                        ),
                      ),
                      onSubmitted: AuthService.instance.saveBaseUrl,
                      onEditingComplete: () =>
                          AuthService.instance.saveBaseUrl(_urlCtrl.text),
                    ),
                  ),
                ),
                _row(
                  'Verbindung',
                  '',
                  const Row(
                    children: [
                      StatusDot(online: true),
                      SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                  last: true,
                ),
              ],
            ),
          ),
          _section(
            'Benachrichtigungen',
            Column(
              children: [
                _row(
                  'Newsletter',
                  'Neue Ausgaben via n8n',
                  _toggle(
                    _notifs['newsletter']!,
                    () => setState(
                      () => _notifs['newsletter'] = !_notifs['newsletter']!,
                    ),
                  ),
                ),
                _row(
                  'Neue Medien',
                  'Jellyfin Neuheiten',
                  _toggle(
                    _notifs['media']!,
                    () => setState(
                      () => _notifs['media'] = !_notifs['media']!,
                    ),
                  ),
                ),
                _row(
                  'Service Alerts',
                  'Uptime Kuma Push',
                  _toggle(
                    _notifs['alerts']!,
                    () => setState(
                      () => _notifs['alerts'] = !_notifs['alerts']!,
                    ),
                  ),
                ),
                _row(
                  'Watchtime Report',
                  'Jeden Freitag 17:00',
                  _toggle(
                    _notifs['watchtime']!,
                    () => setState(
                      () => _notifs['watchtime'] = !_notifs['watchtime']!,
                    ),
                  ),
                  last: true,
                ),
              ],
            ),
          ),
          bootstrapAsync.when(
            loading: () => _section(
              'Integrationen',
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => _section(
              'Integrationen',
              Text(
                'Integrationen konnten nicht geladen werden.\n$error',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            data: (bootstrap) {
              final integrations = _integrationsFromBootstrap(bootstrap);
              return _section(
                'Integrationen',
                Column(
                  children: integrations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final integration = entry.value;
                    final online = integration['online'] == true;
                    final configured = integration['configured'] == true;
                    final statusText = online
                        ? 'Verbunden'
                        : configured
                            ? 'Deaktiviert'
                            : 'Nicht konfiguriert';
                    final label = integration['label'] as String? ??
                        integration['name'] as String? ??
                        'Integration';
                    final description =
                        integration['description'] as String? ?? '';

                    return _row(
                      label,
                      description,
                      Row(
                        children: [
                          Icon(
                            AppIcons.resolve(
                              integration['icon_key'] as String?,
                            ),
                            size: 16,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          StatusDot(online: online, size: 6),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      last: index == integrations.length - 1,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          if (isAdmin)
            _section(
              'Backend Verwaltung',
              Column(
                children: [
                  _row(
                    'Plugin Manager',
                    'Plugins konfigurieren und aktivieren',
                    GlassCard(
                      borderRadius: 10,
                      weight: GlassWeight.thin,
                      onTap: () async {
                        final base = await AuthService.instance.getBaseUrl();
                        final uri = Uri.parse('$base/admin');
                        if (await canLaunchUrl(uri)) {
                          launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: const Text(
                        'Oeffnen >',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                    last: true,
                  ),
                ],
              ),
            ),
          _section(
            'App',
            Column(
              children: [
                _row(
                  'Version',
                  'Family Hub v2.0',
                  const Text(
                    'Aktuell',
                    style: TextStyle(fontSize: 12, color: Colors.white30),
                  ),
                ),
                _row(
                  'Flutter Build',
                  'iOS und Android',
                  const GlassCard(
                    borderRadius: 10,
                    weight: GlassWeight.thin,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text(
                      'Build >',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.white50,
                      ),
                    ),
                  ),
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
