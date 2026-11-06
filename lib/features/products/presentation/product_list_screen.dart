import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:test_task/core/widgets/centered_status.dart';
import 'package:test_task/features/auth/presentation/auth_controller.dart';
import 'package:test_task/features/products/domain/product.dart';
import 'package:test_task/features/products/presentation/products_controller.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  Future<void> _refresh() async {
    final message = await ref
        .read(productsControllerProvider.notifier)
        .refresh();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 240) {
      ref.read(productsControllerProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsControllerProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _ProductListBody(state: state),
          ),
        ),
      ),
    );
  }
}

class _ProductListBody extends ConsumerWidget {
  const _ProductListBody({required this.state});

  final ProductsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return CenteredStatus(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load products',
        message: state.errorMessage,
        actionLabel: 'Try again',
        onAction: () =>
            ref.read(productsControllerProvider.notifier).loadInitial(),
      );
    }

    if (state.isEmpty) {
      return const CenteredStatus(
        icon: Icons.inventory_2_outlined,
        title: 'No products',
        message: 'The catalog is empty right now.',
      );
    }

    final extra = state.isLoadingMore || state.loadMoreError != null ? 1 : 0;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.products.length + extra,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= state.products.length) {
          return _LoadMoreFooter(error: state.loadMoreError);
        }
        return _ProductTile(product: state.products[index]);
      },
    );
  }
}

class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref
                  .read(productsControllerProvider.notifier)
                  .loadMore(userInitiated: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = product.thumbnail.isNotEmpty
        ? product.thumbnail
        : product.gallery.firstOrNull;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: imageUrl == null
              ? const ColoredBox(
                  color: Color(0xFFE7E5E4),
                  child: Icon(Icons.image_outlined),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Color(0xFFE7E5E4),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                ),
        ),
      ),
      title: Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${product.categoryLabel} · ${product.rating.toStringAsFixed(1)}',
      ),
      trailing: Text(product.formattedPrice, style: theme.textTheme.titleSmall),
      onTap: () => context.push('/products/${product.id}', extra: product),
    );
  }
}
