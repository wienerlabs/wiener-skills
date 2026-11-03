---
name: devam
description: /devir ile yazılan "nerede kaldık" notunu okuyup işi kaldığı yerden sürdürür. Yeni session'ın başında ya da kullanıcı "kaldığımız yerden devam", "dünkü işe devam" dediğinde kullan.
argument-hint: "[ek talimat]"
---

# /devam — kaldığın yerden sür

Kullanıcının ek talimatı: $ARGUMENTS

## Devir notu ve mevcut durum

```!
d=$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh)
echo "Not dizini: $d"
echo "Klasör: $(pwd) · Dal: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'git yok')"
echo "--- commit edilmemiş ---"; git status --short 2>/dev/null | head -20 || true
echo "--- devir.md ---"
if [ -f "$d/devir.md" ]; then cat "$d/devir.md"; else echo "(devir.md yok)"; ls -t "$d/arsiv" 2>/dev/null | head -3 || true; fi
echo "--- son gece raporu ---"; ls -t "$d/gece" 2>/dev/null | head -1 || echo "(yok)"
```

## Adımlar

1. **Not yoksa:** arşivdeki en yeni notu ya da son gece raporunu oku; o da yoksa son commit'lerden (`git log --oneline -15`) durumu çıkar ve kullanıcıya not bulunamadığını söyle.
2. **Tutarlılık kontrolü:**
   - Nottaki dal ≠ şu anki dal ise: kullanıcıya söyle. Commit edilmemiş değişiklik yoksa nottaki dala geçmeyi öner, kendiliğinden geçme.
   - Notta "commit edilmemiş değişiklik var" yazıyor ama burada görünmüyorsa: yeni session başka klasörde açılmış olabilir; nottaki klasör yolunu söyle.
   - Nottan sonra yeni commit'ler varsa (`git log <nottaki hash>..HEAD --oneline`) onları da hesaba kat.
3. **Notun en üstüne** `> Okundu: <tarih saat> — session ${CLAUDE_SESSION_ID}` satırını ekle.
4. **Özet:** kullanıcıya 4-6 satır: amaç, nerede kalındı, sıradaki adım, açık sorular.
5. **Devam et:** "Sıradaki adımlar"ın ilkinden hemen başla. İstisnalar:
   - Not kullanıcıdan cevap bekleyen bir soru ile bitiyorsa önce onu sor.
   - Kullanıcı ek talimat verdiyse o önceliklidir.

"Alınan kararlar"ı yeniden tartışma, "Denenip işe yaramayanlar"ı tekrar deneme; yeni bir kanıt yoksa.
