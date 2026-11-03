---
name: rapor
description: Patrona/yöneticiye gönderilecek, teknik olmayan dilde durum raporu hazırlar — son rapordan beri yapılanlar, istek dokümanlarındaki ilerleme, beklenen kararlar. "Patrona rapor", "durum raporu", "ne yaptık özeti" isteklerinde kullan.
argument-hint: "[süre: 'son 7 gün' | 'dünden beri'] [--teknik]"
---

# /rapor — yönetici durum raporu

Argümanlar: $ARGUMENTS

## Kaynaklar

```!
d=$(~/.claude/skills/ortak/scripts/notlar-dizini.sh raporlar)
echo "Rapor dizini: $d"
echo "Son raporlar: $(ls -t "$d" 2>/dev/null | head -3 | tr '\n' ' ')"
echo "Git kullanıcısı: $(git config user.name 2>/dev/null) <$(git config user.email 2>/dev/null)>"
echo "Dal: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'git yok')"
echo "İstek dokümanları:"; ls -t docs/istekler/*.md 2>/dev/null | head -5 || echo "(yok)"
echo "Gece raporları:"; ls -t "$(~/.claude/skills/ortak/scripts/notlar-dizini.sh gece)" 2>/dev/null | head -3 || true
```

## Adımlar

1. **Aralık:** argümandaki süre → yoksa son rapor dosyasının tarihi → o da yoksa son 7 gün.
2. **Veri topla** (diff okuma, token harcama):
   - `git log --all --no-merges --since=<başlangıç> --author=<e-posta> --date=short --pretty='%ad %h %s'` (200 satırla sınırla)
   - commit mesajları yetersizse sadece ilgili commit'lerde `git show --stat <hash>`
   - `docs/istekler/*.md` tablolarındaki "Sonuç" sütunları → madde bazında ilerleme
   - gece raporlarında hâlâ bekleyen kritik kararlar
3. **Yaz** (Türkçe; `--teknik` yoksa teknik terim, dosya adı, commit hash'i yok):

```markdown
**Konu:** <Proje> — durum, <tarih aralığı>

**Özet:** <1-2 cümle, en önemli gelişme>

**Tamamlananlar**
- <iş değeriyle: "Müşteriler artık siparişlerini ... yapabiliyor">

**İstek dokümanları** (varsa)
- <Doküman>: 12 maddeden 9'u tamamlandı, 2'si sizin cevabınızı bekliyor, 1'i devam ediyor.

**Devam edenler**
- <somut durum; yüzde uydurma>

**Sizden beklenenler**
- <karar/soru — seçenekleriyle, kısa>

**Riskler** (yalnızca gerçekten varsa)

**Sıradaki adımlar**
- ...
```

4. **Kurallar:**
   - Uydurma yok: sadece git geçmişinde ve dokümanlarda olan. Belirsizse "devam ediyor" de.
   - Benzer commit'leri tek maddede birleştir; refactor, format, test gibi iç işleri tek satırda topla ya da hiç yazma ("altyapı iyileştirmeleri").
   - Kısa tut: bir ekrana sığsın.
5. **Kaydet ve göster:** `<rapor dizini>/<YYYY-MM-DD>.md` dosyasına yaz, raporu sohbete de kopyalanabilir şekilde yaz. Kimseye gönderme — kullanıcı kendisi gönderir.
