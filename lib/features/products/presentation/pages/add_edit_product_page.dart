import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/barcode_lookup_service.dart';
import '../../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../settings/data/repositories/admin_setup_repository.dart';
import '../../../settings/domain/entities/admin_setup.dart';
import '../../../masters/domain/entities/masters.dart';
import '../../../masters/presentation/bloc/masters_bloc.dart';
import '../../../users/domain/entities/product_uom.dart';
import '../../../users/domain/entities/multi_uom_editor.dart';
import '../../domain/entities/bom_ingredient.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../../shared/widgets/searchable_dropdown_with_add.dart';

class AddEditProductPage extends StatefulWidget {
  final Product? product;

  /// When provided, pre-fills the barcode field.  Used when navigating here
  /// after a failed barcode scan so the user doesn't have to type the code.
  final String? initialBarcode;

  const AddEditProductPage({super.key, this.product, this.initialBarcode});
  @override State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _buyCtrl, _sellCtrl, _wsCtrl, _stockCtrl, _lowStockCtrl, _barcodeCtrl, _hsnCtrl, _skuCtrl;
  Category? _selectedCategory;
  Brand? _selectedBrand;
  UomUnit? _selectedUom;
  double _gstRate = 0.0;
  bool _gstInclusive = true;
  String _rateType = 'fixed';
  // 'physical' | 'raw_material' | 'composite_recipe' | 'service'
  String _itemType = 'physical';
  List<BomIngredient> _bomIngredients = [];
  String? _imageUrl;
  bool _isActive = true;
  bool _didInitializeSelectionsFromMasters = false;
  List<ProductUom> _pendingSaleUoms = [];
  List<ProductUom> _pendingPurchaseUoms = [];
  List<TaxSlabConfig> _taxSlabs = const [];
  bool get isEditing => widget.product != null;
  bool get _isRecipe => _itemType == 'composite_recipe';
  double get _bomCost => _bomIngredients.fold(0.0, (s, i) => s + i.totalCost);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  @override void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _buyCtrl = TextEditingController(text: p != null ? p.purchasePrice.toStringAsFixed(2) : '');
    _sellCtrl = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _wsCtrl = TextEditingController(text: p != null && p.wholesalePrice > 0 ? p.wholesalePrice.toStringAsFixed(2) : '');
    _stockCtrl = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _lowStockCtrl = TextEditingController(text: p?.lowStockThreshold.toString() ?? '5');
    // initialBarcode takes priority for new products; existing product keeps
    // its stored barcode when editing.
    _barcodeCtrl = TextEditingController(
        text: p?.barcode ?? widget.initialBarcode ?? '');
    _hsnCtrl = TextEditingController(text: p?.hsnCode ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _gstRate = p?.gstRate ?? 0.0;
    _gstInclusive = p?.gstInclusive ?? true;
    _rateType = p?.rateType ?? 'fixed';
    _isActive = p?.isActive ?? true;
    _itemType = p?.itemType ?? 'physical';
    _bomIngredients = p?.bomIngredients ?? [];
    _imageUrl = p?.imageUrl;
    _loadTaxSlabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MastersBloc>().add(LoadAllMasters());
      if (isEditing && widget.product!.id != null) {
        context.read<ProductBloc>().add(LoadProductUoms(widget.product!.id!));
        // Load purchase uoms directly
        _loadPurchaseUoms(widget.product!.id!);
      }
    });
  }

  Future<void> _loadPurchaseUoms(int productId) async {
    final repo = ProductUomRepository(DatabaseHelper.instance);
    final uoms = await repo.getPurchaseUomsForProduct(productId);
    if (mounted) setState(() => _pendingPurchaseUoms = uoms);
  }

  Future<void> _loadTaxSlabs() async {
    final slabs = await AdminSetupRepository.instance.getEnabledTaxSlabs();
    if (!mounted) return;
    setState(() {
      _taxSlabs = slabs;
      if (_taxSlabs.isNotEmpty && !_taxSlabs.any((s) => s.rate == _gstRate)) {
        _gstRate = _taxSlabs.first.rate;
        _gstInclusive = _taxSlabs.first.isInclusive;
      }
    });
  }

  Future<void> _generateSku() async {
    if (await _isOnlineMode()) {
      final parts = const Uuid().v4().split('-');
      if (!mounted) return;
      setState(() => _skuCtrl.text = 'SKU-${parts[0]}${parts[1]}'.toUpperCase());
      return;
    }
    final db = await DatabaseHelper.instance.database;
    for (var i = 0; i < 10; i++) {
      final parts = const Uuid().v4().split('-');
      final sku = 'SKU-${parts[0]}${parts[1]}'.toUpperCase();
      final existing = await db.query(
        'products',
        columns: ['id'],
        where: 'sku = ?',
        whereArgs: [sku],
        limit: 1,
      );
      if (existing.isEmpty) {
        if (!mounted) return;
        setState(() => _skuCtrl.text = sku);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not auto-generate unique SKU. Please try again.'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  @override void dispose() {
    for (final c in [_nameCtrl,_buyCtrl,_sellCtrl,_wsCtrl,_stockCtrl,_lowStockCtrl,_barcodeCtrl,_hsnCtrl,_skuCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(docDir.path, 'product_images'));
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final ext = p.extension(picked.path);
      final filename = '${const Uuid().v4()}$ext';
      final savedImage = await File(picked.path).copy(p.join(imagesDir.path, filename));
      setState(() => _imageUrl = savedImage.path);
    }
  }

  Future<void> _scanBarcodeAndFetch() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(),
    );

    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _barcodeCtrl.text = barcode;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching product details...'), duration: Duration(seconds: 1)),
      );

      final productData = await BarcodeLookupService.instance.fetchProductByBarcode(barcode);
      if (!mounted) return;

      if (productData != null) {
        setState(() {
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = productData['name'] ?? '';
          }
          if (_imageUrl == null && productData.containsKey('imageUrl')) {
            _imageUrl = productData['imageUrl'];
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product details fetched successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found in global database. Please enter manually.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  void _initializeSelectionsFromMasters(
    List<Category> categories,
    List<Brand> brands,
    List<UomUnit> units,
  ) {
    if (_didInitializeSelectionsFromMasters) return;
    if (categories.isEmpty && brands.isEmpty && units.isEmpty) return;

    final product = widget.product;
    Category? category = _selectedCategory;
    Brand? brand = _selectedBrand;
    UomUnit? uom = _selectedUom;

    if (product != null) {
      if (category == null && product.categoryId != null) {
        for (final c in categories) {
          if (c.id == product.categoryId) {
            category = c;
            break;
          }
        }
      }
      if (brand == null && product.brandId != null) {
        for (final b in brands) {
          if (b.id == product.brandId) {
            brand = b;
            break;
          }
        }
      }
      if (uom == null) {
        if (product.uomId != null) {
          for (final unit in units) {
            if (unit.id == product.uomId) {
              uom = unit;
              break;
            }
          }
        }
        if (uom == null && product.unit.isNotEmpty) {
          for (final unit in units) {
            if (unit.shortName.toLowerCase() == product.unit.toLowerCase()) {
              uom = unit;
              break;
            }
          }
        }
      }
    } else {
      uom ??= units.isNotEmpty ? units.first : null;
    }

    _didInitializeSelectionsFromMasters = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCategory = category;
        _selectedBrand = brand;
        _selectedUom = uom;
      });
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final skuValue = _skuCtrl.text.trim();
    final isOnlineMode = await _isOnlineMode();
    if (!isOnlineMode && skuValue.isNotEmpty) {
      final db = await DatabaseHelper.instance.database;
      final duplicate = await db.query(
        'products',
        columns: ['id'],
        where: isEditing ? 'sku = ? AND id != ?' : 'sku = ?',
        whereArgs: isEditing ? [skuValue, widget.product!.id] : [skuValue],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SKU already exists. Please use a unique SKU.'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
        return;
      }
    }
    final now = DateTime.now();
    // For composite_recipe, purchase price = BOM cost
    final purchasePrice = _itemType == 'composite_recipe'
        ? _bomCost
        : double.tryParse(_buyCtrl.text) ?? 0.0;
    final p = ProductModel(
      id: widget.product?.id, name: _nameCtrl.text.trim(),
      categoryId: _selectedCategory?.id, categoryName: _selectedCategory?.name,
      brandId: _selectedBrand?.id, brandName: _selectedBrand?.name,
      uomId: _selectedUom?.id, uomShortName: _selectedUom?.shortName,
      purchasePrice: purchasePrice,
      // Open Rate: selling price is optional; default to 0
      sellingPrice: double.tryParse(_sellCtrl.text) ?? 0.0,
      wholesalePrice: double.tryParse(_wsCtrl.text) ?? 0.0,
      stockQuantity: _isRecipe ? 0.0 : (double.tryParse(_stockCtrl.text) ?? 0.0),
      unit: _selectedUom?.shortName ?? 'piece',
      lowStockThreshold: double.tryParse(_lowStockCtrl.text) ?? 5.0,
      gstRate: _gstRate, gstInclusive: _gstInclusive, rateType: _rateType,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      hsnCode: _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim(),
      sku: skuValue.isEmpty ? null : skuValue,
      isActive: _isActive,
      createdAt: widget.product?.createdAt ?? now, updatedAt: now,
      itemType: _itemType,
      attributes: _isRecipe ? BomIngredient.listToAttributesJson(_bomIngredients) : '{}',
      imageUrl: _imageUrl,
      // Legacy wholesale fields kept for backward compatibility with existing
      // data (v9 columns). These are not surfaced in the UI but must be
      // preserved so existing bill and report queries continue to work.
      // TODO(v14): evaluate removing once all devices migrate off v9 data.
      wholesaleUnit: widget.product?.wholesaleUnit ?? 'bag',
      retailUnit: widget.product?.retailUnit ?? 'kg',
      wholesaleToRetailQty: widget.product?.wholesaleToRetailQty ?? 1.0,
      retailPrice: widget.product?.retailPrice ?? 0.0,
    );
    try {
      final productBloc = context.read<ProductBloc>();
      final uomRepo = ProductUomRepository(DatabaseHelper.instance);
      if (isEditing) {
        // Await the update directly so errors surface immediately to the user.
        await productBloc.repository.updateProduct(p);
        productBloc.add(LoadProducts());
        await uomRepo.saveAllUoms(widget.product!.id!, _pendingSaleUoms, 'sale');
        await uomRepo.saveAllUoms(widget.product!.id!, _pendingPurchaseUoms, 'purchase');
      } else {
        // For new products: save product, get new ID, then save pending UOMs
        final newId = await productBloc.repository.addProduct(p);
        if (newId > 0) {
          if (_pendingSaleUoms.isNotEmpty) {
            await uomRepo.saveAllUoms(newId, _pendingSaleUoms, 'sale');
          }
          if (_pendingPurchaseUoms.isNotEmpty) {
            await uomRepo.saveAllUoms(newId, _pendingPurchaseUoms, 'purchase');
          }
        }
        if (mounted) productBloc.add(LoadProducts());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save product: $e'), backgroundColor: Colors.red),
        );
        return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50.h),
            ),
            child: Text(
              isEditing ? 'Update Product' : 'Add Product',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: BlocBuilder<MastersBloc, MastersState>(builder: (ctx, mastersState) {
        return BlocBuilder<ProductBloc, ProductState>(builder: (ctx2, productState) {
          final categories = productState is ProductsLoaded ? productState.categories : <Category>[];
          final brands = mastersState.brands;
          final units = mastersState.units;
          _initializeSelectionsFromMasters(categories, brands, units);
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: _imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: _imageUrl!.startsWith('http')
                                ? Image.network(_imageUrl!, fit: BoxFit.cover)
                                : Image.file(File(_imageUrl!), fit: BoxFit.cover),
                          )
                        : Icon(Icons.add_a_photo, size: 40.sp, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              _sec('📝 Basic Information'),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', prefixIcon: Icon(Icons.inventory_2)),
                  validator: (v) => v!.trim().isEmpty ? 'Name required' : null, textCapitalization: TextCapitalization.words),
              SizedBox(height: 10.h),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      prefixIcon: Icon(Icons.qr_code_2_outlined),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: _generateSku,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(64.w, 40.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Auto'),
                ),
              ]),
              SizedBox(height: 10.h),

              // PRODUCT TYPE
              _sec('🧩 Product Type'),
              Column(children: [
                Row(children: [
                  Expanded(child: _typeBtn('physical', 'Physical', '📦', 'Regular stocked item')),
                  SizedBox(width: 10.w),
                  Expanded(child: _typeBtn('raw_material', 'Raw Material', '🌾', 'Used in production')),
                ]),
                SizedBox(height: 10.h),
                Row(children: [
                  Expanded(child: _typeBtn('composite_recipe', 'Recipe / BOM', '🍳', 'Built from ingredients')),
                  SizedBox(width: 10.w),
                  Expanded(child: _typeBtn('service', 'Service', '🛠️', 'No stock tracking')),
                ]),
              ]),
              SizedBox(height: 20.h),

              // CATEGORY
              SearchableDropdownWithAdd<Category>(
                label: 'Category', hint: 'Select or create category', icon: Icons.category,
                selectedValue: _selectedCategory, items: categories,
                itemLabel: (c) => '${c.icon} ${c.name}', itemId: (c) => c.id,
                onChanged: (c) => setState(() => _selectedCategory = c),
                addNewLabel: 'Create Category',
                onAddNew: (name) async {
                  final bloc = context.read<ProductBloc>();
                  final newCategory = Category(name: name, icon: '📦', color: '#2196F3');
                  final id = await bloc.repository.addCategory(newCategory);
                  bloc.add(LoadProducts());
                  await Future.delayed(const Duration(milliseconds: 400));
                  final created = Category(id: id, name: name, icon: '📦', color: '#2196F3');
                  setState(() => _selectedCategory = created);
                  return created;
                },
              ),
              SizedBox(height: 10.h),

              // BRAND
              SearchableDropdownWithAdd<Brand>(
                label: 'Brand', hint: 'Select or create brand', icon: Icons.branding_watermark,
                selectedValue: _selectedBrand, items: brands,
                itemLabel: (b) => b.name, itemId: (b) => b.id,
                onChanged: (b) => setState(() => _selectedBrand = b),
                addNewLabel: 'Create Brand',
                onAddNew: (name) async {
                  final bloc = context.read<MastersBloc>();
                  final id = await bloc.repository.addBrand(name);
                  bloc.add(LoadAllMasters());
                  await Future.delayed(const Duration(milliseconds: 400));
                  final created = Brand(id: id, name: name, createdAt: DateTime.now());
                  setState(() => _selectedBrand = created);
                  return created;
                },
              ),
              SizedBox(height: 20.h),

              _sec('💰 Pricing'),
              Row(children: [
                if (!_isRecipe) ...[
                  Expanded(child: TextFormField(controller: _buyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Purchase Price *', prefixText: '₹ '),
                      validator: (v) { if (!_isRecipe) { if (v!.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; } return null; },
                      onChanged: (_) => setState(() {}))),
                  SizedBox(width: 10.w),
                ],
                Expanded(child: TextFormField(controller: _sellCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _rateType == 'open' ? 'Selling Price (optional)' : 'Selling Price *',
                      prefixText: '₹ ',
                      helperText: _rateType == 'open' ? 'Price entered at billing' : null,
                    ),
                    validator: (v) {
                      if (_rateType == 'open') return null;
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) => setState(() {}))),
              ]),
              SizedBox(height: 10.h),
              if (!_isRecipe) ...[
                TextFormField(controller: _wsCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Wholesale Price (optional)', prefixText: '₹ ', prefixIcon: Icon(Icons.store)),
                    onChanged: (_) => setState(() {})),
                SizedBox(height: 8.h), _profitPreview(),
              ],
              SizedBox(height: 10.h),

              // ── BOM Builder (composite_recipe only) ─────────────────────────
              if (_isRecipe) ...[
                _sec('🔧 Bill of Materials (Recipe)'),
                _BomBuilderCard(
                  products: productState is ProductsLoaded ? productState.products : [],
                  ingredients: _bomIngredients,
                  onChanged: (updated) => setState(() => _bomIngredients = updated),
                ),
                SizedBox(height: 8.h),
                if (_bomIngredients.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total BOM Cost', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                      Text('₹${_bomCost.toStringAsFixed(2)}', style: AppTheme.body.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                SizedBox(height: 20.h),
              ],
              SizedBox(height: 10.h),

              _sec('🏷️ Rate Type'),
              Row(children: [
                Expanded(child: _rateBtn('fixed', 'Fixed Rate', '🔒', 'Same price every time')),
                SizedBox(width: 10.w),
                Expanded(child: _rateBtn('open', 'Open Rate', '✏️', 'Enter price at billing')),
              ]),
              SizedBox(height: 20.h),

              // ── BASE STOCK UNIT ──────────────────────────────────────────────
              _sec('📦 Base Stock Unit'),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Helper chip — different message for recipe vs regular products
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 14.sp, color: AppTheme.primary),
                      SizedBox(width: 6.w),
                      Expanded(child: Text(
                          _isRecipe
                              ? 'Stock is automatically calculated from raw material availability.'
                              : 'All stock will be calculated in this unit.',
                          style: AppTheme.caption.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  SizedBox(height: 12.h),
                  if (_isRecipe) ...[
                    // For recipe products, show current derived stock as read-only.
                    // The user cannot manually set stock — it derives from raw materials.
                    if (isEditing)
                      Row(children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(children: [
                              Icon(Icons.bar_chart, size: 16.sp, color: AppTheme.textSecondary),
                              SizedBox(width: 8.w),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Available Stock (derived)',
                                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                                SizedBox(height: 2.h),
                                Text(
                                  '${_stockCtrl.text.isEmpty ? "0" : _stockCtrl.text} ${_selectedUom?.shortName ?? "units"}',
                                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ])),
                            ]),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(child: TextFormField(controller: _lowStockCtrl, keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Low Stock Alert'))),
                      ]),
                  ] else ...[
                    Row(children: [
                      Expanded(child: TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEditing ? 'Current Stock' : 'Opening Stock',
                            helperText: isEditing ? null : 'Initial stock quantity',
                          ),
                          validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                      SizedBox(width: 10.w),
                      Expanded(child: TextFormField(controller: _lowStockCtrl, keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Low Stock Alert'))),
                    ]),
                  ],
                  SizedBox(height: 12.h),
                  // UOM picker
                  SearchableDropdownWithAdd<UomUnit>(
                    label: 'Base Unit *', hint: 'Select or create base unit', icon: Icons.straighten,
                    selectedValue: _selectedUom, items: units,
                    itemLabel: (u) => '${u.name} (${u.shortName})', itemId: (u) => u.id,
                    onChanged: (u) => setState(() => _selectedUom = u),
                    addNewLabel: 'Create Unit',
                    onAddNew: (name) async {
                      final bloc = context.read<MastersBloc>();
                      final shortName = name.length > 4 ? name.substring(0, 4) : name;
                      final newUnit = UomUnit(name: name, shortName: shortName, createdAt: DateTime.now());
                      final id = await bloc.repository.addUnit(newUnit);
                      bloc.add(LoadAllMasters());
                      await Future.delayed(const Duration(milliseconds: 400));
                      final created = UomUnit(id: id, name: name, shortName: shortName, createdAt: DateTime.now());
                      setState(() => _selectedUom = created);
                      return created;
                    },
                  ),
                ]),
              ),
              SizedBox(height: 24.h),

              // ── PURCHASE UNITS ──────────────────────────────────────────────
              _sec('🛒 Purchase Units'),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Builder(builder: (ctx) {
                  final existingPurchaseUoms = _pendingPurchaseUoms;
                  final editorProductId = isEditing ? widget.product!.id! : -1;
                  return MultiUomEditor(
                    key: ValueKey('purchase_uoms_${editorProductId}_${existingPurchaseUoms.length}'),
                    productId: editorProductId,
                    availableUnits: units,
                    initialUoms: existingPurchaseUoms,
                    mode: UomEditorMode.purchase,
                    baseUnitShortName: _selectedUom?.shortName ?? '',
                    onChanged: (uoms) => setState(() => _pendingPurchaseUoms = uoms),
                  );
                }),
              ),
              SizedBox(height: 24.h),

              // ── SALE UNITS & PRICES ─────────────────────────────────────────
              _sec('💰 Sale Units & Prices'),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Builder(builder: (ctx) {
                  final existingSaleUoms = productState is ProductsLoaded
                      ? productState.productUoms
                      : const <ProductUom>[];
                  final editorProductId = isEditing ? widget.product!.id! : -1;
                  return MultiUomEditor(
                    key: ValueKey('sale_uoms_${editorProductId}_${existingSaleUoms.length}'),
                    productId: editorProductId,
                    availableUnits: units,
                    initialUoms: existingSaleUoms,
                    mode: UomEditorMode.sale,
                    baseUnitShortName: _selectedUom?.shortName ?? '',
                    onChanged: (uoms) => setState(() => _pendingSaleUoms = uoms),
                  );
                }),
              ),
              SizedBox(height: 24.h),

              _sec('🧾 GST Settings'),
              Wrap(spacing: 8.w, runSpacing: 8.h, children: (_taxSlabs.isEmpty
                  ? [TaxSlabConfig(rate: 0, isInclusive: true)]
                  : _taxSlabs).map((slab) {
                final rate = slab.rate;
                final sel = _gstRate == rate;
                return GestureDetector(
                  onTap: () => setState(() {
                    _gstRate = rate;
                    _gstInclusive = slab.isInclusive;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
                    child: Text('${rate.toStringAsFixed(0)}% GST', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: sel ? Colors.white : AppTheme.textPrimary)),
                  ),
                );
              }).toList()),
              if (_gstRate > 0) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                  child: Row(children: [
                    Expanded(child: Text('Configured as ${_gstInclusive ? "Inclusive" : "Exclusive"} slab', style: AppTheme.body)),
                  ]),
                ),
                SizedBox(height: 8.h),
                TextFormField(controller: _hsnCtrl, decoration: const InputDecoration(labelText: 'HSN Code', prefixIcon: Icon(Icons.numbers))),
                SizedBox(height: 8.h),
                _gstPreview(),
              ],
              SizedBox(height: 20.h),

              _sec('⚙️ Optional'),
              TextFormField(
                controller: _barcodeCtrl,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    color: AppTheme.primary,
                    onPressed: _scanBarcodeAndFetch,
                    tooltip: 'Scan Barcode',
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.divider)),
                child: Row(children: [Expanded(child: Text('Active Product', style: AppTheme.body)), Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: AppTheme.primary)]),
              ),
              SizedBox(height: 80.h),
            ])),
          );
        });
      }),
    );
  }

  Widget _sec(String l) => Padding(padding: EdgeInsets.only(bottom: 10.h), child: Text(l, style: AppTheme.heading3.copyWith(color: AppTheme.primary)));

  Widget _rateBtn(String type, String title, String emoji, String desc) {
    final sel = _rateType == type;
    return GestureDetector(
      onTap: () => setState(() => _rateType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider, width: sel ? 2 : 1)),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: sel ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(desc, style: AppTheme.caption.copyWith(fontSize: 9.sp), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _profitPreview() {
    final buy = double.tryParse(_buyCtrl.text) ?? 0;
    final sell = double.tryParse(_sellCtrl.text) ?? 0;
    final ws = double.tryParse(_wsCtrl.text) ?? 0;
    if (buy == 0 && sell == 0) return const SizedBox();
    final profit = sell - buy; final margin = sell > 0 ? (profit / sell) * 100 : 0.0;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: profit >= 0 ? AppTheme.accent.withOpacity(0.08) : AppTheme.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down, color: profit >= 0 ? AppTheme.accent : AppTheme.danger, size: 16.sp),
          SizedBox(width: 6.w),
          Text('Retail Profit: ₹${profit.toStringAsFixed(2)}  (${margin.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12.sp, color: profit >= 0 ? AppTheme.accent : AppTheme.danger, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
        ]),
        if (ws > 0) Text('Wholesale Profit: ₹${(ws - buy).toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: (ws-buy) >= 0 ? AppTheme.accent : AppTheme.danger, fontFamily: 'Poppins')),
      ]),
    );
  }

  Widget _gstPreview() {
    final price = double.tryParse(_sellCtrl.text) ?? 0;
    if (price == 0) return const SizedBox();
    final r = GstCalculator.calculate(baseAmount: price, gstRate: _gstRate, isInclusive: _gstInclusive);
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GST Breakdown (${_gstInclusive ? "Inclusive" : "Exclusive"})', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        _gstRow('Taxable Amount', r.taxableAmount),
        _gstRow('CGST (${(_gstRate/2).toStringAsFixed(1)}%)', r.cgst),
        _gstRow('SGST (${(_gstRate/2).toStringAsFixed(1)}%)', r.sgst),
        Divider(height: 8.h, color: AppTheme.divider),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total GST', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          Text('₹${r.gstAmount.toStringAsFixed(2)}', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ]),
      ]),
    );
  }
  Widget _gstRow(String l, double v) => Padding(padding: EdgeInsets.symmetric(vertical: 1.h), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: AppTheme.caption), Text('₹${v.toStringAsFixed(2)}', style: AppTheme.caption)]));

  Widget _typeBtn(String type, String title, String emoji, String desc) {
    final sel = _itemType == type;
    return GestureDetector(
      onTap: () => setState(() => _itemType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider, width: sel ? 2 : 1),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600,
              color: sel ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(desc, style: AppTheme.caption.copyWith(fontSize: 9.sp), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── BOM Builder Card ─────────────────────────────────────────────────────────
class _BomBuilderCard extends StatefulWidget {
  final List<Product> products;
  final List<BomIngredient> ingredients;
  final void Function(List<BomIngredient>) onChanged;

  const _BomBuilderCard({
    required this.products,
    required this.ingredients,
    required this.onChanged,
  });

  @override
  State<_BomBuilderCard> createState() => _BomBuilderCardState();
}

class _BomBuilderCardState extends State<_BomBuilderCard> {
  void _addIngredient() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IngredientPickerSheet(
        products: widget.products,
        existing: widget.ingredients,
        onAdded: (ing) {
          final updated = [...widget.ingredients, ing];
          widget.onChanged(updated);
        },
      ),
    );
  }

  void _remove(int index) {
    final updated = [...widget.ingredients]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Ingredients', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
            FilledButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        if (widget.ingredients.isEmpty)
          Padding(
            padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 14.h),
            child: Text('No ingredients yet. Tap "Add" to build the recipe.',
                style: AppTheme.caption),
          )
        else
          ...widget.ingredients.asMap().entries.map((e) {
            final i = e.value;
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.productName, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2.h),
                  Text('${i.quantity} ${i.unit}  •  ₹${i.totalCost.toStringAsFixed(2)} per unit',
                      style: AppTheme.caption),
                ])),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger),
                  onPressed: () => _remove(e.key),
                ),
              ]),
            );
          }),
        SizedBox(height: 4.h),
      ]),
    );
  }
}

// ─── Ingredient Picker Sheet ──────────────────────────────────────────────────
class _IngredientPickerSheet extends StatefulWidget {
  final List<Product> products;
  final List<BomIngredient> existing;
  final void Function(BomIngredient) onAdded;

  const _IngredientPickerSheet({
    required this.products,
    required this.existing,
    required this.onAdded,
  });

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  Product? _selected;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  String _searchQ = '';

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show physical products as ingredients (not recipes themselves)
    final filtered = widget.products
        .where((p) =>
            p.itemType != 'composite_recipe' &&
            p.name.toLowerCase().contains(_searchQ.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      child: Column(children: [
        SizedBox(height: 12.h),
        Container(width: 40.w, height: 4.h,
            decoration: BoxDecoration(color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2.r))),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text('Add Ingredient', style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _selected == null
              ? Column(children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQ = v),
                      decoration: const InputDecoration(
                          hintText: 'Search ingredient...', prefixIcon: Icon(Icons.search)),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Expanded(child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(filtered[i].name, style: AppTheme.body),
                      subtitle: Text(
                          'Stock: ${filtered[i].stockQuantity} ${filtered[i].unit}  •  ₹${filtered[i].purchasePrice}',
                          style: AppTheme.caption),
                      onTap: () => setState(() {
                        _selected = filtered[i];
                        _costCtrl.text = filtered[i].purchasePrice.toStringAsFixed(2);
                      }),
                    ),
                  )),
                ])
              : Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_selected!.name, style: AppTheme.heading2)),
                      TextButton(onPressed: () => setState(() => _selected = null),
                          child: const Text('Change')),
                    ]),
                    SizedBox(height: 12.h),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Qty per 1 unit',
                          suffixText: _selected!.unit,
                          helperText: 'Amount needed to make 1 output unit',
                        ),
                      )),
                      SizedBox(width: 10.w),
                      Expanded(child: TextField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Unit Cost (₹)',
                          prefixText: '₹ ',
                        ),
                      )),
                    ]),
                    SizedBox(height: 16.h),
                    Builder(builder: (ctx) {
                      final qty = double.tryParse(_qtyCtrl.text) ?? 1;
                      final cost = double.tryParse(_costCtrl.text) ?? 0;
                      return Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Line Cost', style: AppTheme.caption),
                          Text('₹${(qty * cost).toStringAsFixed(2)}',
                              style: AppTheme.body.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        final qty = double.tryParse(_qtyCtrl.text) ?? 1;
                        final cost = double.tryParse(_costCtrl.text) ?? _selected!.purchasePrice;
                        widget.onAdded(BomIngredient(
                          productId: _selected!.id,
                          productName: _selected!.name,
                          quantity: qty,
                          unit: _selected!.unit,
                          unitCost: cost,
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text('Add Ingredient'),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
}
