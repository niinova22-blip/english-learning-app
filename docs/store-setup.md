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
   | AI Premium aylık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.monthly` |
   | AI Premium yıllık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.yearly` |

3. İki aboneliği **aynı abonelik grubunda** (`ai_premium`) oluştur; yıllık olanı
   aylığın üstüne yerleştir.
4. Her ürüne Türkçe görünen ad ve açıklama gir, fiyat belirle, "Aile Paylaşımı"
   kapalı kalsın.
5. Her ürün için inceleme ekran görüntüsü olarak paywall sayfasının görüntüsünü ekle.
6. **Gizlilik politikası** ve **kullanım şartları** URL'lerini hazırla.
   `App/Sources/EnglishApp/Store/StoreLinks.swift` içindeki `privacyPolicy` değerini
   yayımlanan gizlilik politikası adresiyle doldur (abonelik uygulamaları bu
   bağlantı olmadan reddedilir). Kullanım şartları için Apple'ın standart EULA'sı
   kullanılır.
7. **Sandbox test hesabı** oluştur (Kullanıcılar ve Erişim → Sandbox).

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
- [ ] Kelime havuzu 120'den 600'e çıktıktan sonra seviye testi: yerleştirme hâlâ mantıklı hissettiriyor mu (daha zor kelimeler soru havuzuna girdi)?

Not: Release/TestFlight derlemelerinde geliştirici "Tüm paketleri aç" anahtarı
yoktur (yalnızca Debug). TestFlight'ta kilitli içeriği görmek için sandbox
satın alması gerekir; bu yüzden ürünler App Store Connect'te hazır olmadan
TestFlight'ta kilitli üniteler açılamaz.
