import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_task/core/network/api_client.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/features/products/domain/product.dart';

const productPageSize = 10;

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(dioProvider));
});

class ProductRepository {
  ProductRepository(this._dio);

  final Dio _dio;

  Future<ProductPage> fetchProducts({required int skip}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products',
        queryParameters: {'limit': productPageSize, 'skip': skip},
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException('Products could not be loaded.');
      }
      return ProductPage.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Product> fetchProduct(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/products/$id');
      final data = response.data;
      if (data == null) {
        throw const ApiException('Product could not be loaded.');
      }
      return Product.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
