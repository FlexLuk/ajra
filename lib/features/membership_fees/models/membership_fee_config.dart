import '../../../core/utils/money.dart';

class MembershipFeeConfig {
  final Money amount;
  final DateTime effectiveDate;
  final String updatedByUserId;
  final String updatedByName;
  final String bankInstructions;

  const MembershipFeeConfig({
    required this.amount,
    required this.effectiveDate,
    required this.updatedByUserId,
    required this.updatedByName,
    this.bankInstructions = 'Paiement hors-application par virement bancaire ou remise en espèces auprès du trésorier.',
  });

  factory MembershipFeeConfig.defaultConfig() {
    return MembershipFeeConfig(
      amount: Money.fromRupees(500), // 500 MUR par défaut
      effectiveDate: DateTime(2026, 1, 1),
      updatedByUserId: 'system',
      updatedByName: 'Système AJRA',
    );
  }

  factory MembershipFeeConfig.fromJson(Map<String, dynamic> json) {
    return MembershipFeeConfig(
      amount: Money.fromCents((json['amountCents'] as num?)?.toInt() ?? 50000),
      effectiveDate: DateTime.tryParse(json['effectiveDate']?.toString() ?? '') ?? DateTime.now(),
      updatedByUserId: (json['updatedByUserId'] as String?) ?? 'system',
      updatedByName: (json['updatedByName'] as String?) ?? 'Système',
      bankInstructions: (json['bankInstructions'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amountCents': amount.cents,
      'effectiveDate': effectiveDate.toIso8601String(),
      'updatedByUserId': updatedByUserId,
      'updatedByName': updatedByName,
      'bankInstructions': bankInstructions,
    };
  }
}
