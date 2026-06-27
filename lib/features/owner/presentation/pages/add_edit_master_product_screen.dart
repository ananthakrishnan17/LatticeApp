import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/entities/product.dart';

class AddEditMasterProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditMasterProductScreen({super.key, this.product});

  @override
  State<AddEditMasterProductScreen> createState() => _AddEditMasterProductScreenState();
}

class _AddEditMasterProductScreenState extends State<AddEditMasterProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _buyCtrl, _sellCtrl, _wsCtrl, _barcodeCtrl, _hsnCtrl;
  String? _imageUrl;
  bool _isActive = true;
  double _gstRate = 0.0;
  bool _isSaving = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _buyCtrl = TextEditingController(text: p != null ? p.purchasePrice.toStringAsFixed(2) : '');
    _sellCtrl = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _wsCtrl = TextEditingController(text: p != null && p.wholesalePrice > 0 ? p.wholesalePrice.toStringAsFixed(2) : '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _hsnCtrl = TextEditingController(text: p?.hsnCode ?? '');
    _gstRate = p?.gstRate ?? 0.0;
    _isActive = p?.isActive ?? true;
    _imageUrl = p?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _wsCtrl.dispose();
    _barcodeCtrl.dispose();
    _hsnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600);
      if (xFile != null) {
        setState(() => _imageUrl = xFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = Product(
        id: widget.product?.id,
        name: _nameCtrl.text.trim(),
        purchasePrice: double.tryParse(_buyCtrl.text.trim()) ?? 0.0,
        sellingPrice: double.tryParse(_sellCtrl.text.trim()) ?? 0.0,
        wholesalePrice: double.tryParse(_wsCtrl.text.trim()) ?? 0.0,
        stockQuantity: widget.product?.stockQuantity ?? 0.0,
        lowStockThreshold: widget.product?.lowStockThreshold ?? 5.0,
        gstRate: _gstRate,
        barcode: _barcodeCtrl.text.trim(),
        hsnCode: _hsnCtrl.text.trim(),
        isActive: _isActive,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        imageUrl: _imageUrl,
        unit: widget.product?.unit ?? 'piece',
      );

      final repo = sl<ProductRepository>();
      await repo.upsertMasterProduct(product);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save master product: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Master Product' : 'Add Master Product', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50.r,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          backgroundImage: _imageUrl != null
                              ? (_imageUrl!.startsWith('http') ? NetworkImage(_imageUrl!) : FileImage(File(_imageUrl!))) as ImageProvider
                              : null,
                          child: _imageUrl == null
                              ? Icon(Icons.add_a_photo, size: 30.sp, color: AppTheme.primary)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Details Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Basic Details', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                            SizedBox(height: 16.h),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: _inputDeco('Product Name *'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            SizedBox(height: 16.h),
                            TextFormField(
                              controller: _barcodeCtrl,
                              decoration: _inputDeco('Barcode'),
                            ),
                            SizedBox(height: 16.h),
                            SwitchListTile(
                              title: const Text('Is Active', style: TextStyle(fontFamily: 'Poppins')),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Pricing Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pricing & Tax', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _buyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDeco('Purchase Price *'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: _sellCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDeco('Selling Price *'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            TextFormField(
                              controller: _wsCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDeco('Wholesale Price (Optional)'),
                            ),
                            SizedBox(height: 16.h),
                            DropdownButtonFormField<double>(
                              value: _gstRate,
                              decoration: _inputDeco('GST Rate'),
                              items: const [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                                return DropdownMenuItem(value: rate, child: Text('$rate%'));
                              }).toList(),
                              onChanged: (v) => setState(() => _gstRate = v ?? 0.0),
                            ),
                            SizedBox(height: 16.h),
                            TextFormField(
                              controller: _hsnCtrl,
                              decoration: _inputDeco('HSN Code (Optional)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: Text('Save Master Product', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Poppins'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
