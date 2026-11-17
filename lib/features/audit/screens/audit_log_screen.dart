import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/audit_log_entry.dart';

final auditLogsProvider = StreamProvider<List<AuditLogEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colAuditLogs)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) => AuditLogEntry.fromJson(doc.data(), doc.id)).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  });
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterRole; // 'ADMIN', 'BUREAU', 'USER'
  String? _filterEntity; // 'transaction', 'due', 'loan', 'member'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canView = user != null && (user.isAdmin || user.canViewAudit);

    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          leading: const AjraBackButton(fallbackRoute: '/dashboard'),
          title: const Text('Journal d\'Audit & Sécurité'),
        ),
        body: const Center(child: Text('Accès non autorisé.')),
      );
    }

    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AjraBackButton(fallbackRoute: '/dashboard'),
        title: const Text('Journal d\'Audit & Sécurité'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.refresh(auditLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          // Filtrage interactif
          final filtered = logs.where((log) {
            // Filtre Rôle
            if (_filterRole != null) {
              if (!log.userRole.toUpperCase().contains(_filterRole!)) {
                return false;
              }
            }

            // Filtre Entité
            if (_filterEntity != null) {
              final target = log.entityType.toLowerCase();
              final act = log.action.toLowerCase();
              if (_filterEntity == 'transaction' && !target.contains('transact') && !act.contains('transact')) {
                return false;
              }
              if (_filterEntity == 'due' && !target.contains('due') && !act.contains('due') && !act.contains('cotis')) {
                return false;
              }
              if (_filterEntity == 'loan' && !target.contains('loan') && !act.contains('loan') && !act.contains('emprunt')) {
                return false;
              }
              if (_filterEntity == 'member' && !target.contains('member') && !act.contains('member') && !act.contains('adhes')) {
                return false;
              }
            }

            // Recherche textuelle
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesAuthor = log.userName.toLowerCase().contains(q);
              final matchesAction = log.action.toLowerCase().contains(q);
              final matchesEntity = log.entityType.toLowerCase().contains(q) || log.entityId.toLowerCase().contains(q);
              final matchesDetails = log.details.toString().toLowerCase().contains(q);
              return matchesAuthor || matchesAction || matchesEntity || matchesDetails;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Zone de recherche et de filtres
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par auteur, action, référence...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Rôle Chips
                          FilterChip(
                            label: const Text('Tous rôles'),
                            selected: _filterRole == null,
                            onSelected: (_) => setState(() => _filterRole = null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('BUREAU'),
                            selected: _filterRole == 'BUREAU',
                            onSelected: (_) => setState(() {
                              _filterRole = _filterRole == 'BUREAU' ? null : 'BUREAU';
                            }),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('ADMIN'),
                            selected: _filterRole == 'ADMIN',
                            onSelected: (_) => setState(() {
                              _filterRole = _filterRole == 'ADMIN' ? null : 'ADMIN';
                            }),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 22, color: AppColors.borderLight),
                          const SizedBox(width: 12),
                          // Type d'action
                          FilterChip(
                            label: const Text('Toutes entités'),
                            selected: _filterEntity == null,
                            onSelected: (_) => setState(() => _filterEntity = null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Cotisations'),
                            selected: _filterEntity == 'due',
                            onSelected: (_) => setState(() {
                              _filterEntity = _filterEntity == 'due' ? null : 'due';
                            }),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Écritures / Trésorerie'),
                            selected: _filterEntity == 'transaction',
                            onSelected: (_) => setState(() {
                              _filterEntity = _filterEntity == 'transaction' ? null : 'transaction';
                            }),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Emprunts'),
                            selected: _filterEntity == 'loan',
                            onSelected: (_) => setState(() {
                              _filterEntity = _filterEntity == 'loan' ? null : 'loan';
                            }),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Adhésions / Membres'),
                            selected: _filterEntity == 'member',
                            onSelected: (_) => setState(() {
                              _filterEntity = _filterEntity == 'member' ? null : 'member';
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Compteur & réinitialisation si filtré
              if (_searchQuery.isNotEmpty || _filterRole != null || _filterEntity != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${filtered.length} entrée(s) filtrée(s) sur ${logs.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filterRole = null;
                            _filterEntity = null;
                          });
                        },
                        child: const Text(
                          'Réinitialiser',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1),

              // Liste des logs
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'Aucun résultat',
                        message: 'Aucun enregistrement d\'audit ne correspond à vos filtres actuels.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = filtered[index];
                          final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss', 'fr_FR').format(log.timestamp);
                          final isAdmin = log.userRole.toUpperCase().contains('ADMIN');
                          final isBureau = log.userRole.toUpperCase().contains('BUREAU');

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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Auteur : ${log.userName}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? const Color(0xFFFEE2E2)
                                            : (isBureau ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.userRole,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isAdmin
                                              ? const Color(0xFFB91C1C)
                                              : (isBureau ? const Color(0xFFB45309) : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cible : ${log.entityType} [${log.entityId}]',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                                if (log.details.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
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
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des journaux d\'audit...'),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.refresh(auditLogsProvider),
        ),
      ),
    );
  }
}
