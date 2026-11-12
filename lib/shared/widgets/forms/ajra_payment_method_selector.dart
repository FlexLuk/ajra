import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class PaymentMethodResult {
  final String method; // 'Transfert bancaire', 'Virement par Juice', 'Espèces', 'Autre'
  final String? bankName; // 'MCB', 'SBM', 'Absa', 'MauBank', 'Autre banque'
  final String? customDetails;
  final String fullLabel; // ex: 'Transfert bancaire (MCB)' or 'Virement par Juice'
  final String targetAccountId; // AppConstants.accountBank, accountJuice, accountCash

  const PaymentMethodResult({
    required this.method,
    this.bankName,
    this.customDetails,
    required this.fullLabel,
    required this.targetAccountId,
  });
}

class AjraPaymentMethodSelector extends StatefulWidget {
  final String initialMethod;
  final String? initialBank;
  final ValueChanged<PaymentMethodResult> onChanged;

  const AjraPaymentMethodSelector({
    super.key,
    this.initialMethod = 'Transfert bancaire',
    this.initialBank = 'MCB',
    required this.onChanged,
  });

  @override
  State<AjraPaymentMethodSelector> createState() => _AjraPaymentMethodSelectorState();
}

class _AjraPaymentMethodSelectorState extends State<AjraPaymentMethodSelector> {
  late String _selectedMethod;
  late String _selectedBank;
  final TextEditingController _otherController = TextEditingController();

  static const List<String> availableBanks = [
    'MCB (Mauritius Commercial Bank)',
    'SBM (State Bank of Mauritius)',
    'Absa Bank Mauritius',
    'MauBank',
    'Bank One',
    'Autre banque',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
    _selectedBank = widget.initialBank ?? 'MCB (Mauritius Commercial Bank)';
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChange());
  }

  void _notifyChange() {
    String fullLabel;
    String targetAccountId;

    switch (_selectedMethod) {
      case 'Transfert bancaire':
        fullLabel = 'Transfert bancaire ($_selectedBank)';
        targetAccountId = AppConstants.accountBank;
        break;
      case 'Virement par Juice':
        fullLabel = 'Virement par Juice (MCB)';
        targetAccountId = AppConstants.accountJuice;
        break;
      case 'Espèces':
        fullLabel = 'Espèces (Remise en mains propres)';
        targetAccountId = AppConstants.accountCash;
        break;
      case 'Autre':
      default:
        final extra = _otherController.text.trim();
        fullLabel = extra.isNotEmpty ? 'Autre : $extra' : 'Autre mode de paiement';
        targetAccountId = AppConstants.accountCash;
        break;
    }

    widget.onChanged(
      PaymentMethodResult(
        method: _selectedMethod,
        bankName: _selectedMethod == 'Transfert bancaire' ? _selectedBank : null,
        customDetails: _selectedMethod == 'Autre' ? _otherController.text.trim() : null,
        fullLabel: fullLabel,
        targetAccountId: targetAccountId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedMethod,
          decoration: const InputDecoration(
            labelText: 'Méthode de paiement *',
            prefixIcon: Icon(Icons.payment_outlined, color: AppColors.primary),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Transfert bancaire',
              child: Text('Transfert bancaire'),
            ),
            DropdownMenuItem(
              value: 'Virement par Juice',
              child: Text('Virement par Juice (MCB)'),
            ),
            DropdownMenuItem(
              value: 'Espèces',
              child: Text('Espèces'),
            ),
            DropdownMenuItem(
              value: 'Autre',
              child: Text('Autre'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedMethod = val);
              _notifyChange();
            }
          },
        ),
        if (_selectedMethod == 'Transfert bancaire') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: availableBanks.contains(_selectedBank) ? _selectedBank : availableBanks.first,
            decoration: const InputDecoration(
              labelText: 'Choisir la banque *',
              prefixIcon: Icon(Icons.account_balance_outlined, color: AppColors.primary),
            ),
            items: availableBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedBank = val);
                _notifyChange();
              }
            },
          ),
        ],
        if (_selectedMethod == 'Autre') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherController,
            decoration: const InputDecoration(
              labelText: 'Précisez le mode de paiement *',
              hintText: 'ex: Chèque, Orange Money, etc.',
              prefixIcon: Icon(Icons.edit_note, color: AppColors.primary),
            ),
            onChanged: (_) => _notifyChange(),
          ),
        ],
      ],
    );
  }
}
