import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../masters/domain/entities/masters.dart';

class CustomerPickerSheet extends StatefulWidget {
  final Customer? selectedCustomer;

  const CustomerPickerSheet({super.key, this.selectedCustomer});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  final _searchController = TextEditingController();
  final _repository = MastersRepositoryImpl(DatabaseHelper.instance);
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getAllCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _future = _repository.getAllCustomers(search: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Text('Select Customer', style: AppTheme.heading2),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _searchController,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search by name or phone',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 320.h,
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data ?? const <Customer>[];
                return ListView(
                  shrinkWrap: true,
                  children: [
                     _customerTile(
                       title: 'Walk-in customer',
                       subtitle: 'No registered customer selected',
                       isSelected: widget.selectedCustomer == null,
                       onTap: () => Navigator.pop(context, 'walk_in'),
                     ),
                    ...customers.map(
                      (customer) => _customerTile(
                        title: customer.name,
                        subtitle: [
                          if ((customer.phone ?? '').isNotEmpty) customer.phone!,
                          if ((customer.address ?? '').isNotEmpty)
                            customer.address!,
                        ].join(' • '),
                        isSelected: widget.selectedCustomer?.id == customer.id,
                        onTap: () => Navigator.pop(context, customer),
                      ),
                    ),
                    if (customers.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Text(
                          'No customers found',
                          style: AppTheme.caption,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTheme.body),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: AppTheme.caption),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.accent)
          : const Icon(Icons.chevron_right),
    );
  }
}
