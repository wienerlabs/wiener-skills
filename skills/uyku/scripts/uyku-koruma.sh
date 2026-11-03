#!/bin/bash
# /uyku PreToolUse hook'u: uyku modu açıkken geri dönüşü zor ya da proje dışına dokunan işlemleri engeller.
# Uyku modu kapalıyken hiçbir şey yapmaz.

KOK="$HOME/.local/state/claude-uyku"
[ -d "$KOK" ] || exit 0

girdi=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$girdi" 2>/dev/null)
d="$KOK/$sid"
[ -n "$sid" ] && [ -f "$d/durum" ] || exit 0
case $(cat "$d/durum") in calisiyor|bekliyor|kapanis) ;; *) exit 0 ;; esac

arac=$(jq -r '.tool_name // empty' <<<"$girdi")

reddet() {
  echo "$(date '+%F %T') koruma: $arac engellendi: $1" >> "$d/log"
  jq -nc --arg m "Uyku modunda yasak: $1. Bunu yapma; sabah raporuna kritik karar olarak yaz (ne gerekiyordu, neden) ve başka işe geç." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}}'
  exit 0
}

if [ "$arac" = Bash ]; then
  komut=$(jq -r '.tool_input.command // empty' <<<"$girdi")
  s='(^|[;&|(`[:space:]])'   # komut başı
  desenler=(
    "${s}git[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)|push (uzak depoya gönderme)"
    "${s}git[[:space:]]+([^;&|]*[[:space:]])?(merge|rebase)([[:space:]]|$)|merge/rebase"
    "${s}git[[:space:]]+reset[[:space:]]+([^;&|]*[[:space:]])?--hard|git reset --hard"
    "${s}git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f|git clean -f"
    "${s}gh[[:space:]]+(pr[[:space:]]+(create|merge|close)|release|repo[[:space:]]+(delete|edit))|GitHub'da PR/release işlemi"
    "${s}(npm|yarn|pnpm|bun)[[:space:]]+publish|paket yayınlama"
    "${s}(vercel|netlify|firebase|fly|flyctl|wrangler|heroku|railway|serverless|sls)[[:space:]]+([^;&|]*[[:space:]])?deploy|deploy"
    "${s}vercel[[:space:]]+([^;&|]*[[:space:]])?--prod|production deploy"
    "${s}(eas[[:space:]]+(submit|update|build)|fastlane)|mağaza/OTA yayını"
    "${s}(kubectl[[:space:]]+(apply|delete|rollout)|terraform[[:space:]]+(apply|destroy)|pulumi[[:space:]]+up|docker[[:space:]]+push)|altyapı değişikliği"
    "(migrate[[:space:]]+deploy|db[[:space:]]+push|supabase[[:space:]]+db[[:space:]]+(push|reset))|veritabanına migration/şema uygulama"
  )
  for satir in "${desenler[@]}"; do
    desen=${satir%|*}; ad=${satir##*|}
    if grep -qE -- "$desen" <<<"$komut"; then reddet "$ad"; fi
  done
  exit 0
fi

case "$arac" in
  mcp__*)
    yontem=${arac##*__}
    # Okuma ve oturum araçları serbest
    case "$arac" in
      mcp__ccd_turn__*|mcp__ccd_session_mgmt__get_usage|mcp__ccd_host__request_keep_awake) exit 0 ;;
    esac
    if grep -qiE '^(get|read|list|search|query|resolve|find|fetch|view|describe|check|preview|browser_snapshot|browser_take_screenshot)' <<<"$yontem"; then exit 0; fi
    if grep -qiE 'send|deploy|publish|launch|forward|reply|merge|delete|trash|remove|share|upload|create|update|set_|import|approve|release|block|write|move|copy|label|spam|cancel|clear|start|stop|post|comment|edit' <<<"$yontem"; then
      reddet "dış servise yazan araç ($arac)"
    fi
    ;;
esac
exit 0
