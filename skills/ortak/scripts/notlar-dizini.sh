#!/bin/bash
# Projenin not dizinini yazdırır, yoksa oluşturur.
#
# Notlar repo dışında, ~/.local/state/claude-notlar/<proje>-<kısa-hash>/ altında durur:
#   - git'e karışmaz, commit'lere sızmaz
#   - aynı reponun bütün worktree'leri aynı dizini paylaşır (anahtar, ana reponun yolu)
#
# Kullanım: notlar-dizini.sh [alt-dizin]
#   notlar-dizini.sh          -> .../claude-notlar/projem-3fa2c1
#   notlar-dizini.sh gece     -> .../claude-notlar/projem-3fa2c1/gece
set -euo pipefail

ortak=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || ortak=""
if [ -n "$ortak" ]; then
  kok=$(dirname "$ortak")   # .../proje/.git -> .../proje
else
  kok=$PWD
fi

anahtar="$(basename "$kok")-$(printf '%s' "$kok" | shasum | cut -c1-6)"
ana="$HOME/.local/state/claude-notlar/$anahtar"
mkdir -p "$ana"
[ -f "$ana/proje" ] || printf '%s\n' "$kok" > "$ana/proje"

dizin="$ana${1:+/$1}"
mkdir -p "$dizin"
printf '%s\n' "$dizin"
