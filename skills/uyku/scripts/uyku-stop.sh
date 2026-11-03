#!/bin/bash
# /uyku Stop hook'u: uyku modu açıkken Claude'un turu erken bitirmesini engeller.
#
# Sadece bu session için /uyku başlatıldıysa ve durum 'calisiyor' ya da 'bekliyor' ise devreye girer;
# diğer her durumda hiçbir şey yazmadan çıkar (normal çalışmayı etkilemez).
#
# Durmaya izin verir:  bitiş saati / pil eşiği (önce bir kez "kapanış" talimatı verir),
#                      arka planda subagent ya da limit beklemesi (caffeinate) çalışıyorsa,
#                      ilerleme olmadan art arda 3 uyarıdan sonra (takıldı sayılır).
# Test: UYKU_PMSET ortam değişkeni pmset çıktısının yerine geçer.

KOK="$HOME/.local/state/claude-uyku"
[ -d "$KOK" ] || exit 0

girdi=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$girdi" 2>/dev/null)
d="$KOK/$sid"
[ -n "$sid" ] && [ -f "$d/durum" ] || exit 0

durum=$(cat "$d/durum")
simdi=$(date +%s)
U="$(cd "$(dirname "$0")" && pwd)/uyku.sh"

log() { echo "$(date '+%F %T') stop: $*" >> "$d/log"; }
soyle() { jq -nc --arg m "$1" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'; }

devam_ettir() {
  local n
  n=$(( $(cat "$d/engel" 2>/dev/null || echo 0) + 1 ))
  if [ "$n" -gt 3 ]; then
    echo takildi > "$d/durum"
    log "3 uyarıdan sonra ilerleme yok, durmasına izin verildi (takildi)"
    exit 0
  fi
  echo "$n" > "$d/engel"
  log "devam ettirildi ($n/3)"
  soyle "$1 (Uyarı $n/3 — ilerleme olmadan 3 kez durmaya çalışırsan uyku modu kendiliğinden kapanır.)"
  exit 0
}

kapanisa_gec() {
  echo kapanis > "$d/durum"; echo "$1" > "$d/neden"
  log "kapanış: $1"
  soyle "UYKU MODU KAPANIŞI — $1. Yeni göreve başlama. Yarım iş çalışır durumdaysa commit et; değilse commit etme, rapora yarım olarak yaz. Sabah raporunu son haline getir (durma nedeni ve son kullanım dahil), kısa bir özet yaz ve dur."
  exit 0
}

case "$durum" in
  deneme)
    echo bitti > "$d/durum"; log "deneme"
    soyle "Uyku hook testi: hook çalışıyor. Sadece UYKU-HOOK-OK yaz ve dur."
    exit 0 ;;
  kapanis)
    echo bitti > "$d/durum"; log "bitti"
    exit 0 ;;
  calisiyor|bekliyor) ;;
  *) exit 0 ;;
esac

# Bitiş saati
bitis=$(cat "$d/bitis" 2>/dev/null || echo 0)
[ "$bitis" -gt 0 ] && [ "$simdi" -ge "$bitis" ] && kapanisa_gec "bitiş saati geldi ($(date -r "$bitis" '+%H:%M'))"

# Pil (sadece pildeyken)
read -r kaynak yuzde <<<"$("$U" pil)"
esik=$(cat "$d/pil_esik" 2>/dev/null || echo 27)
[ "$kaynak" = PIL ] && [ "$yuzde" -le "$esik" ] && kapanisa_gec "pil %$yuzde (eşik %$esik)"

alt_ajan=$(jq '[.background_tasks[]? | select(.type == "subagent")] | length' <<<"$girdi" 2>/dev/null || echo 0)
bekleme=$(jq '[.background_tasks[]? | select(.type == "shell" and ((.command // "") | test("caffeinate")))] | length' <<<"$girdi" 2>/dev/null || echo 0)

if [ "$durum" = bekliyor ]; then
  if [ "$bekleme" -gt 0 ]; then log "limit beklemesi sürüyor"; exit 0; fi
  devam_ettir "Durum 'bekliyor' ama arka planda bekleme komutu (caffeinate) çalışmıyor. Bekleme bittiyse: '$U durum $sid calisiyor', kullanımı kontrol et ve kuyruktan devam et. Hâlâ beklemen gerekiyorsa '$U bekle' çıktısındaki komutu run_in_background ile çalıştır."
fi

# calisiyor
if [ "$alt_ajan" -gt 0 ]; then log "subagent bekleniyor"; exit 0; fi

hatirlatma=""
son=$(cat "$d/son_kontrol" 2>/dev/null || echo 0)
[ $(( simdi - son )) -gt 1800 ] && hatirlatma=" Kullanım kontrolü 30 dakikadan eski: önce get_usage ile kontrol edip '$U kullanim $sid <5s> <haftalık> <sıfırlanma>' çalıştır."

devam_ettir "Uyku modu açık; turu bitirme. Kuyruktaki sıradaki göreve geç (kritik kararları rapora yazıp atla).$hatirlatma Kuyruk gerçekten bittiyse '$U kapat $sid \"kuyruk bitti\"' çalıştır, raporu tamamla ve dur."
