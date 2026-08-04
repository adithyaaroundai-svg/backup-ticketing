import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/design_system.dart';

class ResolveBillDialog extends StatefulWidget {
  final String ticketId;
  final Future<bool> Function(String ticketId, double amount) onResolve;

  const ResolveBillDialog({
    super.key,
    required this.ticketId,
    required this.onResolve,
  });

  @override
  State<ResolveBillDialog> createState() => _ResolveBillDialogState();
}

class _ResolveBillDialogState extends State<ResolveBillDialog> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.onResolve(widget.ticketId, amount);
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve & Raise Bill'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the bill amount for this ticket. The ticket status will be updated to "Bill Raised".',
              style: TextStyle(fontSize: 14, color: AppColors.slate600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Bill Amount',
                prefixText: '₹ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          label: _isSubmitting ? 'Processing...' : 'Raise Bill',
          icon: _isSubmitting ? null : Icons.check,
        ),
      ],
    );
  }
}
