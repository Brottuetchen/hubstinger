import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({bool? isLoggedIn, Map<String, dynamic>? user,
      bool? isLoading, String? error}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await AuthService.instance.isLoggedIn;
    if (loggedIn) {
      try {
        final user = await ApiService.instance.getMe();
        state = AuthState(isLoggedIn: true, user: user);
      } catch (_) {
        await AuthService.instance.logout();
        state = const AuthState(isLoggedIn: false);
      }
    } else {
      state = const AuthState(isLoggedIn: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiService.instance.login(username, password);
      final user = await ApiService.instance.getMe();
      state = AuthState(isLoggedIn: true, user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(
        isLoggedIn: false,
        error: e.statusCode == 401 ? 'Falscher Benutzername oder Passwort' : e.message,
      );
      return false;
    } catch (_) {
      state = const AuthState(
        isLoggedIn: false,
        error: 'Server nicht erreichbar',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    state = const AuthState(isLoggedIn: false);
  }

  /// Re-fetch user info after an OIDC deep-link login.
  Future<void> reloadUser() async {
    try {
      final user = await ApiService.instance.getMe();
      state = AuthState(isLoggedIn: true, user: user);
    } catch (_) {
      await AuthService.instance.logout();
      state = const AuthState(isLoggedIn: false);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);

// ── Jellyfin Sessions ─────────────────────────────────────────────────────────

final sessionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ApiService.instance.getSessions();
});

// ── Recently Added ────────────────────────────────────────────────────────────

final recentlyAddedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ApiService.instance.getRecentlyAdded();
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ApiService.instance.getStats();
});

// ── Newsletter Archive ────────────────────────────────────────────────────────

final newsletterArchiveProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ApiService.instance.getNewsletterArchive();
});

// ── Server URL ────────────────────────────────────────────────────────────────

final baseUrlProvider = FutureProvider<String>((ref) {
  return AuthService.instance.getBaseUrl();
});
