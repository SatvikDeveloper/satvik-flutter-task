import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/core/widgets/centered_status.dart';
import 'package:test_task/features/products/data/product_repository.dart';
import 'package:test_task/features/products/domain/product.dart';

final productDetailProvider = FutureProvider.family<Product, int>((ref, id) {
  return ref.watch(productRepositoryProvider).fetchProduct(id);
});

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final int productId;
  final Product? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialProduct = this.initialProduct;
    if (initialProduct != null) {
      return _ProductDetailView(product: initialProduct);
    }

    final product = ref.watch(productDetailProvider(productId));
    return product.when(
      data: (value) => _ProductDetailView(product: value),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        final message = error is ApiException
            ? error.message
            : 'Product could not be loaded.';
        return Scaffold(
          appBar: AppBar(),
          body: CenteredStatus(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load product',
            message: message,
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(productDetailProvider(productId)),
          ),
        );
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            if (product.gallery.isNotEmpty)
              SizedBox(
                height: 280,
                child: PageView.builder(
                  itemCount: product.gallery.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      product.gallery[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (product.brand.isNotEmpty)
                        Chip(label: Text(product.brand)),
                      if (product.categoryLabel.isNotEmpty)
                        Chip(label: Text(product.categoryLabel)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 12),
                      if (product.discountPercentage > 0)
                        Text(
                          '${product.discountPercentage.toStringAsFixed(1)}% off',
                        ),
                      const Spacer(),
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 4),
                      Text(product.rating.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      if (product.availabilityStatus.isNotEmpty)
                        product.availabilityStatus,
                      '${product.stock} in stock',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(product.description, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
