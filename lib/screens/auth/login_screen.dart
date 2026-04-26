import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass/glass_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl      = TextEditingController();
  bool _obscurePassword = true;
  bool _showServerField = false;
  bool _oidcAvailable   = false;
  bool _oidcLoading     = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await AuthService.instance.getBaseUrl();
    if (mounted) {
      _urlCtrl.text = url;
      if (url.isEmpty) setState(() => _showServerField = true);
      if (url.isNotEmpty) _checkOidc(url);
    }
  }

  Future<void> _checkOidc(String url) async {
    try {
      final health = await ApiService.instance.checkHealth();
      if (mounted) {
        setState(() => _oidcAvailable =
            health['oidc_configured'] == true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrlAndCheckOidc() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await AuthService.instance.saveBaseUrl(url);
    await _checkOidc(url);
  }

  Future<void> _login() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte Server-URL eingeben'),
        backgroundColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() => _showServerField = true);
      return;
    }
    await AuthService.instance.saveBaseUrl(url);

    final ok = await ref.read(authProvider.notifier)
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(authProvider).error ?? 'Login fehlgeschlagen'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loginWithAuthentik() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _showServerField = true);
      return;
    }
    await AuthService.instance.saveBaseUrl(url);
    setState(() => _oidcLoading = true);
    try {
      final oidcUrl = await ApiService.instance.getOidcUrl();
      if (oidcUrl == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OIDC nicht konfiguriert'),
          backgroundColor: AppColors.amber,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      final uri = Uri.parse(oidcUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler: $e'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _oidcLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final loading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          _buildOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),

                  // Logo
                  Center(
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.violet, AppColors.cyan]),
                        boxShadow: [BoxShadow(
                          color: AppColors.violet.withOpacity(0.5),
                          blurRadius: 40)],
                      ),
                      child: const Center(child: Text('⌂',
                        style: TextStyle(fontSize: 36))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Family Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                  const SizedBox(height: 6),
                  const Text('Dein Homelab Dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white38)),

                  const SizedBox(height: 56),

                  GlassCard(
                    weight: GlassWeight.thick,
                    rimColor: AppColors.violet.withOpacity(0.4),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Server URL
                        GestureDetector(
                          onTap: () => setState(
                              () => _showServerField = !_showServerField),
                          child: Row(children: [
                            const Icon(Icons.dns_outlined,
                                size: 14, color: Colors.white38),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              _urlCtrl.text.isNotEmpty
                                  ? _urlCtrl.text : 'Server-URL',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white38),
                              overflow: TextOverflow.ellipsis)),
                            Icon(
                              _showServerField
                                  ? Icons.expand_less : Icons.expand_more,
                              size: 16, color: Colors.white30),
                          ]),
                        ),
                        if (_showServerField) ...[
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _urlCtrl,
                            hint: 'https://hub.example.com',
                            icon: Icons.link,
                            keyboardType: TextInputType.url,
                            onSubmitted: (_) => _saveUrlAndCheckOidc(),
                          ),
                        ],

                        // OIDC button (shown when server is configured and OIDC available)
                        if (_oidcAvailable) ...[
                          const SizedBox(height: 20),
                          GlassCard(
                            borderRadius: 16,
                            weight: GlassWeight.mid,
                            rimColor: AppColors.cyan.withOpacity(0.5),
                            tint: AppColors.cyan.withOpacity(0.12),
                            onTap: (_oidcLoading || loading)
                                ? null : _loginWithAuthentik,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: _oidcLoading
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🔑',
                                        style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Text('Mit Authentik anmelden',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.cyan)),
                                  ])),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(children: [
                              Expanded(child: Divider(color: Colors.white12)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('oder',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white30))),
                              Expanded(child: Divider(color: Colors.white12)),
                            ]),
                          ),
                        ] else
                          const SizedBox(height: 20),

                        // Username + password
                        _buildField(
                          controller: _usernameCtrl,
                          hint: 'Benutzername',
                          icon: Icons.person_outline,
                          autofillHints: const [AutofillHints.username],
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _passwordCtrl,
                          hint: 'Passwort',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38, size: 20),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          onSubmitted: (_) => loading ? null : _login(),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        GlassCard(
                          borderRadius: 16,
                          weight: GlassWeight.thick,
                          rimColor: AppColors.violet.withOpacity(0.6),
                          tint: AppColors.violet.withOpacity(0.3),
                          onTap: loading ? null : _login,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Anmelden',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700))),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Text('Family Hub · Self-hosted',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white18)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
              prefixIcon: Icon(icon, color: Colors.white30, size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrbs() {
    return Positioned.fill(
      child: Stack(children: [
        Positioned(top: -100, left: -100,
          child: _orb(500, AppColors.bgOrb1)),
        Positioned(bottom: 0, right: -80,
          child: _orb(400, AppColors.bgOrb2)),
        Positioned(top: 200, right: -50,
          child: _orb(300, AppColors.bgOrb4)),
      ]),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent], stops: const [0, 0.7]),
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: color.withOpacity(0.55)),
      ),
    );
  }
}
