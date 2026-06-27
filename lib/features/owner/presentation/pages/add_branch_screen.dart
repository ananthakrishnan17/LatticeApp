import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/backend/owner_management_service.dart';
import '../../../../core/theme/app_theme.dart';

class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({super.key});

  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Branch name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await OwnerManagementService.instance.createBranch(name);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, result.branch);
    } else {
      setState(() {
        _saving = false;
        _error = result.error ?? 'Failed to create branch';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Branch')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Branch',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
            ),
            SizedBox(height: 6.h),
            Text(
              'Create a new branch for your organization.',
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
            ),
            SizedBox(height: 24.h),
            TextField(
              controller: _nameCtrl,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Branch Name *',
                hintText: 'e.g. North Branch, Outlet 2',
                prefixIcon: const Icon(Icons.store_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                errorText: _error,
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _saving
                    ? SizedBox(
                        width: 22.w,
                        height: 22.h,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Create Branch',
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
