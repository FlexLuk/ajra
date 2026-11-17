class AppConstants {
  static const String appName = 'AJRA';
  static const String appFullName = 'Association des Jeunes de la Région Anosy';
  static const String currencyCode = 'MUR';
  static const String currencySymbol = 'Rs.';
  static const String defaultLocale = 'fr_FR';
  static const String logoAsset = 'assets/images/logo.png';
  static const String appVersion = '1.5.1';
  static const int appBuildNumber = 6;
  static const String androidPackageId = 'com.ajra.ajra';
  static const String apkDownloadUrl = 'https://ajra-app-8ae42.web.app/app.apk';
  static const String apkFallbackDownloadUrl = 'https://ajra-app-8ae42.web.app/ajra.apk';
  static const String apkMd5Url = 'https://ajra-app-8ae42.web.app/app.apk.md5';
  static const String versionManifestUrl = 'https://ajra-app-8ae42.web.app/version.json';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.ajra.ajra';
  static const String playStoreMarketUrl = 'market://details?id=com.ajra.ajra';

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colMembers = 'members';
  static const String colMembershipPayments = 'membershipPayments';
  static const String colMembershipFeeConfigs = 'membershipFeeConfigs';
  static const String colDues = 'dues';
  static const String colContributionPayments = 'contributionPayments';
  static const String colFinancialAccounts = 'financialAccounts';
  static const String colFinancialTransactions = 'financialTransactions';
  static const String colFinancialCategories = 'financialCategories';
  static const String colEvents = 'events';
  static const String colEventParticipants = 'eventParticipants';
  static const String colEventTransactions = 'eventTransactions';
  static const String colFundraisingCampaigns = 'fundraisingCampaigns';
  static const String colFundraisingContributions = 'fundraisingContributions';
  static const String colPosts = 'posts';
  static const String colNotifications = 'notifications';
  static const String colConversations = 'conversations';
  static const String colMessages = 'messages';
  static const String colAuditLogs = 'auditLogs';
  static const String colLoans = 'loans';
  static const String colLoanRepayments = 'loanRepayments';
  static const String colAppSettings = 'appSettings';

  // Default Account IDs
  static const String accountCash = 'caisse_especes';
  static const String accountBank = 'compte_bancaire';
  static const String accountJuice = 'compte_juice';

  // Passport alert threshold in days
  static const int passportAlertThresholdDays = 90;
}
