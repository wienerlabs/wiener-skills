#!/bin/bash
# Skill'leri ~/.claude/skills altına kurar.
#
#   ./kur.sh            symlink ile kurar (repoyu güncelleyince skill'ler de güncellenir)
#   ./kur.sh --kopyala  dosyaları kopyalar
#   ./kur.sh --kaldir   bu repodan kurulmuş skill'leri kaldırır
#
# Aynı adda başka bir skill varsa silmez, yanına .yedek-<tarih> olarak taşır.
set -euo pipefail

kaynak="$(cd "$(dirname "$0")" && pwd)/skills"
hedef="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mod=${1:-}

case "$mod" in
  ""|--kopyala|--kaldir) ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac

if [ "$mod" = --kaldir ]; then
  for s in "$kaynak"/*/; do
    ad=$(basename "$s")
    if [ -L "$hedef/$ad" ] || [ -f "$hedef/$ad/.claude-skills-tr" ]; then
      rm -rf "$hedef/$ad"; echo "kaldırıldı: $ad"
    fi
  done
  exit 0
fi

mkdir -p "$hedef"
chmod +x "$kaynak"/*/scripts/*.sh

for s in "$kaynak"/*/; do
  s=${s%/}; ad=$(basename "$s")
  if [ -L "$hedef/$ad" ]; then
    rm "$hedef/$ad"
  elif [ -e "$hedef/$ad" ]; then
    if [ -f "$hedef/$ad/.claude-skills-tr" ]; then
      rm -rf "$hedef/$ad"
    else
      yedek="$hedef/$ad.yedek-$(date +%Y%m%d%H%M%S)"
      mv "$hedef/$ad" "$yedek"; echo "mevcut '$ad' yedeklendi: $yedek"
    fi
  fi
  if [ "$mod" = --kopyala ]; then
    cp -R "$s" "$hedef/$ad"; touch "$hedef/$ad/.claude-skills-tr"
  else
    ln -s "$s" "$hedef/$ad"
  fi
  echo "kuruldu: /$ad"
done

echo
eksik=0
for t in jq git python3 pmset caffeinate shasum; do
  command -v "$t" >/dev/null || { echo "Uyarı: '$t' bulunamadı."; eksik=1; }
done
command -v pdftotext >/dev/null || echo "İsteğe bağlı: pdftotext yok (brew install poppler). /analiz PDF'leri görsel okur, bu daha çok token harcar."
[ "$eksik" = 0 ] && echo "Bağımlılıklar tamam."
echo "Açık bir Claude Code oturumundaysan skill'leri görmek için /reload-skills yaz; yeni oturumlarda otomatik yüklenir."
