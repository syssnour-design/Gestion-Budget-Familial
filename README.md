# BudgetFoyer — Budget familial prévisionnel

Application web de suivi du budget familial mensuel : ressources, dépenses, imprévus, objectifs et tableau de bord, construite sur la démarche du guide DGTCP « La gestion du budget familial » (élaborer, exécuter, suivre, évaluer).

## Fonctionnalités

- **Comptes utilisateurs** : création de compte et connexion (mot de passe haché SHA-256 avec sel), plusieurs comptes par appareil, changement de mot de passe, suppression du compte.
- **Rubriques personnalisables** : ressources (régulières fixes, régulières variables, occasionnelles) et dépenses (fixes, variables, occasionnelles, imprévus, épargne), avec couleur, type besoin/envie/épargne et classe 1 à 4 pour la règle 20/20/30/30. 30 rubriques adaptées au contexte ivoirien fournies par défaut (CIE, SODECI, tontine, aide aux parents, nounou…).
- **Budget prévisionnel mensuel** : saisie du prévu par rubrique, réalisé et écart en temps réel, solde prévisionnel avec conduite à tenir, reprise du mois précédent, extension à l'année, contrôle avec la règle de répartition choisie.
- **Journal des opérations** : date, montant, rubrique, libellé, mode de paiement (espèces, Mobile Money, virement…), exécutant, reçu conservé, imprévu payé par le fonds. Filtres, recherche, export CSV (compatible Excel).
- **Tableau de bord** avec filtre **mensuel, trimestriel, semestriel et annuel** : solde réalisé et barre d'équilibre ressources/dépenses, indicateurs (exécution des ressources et des dépenses, taux d'épargne, imprévus), évolution sur l'année, répartition des dépenses, comparaison à la règle, alertes de dépassement, tableau des écarts prévu/réalisé exportable et imprimable.
- **Règles de répartition** : 50/20/30, 20/20/30/30, 50/40/10, 50/50, avec simulateur.
- **Fonds d'imprévus** : cible en mois de besoins, solde alimenté par sa rubrique et diminué par les imprévus qu'il finance.
- **Objectifs SMART** : montant, échéance, épargne mensuelle nécessaire, versements.
- **Sauvegarde** : export/import JSON, données d'exemple, thème clair/sombre, affichage mobile, raccourci clavier `N` pour une nouvelle opération.

## Déploiement sur GitHub Pages

1. Créez un dépôt (par exemple `budget-familial`) et déposez-y `index.html`, `supabase.sql`, `README.md` et `.nojekyll`.
2. Dans **Settings > Pages**, choisissez **Deploy from a branch**, branche `main`, dossier `/ (root)`.
3. L'application est en ligne après une ou deux minutes à l'adresse `https://<votre-compte>.github.io/budget-familial/`.

En ligne de commande :

```bash
git init && git add . && git commit -m "BudgetFoyer v1"
git branch -M main
git remote add origin https://github.com/<votre-compte>/budget-familial.git
git push -u origin main
```

## Partager le budget entre plusieurs téléphones

L'application fonctionne en deux modes :

- **Mode local** (par défaut) : les données restent dans le navigateur de l'appareil.
- **Mode familial partagé** : chaque membre a son compte, tous travaillent sur le même budget, les saisies apparaissent sur les autres téléphones en quelques secondes. Chaque téléphone garde une copie pour fonctionner hors connexion ; les saisies faites sans réseau partent dès que la connexion revient.

### Mise en place (une seule fois, 10 minutes, offre gratuite de Supabase suffisante)

1. Créez un compte sur [supabase.com](https://supabase.com), puis un projet (région la plus proche, par exemple Europe de l'Ouest).
2. Ouvrez **SQL Editor > New query**, collez tout le contenu de `supabase.sql`, cliquez **Run**.
3. Dans **Authentication > URL Configuration**, mettez l'adresse GitHub Pages de l'application dans **Site URL** (par exemple `https://<votre-compte>.github.io/budget-familial/`) et ajoutez-la aussi dans **Redirect URLs**. Cela permet aux liens de confirmation et de réinitialisation du mot de passe de revenir vers l'application.
4. Dans **Project Settings > API**, copiez **Project URL** et la clé **anon public**.
5. Ouvrez `index.html`, cherchez `const SUPABASE_URL=''` et `const SUPABASE_ANON_KEY=''`, collez les deux valeurs entre les guillemets, puis publiez sur GitHub. La clé *anon* est faite pour être publique : ce sont les règles de sécurité du script SQL qui protègent les données.
   (Variante sans modifier le code : sur chaque téléphone, écran de connexion > **Configurer la synchronisation familiale**.)

### Utilisation en famille

1. Le premier membre crée son compte, puis **Créer un nouveau foyer**. Il peut reprendre les données d'un compte local existant sur le téléphone ou partir des données d'exemple.
2. Dans **Réglages > Foyer partagé**, il envoie l'invitation (WhatsApp ou partage du téléphone) : elle contient le lien et le code du foyer.
3. Chaque membre crée son compte, confirme son e-mail, puis saisit le code dans **Rejoindre un foyer**.
4. L'administrateur peut changer le code et retirer un membre ; chacun peut quitter le foyer.

Sécurité : les règles RLS de Postgres garantissent qu'un utilisateur ne lit et n'écrit que les données des foyers dont il est membre. Les mots de passe sont gérés par Supabase Auth.

Astuce : sur le téléphone, ouvrez l'application dans Chrome ou Safari puis **Ajouter à l'écran d'accueil** pour l'utiliser comme une application.

## Données et sécurité

En mode local, les comptes et les données sont enregistrés dans le `localStorage` du navigateur, sans synchronisation ; exportez régulièrement la sauvegarde JSON depuis **Paramètres**. En mode partagé, les données sont stockées dans votre projet Supabase (vous en restez propriétaire) et une copie de travail est gardée sur chaque téléphone ; la déconnexion efface cette copie.

## Technologies

HTML, CSS et JavaScript sans framework ; Supabase (authentification, Postgres, temps réel) pour le mode partagé ; Chart.js 4 (cdnjs) pour les graphiques ; polices Bricolage Grotesque et Source Sans 3 (Google Fonts).
