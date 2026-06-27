import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/cash_session_repository.dart';

class CashDenominationResult {
  final Map<int, int> counts;
  final double total;
  const CashDenominationResult({required this.counts, required this.total});
}

Future<CashDenominationResult?> showCashDenominationDialog(
  BuildContext context, {
  required String title,
  Map<int, int>? initialCounts,
}) {
  return showDialog<CashDenominationResult>(
    context: context,
    builder: (ctx) => _CashDenominationDialog(
      title: title,
      initialCounts: initialCounts,
    ),
  );
}

class _CashDenominationDialog extends StatefulWidget {
  final String title;
  final Map<int, int>? initialCounts;
  const _CashDenominationDialog({required this.title, this.initialCounts});

  @override
  State<_CashDenominationDialog> createState() => _CashDenominationDialogState();
}

class _CashDenominationDialogState extends State<_CashDenominationDialog> {
  final _controllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final value in kCashDenominations) {
      _controllers[value] = TextEditingController(
        text: (widget.initialCounts?[value] ?? 0).toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _countFor(int value) {
    final parsed = int.tryParse(_controllers[value]!.text.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  double get _total {
    var total = 0.0;
    for (final value in kCashDenominations) {
      total += value * _countFor(value);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kCashDenominations.length,
                itemBuilder: (_, i) {
                  final value = kCashDenominations[i];
                  final count = _countFor(value);
                  final rowTotal = value * count;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        Expanded(child: Text('₹$value', style: AppTheme.body)),
                        SizedBox(
                          width: 90.w,
                          child: TextField(
                            controller: _controllers[value],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Count'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        SizedBox(
                          width: 100.w,
                          child: Text(
                            CurrencyFormatter.format(rowTotal.toDouble()),
                            textAlign: TextAlign.right,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${CurrencyFormatter.format(_total)}',
                style: AppTheme.heading3.copyWith(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final counts = <int, int>{
              for (final value in kCashDenominations) value: _countFor(value),
            };
            Navigator.pop(
              context,
              CashDenominationResult(counts: counts, total: _total),
            );
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
