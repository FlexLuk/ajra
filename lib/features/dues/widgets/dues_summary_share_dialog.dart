import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../models/monthly_due.dart';
import '../screens/dues_list_screen.dart';

/// Modal dialog that renders a high-definition official summary card of monthly dues,
/// captures it to PNG via RepaintBoundary, and shares it directly to WhatsApp / downloads it.
class DuesSummaryShareDialog extends ConsumerStatefulWidget {
  final List<MonthlyDue>? dues;

  const DuesSummaryShareDialog({
    super.key,
    this.dues,
  });

  @override
  ConsumerState<DuesSummaryShareDialog> createState() => _DuesSummaryShareDialogState();
}

class _DuesSummaryShareDialogState extends ConsumerState<DuesSummaryShareDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  int? _selectedYear;
  int? _selectedMonth;
  bool _isExporting = false;

  List<MonthlyDue> _getAllDues() {
    if (widget.dues != null) return widget.dues!;
    return ref.watch(allDuesProvider).asData?.value ?? [];
  }

  void _initSelectedPeriod(List<MonthlyDue> dues) {
    if (_selectedYear != null && _selectedMonth != null) return;
    final now = DateTime.now();
    if (dues.any((d) => d.periodYear == now.year && d.periodMonth == now.month)) {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    } else if (dues.isNotEmpty) {
      _selectedYear = dues.first.periodYear;
      _selectedMonth = dues.first.periodMonth;
    } else {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    }
  }

  List<String> _getAvailablePeriods(List<MonthlyDue> dues) {
    final periods = <String>{};
    for (final d in dues) {
      periods.add('${d.periodYear}-${d.periodMonth.toString().padLeft(2, '0')}');
    }
    final sorted = periods.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<MonthlyDue> _getCurrentMonthDues(List<MonthlyDue> dues) {
    final y = _selectedYear ?? DateTime.now().year;
    final m = _selectedMonth ?? DateTime.now().month;
    final list = dues.where((d) => d.periodYear == y && d.periodMonth == m).toList();
    list.sort((a, b) => a.memberName.compareTo(b.memberName));
    return list;
  }

  String get _periodLabel {
    final date = DateTime(_selectedYear ?? DateTime.now().year, _selectedMonth ?? DateTime.now().month);
    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return monthName[0].toUpperCase() + monthName.substring(1);
  }

  String _buildWhatsAppMessageText({
    required List<MonthlyDue> dues,
  }) {
    final nowStr = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('📢 *Cotisations AJRA — $_periodLabel*');
    buffer.writeln('');
    for (final d in dues) {
      final isPaid = d.status == DueStatus.paid;
      final isDeclared = d.status == DueStatus.declared || d.status == DueStatus.inReview;
      final icon = isPaid ? '✅' : (isDeclared ? '⏳' : '❌');
      final statusLabel = isPaid ? 'Réglé' : (isDeclared ? 'En vérification' : 'À payer');
      buffer.writeln('$icon *${d.memberName}* : ${d.amount.toFormattedString()} ($statusLabel)');
    }
    buffer.writeln('');
    buffer.writeln('💡 *Rappel pour régler :*');
    buffer.writeln('Virement Juice MCB, Transfert bancaire ou Caisse AJRA.');
    buffer.writeln('');
    buffer.writeln('_Généré le $nowStr — AJRA Île Maurice_');
    return buffer.toString();
  }

  Future<Uint8List?> _capturePngBytes() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareOnWhatsApp(String textSummary) async {
    setState(() => _isExporting = true);
    try {
      final pngBytes = await _capturePngBytes();
      if (pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de générer l\'image PNG.')),
          );
        }
        return;
      }

      final y = _selectedYear ?? DateTime.now().year;
      final m = (_selectedMonth ?? DateTime.now().month).toString().padLeft(2, '0');
      final fileName = 'AJRA_Cotisations_${y}_$m.png';
      final xFile = XFile.fromData(
        pngBytes,
        name: fileName,
        mimeType: 'image/png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: textSummary,
          subject: 'AJRA - Cotisations $_periodLabel',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadPng() async {
    setState(() => _isExporting = true);
    try {
      final pngBytes = await _capturePngBytes();
      if (pngBytes == null) return;

      final y = _selectedYear ?? DateTime.now().year;
      final m = (_selectedMonth ?? DateTime.now().month).toString().padLeft(2, '0');
      final fileName = 'AJRA_Cotisations_${y}_$m.png';
      final xFile = XFile.fromData(
        pngBytes,
        name: fileName,
        mimeType: 'image/png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Image PNG $fileName prête.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _copyWhatsAppText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Texte récapitulatif copié ! Prêt à être collé dans WhatsApp.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDues = _getAllDues();
    _initSelectedPeriod(allDues);
    final availablePeriods = _getAvailablePeriods(allDues);
    final dues = _getCurrentMonthDues(allDues);

    int totalExpectedCents = 0;
    int totalCollectedCents = 0;
    int paidCount = 0;
    int declaredCount = 0;
    int pendingCount = 0;

    for (final d in dues) {
      totalExpectedCents += d.amount.cents;
      totalCollectedCents += d.amountPaid.cents;
      if (d.status == DueStatus.paid) {
        paidCount++;
      } else if (d.status == DueStatus.declared || d.status == DueStatus.inReview) {
        declaredCount++;
      } else {
        pendingCount++;
      }
    }

    final totalExpected = Money.fromCents(totalExpectedCents);
    final totalCollected = Money.fromCents(totalCollectedCents);
    final totalRemaining = Money.fromCents(
        totalExpectedCents > totalCollectedCents ? totalExpectedCents - totalCollectedCents : 0);
    final ratePercent =
        totalExpectedCents > 0 ? (totalCollectedCents * 100 / totalExpectedCents).round() : 0;

    final whatsappText = _buildWhatsAppMessageText(dues: dues);

    final currentPeriodKey = '${_selectedYear ?? DateTime.now().year}-${(_selectedMonth ?? DateTime.now().month).toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header modal
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.share_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Partager le Bilan des Cotisations (PNG)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (availablePeriods.length > 1) ...[
                      DropdownButton<String>(
                        value: availablePeriods.contains(currentPeriodKey) ? currentPeriodKey : availablePeriods.first,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        items: availablePeriods.map((p) {
                          final parts = p.split('-');
                          final y = int.parse(parts[0]);
                          final m = int.parse(parts[1]);
                          final label = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime(y, m));
                          return DropdownMenuItem(
                            value: p,
                            child: Text(label[0].toUpperCase() + label.substring(1)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final parts = val.split('-');
                            setState(() {
                              _selectedYear = int.parse(parts[0]);
                              _selectedMonth = int.parse(parts[1]);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Visual preview scrollable area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: _buildInfographicCard(
                        dues: dues,
                        totalExpected: totalExpected,
                        totalCollected: totalCollected,
                        totalRemaining: totalRemaining,
                        ratePercent: ratePercent,
                        paidCount: paidCount,
                        declaredCount: declaredCount,
                        pendingCount: pendingCount,
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),
              // Action buttons footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // WhatsApp Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text(
                              'Partager sur WhatsApp (Image PNG)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isExporting ? null : () => _shareOnWhatsApp(whatsappText),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Download PNG Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Télécharger PNG'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isExporting ? null : _downloadPng,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Copy Text button
                    InkWell(
                      onTap: () => _copyWhatsAppText(whatsappText),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.copy, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Copier le récapitulatif textuel pour WhatsApp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Official card design to be captured as PNG (560px width, crisp typography)
  Widget _buildInfographicCard({
    required List<MonthlyDue> dues,
    required Money totalExpected,
    required Money totalCollected,
    required Money totalRemaining,
    required int ratePercent,
    required int paidCount,
    required int declaredCount,
    required int pendingCount,
  }) {
    final nowStr = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(DateTime.now());

    return Container(
      width: 560,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête épuré
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cotisations AJRA — $_periodLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${dues.length} membre(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des membres et statuts
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                if (dues.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Aucune cotisation générée pour ce mois.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dues.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = dues[index];
                        final isPaid = d.status == DueStatus.paid;
                        final isDeclared = d.status == DueStatus.declared || d.status == DueStatus.inReview;

                        final statusBg = isPaid
                            ? const Color(0xFFECFDF5)
                            : isDeclared
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFFEF2F2);

                        final statusFg = isPaid
                            ? const Color(0xFF047857)
                            : isDeclared
                                ? const Color(0xFFB45309)
                                : const Color(0xFFDC2626);

                        final statusText = isPaid
                            ? 'Réglé'
                            : isDeclared
                                ? 'En vérification'
                                : 'À payer';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              // Avatar initial
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(
                                  d.memberName.isNotEmpty ? d.memberName[0].toUpperCase() : 'M',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Nom du membre
                              Expanded(
                                child: Text(
                                  d.memberName,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Montant
                              Text(
                                d.amount.toFormattedString(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              // Badge Statut
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusFg.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Pied de page officiel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Bureau AJRA • Île Maurice',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  'Généré le $nowStr',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
