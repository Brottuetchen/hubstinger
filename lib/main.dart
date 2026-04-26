import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/auth/login_screen.dart';
import 'services/push_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/services/services_screen.dart';
import 'screens/newsletter/newsletter_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/glass/glass_card.dart';
import 'dart:ui';

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
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.violet),
        ),
      );
    }

    if (!auth.isLoggedIn) return const LoginScreen();

    // Initialize push notifications after successful login (fails silently without Firebase).
    PushService.instance.init();

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    ServicesScreen(),
    NewsletterScreen(),
    SettingsScreen(),
  ];

  static const _tabs = [
    ('⌂', 'Home'),
    ('◈', 'Services'),
    ('✉', 'Newsletter'),
    ('⚙', 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          const _BackgroundOrbs(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _screens[_tab],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomBar(
              currentIndex: _tab,
              tabs: _tabs,
              onTap: (i) => setState(() => _tab = i),
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
    _controllers = _orbs.map((o) => AnimationController(
      vsync: this,
      duration: Duration(seconds: o.$5.toInt()),
    )..repeat(reverse: true)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
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
                  width: o.$1, height: o.$1,
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
  final List<(String, String)> tabs;
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
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.22), width: 1),
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
                    width: 36, height: 4,
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
                                  gradient: LinearGradient(
                                    colors: [AppColors.violet, AppColors.cyan],
                                  ),
                                  boxShadow: active ? [
                                    BoxShadow(color: AppColors.violet.withOpacity(0.8), blurRadius: 12),
                                  ] : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: active ? 24 : 21,
                                  shadows: active ? [
                                    Shadow(color: AppColors.violet.withOpacity(0.9), blurRadius: 14),
                                  ] : null,
                                ),
                                child: Text(t.$1),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
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
