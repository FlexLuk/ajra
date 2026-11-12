import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/sound_helper.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const MethodChannel _nativeChannel = MethodChannel('com.ajra.ajra/notifications');

  static String? _subscribedUserId;
  static DateTime? _lastNotificationAt;
  static String? _lastNotificationSignature;
  static final Set<String> _shownNotificationIds = {};

  /// Initialise les permissions et les abonnements FCM (pour réveiller le téléphone même écran éteint)
  static Future<void> initializeForUser(String userId) async {
    if (userId.isEmpty) return;

    try {
      if (!kIsWeb) {
        await _nativeChannel.invokeMethod('requestPermission');
      }
    } catch (_) {}

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      if (!kIsWeb && _subscribedUserId != userId) {
        if (_subscribedUserId != null && _subscribedUserId!.isNotEmpty) {
          try {
            await messaging.unsubscribeFromTopic('user_$_subscribedUserId');
          } catch (_) {}
        }
        _subscribedUserId = userId;
        try {
          await messaging.subscribeToTopic('all_members');
          await messaging.subscribeToTopic('user_$userId');
        } catch (_) {}
      }

      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _firestore.collection(AppConstants.colUsers).doc(userId).update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// Affiche une notification système sur le téléphone et déclenche la sonnerie de notification
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    int? id,
    String? notificationId,
  }) async {
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        !_shownNotificationIds.add(notificationId)) {
      return;
    }

    final now = DateTime.now();
    final sig = '$title|$body';
    if (_lastNotificationAt != null &&
        _lastNotificationSignature == sig &&
        now.difference(_lastNotificationAt!).inMilliseconds < 2500) {
      return;
    }
    _lastNotificationAt = now;
    _lastNotificationSignature = sig;

    final notifId = (id ?? now.millisecondsSinceEpoch).abs() % 2147483647;

    if (!kIsWeb) {
      try {
        await _nativeChannel.invokeMethod('showNotification', {
          'id': notifId,
          'tag': notificationId ?? '',
          'title': title,
          'body': body,
        });
        return;
      } catch (_) {}
    } else {
      try {
        showPlatformWebNotification(title, body);
      } catch (_) {}
    }

    playNotificationSound();
  }

  /// Joue le son de notification du téléphone et déclenche une vibration
  static void playNotificationSound() {
    if (!kIsWeb) {
      try {
        _nativeChannel.invokeMethod('playNotificationSound');
      } catch (_) {}
    }
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
      HapticFeedback.heavyImpact();
    } catch (_) {}
    try {
      playPlatformChime();
    } catch (_) {}
  }

  /// Envoie une notification générale à tous les membres (événements, actualités officielles)
  static Future<void> createBroadcastNotification({
    required String title,
    required String body,
    String type = 'general',
    String? targetRoute,
    String? entityType,
    String? entityId,
    String? senderUserId,
    String? senderName,
  }) async {
    try {
      final notifId = const Uuid().v4();
      await _firestore.collection(AppConstants.colNotifications).doc(notifId).set({
        'title': title,
        'body': body,
        'type': type,
        'recipientUserId': 'all',
        'senderUserId': senderUserId ?? '',
        'senderName': senderName ?? 'AJRA',
        'entityType': entityType,
        'entityId': entityId,
        'targetRoute': targetRoute,
        'isRead': false,
        'readBy': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignorer silencieusement si hors-ligne
    }
  }

  /// Envoie une notification personnelle à un utilisateur spécifique (messages, cotisations, statut)
  static Future<void> createUserNotification({
    required String recipientUserId,
    required String title,
    required String body,
    String type = 'general',
    String? targetRoute,
    String? entityType,
    String? entityId,
    String? senderUserId,
    String? senderName,
  }) async {
    if (recipientUserId.isEmpty) return;

    try {
      final notifId = const Uuid().v4();
      await _firestore.collection(AppConstants.colNotifications).doc(notifId).set({
        'title': title,
        'body': body,
        'type': type,
        'recipientUserId': recipientUserId,
        'senderUserId': senderUserId ?? '',
        'senderName': senderName ?? 'AJRA',
        'entityType': entityType,
        'entityId': entityId,
        'targetRoute': targetRoute,
        'isRead': false,
        'readBy': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignorer silencieusement si hors-ligne
    }
  }

  /// Marque une notification comme lue par un utilisateur donné (ne se réactivera plus jamais)
  static Future<void> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    if (notificationId.isEmpty || userId.isEmpty) return;

    try {
      await _firestore.collection(AppConstants.colNotifications).doc(notificationId).update({
        'isRead': true,
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      // Document inexistant ou erreur réseau
    }
  }

  /// Marque toutes les notifications non lues comme lues pour un utilisateur
  static Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String userId,
  }) async {
    if (notificationIds.isEmpty || userId.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final ref = _firestore.collection(AppConstants.colNotifications).doc(id);
      batch.update(ref, {
        'isRead': true,
        'readBy': FieldValue.arrayUnion([userId]),
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      // Erreur silencieuse
    }
  }

  /// Rétrocompatibilité : Notifie les membres lors d'actions du Bureau ou de l'Admin
  static Future<void> notifyIfBureauAction({
    required String actorUserId,
    required String actorName,
    required String actorRole,
    required String title,
    required String body,
    String? entityType,
    String? entityId,
    String? targetRoute,
  }) async {
    return createBroadcastNotification(
      title: title,
      body: body,
      type: entityType ?? 'general',
      targetRoute: targetRoute,
      entityType: entityType,
      entityId: entityId,
      senderUserId: actorUserId,
      senderName: actorName,
    );
  }
}
