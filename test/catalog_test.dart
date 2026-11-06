import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/features/auth/presentation/auth_controller.dart';
import 'package:test_task/features/auth/presentation/login_screen.dart';
import 'package:test_task/features/products/domain/product.dart';
import 'package:test_task/features/products/presentation/products_controller.dart';

void main() {
  test('parses a product page and skips missing fields', () {
    final page = ProductPage.fromJson({
      'products': [
        {
          'id': 1,
          'title': 'Essence Mascara',
          'price': 9.99,
          'rating': 4.9,
          'category': 'beauty',
          'images': ['https://example.com/a.png'],
        },
      ],
      'total': 194,
      'skip': 0,
      'limit': 10,
    });

    expect(page.total, 194);
    expect(page.products.single.title, 'Essence Mascara');
    expect(page.products.single.formattedPrice, r'$9.99');
    expect(page.products.single.brand, isEmpty);
    expect(page.products.single.gallery, ['https://example.com/a.png']);
  });

  test('products state knows when another page is available', () {
    const loading = ProductsState(
      products: [
        Product(
          id: 1,
          title: 'One',
          description: '',
          category: '',
          price: 1,
          discountPercentage: 0,
          rating: 0,
          stock: 1,
          brand: '',
          thumbnail: '',
          images: [],
          availabilityStatus: '',
        ),
      ],
      total: 20,
    );

    expect(loading.hasMore, isTrue);
    expect(loading.isEmpty, isFalse);
    expect(const ProductsState().isEmpty, isTrue);
  });

  test('maps connection failures to a readable message', () {
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/products'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(exception.message, contains('Could not reach the server'));
  });

  testWidgets('login requires a username and password', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
}

class _SignedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}
