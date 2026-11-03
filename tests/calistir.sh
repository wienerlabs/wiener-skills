#!/bin/bash
# Script testleri. Gerçek ~/.local/state dizinine dokunmaz: geçici bir HOME kullanır.
# Kullanım: ./tests/calistir.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SK="$REPO/skills"
U="$SK/uyku/scripts"
GECICI=$(mktemp -d); trap 'rm -rf "$GECICI"' EXIT
export HOME="$GECICI/home"; mkdir -p "$HOME"
AC=$'Now drawing from \'AC Power\'\n -InternalBattery-0 (id=1)\t20%; charging;'
PIL=$'Now drawing from \'Battery Power\'\n -InternalBattery-0 (id=1)\t20%; discharging;'
export UYKU_PMSET="$AC"

basari=0; hata=0
ok() {
  if [ "$2" = "$3" ]; then basari=$((basari + 1)); printf '  ✓ %s\n' "$1"
  else hata=$((hata + 1)); printf '  ✗ %s\n      beklenen: %s\n      gelen:    %s\n' "$1" "$3" "$2"; fi
}
icerir() { case "$2" in *"$3"*) ok "$1" x x ;; *) ok "$1" "$(head -c 160 <<<"$2")" "…$3…" ;; esac; }
bolum() { printf '\n%s\n' "$1"; }

D() { echo "$HOME/.local/state/claude-uyku/$1"; }
stop() {
  local ek=${2:-}; [ -n "$ek" ] || ek='{}'
  jq -nc --arg s "$1" --argjson e "$ek" '{session_id: $s, hook_event_name: "Stop", stop_hook_active: false} + $e' |
    "$U/uyku-stop.sh" | jq -r '.hookSpecificOutput.additionalContext // ""'
}
karar() {
  jq -nc --arg s "$1" --arg t "$2" --arg c "$3" '{session_id: $s, hook_event_name: "PreToolUse", tool_name: $t, tool_input: {command: $c}}' |
    "$U/uyku-koruma.sh" | grep -q '"deny"' && echo engel || echo izin
}
sonra() { echo $(( $(date +%s) + $1 )); }

# ---------------------------------------------------------------------------
bolum "Sözdizimi ve frontmatter"
for f in "$SK"/*/scripts/*.sh "$REPO/kur.sh"; do
  bash -n "$f" 2>/dev/null; ok "bash -n $(basename "$f")" $? 0
done
for f in "$SK"/*/SKILL.md; do
  ad=$(basename "$(dirname "$f")")
  ok "$ad: name alanı klasör adıyla aynı" "$(awk '/^---$/{n++; next} n==1 && /^name:/{print $2; exit}' "$f")" "$ad"
  grep -q '^description: .\{20,\}' "$f"; ok "$ad: description var" $? 0
done

# ---------------------------------------------------------------------------
bolum "uyku.sh"
S=test-uyku
"$U/uyku.sh" baslat $S 23:59 27 80 60 "$GECICI/rapor.md" >/dev/null
sonra 10800 > "$(D $S)/bitis"
ok "baslat → calisiyor" "$(cat "$(D $S)/durum")" calisiyor
ok "kullanım %40/%30 → DEVAM" "$("$U/uyku.sh" kullanim $S 40 30 2026-11-03T00:10:00.428Z)" DEVAM
icerir "kullanım %85 → BEKLE" "$("$U/uyku.sh" kullanim $S 85 30)" BEKLE
icerir "haftalık %65 → KAPAT" "$("$U/uyku.sh" kullanim $S 50 65)" KAPAT
"$U/uyku.sh" kullanim $S 10 20 >/dev/null

# ---------------------------------------------------------------------------
bolum "Stop hook"
ok "uyku kaydı olmayan session'a dokunmaz" "$(stop baska-session)" ""
icerir "çalışırken durmaya izin vermez" "$(stop $S)" "turu bitirme"
stop $S >/dev/null; stop $S >/dev/null
ok "3 uyarıdan sonra durmaya izin verir" "$(stop $S)" ""
ok "… ve durumu 'takildi' yapar" "$(cat "$(D $S)/durum")" takildi
ok "gorev-bitti takıldıyı düzeltir" "$("$U/uyku.sh" gorev-bitti $S)" calisiyor
ok "subagent çalışırken durmaya izin verir" "$(stop $S '{"background_tasks":[{"id":"a","type":"subagent","status":"running"}]}')" ""
ok "… uyarı sayacını artırmaz" "$(cat "$(D $S)/engel")" 0
icerir "pilde %20 → kapanış" "$(UYKU_PMSET="$PIL" stop $S)" "KAPANIŞI — pil %20"
ok "kapanıştan sonra durmaya izin verir" "$(stop $S)" ""
ok "… ve durumu 'bitti' yapar" "$(cat "$(D $S)/durum")" bitti
"$U/uyku.sh" durum $S calisiyor >/dev/null
icerir "prizde %20 → pil kuralı uygulanmaz" "$(stop $S)" "turu bitirme"
sonra -60 > "$(D $S)/bitis"
icerir "bitiş saati geçti → kapanış" "$(stop $S)" "bitiş saati geldi"
sonra 10800 > "$(D $S)/bitis"; "$U/uyku.sh" durum $S calisiyor >/dev/null
icerir "bekle → caffeinate komutu verir" "$("$U/uyku.sh" bekle $S "$(date -u -v+1H +%Y-%m-%dT%H:%M:%S.000Z)")" "exec caffeinate -i -t"
ok "… durum 'bekliyor'" "$(cat "$(D $S)/durum")" bekliyor
icerir "bekliyor ama bekleme komutu yok → devam ettirir" "$(stop $S)" "caffeinate) çalışmıyor"
ok "bekleme komutu çalışırken durmaya izin verir" "$(stop $S '{"background_tasks":[{"id":"b","type":"shell","command":"exec caffeinate -i -t 3600"}]}')" ""
icerir "sıfırlanma bitiş saatinden sonraysa beklemez" "$("$U/uyku.sh" bekle $S "$(date -u -v+5H +%Y-%m-%dT%H:%M:%SZ)")" KAPAT
"$U/uyku.sh" durum $S deneme >/dev/null
icerir "deneme modu" "$(stop $S)" "UYKU-HOOK-OK"
ok "bitti → hiçbir şey yapmaz" "$(stop $S)" ""

# ---------------------------------------------------------------------------
bolum "Koruma hook'u (PreToolUse)"
ok "uyku kapalıyken git push serbest" "$(karar baska-session Bash 'git push origin main')" izin
K=test-koruma
"$U/uyku.sh" baslat $K 23:59 27 80 60 "$GECICI/r.md" >/dev/null
while IFS='|' read -r beklenen arac komut; do
  ok "$beklenen: $arac ${komut:0:45}" "$(karar $K "$arac" "$komut")" "$beklenen"
done <<'EOF'
engel|Bash|git push origin gece/2026-11-02
engel|Bash|git -C repo push --force
izin|Bash|git status && git add -A && git commit -m "gece: test"
engel|Bash|git merge main
engel|Bash|git rebase -i HEAD~3
izin|Bash|git log --no-merges --oneline
izin|Bash|git merge-base HEAD main
engel|Bash|git reset --hard HEAD~1
izin|Bash|git reset --soft HEAD~1
engel|Bash|git clean -fd
engel|Bash|gh pr create --fill
izin|Bash|gh pr view 12
engel|Bash|npm publish
engel|Bash|npm run build && npx vercel --prod
engel|Bash|netlify deploy --prod
engel|Bash|firebase deploy
izin|Bash|npx prisma migrate dev --name x
engel|Bash|npx prisma migrate deploy
engel|Bash|supabase db push
engel|Bash|eas build -p ios
engel|Bash|terraform apply
izin|Bash|rm -rf node_modules && npm ci
engel|mcp__slack__send_message|
engel|mcp__gmail__reply|
izin|mcp__gmail__list_threads|
engel|mcp__netlify__deploy-site|
engel|mcp__ccd_session__start_session|
izin|mcp__ccd_turn__update_plan|
izin|mcp__ccd_session_mgmt__get_usage|
izin|mcp__context7__query-docs|
EOF

# ---------------------------------------------------------------------------
bolum "API hatası hook'u (StopFailure)"
H=test-hata
"$U/uyku.sh" baslat $H 23:59 27 80 60 "$GECICI/h.md" >/dev/null; sonra 10800 > "$(D $H)/bitis"
jq -nc --arg s $H '{session_id: $s, error: "authentication_failed"}' | "$U/uyku-hata.sh"
ok "kalıcı hata → uyandırmaz (çıkış 0)" $? 0
ok "… durum 'hata'" "$(cat "$(D $H)/durum")" hata
"$U/uyku.sh" durum $H calisiyor >/dev/null
mesaj=$(jq -nc --arg s $H '{session_id: $s, error: "overloaded"}' | UYKU_TEST_SURE=1 "$U/uyku-hata.sh" 2>&1 >/dev/null); kod=$?
ok "geçici hata → bekleyip uyandırır (çıkış 2)" $kod 2
icerir "… uyandırma mesajı" "$mesaj" "yeniden uyandırdım"
jq -nc '{session_id: "yok", error: "overloaded"}' | "$U/uyku-hata.sh"
ok "uyku kapalıyken hiçbir şey yapmaz" $? 0

# ---------------------------------------------------------------------------
bolum "Not dizini ve değişiklik taraması"
g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
R="$GECICI/repo"; W="$GECICI/wt"
mkdir -p "$R" && g -C "$R" init -q && printf 'const a = 1;\n' > "$R/app.js" && g -C "$R" add . && g -C "$R" commit -qm ilk
g -C "$R" worktree add -q -b ozellik "$W"
n1=$(cd "$R" && "$SK/ortak/scripts/notlar-dizini.sh" gece); n2=$(cd "$W" && "$SK/ortak/scripts/notlar-dizini.sh" gece)
ok "ana repo ve worktree aynı not dizinini kullanır" "$n2" "$n1"
icerir "not dizini repo dışında" "$n1" "$HOME/.local/state/claude-notlar/repo-"
sahte_anahtar="sk-""ant-api03-$(printf 'x%.0s' {1..30})"   # parça parça: depoda gerçek anahtar gibi görünmesin
printf 'console.log("x", a);\nconst key = "%s";\n// TODO: düzelt\n<<<<<<< HEAD\n' "$sahte_anahtar" >> "$W/app.js"
g -C "$W" commit -qam degisiklik; printf 'DB_PASSWORD=supersecret123\n' > "$W/.env"; printf 'debugger;\n' > "$W/yeni.js"
tarama=$(cd "$W" && "$SK/kontrol/scripts/tara.sh" main)
for b in "SECRET olabilir (1)" "Çakışma işareti (1)" "Debug kalıntısı (2)" "Yeni TODO/FIXME (1)" ".env dosyası"; do
  icerir "tarama: $b" "$tarama" "$b"
done
temiz=$(cd "$R" && "$SK/kontrol/scripts/tara.sh" main)
case "$temiz" in *"## "*) ok "temiz dalda bulgu yok" bulgu-var yok ;; *) ok "temiz dalda bulgu yok" yok yok ;; esac

# ---------------------------------------------------------------------------
printf '\n%d başarılı, %d başarısız\n' "$basari" "$hata"
[ "$hata" -eq 0 ]
