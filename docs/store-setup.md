# Mağaza kurulumu ve satın alma testi (Slice 8)

Kod tarafı hazır olduğunda, satın almaların gerçekten çalışması için aşağıdaki
adımlar App Store Connect'te elle yapılır. CI gerçek StoreKit'i çalıştıramaz.

## 1. App Store Connect

1. **Paid Applications** sözleşmesini kabul et; vergi ve banka bilgilerini doldur.
2. Uygulamada **Uygulama İçi Satın Almalar** altında şu ürünleri oluştur
   (kimlikler birebir aynı olmalı; silinen kimlik yeniden kullanılamaz):

   | Ürün | Tür | Ürün kimliği |
   |---|---|---|
   | YDS Paketi | Tüketilmeyen (Non-Consumable) | `com.niinova22.englishapp.package.yds` |
   | Business English | Tüketilmeyen (Non-Consumable) | `com.niinova22.englishapp.package.business` |
   | Everyday English | Tüketilmeyen (Non-Consumable) | `com.niinova22.englishapp.package.everyday` |
   | AI Premium aylık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.monthly` |
   | AI Premium yıllık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.yearly` |

3. İki aboneliği **aynı abonelik grubunda** (`ai_premium`) oluştur; yıllık olanı
   aylığın üstüne yerleştir.
4. Her ürüne Türkçe görünen ad ve açıklama gir, fiyat belirle, "Aile Paylaşımı"
   kapalı kalsın.
5. Her ürün için inceleme ekran görüntüsü olarak paywall sayfasının görüntüsünü ekle.
6. **Gizlilik politikası** ve **kullanım şartları** — HAZIR. Gizlilik politikası
   https://niinova22-blip.github.io/lexpath/privacy.html adresinde (ayrı public
   `niinova22-blip/lexpath` reposu, GitHub Pages) ve `StoreLinks.privacyPolicy`'de
   tanımlı. App Store Connect'te "Gizlilik Politikası URL'si" alanına bu adresi,
   "Destek URL'si" alanına https://niinova22-blip.github.io/lexpath/ adresini gir.
   Uygulama Gizliliği bölümünde "Veri toplanmıyor" seçilir. Kullanım şartları için
   Apple'ın standart EULA'sı kullanılır.
7. **Sandbox test hesabı** oluştur (Kullanıcılar ve Erişim → Sandbox).

## 1b. Yayın öncesi App Store Connect kontrol listesi (sırayla)

1. **Uygulama adı:** Uygulama Bilgileri → Ad: `Lexpath`; Alt başlık (EN):
   `English for YDS, Work & Travel`; Türkçe yerelleştirme ekle, alt başlık (TR):
   `YDS, iş ve günlük İngilizce`.
2. **Fiyatlar** (her ürün → Fiyatlandırma → temel ülke ABD, sonra Türkiye'yi elle düzelt):

   | Ürün | ABD | Türkiye |
   |---|---|---|
   | AI Premium aylık | $6.99 | ₺149,99 |
   | AI Premium yıllık | $39.99 | ₺899,99 |
   | YDS Paketi | $12.99 | ₺349,99 |
   | Business English | $9.99 | ₺249,99 |
   | Everyday English | $9.99 | ₺249,99 |

3. **Ücretsiz deneme:** Her iki abonelik → Abonelik Fiyatları → Tanıtım Teklifi
   Oluştur → tüm ülkeler → "Ücretsiz", süre **1 hafta**. (Uygulama denemeyi
   StoreKit'ten okur; teklif tanımlı değilse deneme metni hiç gösterilmez.)
4. **Ürün adları/açıklamaları:** her ürüne EN ve TR görünen ad + açıklama
   (örn. "AI Premium (yearly)" / "AI Premium (yıllık)").
5. **Beta App Information** (TestFlight → Test Bilgileri): geri bildirim
   e-postası, inceleme iletişim bilgileri (ad, soyad, telefon, e-posta) ve kısa
   "Ne test edilmeli" metni. Dış test grubuna göndermek için zorunlu.
6. **Mağaza görselleri:** İngilizce, paketleri tanıtan pazarlama görselleri
   (6.9" ve 6.5" iPhone boyutları).

## 2. Yerel geliştirme (Xcode)

`App/StoreKit/Products.storekit` dosyasını Edit Scheme → Run → Options →
StoreKit Configuration altında seç. Fiyatlar yalnızca yerel örnek değerlerdir.

## 3. TestFlight'ta elle doğrulama (CI'nin yapamadığı kısım)

Sandbox hesabıyla, gerçek cihazda:

- [ ] Ders Yolu'nda kilitli bir derse dokun → "Paketi aç" → fiyat görünüyor mu?
- [ ] Satın al → Apple ödeme sayfası → onay → kilitler açıldı mı, Bugün ve Ders Yolu yenilendi mi?
- [ ] Uygulamayı kapatıp aç → paket hâlâ açık mı? Uçak modunda aç → hâlâ açık mı?
- [ ] Profil → Satın alımları geri yükle → çalışıyor mu (silip yeniden yükledikten sonra)?
- [ ] Tutor sekmesi → kilitli ekran → "AI Premium'a geç" → aylık/yıllık seçimi → abonelik.
- [ ] Abonelik sonrası "Öğretmene Sor" ve Tutor sohbeti açılıyor mu?
- [ ] Profil → Aboneliği yönet açılıyor mu?
- [ ] Bir gramer dersini uçtan uca dene: kart → 8 veya 10 soru → özet → "Tekrar: konu" zamanlaması.
- [ ] Ask to Buy (çocuk hesabı) bekleme durumu: "Onay bekleniyor" görünüyor mu?
- [ ] Slice 7c yeni soru tipleri (ekranlar CI'da görülemiyor): bir okuma dersi (parça paneli), bir cloze dersi (boşluklu parça) ve bir konu dışı cümle dersi (uzun numaralı soru + I-V seçenekleri) küçük ekranda ve büyük yazı boyutunda düzgün görünüyor mu?
- [ ] Slice 7d strateji dersi uçtan uca (Sınav soru tipi stratejileri ünitesinden bir ders): strateji kartı önce görünüyor mu, ardından sorular geliyor mu, açıklamalardaki (A)-(E) harfleri seçeneklerle eşleşiyor mu? Sınav yönetimi ve kelime öğrenme teknikleri ünitelerinden birer ders de dene.
- [ ] Slice 7d yeni kelime ünitelerinden bir ders (ör. Health & Medicine): 10 kelime, üçer örnek ve üçer collocation düzgün görünüyor mu? Uzun tanım/çeviri satırları büyük yazı boyutunda taşmıyor mu?
- [ ] Slice 9 AI Koç (premium, sandbox abonelikle): Bugün'ün üstünde koç kartı görünüyor mu (durum rozeti, ilerleme satırı)? Sınav tarihi yokken "Sınav tarihini ekle" daveti ve Çalışma ayarları sayfası çalışıyor mu? Sınav tarihini çok yakın (7 günden az) yapınca plan yalnızca tekrar mı oluyor? Tarihi yetişilemeyecek kadar yakın yapınca "Tempo yetmiyor" ve iki buton çıkıyor mu?
- [ ] AI Koç kişisel not: "Koçtan kişisel not al" → model yüklenip Türkçe, 2-4 cümlelik, sayıları doğru bir not yazıyor mu? Uygulamayı açınca model KENDİLİĞİNDEN yüklenmiyor mu (bellek)? Ücretsiz kullanıcıda kilitli "AI Koç" kartı paywall'u açıyor mu? Büyük yazı boyutunda kart taşmıyor mu?
- [ ] Kelime havuzu 120'den 600'e çıktıktan sonra seviye testi: yerleştirme hâlâ mantıklı hissettiriyor mu (daha zor kelimeler soru havuzuna girdi)?
- [ ] **Son hâl (2026-09-25):** Telefonu Türkçe yap → ilk açılıştan itibaren her ekran Türkçe mi (paket adları "İş İngilizcesi", "Günlük İngilizce", ders başlıkları Türkçe)? İngilizce yap (uygulamayı sil-yükle) → her şey İngilizce mi ve YDS paketi listede **yok** mu?
- [ ] Yeni görünüm: açık/koyu modda arka plan iOS gri tonu, kartlar gölgeli ve çerçevesiz mi; butonlara basınca yaylı küçülme ve hafif titreşim var mı; iOS 26'da sekme çubuğu ve Öğretmen sohbet giriş alanı cam görünümlü mü; Ayarlar → Erişilebilirlik → Hareketi Azalt açıkken animasyonlar duruyor mu?
- [ ] Alıştırmada doğru cevapta başarı, yanlış cevapta hata titreşimi; oturum özetinde kutlama animasyonu.
- [ ] Onboarding: hedef → tarih (Business/Everyday'de "hedef tarih") → süre → **hatırlatıcı** ("Hatırlat" izin ister, "Şimdi değil" istemez) → seviye testi → **deneme teklifi** (sandbox hesabı deneme hakkı varken) → "Şimdi değil" ile uygulamaya giriliyor mu? Deneme sayfasını açıp kapatınca adımda kalıyor mu?
- [ ] AI Premium sayfası: yıllık plan önde, "En avantajlı · %50 tasarruf" (TR) / "save 52%" (US) rozeti, "≈ ayda …" satırı, deneme zaman çizelgesi, buton "7 gün ücretsiz dene", altında "7 gün ücretsiz, sonra yıllık ₺899,99…" yazıyor mu? Deneme kullanılmış sandbox hesabında zaman çizelgesi kayboluyor ve buton "Abone ol · fiyat" oluyor mu?
- [ ] Denemeyi başlat → Bildirim izni istendi mi → Ayarlar'da bekleyen bildirim (Xcode ile) deneme bitişinden 1 gün önce mi? Sandbox'ta deneme süreleri kısalır (1 hafta ≈ 3 dakika), hatırlatma bu yüzden anında düşebilir.
- [ ] Profil → HATIRLATICILAR: açınca izin isteniyor mu; saat değişince bildirim o saate kuruluyor mu; o günün planı bitince o günün hatırlatması gelmiyor mu?
- [ ] Ücretsiz kullanıcıda Bugün'deki koç önizlemesi: gerçek durum rozeti, bulanık mesaj, "7 gün ücretsiz dene"; X ile gizleyince 7 gün görünmüyor mu?
- [ ] Paket satın alma sayfası: ünite/ders/soru sayıları ve "İlk ünite ücretsiz" satırı.
- [ ] 7 günlük seriye ulaşılan gün oturum özetinden çıkarken puanlama penceresi (TestFlight'ta Apple bunu göstermez; yalnızca App Store sürümünde görünür — kod yolu hata vermemeli).

Not: Release/TestFlight derlemelerinde geliştirici "Tüm paketleri aç" anahtarı
yoktur (yalnızca Debug). TestFlight'ta kilitli içeriği görmek için sandbox
satın alması gerekir; bu yüzden ürünler App Store Connect'te hazır olmadan
TestFlight'ta kilitli üniteler açılamaz.
