import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/features/products/data/product_repository.dart';
import 'package:test_task/features/products/domain/product.dart';
import 'package:test_task/features/products/presentation/products_controller.dart';

void main() {
  late _FakeProductRepository repository;
  late ProviderContainer container;

  ProductsController controller() =>
      container.read(productsControllerProvider.notifier);
  ProductsState state() => container.read(productsControllerProvider);

  setUp(() {
    repository = _FakeProductRepository();
    container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  /// Builds the controller and completes the initial request with ids 1-10.
  Future<void> loadFirstPage() async {
    container.listen(productsControllerProvider, (_, _) {});
    await _flush();
    repository.succeed(0, _page(start: 1));
    await _flush();
  }

  test('pagination appends the next page', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    expect(state().isLoadingMore, isTrue);
    expect(repository.requests.last.skip, 10);

    repository.succeed(1, _page(start: 11));
    await _flush();

    expect(state().products.map((p) => p.id), List.generate(20, (i) => i + 1));
    expect(state().isLoadingMore, isFalse);
    expect(state().loadMoreError, isNull);
  });

  test('pagination failure shows an error and Retry loads the page', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    repository.fail(1);
    await _flush();

    expect(state().isLoadingMore, isFalse);
    expect(state().loadMoreError, 'offline');
    expect(state().products, hasLength(10));

    await controller().loadMore();
    expect(repository.requests, hasLength(2), reason: 'scroll does not retry');

    unawaited(controller().loadMore(userInitiated: true));
    expect(state().isLoadingMore, isTrue);
    expect(state().loadMoreError, isNull);

    repository.succeed(2, _page(start: 11));
    await _flush();

    expect(state().products, hasLength(20));
    expect(state().isLoadingMore, isFalse);
  });

  test('refresh succeeding while a page loads discards that page', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    final refresh = controller().refresh();

    repository.succeed(2, _page(start: 101));
    expect(await refresh, isNull);
    expect(state().products.first.id, 101);
    expect(state().isLoadingMore, isFalse);

    repository.succeed(1, _page(start: 11));
    await _flush();

    expect(
      state().products.map((p) => p.id),
      List.generate(10, (i) => i + 101),
    );
    expect(state().isLoadingMore, isFalse);
  });

  test('refresh failing while a page loads keeps the list', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    final refresh = controller().refresh();

    repository.fail(2);
    expect(await refresh, 'offline');
    expect(state().products, hasLength(10));
    expect(state().isLoadingMore, isTrue, reason: 'page is still in flight');
  });

  test(
    'stale page succeeding after a failed refresh clears the spinner',
    () async {
      await loadFirstPage();

      unawaited(controller().loadMore());
      final refresh = controller().refresh();
      repository.fail(2);
      await refresh;

      repository.succeed(1, _page(start: 11));
      await _flush();

      expect(state().products, hasLength(10));
      expect(state().isLoadingMore, isFalse);
      expect(state().loadMoreError, isNull);

      unawaited(controller().loadMore());
      expect(
        repository.requests.last.skip,
        10,
        reason: 'scrolling works again',
      );
      expect(state().isLoadingMore, isTrue);
    },
  );

  test(
    'stale page failing after a failed refresh clears the spinner',
    () async {
      await loadFirstPage();

      unawaited(controller().loadMore());
      final refresh = controller().refresh();
      repository.fail(2);
      await refresh;

      repository.fail(1);
      await _flush();

      expect(state().products, hasLength(10));
      expect(state().isLoadingMore, isFalse);
      expect(state().loadMoreError, isNull);

      unawaited(controller().loadMore());
      expect(
        repository.requests,
        hasLength(4),
        reason: 'scrolling works again',
      );
    },
  );

  test('stale page does not clear the spinner of a newer page', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    final refresh = controller().refresh();
    repository.succeed(2, _page(start: 1));
    await refresh;

    unawaited(controller().loadMore());
    expect(state().isLoadingMore, isTrue);

    repository.succeed(1, _page(start: 11));
    await _flush();
    expect(state().isLoadingMore, isTrue);
    expect(state().products, hasLength(10));

    repository.succeed(3, _page(start: 11));
    await _flush();
    expect(state().products, hasLength(20));
    expect(state().isLoadingMore, isFalse);
  });

  test(
    'page requested during a refresh is not appended to the new list',
    () async {
      await loadFirstPage();
      unawaited(controller().loadMore());
      repository.succeed(1, _page(start: 11));
      await _flush();
      expect(state().products, hasLength(20));

      final refresh = controller().refresh();
      unawaited(controller().loadMore());
      expect(repository.requests.last.skip, 20);

      repository.succeed(2, _page(start: 1));
      await refresh;
      repository.succeed(3, _page(start: 21));
      await _flush();

      expect(
        state().products.map((p) => p.id),
        List.generate(10, (i) => i + 1),
      );
      expect(state().isLoadingMore, isFalse);
    },
  );

  test('unexpected errors do not leave loading indicators stuck', () async {
    await loadFirstPage();

    unawaited(controller().loadMore());
    repository.requests[1].completer.completeError(StateError('bad json'));
    await _flush();

    expect(state().isLoadingMore, isFalse);
    expect(state().loadMoreError, 'Something went wrong. Please try again.');
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

ProductPage _page({required int start, int total = 30}) {
  return ProductPage(
    products: [
      for (var id = start; id < start + 10; id++)
        Product(
          id: id,
          title: 'Product $id',
          description: '',
          category: '',
          price: 1,
          discountPercentage: 0,
          rating: 0,
          stock: 1,
          brand: '',
          thumbnail: '',
          images: const [],
          availabilityStatus: '',
        ),
    ],
    total: total,
    skip: start - 1,
    limit: 10,
  );
}

class _Request {
  _Request(this.skip);

  final int skip;
  final completer = Completer<ProductPage>();
}

class _FakeProductRepository implements ProductRepository {
  final requests = <_Request>[];

  void succeed(int index, ProductPage page) {
    requests[index].completer.complete(page);
  }

  void fail(int index) {
    requests[index].completer.completeError(const ApiException('offline'));
  }

  @override
  Future<ProductPage> fetchProducts({required int skip}) {
    final request = _Request(skip);
    requests.add(request);
    return request.completer.future;
  }

  @override
  Future<Product> fetchProduct(int id) => throw UnimplementedError();
}
