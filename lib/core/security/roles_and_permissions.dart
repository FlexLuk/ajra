/// Rôles officiels du système AJRA
enum UserRole {
  admin('ADMIN', 'Administrateur'),
  bureau('MEMBRE_BUREAU', 'Membre du Bureau'),
  member('MEMBRE', 'Membre');

  final String code;
  final String label;

  const UserRole(this.code, this.label);

  static UserRole fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'MEMBRE_BUREAU':
        return UserRole.bureau;
      case 'MEMBRE':
      default:
        return UserRole.member;
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isBureau => this == UserRole.bureau;
  bool get isMember => this == UserRole.member;
}

/// Permissions explicites et granulaires attribuables aux membres du bureau
class AppPermissions {
  // Adhésions
  static const String membershipReview = 'membership.review';
  static const String membershipManage = 'membership.manage';

  // Cotisations & Droits
  static const String duesRecord = 'dues.record';
  static const String duesManage = 'dues.manage';

  // Finances & Paiements
  static const String paymentVerify = 'payment.verify';
  static const String financeTransactionCreate = 'finance.transaction.create';
  static const String financeTransactionApprove = 'finance.transaction.approve';
  static const String financeReportView = 'finance.report.view';

  // Événements & Collectes
  static const String eventManage = 'event.manage';
  static const String fundraisingManage = 'fundraising.manage';

  // Actualités & Notifications
  static const String postPublish = 'post.publish';

  // Administration & Audit
  static const String usersManage = 'users.manage';
  static const String auditView = 'audit.view';

  /// Liste exhaustive de toutes les permissions système
  static const List<String> allPermissions = [
    membershipReview,
    membershipManage,
    duesRecord,
    duesManage,
    paymentVerify,
    financeTransactionCreate,
    financeTransactionApprove,
    financeReportView,
    eventManage,
    fundraisingManage,
    postPublish,
    usersManage,
    auditView,
  ];

  /// Libellés en français pour l'interface de gestion des permissions
  static const Map<String, String> labels = {
    membershipReview: 'Examiner et valider/rejeter les adhésions',
    membershipManage: 'Gérer et modifier les dossiers des membres',
    duesRecord: 'Enregistrer des paiements de cotisations hors-application',
    duesManage: 'Configurer les échéances et barèmes de cotisations',
    paymentVerify: 'Vérifier et confirmer la réception réelle des fonds',
    financeTransactionCreate: 'Saisir des recettes et des dépenses',
    financeTransactionApprove: 'Valider définitivement les opérations financières',
    financeReportView: 'Consulter les rapports financiers et de trésorerie',
    eventManage: 'Créer et administrer les événements',
    fundraisingManage: 'Gérer les collectes de fonds et vérifier les dons',
    postPublish: 'Publier des annonces et actualités officielles',
    usersManage: 'Gérer les utilisateurs et les rôles',
    auditView: 'Consulter le journal d\'audit complet',
  };
}

/// Statuts du cycle de vie d'une adhésion
enum MembershipStatus {
  pending('En attente'),
  active('Active'),
  rejected('Rejetée'),
  suspended('Suspendue'),
  terminated('Terminée');

  final String label;
  const MembershipStatus(this.label);

  static MembershipStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'active':
        return MembershipStatus.active;
      case 'rejected':
        return MembershipStatus.rejected;
      case 'suspended':
        return MembershipStatus.suspended;
      case 'terminated':
        return MembershipStatus.terminated;
      case 'pending':
      default:
        return MembershipStatus.pending;
    }
  }

  bool get isPending => this == MembershipStatus.pending;
  bool get isActive => this == MembershipStatus.active;
  bool get isRejected => this == MembershipStatus.rejected;
  bool get isSuspended => this == MembershipStatus.suspended;
  bool get isTerminated => this == MembershipStatus.terminated;
}

/// Types de permis de séjour / statut à Maurice
enum PermitType {
  worker('Travailleur'),
  student('Étudiant');

  final String label;
  const PermitType(this.label);

  static PermitType fromString(String? val) {
    if (val?.toLowerCase() == 'student' || val?.toLowerCase() == 'étudiant') {
      return PermitType.student;
    }
    return PermitType.worker;
  }
}
