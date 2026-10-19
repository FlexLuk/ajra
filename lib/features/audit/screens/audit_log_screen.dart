import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/audit_log_entry.dart';

final auditLogsProvider = StreamProvider<List<AuditLogEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colAuditLogs)
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => AuditLogEntry.fromJson(doc.data(), doc.id)).toList();
  });
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canView = user != null && (user.isAdmin || user.canViewAudit);

    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journal d\'Audit')),
        body: const Center(child: Text('Accès non autorisé.')),
      );
    }

    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'Audit & Sécurité'),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history_edu_outlined,
              title: 'Journal d\'audit vierge',
              message: 'Toutes les actions d\'approbation, de rejet et d\'encaissement seront consignées ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              final dateStr =
                  DateFormat('dd/MM/yyyy HH:mm:ss', 'fr_FR').format(log.timestamp);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.action,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Auteur : ${log.userName} (${log.userRole})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cible : ${log.entityType} [${log.entityId}]',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    if (log.details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          log.details.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des journaux d\'audit...'),
        error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
      ),
    );
  }
}
