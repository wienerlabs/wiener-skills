#!/bin/bash
# Kök dizindeki bütün git projelerinde son N günün commit'lerini toplar (yazar: sen).
# Aynı reponun worktree'leri tek proje sayılır.
#
# Kullanım: topla.sh [gün=7] [kök=~/Documents/GitHub]
set -uo pipefail

gun=${1:-7}
kok=${2:-$HOME/Documents/GitHub}
[ -d "$kok" ] || { echo "dizin yok: $kok"; exit 1; }

genel_eposta=$(git config --global user.email 2>/dev/null || true)
goruldu=""
toplam=0; proje_sayisi=0

baslangic=$(date -v-"$gun"d +%F)
echo "Aralık: son $gun gün ($baslangic'den beri) · Kök: $kok"

for git_yolu in "$kok"/*/.git "$kok"/*/*/.git; do
  [ -e "$git_yolu" ] || continue
  repo=$(dirname "$git_yolu")
  ortak=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
  grep -Fxq -- "$ortak" <<<"$goruldu" && continue
  goruldu="$goruldu"$'\n'"$ortak"

  yerel_eposta=$(git -C "$repo" config user.email 2>/dev/null || true)
  yazar=()
  [ -n "$genel_eposta" ] && yazar+=(--author="$genel_eposta")
  [ -n "$yerel_eposta" ] && [ "$yerel_eposta" != "$genel_eposta" ] && yazar+=(--author="$yerel_eposta")

  kayitlar=$(git -C "$repo" log --all --no-merges --since="$gun days ago" ${yazar[@]+"${yazar[@]}"} \
             --date=short --pretty='%ad %h %s' 2>/dev/null | sort -r | uniq)
  [ -n "$kayitlar" ] || continue

  n=$(wc -l <<<"$kayitlar" | tr -d ' ')
  toplam=$((toplam + n)); proje_sayisi=$((proje_sayisi + 1))
  ad=$(basename "$(dirname "$ortak")")
  dallar=$(git -C "$repo" for-each-ref --sort=-committerdate --format='%(committerdate:short) %(refname:short)' refs/heads 2>/dev/null |
           awk -v s="$baslangic" '$1 >= s {print $2}' | head -4 | tr '\n' ' ')
  echo
  echo "== $ad ($n commit) · aktif dallar: ${dallar:-?}"
  head -40 <<<"$kayitlar"
  [ "$n" -gt 40 ] && echo "... (+$((n - 40)) daha)"
done

echo
echo "TOPLAM: $proje_sayisi projede $toplam commit"
