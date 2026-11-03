---
name: devir
description: Uzayan session'ı devretmek için "nerede kaldık" notu yazar; yeni session'da /devam bu notla kaldığı yerden sürer. Kullanıcı "devret", "yeni session'a geçelim", "session çok uzadı" dediğinde ya da context çok dolduğunda kullan.
argument-hint: "[ek not]"
---

# /devir — session'ı devret

Amaç: Yeni ve temiz bir session'ın, bu konuşmayı hiç görmeden, 2-3k token'lık tek bir notla aynı işe kaldığı yerden devam edebilmesi.

Kullanıcının ek notu: $ARGUMENTS

## Mevcut durum

```!
echo "Not dizini: $(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh)"
echo "Klasör: $(pwd)"
echo "Dal: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'git yok')"
echo "Varsayılan dal: $(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo 'bilinmiyor')"
echo "--- commit edilmemiş ---"; git status --short 2>/dev/null | head -30 || true
echo "--- son commit'ler ---"; git log --oneline -12 2>/dev/null || true
```

## Adımlar

1. **Commit edilmemiş değişiklik varsa:**
   - Varsayılan dalda değilsen: `git add -A && git commit -m "wip: devir ara kaydı"`. Yeni session başka bir worktree'de açılırsa değişiklikler kaybolmasın.
   - Varsayılan daldaysan commit etme; notta açıkça yaz ve kullanıcıya yeni session'ı **bu klasörde** açmasını söyle.
2. **Eski notu arşivle:** not dizininde `devir.md` varsa `arsiv/devir-<YYYYMMDD-HHMM>.md` olarak taşı (`mkdir -p` ile).
3. **`devir.md` yaz** (aşağıdaki şablon, en fazla ~150 satır).
4. **Yeni session'ı teklif et:**
   - `mcp__ccd_session__start_session` aracı varsa (gerekirse ToolSearch ile `select:mcp__ccd_session__start_session` yükle): önce yalnızca `initiation: "offer"` ve `title: "Devam: <iş özeti>"` ile çağır, mesajdaki tek araç çağrısı bu olsun. Kullanıcı yeni session'ı seçerse `proposal_id` ile şunu gönder: `context: "fresh"`, `use_worktree: false`, `prompt: "/devam"`, `background`: işin 2-3 cümlelik özeti + `devir.md`'nin tam yolu + "/devam çalışmazsa bu dosyayı oku ve 'Sıradaki adımlar'dan devam et".
   - Araç yoksa: "Yeni bir session aç (aynı proje klasöründe) ve `/devam` yaz."

## Not şablonu

```markdown
# Devir notu
- Tarih: <YYYY-MM-DD HH:MM> · Önceki session: ${CLAUDE_SESSION_ID}
- Klasör: <pwd> · Dal: <dal> · Son commit: <kısa hash + mesaj>
- Commit edilmemiş değişiklik: yok | <liste ve neden commit edilmedi>

## Amaç
<Kullanıcının asıl istediği, 2-4 cümle. Kabul kriterleri varsa.>

## Yapılanlar
- <ne yapıldı> — `dosya` (<commit>)

## Şu an nerede kaldık
<Yarım kalan iş: hangi dosyada, ne eksik. Yapılacak bir sonraki somut adım.>

## Sıradaki adımlar
1. <somut, sıralı>

## Alınan kararlar (yeniden tartışma)
- <karar> — <gerekçe>

## Denenip işe yaramayanlar
- <yaklaşım> — <neden olmadı>

## Açık sorular / kullanıcıdan beklenenler
- ...

## Önemli dosyalar
- `yol` — <neden önemli>

## Çalıştırma ve test
- <komutlar, gerekli servisler, ortam notları>

## Kullanıcı tercihleri
- <bu session'da öğrenilen çalışma tercihleri, varsa>
```

## Kurallar

- Sadece yeni session'ın bilmesi gerekeni yaz. Kod yapıştırma, `dosya:satır` ile referans ver.
- "Denenip işe yaramayanlar" ve "Alınan kararlar" en değerli bölümler: yeni session aynı hataları tekrar yapmasın, kapanmış konuları yeniden açmasın.
- Belirsiz ifade yok: "bazı testler" değil, "`auth.test.ts` içindeki 2 test (refresh token)".
- Son mesajda: notun tam yolu, 3-5 satırlık özet ve yeni session nasıl açılacak.
