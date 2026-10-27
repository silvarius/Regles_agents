# Changelog — init_projet.ps1

## 2026-10-27

- Installe le hook `commit-msg` (`Outils\hooks\commit-msg`) dans le dépôt
  du projet cible : refuse les messages portant `Co-Authored-By`. Fait
  avant les sorties anticipées, donc aussi quand `AGENTS.md` est déjà un
  symlink. Non testé sous Windows.

## 2026-09-22

- Le symlink créé est désormais **relatif** (au lieu d'un chemin
  absolu Windows) : portable entre machines/utilisateurs et
  compatible avec un checkout Linux du même repo (sous réserve de
  `core.symlinks=true`). Ajout d'un avertissement si `core.symlinks`
  n'est pas activé. Voir jumeau `init_projet.sh` pour Linux/macOS.
- Création du script : symlink de `AGENTS.md` du projet cible vers le
  socle partagé `Regles_agents/AGENTS.md`.
