/**
 * AJRA — Script sécurisé d'attribution du rôle de Premier Administrateur
 * 
 * Ce script s'exécute exclusivement en environnement serveur / DevOps avec la clé
 * de service account (Firebase Admin SDK), garantissant qu'aucun utilisateur
 * ne peut s'auto-promouvoir depuis le client Flutter ou via un formulaire web public.
 * 
 * Usage:
 *   node scripts/bootstrap_admin.js <email_ou_uid_administrateur>
 * 
 * Prérequis:
 *   Placer la clé de compte de service dans scripts/serviceAccountKey.json
 *   ou définir la variable d'environnement GOOGLE_APPLICATION_CREDENTIALS.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

async function main() {
  const targetIdentifier = process.argv[2];

  if (!targetIdentifier) {
    console.error('❌ ERREUR: Veuillez spécifier l\'adresse e-mail ou l\'UID de l\'administrateur cible.');
    console.log('Usage: node scripts/bootstrap_admin.js admin@ajra-mauritius.org');
    process.exit(1);
  }

  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, 'serviceAccountKey.json');

  if (!fs.existsSync(keyPath) && !process.env.FIREBASE_EMULATOR_HUB) {
    console.error(`❌ Clé de compte de service introuvable : ${keyPath}`);
    console.log('👉 Téléchargez la clé de compte de service depuis la console Firebase :');
    console.log('   Paramètres du projet > Comptes de service > Générer une nouvelle clé privée');
    console.log('   Et sauvegardez-la sous "scripts/serviceAccountKey.json".');
    process.exit(1);
  }

  // Initialisation Admin SDK
  if (!admin.apps.length) {
    if (fs.existsSync(keyPath)) {
      admin.initializeApp({
        credential: admin.credential.cert(require(keyPath)),
      });
    } else {
      admin.initializeApp({ projectId: 'ajra-app' });
    }
  }

  const auth = admin.auth();
  const db = admin.firestore();

  console.log(`🔍 Recherche de l'utilisateur cible : ${targetIdentifier}...`);

  let userRecord;
  try {
    if (targetIdentifier.includes('@')) {
      userRecord = await auth.getUserByEmail(targetIdentifier);
    } else {
      userRecord = await auth.getUser(targetIdentifier);
    }
  } catch (error) {
    console.error(`❌ Impossible de trouver l'utilisateur : ${error.message}`);
    console.log('💡 Assurez-vous que l\'utilisateur s\'est connecté au moins une fois avec son compte Google.');
    process.exit(1);
  }

  console.log(`✅ Utilisateur trouvé : ${userRecord.displayName || 'Sans nom'} (UID: ${userRecord.uid})`);

  // 1. Attribution des Custom Claims côté serveur (vérifiables dans firestore.rules et tokens)
  console.log('🔒 Définition des Custom Claims { role: "ADMIN" }...');
  await auth.setCustomUserClaims(userRecord.uid, {
    role: 'ADMIN',
    isAdmin: true,
  });

  // 2. Mise à jour ou création du profil dans Firestore
  console.log('📝 Mise à jour du document Firestore /users/' + userRecord.uid + '...');
  const now = new Date().toISOString();
  await db.collection('users').doc(userRecord.uid).set({
    uid: userRecord.uid,
    email: userRecord.email,
    displayName: userRecord.displayName || 'Administrateur AJRA',
    photoUrl: userRecord.photoURL || null,
    role: 'ADMIN',
    permissions: [
      'membership.review',
      'membership.manage',
      'dues.record',
      'dues.manage',
      'payment.verify',
      'finance.transaction.create',
      'finance.transaction.approve',
      'finance.report.view',
      'event.manage',
      'fundraising.manage',
      'post.publish',
      'users.manage',
      'audit.view'
    ],
    isSuspended: false,
    updatedAt: now,
  }, { merge: true });

  // 3. Enregistrement dans le journal d'audit immuable
  await db.collection('auditLogs').add({
    userId: 'CLI_SERVER_BOOTSTRAP',
    userName: 'Système DevOps / CLI Admin',
    userRole: 'SUPER_ADMIN',
    action: 'admin.bootstrapped',
    entityType: 'user',
    entityId: userRecord.uid,
    details: {
      targetEmail: userRecord.email,
      method: 'service_account_cli',
    },
    timestamp: now,
  });

  console.log('\n🎉 SUCCÈS : Le premier administrateur a été configuré avec succès !');
  console.log(`   - Nom : ${userRecord.displayName}`);
  console.log(`   - Email : ${userRecord.email}`);
  console.log(`   - Rôle : ADMIN (Custom Claim injecté)`);
  console.log('L\'utilisateur peut désormais se connecter à l\'application avec ses droits complets.');
  process.exit(0);
}

main().catch(err => {
  console.error('Erreur inattendue :', err);
  process.exit(1);
});
