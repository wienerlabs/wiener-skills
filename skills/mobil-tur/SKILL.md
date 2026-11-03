---
name: mobil-tur
description: Mobil uygulamayı simülatörde çalıştırıp ana akışları gezer, ekran görüntüsü alır ve bozuk görünen ekranları raporlar.
argument-hint: "[gezilecek akışlar/ekranlar] [--karanlik]"
disable-model-invocation: true
---

# /mobil-tur — simülatörde görsel tur

Argümanlar: $ARGUMENTS (`--karanlik`: ana ekranları karanlık modda da kontrol et)

Amaç: hata bulmak, düzeltmek değil. Düzeltmeyi sonda kullanıcıya sor.

## 1. Platform ve çalıştırma

Proje türünü belirle: `*.xcodeproj`/`*.xcworkspace` (native iOS), `package.json`'da `expo` ya da `react-native`, `pubspec.yaml` (Flutter), sadece `android/` (Android).

**iOS (öncelikli):**
- `mcp__Claude_Code_iOS_Simulator__control` aracı varsa: önce `attach` (kullanıcı izleyebilsin), sonra derle (`mcp__Claude_Code_iOS_Simulator__build` varsa onu, yoksa projenin kendi komutu: `xcodebuild`, `npx expo run:ios`, `flutter run`), sonra `launch`.
- Araç yoksa `xcrun simctl` ile: `boot`, `install`, `launch`; ekran görüntüsü için `xcrun simctl io booted screenshot <dosya>`.

**Android:** emülatör + `adb` (`adb exec-out screencap -p > <dosya>`, `adb shell input tap x y`).

Derleme başarısızsa turu yapma; hatayı özetle ve dur.

## 2. Akış listesi

Argüman verildiyse onu kullan. Yoksa navigasyon kodundan çıkar (expo-router `app/` dizini, React Navigation screen tanımları, SwiftUI `NavigationStack`/`TabView`, Flutter route'ları):
- en fazla 8 ana ekran + varsa giriş/onboarding, boş durum, hata durumu
- listeyi kullanıcıya tek satırda göster ve onay beklemeden başla

## 3. Gez ve kontrol et

Her ekran için: oraya git → ekran görüntüsü **`scale: 0.5`** (token tasarrufu) → kontrol listesi:
- taşan/kesilen metin, üst üste binen öğeler, ekran dışına taşan içerik
- çentik / safe area / alt bar çakışması
- boş, yükleniyor ya da hata durumunda takılı kalma
- klavyenin giriş alanını kapatması (form ekranlarında)
- çok küçük dokunma alanları, okunmayan kontrast
- `--karanlik` ile ana 2-3 ekranda karanlık mod (`set_appearance` ya da `xcrun simctl ui booted appearance dark`)

Şüpheli bir şey görürsen o bölgeyi `zoom` ile tam çözünürlükte doğrula ve ekranı dosyaya kaydet:
`$(${CLAUDE_SKILL_DIR}/../ortak/scripts/notlar-dizini.sh mobil-tur/<YYYY-MM-DD>)/<ekran>.png`

Toplamda 25 ekran görüntüsünü geçme. Bir ekrana ulaşılamıyorsa (giriş gerekiyor, veri yok) not et ve geç; test hesabı gerekiyorsa projenin seed/örnek dosyalarına bak, gerçek kimlik bilgisi isteme.

## 4. Rapor

`<aynı dizin>/rapor.md` dosyasına ve sohbete:

```markdown
# Mobil tur — <tarih> · <cihaz> · <dal>
| Ekran | Durum | Sorun | Görüntü |
|---|---|---|---|
| Giriş | ✅ | – | |
| Sepet | ⚠️ | Uzun ürün adı fiyatın üstüne biniyor | sepet.png |
```

Sonra tek soru: "Hangilerini düzelteyim?" (seçenekler: hepsini / sadece ❌ olanları / hiçbirini).
