import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../audit/models/audit_log_entry.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => AppUser.fromJson(doc.data(), doc.id)).toList();
  });
});

class AdminRolesScreen extends ConsumerStatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  ConsumerState<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends ConsumerState<AdminRolesScreen> {
  Future<void> _editUserRole(AppUser targetUser) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action réservée exclusivement à l\'administrateur.')),
      );
      return;
    }

    UserRole selectedRole = targetUser.role;
    final selectedPermissions = List<String>.from(targetUser.permissions);
    bool isSuspended = targetUser.isSuspended;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Gestion du rôle : ${targetUser.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rôle attribué'),
                  items: UserRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.label));
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
                  activeColor: AppColors.danger,
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer les modifications'),
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
            content: Text('Rôles et permissions mis à jour avec succès.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration des Rôles & Permissions'),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const EmptyStateView(
              icon: Icons.people_outline,
              title: 'Aucun utilisateur',
              message: 'Les comptes enregistrés apparaîtront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final u = users[index];

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  title: Row(
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(u.email, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusBadge.fromRole(u.role),
                          if (u.role == UserRole.bureau && u.permissions.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${u.permissions.length} permission(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editUserRole(u),
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des comptes...'),
        error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
      ),
    );
  }
}
