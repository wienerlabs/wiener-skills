---
name: gunaydin
description: /uyku sonrası sabah incelemesi — uyku modunu kapatır, gece raporunu özetler, kritik kararları sorar ve onaylananları uygular.
disable-model-invocation: true
---

# /gunaydin — sabah incelemesi

## Uyku kayıtları

```!
echo "Bu session: ${CLAUDE_SESSION_ID}"
echo "--- bu projenin uyku kayıtları (en yeni önce) ---"
${CLAUDE_SKILL_DIR}/../uyku/scripts/uyku.sh bul 2>/dev/null || true
echo "--- son gece raporları ---"
ls -t "$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh gece)" 2>/dev/null | head -3 || true
```

## Adımlar

1. **Uyku modunu kapat.** Kayıt listesinde bu session varsa onu, yoksa en yeni kaydı seç:
   `${CLAUDE_SKILL_DIR}/../uyku/scripts/uyku.sh bitir <session_id>`
   Bu, hook'ları devre dışı bırakır ve bekleme sürecini sonlandırır. Hiç kayıt yoksa en yeni gece raporuyla devam et; rapor da yoksa "Gece raporu bulunamadı" de ve dur.
2. **Raporu oku** (kayıttaki `rapor:` yolu). Durum `hata` ya da `takildi` ise nedenini ilk satırda söyle.
3. **Özet sun** (en fazla ~15 satır):
   - durma nedeni, saat aralığı, kullanım (başlangıç → bitiş)
   - tamamlanan görev sayısı ve tek satırlık listesi
   - yarım kalan / başarısız olanlar
   - küçük kararlar, her biri tek satır — "İtiraz ettiğin olursa söyle, ilgili commit'i geri alırım."
4. **Kritik kararları sor:** AskUserQuestion, bir çağrıda en fazla 4 karar. Her karar için rapordaki seçenekler; önerilen seçenek ilk sırada ve "(Önerilen)" etiketli; her kararda bir seçenek "Şimdilik bekletelim" olsun. 4'ten fazla karar varsa sırayla birkaç çağrı yap. Kritik karar yoksa bu adımı atla.
5. **Onaylananları uygula:** her karar için bekleyen işi yap, ayrı commit at (`karar(K1): <özet>`). Uyku kuralları artık geçerli değil, ama push/PR yine kullanıcı isteyince.
6. **Raporu kapat:** rapora `## Sabah incelemesi (<HH:MM>)` bölümü ekle: verilen kararlar, uygulananlar, bekletilenler.
7. **Son mesaj:** dalın durumu (`git log --oneline <ana dal>..HEAD | wc -l` commit), test durumu ve öneri: "Hazırsa önce /kontrol, sonra push/PR."
