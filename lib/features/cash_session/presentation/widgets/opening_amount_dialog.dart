import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'cash_denomination_dialog.dart';

class OpeningAmountResult {
  final double amount;
  final Map<int, int>? denominations;
  const OpeningAmountResult({required this.amount, this.denominations});
}

Future<OpeningAmountResult?> showOpeningAmountDialog(BuildContext context) {
  return showDialog<OpeningAmountResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OpeningAmountDialog(),
  );
}

class _OpeningAmountDialog extends StatefulWidget {
  const _OpeningAmountDialog();

  @override
  State<_OpeningAmountDialog> createState() => _OpeningAmountDialogState();
}

class _OpeningAmountDialogState extends State<_OpeningAmountDialog> {
  final _amountController = TextEditingController();
  Map<int, int>? _denominations;
  String? _validationError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _openDenominations() async {
    final result = await showCashDenominationDialog(
      context,
      title: 'Opening Cash Denominations',
      initialCounts: _denominations,
    );
    if (result == null) return;
    setState(() {
      _denominations = result.counts;
      _amountController.text = result.total.toStringAsFixed(2);
    });
  }

  void _submit() {
    final rawAmount = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount < 0) {
      setState(() => _validationError = 'Enter a valid opening amount.');
      return;
    }
    Navigator.pop(
      context,
      OpeningAmountResult(amount: amount, denominations: _denominations),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('Enter Opening Cash'),
        content: SizedBox(
          width: 360.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_validationError != null) {
                    setState(() => _validationError = null);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Opening Amount',
                  prefixText: '₹ ',
                ),
              ),
              if (_validationError != null) ...[
                SizedBox(height: 6.h),
                Text(
                  _validationError!,
                  style: AppTheme.caption.copyWith(color: AppTheme.danger),
                ),
              ],
              SizedBox(height: 10.h),
              OutlinedButton.icon(
                onPressed: _openDenominations,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Use Denomination Screen'),
              ),
              if (_denominations != null) ...[
                SizedBox(height: 8.h),
                Text(
                  'Selected from denominations: ${CurrencyFormatter.format(double.tryParse(_amountController.text.trim()) ?? 0)}',
                  style: AppTheme.caption.copyWith(color: AppTheme.accent),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Start Shift'),
          ),
        ],
      ),
    );
  }
}
