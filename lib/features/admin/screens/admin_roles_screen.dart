import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../audit/models/audit_log_entry.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership/models/member_profile.dart';
import '../../membership/providers/membership_provider.dart';
import '../../membership/screens/member_detail_screen.dart';

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .snapshots()
      .map((snapshot) {
    final users = snapshot.docs.map((doc) => AppUser.fromJson(doc.data(), doc.id)).toList();
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  });
});

class AdminRolesScreen extends ConsumerStatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  ConsumerState<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends ConsumerState<AdminRolesScreen> {
  Future<void> _deleteUserAccount(AppUser targetUser) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action réservée exclusivement à l\'administrateur.')),
      );
      return;
    }

    if (targetUser.uid == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas supprimer votre propre compte administrateur.')),
      );
      return;
    }

    if (targetUser.email.toLowerCase().trim() == 'heriniaina.luk@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer le compte du super-administrateur principal.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Suppression irréversible',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous certain de vouloir supprimer définitivement le compte de :',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetUser.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                  Text(
                    targetUser.email,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cette opération effacera irrévocablement :\n'
              '• Le compte d\'accès utilisateur\n'
              '• Le dossier d\'adhésion et numéro matricule\n'
              '• Les déclarations et reçus de cotisation\n'
              '• Les pièces stockées (photos, passeport, justificatifs)\n'
              '• Les inscriptions aux événements et notifications',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Supprimer définitivement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Suppression du compte et de ses données en cours...'),
            ],
          ),
        ),
      );

      try {
        await ref.read(authRepositoryProvider).deleteUserAccountAndDataByAdmin(
          targetUserId: targetUser.uid,
          targetEmail: targetUser.email,
          adminUserId: currentUser.uid,
          adminName: currentUser.displayName,
        );

        ref.invalidate(allUsersProvider);
        ref.invalidate(allMembersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Compte et données de ${targetUser.displayName} supprimés avec succès.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('Erreur lors de la suppression : ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _createOrActivateMemberProfile(AppUser targetUser, {bool approveDirectly = true}) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action réservée exclusivement à l\'administrateur.')),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Vérification d'unicité d'email pour éviter les doubles fiches membres
      if (targetUser.email.isNotEmpty) {
        final existingMembers = await firestore
            .collection(AppConstants.colMembers)
            .get();
        for (final mDoc in existingMembers.docs) {
          if (mDoc.id != targetUser.uid) {
            final mData = mDoc.data();
            final existingEmail = (mData['email'] as String?)?.trim().toLowerCase() ?? '';
            if (existingEmail == targetUser.email.trim().toLowerCase()) {
              final existingName = mData['fullName'] ?? mData['firstName'] ?? 'Un autre membre';
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.danger,
                    content: Text(
                      'Doublon bloqué : L\'adresse e-mail "${targetUser.email}" est déjà utilisée par $existingName.',
                    ),
                  ),
                );
              }
              return;
            }
          }
        }
      }

      final docRef = firestore.collection(AppConstants.colMembers).doc(targetUser.uid);
      final doc = await docRef.get();
      final now = DateTime.now();

      if (doc.exists) {
        await docRef.update({
          'status': approveDirectly ? MembershipStatus.active.name : MembershipStatus.pending.name,
          'reviewedByUserId': currentUser.uid,
          'reviewedByName': currentUser.displayName,
          'approvedAt': approveDirectly ? now.toIso8601String() : null,
          'reviewNotes': 'Statut validé par l\'administrateur ${currentUser.displayName}',
          'updatedAt': now.toIso8601String(),
        });
      } else {
        final parts = targetUser.displayName.trim().split(' ');
        final firstName = parts.isNotEmpty ? parts.first : 'Membre';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : 'AJRA';
        final shortId = targetUser.uid.length >= 6 ? targetUser.uid.substring(0, 6).toUpperCase() : 'M001';
        final memberNumber = 'AJRA-${now.year}-$shortId';

        final newProfile = MemberProfile(
          id: targetUser.uid,
          userId: targetUser.uid,
          memberNumber: memberNumber,
          lastName: lastName,
          firstName: firstName,
          birthDate: DateTime(1995, 1, 1),
          residentialAddress: 'Maurice',
          email: targetUser.email,
          phone: '',
          photoUrl: targetUser.photoUrl,
          appliedAt: now,
          approvedAt: approveDirectly ? now : null,
          status: approveDirectly ? MembershipStatus.active : MembershipStatus.pending,
          reviewedByUserId: approveDirectly ? currentUser.uid : null,
          reviewedByName: approveDirectly ? currentUser.displayName : null,
          reviewNotes: approveDirectly ? 'Fiche créée et validée directement par l\'administrateur' : null,
          passportNumber: 'EN_ATTENTE',
          passportIssueDate: now,
          passportExpiryDate: now.add(const Duration(days: 365 * 2)),
          permitType: PermitType.worker,
          createdAt: now,
          updatedAt: now,
        );

        await docRef.set(newProfile.toJson());
      }

      final audit = AuditLogEntry(
        id: firestore.collection(AppConstants.colAuditLogs).doc().id,
        userId: currentUser.uid,
        userName: currentUser.displayName,
        userRole: currentUser.role.code,
        action: 'membership.direct_activation',
        entityType: 'membership',
        entityId: targetUser.uid,
        details: {
          'targetEmail': targetUser.email,
          'approvedDirectly': approveDirectly,
        },
        timestamp: now,
      );
      await firestore.collection(AppConstants.colAuditLogs).doc(audit.id).set(audit.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Fiche membre de ${targetUser.displayName} mise à jour avec succès.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erreur : ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _editUserRole(AppUser targetUser) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action réservée exclusivement à l\'administrateur.')),
      );
      return;
    }

    final memberDoc = await FirebaseFirestore.instance.collection(AppConstants.colMembers).doc(targetUser.uid).get();
    MemberProfile? memberProfile = memberDoc.exists ? MemberProfile.fromJson(memberDoc.data()!, memberDoc.id) : null;

    UserRole selectedRole = targetUser.role;
    final selectedPermissions = List<String>.from(targetUser.permissions);
    bool isSuspended = targetUser.isSuspended;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Gestion du compte : ${targetUser.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rôle attribué'),
                  items: UserRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Compte suspendu'),
                  subtitle: const Text('Désactive tout accès à l\'application'),
                  value: isSuspended,
                  onChanged: (val) => setModalState(() => isSuspended = val),
                  activeThumbColor: AppColors.danger,
                  contentPadding: EdgeInsets.zero,
                ),
                if (selectedRole == UserRole.bureau) ...[
                  const Divider(height: 24),
                  const Text(
                    'Permissions explicites du bureau :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...AppPermissions.allPermissions.map((perm) {
                    final label = AppPermissions.labels[perm] ?? perm;
                    final isChecked = selectedPermissions.contains(perm);

                    return CheckboxListTile(
                      title: Text(label, style: const TextStyle(fontSize: 12.5)),
                      value: isChecked,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedPermissions.add(perm);
                          } else {
                            selectedPermissions.remove(perm);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                ],
                const Divider(height: 24),
                const Text(
                  'Fiche Annuaire des Membres :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (memberProfile == null) ...[
                  const Text(
                    'Aucune fiche membre enregistrée pour cet utilisateur.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Créer & Valider la fiche membre'),
                    onPressed: () async {
                      Navigator.pop(ctx, false);
                      await _createOrActivateMemberProfile(targetUser, approveDirectly: true);
                    },
                  ),
                ] else if (memberProfile.isPending) ...[
                  const Text(
                    'Demande d\'adhésion en attente de décision.',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Valider l\'adhésion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx, false);
                          await _createOrActivateMemberProfile(targetUser, approveDirectly: true);
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Voir dossier'),
                        onPressed: () {
                          Navigator.pop(ctx, false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberDetailScreen(member: memberProfile),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge.fromMembershipStatus(memberProfile.status),
                      Text(
                        memberProfile.memberNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Voir fiche'),
                        onPressed: () {
                          Navigator.pop(ctx, false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberDetailScreen(member: memberProfile),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer le rôle'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(AppConstants.colUsers).doc(targetUser.uid).update({
        'role': selectedRole.code,
        'permissions': selectedRole == UserRole.bureau ? selectedPermissions : [],
        'isSuspended': isSuspended,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Audit Log
      final audit = AuditLogEntry(
        id: firestore.collection(AppConstants.colAuditLogs).doc().id,
        userId: currentUser.uid,
        userName: currentUser.displayName,
        userRole: currentUser.role.code,
        action: 'user.role.updated',
        entityType: 'user',
        entityId: targetUser.uid,
        details: {
          'targetEmail': targetUser.email,
          'newRole': selectedRole.code,
          'permissions': selectedPermissions,
          'isSuspended': isSuspended,
        },
        timestamp: DateTime.now(),
      );
      await firestore.collection(AppConstants.colAuditLogs).doc(audit.id).set(audit.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Rôle et permissions mis à jour avec succès.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final membersAsync = ref.watch(allMembersProvider);

    final membersByUserId = membersAsync.value?.fold<Map<String, MemberProfile>>(
      {},
      (map, m) => map..[m.userId] = m,
    ) ?? {};

    return Scaffold(
      appBar: AppBar(
        leading: const AjraBackButton(fallbackRoute: '/members'),
        title: const Text('Administration des Rôles & Utilisateurs'),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const EmptyStateView(
              icon: Icons.people_outline,
              title: 'Aucun compte utilisateur',
              message: 'Les comptes enregistrés apparaîtront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final u = users[index];
              final member = membersByUserId[u.uid];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                            child: Text(
                              u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        u.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    if (u.isSuspended)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.dangerLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'SUSPENDU',
                                          style: TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(u.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    StatusBadge.fromRole(u.role),
                                    if (member != null)
                                      StatusBadge.fromMembershipStatus(member.status)
                                    else
                                      const StatusBadge(
                                        label: 'Sans fiche membre',
                                        backgroundColor: Color(0xFFF3F4F6),
                                        textColor: Color(0xFF6B7280),
                                      ),
                                    if (u.role == UserRole.bureau && u.permissions.isNotEmpty)
                                      Text(
                                        '${u.permissions.length} perm.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (currentUser != null &&
                              currentUser.isAdmin &&
                              u.uid != currentUser.uid &&
                              u.email.toLowerCase().trim() != 'heriniaina.luk@gmail.com')
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined, color: AppColors.danger, size: 20),
                              tooltip: 'Supprimer ce compte et toutes ses données',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _deleteUserAccount(u),
                            )
                          else
                            const SizedBox.shrink(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (member == null)
                                TextButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: const Text('Activer membre', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _createOrActivateMemberProfile(u, approveDirectly: true),
                                )
                              else if (member.isPending)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Valider adhésion', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () => _createOrActivateMemberProfile(u, approveDirectly: true),
                                )
                              else
                                TextButton.icon(
                                  icon: const Icon(Icons.badge_outlined, size: 16),
                                  label: Text(member.memberNumber, style: const TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MemberDetailScreen(member: member),
                                      ),
                                    );
                                  },
                                ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Modifier rôle', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _editUserRole(u),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des comptes utilisateurs...'),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.refresh(allUsersProvider),
        ),
      ),
    );
  }
}
