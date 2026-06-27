import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/entities/product.dart';
import 'add_edit_master_product_screen.dart';

class MasterCatalogScreen extends StatefulWidget {
  const MasterCatalogScreen({super.key});

  @override
  State<MasterCatalogScreen> createState() => _MasterCatalogScreenState();
}

class _MasterCatalogScreenState extends State<MasterCatalogScreen> {
  final _searchCtrl = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMasterProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = sl<ProductRepository>();
      final products = await repository.getMasterProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load master catalog: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() => _filteredProducts = _allProducts);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.barcode?.toLowerCase().contains(q) ?? false) ||
            (p.sku?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Master Catalog', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMasterProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditMasterProductScreen()),
          );
          if (result == true) {
            _loadMasterProducts();
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterProducts,
              decoration: InputDecoration(
                hintText: 'Search master catalog...',
                hintStyle: TextStyle(fontFamily: 'Poppins', color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filterProducts('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
              SizedBox(height: 16.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontFamily: 'Poppins', fontSize: 14.sp),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: _loadMasterProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Text(
          _searchCtrl.text.isEmpty
              ? 'Master catalog is empty.\nAdd your first global product.'
              : 'No products found.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Poppins', fontSize: 16.sp),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.w),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              radius: 24.r,
              backgroundImage: product.imageUrl != null ? NetworkImage(product.imageUrl!) : null,
              child: product.imageUrl == null
                  ? Text(
                      product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18.sp),
                    )
                  : null,
            ),
            title: Text(
              product.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 16.sp),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4.h),
                Text(
                  '₹${product.sellingPrice.toStringAsFixed(2)} / ${product.unit}',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 14.sp),
                ),
                if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text('Barcode: ${product.barcode}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp, fontFamily: 'Poppins')),
                ]
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditMasterProductScreen(product: product)),
              );
              if (result == true) {
                _loadMasterProducts();
              }
            },
          ),
        );
      },
    );
  }
}
