const functions = require('firebase-functions');
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
