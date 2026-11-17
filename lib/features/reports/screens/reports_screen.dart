import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dues/widgets/dues_summary_share_dialog.dart';
import '../../membership/providers/membership_provider.dart';
import '../../treasury/screens/treasury_dashboard_screen.dart';
import '../services/export_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _exportMembersCsv(BuildContext context, WidgetRef ref) async {
    final members = await ref.read(membershipRepositoryProvider).watchAllMembers().first;
    final csv = ExportService.exportMembersToCsv(members);
    await SharePlus.instance.share(
      ShareParams(
        text: csv,
        subject: 'AJRA_Membres_${DateTime.now().year}.csv',
      ),
    );
  }

  Future<void> _exportTransactionsCsv(BuildContext context, WidgetRef ref) async {
    final txs = await ref.read(accountingRepoProvider).watchTransactions().first;
    final csv = ExportService.exportTransactionsToCsv(txs);
    await SharePlus.instance.share(
      ShareParams(
        text: csv,
        subject: 'AJRA_Comptabilite_${DateTime.now().year}.csv',
      ),
    );
  }

  Future<void> _generateTreasuryPdf(BuildContext context, WidgetRef ref) async {
    final txs = await ref.read(accountingRepoProvider).watchTransactions().first;
    final validated = txs.where((t) => t.status == TransactionStatus.validated).toList();

    int inc = 0;
    int exp = 0;
    for (final t in validated) {
      if (t.type == TransactionType.income) inc += t.amount.cents;
      if (t.type == TransactionType.expense) exp += t.amount.cents;
    }

    final net = Money.fromCents(inc - exp);
    final totalInc = Money.fromCents(inc);
    final totalExp = Money.fromCents(exp);

    await ExportService.printTreasuryReportPdf(
      netBalance: net,
      totalIncome: totalInc,
      totalExpense: totalExp,
      transactions: validated,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canViewReports = user != null &&
        (user.isAdmin || user.canViewFinanceReports || user.canManageMembership);

    if (!canViewReports) {
      return Scaffold(
        appBar: AppBar(
          leading: const AjraBackButton(fallbackRoute: '/dashboard'),
          title: const Text('Rapports'),
        ),
        body: const Center(
          child: Text('Accès restreint aux utilisateurs habilités.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AjraBackButton(fallbackRoute: '/dashboard'),
        title: const Text('Rapports & Exports Officiels'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Cotisations WhatsApp & PNG
          _buildReportCard(
            title: 'Point Cotisations Mensuelles (PNG & WhatsApp)',
            description:
                'Génère une infographie visuelle officielle haute définition (PNG) prête à être partagée sur WhatsApp ou téléchargée, avec le détail des cotisations du mois.',
            icon: Icons.share_rounded,
            actionLabel: 'Partager le récapitulatif',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => const DuesSummaryShareDialog(),
              );
            },
          ),
          const SizedBox(height: 16),

          // Section Membres
          _buildReportCard(
            title: 'Registre des Membres (CSV)',
            description:
                'Exporte la liste complète des membres avec coordonnées, matricules et statuts. Les numéros de passeport sont exclus par défaut pour préserver la vie privée.',
            icon: Icons.people_outline,
            actionLabel: 'Exporter en CSV',
            onTap: () => _exportMembersCsv(context, ref),
          ),
          const SizedBox(height: 16),

          // Section Trésorerie PDF
          _buildReportCard(
            title: 'Bilan de Trésorerie Officiel (PDF)',
            description:
                'Génère un rapport comptable officiel imprimable contenant les recettes, les dépenses, le solde net en MUR et l\'historique des écritures validées.',
            icon: Icons.picture_as_pdf_outlined,
            actionLabel: 'Générer le PDF',
            onTap: () => _generateTreasuryPdf(context, ref),
          ),
          const SizedBox(height: 16),

          // Section Opérations CSV
          _buildReportCard(
            title: 'Journal des Opérations Financières (CSV)',
            description:
                'Télécharge l\'historique détaillé des écritures de caisse et de banque pour intégration dans un logiciel comptable externe ou audit annuel.',
            icon: Icons.table_view_outlined,
            actionLabel: 'Exporter en CSV',
            onTap: () => _exportTransactionsCsv(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          AjraButton(
            label: actionLabel,
            icon: Icons.download_rounded,
            height: 40,
            variant: AjraButtonVariant.primary,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
