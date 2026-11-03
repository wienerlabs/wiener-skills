#!/bin/bash
# Push öncesi değişiklik taraması: sızmış secret, debug kalıntısı, çakışma işareti, .env, büyük dosya, yeni TODO.
# Taban dala göre eklenen satırlara bakar (commit'lenmiş + commit'lenmemiş + izlenmeyen dosyalar).
#
# Kullanım: tara.sh [taban]   (varsayılan: origin/HEAD, yoksa origin/main, origin/master, main, master)
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "git deposu değil"; exit 1; }

taban=${1:-}
if [ -z "$taban" ]; then
  taban=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  for b in origin/main origin/master main master; do
    [ -n "$taban" ] && break
    git rev-parse -q --verify "$b" >/dev/null && taban=$b
  done
fi
mb=$(git merge-base HEAD "${taban:-HEAD}" 2>/dev/null || git rev-parse HEAD)
echo "Taban: ${taban:-?} ($(git rev-parse --short "$mb"))"

gecici=$(mktemp -d); trap 'rm -rf "$gecici"' EXIT
eklenen="$gecici/eklenen"

# dosya:satır: içerik
git diff "$mb" --unified=0 --no-color --no-ext-diff -- . \
    ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)*.min.js' ':(exclude)*.snap' |
  awk '/^\+\+\+ /{f=substr($0,7); next} /^@@/{split($3,a,","); n=substr(a[1],2); next} /^\+/{print f":"n": "substr($0,2); n++}' > "$eklenen"
git ls-files --others --exclude-standard | while IFS= read -r f; do
  [ -f "$f" ] && [ "$(wc -c < "$f")" -lt 1000000 ] && grep -Iq . "$f" 2>/dev/null && grep -n "" "$f" | sed "s|^|$f:|"
done >> "$eklenen"

bolum() {  # başlık, desen, [ek grep bayrağı]
  local sonuc
  sonuc=$(grep -E ${3:-} -- "$2" "$eklenen" | cut -c1-220)
  if [ -n "$sonuc" ]; then
    echo; echo "## $1 ($(wc -l <<<"$sonuc" | tr -d ' '))"
    head -20 <<<"$sonuc"
    [ "$(wc -l <<<"$sonuc")" -gt 20 ] && echo "... (+$(( $(wc -l <<<"$sonuc") - 20 )) daha)"
  fi
}

echo "Eklenen satır: $(wc -l < "$eklenen" | tr -d ' ')"
bolum "SECRET olabilir" 'AKIA[0-9A-Z]{16}|sk-(ant-|proj-|live_)?[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}["'"'"']' -i
bolum "Çakışma işareti" ': (<<<<<<<|>>>>>>>)( |$)|: =======$'
bolum "Debug kalıntısı" 'console\.(log|debug)\(|(^|[^a-zA-Z_])debugger;?([[:space:]]|$)|binding\.pry|var_dump\(|breakpoint\(\)|pdb\.set_trace|print_r\('
bolum "Yeni TODO/FIXME" '(TODO|FIXME|XXX|HACK)([[:space:]:(]|$)'

# Dosya düzeyi kontroller
degisen=$( { git diff --name-only "$mb"; git ls-files --others --exclude-standard; } | sort -u)
env_dosya=$(grep -E '(^|/)\.env(\.[a-z]+)?$' <<<"$degisen" | grep -vE '\.(example|sample|template)$' || true)
[ -n "$env_dosya" ] && { echo; echo "## .env dosyası değişmiş/eklenmiş"; echo "$env_dosya"; }
buyuk=$(while IFS= read -r f; do [ -f "$f" ] && s=$(wc -c < "$f") && [ "$s" -gt 1000000 ] && echo "$f ($(( s / 1024 )) KB)"; done <<<"$degisen")
[ -n "$buyuk" ] && { echo; echo "## 1 MB'tan büyük dosya"; echo "$buyuk"; }

echo; echo "Tarama bitti."
