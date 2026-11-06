import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/features/auth/data/auth_repository.dart';
import 'package:test_task/features/auth/domain/auth_user.dart';
import 'package:test_task/features/products/presentation/products_controller.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState();
  }

  Future<void> restoreSession() async {
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      if (!ref.mounted) return;
      state = user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      // The saved session could not be checked (for example while offline).
      // It is kept, so the user stays signed in without profile details.
      if (!ref.mounted) return;
      state = const AuthState(status: AuthStatus.authenticated);
    } catch (_) {
      if (!ref.mounted) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(username: username, password: password);
      if (!ref.mounted) return;
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: error.message,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: 'Sign-in failed. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(productsControllerProvider);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
