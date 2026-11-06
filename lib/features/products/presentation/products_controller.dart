import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/features/products/data/product_repository.dart';
import 'package:test_task/features/products/domain/product.dart';

class ProductsState {
  const ProductsState({
    this.products = const [],
    this.total = 0,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.loadMoreError,
  });

  final List<Product> products;
  final int total;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? loadMoreError;

  bool get hasMore => products.length < total;

  bool get isEmpty =>
      !isInitialLoading && errorMessage == null && products.isEmpty;

  ProductsState copyWith({
    List<Product>? products,
    int? total,
    bool? isInitialLoading,
    bool? isLoadingMore,
    String? errorMessage,
    String? loadMoreError,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return ProductsState(
      products: products ?? this.products,
      total: total ?? this.total,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

final productsControllerProvider =
    NotifierProvider<ProductsController, ProductsState>(ProductsController.new);

class ProductsController extends Notifier<ProductsState> {
  /// Incremented whenever the first page is requested (initial load or
  /// refresh), so responses for an older version of the list are ignored.
  int _requestId = 0;

  /// Incremented for every next-page request, so only the newest one may
  /// clear [ProductsState.isLoadingMore].
  int _pageRequestId = 0;

  @override
  ProductsState build() {
    Future.microtask(loadInitial);
    return const ProductsState(isInitialLoading: true);
  }

  Future<void> loadInitial() async {
    final requestId = ++_requestId;
    state = const ProductsState(isInitialLoading: true);
    try {
      final page = await ref
          .read(productRepositoryProvider)
          .fetchProducts(skip: 0);
      if (!ref.mounted || requestId != _requestId) return;
      state = ProductsState(products: page.products, total: page.total);
    } catch (error) {
      if (!ref.mounted || requestId != _requestId) return;
      state = ProductsState(errorMessage: _messageFor(error));
    }
  }

  /// Returns an error message when refresh fails and the current list is kept.
  Future<String?> refresh() async {
    final requestId = ++_requestId;
    try {
      final page = await ref
          .read(productRepositoryProvider)
          .fetchProducts(skip: 0);
      if (!ref.mounted || requestId != _requestId) return null;
      state = ProductsState(products: page.products, total: page.total);
      return null;
    } catch (error) {
      if (!ref.mounted || requestId != _requestId) return null;
      if (state.products.isEmpty) {
        state = ProductsState(errorMessage: _messageFor(error));
        return null;
      }
      return _messageFor(error);
    }
  }

  Future<void> loadMore({bool userInitiated = false}) async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    if (state.loadMoreError != null && !userInitiated) return;

    final requestId = _requestId;
    final pageRequestId = ++_pageRequestId;
    final skip = state.products.length;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    // A page is only applied to the list it was requested for: no refresh
    // has started since, and the list still ends where this page begins.
    bool isCurrent() =>
        ref.mounted && requestId == _requestId && skip == state.products.length;

    try {
      final page = await ref
          .read(productRepositoryProvider)
          .fetchProducts(skip: skip);
      if (!isCurrent()) return;

      final ids = state.products.map((product) => product.id).toSet();
      final merged = [
        ...state.products,
        ...page.products.where((product) => ids.add(product.id)),
      ];
      state = state.copyWith(
        products: merged,
        total: page.total,
        isLoadingMore: false,
      );
    } catch (error) {
      if (!isCurrent()) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: _messageFor(error),
      );
    } finally {
      // A discarded response must still clear the footer spinner, unless a
      // newer page request has started and now owns the loading state.
      if (ref.mounted &&
          pageRequestId == _pageRequestId &&
          state.isLoadingMore) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  String _messageFor(Object error) {
    return error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';
  }
}
