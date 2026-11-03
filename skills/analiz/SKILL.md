---
name: analiz
description: Patrondan veya müşteriden gelen PDF, toplantı raporu ya da istek metnini okuyup projeyle karşılaştırır; olmayanları kodlar, var olanları dokümana göre günceller. Kullanıcı bir PDF/rapor/istek metni verip "bunu uygula", "eksikleri kodla", "bu dokümana göre düzenle" dediğinde kullan.
argument-hint: "[PDF yolu | metin] [--onaysiz]"
---

# /analiz — istek dokümanını koda dönüştür

Girdi: $ARGUMENTS
(Girdi boşsa doküman bu mesaja eklenmiştir ya da metin olarak yapıştırılmıştır. Hiçbiri yoksa kullanıcıdan dokümanı iste ve dur.)

`--onaysiz` verildiyse hiçbir soru sorma: çelişen maddelerde doküman kazanır, muğlak maddeler uygulanmaz, "sorulacaklar"a yazılır.

## 1. Dokümanı oku (token tasarrufuyla)

- PDF dosya yolu verildiyse önce metne çevir, görsel olarak okuma:
  `K=$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh kaynaklar); pdftotext -layout "<pdf>" "$K/<tarih>-<kısa-ad>.txt"` sonra metni oku.
  Çıktı boş ya da anlamsızsa (taranmış PDF) o zaman sayfaları Read ile görsel oku.
- PDF mesaja doğrudan eklendiyse zaten okumuşsun; tekrar çıkarma.
- Toplantı notu / yapıştırılan metin: olduğu gibi kullan.

## 2. Gereksinimleri çıkar

Dokümanı tek tek, test edilebilir maddelere böl: `R1, R2, ...`. Her madde için:
- tek cümlelik gereksinim + kaynağa kısa referans (sayfa/başlık, 10 kelimeyi geçmeyen alıntı)
- **net** mi, **yoruma açık** mı? İki makul yorumu olan, sayı/kapsam belirtmeyen, "iyileştirilsin" gibi muğlak maddeler yoruma açıktır.

Toplantı notlarındaki fikir alışverişini, "belki", "ileride" denen şeyleri gereksinim sayma; "Notlar"a yaz.

## 3. Projeyle karşılaştır

Önce proje bağlamını al (CLAUDE.md, README, dizin yapısı — kısaca). Sonra her madde için kodda karşılığını bul:

| Durum | Anlamı |
|---|---|
| **Var** | Doküman ne istiyorsa kod zaten yapıyor |
| **Kısmen** | Bir kısmı var, eksikleri var |
| **Yok** | Hiç yok |
| **Çelişiyor** | Kod farklı/ters davranıyor; dokümana uymak mevcut davranışı değiştirir |

- 5'ten fazla madde varsa ya da proje büyükse taramayı bir subagent'a ver: `Agent` aracı, `subagent_type: Explore`, `model: sonnet`. Prompt'a gereksinim listesini koy ve şunu iste: "Her madde için durum (Var/Kısmen/Yok/Çelişiyor), kanıt `dosya:satır`, bir satırlık not. Dosya içeriği yapıştırma, sadece tablo döndür."
- Küçük işlerde kendin ara: dosyaları baştan sona okuma, Grep/Glob ile hedefli ara.
- Kanıtsız "Var" deme: dosya:satır göstermiyorsan "Kısmen" ya da "Yok"tur.

## 4. Analiz dosyasını yaz

`docs/istekler/<YYYY-MM-DD>-<kısa-ad>.md` (dizin yoksa oluştur):

```markdown
# <Doküman adı> — istek analizi
Kaynak: <dosya adı veya "toplantı notu, tarih"> · Analiz: <tarih> · Dal: <dal>

| # | Gereksinim | Durum | Kanıt | Yapılacak | Sonuç |
|---|---|---|---|---|---|
| R1 | ... | Yok | – | ... | |

## Sorulacaklar
1. R4 — <soru>. Olası yorumlar: A) ... B) ...

## Notlar
- <gereksinim sayılmayan ama bilinmesi gerekenler>
```

## 5. Onay (yalnızca riskli maddeler)

Tabloyu kullanıcıya kısaca göster (sadece Durum ≠ Var olanlar + sayılar). Sonra:
- **Çelişiyor** maddeleri ve **yoruma açık** maddeler için AskUserQuestion kullan (bir çağrıda en fazla 4 soru). Çelişen madde çoksa tek soruda topla: "Çelişen N maddenin hepsini dokümana göre değiştireyim mi?"
- Yoruma açık maddede seçeneklerden biri her zaman "Patrona soralım, şimdilik yapma" olsun.
- Geri kalan (Yok/Kısmen, net) maddeler için onay bekleme, doğrudan uygula.

## 6. Uygula

1. Git: varsayılan daldaysan (main/master/develop) `git switch -c istek/<kısa-ad>`. Başka bir daldaysan orada kal.
2. Sıra: bağımlılıklar önce; sonra Yok → Kısmen → onaylanan Çelişiyor.
3. Her madde ya da birbirine bağlı madde grubu için ayrı commit: `feat(R3,R4): <özet>`. Mevcut kod stiline, isimlendirmeye, dosya düzenine uy.
4. Davranış değiştiren her maddeye test ekle ya da mevcut testi güncelle (projede test altyapısı varsa).
5. 10'dan fazla madde varsa her grubu sırayla bir `general-purpose` subagent'a ver (aynı anda tek yazıcı), ana context küçük kalsın; commit'i sen at.
6. Sonda projenin testlerini/tip kontrolünü/lint'ini çalıştır (çıktıyı `tail -40` ile kısalt). Kırık bırakma.
7. Analiz dosyasındaki "Sonuç" sütununu doldur (`✅ <commit>`, `⏸ soruldu`, `❌ <neden>`) ve dosyayı commit et.

Push etme, PR açma — kullanıcı isterse yapılır.

## 7. Son mesaj

- Kısa tablo: madde → sonuç
- **Sorulacaklar** listesi, patrona olduğu gibi gönderilebilecek dille (teknik terim yok)
- Analiz dosyasının yolu ve dal adı
