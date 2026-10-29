# Dengeli kahvehane, eski ıstaka ve birleşik masa

Aktif oda `kahvehane_balanced.glb`; Blender kaynağı `tools/blender/source/kahvehane_balanced.blend`.
Aktif masa `assets/models/table_details/okey_table_joined.glb`; kaynak `tools/blender/source/okey_table_joined.blend`.
Istaka tekrar özgün `okey_rack.glb`. Kaynak üretim `tools/blender/okey_table_details.py`; yeni ince destekli model kullanılmıyor.
Oda ve masa düzeltme betiği `tools/blender/restore_cafe_balance.py`.

- Önceki dört ayrı masa kenarı ve açıkta kalan yatak yerine yuvarlatılmış, kapalı hacimli tek parça ahşap çerçeve ve uyumlu alt tabla modellendi. Keçe açıklığı ve oyun koordinatları korundu.
- Yerel ıstaka uzaklığı 0.57'den 0.50 metreye alındı; diğerleriyle aynı mesafede. Bütün ıstaka hacimleri artık keçe sınırlarında; ahşap kenara gömülmüyor.
- Özgün ıstaka gövdesinin bazı yüzleri çift taraflıdır. Ortak ahşap shader'ında `cull_disabled` korunmalı; aksi hâlde ön/arka yüzler kaybolur ve rakip taşları görünür.
- Çini alt duvar tamamen kaldırıldı. Daha açık ceviz tonlarında, sığ çerçeveli ahşap paneller geldi. Tavanı ve üst duvarları kesen çıtalar geri eklenmedi.
- Mevcut arka bankın önüne sohbet masası ve sandalye, banka Davut, girişe küçük gazete standı eklendi. Ana masa çaysız kalıyor.
- Pencere dışındaki büyük yapraklar, üst kat pencere kalıntıları ve havada kalan pervazlar çıkarıldı. Açık keten perdeler, şeffaf cam, daha alçak avlu cephesi ve akşam gökyüzü var. Dışarıdaki gerçek geometri korunuyor.
- Ortam ışığı 0.20; alt duvarlara hafif dolgu, bank masasına ışık eklendi. Kesintiden dönüş de 0.20 kullanır.

Blender'da aktif `Kahvehane_Dengeli` sahnesi masa ve dört ıstakayı da gösterir. `PREVIEW - table racks and lighting` koleksiyonu yalnızca çalışma görünümüdür, oyun odası GLB'sine aktarılmaz. Kaynak sahne ışıklı malzeme görünümünde, yardımcı çizgiler kapalı bırakıldı. Oyun karakterleri Godot tarafından eklenir.

Kontrol: dört yönden masa/oda, ıstaka yakın görünümü, pencere ve soba incelendi. `screenshots/review_balanced.gd` tüm ıstaka sınırlarını kontrol etti: `BALANCED_CLEARANCE_AND_REVIEW: PASS`. `tests/plain_table_interaction.gd` geçti. Görseller `screenshots/balanced_*.png`.
GitHub'a yüklenmedi; performans ölçümü yapılmadı.
