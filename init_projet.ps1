<#
.SYNOPSIS
  Symlink AGENTS.md du projet cible vers le fichier partage Regles_agents/AGENTS.md.
.PARAMETER ProjectPath
  Chemin du projet a initialiser. Par defaut : repertoire courant.
.EXAMPLE
  .\init_projet.ps1 -ProjectPath "C:\...\NouveauProjet"
#>
param(
    [string]$ProjectPath = (Get-Location).Path
)

$SharedAgents = Join-Path $PSScriptRoot "AGENTS.md"
$TargetAgents = Join-Path $ProjectPath "AGENTS.md"

if (-not (Test-Path $SharedAgents)) {
    Write-Error "Fichier source introuvable : $SharedAgents"
    exit 1
}

if (-not (Test-Path $ProjectPath)) {
    Write-Error "Dossier projet introuvable : $ProjectPath"
    exit 1
}

if (Test-Path $TargetAgents) {
    $existing = Get-Item $TargetAgents -Force
    if ($existing.LinkType -eq "SymbolicLink") {
        Write-Host "AGENTS.md est deja un symlink dans $ProjectPath - rien a faire."
        exit 0
    } else {
        Write-Error "$TargetAgents existe deja et n'est PAS un symlink. Suppression manuelle requise avant de relancer ce script (pour eviter d'ecraser du contenu specifique au projet)."
        exit 1
    }
}

# New-Item -ItemType SymbolicLink exige l'elevation meme mode
# Developpeur actif (limitation connue de Windows PowerShell 5.1) -
# on passe par "cmd /c mklink", qui respecte correctement le mode
# Developpeur.
$mklinkOutput = cmd /c mklink "`"$TargetAgents`"" "`"$SharedAgents`"" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Echec de creation du symlink (mklink) : $mklinkOutput"
    Write-Host ""
    Write-Host "Cause probable : mode Developpeur Windows desactive."
    Write-Host "Activer : Parametres Windows > Confidentialite et securite > Pour les developpeurs > Mode developpeur."
    exit 1
}
Write-Host "OK : $TargetAgents -> $SharedAgents"
