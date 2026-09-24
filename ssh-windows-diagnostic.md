# Diagnostic SSH/git sur Windows

Référencé depuis `AGENTS.md` (section "Diagnostic SSH sous Windows") et
depuis la skill Claude Code `git-ssh-windows-diagnostic`
(`~/.claude/skills/git-ssh-windows-diagnostic/SKILL.md`). Ne s'applique
qu'à Windows.

## Pourquoi

Sur une machine Windows, deux mondes SSH coexistent souvent sans le savoir
l'un de l'autre :

1. **Git Bash** (MSYS2) a son propre binaire `ssh` et son propre agent SSH
   (via `SSH_AUTH_SOCK`, socket Unix). C'est ce `ssh` qui répond quand on
   tape `ssh -T git@github.com` depuis un terminal Bash.
2. **Windows OpenSSH natif** (`C:\Windows\System32\OpenSSH\ssh.exe`) a son
   propre service agent (`ssh-agent`, service Windows, pipe nommé
   `\\.\pipe\openssh-ssh-agent`). Des clés peuvent y être chargées et
   déverrouillées indépendamment de Git Bash.

`git` lui-même n'utilise ni l'un ni l'autre par défaut : il utilise le SSH
indiqué par `core.sshCommand` (global ou local), qui sur beaucoup de postes
Windows pointe vers l'OpenSSH natif — donc vers l'agent Windows, pas celui
de Git Bash.

Conséquence concrète déjà rencontrée : tester `ssh -T git@github.com` dans
Git Bash renvoie "Permission denied (publickey)" parce que Git Bash ne voit
pas la clé chargée dans l'agent Windows — alors que `git push`/`git
ls-remote` avec ce même remote fonctionnent sans problème, puisqu'ils
passent par `core.sshCommand`. Diagnostiquer avec le mauvais outil mène à
croire (à tort) qu'il faut générer ou ajouter une nouvelle clé SSH, alors
que l'authentification est déjà fonctionnelle.

## Procédure de diagnostic (dans cet ordre)

1. **Vérifier quel SSH git utilise réellement** avant toute hypothèse :
   ```
   git config --get core.sshCommand
   git config --global --get core.sshCommand
   ```
   Si une valeur pointe vers `OpenSSH\ssh.exe` (ou tout autre client que le
   `ssh` de Git Bash), c'est CE client-là qui fait foi, pas celui de Git
   Bash.

2. **Tester la connectivité via git, pas via `ssh` brut** :
   ```
   git ls-remote <url-du-remote>
   ```
   `git ls-remote` respecte `core.sshCommand` et donne donc un diagnostic
   fiable de ce que `git push`/`pull`/`clone` feront réellement. Un
   `ssh -T git@github.com` lancé depuis Git Bash n'est PAS un test fiable
   sur Windows tant que `core.sshCommand` n'a pas été vérifié à l'étape 1
   — un échec là-bas ne prouve rien sur la capacité réelle de git à se
   connecter.

3. **Si `git ls-remote`/`git push` échoue réellement**, alors seulement
   creuser côté agent Windows (PowerShell) :
   ```
   Get-Service ssh-agent | Select-Object Status,StartType
   ssh-add -l
   ```
   `Get-Service` confirme que le service tourne (`Running`/`Automatic`) et
   `ssh-add -l` liste les clés déjà chargées et déverrouillées dans cet
   agent — une clé peut déjà y être présente sans que Git Bash ne la voie
   jamais.

4. **Ne conclure à un besoin de nouvelle clé SSH ou de reconfiguration
   qu'après avoir épuisé les étapes 1 à 3.** Si une clé apparaît dans
   `ssh-add -l` avec une empreinte qui correspond à une clé publique
   connue (`ssh-keygen -lf <fichier>.pub`), c'est probablement déjà la
   bonne clé, déjà acceptée par le serveur (GitHub/GitLab/...) — le
   blocage n'est pas une absence de clé mais un problème d'outil de
   diagnostic.

## Ce qu'il ne faut PAS faire

- Ne pas tester la connectivité avec `ssh -T` depuis Git Bash en premier
  réflexe sur Windows : ce test peut donner un faux négatif.
- Ne pas proposer de générer une nouvelle paire de clés avant d'avoir
  regardé `core.sshCommand` et `ssh-add -l` (agent Windows).
- Ne pas supposer que l'environnement Bash (Git Bash) et l'environnement
  PowerShell partagent le même agent SSH sur Windows — ce n'est pas
  garanti, et sur ce type de poste ils sont typiquement distincts.

## Hors-scope

Cette procédure ne s'applique qu'à Windows. Sur macOS/Linux, il n'y a
généralement qu'un seul agent SSH pertinent (`ssh-agent` POSIX ou
intégration Keychain/gnome-keyring), donc ce problème de double-agent
n'existe pas — un `ssh -T` classique y est un diagnostic fiable.
