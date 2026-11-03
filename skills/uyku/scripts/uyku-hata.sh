#!/bin/bash
# /uyku StopFailure hook'u (asyncRewake ile çalışır): tur bir API hatasıyla biterse
# geçici hatalarda bekleyip Claude'u yeniden uyandırır; kalıcı hatalarda durumu 'hata' yapar.
#
# Bekleme süresi:  overloaded / server_error / unknown -> 5 dk
#                  rate_limit -> bilinen sıfırlanma zamanı + 2 dk (bilinmiyorsa 30 dk)
#                  max_output_tokens -> hemen
# Gece boyunca en fazla 5 kez uyandırır. Bekleme bitiş saatini aşacaksa uyandırmaz.

KOK="$HOME/.local/state/claude-uyku"
[ -d "$KOK" ] || exit 0

girdi=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$girdi" 2>/dev/null)
d="$KOK/$sid"
[ -n "$sid" ] && [ -f "$d/durum" ] || exit 0
case $(cat "$d/durum") in calisiyor|bekliyor) ;; *) exit 0 ;; esac

hata=$(jq -r '.error // "unknown"' <<<"$girdi")
detay=$(jq -r '.error_details // ""' <<<"$girdi" | head -c 300)
simdi=$(date +%s)
log() { echo "$(date '+%F %T') hata: $*" >> "$d/log"; }

kalici() {
  echo hata > "$d/durum"; echo "API hatası: $hata $detay" > "$d/neden"
  log "$hata (kalıcı) — uyku modu durdu"
  exit 0
}

case "$hata" in
  overloaded|server_error|unknown) sure=300 ;;
  max_output_tokens) sure=5 ;;
  rate_limit)
    sif=$(cat "$d/sifirlanma" 2>/dev/null || echo 0)
    if [ "$sif" -gt "$simdi" ]; then sure=$(( sif - simdi + 120 )); else sure=1800; fi ;;
  *) kalici ;;
esac

sure=${UYKU_TEST_SURE:-$sure}   # yalnızca testler için

yeniden=$(( $(cat "$d/yeniden" 2>/dev/null || echo 0) + 1 ))
[ "$yeniden" -gt 5 ] && kalici
bitis=$(cat "$d/bitis" 2>/dev/null || echo 0)
[ $(( simdi + sure )) -ge "$bitis" ] && kalici
echo "$yeniden" > "$d/yeniden"

log "$hata — $(( sure / 60 )) dk sonra uyandırılacak ($yeniden/5)"
caffeinate -i -t "$sure" 2>/dev/null || sleep "$sure"

# Beklerken sabah olduysa ya da biri uyku modunu kapattıysa uyandırma
case $(cat "$d/durum") in calisiyor|bekliyor) ;; *) exit 0 ;; esac
echo calisiyor > "$d/durum"; echo 0 > "$d/engel"
log "uyandırıldı"
echo "Uyku modu: önceki tur API hatasıyla ($hata) bitti, bekleyip seni yeniden uyandırdım. Kullanımı kontrol et ('$(cd "$(dirname "$0")" && pwd)/uyku.sh kullanim $sid ...'), sabah raporuna kısa bir not düş ve kuyruktan devam et. $( [ "$hata" = max_output_tokens ] && echo 'Çıktı sınırına takıldın: daha küçük adımlarla, daha kısa yanıtlarla ilerle.')" >&2
exit 2
