import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_task/features/auth/presentation/auth_controller.dart';
import 'package:test_task/features/products/domain/product.dart';
import 'package:test_task/features/products/presentation/product_detail_screen.dart';
import 'package:test_task/features/products/presentation/product_list_screen.dart';
import 'package:test_task/features/products/presentation/products_controller.dart';

/// Logical-pixel insets of common devices: (top, bottom).
const _devices = {
  'iPhone with home indicator': (47.0, 34.0),
  'Android gesture navigation': (24.0, 24.0),
  'Android 3-button navigation': (24.0, 48.0),
};

void main() {
  for (final MapEntry(key: name, value: (top, bottom)) in _devices.entries) {
    group(name, () {
      testWidgets('last product stays above the system bar', (tester) async {
        _setInsets(tester, top: top, bottom: bottom);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productsControllerProvider.overrideWith(_LoadedProducts.new),
              authControllerProvider.overrideWith(_SignedIn.new),
            ],
            child: const MaterialApp(home: ProductListScreen()),
          ),
        );

        final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
        expect(
          tester.getTopLeft(find.byType(ListTile).first).dy,
          appBarBottom + 8,
          reason: 'no extra top inset below the app bar',
        );

        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final lastTile = find.text('Product 20');
        expect(lastTile, findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(ListTile).last).dy,
          lessThanOrEqualTo(screenHeight - bottom - 8),
        );
      });

      testWidgets('product details end above the system bar', (tester) async {
        _setInsets(tester, top: top, bottom: bottom);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ProductDetailScreen(
                productId: 1,
                initialProduct: _product(1, description: 'Long text. ' * 400),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(ListView), const Offset(0, -100000));
        await tester.pumpAndSettle();

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          tester.getBottomLeft(find.textContaining('Long text.')).dy,
          lessThanOrEqualTo(screenHeight - bottom - 16),
        );
      });
    });
  }
}

void _setInsets(
  WidgetTester tester, {
  required double top,
  required double bottom,
}) {
  const ratio = 3.0;
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = const Size(390 * ratio, 844 * ratio)
    ..padding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio)
    ..viewPadding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
  addTearDown(tester.view.reset);
}

Product _product(int id, {String description = ''}) {
  return Product(
    id: id,
    title: 'Product $id',
    description: description,
    category: 'beauty',
    price: 1,
    discountPercentage: 0,
    rating: 4,
    stock: 1,
    brand: '',
    thumbnail: '',
    images: const [],
    availabilityStatus: '',
  );
}

class _LoadedProducts extends ProductsController {
  @override
  ProductsState build() {
    return ProductsState(
      products: [for (var id = 1; id <= 20; id++) _product(id)],
      total: 20,
    );
  }
}

class _SignedIn extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}
