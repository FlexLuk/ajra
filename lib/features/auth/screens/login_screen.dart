import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoadingGoogle = false;
  bool _isLoadingPassword = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isAnyLoading => _isLoadingGoogle || _isLoadingPassword;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkOnAppStart(context);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanError(Object e) {
    return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithGoogle();

      if (user != null && mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la connexion Google : ${_cleanError(e)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  Future<void> _handlePasswordSignIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoadingPassword = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _cleanError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPassword = false;
        });
      }
    }
  }

  Future<void> _openPasswordHelpOrResetModal() async {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mot de passe & Accès AJRA',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Comment obtenir un mot de passe ?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Aucune inscription directe n\'est ouverte : vous devez d\'abord vous connecter une première fois avec votre compte Google.\n'
                          '2. Rendez-vous ensuite dans « Mon Profil » > « Sécurité & Mot de passe » pour créer votre mot de passe personnel.\n'
                          '3. Vous pourrez alors vous connecter au choix avec Google ou avec votre e-mail et mot de passe.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimaryLight,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Réinitialiser un mot de passe existant par e-mail :',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Votre adresse e-mail Google',
                      hintText: 'exemple@gmail.com',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 17),
                    label: const Text('Envoyer un lien de réinitialisation'),
                    onPressed: isSending
                        ? null
                        : () async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.danger,
                                  content: Text('Veuillez saisir une adresse e-mail valide.'),
                                ),
                              );
                              return;
                            }
                            setModalState(() => isSending = true);
                            try {
                              await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.success,
                                    content: Text('E-mail de réinitialisation envoyé à $email.'),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSending = false);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.danger,
                                    content: Text(_cleanError(e)),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDemoBypass([UserRole role = UserRole.admin]) async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInAsDemoUser(role: role);

      if (user != null && mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du mode test : ${_cleanError(e)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC), Color(0xFFEEF2F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Card with Halo
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            AppConstants.logoAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.groups_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '${AppConstants.appFullName} • Île Maurice',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main Authentication Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.9)),
                        boxShadow: AppColors.elevatedCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Espace Membre Officiel',
                                  style: TextStyle(
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Connectez-vous avec votre compte Google (création initiale obligatoire) ou avec votre identifiant et mot de passe défini dans votre profil.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondaryLight,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 1. Google Sign-in Button (Official Account Creation & Sign-In)
                          AjraButton(
                            label: 'Se connecter avec Google',
                            icon: Icons.g_mobiledata_rounded,
                            isLoading: _isLoadingGoogle,
                            onPressed: _isAnyLoading ? null : _handleGoogleSignIn,
                            variant: AjraButtonVariant.primary,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Première connexion ? Utilisez impérativement « Se connecter avec Google » pour créer votre compte sur le serveur.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),

                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.borderLight)),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'OU PAR IDENTIFIANT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: AppColors.textSecondaryLight.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: AppColors.borderLight)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. Login & Password Form (Only for accounts created via Google that set a password in Profile)
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  enabled: !_isAnyLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Identifiant (E-mail Google)',
                                    hintText: 'votre.nom@gmail.com',
                                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    final v = val?.trim() ?? '';
                                    if (v.isEmpty) {
                                      return 'Veuillez saisir votre identifiant (adresse e-mail)';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Veuillez saisir une adresse e-mail valide';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !_isAnyLoading,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handlePasswordSignIn(),
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    hintText: 'Votre mot de passe AJRA',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                    isDense: true,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'Afficher le mot de passe'
                                          : 'Masquer le mot de passe',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Veuillez saisir votre mot de passe';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                AjraButton(
                                  label: 'Se connecter avec identifiant',
                                  icon: Icons.login_rounded,
                                  isLoading: _isLoadingPassword,
                                  onPressed: _isAnyLoading ? null : _handlePasswordSignIn,
                                  variant: AjraButtonVariant.secondary,
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _openPasswordHelpOrResetModal,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.help_outline_rounded, size: 15),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Mot de passe non créé ou oublié ?',
                                            softWrap: true,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Section Déblocage Mode Test / Dev (Actif uniquement en mode Debug)
                          if (kDebugMode) ...[
                            const Divider(color: AppColors.borderLight),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.developer_mode_rounded,
                                          size: 16, color: Color(0xFF15803D)),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Mode Test / Développement :',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  AjraButton(
                                    label: 'Passer la connexion (Admin)',
                                    icon: Icons.arrow_forward_rounded,
                                    isLoading: _isAnyLoading,
                                    onPressed: () => _handleDemoBypass(UserRole.admin),
                                    variant: AjraButtonVariant.secondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isAnyLoading
                                              ? null
                                              : () => _handleDemoBypass(UserRole.bureau),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            side: const BorderSide(color: Color(0xFF86EFAC)),
                                            foregroundColor: const Color(0xFF15803D),
                                          ),
                                          child: const Text('Test : Bureau',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isAnyLoading
                                              ? null
                                              : () => _handleDemoBypass(UserRole.member),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            side: const BorderSide(color: Color(0xFF86EFAC)),
                                            foregroundColor: const Color(0xFF15803D),
                                          ),
                                          child: const Text('Test : Membre',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Important Rule Alert
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sécurité AJRA : Aucune inscription libre n\'est autorisée. Seule la création de compte sur le serveur via Google est acceptée. Vous pouvez ensuite définir un mot de passe dans Mon Profil.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF1E3A8A),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Quick Action Bar: Check Update (MAJ) + Download APK (on Web)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: AppColors.borderLight),
                            backgroundColor: Colors.white.withValues(alpha: 0.85),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.system_update_rounded, size: 16, color: AppColors.primary),
                          label: const Text(
                            'Vérifier MAJ (v${AppConstants.appVersion})',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => AppUpdateService.checkAndPromptUpdate(context),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: AppColors.borderLight),
                            backgroundColor: Colors.white.withValues(alpha: 0.85),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.android_rounded, size: 16, color: Color(0xFF047857)),
                          label: const Text(
                            'APK Android',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                          onPressed: () => AppUpdateService.launchApkDownload(AppConstants.apkDownloadUrl),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      'Association des Jeunes de la Région Anosy à l\'Île Maurice\nDevise officielle : Rs. (MUR)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
