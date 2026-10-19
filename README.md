# AJRA — Association des Jeunes de la Région Anosy

Application mobile et système d'information de gestion pour l'**Association des Jeunes de la Région Anosy (AJRA)** à l'Île Maurice.

Développée en **Flutter & Dart**, adossée aux services **Firebase**, avec une architecture par fonctionnalités, un système strict de contrôle d'accès basé sur les rôles et permissions (RBAC), et une traçabilité comptable et administrative intégrale.

---

## 1. Principes & Décisions Métier Définitives

### 🇲🇺 Devise et Précision Financière
* **Devise officielle** : Roupie mauricienne (**MUR**).
* **Symbole affiché** : **Rs.** (ex: `1 500,00 Rs.`).
* **Précision monétaire** : Tous les montants financiers sont manipulés et stockés sous forme de centimes entiers (`int cents`) via la classe dédiée `Money`. **Aucun calcul financier flottant n'est toléré**, garantissant l'exactitude absolue des bilans au centime près.
* **Aucune conversion automatique** n'est appliquée.

### 🛡️ Adhésions & Séparation des Responsabilités
* Une connexion Google crée un profil utilisateur inscrit avec le statut **« En attente »** ; elle ne confère **jamais** automatiquement le statut de membre actif.
* Seul un **Administrateur** ou un membre du bureau ayant la permission explicite `membership.review` peut approuver ou rejeter une adhésion.
* **Règle absolue d'impartialité** : Un membre ne peut **jamais** approuver sa propre adhésion ni valider son propre paiement.

### 💰 Gestion des Paiements Hors-Application
* Tous les paiements réels (droits d'adhésion, cotisations mensuelles, collectes de fonds) s'effectuent **hors application** (virement bancaire MCB / SBM, ou remise en espèces).
* Le membre déclare son paiement en renseignant la référence bancaire et la preuve de transaction.
* Le trésorier ou vérificateur habilité (`payment.verify`) contrôle la réception réelle sur le compte de l'AJRA avant confirmation.
* **Écriture comptable unique** : La confirmation d'un paiement génère automatiquement **une seule opération financière validée** dans `financialTransactions` et crédite le compte associatif concerné (`caisse_especes` ou `compte_bancaire`).
* **Solde officiel** : `Solde = Solde initial + Recettes validées − Dépenses validées`. Les opérations en attente ou rejetées n'affectent jamais le solde officiel.

### 🔒 Confidentialité des Données Sensibles
* Les numéros de passeport et pièces d'identité sont strictement protégés par les règles Firestore & Storage.
* Les utilisateurs non habilités ne voient qu'une version masquée (ex: `AB****67`).
* Les exports CSV et PDF publics excluent systématiquement les données sensibles de passeport.

---

## 2. Rôles et Matrice des Permissions

| Rôle | Description | Droits |
|---|---|---|
| **ADMIN** | Superviseur général et exécutif | Accès complet, gestion des utilisateurs, attribution des permissions, validation finale. |
| **MEMBRE_BUREAU** | Responsables de l'association | Accès conditionné par les permissions explicites attribuées individuellement. |
| **MEMBRE** | Membre régulier de l'AJRA | Consultation de son dossier, déclaration de paiements, accès aux actualités, événements, dons et messagerie privée. |

### Permissions granulaires du bureau (`AppPermissions`)
* `membership.review` : Valider ou rejeter les dossiers d'adhésion.
* `membership.manage` : Modifier les informations administratives des membres.
* `dues.record` : Enregistrer un paiement de cotisation reçu hors-application.
* `dues.manage` : Générer les échéances mensuelles et barèmes de cotisations.
* `payment.verify` : Contrôler et certifier l'encaissement effectif des fonds.
* `finance.transaction.create` : Saisir des dépenses ou recettes prévisionnelles.
* `finance.transaction.approve` : Valider définitivement les écritures comptables.
* `finance.report.view` : Consulter les bilans et rapports financiers.
* `event.manage` : Créer et administrer les événements associatifs.
* `fundraising.manage` : Gérer les campagnes de collecte et contributions.
* `post.publish` : Publier des annonces et communiqués officiels.
* `users.manage` : Administrer les statuts des utilisateurs.
* `audit.view` : Consulter le journal d'audit immuable.

---

## 3. Architecture Technique du Projet

Architecture modulaire **Feature-First** avec séparation stricte des couches :

```
lib/
├── core/
│   ├── constants/             # Noms des collections Firestore, devises, alertes
│   ├── routing/               # Navigation GoRouter, gardes d'authentification et de rôles
│   ├── security/              # Rôles, permissions explicites, statuts d'adhésion
│   ├── theme/                 # Charte graphique AJRA, palettes de couleurs, Material 3
│   └── utils/                 # Money (calculs exacts en centimes MUR), DateUtils, Audit
├── shared/
│   └── widgets/               # Composants réutilisables (AjraButton, MetricCard, StatusBadge, etc.)
└── features/
    ├── admin/                 # Administration des rôles et permissions
    ├── audit/                 # Journalisation immuable des décisions et actions sensibles
    ├── auth/                  # Connexion Google, synchronisation profil, persistance
    ├── dashboard/             # Tableaux de bord dynamiques (Admin, Bureau, Membre)
    ├── dues/                  # Cotisations mensuelles, échéances idempotentes, arriérés
    ├── events/                # Événements, calendrier, gestion des inscriptions (RSVP)
    ├── fundraising/           # Collectes associées aux événements, suivi d'objectifs
    ├── membership/            # Formulaire d'adhésion, alertes expiration de passeport
    ├── membership_fees/       # Paramétrage et vérification du droit d'adhésion unique
    ├── messaging/             # Messagerie privée temps réel sécurisée par participant
    ├── notifications/         # Centre d'alertes in-app & intégration FCM
    ├── posts/                 # Fil d'actualités officielles
    ├── reports/               # Génération de rapports et exports CSV & PDF
    ├── treasury/              # Portefeuille multi-comptes (caisse espèces, banque)
    └── user_profile/          # Profil membre, paramètres et procédure de suppression RGPD
```

---

## 4. Modèle de Données Cloud Firestore

1. **`users/{uid}`** :
   * `uid`, `email`, `displayName`, `photoUrl`, `role` (`ADMIN`, `MEMBRE_BUREAU`, `MEMBRE`), `permissions` (`List<String>`), `isSuspended` (`bool`), `createdAt`, `updatedAt`, `lastLoginAt`.
2. **`members/{userId}`** :
   * `userId`, `memberNumber` (ex: `AJRA-2026-AB12`), `lastName`, `firstName`, `birthDate`, `residentialAddress`, `email`, `phone`, `photoUrl`, `appliedAt`, `approvedAt`, `rejectedAt`, `reviewNotes`, `status` (`pending`, `active`, `rejected`, `suspended`, `terminated`), `passportNumber`, `passportIssueDate`, `passportExpiryDate`, `permitType` (`worker`, `student`), `jobTitle`, `employer`, `fieldOfStudy`, `institution`.
3. **`membershipFeeConfigs/current`** :
   * `amountCents` (ex: `50000` pour 500.00 Rs.), `effectiveDate`, `updatedByUserId`, `bankInstructions`.
4. **`membershipPayments/{userId}`** :
   * `userId`, `amountCents`, `paymentMode`, `transactionReference`, `proofUrl`, `isDeclared`, `isVerified`, `verifiedAt`, `verifiedByUserId`, `financialTransactionId`.
5. **`dues/{dueId}`** (ID déterministe: `${userId}_${year}_${month}`) :
   * `userId`, `memberNumber`, `memberName`, `periodYear`, `periodMonth`, `periodLabel`, `amountCents`, `amountPaidCents`, `status`, `declaredPaymentMode`, `transactionReference`, `verifiedAt`, `financialTransactionId`.
6. **`financialAccounts/{accountId}`** :
   * `id` (`caisse_especes`, `compte_bancaire`), `name`, `initialBalanceCents`, `currentBalanceCents`, `isDefault`, `isActive`.
7. **`financialTransactions/{txId}`** :
   * `id`, `type` (`income`, `expense`, `transfer`), `category`, `amountCents`, `date`, `description`, `paymentMode`, `reference`, `accountId`, `targetAccountId`, `status` (`pending`, `validated`, `rejected`, `cancelled`), `linkedEntityType`, `linkedEntityId`, `createdByUserId`, `validatedByUserId`.
8. **`events/{eventId}`** :
   * `id`, `title`, `description`, `type`, `startDate`, `endDate`, `location`, `organizerUserId`, `estimatedBudgetCents`, `status`.
9. **`fundraisingCampaigns/{campaignId}`** :
   * `id`, `title`, `description`, `eventId`, `goalAmountCents`, `collectedAmountCents`, `startDate`, `deadline`, `isActive`.
10. **`fundraisingContributions/{contribId}`** :
    * `campaignId`, `userId`, `contributorName`, `amountCents`, `paymentMode`, `reference`, `isVerified`, `financialTransactionId`.
11. **`posts/{postId}`** :
    * `title`, `content`, `authorUserId`, `authorName`, `publishedAt`, `isArchived`.
12. **`notifications/{notifId}`** :
    * `recipientUserId`, `type`, `title`, `body`, `isRead`, `targetRoute`, `createdAt`.
13. **`conversations/{convId}`** & **`messages/{messageId}`** :
    * `participantIds` (`[uid1, uid2]`), `participantNames`, `lastMessageText`, `lastMessageTime`, `unreadCounts`.
14. **`auditLogs/{logId}`** :
    * `userId`, `userName`, `userRole`, `action`, `entityType`, `entityId`, `details`, `timestamp`. **Collection en écriture seule (immuable)**.

---

## 5. Procédure Sécurisée : Création du Premier Administrateur

> [!CAUTION]
> **Règle de sécurité critique** : Aucun utilisateur ne peut s'auto-promouvoir Administrateur depuis l'application mobile ou un formulaire public. Le rôle initial est injecté via le Firebase Admin SDK avec la clé de compte de service.

### Étapes d'exécution :
1. Créez votre projet sur la [Console Firebase](https://console.firebase.google.com/).
2. Rendez-vous dans **Paramètres du projet** > **Comptes de service** > **Générer une nouvelle clé privée**.
3. Enregistrez le fichier JSON téléchargé sous :
   ```
   scripts/serviceAccountKey.json
   ```
4. Demandez à la personne désignée comme premier administrateur de se connecter **une première fois avec son compte Google** sur l'application AJRA (son document `users/{uid}` sera créé avec le rôle standard `MEMBRE`).
5. Depuis une machine d'administration sécurisée, installez les dépendances du script :
   ```bash
   cd scripts
   npm install
   ```
6. Exécutez le script d'attribution du rôle avec l'adresse Gmail de l'administrateur :
   ```bash
   node bootstrap_admin.js "admin.ajra@gmail.com"
   ```
7. Le script va :
   * Vérifier l'identité auprès de Firebase Authentication.
   * Définir le **Custom Claim** officiel `{ role: 'ADMIN', isAdmin: true }`.
   * Mettre à jour le document Firestore `users/{uid}` avec l'ensemble des permissions.
   * Consigner l'événement dans le journal d'audit immuable (`auditLogs`).

Dès sa reconnexion, l'utilisateur disposera automatiquement de l'accès au tableau de bord administrateur et pourra gérer l'association et le bureau.

---

## 6. Lancement Local & Tests

### Prérequis
* Flutter SDK (3.44+ recommandé, Dart 3.12+)
* Node.js 18+ (pour Cloud Functions et scripts d'administration)
* Git

### Installation
```bash
# Récupération des dépendances Flutter
flutter pub get

# Lancement de la suite complète de tests (17 tests automatisés)
flutter test
```

### Exécution avec les émulateurs Firebase
Pour tester l'ensemble des règles de sécurité et Cloud Functions en local :
```bash
# Démarrage de la suite d'émulateurs Firebase
firebase emulators:start
```

---

## 7. Déploiement & Compilation

### Déploiement des Règles et Cloud Functions
```bash
# Déploiement des règles Firestore, Storage et index
firebase deploy --only firestore:rules,firestore:indexes,storage

# Déploiement des Cloud Functions
firebase deploy --only functions
```

### Compilation Android (Release APK & App Bundle)
```bash
# Génération de l'APK Release pour Android
flutter build apk --release

# Génération de l'App Bundle pour Google Play Store
flutter build appbundle --release
```

### Compilation iOS (Release IPA)
```bash
# Préparation des pods et bundle iOS
cd ios && pod install && cd ..
flutter build ipa --release
```

---

## 8. Sauvegarde et Restauration

### Sauvegarde planifiée de Firestore
Dans Google Cloud Console, configurez un export quotidien automatique vers un bucket Cloud Storage sécurisé :
```bash
gcloud firestore export gs://ajra-backups-bucket/daily-$(date +%Y%m%d)
```

### Restauration
```bash
gcloud firestore import gs://ajra-backups-bucket/daily-20261019/
```

---

## 9. Licence & Propriété
Ce projet est développé exclusivement pour l'**Association des Jeunes de la Région Anosy (AJRA)**.
Tous droits réservés.
