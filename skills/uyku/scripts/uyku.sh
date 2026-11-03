#!/bin/bash
# /uyku yardımcı komutları. Her session'ın durumu: ~/.local/state/claude-uyku/<session_id>/
#
#   uyku.sh baslat <sid> <bitis HH:MM> <pil%> <limit5s%> <haftalik%> <rapor_yolu>
#   uyku.sh durum <sid> [yeni_durum]          durumu oku / değiştir
#   uyku.sh kullanim <sid> <5s%> <haftalik%> [5s_sifirlanma_ISO]
#                                             kaydeder ve DEVAM / BEKLE / KAPAT yazar
#   uyku.sh gorev-bitti <sid>                 uyarı sayacını sıfırlar
#   uyku.sh bekle <sid> <uyanis_ISO|epoch>    5 saatlik limit beklemesi
#   uyku.sh kapat <sid> <neden>               kapanışa geçir (rapor tamamlanıp durulur)
#   uyku.sh bitir <sid>                       uyku modunu kapat (sabah)
#   uyku.sh pil                               "AC 85" | "PIL 43" | "YOK"
#   uyku.sh goster <sid>
#   uyku.sh bul                               bu projenin uyku kayıtları, en yeni önce
#
# Durumlar: calisiyor | bekliyor | kapanis | bitti | takildi | hata | deneme
set -euo pipefail

KOK="$HOME/.local/state/claude-uyku"
komut=${1:-}
[ $# -gt 0 ] && shift

dizin() {
  [ -n "${1:-}" ] || { echo "session id gerekli" >&2; exit 1; }
  echo "$KOK/$1"
}
log() { echo "$(date '+%F %T') $2" >> "$1/log"; }
saat() { date -r "$1" '+%H:%M'; }

proje_kok() {
  local o
  if o=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then dirname "$o"; else pwd; fi
}

# HH:MM -> o saatin bir sonraki gelişinin epoch'u
saat_epoch() {
  local hedef
  hedef=$(date -j -f '%Y-%m-%d %H:%M' "$(date +%F) $1" +%s)
  [ "$hedef" -le "$(date +%s)" ] && hedef=$((hedef + 86400))
  echo "$hedef"
}

# ISO-8601 (Z/ofset, milisaniyeli olabilir) ya da epoch -> epoch
iso_epoch() {
  case "$1" in
    *[!0-9]*) python3 -c 'import sys,datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1].replace("Z","+00:00")).timestamp()))' "$1" ;;
    *) echo "$1" ;;
  esac
}

pil() {
  local p y
  p=${UYKU_PMSET:-$(pmset -g batt 2>/dev/null || true)}
  y=$(grep -oE '[0-9]+%' <<<"$p" | head -1 | tr -d % || true)
  if [ -z "$y" ]; then echo "YOK"
  elif grep -q "Battery Power" <<<"$p"; then echo "PIL $y"
  else echo "AC $y"; fi
}

goster() {
  local d=$1
  [ -d "$d" ] || { echo "kayit-yok"; return; }
  echo "durum:     $(cat "$d/durum")"
  echo "bitiş:     $(saat "$(cat "$d/bitis")") · pil eşiği: %$(cat "$d/pil_esik") (sadece pildeyken) · 5 saatlik: %$(cat "$d/limit5s") · haftalık tavan: %$(cat "$d/haftalik")"
  echo "pil:       $(pil)"
  echo "kullanım:  ilk $(cat "$d/ilk_kullanim" 2>/dev/null || echo -) · son $(cat "$d/kullanim" 2>/dev/null || echo -)"
  echo "görev:     $(cat "$d/tamamlanan" 2>/dev/null || echo 0) tamamlandı · uyarı sayacı $(cat "$d/engel" 2>/dev/null || echo 0)/3"
  echo "rapor:     $(cat "$d/rapor")"
  echo "proje:     $(cat "$d/proje")"
  [ -f "$d/neden" ] && echo "neden:     $(cat "$d/neden")"
  echo "--- son kayıtlar ---"; tail -5 "$d/log" 2>/dev/null || true
}

case "$komut" in
  baslat)
    d=$(dizin "${1:-}")
    rapor=${6:?rapor yolu gerekli}
    find "$KOK" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "$d"
    rm -f "$d/neden" "$d/ilk_kullanim" "$d/kullanim" "$d/son_kontrol" "$d/sifirlanma" "$d/uyanis" "$d/bekleme.pid"
    saat_epoch "${2:-08:00}" > "$d/bitis"
    echo "${3:-27}" > "$d/pil_esik"
    echo "${4:-80}" > "$d/limit5s"
    echo "${5:-60}" > "$d/haftalik"
    echo "$rapor" > "$d/rapor"
    proje_kok > "$d/proje"
    date +%s > "$d/baslangic"
    echo 0 > "$d/engel"; echo 0 > "$d/tamamlanan"; echo 0 > "$d/yeniden"
    echo calisiyor > "$d/durum"
    log "$d" "başladı · bitiş $(saat "$(cat "$d/bitis")") · pil %${3:-27} · 5s %${4:-80} · haftalık %${5:-60}"
    goster "$d"
    ;;

  durum)
    d=$(dizin "${1:-}")
    [ -d "$d" ] || { echo "kayit-yok"; exit 0; }
    if [ -n "${2:-}" ]; then
      echo "$2" > "$d/durum"
      [ "$2" = calisiyor ] && { echo 0 > "$d/engel"; rm -f "$d/neden"; }
      log "$d" "durum=$2"
    fi
    cat "$d/durum"
    ;;

  kullanim)
    d=$(dizin "${1:-}")
    b=${2:?5 saatlik yüzde gerekli}; h=${3:?haftalık yüzde gerekli}
    b=${b%%.*}; h=${h%%.*}
    echo "5s %$b · haftalık %$h ($(date '+%H:%M'))" > "$d/kullanim"
    [ -f "$d/ilk_kullanim" ] || cp "$d/kullanim" "$d/ilk_kullanim"
    date +%s > "$d/son_kontrol"
    [ -n "${4:-}" ] && iso_epoch "$4" > "$d/sifirlanma"
    log "$d" "kullanım 5s=%$b haftalık=%$h"
    if [ "$h" -ge "$(cat "$d/haftalik")" ]; then echo "KAPAT: haftalık kullanım %$h, tavan %$(cat "$d/haftalik")"
    elif [ "$b" -ge "$(cat "$d/limit5s")" ]; then echo "BEKLE: 5 saatlik kullanım %$b, eşik %$(cat "$d/limit5s")"
    else echo "DEVAM"; fi
    ;;

  gorev-bitti)
    d=$(dizin "${1:-}")
    echo 0 > "$d/engel"
    echo $(( $(cat "$d/tamamlanan" 2>/dev/null || echo 0) + 1 )) > "$d/tamamlanan"
    [ "$(cat "$d/durum")" = takildi ] && echo calisiyor > "$d/durum"
    log "$d" "görev bitti (toplam $(cat "$d/tamamlanan"))"
    cat "$d/durum"
    ;;

  bekle)
    d=$(dizin "${1:-}")
    u=$(( $(iso_epoch "${2:?uyanış zamanı gerekli}") + 120 ))
    simdi=$(date +%s); bitis=$(cat "$d/bitis")
    if [ "$u" -ge "$bitis" ]; then
      echo "KAPAT: limitin sıfırlanma saati $(saat "$u"), bitiş saati $(saat "$bitis"). Beklemeye değmez; 'uyku.sh kapat' ile kapanışa geç."
      exit 0
    fi
    sure=$(( u - simdi )); [ "$sure" -lt 60 ] && sure=60
    echo bekliyor > "$d/durum"; echo "$u" > "$d/uyanis"
    log "$d" "bekleme $(saat "$simdi") → $(saat "$u")"
    echo "BEKLE: uyanış saati $(saat "$u"). Şu komutu Bash ile run_in_background: true olarak çalıştır, sonra turu bitir:"
    echo "echo \$\$ > '$d/bekleme.pid' && exec caffeinate -i -t $sure"
    ;;

  kapat)
    d=$(dizin "${1:-}")
    echo kapanis > "$d/durum"; echo "${2:-belirtilmedi}" > "$d/neden"
    log "$d" "kapanış: ${2:-belirtilmedi}"
    echo kapanis
    ;;

  bitir)
    d=$(dizin "${1:-}")
    [ -d "$d" ] || { echo "kayit-yok"; exit 0; }
    if [ -f "$d/bekleme.pid" ]; then
      p=$(cat "$d/bekleme.pid")
      ps -p "$p" -o comm= 2>/dev/null | grep -q caffeinate && kill "$p" 2>/dev/null || true
      rm -f "$d/bekleme.pid"
    fi
    onceki=$(cat "$d/durum")
    echo bitti > "$d/durum"
    log "$d" "bitirildi (önceki durum: $onceki)"
    echo "önceki durum: $onceki"
    goster "$d"
    ;;

  pil) pil ;;

  goster) goster "$(dizin "${1:-}")" ;;

  bul)
    p=$(proje_kok)
    [ -d "$KOK" ] || exit 0
    ls -t "$KOK" | while read -r s; do
      [ "$(cat "$KOK/$s/proje" 2>/dev/null)" = "$p" ] || continue
      echo "$s · $(cat "$KOK/$s/durum") · başladı $(date -r "$(cat "$KOK/$s/baslangic")" '+%F %H:%M') · rapor: $(cat "$KOK/$s/rapor")$( [ -f "$KOK/$s/neden" ] && echo " · neden: $(cat "$KOK/$s/neden")")"
    done | head -5
    ;;

  *)
    sed -n '2,16p' "$0"; exit 1 ;;
esac
