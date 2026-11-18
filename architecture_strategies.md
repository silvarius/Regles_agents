# Architecture des stratégies — quatre couches

Statut : **validé par Jérôme (confirmé le 2026-11-17) ; précisé le 2026-11-17
par la refonte du moteur propmaster** (`Master/Propmaster/Backtest/propfirm/
cahier_des_charges_refonte.md` et `spec_propmaster.md`, en projet). Vocabulaire et règles communes à tous
les projets de Trading (Gunmaster, Propmaster, etc.). Les détails
d'implémentation vivent dans chaque projet.

## 1. Les quatre couches

| Couche | Objet | Identité | Dépend du contexte master | On y backteste et on y optimise | Sortie |
|---|---|---|---|---|---|
| 1 | **Stratégie** : une idée originale et ses règles algorithmiques | code stratégie (`R1C`, `MAR`, `FVG`…) | non | rien : spécification, détecteurs testés | `spec_<strat>.md` |
| 2 | **Couple** (stratégie-actif) : une stratégie sur un actif (MNQ…) | `<STRAT>-<ACTIF>` ; une variante ajoute `-<MNÉMONIQUE>` | oui | début du backtest et de l'optimisation, en deux temps (§3) | table de trades en R (format unitaire, avec MFE/MAE à la minute) |
| 3 | **Portefeuille** : une stratégie sur plusieurs actifs | portefeuille d'une stratégie, dans un master | oui | choix des actifs ; tailles des couples ajustées pour neutraliser les effets de corrélation | flux de trades pondérés du portefeuille |
| 4 | **Master** : plusieurs portefeuilles associés | gunmaster, propmaster, futurmaster | c'est le contexte | tailles ajustées à un niveau macro pour respecter le drawdown maximal accepté ; évaluation de la performance finale | allocation prête à porter en production |

Seuls les masters sont portés en production. Un master à un seul
portefeuille reste exceptionnel. Gunmaster existe ; propmaster (prop firms)
et futurmaster (futures chez un courtier) sont à venir.

## 2. Stratégie, variante, contexte

- **Stratégie** : une idée originale (FVG : exploiter un FVG ; MARET :
  exploiter le retournement d'une moyenne mobile). **Variante** : un
  ajustement de la même idée (nature des filtres, unité de temps, session,
  type d'ordre, nature des sorties). La frontière est discrétionnaire.
- Une stratégie ne change de nom dans un autre contexte que si **ses règles**
  changent. Le même algorithme dans deux contextes est la même stratégie ;
  seules ses formes globales et ses tailles diffèrent.
- Seules les stratégies de la couche 1 sont agnostiques au contexte. Un
  couple et un portefeuille sont toujours optimisés **dans** un contexte
  master ; il n'y a pas d'optimisation « neutre ».
- **Préfixe de contexte** : le contexte se marque par un préfixe sur les
  codes de couple et de variante (`GUN`, `PROP`, `FUT`), par exemple
  `PROP-FVG-MNQ-BASE`. Il n'entre jamais dans le code de la stratégie
  (couche 1, agnostique).
- Les **plans** font partie du contexte propmaster et n'ont pas de sens
  ailleurs.
- Dans un contexte, un couple peut avoir plusieurs optimisations
  **indépendantes**. Pour propmaster, par plan : **Évaluation** (minimiser
  le temps de passage en respectant les règles du plan) et **Financé**
  (maximiser le sortino). Les deux optimisations sont
  indépendantes, sauf une dépendance à sens unique : le Financé reçoit de
  l'Évaluation du même couple et du même plan le temps d'attente après la
  perte d'un compte et le coût d'obtention d'un compte (aucune boucle), à
  l'exclusion de la forme et de la table de trades : chaque objectif a sa forme
  globale. Un couple propmaster déployé porte donc deux formes (comptes
  d'Évaluation, comptes financés) : deux instances de la stratégie ou un
  changement de paramètres au passage de phase, à fixer à la couche 4
  (adaptateur d'exécution, portabilité Gunbot). Définition exacte des mesures :
  spécification du moteur propmaster, jamais recopiée ici.
- Identité d'une optimisation : (couple, contexte master, plan le cas
  échéant, objectif, forme globale).

## 3. Dimensionnement

La couche 2 optimise en deux temps.

1. **Optimisation de la forme à taille unique.** La taille de position est la
   même pour tous les trades : 1 % du capital de départ normalisé à 10 000 $,
   converti en nombre de contrats arrondi au plus proche ; si l'arrondi donne
   zéro, le trade n'est pas déclenché. Elle neutralise les comparaisons
   par rapport au capital de départ, au contexte master et à la durée de
   l'échantillon. 1 % du capital s'entend comme risque par trade (100 $).
   L'arrondi écarte les trades à stop large et peut favoriser des stops
   serrés : la part de trades non déclenchés est rapportée pour chaque
   forme, avec une alerte fixée à l'avance (20 %) ; au-delà, la forme est
   examinée avant d'être retenue, décision tracée. Un trade dont la taille
   acceptable est nulle (arrondi à zéro, ou limite de risque du contexte
   franchie même avec un contrat) n'est pas déclenché. Le critère de forme est
   commun aux objectifs d'un contexte : sortino par trade (sur la table de
   trades en R, seuil 0) × √(trades déclenchés par an), à maximiser ; aucune
   mesure de compte n'est rapportée à cette étape.
2. **Optimisation de la taille.** L'algorithme dépend du contexte master :
   pnl pour gunmaster, sous plafond de risque (`MAX_RISK_FRACTION`) ;
   sortino et temps de passage pour propmaster.

Puis :

- **Couche 3** : les tailles de chaque couple sont adaptées pour neutraliser
  les effets de corrélation entre les couples du portefeuille. La méthode se
  définit au cas par cas ; une méthode générique sera adoptée si elle se
  dégage. Les tailles s'expriment en coefficients appliqués à la fraction de
  risque, sans modifier la valeur issue de la couche 2 ; quand la taille
  dépend de l'état du compte, la conversion en contrats se fait en couche 4.
- **Couche 4** : un **coefficient global unique**, appliqué à chaque trade,
  satisfait le niveau de risque que le trader accepte, matérialisé par un
  drawdown maximal (gunmaster : −30 %). Il est choisi pour atteindre ce
  drawdown, non optimisé. Pas de coefficients séparés par portefeuille en
  couche 4 : étudié dans gunmaster, pénalisant.
- **Propmaster** : la performance finale se mesure comme en trading
  traditionnel, par le retour sur le capital engagé, en tenant compte du
  niveau de pnl, du risque (le drawdown est matérialisé par les flux de
  frais) et de la régularité. Le capital engagé est le drawdown maximal de la
  trésorerie du trader (frais nets cumulés, le `budget_max` des scénarios
  propfirm), et non le capital mis à disposition par la firme.

## 4. Validation et biais de sélection

- Chaque couche tient son **journal d'essais** : formes globales testées
  (couche 2), sous-ensembles d'actifs et jeux de poids (couche 3),
  coefficients et allocations (couche 4).
- Chaque couche a son propre découpage IS / OOS ; un OOS n'est lu qu'une
  fois par objet évalué.
- **Phase de démarrage** : sans base de référence, les critères de
  validation ne peuvent pas être fixés à l'avance. La validation est
  **discrétionnaire** (décision de Jérôme) mais **tracée** : décision et
  justification consignées au changelog avant la lecture de l'OOS. Les
  critères de validation par défaut seront fixés dans un second temps, une
  fois une base de référence solide constituée.
- Les ajustements des couches 3 et 4 restent de faible dimension : poids par
  couple en couche 3, un scalaire en couche 4.

## 5. Contrats de données

- **Contexte injecté en couche 2** : le contexte impose à la simulation du
  couple ses **contraintes** (entrées interdites, clôtures forcées, coûts) et
  le **domaine admissible de ses paramètres** (maximum de contrats, sessions,
  types d'ordre ou de sortie, actifs supportés ; une variante entière peut
  être exclue) ; la stratégie est relancée quand les contraintes changent.
  Les restrictions sont déclarées côté contexte, dans le vocabulaire de la
  stratégie, qui ne connaît aucun contexte.
- **Contrat de contexte** : chaque contexte expose un contrat en trois parties :
  *contraintes imposées* à la stratégie, *données exigées* en retour (colonnes
  et unités de la table de trades, couverture des échantillons), *sorties* (format
  et objectifs). L'orchestrateur vérifie les données contre le contrat à
  l'entrée et à chaque frontière de couche. Le contrat est versionné ; sa
  version et l'empreinte du contexte entrent dans la clé de cache et dans
  l'identité du couple.
- **2 → 3** : table de trades en R (stratégie, actif, forme globale,
  contexte, dates et prix d'entrée et de sortie, R réalisé, MFE / MAE
  minute), au **format de base unique** du cœur, identique pour tous les
  contextes ; un contexte peut exiger un sur-ensemble, jamais un autre
  format.
- **3 → 4** : flux de trades pondérés par portefeuille, sur un calendrier
  commun (équité jointe à la minute) ; les corrélations se mesurent sur ces
  flux. Pas de resimulation des signaux à partir de la couche 3.
- Le moteur se compose de fonctions pures par couche, chacune lisant la
  sortie de la précédente.

## 6. Définition d'un master

Un master définit :

- son **objectif** : un **critère de performance** et un **critère de
  risque** (gunmaster : capital final à drawdown cible ; propmaster : temps
  de passage et sortino par plan, puis retour sur capital engagé) ;
- un **espace backtest** et un **espace production** ;
- une ou plusieurs **plateformes d'exécution** (gunmaster : Gunbot ;
  propmaster : MetaTrader, et d'autres plateformes selon les contraintes des
  différentes prop firms).

Plusieurs masters peuvent partager des **ressources communes** : utilitaires
logiciels, données de marché, accès aux données et aux résultats. Exemple de
duplication résorbée (2026-11-17) : `ohlcv_acces.py` est un exemplaire unique dans
`Ressources_master/` (il existait en copie identique dans `Recherche/` et
`Gunmaster/Backtest/`).

Interfaces cibles d'un moteur à cœur commun :

| Rôle | Contenu |
|---|---|
| Cœur, commun à tous les contextes | données et contrôle qualité, coûts et R, simulateur de sortie unique, table de trades canonique, statistiques, témoin, biais, optimiseur, cache, journal des essais |
| Module de stratégie | signaux et règles d'entrée et de sortie, interface unique |
| Module de contexte | contraintes injectées, politique de dimensionnement, objectif (critère de performance et critère de risque), adaptateur d'exécution par plateforme |

**Orchestrateur** : point d'entrée unique, commun aux contextes
(`Ressources_master/orchestrateur.py`). Il lit une spécification de run
(couche, contexte, couple ou portefeuille, plan, objectif, forme globale),
injecte à chaque couche les éléments du contexte, vérifie les contrats,
tient le journal des essais, le cache et l'envoi des résultats. Il ne contient
aucune logique métier d'un contexte.

**Interface de stratégie** : agnostique au contexte, dans le dossier de la
stratégie (`interface_<strat>.py`, versionnée avec elle), qui implémente un
protocole défini dans le cœur : identité, paramètres et axes de forme déclarés,
capacités, échantillons et données, production de la table de base à partir des
contraintes imposées. Aucun nom de contexte n'y figure ; une conversion propre à
un contexte vit dans le dossier de ce contexte. Un contexte qui exige une
capacité absente fait refuser le run ; on ne modifie pas la stratégie pour un
contexte.

**Témoin** (stratégie sans signal) : informatif, jamais un critère de
sélection ; capacité facultative de la stratégie, son absence n'arrête pas un
run.

Entre backtest et production (langages différents selon la plateforme), la
parité se contrôle par des **vecteurs de test communs** (jeu de barres fixe
et trades attendus) plutôt que par du code partagé.

## 7. Codes et registres

- Stratégie : colonne « Code » de `Ressources_master/registres/registre_strategies.md`.
- Actif : clés de `Propmaster/Backtest/propfirm/actifs.toml` pour un futures
  (déplacement prévu dans `Ressources_master/registres/`, ressource commune) ; section « Codes
  d'actifs » du même registre pour les autres.
- Contexte : section « Codes de contexte » du même registre (`GUN`, `PROP`,
  `FUT`).
- Couple et variante : `<CTX>-<STRAT>-<ACTIF>[-<MNÉMONIQUE>]`.
- **Registre des masters**, et **un registre par master et par couche** (un
  portefeuille dépend de son master). Emplacement : `Ressources_master/registres/`
  (à créer avec le premier master formalisé).

## 8. Cas dégénérés

Un portefeuille à un seul actif, ou un master à un seul portefeuille,
existent comme cas triviaux pour que l'identité reste uniforme.

## 9. Structure du dépôt Master

Décisions de Jérôme (2026-11-16) :

- Les projets de l’ancien dossier `Modeles/` (Gunmaster, Recherche, propfirm) sont fusionnés
  dans un dépôt unique, **`Master`**, à la racine de `Trading/Master/` (dossier renommé le 2026-11-17). Historiques
  conservés ; les anciens dépôts sont archivés en lecture seule.
- Un dossier par **contexte master** (`Gunmaster/`, `Propmaster/`,
  `Futurmaster/` à venir), chacun avec un espace backtest et un espace
  production. Chaque fichier appartient à un contexte.
- Le dossier `Recherche/` est **supprimé** : ses fichiers sont réaffectés aux
  contextes.
- Un dossier **`Ressources_master/`** réunit les ressources communes aux contextes :
  scripts d'accès aux données, registre des stratégies et ses règles, certains
  journaux, etc.
- **Chemins dynamiques** : partout où c'est possible, jamais de chemin codé en
  dur ni de remontée relative fragile ; la racine du dépôt, les dossiers de
  contexte, les données, les caches et les résultats se résolvent par un
  module unique de `Ressources_master/` et par des variables d'environnement
  (`TRADING_DATA_DIR`, `TRADING_CACHE_DIR`). Cela sert aussi les VPS.

Propositions validées par Jérôme (2026-11-16) et réalisées le 2026-11-17 :

- Un dossier `Strategies/` pour la couche 1 (spécification et détecteurs
  agnostiques du contexte), distinct de `Ressources_master/` ; Julian (contexte non
  défini) y vit. Les spécifications des autres stratégies restent à côté de
  leur moteur, sous `Propmaster/Backtest/` ou `Gunmaster/Backtest/`, jusqu'à
  ce qu'un second contexte réutilise la stratégie.
- Les skills et règles de méthode (recherche, backtest, audit de biais) à la
  racine de `Master` (`.cursor/skills`, `.claude/skills` lien relatif,
  `.claude/rules/00-master-general.md`), pour s'appliquer à tous les contextes.
- Migration en deux temps : fusion mécanique sans changer les dossiers (temps A),
  puis réaffectation par étapes avec `git mv`, tests verts à chaque étape
  (temps B : `Recherche/` et `propfirm/` réaffectés, dossier `Recherche/`
  supprimé le 2026-11-17).

Structure réalisée : `Gunmaster/` (dont `Backtest/Aw`, `Backtest/Sweep1`),
`Propmaster/Backtest/{propfirm,Retour1,Maret_MNQ,Fvg_MNQ}`,
`Ressources_master/` (`chemins.py`, `ohlcv_acces.py`, `resultats_acces.py`,
`stats_r.py`, `Indicateurs/`, `registres/`), `Strategies/Julian`.

Prévu (décisions de Jérôme, 2026-11-17, après la refonte du moteur propmaster) :
l'orchestrateur, le protocole d'interface de stratégie et le schéma de la table
de base dans `Ressources_master/` ; le moteur propmaster en paquet
`Propmaster/Backtest/Moteur/` (sous-dossiers `contexte/`, `couche2/`, `couche3/`,
`couche4/`), qui remplace `propfirm/` ; le contrat de contexte dans
`Propmaster/` ; `actifs.toml` dans `Ressources_master/registres/`.

## 10. Points ouverts

1. **Vecteurs de test communs** : format et premiers cas (stratégie MARET,
   FVG).
2. **Neutralisation des corrélations (couche 3)** : méthode au cas par cas,
   à généraliser si une méthode se dégage.
3. **Critères de validation par défaut** : à fixer une fois la base de
   référence constituée (§4).
4. **Registres des masters et des portefeuilles** : un registre par master
   et par couche, emplacement : `Ressources_master/registres/` (qui contient déjà le
   registre des stratégies) ; à créer avec le premier master formalisé.
5. **Protocole d'interface de stratégie et schéma de la table de base** : forme
   exacte, à fixer avec l'orchestrateur minimal (refonte propmaster, étapes 2
   et 3).
