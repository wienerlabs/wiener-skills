---
name: uyku
description: Gece modu — kullanıcı uyurken kritik kararları sabaha bırakıp geri kalan işi pil, kullanım limiti ve bitiş saatine göre otonom sürdürür. Sabah /gunaydin ile kapatılır.
argument-hint: "[görevler] [bitis=08:00] [pil=27] [limit=80] [haftalik=60]"
disable-model-invocation: true
# CLAUDE_PLUGIN_ROOT: plugin olarak kurulunca plugin kökü, kişisel kurulumda bu skill'in klasörü.
hooks:
  Stop:
    - hooks:
        - type: command
          command: 'r="${CLAUDE_PLUGIN_ROOT}"; [ -d "$r/skills/uyku" ] && r="$r/skills/uyku"; exec "$r/scripts/uyku-stop.sh"'
          timeout: 30
  PreToolUse:
    - matcher: "Bash|mcp__.*"
      hooks:
        - type: command
          command: 'r="${CLAUDE_PLUGIN_ROOT}"; [ -d "$r/skills/uyku" ] && r="$r/skills/uyku"; exec "$r/scripts/uyku-koruma.sh"'
          timeout: 10
  StopFailure:
    - hooks:
        - type: command
          command: 'r="${CLAUDE_PLUGIN_ROOT}"; [ -d "$r/skills/uyku" ] && r="$r/skills/uyku"; exec "$r/scripts/uyku-hata.sh"'
          asyncRewake: true
          timeout: 21600
---

# /uyku — gece modu

Kullanıcı uyuyor. Sabaha kadar onu beklemeden çalışacaksın.

- Session: `${CLAUDE_SESSION_ID}`
- Yardımcı: `${CLAUDE_SKILL_DIR}/../uyku/scripts/uyku.sh` (aşağıda `uyku.sh` diye geçer; her çağrıda tam yolu yaz)
- Argümanlar: $ARGUMENTS

## Değişmez kurallar

1. **Soru sorma, onay bekleme.** AskUserQuestion yok. Tek istisna: başlamadan önceki izin modu kontrolü.
2. **Push, merge, rebase, deploy, publish, PR açma, gerçek veritabanına migration, mesaj/e-posta gönderme yok.** Koruma hook'u bunları zaten engeller; engellenirse kritik karar olarak rapora yaz.
3. **Kritik karar → uygulama.** Rapora yaz (seçenekler + önerin), etrafından dolaş, bağımsız işlere devam et.
   - Kritik: geri dönüşü zor ya da proje dışına dokunan; veri/şema silme veya değiştirme; kendi oluşturmadığın dosyayı silme; yeni ücretli servis/bağımlılık; public API ya da sözleşme değişikliği; birçok dosyayı etkileyen mimari tercih; güvenlik/kimlik doğrulama davranışı; gereksinimin iki makul yorumu olması.
   - Küçük (sen ver, gerekçesini rapora yaz): isimlendirme, iç yapı, eşdeğer kütüphane seçimi, test ekleme, davranışı değiştirmeyen refactor, hata mesajları, küçük UI düzenlemeleri.
4. **Her görev ayrı commit.** Sabah tek tek geri alınabilsin. Çalışmayan kodu commit etme.
5. **Durma kararını kurallar verir:** kuyruk bitti, bitiş saati, pil eşiği (sadece pildeyken), haftalık tavan. 5 saatlik limit dolduysa durma, **bekle**.

## Başlamadan önce (kullanıcı henüz uyanık)

1. **İzin modu:** Bağlamında auto mode (ya da bypass) açık olduğuna dair işaret yoksa dur ve söyle: "Auto mode'a geçmezsen ilk izin isteğinde sabaha kadar takılırım." Modu kullanıcı değiştirir; geçtiğini söyleyince devam et.
2. **Ayarlar:** argümanlardan al, yoksa varsayılan: `bitis=08:00`, `pil=27`, `limit=80` (5 saatlik %), `haftalik=60` (haftalık % tavanı).
3. **Git:** `git status -sb`. Varsayılan daldaysan (main/master/develop) `git switch -c gece/<YYYY-MM-DD>`. Commit edilmemiş değişiklik varsa önce `git add -A && git commit -m "wip: uyku öncesi durum"`.
4. **Görev kuyruğu**, bu sırayla topla:
   a. argümanlardaki görevler
   b. bu konuşmada yarım kalan işler
   c. `$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh)/devir.md` → "Sıradaki adımlar"
   d. en yeni `docs/istekler/*.md` → sonucu boş maddeler
   Her görevi tek cümleyle, bir-iki saatte bitecek boyutta yaz; büyükleri böl. **Kuyruk boşsa başlama**, kullanıcıya söyle.
5. **Kullanım:** `mcp__ccd_session_mgmt__get_usage` (gerekirse ToolSearch ile `select:` yükle) → 5 saatlik % ve sıfırlanma zamanı, haftalık %. Haftalık zaten tavanın üstündeyse başlama. Araç yoksa (terminal) yüzde kuralları uygulanamaz: bunu rapora yaz, diğer kurallarla devam et.
6. **Rapor dosyası:** `$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh gece)/<YYYY-MM-DD>.md` — aşağıdaki şablonla oluştur.
7. **Başlat:**
   `uyku.sh baslat ${CLAUDE_SESSION_ID} <HH:MM> <pil> <limit> <haftalik> <rapor_yolu>`
   `uyku.sh kullanim ${CLAUDE_SESSION_ID} <5s%> <haftalik%> <resetsAt>`
8. `mcp__ccd_host__request_keep_awake` varsa `until: "session_idle"` ile çağır.
9. Kullanıcıya en fazla 6 satır: kuyruk (madde sayısı + ilk 3), bitiş saati, rapor yolu, **"Kapağı açık bırak, sabah /gunaydin yaz."** Sonra hemen işe başla.

## Çalışma döngüsü

Her görevden önce:
1. **Kullanım:** get_usage → `uyku.sh kullanim ${CLAUDE_SESSION_ID} <5s%> <haftalik%> <resetsAt>`. Çıktı:
   - `DEVAM` → göreve geç
   - `BEKLE` → aşağıdaki **Bekleme**
   - `KAPAT` → `uyku.sh kapat ${CLAUDE_SESSION_ID} "<neden>"` ve **Kapanış**
   (Pil ve bitiş saatini Stop hook kontrol eder.)
2. **Uygula:** Büyük görevi `general-purpose` bir subagent'a ver; prompt'a görevi, ilgili dosyaları, kural 2-3'ü aynen koy ve şunu iste: "Commit etme, push etme. Bitince döndür: ne değişti, test sonucu, verdiğin küçük kararlar, `KRİTİK:` ile başlayan bekleyen kararlar (seçenekler + önerin)." Aynı anda tek subagent. Birkaç dosyalık küçük işleri kendin yap — subagent'ın amacı ana context'i küçük tutmak.
3. **Doğrula:** `git diff --stat`, projenin hızlı testleri / tip kontrolü / lint (çıktıyı `tail -40` ile kısalt). Kırıksa düzelt; düzelmiyorsa bu görevin değişikliklerini geri al ve rapora "başarısız" yaz.
4. **Commit:** `gece: <görev özeti>`.
5. **Rapor:** güncelle, sonra `uyku.sh gorev-bitti ${CLAUDE_SESSION_ID}`.

Kuyruk bitince, zaman ve limit varsa yalnızca düşük riskli iş ekle: eksik testler, mevcut koddaki açık TODO'lar, lint uyarıları. Yeni özellik icat etme. O da bitince `uyku.sh kapat ${CLAUDE_SESSION_ID} "kuyruk bitti"` ve **Kapanış**.

Her yeniden uyandırılışta (subagent bitti, bekleme bitti, hata sonrası) önce `uyku.sh durum ${CLAUDE_SESSION_ID}`: `kapanis` ise yeni işe başlama; `bitti` ise kullanıcı devraldı, dur; `takildi` ise `uyku.sh durum ${CLAUDE_SESSION_ID} calisiyor` yap ve devam et.

## Bekleme (5 saatlik limit)

1. `uyku.sh bekle ${CLAUDE_SESSION_ID} <resetsAt>`
   - `KAPAT` derse (sıfırlanma bitiş saatinden sonra) → `uyku.sh kapat ...` ve **Kapanış**.
   - Aksi halde verdiği komutu **Bash ile `run_in_background: true`** çalıştır. Hem bekler hem Mac'i uyanık tutar.
2. Rapora "HH:MM–HH:MM limit beklemesi" yaz, tek satır mesajla turu bitir.
3. Komut bitince yeniden çağrılırsın: `uyku.sh durum ${CLAUDE_SESSION_ID} calisiyor`, kullanımı kontrol et, kaldığın yerden devam et.

## Kapanış

Stop hook "UYKU MODU KAPANIŞI" dediğinde ya da sen `uyku.sh kapat` çalıştırdığında:
1. Yeni işe başlama. Yarım iş çalışıyorsa commit et; çalışmıyorsa commit etme, rapora yaz.
2. Raporu son haline getir: durma nedeni, son kullanım (`uyku.sh goster ${CLAUDE_SESSION_ID}`), zaman çizelgesi.
3. Saat 07:00–23:00 arasındaysa `PushNotification` ile tek satır: "Gece işi bitti: X/Y görev, Z kritik karar bekliyor". Gece yarısı bildirim gönderme.
4. 3-4 satırlık özet yaz ve dur.

## Rapor şablonu

```markdown
# Gece raporu — <YYYY-MM-DD>
Proje: <klasör> · Dal: <dal> · Başlangıç: <HH:MM> · Bitiş: <HH:MM> · Durma nedeni: <...>
Kullanım: 5 saatlik %a → %b · Haftalık %c → %d · Güç: <AC | pil %x → %y>

## Özet
<2-3 cümle: ne bitti, ne kaldı, sabah ilk ne yapılmalı>

## Kritik kararlar (onayın gerekiyor)
### K1. <başlık>
- Bağlam: <neden karar gerekiyor, 2-3 satır>
- Seçenekler: A) ... B) ...
- Önerim: A, çünkü ...
- Bekleyen iş: <bu karara bağlı yapılmayan>

## Tamamlanan görevler
| # | Görev | Commit | Test |
|---|---|---|---|

## Yarım kalan / başarısız
- <görev> — <neden, nerede kaldı>

## Verdiğim küçük kararlar
- <karar> — <gerekçe> (<commit>)

## Kuyruk (başlangıçtaki hali)
1. ...

## Zaman çizelgesi
- 23:40 başladı · 02:10–03:15 limit beklemesi · ...
```
