import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'core/constants/app_icons.dart';
import 'core/constants/colors.dart';
import 'core/theme/app_theme.dart';
import 'package:app_links/app_links.dart';
import 'providers/providers.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/services/services_screen.dart';
import 'screens/newsletter/newsletter_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: FamilyHubApp()));
}

class FamilyHubApp extends StatelessWidget {
  const FamilyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Hub',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();
  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate>
    with WidgetsBindingObserver {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshIfNeeded();
    }
  }

  void _listenDeepLinks() {
    _appLinks = AppLinks();
    // Handle link that launched the app from cold start
    _appLinks.getInitialLink().then(_handleLink);
    // Handle links while app is running
    _appLinks.uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleLink(Uri? uri) async {
    if (uri == null) return;
    // hubstinger://auth?token=<jwt> or hubstinger://auth#token=<jwt>
    if (uri.scheme == 'hubstinger' && uri.host == 'auth') {
      String? token = uri.queryParameters['token'];
      if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
        token = Uri.splitQueryString(uri.fragment)['token'];
      }
      if (token != null && token.isNotEmpty) {
        await AuthService.instance.saveToken(token);
        if (mounted) ref.read(authProvider.notifier).reloadUser();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.violet)),
      );
    }

    if (!auth.isLoggedIn) return const LoginScreen();

    PushService.instance.init();
    return const MainShell();
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeScreen(),
    ServicesScreen(),
    NewsletterScreen(),
    SettingsScreen(),
  ];

  static const _tabs = [
    (AppIcons.home, 'Home'),
    (AppIcons.services, 'Services'),
    (AppIcons.newsletter, 'Newsletter'),
    (AppIcons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabIndexProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          const _BackgroundOrbs(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _screens[tab],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(
              currentIndex: tab,
              tabs: _tabs,
              onTap: (i) => ref.read(tabIndexProvider.notifier).state = i,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background Orbs ──────────────────────────────────────────────────────────
class _BackgroundOrbs extends StatefulWidget {
  const _BackgroundOrbs();

  @override
  State<_BackgroundOrbs> createState() => _BackgroundOrbsState();
}

class _BackgroundOrbsState extends State<_BackgroundOrbs>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  final _orbs = [
    (700.0, -150.0, -150.0, AppColors.bgOrb1, 9.0),
    (550.0, 250.0, double.infinity, AppColors.bgOrb2, 13.0),
    (450.0, double.infinity, 50.0, AppColors.bgOrb3, 8.0),
    (350.0, 450.0, 200.0, AppColors.bgOrb4, 11.0),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = _orbs
        .map((o) => AnimationController(
              vsync: this,
              duration: Duration(seconds: o.$5.toInt()),
            )..repeat(reverse: true))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: _orbs.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (_, __) {
              final t = _controllers[i].value;
              return Positioned(
                top: o.$2 != double.infinity ? o.$2 - 50 * t : null,
                left: o.$3 != double.infinity ? o.$3 - 30 * t : null,
                right: o.$3 == double.infinity ? 0 : null,
                child: Container(
                  width: o.$1,
                  height: o.$1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [o.$4, Colors.transparent],
                      stops: const [0, 0.7],
                    ),
                  ),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: o.$4.withOpacity(0.55)),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

// ── Bottom Tab Bar ────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final List<(IconData, String)> tabs;
  final ValueChanged<int> onTap;

  const _BottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.11),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: const Border(
              top: BorderSide(color: AppColors.white22, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(top: 13, bottom: bottom > 0 ? 4 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: tabs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      final active = currentIndex == i;
                      return GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 3,
                                width: active ? 36 : 0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [AppColors.violet, AppColors.cyan],
                                  ),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                              color: AppColors.violet
                                                  .withOpacity(0.8),
                                              blurRadius: 12),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  shadows: active
                                      ? [
                                          Shadow(
                                              color: AppColors.violet
                                                  .withOpacity(0.9),
                                              blurRadius: 14),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  t.$1,
                                  size: active ? 24 : 21,
                                  color: active ? Colors.white : Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: active ? Colors.white : Colors.white30,
                                  letterSpacing: 0.3,
                                ),
                                child: Text(t.$2),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
