# AGENTS.md — socle partagé (Regles_agents)

Fichier unique, partagé entre tous les projets (Cursor, Claude Code,
etc.), lié par symlink à la racine de chaque projet — ne contient que
du contenu **agnostique au projet**. Le contenu spécifique à un projet
donné vit dans ce projet (ex. `.cursor/rules/00-<projet>-general.mdc` /
`.claude/rules/00-<projet>-general.md`), jamais ici.

Toute modification de ce fichier s'applique immédiatement à tous les
projets qui le symlinkent — pas de copier-coller à répercuter.

## Contexte utilisateur

- Trader professionnel, style trading algorithmique.
  Outils : Amibroker (backtest AFL), Gunbot (exécution live), Claude
  (backtests), Cursor (développement).
- Connaissance intermédiaire en programmation : PHP, JavaScript, Python,
  AFL. Connaissance intermédiaire en administration système.
- Environnement de travail : alterne Linux et Windows. LibreOffice en
  anglais.
- Langue de travail par défaut : français (bonne maîtrise de l'anglais,
  connaissance moyenne du russe).

## Convention de nommage des fichiers

- Tous les fichiers de code, changelogs et règles sont nommés en
  **minuscule**.
- Piège cross-OS à connaître : un renommage qui ne change QUE la casse
  n'est pas fiable avec `git mv` sur un système de fichiers insensible à
  la casse (Windows/NTFS, macOS/APFS) — Git peut ne pas détecter le
  changement. Effectuer ce type de renommage depuis Linux (sensible à la
  casse) plutôt que Windows.

## Commits

- Avant tout `git commit` : présenter le message de commit proposé et
  attendre validation explicite de l'utilisateur avant de l'exécuter.
  Ne jamais lancer `git commit` directement sans cette étape.
- **Format du message** : en anglais, compact, une ligne par élément
  séparée par un point-virgule (`;`) — pas de paragraphe, pas de détail
  narratif. Le détail complet vit dans les changelogs du projet quand
  il en existe.
- **Ne jamais ajouter de ligne d'attribution `Co-Authored-By` (ou
  équivalente) dans le message de commit.**

## Scripts

- Tout script (shell, PowerShell, Python, etc.) doit être versionné dans
  git et accompagné d'un changelog dédié, colocalisé avec lui :
  `<nom_du_script>.changelog.md` (même nom de base que le script, en
  minuscule, cf. convention de nommage ci-dessus).
- Le changelog liste les entrées par ordre antéchronologique (la plus
  récente en premier), chacune datée (`AAAA-MM-JJ`) et décrivant le
  changement en une ligne concise. Langue : français (langue de travail
  par défaut), indépendamment de la langue anglaise des messages de
  commit.
- Toute modification fonctionnelle du script s'accompagne d'une entrée
  correspondante dans son changelog, dans le même commit.

## Portabilité Cursor / Claude Code

- Claude Code ne lit pas `AGENTS.md` nativement mais l'importe via un
  `CLAUDE.md` de projet (`@AGENTS.md`).
- Bug connu Cursor (non résolu à ce jour) : `AGENTS.md` peut être traité
  comme "requestable" plutôt que "toujours appliqué" quand le workspace
  est ouvert via un `.code-workspace` — vérifier si c'est le cas.
- Si un projet a des règles ciblées par dossier, leur double s'écrit
  `.cursor/rules/*.mdc` (frontmatter `globs`) côté Cursor et
  `.claude/rules/*.md` (frontmatter `paths`) côté Claude Code. Pas
  d'import fiable entre les deux formats à ce jour : dupliquer le
  contenu par paire de fichiers jumeaux, avec un pointeur croisé en tête
  de chaque fichier, et répercuter toute modification de fond dans les
  deux au même commit.
