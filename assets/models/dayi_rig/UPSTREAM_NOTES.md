# GitHub'dan alınan karakterler
Kaynak: https://github.com/talhaelck/okey
Kayıt: 620674b — Mixamo-rigged Meshy dayıs that handle real tiles

Dosyalar bu kayıtla aynı hâlde, dokuları ve .import dosyalarıyla birlikte indirildi:
- assets/models/dayi_rig/dayi_gozluklu.glb
- assets/models/dayi_rig/dayi_tespihli.glb
- assets/models/dayi_rig/dayi_yasli.glb
- assets/models/dayi_rig/anim/seated_idle.glb
- assets/models/dayi/dayi.glb
- assets/models/dayi/fp_arms.glb ve kol dokusu

Modeller projeye alındı; mevcut oyun karakterleriyle otomatik değiştirilmedi. Arkadaşın main dalındaki RiggedDayi/DayiHands/IK oyun kodu bu indirmeye dahil edilmedi. Oyun içine animasyonlu entegrasyon ayrı bir düzenleme gerektirir.
Kaynak kayıttaki credits: Dayı modelleri Meshy ile Talha tarafından üretilmiş; iskelet ve oturma klipleri Mixamo tabanlıdır. Ayrıntılı kredi metni SOURCE_CREDITS.md içinde saklandı.
Yereldeki Sabri varyantı ve Gemini değişiklikleri korunmuştur.

## Oyuna entegrasyon
Üç model artık ekstra seçim kartları olarak kullanılıyor: Nihat Dayı (gozluklu), Cemil Dayı (tespihli), Hamdi Amca (yasli). Dört eski karakter korundu. Karakter listesi kaydırılabilir.
Yerel uyarlayıcı scripts/world/rigged_patron.gd ve scripts/character/rig_patron_ik.gd dosyalarıdır. Oturma klibi iskelete yeniden hedeflenir; ölçek oturmuş gövdeye göre ayarlanır, karakter koltuğun önüne yerleştirilir, gerekirse sandalye ayak desteği eklenir. Baş takibi/olay tepkileri ve kollar için iki kemikli IK bulunur. El hedefleri ıstakanın iki yanında tutulur. Yeni modellerin gövdeleri yerel kameraya eklenmez; mevcut oyuncu elleri ve seçime uygun kol rengi kullanılır. Ham fp_arms dosyası mevcut el mekaniğinin yerine geçirilmedi.
Taş sahipliği ve kurallar bu sunum bileşenine taşınmadı; otomatik yeni taş çalma davranışı eklenmedi. Özgün Meshy/Mixamo GLB dosyalarına değişiklik yapılmadı.
Doğrulama: tests/rigged_patrons_integration.gd geçti. Üç karakterin masa görünüşü screenshots/extra_patrons_table.png, seçim ekranı screenshots/extra_patrons_selection.png.

## Ortama göre ölçek revizyonu
Yeni üç karakterin oturmuş gövde hedefi 0.41 m yerine 0.34 m oldu: tüm model tekdüze yaklaşık %17 küçültülür. Baş/eller/kemikler ayrı ayrı ölçeklenmez; özgün GLB geometrisi değiştirilmez. Kalça konumu (0, 0.09, -0.075) olarak ayarlandı. Ayak desteği modelin yeni kemik konumlarından yeniden hesaplanır. Aynı uyarlama hem karakter seçim önizlemesinde hem oyun masasında kullanılır. Ortam ve dört eski karakterin ölçeği değişmedi.
Kontrol: tests/rigged_patrons_integration.gd tekrar geçti. Yeni oyun içi görüntü screenshots/extra_patrons_table_rescaled.png; önceki ölçü screenshots/extra_patrons_table_before_scale.png.

## Son masa kadrosu kuralı
Kullanıcının yeni talebiyle, oyun masasındaki üç rakip artık yalnızca gozluklu (Nihat), tespihli (Cemil) ve yasli (Hamdi) karakterleridir; her biri tam bir kez yer alır. Yerel karakter seçimi rakip havuzunu değiştirmez. CafePreferences.patron_lineup her yeni masa için yerleri karıştırır, aynı oturumu izleyen masada birebir aynı dizilişi önler. Menüde kart/örtü değiştirmek mevcut masanın yerleşimini tekrar karıştırmaz. Dört eski karakterin dosyaları ve seçim önizlemeleri korunmuştur. 24 masa dizilişi ve entegrasyon kontrolü tests/rigged_patrons_integration.gd ile geçti.
