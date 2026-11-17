const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

/**
 * Attribue un rôle et des permissions de façon sécurisée (réservé aux ADMINs vérifiés)
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  // Vérification de l'authentification et du rôle ADMIN
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }

  const callerUid = context.auth.uid;
  const callerUserDoc = await db.collection('users').doc(callerUid).get();

  if (!callerUserDoc.exists || callerUserDoc.data().role !== 'ADMIN') {
    throw new functions.https.HttpsError('permission-denied', 'Seul un administrateur peut modifier les rôles.');
  }

  const { targetUid, role, permissions } = data;
  if (!targetUid || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'UID cible et rôle requis.');
  }

  // Interdiction de rétrograder le dernier admin sans précaution
  await auth.setCustomUserClaims(targetUid, {
    role: role,
    isAdmin: role === 'ADMIN',
  });

  const now = new Date().toISOString();
  await db.collection('users').doc(targetUid).update({
    role: role,
    permissions: role === 'MEMBRE_BUREAU' ? (permissions || []) : [],
    updatedAt: now,
  });

  // Audit
  await db.collection('auditLogs').add({
    userId: callerUid,
    userName: callerUserDoc.data().displayName || 'Admin',
    userRole: 'ADMIN',
    action: 'role.changed_by_admin',
    entityType: 'user',
    entityId: targetUid,
    details: { targetUid, newRole: role, permissions },
    timestamp: now,
  });

  return { success: true };
});

/**
 * Permet à un utilisateur déjà créé sur le serveur via Google de définir ou modifier son mot de passe.
 * Aucune inscription directe n'est autorisée : le document users/{uid} doit déjà exister.
 */
exports.setUserPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }

  const callerUid = context.auth.uid;
  const newPassword = data && typeof data.newPassword === 'string' ? data.newPassword : '';
  if (newPassword.length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Le mot de passe doit comporter au moins 6 caractères.'
    );
  }

  const callerUserDoc = await db.collection('users').doc(callerUid).get();
  if (!callerUserDoc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Seuls les comptes créés initialement via Google sur le serveur AJRA sont autorisés.'
    );
  }

  await auth.updateUser(callerUid, {
    password: newPassword,
  });

  const now = new Date().toISOString();
  await db.collection('users').doc(callerUid).update({
    hasPassword: true,
    passwordUpdatedAt: now,
    updatedAt: now,
  });

  await db.collection('auditLogs').add({
    userId: callerUid,
    userName: callerUserDoc.data().displayName || callerUserDoc.data().email || 'Membre',
    userRole: callerUserDoc.data().role || 'MEMBRE',
    action: 'user.password_set_via_server',
    entityType: 'user',
    entityId: callerUid,
    details: { email: callerUserDoc.data().email || '' },
    timestamp: now,
  });

  return { success: true };
});

/**
 * Déclencheur: notification lors de la validation ou du rejet d'une adhésion
 */
exports.onMembershipReviewed = functions.firestore
  .document('members/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

    const userId = context.params.userId;
    let notifTitle = '';
    let notifBody = '';

    if (after.status === 'active') {
      notifTitle = 'Adhésion AJRA validée !';
      notifBody = 'Félicitations, votre adhésion a été validée par le bureau. Vous pouvez maintenant régler votre droit d\'adhésion.';
    } else if (after.status === 'rejected') {
      notifTitle = 'Statut de votre demande d\'adhésion';
      notifBody = `Votre demande a été rejetée par le bureau. Remarque: ${after.reviewNotes || 'Dossier incomplet'}.`;
    } else {
      return null;
    }

    await db.collection('notifications').add({
      recipientUserId: userId,
      type: 'membership_review',
      title: notifTitle,
      body: notifBody,
      isRead: false,
      targetRoute: '/membership-status',
      createdAt: new Date().toISOString(),
    });

    return null;
  });

/**
 * Déclencheur: notification lors de la confirmation d'un paiement de cotisation
 */
exports.onDuePaymentVerified = functions.firestore
  .document('dues/{dueId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

    if (after.status === 'paid') {
      await db.collection('notifications').add({
        recipientUserId: after.userId,
        type: 'due_paid',
        title: 'Cotisation confirmée',
        body: `Votre règlement pour la cotisation ${after.periodLabel} a été vérifié et encaissé.`,
        isRead: false,
        targetRoute: '/dues',
        createdAt: new Date().toISOString(),
      });
    }

    return null;
  });

/**
 * Supprime un compte utilisateur et ses données par un administrateur vérifié
 */
exports.deleteUserAccountByAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }

  const callerUid = context.auth.uid;
  const callerUserDoc = await db.collection('users').doc(callerUid).get();
  const callerEmail = (context.auth.token.email || '').toLowerCase().trim();

  const isSuperAdmin = callerEmail === 'heriniaina.luk@gmail.com';
  const isAdmin = isSuperAdmin || (callerUserDoc.exists && callerUserDoc.data().role === 'ADMIN');

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Seul un administrateur peut supprimer un compte.');
  }

  const { targetUid } = data;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'UID cible requis.');
  }

  if (targetUid === callerUid) {
    throw new functions.https.HttpsError('failed-precondition', 'L\'administrateur ne peut pas supprimer son propre compte.');
  }

  const targetUserDoc = await db.collection('users').doc(targetUid).get();
  const targetEmail = (targetUserDoc.exists && targetUserDoc.data().email) || '';
  if (targetEmail.toLowerCase().trim() === 'heriniaina.luk@gmail.com') {
    throw new functions.https.HttpsError('permission-denied', 'Impossible de supprimer le compte du super-administrateur principal.');
  }

  // 1. Supprimer le profil membre
  await db.collection('members').doc(targetUid).delete().catch(() => {});

  // 2. Supprimer les paiements d'adhésion
  const paymentsSnap = await db.collection('membershipPayments').where('userId', '==', targetUid).get();
  for (const doc of paymentsSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }
  await db.collection('membershipPayments').doc(targetUid).delete().catch(() => {});

  // 3. Supprimer les cotisations
  const duesSnap = await db.collection('dues').where('userId', '==', targetUid).get();
  for (const doc of duesSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }

  // 4. Supprimer les participations aux événements
  const partsSnap = await db.collection('eventParticipants').where('userId', '==', targetUid).get();
  for (const doc of partsSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }

  // 5. Supprimer les contributions de collectes
  const contribSnap = await db.collection('fundraisingContributions').where('userId', '==', targetUid).get();
  for (const doc of contribSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }

  // 6. Supprimer les notifications
  const notifsSnap = await db.collection('notifications').where('recipientUserId', '==', targetUid).get();
  for (const doc of notifsSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }

  // 7. Supprimer les prêts
  const loansSnap = await db.collection('memberLoans').where('borrowerUserId', '==', targetUid).get();
  for (const doc of loansSnap.docs) {
    await doc.ref.delete().catch(() => {});
  }

  // 8. Supprimer le document utilisateur
  await db.collection('users').doc(targetUid).delete().catch(() => {});

  // 9. Supprimer le compte Firebase Authentication
  try {
    await auth.deleteUser(targetUid);
  } catch (err) {
    console.error('Erreur suppression auth.deleteUser:', err);
  }

  // 10. Journal d'audit
  const now = new Date().toISOString();
  await db.collection('auditLogs').add({
    userId: callerUid,
    userName: (callerUserDoc.exists && callerUserDoc.data().displayName) || 'Admin',
    userRole: 'ADMIN',
    action: 'user.account_deleted_by_admin',
    entityType: 'user',
    entityId: targetUid,
    details: { targetUid, targetEmail },
    timestamp: now,
  });

  return { success: true };
});

/**
 * Déclencheur: envoi d'une notification Push FCM haute priorité (fait sonner le téléphone même écran éteint)
 * lors de la création d'une notification ou d'un message dans la collection `notifications`.
 */
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const title = data.title || 'AJRA';
    const body = data.body || 'Vous avez une nouvelle notification.';
    const recipientUserId = data.recipientUserId || 'all';
    const notifId = context.params.notifId;

    const androidConfig = {
      priority: 'high',
      ttl: 86400 * 1000,
      notification: {
        channelId: 'ajra_notifications_high_v2',
        tag: String(notifId),
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
        priority: 'max',
        visibility: 'public',
      },
    };

    const payloadData = {
      notificationId: String(notifId),
      type: String(data.type || 'general'),
      targetRoute: String(data.targetRoute || '/notifications'),
      entityId: String(data.entityId || ''),
      title: String(title),
      body: String(body),
    };

    try {
      if (recipientUserId === 'all') {
        await admin.messaging().send({
          topic: 'all_members',
          notification: { title, body },
          data: payloadData,
          android: androidConfig,
        });
      } else {
        await admin.messaging().send({
          topic: `user_${recipientUserId}`,
          notification: { title, body },
          data: payloadData,
          android: androidConfig,
        });
      }
    } catch (err) {
      console.error('Erreur envoi FCM onNotificationCreated:', err);
    }

    return null;
  });

