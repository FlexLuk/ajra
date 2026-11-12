import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money.dart';

class FinancialAccount {
  final String id;
  final String name; // ex: "Caisse Espèces", "Compte MCB", "Compte SBM"
  final String description;
  final Money initialBalance;
  final Money currentBalance;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialAccount({
    required this.id,
    required this.name,
    required this.description,
    required this.initialBalance,
    required this.currentBalance,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancialAccount.cashDefault() {
    return FinancialAccount(
      id: AppConstants.accountCash,
      name: 'Caisse Espèces',
      description: 'Espèces détenues par le trésorier AJRA',
      initialBalance: const Money.zero(),
      currentBalance: const Money.zero(),
      isDefault: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  factory FinancialAccount.bankDefault() {
    return FinancialAccount(
      id: AppConstants.accountBank,
      name: 'Compte Bancaire Principal',
      description: 'Compte courant bancaire associatif (Île Maurice)',
      initialBalance: const Money.zero(),
      currentBalance: const Money.zero(),
      isDefault: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  factory FinancialAccount.juiceDefault() {
    return FinancialAccount(
      id: AppConstants.accountJuice,
      name: 'Juice',
      description: 'Compte Juice MCB associatif (Île Maurice)',
      initialBalance: const Money.zero(),
      currentBalance: const Money.zero(),
      isDefault: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  factory FinancialAccount.fromJson(Map<String, dynamic> json, String docId) {
    return FinancialAccount(
      id: docId,
      name: (json['name'] as String?) ?? 'Compte',
      description: (json['description'] as String?) ?? '',
      initialBalance: Money.fromCents((json['initialBalanceCents'] as num?)?.toInt() ?? 0),
      currentBalance: Money.fromCents((json['currentBalanceCents'] as num?)?.toInt() ?? 0),
      isDefault: (json['isDefault'] as bool?) ?? false,
      isActive: (json['isActive'] as bool?) ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'initialBalanceCents': initialBalance.cents,
      'currentBalanceCents': currentBalance.cents,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
