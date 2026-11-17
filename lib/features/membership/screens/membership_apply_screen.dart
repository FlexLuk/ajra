import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/member_profile.dart';
import '../providers/membership_provider.dart';

class MembershipApplyScreen extends ConsumerStatefulWidget {
  const MembershipApplyScreen({super.key});

  @override
  ConsumerState<MembershipApplyScreen> createState() => _MembershipApplyScreenState();
}

class _MembershipApplyScreenState extends ConsumerState<MembershipApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _lastNameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passportNumberController;

  // Spécifique travailleur
  late final TextEditingController _jobTitleController;
  late final TextEditingController _employerController;

  // Spécifique étudiant
  late final TextEditingController _fieldOfStudyController;
  late final TextEditingController _institutionController;

  DateTime? _birthDate;
  DateTime? _passportIssueDate;
  DateTime? _passportExpiryDate;
  PermitType _permitType = PermitType.worker;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);

    String initialFirstName = '';
    String initialLastName = '';
    if (user != null && user.displayName.isNotEmpty) {
      final parts = user.displayName.split(' ');
      if (parts.isNotEmpty) initialFirstName = parts.first;
      if (parts.length > 1) initialLastName = parts.sublist(1).join(' ');
    }

    _lastNameController = TextEditingController(text: initialLastName);
    _firstNameController = TextEditingController(text: initialFirstName);
    _addressController = TextEditingController();
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: '+230 ');
    _passportNumberController = TextEditingController();

    _jobTitleController = TextEditingController();
    _employerController = TextEditingController();
    _fieldOfStudyController = TextEditingController();
    _institutionController = TextEditingController();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passportNumberController.dispose();
    _jobTitleController.dispose();
    _employerController.dispose();
    _fieldOfStudyController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner votre date de naissance')),
      );
      return;
    }
    if (_passportIssueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la date de délivrance du passeport')),
      );
      return;
    }
    if (_passportExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la date d\'expiration du passeport')),
      );
      return;
    }
    if (_passportExpiryDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre passeport ne peut pas être déjà expiré.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Utilisateur non connecté');

      final shortId = const Uuid().v4().substring(0, 6).toUpperCase();
      final year = DateTime.now().year;
      final memberNumber = 'AJRA-$year-$shortId';

      final profile = MemberProfile(
        id: user.uid,
        userId: user.uid,
        memberNumber: memberNumber,
        lastName: _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        birthDate: _birthDate!,
        residentialAddress: _addressController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: user.photoUrl,
        appliedAt: DateTime.now(),
        status: MembershipStatus.pending,
        passportNumber: _passportNumberController.text.trim(),
        passportIssueDate: _passportIssueDate!,
        passportExpiryDate: _passportExpiryDate!,
        permitType: _permitType,
        jobTitle: _permitType == PermitType.worker ? _jobTitleController.text.trim() : null,
        employer: _permitType == PermitType.worker ? _employerController.text.trim() : null,
        fieldOfStudy: _permitType == PermitType.student ? _fieldOfStudyController.text.trim() : null,
        institution: _permitType == PermitType.student ? _institutionController.text.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(membershipRepositoryProvider).submitApplication(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Votre demande d\'adhésion a été soumise avec succès !'),
          ),
        );
        context.go('/membership-status');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la soumission : ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Demande d\'adhésion AJRA'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complétez votre dossier d\'adhésion. Les informations administratives (passeport) sont strictement confidentielles et réservées aux responsables habilités.',
                          style: TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Section 1: Informations Personnelles
                const Text(
                  '1. Informations Personnelles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: AjraTextField(
                        controller: _firstNameController,
                        label: 'Prénom *',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AjraTextField(
                        controller: _lastNameController,
                        label: 'Nom *',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                AjraDateField(
                  label: 'Date de naissance *',
                  initialDate: _birthDate,
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                  onDateSelected: (date) => setState(() => _birthDate = date),
                ),
                const SizedBox(height: 14),

                AjraTextField(
                  controller: _addressController,
                  label: 'Adresse de résidence à l\'Île Maurice *',
                  hint: 'ex: Flic en Flac, Rivière Noire...',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AjraTextField(
                            controller: _emailController,
                            label: 'Adresse e-mail (liée au compte) *',
                            hint: 'Compte Google connecté',
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || !v.contains('@') ? 'E-mail invalide' : null,
                          ),
                          const SizedBox(height: 14),
                          AjraTextField(
                            controller: _phoneController,
                            label: 'Téléphone (avec indicatif) *',
                            hint: '+230 5XXX XXXX',
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AjraTextField(
                            controller: _emailController,
                            label: 'Adresse e-mail (liée au compte) *',
                            hint: 'Compte Google connecté',
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || !v.contains('@') ? 'E-mail invalide' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AjraTextField(
                            controller: _phoneController,
                            label: 'Téléphone (avec indicatif) *',
                            hint: '+230 5XXX XXXX',
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Section 2: Informations Administratives
                const Text(
                  '2. Informations Administratives & Passeport',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                AjraTextField(
                  controller: _passportNumberController,
                  label: 'Numéro de passeport *',
                  hint: 'ex: A1234567',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: AjraDateField(
                        label: 'Date de délivrance *',
                        initialDate: _passportIssueDate,
                        firstDate: DateTime(2010),
                        lastDate: DateTime.now(),
                        onDateSelected: (d) => setState(() => _passportIssueDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AjraDateField(
                        label: 'Date d\'expiration *',
                        initialDate: _passportExpiryDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 12)),
                        onDateSelected: (d) => setState(() => _passportExpiryDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Section 3: Statut à Maurice
                const Text(
                  '3. Statut & Permis de séjour à Maurice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Choice chips for permit type
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Travailleur', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        selected: _permitType == PermitType.worker,
                        selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) setState(() => _permitType = PermitType.worker);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Étudiant', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        selected: _permitType == PermitType.student,
                        selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) setState(() => _permitType = PermitType.student);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Conditional fields
                if (_permitType == PermitType.worker) ...[
                  AjraTextField(
                    controller: _jobTitleController,
                    label: 'Profession ou Emploi occupé *',
                    hint: 'ex: Développeur, Hôtellerie, Comptable...',
                    validator: (v) {
                      if (_permitType == PermitType.worker && (v == null || v.trim().isEmpty)) {
                        return 'Veuillez renseigner votre profession';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AjraTextField(
                    controller: _employerController,
                    label: 'Entreprise ou Employeur (facultatif)',
                    hint: 'ex: Société XYZ Ltd',
                  ),
                ] else ...[
                  AjraTextField(
                    controller: _fieldOfStudyController,
                    label: 'Domaine d\'études *',
                    hint: 'ex: Informatique, Gestion, Hôtellerie...',
                    validator: (v) {
                      if (_permitType == PermitType.student && (v == null || v.trim().isEmpty)) {
                        return 'Veuillez renseigner votre filière';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AjraTextField(
                    controller: _institutionController,
                    label: 'Établissement ou Université (facultatif)',
                    hint: 'ex: Université des Mascareignes, Curtin Mauritius...',
                  ),
                ],

                const SizedBox(height: 36),

                AjraButton(
                  label: 'Soumettre ma demande d\'adhésion',
                  icon: Icons.send_rounded,
                  isLoading: _isLoading,
                  onPressed: _submitForm,
                  variant: AjraButtonVariant.primary,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
