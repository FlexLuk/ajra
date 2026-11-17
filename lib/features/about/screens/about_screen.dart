import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String apkDownloadUrl = AppConstants.apkDownloadUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadApk() async {
    final uri = Uri.parse(apkDownloadUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Téléchargement direct : https://ajra-app-8ae42.web.app/app.apk')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien APK : https://ajra-app-8ae42.web.app/app.apk')),
        );
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
        title: const Text('À propos & Statuts AJRA'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.gavel_rounded, size: 20), text: 'Statuts Officiels'),
            Tab(icon: Icon(Icons.security_outlined, size: 20), text: 'RPD & Règlement'),
            Tab(icon: Icon(Icons.info_outline, size: 20), text: 'Application (1.4.9)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatutsTab(),
          _buildRpdTab(),
          _buildAppInfoTab(),
        ],
      ),
    );
  }

  Widget _buildStatutsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tête officiel
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUTS OFFICIELS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Jeunes de la Région Anosy à Maurice',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              const Text(
                'Association régie par la loi mauricienne du 3 janvier 1979 et le décret 33 de 1978.',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Siège social : Port-Louis, Île Maurice • Fait le 13 février 2026',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Articles 1 à 15
        _buildArticleCard(
          articleNumber: 'Article 1',
          title: 'Titre & Fondation',
          content: 'Il est fondé entre les adhérents aux présents statuts une association régie par la loi mauricienne du 3 janvier 1979 et le décret 33 de 1978, ayant pour titre : Jeunes de la région Anosy à Maurice.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 2',
          title: 'But & Objet social',
          content: 'Cette association a pour but de promouvoir l’entraide sociale, la solidarité malgache et l’assistance morale et matérielle entre les personnes originaires du sud de Madagascar et toute autre personne partageant les valeurs de solidarité, de fraternité et de cohésion sociale.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 3',
          title: 'Siège social',
          content: 'Le siège social est fixé à Port Louis.\nIl pourra être transféré par simple décision du conseil d’administration ; la ratification par l’assemblée générale sera nécessaire.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 4',
          title: 'Composition de l’association',
          content: 'L’association se compose de :\na) Membres actifs ou adhérents\nb) Membres de bureau\nc) Membres d’honneur',
        ),
        _buildArticleCard(
          articleNumber: 'Article 5',
          title: 'Admission',
          content: 'Pour faire partie de l’association, il faut être agréé par le bureau qui statue, lors de chacune de ses réunions, sur les demandes d’admission présentées.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 6',
          title: 'Les membres - Cotisations',
          content: 'Sont membres actifs ceux qui ont pris l’engagement de verser mensuellement une cotisation fixée chaque année par l’assemblée générale.\n\nMembres de bureau sont les membres actifs élus par l’assemblée générale, chargés de la direction, de l’administration et de la gestion de l’association. Ils exercent leurs fonctions dans le respect des présents statuts et des décisions de l’assemblée générale.\n\nSont membres d’honneur ceux qui ont rendu des services signalés à l’association ; ils sont dispensés de cotisation.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 7',
          title: 'Radiations',
          content: 'La qualité de membre se perd par :\na) La démission ;\nb) Le décès ;\nc) La radiation prononcée pour non-paiement de la cotisation ou pour motif grave, l\'intéressé ayant été invité à fournir des explications devant le bureau et/ou par écrit.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 8',
          title: 'Ressources de l’association',
          content: 'Les ressources de l\'association comprennent :\n1° Le montant des droits d\'entrée et des cotisations ;\n2° Toutes les ressources autorisées par les lois et règlements en vigueur.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 9',
          title: 'Assemblée générale ordinaire',
          content: 'L\'assemblée générale ordinaire comprend tous les membres de l\'association.\nQuinze jours au moins avant la date fixée, les membres de l\'association sont convoqués par les soins du secrétaire. L\'ordre du jour figure sur les convocations.\n\nLe président, assisté des membres du bureau, préside l\'assemblée et expose la situation morale ou l’activité de l\'association.\n\nLe trésorier rend compte de sa gestion et soumet les comptes annuels (bilan, compte de résultat et annexe) à l\'approbation de l\'assemblée.\n\nNe peuvent être abordés que les points inscrits à l\'ordre du jour.\nLes décisions sont prises à la majorité des voix des membres présents ou représentés.\nIl est procédé, après épuisement de l\'ordre du jour, au renouvellement des membres sortants du bureau exécutif.\nLes décisions des assemblées générales s’imposent à tous les membres, y compris absents ou représentés.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 10',
          title: 'Assemblée générale extraordinaire',
          content: 'Si besoin est, ou sur la demande de la moitié plus un des membres inscrits, le président peut convoquer une assemblée générale extraordinaire, suivant les modalités prévues aux présents statuts et uniquement pour modification des statuts ou la dissolution ou pour des actes portant sur des immeubles.\n\nLes modalités de convocation sont les mêmes que pour l’assemblée générale ordinaire.\nLes délibérations sont prises à la majorité des membres présents.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 11',
          title: 'Le Bureau Exécutif',
          content: 'L’association est administrée par un bureau exécutif, élu au scrutin secret par l’assemblée générale. Les membres sont rééligibles.\n\nLe conseil choisit parmi ses membres, au scrutin secret, un bureau composé d’au moins 3 personnes :\n- Le président\n- Le vice-président\n- Conseiller\n\nLe bureau est élu pour 2 ans. Le renouvellement du bureau a lieu (intégralement, par moitié, par tiers).\n\nEn cas de vacances, l’assemblée générale pourvoit provisoirement au remplacement de ses membres. Il est procédé à leur remplacement définitif à la prochaine assemblée générale. Les pouvoirs des membres ainsi élus prennent fin à l’époque où devrait normalement expirer le mandat des membres remplacés.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 12',
          title: 'Réunions - Procès-Verbaux',
          content: 'Les membres de l’association se réunissent une fois au moins tout le mois, et chaque fois qu’une assemblée est convoquée par son président, ou sur la demande du quart de ses membres.\n\nLes décisions sont prises à la majorité des voix. En cas de partage, la voix du président est prépondérante.\n\nIl est tenu un procès-verbal des séances. Les procès-verbaux sont signés par le président et le secrétaire. Ils sont transcrits sans blanc, ni rature sur un registre spécial.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 13',
          title: 'Bénévolat & Indemnités',
          content: 'Toutes les fonctions, y compris celles des membres et du bureau, sont gratuites et bénévoles. Seuls les frais occasionnés par l’accomplissement de leur mandat sont remboursés sur justificatifs.\n\nLe rapport financier présenté à l’assemblée générale ordinaire présente, par bénéficiaire, les remboursements de frais de mission, de déplacement ou de représentation.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 14',
          title: 'Règlement Intérieur',
          content: 'Un règlement intérieur peut être établi, et approuvé par l\'assemblée générale. Ce règlement éventuel est destiné à fixer les divers points non prévus par les présents statuts, notamment ceux qui ont trait à l\'administration interne de l\'association.',
        ),
        _buildArticleCard(
          articleNumber: 'Article 15',
          title: 'Dissolution',
          content: 'En cas de dissolution prononcée selon les modalités prévues à l’article 11, un ou plusieurs liquidateurs sont nommés, et l\'actif, s\'il y a lieu, est dévolu conformément aux décisions de l’assemblée générale extraordinaire qui statue sur la dissolution.\n\nFait à Port-Louis, Le 13 février 2026',
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildRpdTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'RÈGLEMENT & PROTECTION DES DONNÉES (RPD)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'L\'association AJRA s\'engage fermement à respecter la vie privée de tous ses membres, la sécurité de leurs données et la transparence totale de ses opérations.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: '1. Principes de Solidarité & de Convivialité',
          icon: Icons.handshake_outlined,
          content: 'L\'association AJRA est fondée sur le Fihavanana, la solidarité malgache et l\'entraide mutuelle. Chaque membre s\'engage au respect mutuel, à la discrétion et à la bienveillance dans toutes les activités de la communauté à l\'île Maurice.',
        ),
        _buildSectionCard(
          title: '2. Données Personnelles Collectées',
          icon: Icons.badge_outlined,
          content: 'Seules les informations indispensables à l\'administration de l\'association sont collectées : nom, prénom, contact, adresse, données de passeport (pour l\'assistance consulaire et les alertes d\'expiration) et justificatifs de cotisation.\nAucune donnée n\'est cédée, vendue ou transmise à un tiers commercial.',
        ),
        _buildSectionCard(
          title: '3. Transparence Financière & Traçabilité Inviolable',
          icon: Icons.account_balance_wallet_outlined,
          content: 'Toutes les cotisations, prêts solidaires et dépenses font l\'objet d\'écritures comptables traçables et d\'un journal d\'audit infalsifiable (Audit Log). Chaque membre actif peut consulter les bilans et rapports financiers approuvés par le bureau.',
        ),
        _buildSectionCard(
          title: '4. Vos Droits & Sécurité Numérique',
          icon: Icons.lock_outline,
          content: 'Conformément au Data Protection Act et aux principes RGPD, chaque membre dispose d\'un droit direct de consultation, de rectification et de demande de suppression de son compte depuis l\'onglet Profil de l\'application.',
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildAppInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'identité de l'application
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
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
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const Text(
                'Jeunes de la Région Anosy • Maurice',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Version 1.4.9 (Release Production)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Carte Mise à jour Automatique (MAJ) & Téléchargement APK Android
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: Color(0xFF047857), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mises à jour & APK Officiel (Production)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'L\'application vérifie automatiquement à chaque ouverture la présence d\'une nouvelle version sur Google Play Store ou d\'un nouveau fichier APK officiel (comparaison d\'empreinte MD5 sur https://ajra-app-8ae42.web.app/app.apk).',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (!kIsWeb) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: const Text(
                      'Vérifier les mises à jour (MD5 & Play Store)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () => AppUpdateService.checkAndPromptUpdate(context),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Télécharger l\'APK officiel (app.apk)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: _downloadApk,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.shop_two_outlined, size: 19),
                  label: const Text(
                    'Ouvrir sur Google Play Store',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => AppUpdateService.launchPlayStore(AppConstants.playStoreUrl),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Fonctionnalités clés
        const Text(
          'Fonctionnalités intégrées',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(Icons.payments_outlined, 'Cotisations mensuelles', 'Déclaration en ligne, suivi des versements et régularisation directe.'),
        _buildFeatureItem(Icons.handshake_outlined, 'Prêts solidaires & Emprunts', 'Demande d\'aide solidaire, suivi des échéances et remboursements contrôlés.'),
        _buildFeatureItem(Icons.account_balance_outlined, 'Trésorerie multi-comptes', 'Gestion synchronisée Caisse Espèces, Compte Bancaire Principal et MCB Juice.'),
        _buildFeatureItem(Icons.calendar_month_outlined, 'Événements & Sorties', 'Annonces, confirmations de participation et partages communautaires.'),
        _buildFeatureItem(Icons.notifications_active_outlined, 'Notifications & Sonnerie', 'Alertes instantanées avec vibreur et sonnerie lors d\'annonces importantes.'),
        _buildFeatureItem(Icons.chat_bubble_outline, 'Messagerie privée', 'Discussions directes et échanges entre membres vérifiés.'),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildArticleCard({
    required String articleNumber,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  articleNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
