import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class AppUpdateCheckResult {
  final bool hasUpdate;
  final bool isMd5Mismatch;
  final bool isPlayStoreUpdate;
  final bool forceUpdate;
  final String localVersion;
  final int localBuildNumber;
  final String remoteVersion;
  final int remoteBuildNumber;
  final String playStoreVersion;
  final String localMd5;
  final String remoteMd5;
  final String apkDownloadUrl;
  final String playStoreUrl;
  final String releaseNotes;

  const AppUpdateCheckResult({
    required this.hasUpdate,
    this.isMd5Mismatch = false,
    this.isPlayStoreUpdate = false,
    this.forceUpdate = false,
    required this.localVersion,
    required this.localBuildNumber,
    required this.remoteVersion,
    required this.remoteBuildNumber,
    this.playStoreVersion = '',
    required this.localMd5,
    required this.remoteMd5,
    required this.apkDownloadUrl,
    required this.playStoreUrl,
    this.releaseNotes = '',
  });
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('com.ajra.ajra/app_updater');
  static bool _autoCheckedInSession = false;
  static bool _isDialogShowing = false;
  static AppUpdateCheckResult? _lastResult;

  static AppUpdateCheckResult? get lastResult => _lastResult;

  static bool _isValidMd5(String value) {
    final trimmed = value.trim();
    return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(trimmed);
  }

  /// Compare deux versions sémantiques (ex: "1.4.9" > "1.4.8")
  static bool isVersionNewer(String candidate, String current) {
    if (candidate.trim().isEmpty) return false;
    final cleanCandidate = candidate.trim().split('+').first.replaceAll(RegExp(r'^v'), '');
    final cleanCurrent = current.trim().split('+').first.replaceAll(RegExp(r'^v'), '');

    final candParts = cleanCandidate
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final currParts = cleanCurrent
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final maxLen = candParts.length > currParts.length ? candParts.length : currParts.length;
    for (int i = 0; i < maxLen; i++) {
      final c = i < candParts.length ? candParts[i] : 0;
      final l = i < currParts.length ? currParts[i] : 0;
      if (c > l) return true;
      if (c < l) return false;
    }
    return false;
  }

  /// Vérifie les mises à jour sur https://ajra-app-8ae42.web.app/app.apk (comparaison MD5),
  /// Google Play Store et Firestore (`appSettings/app_version`).
  static Future<AppUpdateCheckResult> checkForUpdate() async {
    String localVersion = AppConstants.appVersion;
    int localBuildNumber = AppConstants.appBuildNumber;
    String remoteVersion = '';
    int remoteBuildNumber = 0;
    String playStoreVersion = '';
    String localMd5 = '';
    String remoteMd5 = '';
    String resolvedApkUrl = AppConstants.apkDownloadUrl;
    String playStoreUrl = AppConstants.playStoreUrl;
    String releaseNotes = '';
    bool forceUpdate = false;

    // 1. Vérification native Android (MD5 de l'APK installé vs MD5 de https://ajra-app-8ae42.web.app/app.apk + Play Store)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && Firebase.apps.isNotEmpty) {
      try {
        final raw = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('checkRemoteApkAndPlayStore', {
          'apkUrl': AppConstants.apkDownloadUrl,
          'fallbackApkUrl': AppConstants.apkFallbackDownloadUrl,
          'md5Url': AppConstants.apkMd5Url,
          'versionJsonUrl': AppConstants.versionManifestUrl,
        });

        if (raw != null) {
          localVersion = (raw['localVersion'] as String?)?.trim().isNotEmpty == true
              ? (raw['localVersion'] as String).trim()
              : localVersion;
          localBuildNumber = (raw['localBuildNumber'] as int?) ?? localBuildNumber;
          localMd5 = ((raw['localMd5'] as String?) ?? '').trim().toLowerCase();
          remoteMd5 = ((raw['remoteMd5'] as String?) ?? '').trim().toLowerCase();
          remoteVersion = ((raw['remoteVersion'] as String?) ?? '').trim();
          remoteBuildNumber = (raw['remoteBuildNumber'] as int?) ?? 0;
          playStoreVersion = ((raw['playStoreVersion'] as String?) ?? '').trim();
          final nativeUrl = ((raw['resolvedApkUrl'] as String?) ?? '').trim();
          if (nativeUrl.startsWith('http')) {
            resolvedApkUrl = nativeUrl;
          }
          releaseNotes = ((raw['releaseNotes'] as String?) ?? '').trim();
        }
      } catch (e) {
        debugPrint('AppUpdateService native check warning: $e');
      }
    }

    // 2. Vérification complémentaire dans Firestore (`appSettings/app_version`)
    if (Firebase.apps.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(AppConstants.colAppSettings)
            .doc('app_version')
            .get()
            .timeout(const Duration(seconds: 5));

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final fsVersion = (data['version'] as String?)?.trim() ?? '';
          final fsBuild = (data['buildNumber'] as num?)?.toInt() ?? 0;
          final fsMd5 = ((data['md5'] as String?) ?? '').trim().toLowerCase();
          final fsApkUrl = ((data['apkUrl'] as String?) ?? '').trim();
          final fsPlayUrl = ((data['playStoreUrl'] as String?) ?? '').trim();
          final fsNotes = ((data['releaseNotes'] as String?) ?? '').trim();
          final fsForce = (data['forceUpdate'] as bool?) ?? false;

          if (fsVersion.isNotEmpty && (remoteVersion.isEmpty || isVersionNewer(fsVersion, remoteVersion))) {
            remoteVersion = fsVersion;
          }
          if (fsBuild > remoteBuildNumber) {
            remoteBuildNumber = fsBuild;
          }
          if (_isValidMd5(fsMd5) && !_isValidMd5(remoteMd5)) {
            remoteMd5 = fsMd5;
          }
          if (fsApkUrl.startsWith('http')) {
            resolvedApkUrl = fsApkUrl;
          }
          if (fsPlayUrl.startsWith('http')) {
            playStoreUrl = fsPlayUrl;
          }
          if (fsNotes.isNotEmpty && releaseNotes.isEmpty) {
            releaseNotes = fsNotes;
          }
          forceUpdate = fsForce;
        }
      } catch (_) {
        // Silencieux si hors-ligne ou non configuré
      }
    }

    // 3. Comparaison des versions et des empreintes MD5
    final bool versionHigher = isVersionNewer(remoteVersion, localVersion) ||
        (remoteVersion == localVersion && remoteBuildNumber > localBuildNumber);
    final bool playStoreHigher = isVersionNewer(playStoreVersion, localVersion);

    final bool bothMd5Valid = _isValidMd5(localMd5) && _isValidMd5(remoteMd5);
    final bool md5Differs = bothMd5Valid && (localMd5 != remoteMd5);

    final bool hasUpdate = versionHigher || playStoreHigher || md5Differs;

    final effectiveRemoteVersion = playStoreHigher && isVersionNewer(playStoreVersion, remoteVersion)
        ? playStoreVersion
        : (remoteVersion.isNotEmpty ? remoteVersion : localVersion);

    final result = AppUpdateCheckResult(
      hasUpdate: hasUpdate,
      isMd5Mismatch: md5Differs,
      isPlayStoreUpdate: playStoreHigher,
      forceUpdate: forceUpdate,
      localVersion: localVersion,
      localBuildNumber: localBuildNumber,
      remoteVersion: effectiveRemoteVersion,
      remoteBuildNumber: remoteBuildNumber > 0 ? remoteBuildNumber : localBuildNumber,
      playStoreVersion: playStoreVersion,
      localMd5: localMd5,
      remoteMd5: remoteMd5,
      apkDownloadUrl: resolvedApkUrl,
      playStoreUrl: playStoreUrl,
      releaseNotes: releaseNotes,
    );

    _lastResult = result;
    return result;
  }

  /// Lance la vérification automatique à l'ouverture de l'application
  static Future<void> checkOnAppStart(BuildContext context) async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    if (_autoCheckedInSession) return;
    _autoCheckedInSession = true;

    try {
      final result = await checkForUpdate();
      if (!context.mounted) return;
      if (result.hasUpdate && !_isDialogShowing) {
        await showUpdateDialog(context, result);
      }
    } catch (e) {
      debugPrint('Auto update check error: $e');
    }
  }

  /// Vérification manuelle déclenchée par l'utilisateur (ex: depuis Connexion, Profil ou À propos)
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool showUpToDateDialog = true,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Vérification des mises à jour (Play Store & MD5 APK)...',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await checkForUpdate();

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    if (result.hasUpdate) {
      await showUpdateDialog(context, result);
    } else if (showUpToDateDialog) {
      await _showUpToDateModal(context, result);
    }
  }

  static Future<void> launchApkDownload(String url) async {
    final uri = Uri.parse(url.isNotEmpty ? url : AppConstants.apkDownloadUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallback = Uri.parse(AppConstants.apkFallbackDownloadUrl);
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> launchPlayStore(String playStoreWebUrl) async {
    final marketUri = Uri.parse(AppConstants.playStoreMarketUrl);
    final webUri = Uri.parse(
      playStoreWebUrl.isNotEmpty ? playStoreWebUrl : AppConstants.playStoreUrl,
    );
    try {
      if (!kIsWeb && await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateCheckResult info,
  ) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !info.forceUpdate,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.oceanicGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mise à jour disponible',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nouvelle version AJRA détectée',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  info.isMd5Mismatch
                      ? 'Une nouvelle compilation officielle de l\'application (empreinte MD5 différente sur le serveur) est disponible. Mettez à jour l\'application pour bénéficier des dernières fonctionnalités et correctifs.'
                      : 'Une nouvelle version officielle de l\'application AJRA est disponible sur le serveur et Google Play Store.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaRow('Version installée', 'v${info.localVersion} (+${info.localBuildNumber})'),
                      if (info.remoteVersion.isNotEmpty)
                        _buildMetaRow(
                          'Nouvelle version',
                          'v${info.remoteVersion}',
                          valueColor: AppColors.success,
                        ),
                      if (info.localMd5.isNotEmpty) ...[
                        const Divider(height: 16),
                        _buildMetaRow(
                          'MD5 installé',
                          _shortMd5(info.localMd5),
                          monospace: true,
                        ),
                      ],
                      if (info.remoteMd5.isNotEmpty)
                        _buildMetaRow(
                          'MD5 serveur (app.apk)',
                          _shortMd5(info.remoteMd5),
                          valueColor: info.isMd5Mismatch ? AppColors.warning : AppColors.success,
                          monospace: true,
                        ),
                    ],
                  ),
                ),
                if (info.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Nouveautés : ${info.releaseNotes}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Télécharger l\'APK officiel (app.apk)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: () {
                    launchApkDownload(info.apkDownloadUrl);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shop_two_outlined, size: 19),
                  label: const Text(
                    'Ouvrir sur Google Play Store',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    launchPlayStore(info.playStoreUrl);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Plus tard'),
              ),
          ],
        ),
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  static Future<void> _showUpToDateModal(
    BuildContext context,
    AppUpdateCheckResult info,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Application à jour',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vous utilisez déjà la dernière version officielle de l\'application AJRA.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildMetaRow('Version actuelle', 'v${info.localVersion} (+${info.localBuildNumber})'),
                  if (info.localMd5.isNotEmpty)
                    _buildMetaRow('MD5 APK local', _shortMd5(info.localMd5), monospace: true),
                  if (info.remoteMd5.isNotEmpty)
                    _buildMetaRow(
                      'MD5 serveur (app.apk)',
                      _shortMd5(info.remoteMd5),
                      valueColor: AppColors.success,
                      monospace: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Lien APK', style: TextStyle(fontSize: 12)),
                    onPressed: () => launchApkDownload(info.apkDownloadUrl),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.shop_outlined, size: 16),
                    label: const Text('Play Store', style: TextStyle(fontSize: 12)),
                    onPressed: () => launchPlayStore(info.playStoreUrl),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static String _shortMd5(String md5) {
    if (md5.length <= 16) return md5;
    return '${md5.substring(0, 8)}...${md5.substring(md5.length - 8)}';
  }

  static Widget _buildMetaRow(
    String label,
    String value, {
    Color? valueColor,
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimaryLight,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
