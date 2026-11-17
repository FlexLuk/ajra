import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';
import 'ajra_text_field.dart';

class AjraCurrencyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(Money)? onMoneyChanged;

  const AjraCurrencyField({
    super.key,
    required this.controller,
    this.label = 'Montant (MUR)',
    this.hint = '0.00',
    this.validator,
    this.onMoneyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AjraTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          AppConstants.currencySymbol,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      onChanged: (val) {
        if (onMoneyChanged != null) {
          final clean = val.replaceAll(',', '.').trim();
          final numVal = double.tryParse(clean) ?? 0.0;
          onMoneyChanged!(Money.fromRupees(numVal));
        }
      },
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Veuillez saisir un montant';
        }
        final clean = val.replaceAll(',', '.').trim();
        final parsed = double.tryParse(clean);
        if (parsed == null || parsed <= 0) {
          return 'Veuillez saisir un montant supérieur à 0';
        }
        if (validator != null) {
          return validator!(val);
        }
        return null;
      },
    );
  }
}
