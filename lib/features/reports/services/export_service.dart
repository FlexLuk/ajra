import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/money.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../membership/models/member_profile.dart';

class ExportService {
  /// Génère un fichier CSV pour la liste des membres (sans numéro de passeport par défaut)
  static String exportMembersToCsv(List<MemberProfile> members) {
    final rows = <List<dynamic>>[
      [
        'Matricule',
        'Nom',
        'Prénom',
        'Email',
        'Téléphone',
        'Statut Adhésion',
        'Permis',
        'Profession / Filière',
        'Date Demande',
      ],
    ];

    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final m in members) {
      rows.add([
        m.memberNumber,
        m.lastName,
        m.firstName,
        m.email,
        m.phone,
        m.status.label,
        m.permitType.label,
        m.jobTitle ?? m.fieldOfStudy ?? '',
        dateFormat.format(m.appliedAt),
      ]);
    }

    return _toCsv(rows);
  }

  /// Génère un fichier CSV pour les opérations comptables
  static String exportTransactionsToCsv(List<FinancialTransaction> transactions) {
    final rows = <List<dynamic>>[
      [
        'ID Opération',
        'Date',
        'Type',
        'Catégorie',
        'Montant (MUR)',
        'Description',
        'Mode Paiement',
        'Référence',
        'Statut',
      ],
    ];

    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final tx in transactions) {
      rows.add([
        tx.id,
        dateFormat.format(tx.date),
        tx.type.label,
        tx.category,
        tx.amount.inRupees,
        tx.description,
        tx.paymentMode,
        tx.reference,
        tx.status.label,
      ]);
    }

    return _toCsv(rows);
  }

  static String _toCsv(List<List<dynamic>> rows) {
    return rows.map((row) {
      return row.map((cell) {
        final str = cell?.toString() ?? '';
        if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(',');
    }).join('\r\n');
  }

  /// Imprime ou télécharge un rapport PDF récapitulatif de trésorerie
  static Future<void> printTreasuryReportPdf({
    required Money netBalance,
    required Money totalIncome,
    required Money totalExpense,
    required List<FinancialTransaction> transactions,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AJRA — Rapport de Trésorerie Officiel',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
                pw.Text(
                  dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Association des Jeunes de la Région Anosy à l\'Île Maurice (Devise : MUR / Rs.)',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Recettes validées', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(totalIncome.toFormattedString(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Dépenses validées', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(totalExpense.toFormattedString(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Solde net officiel', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(netBalance.toFormattedString(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Dernières écritures comptables validées :',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Catégorie', 'Description', 'Montant'],
            data: transactions.take(20).map((t) {
              return [
                dateFormat.format(t.date),
                t.type.label,
                t.category,
                t.description,
                t.amount.toFormattedString(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Rapport_Tresorerie_AJRA_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
