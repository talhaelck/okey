# Menü revizyonu

Ortak görünüm `cafe_ui.gd`: mat koyu yeşil paneller, kırık beyaz metin, sakin adaçayı ana düğme, tek çerçeve, klavye odağı. Menü ve duraklatma/yardım ekranları aynı temayı kullanır. Eski görsel varlıklar silinmedi.

Ana menü: Oyna / Karakterler / Ayarlar / Çıkış. Oyna doğrudan oyunu açar. İşlevsiz mekân, davet ve iki kişilik masa seçenekleri kaldırıldı; mevcut dört kişilik kahvehane kullanılır. Önceden kaydedilmiş iki kişilik/mekân tercihi menüde geçerli sayılmaz.

Karakterler: yedi karakter korunur; canlı 3D önizleme ve seçili kart vurgusu vardır. Oynanışı etkilemeyen özellik çubukları kaldırıldı. Kart seçimi hemen uygulanır, Tamam/Geri ana menüye döner. Menüyü gezinmek rakip sırasını değiştirmez.

Ayarlar: ses, fare hassasiyeti, tam ekran, örtü rengi ve gerçek oyun temposu. Değişiklikler mevcut tercih sistemiyle anında kaydedilir; ayrıca Kaydet düğmesi yoktur. Oyun temposu başlatma sırasında ilk tur süresine de uygulanır. Esc alt ekrandan ana menüye döner.

Duraklatma: Oyuna dön / Nasıl oynanır / Ana menü. Yardım metni kaldırılmış aksesuarları vaat etmez. Oyun sırasındaki yazısız HUD korunur.

Karakter ölçeği: `RiggedPatron` önceden yalnızca omuz-kalça mesafesini eşitliyordu; bu, yaşlı modelin tüm vücudunu fazla büyütüyordu. Artık `HeadTop_End`–`Hips` mesafesi 0,655 m hedefiyle tek tip ölçeklenir ve kalça aynı oturma noktasına hizalanır. Mesh/iskelet oranları esnetilmez, kaynak modeller değiştirilmez. Masa, arka plan misafirleri ve önizleme aynı sunumu kullanır. Eski dört modelin baş merkezi zaten ortak yüksekliktedir.

Doğrulama: `tests/menu_flow.gd` ve `tests/rigged_patrons_integration.gd` başarılı. Doğrudan başlama, alt ekranlar, yedi karakter, yerel kameranın açıklığı, el/ıstaka teması, gizli taş yüzleri ve duraklat/devam et kontrol edildi. Ana menü, karakterler, ayarlar, duraklatma, yardım ve masa görüntüleri yerel `screenshots/ui_*.png` dosyalarındadır. Performans ölçümü ve GitHub yüklemesi yapılmadı.
