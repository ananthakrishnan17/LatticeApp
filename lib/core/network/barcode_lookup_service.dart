import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class BarcodeLookupService {
  BarcodeLookupService._();
  static final instance = BarcodeLookupService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'NammaNanbanApp - Android/iOS - Version 1.0',
      },
    ),
  );

  /// Fetches product details by querying multiple free databases.
  /// Returns a map with 'name' and 'imageUrl' if found, otherwise null.
  Future<Map<String, String>?> fetchProductByBarcode(String barcode) async {
    // 1. Try UPCItemDB (Good for global and some regional FMCG)
    try {
      final response = await _dio.get('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['code'] == 'OK' && data['items'] != null && (data['items'] as List).isNotEmpty) {
          final item = data['items'][0] as Map<String, dynamic>;
          final String title = item['title']?.toString() ?? '';
          final List images = item['images'] as List? ?? [];
          
          if (title.isNotEmpty) {
            return {
              'name': title,
              if (images.isNotEmpty) 'imageUrl': images.first.toString(),
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[BarcodeLookup] UPCItemDB failed or rate-limited for $barcode: $e');
    }

    // 2. Try OpenFoodFacts (Good for food items, limited Indian DB)
    try {
      final response = await _dio.get('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // OpenFoodFacts returns status = 1 if the product is found
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'] as Map<String, dynamic>;
          
          final String? name = product['product_name']?.toString() ?? 
                               product['product_name_en']?.toString();
          final String? imageUrl = product['image_url']?.toString() ?? 
                                   product['image_front_url']?.toString();
                                   
          if (name != null && name.isNotEmpty) {
            return {
              'name': name,
              if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[BarcodeLookup] OpenFoodFacts failed for $barcode: $e');
    }

    return null;
  }
}
