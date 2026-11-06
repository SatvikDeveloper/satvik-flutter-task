import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:test_task/features/auth/presentation/auth_controller.dart';
import 'package:test_task/features/auth/presentation/login_screen.dart';
import 'package:test_task/features/products/domain/product.dart';
import 'package:test_task/features/products/presentation/product_detail_screen.dart';
import 'package:test_task/features/products/presentation/product_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider.select((state) => state.status), (
    previous,
    next,
  ) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/login',
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final onLogin = state.matchedLocation == '/login';

      if (status == AuthStatus.unknown) return null;
      if (status == AuthStatus.unauthenticated) {
        return onLogin ? null : '/login';
      }
      if (onLogin) return '/products';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              final extra = state.extra;
              return ProductDetailScreen(
                productId: id,
                initialProduct: extra is Product ? extra : null,
              );
            },
          ),
        ],
      ),
    ],
  );
});
