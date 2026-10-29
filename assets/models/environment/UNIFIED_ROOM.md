# Kahvehane — bütünlük geçişi

Aktif oda: `kahvehane_unified.glb`. Kaynak: `tools/blender/source/kahvehane_unified.blend`.
Üretim: `tools/blender/unify_coffeehouse.py`, Blender MCP üzerinden `build(base)`.
Önceki `kahvehane_atmosphere.blend` yüklenip ayrı sahnede düzenlenir; eski kaynaklar korunur.

- Oda kabuğu 8.4 × 8.4 metreden yaklaşık 9.66 × 9.91 metreye genişletildi. Oyun masası, koltuklar ve etkileşim koordinatları değişmedi.
- Çay ocağı sol servis duvarına taşındı. İki sohbet masası farklı köşelere yerleşti; Sabri, Temel ve Rıfkı dekoratif misafir olarak kullanılıyor. Ana masadaki yeni karakter seçimi korunuyor.
- Ceviz alt duvarlar, krem sıva, koyu yeşil emaye, ortak ahşap kirişler ve aplikler dört yönü birleştiriyor. Tüfek, tek tuğla şerit, petek ve kaba ceket süsü aktif sahneden çıkarıldı.
- Soba ayrı kapaklı emaye kuzine olarak yeniden modellendi: pişirme halkaları, menteşeler, mandallar, kül çekmecesi, boru bağlantıları ve taş taban.
- Istaka `okey_rack_refined.glb`: kapalı hacimli, kenarları yuvarlatılmış ceviz kesit; iki raf mevcut taş slotlarıyla aynı yerde. Ön yüzü kesen destekler düzeltildi. Blender kaynağı `tools/blender/source/okey_rack_refined.blend`.
- Ana masa çayları oluşturulmuyor; eski etkileşim kodu korunuyor. Arka masalar ve servis bölümündeki çaylar duruyor.
- `cafe_walnut.gdshader` taranmış ahşabın renk karşıtlığını dengeler; `cafe_plaster.gdshader` hafif sıva ayrıntısı verir. Menü ve oyun keçe rengini aynı metottan kullanır.
- Ortam ışığı 0.16; masa ve sohbet grupları sıcak, pencere dolgusu daha nötr. Kesinti sonrasında da 0.16 geri gelir. Mevcut yansıma ve kesinti akışı korunur.

Kontrol: Godot açılışı, dört yönden ortam, masa/ıstaka yakın görünümü, servis ve soba görüntüleri kontrol edildi. `tests/plain_table_interaction.gd` geçti. Performans ölçümü yapılmadı.
Görseller: `screenshots/unified_*.png`. `seat0..3` ortam incelemesinde ön plandaki karakterler geçici olarak gizlenir; oyun karakterleri kaldırılmamıştır.
GitHub'a yükleme yapılmadı.
