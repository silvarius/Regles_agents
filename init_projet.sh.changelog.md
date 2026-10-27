# Changelog — init_projet.sh

## 2026-10-27

- Installe le hook `commit-msg` (`Outils/hooks/commit-msg`) dans le dépôt
  du projet cible : refuse les messages portant `Co-Authored-By`. Fait
  avant les sorties anticipées, donc aussi quand `AGENTS.md` est déjà un
  symlink.

## 2026-09-22

- Création du script : jumeau Linux/macOS de `init_projet.ps1`, même
  comportement (symlink relatif de `AGENTS.md` du projet cible vers le
  socle partagé `Regles_agents/AGENTS.md`, avertissement si
  `core.symlinks` n'est pas activé).
