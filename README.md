---
title: "README — Setup Claude Code"
author: "Anta NDAO et Mame Diarra NDIAYE — ISEP 2"
date: "`r Sys.Date()`"
output:
  pdf_document:
    toc: true
  html_document:
    toc: true
    toc_float: true
    theme: flatly
    highlight: tango
subtitle: 'TP3 : Élevage Pastoral — Statistiques Agricoles'
---

---

## 1. Installation de Claude Code

**Version :** Claude Code (dernière version stable)  
**Système :** Windows 11, VS Code

**Étapes :**

1. Ouvrir VS Code
2. Aller dans Extensions (`Ctrl+Shift+X`)
3. Chercher **Claude Code** et installer
4. Se connecter avec un compte Anthropic
5. Claude Code apparaît dans la barre latérale de VS Code

---

## 2. Structure du projet

```
tp3-elevage/
  data/
    raw/          # données brutes (famille_troupeau.dta)
    cleaned/      # bases nettoyées exportées par R
  scripts/
    cleaning_commented.do      # version commentée et critique
    emigration_cleaning.do     # sous-script émigration
    Analysis.do                # analyses statistiques
  output/                      # tableaux et graphiques
  README.md
  Prompts_journal.Rmd
  Critique_cleaning.Rmd
```

---

## 3. Reproduire l'analyse de A à Z

**Étape 1 — Cloner le dépôt GitHub**

```bash
git clone https://github.com/VOTRE-COMPTE/tp3-elevage-pastoral.git
cd tp3-elevage-pastoral
code .
```

**Étape 2 — Modifier le chemin racine**

Dans `scripts/cleaning_commented.do`, changer **uniquement** cette ligne :

```stata
global root "C:/VOTRE/CHEMIN/tp3-elevage"
```

**Étape 3 — Exécuter les scripts dans l'ordre**

```
cleaning_commented.do  →  Analysis.do
```

Les résultats se trouvent dans `output/`.

---

## 4. Difficultés rencontrées et solutions

| Problème | Solution |
|----------|----------|
| Commandes Unix (`mkdir`, `touch`) ne fonctionnent pas sur PowerShell | Utiliser `New-Item` et `mkdir` séparément |
| Espaces dans les chemins de fichiers | Entourer les chemins de guillemets simples `' '` |
| Fichier nommé `1. cleaning.do` avec espace | `Rename-Item "1. cleaning.do" "cleaning.do"` |
| Contenu collé dans le terminal au lieu du fichier | Utiliser `code .gitignore` pour éditer dans VS Code |
| Double dossier `tp3-elevage/tp3-elevage` créé par erreur | Structure conservée telle quelle, sans impact sur le code |
| Variables globales `inputfile`, `data`, `codes` non définies | Ajout d'un bloc `global root` en tête du script |
