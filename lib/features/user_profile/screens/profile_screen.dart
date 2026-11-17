import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/cards/ajra_digital_member_card.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership/models/member_profile.dart';
import '../../membership/providers/membership_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _openEditProfileModal(AppUser user, MemberProfile? member) async {
    String initialFirstName = member?.firstName ?? '';
    String initialLastName = member?.lastName ?? '';
    if (member == null && user.displayName.isNotEmpty) {
      final parts = user.displayName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) initialFirstName = parts.first;
      if (parts.length > 1) initialLastName = parts.sublist(1).join(' ');
    }

    final firstNameController = TextEditingController(text: initialFirstName);
    final lastNameController = TextEditingController(text: initialLastName);
    final phoneController = TextEditingController(text: member?.phone ?? '+230 ');
    final addressController = TextEditingController(text: member?.residentialAddress ?? '');
    final passportController = TextEditingController(text: member?.passportNumber ?? '');
    final jobTitleController = TextEditingController(text: member?.jobTitle ?? '');
    final employerController = TextEditingController(text: member?.employer ?? '');
    final fieldOfStudyController = TextEditingController(text: member?.fieldOfStudy ?? '');
    final institutionController = TextEditingController(text: member?.institution ?? '');

    DateTime birthDate = member?.birthDate ?? DateTime(1998, 1, 1);
    DateTime passportIssueDate = member?.passportIssueDate ?? DateTime(2022, 1, 1);
    DateTime passportExpiryDate = member?.passportExpiryDate ?? DateTime(2028, 1, 1);
    PermitType permitType = member?.permitType ?? PermitType.worker;
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modifier mes informations',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Informations personnelles',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AjraTextField(
                          controller: firstNameController,
                          label: 'Prénom *',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AjraTextField(
                          controller: lastNameController,
                          label: 'Nom *',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AjraDateField(
                    label: 'Date de naissance *',
                    initialDate: birthDate,
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                    onDateSelected: (d) => setModalState(() => birthDate = d),
                  ),
                  const SizedBox(height: 12),
                  AjraTextField(
                    controller: phoneController,
                    label: 'Téléphone (Maurice) *',
                    hint: '+230 5XXX XXXX',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  AjraTextField(
                    controller: addressController,
                    label: 'Adresse de résidence à Maurice *',
                    hint: 'ex: Port-Louis, Rose-Hill, Flic en Flac...',
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Passeport & Séjour à Maurice',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 10),
                  AjraTextField(
                    controller: passportController,
                    label: 'Numéro de passeport *',
                    hint: 'ex: A1234567',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AjraDateField(
                          label: 'Délivrance *',
                          initialDate: passportIssueDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now(),
                          onDateSelected: (d) => setModalState(() => passportIssueDate = d),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AjraDateField(
                          label: 'Expiration *',
                          initialDate: passportExpiryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
                          onDateSelected: (d) => setModalState(() => passportExpiryDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Travailleur')),
                          selected: permitType == PermitType.worker,
                          selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) setModalState(() => permitType = PermitType.worker);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Étudiant')),
                          selected: permitType == PermitType.student,
                          selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) setModalState(() => permitType = PermitType.student);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (permitType == PermitType.worker) ...[
                    AjraTextField(
                      controller: jobTitleController,
                      label: 'Profession / Poste occupé',
                      hint: 'ex: Comptable, Développeur, Hôtellerie...',
                    ),
                    const SizedBox(height: 12),
                    AjraTextField(
                      controller: employerController,
                      label: 'Entreprise / Employeur',
                      hint: 'ex: Société XYZ Ltd',
                    ),
                  ] else ...[
                    AjraTextField(
                      controller: fieldOfStudyController,
                      label: 'Domaine d\'études / Filière',
                      hint: 'ex: Informatique, Gestion, Finance...',
                    ),
                    const SizedBox(height: 12),
                    AjraTextField(
                      controller: institutionController,
                      label: 'Établissement / Université',
                      hint: 'ex: Université de Maurice, Curtin...',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
              onPressed: isSaving
                  ? null
                  : () async {
                      final fName = firstNameController.text.trim();
                      final lName = lastNameController.text.trim();
                      if (fName.isEmpty || lName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner votre prénom et votre nom.')),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      try {
                        final repo = ref.read(membershipRepositoryProvider);
                        if (member != null) {
                          await repo.updateMemberProfile(
                            userId: user.uid,
                            firstName: fName,
                            lastName: lName,
                            birthDate: birthDate,
                            residentialAddress: addressController.text.trim(),
                            phone: phoneController.text.trim(),
                            passportNumber: passportController.text.trim(),
                            passportIssueDate: passportIssueDate,
                            passportExpiryDate: passportExpiryDate,
                            permitType: permitType,
                            jobTitle: jobTitleController.text.trim(),
                            employer: employerController.text.trim(),
                            fieldOfStudy: fieldOfStudyController.text.trim(),
                            institution: institutionController.text.trim(),
                          );
                        } else {
                          final fullName = '$fName $lName'.trim();
                          await FirebaseFirestore.instance
                              .collection(AppConstants.colUsers)
                              .doc(user.uid)
                              .update({
                            'displayName': fullName,
                            'updatedAt': DateTime.now().toIso8601String(),
                          });

                          if (addressController.text.trim().isNotEmpty ||
                              passportController.text.trim().isNotEmpty) {
                            final shortId = const Uuid().v4().substring(0, 6).toUpperCase();
                            final newProfile = MemberProfile(
                              id: user.uid,
                              userId: user.uid,
                              memberNumber: 'AJRA-${DateTime.now().year}-$shortId',
                              lastName: lName,
                              firstName: fName,
                              birthDate: birthDate,
                              residentialAddress: addressController.text.trim(),
                              email: user.email,
                              phone: phoneController.text.trim(),
                              photoUrl: user.photoUrl,
                              appliedAt: DateTime.now(),
                              status: user.isAdmin ? MembershipStatus.active : MembershipStatus.pending,
                              passportNumber: passportController.text.trim(),
                              passportIssueDate: passportIssueDate,
                              passportExpiryDate: passportExpiryDate,
                              permitType: permitType,
                              jobTitle: permitType == PermitType.worker ? jobTitleController.text.trim() : null,
                              employer: permitType == PermitType.worker ? employerController.text.trim() : null,
                              fieldOfStudy: permitType == PermitType.student ? fieldOfStudyController.text.trim() : null,
                              institution: permitType == PermitType.student ? institutionController.text.trim() : null,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            );
                            await repo.submitApplication(newProfile);
                          }
                        }

                        await ref.read(authRepositoryProvider).reloadUser();
                        ref.invalidate(currentMemberProfileProvider);
                        ref.invalidate(allMembersProvider);

                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.danger,
                              content: Text('Erreur lors de la mise à jour : $e'),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Vos informations de profil ont été mises à jour avec succès !'),
        ),
      );
    }
  }

  Future<void> _openPasswordModal(AppUser user, bool alreadyConfigured) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;
    String? modalError;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_person_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadyConfigured
                      ? 'Modifier mon mot de passe'
                      : 'Créer mon mot de passe',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identifiant de connexion (Compte Google officiel) :',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.alternate_email_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalError!,
                              style: const TextStyle(fontSize: 12, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (alreadyConfigured) ...[
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel (facultatif si connecté avec Google)',
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 19,
                          ),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe *',
                      hintText: 'Au moins 6 caractères',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe *',
                      hintText: 'Répétez le mot de passe',
                      prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Une fois enregistré, vous pourrez vous connecter sur l\'application AJRA soit avec Google, soit avec votre adresse e-mail et ce mot de passe.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(alreadyConfigured ? 'Mettre à jour' : 'Créer le mot de passe'),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPass = newPasswordController.text;
                      final confirmPass = confirmPasswordController.text;

                      if (newPass.length < 6) {
                        setModalState(() {
                          modalError = 'Le mot de passe doit contenir au moins 6 caractères.';
                        });
                        return;
                      }
                      if (newPass != confirmPass) {
                        setModalState(() {
                          modalError = 'La confirmation ne correspond pas au nouveau mot de passe.';
                        });
                        return;
                      }

                      setModalState(() {
                        isSaving = true;
                        modalError = null;
                      });

                      try {
                        await ref.read(authRepositoryProvider).createOrUpdatePassword(
                              newPassword: newPass,
                              currentPassword: currentPasswordController.text.isNotEmpty
                                  ? currentPasswordController.text
                                  : null,
                            );
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                        }
                      } catch (e) {
                        setModalState(() {
                          isSaving = false;
                          modalError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            alreadyConfigured
                ? 'Votre mot de passe de connexion a été modifié avec succès !'
                : 'Votre mot de passe a été créé ! Vous pouvez désormais vous connecter avec votre e-mail et mot de passe.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre compte AJRA ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suppression du compte (RGPD)'),
        content: const Text(
          'Attention : Conformément au RGPD et à la protection des données, vos identifiants d\'accès seront supprimés et votre compte sera désactivé. Vos opérations comptables historiques resteront archivées anonymement pour la conformité légale de l\'association. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer la suppression'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount();
        if (mounted) context.go('/login');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final member = ref.watch(currentMemberProfileProvider).value;
    final role = user?.role ?? UserRole.member;

    return Scaffold(
      appBar: AppBar(
        leading: const AjraBackButton(fallbackRoute: '/dashboard'),
        title: const Text('Mon Profil & Paramètres'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Modifier mes informations',
              onPressed: () => _openEditProfileModal(user, member),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            tooltip: 'Déconnexion',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Digital Official Member ID Card + Edit Button
              if (user != null) ...[
                AjraDigitalMemberCard(
                  user: user,
                  member: member,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Modifier mes informations personnelles'),
                    onPressed: () => _openEditProfileModal(user, member),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Security & Password Card (Connexion par identifiant & mot de passe)
              if (user != null) ...[
                Builder(
                  builder: (context) {
                    final hasPasswordConfigured =
                        user.hasPassword || ref.read(authRepositoryProvider).isPasswordProviderLinked;
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.lock_person_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Sécurité & Mot de passe',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              StatusBadge(
                                label: hasPasswordConfigured
                                    ? 'Mot de passe actif'
                                    : 'Google uniquement',
                                backgroundColor: hasPasswordConfigured
                                    ? AppColors.successLight
                                    : AppColors.warningLight,
                                textColor: hasPasswordConfigured
                                    ? AppColors.success
                                    : const Color(0xFFB45309),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildInfoRow('Identifiant (Login)', user.email),
                          _buildInfoRow(
                            'Modes de connexion',
                            hasPasswordConfigured
                                ? 'Google + Identifiant & Mot de passe'
                                : 'Compte Google uniquement',
                          ),
                          if (user.passwordUpdatedAt != null)
                            _buildInfoRow(
                              'Dernière mise à jour',
                              DateFormat('dd/MM/yyyy à HH:mm').format(user.passwordUpdatedAt!),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            hasPasswordConfigured
                                ? 'Votre mot de passe est configuré. Vous pouvez vous connecter sur l\'écran d\'accueil avec votre adresse e-mail (${user.email}) et votre mot de passe.'
                                : 'Créez un mot de passe personnel pour pouvoir vous connecter avec votre identifiant (${user.email}) et mot de passe en plus de Google.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasPasswordConfigured
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                hasPasswordConfigured
                                    ? Icons.password_rounded
                                    : Icons.add_moderator_outlined,
                                size: 18,
                              ),
                              label: Text(
                                hasPasswordConfigured
                                    ? 'Modifier mon mot de passe'
                                    : 'Créer mon mot de passe de connexion',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              onPressed: () => _openPasswordModal(user, hasPasswordConfigured),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Membership Card
              if (member != null) ...[
                Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dossier d\'adhésion & Informations',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          if (user != null)
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Modifier', style: TextStyle(fontSize: 12.5)),
                              onPressed: () => _openEditProfileModal(user, member),
                            ),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildInfoRow('Matricule AJRA', member.memberNumber),
                      _buildInfoRow('Nom complet', member.fullName),
                      _buildInfoRow('Date de naissance', DateFormat('dd/MM/yyyy').format(member.birthDate)),
                      _buildInfoRow('Téléphone', member.phone),
                      _buildInfoRow('Adresse à Maurice', member.residentialAddress),
                      _buildInfoRow('Statut de séjour', member.permitType.label),
                      if (member.permitType == PermitType.worker) ...[
                        if (member.jobTitle != null && member.jobTitle!.isNotEmpty)
                          _buildInfoRow('Profession', member.jobTitle!),
                        if (member.employer != null && member.employer!.isNotEmpty)
                          _buildInfoRow('Employeur', member.employer!),
                      ] else ...[
                        if (member.fieldOfStudy != null && member.fieldOfStudy!.isNotEmpty)
                          _buildInfoRow('Domaine d\'études', member.fieldOfStudy!),
                        if (member.institution != null && member.institution!.isNotEmpty)
                          _buildInfoRow('Établissement', member.institution!),
                      ],
                      _buildInfoRow('Numéro de passeport', member.passportNumber),
                      _buildInfoRow('Expiration passeport', DateFormat('dd/MM/yyyy').format(member.passportExpiryDate)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/membership-status'),
                        child: const Text('Voir l\'état détaillé de ma demande'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Role & Permissions info
              if (role.isBureau || role.isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permissions attribuées',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      if (role.isAdmin)
                        const Text(
                          'En tant qu\'Administrateur, vous disposez de l\'accès complet à tous les modules, approbations financières et configurations.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                        )
                      else ...[
                        if (user != null && user.permissions.isNotEmpty)
                          ...user.permissions.map((p) {
                            final label = AppPermissions.labels[p] ?? p;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16, color: AppColors.secondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(label, style: const TextStyle(fontSize: 12.5))),
                                ],
                              ),
                            );
                          })
                        else
                          const Text(
                            'Aucune permission financière ou d\'examen spécifique ne vous a encore été attribuée par l\'administrateur.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Danger Zone: Account Deletion
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.dangerLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestion des données personnelles',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vous pouvez demander la désactivation de votre compte et la purge de vos données d\'accès conformément à la politique de confidentialité de l\'AJRA.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 14),
                    AjraButton(
                      label: 'Supprimer mon compte',
                      icon: Icons.delete_forever_outlined,
                      variant: AjraButtonVariant.danger,
                      height: 40,
                      onPressed: _handleDeleteAccount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // About, Statuts & App Update Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Statuts de l\'AJRA, RPD & Mises à jour',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Consultez les 15 statuts officiels fondateurs de l\'association, le règlement intérieur et vérifiez la disponibilité d\'une mise à jour (MAJ).',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.menu_book_outlined, size: 18),
                            label: const Text('Voir les Statuts & RPD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => context.go('/about'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.system_update_rounded, size: 18),
                          label: const Text('Vérifier MAJ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => AppUpdateService.checkAndPromptUpdate(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF047857),
                          side: const BorderSide(color: Color(0xFF047857)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.android_rounded, size: 18),
                        label: const Text(
                          'Télécharger l\'APK Android (app.apk)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        onPressed: () => AppUpdateService.launchApkDownload(AppConstants.apkDownloadUrl),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Association Brand & About Card
              Center(
                child: InkWell(
                  onTap: () => context.go('/about'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              AppConstants.logoAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.groups,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          AppConstants.appFullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Île Maurice • Région Anosy (Madagascar)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'v1.4.9 (Release Production)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
