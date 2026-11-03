---
name: kontrol
description: Push/PR öncesi kalite kontrolü — testler, lint, tip kontrolü ve değişikliklerde sızmış secret, debug kalıntısı, çakışma işareti, .env, büyük dosya taraması. "Push etmeden kontrol et", "PR'a hazır mı", "kontrol" isteklerinde kullan.
argument-hint: "[--tam] [taban-dal]"
---

# /kontrol — push öncesi kontrol

Argümanlar: $ARGUMENTS (`--tam`: build ve yavaş kontrolleri de çalıştır)

## 1. Komutları belirle

Öncelik sırası: CLAUDE.md / README'de yazan komutlar → proje dosyaları:
- **Node:** paket yöneticisi kilit dosyasından (pnpm-lock → pnpm, yarn.lock → yarn, bun.lock* → bun, yoksa npm). `package.json` script'lerinden: `test`, `lint`, `typecheck`/`type-check`/`tsc` (yoksa `tsconfig.json` varsa `npx tsc --noEmit`). `build` sadece `--tam` ile. Test script'i watch modundaysa CI modunda çalıştır (`CI=1`, `--run` vb.).
- **Python:** `pytest -q`, yapılandırılmışsa `ruff check .`, `mypy`.
- **Go:** `go vet ./...`, `go test ./...` · **Rust:** `cargo clippy -q`, `cargo test -q`
- **Swift/Xcode:** sadece `--tam` ile (yavaş).
Monorepo'da sadece değişen paketlerin komutlarını çalıştır.

## 2. Çalıştır (çıktıyı kısa tut)

Her komut için: `set -o pipefail; <komut> 2>&1 | tail -40`
- Geçtiyse sadece ✅ yaz, çıktıyı aktarma.
- Kaldıysa sadece hata satırlarını özetle (dosya:satır + mesaj).
- Bağımsız komutları paralel çalıştırabilirsin.

## 3. Değişiklik taraması

`~/.claude/skills/kontrol/scripts/tara.sh [taban-dal]`

Bulguları değerlendir; yanlış alarmları (test fixture'ı, örnek değer, bilerek bırakılmış log) ele ve neden elediğini tek satırla yaz.

## 4. Sonuç

```markdown
| Kontrol | Sonuç | Not |
|---|---|---|
| Testler | ✅ / ❌ | ... |
| Lint | ... | |
| Tip kontrolü | ... | |
| Secret | ... | |
| Debug kalıntısı | ... | |
| Çakışma / .env / büyük dosya | ... | |
```

Son satır: **"Push'a hazır"** ya da **"Önce şunlar düzelmeli: ..."**

- **Secret bulunduysa** en üstte, açıkça uyar. Commit'lenmişse: anahtarın iptal edilip yenilenmesi gerektiğini ve geçmişten temizlemenin ayrı bir iş olduğunu söyle. Kendiliğinden geçmişi yeniden yazma.
- Mekanik düzeltmeler (debug log silme, çakışma işareti, lint --fix) için tek soru sor: "Düzelteyim mi?"
- Push etme, PR açma.
