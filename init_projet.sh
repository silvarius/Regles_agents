#!/usr/bin/env bash
# Symlink relatif AGENTS.md du projet cible vers le socle partage
# Regles_agents/AGENTS.md. Jumeau de init_projet.ps1 (meme comportement,
# cote Linux/macOS).
#
# Usage : ./init_projet.sh [chemin_du_projet]
#   (par defaut : repertoire courant)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${1:-$(pwd)}"

SHARED_AGENTS="$SCRIPT_DIR/AGENTS.md"
TARGET_AGENTS="$PROJECT_PATH/AGENTS.md"

if [ ! -f "$SHARED_AGENTS" ]; then
    echo "Erreur : fichier source introuvable : $SHARED_AGENTS" >&2
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Erreur : dossier projet introuvable : $PROJECT_PATH" >&2
    exit 1
fi

# Hook commit-msg (refuse les messages avec Co-Authored-By) : source dans
# Outils/hooks/commit-msg. Hooks locaux, donc a reinstaller apres chaque clone.
HOOK_SRC="$SCRIPT_DIR/../Outils/hooks/commit-msg"
if [ -f "$HOOK_SRC" ] && hook_dest="$(git -C "$PROJECT_PATH" rev-parse --git-path hooks/commit-msg 2>/dev/null)"; then
    case "$hook_dest" in /*) ;; *) hook_dest="$PROJECT_PATH/$hook_dest" ;; esac
    mkdir -p "$(dirname "$hook_dest")" && cp "$HOOK_SRC" "$hook_dest" && chmod +x "$hook_dest" \
        && echo "Hook commit-msg installe : $hook_dest"
fi

if [ -e "$TARGET_AGENTS" ] || [ -L "$TARGET_AGENTS" ]; then
    if [ -L "$TARGET_AGENTS" ]; then
        echo "AGENTS.md est deja un symlink dans $PROJECT_PATH - rien a faire."
        exit 0
    else
        echo "Erreur : $TARGET_AGENTS existe deja et n'est PAS un symlink. Suppression manuelle requise avant de relancer ce script (pour eviter d'ecraser du contenu specifique au projet)." >&2
        exit 1
    fi
fi

symlinks_config="$(git config --get core.symlinks || true)"
if [ "$symlinks_config" != "true" ]; then
    echo "Avertissement : git config core.symlinks n'est pas a 'true' (valeur actuelle : '${symlinks_config:-<non definie>}')." >&2
    echo "Sans ce reglage, Git peut stocker ce symlink comme un fichier texte ordinaire" >&2
    echo "et le lien sera casse au clone/checkout (Windows comme Linux)." >&2
    echo "Corriger avec : git config --global core.symlinks true (puis re-cloner le repo)." >&2
    echo "" >&2
fi

# Chemin relatif de SHARED_AGENTS par rapport a PROJECT_PATH, pour un
# symlink portable entre machines/utilisateurs et entre Windows/Linux
# (sous reserve que core.symlinks=true des deux cotes).
relative_agents="$(realpath --relative-to="$PROJECT_PATH" "$SHARED_AGENTS")"

ln -s "$relative_agents" "$TARGET_AGENTS"
echo "OK : $TARGET_AGENTS -> $relative_agents"
