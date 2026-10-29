# Dar pencere ve avlu düzenlemesi

Aktif model: `kahvehane_courtyard.glb`. Blender kaynağı: `tools/blender/source/kahvehane_courtyard.blend`.
Kaynak düzenleme: `tools/blender/open_courtyard_pass.py`, Blender MCP üzerinden `build(base)`.
Önceki birleşik oda ayrı tutulur.

- Pencere açıklığı yaklaşık 2.27 metreden 1.12 metreye indirildi. Derin söve, dışa yakın kasa, pervaz, orta kayıt ve mandal modellendi.
- Düz İstanbul manzarası kaldırıldı. Pencere arkasında gerçek 3D avlu, alçak duvar, farklı uzaklıklardaki cepheler ve yapraklı ağaç var. Kamera hareketinde paralaks oluşur.
- Pencere ışığı, yerel hafif sis hacmiyle desteklenir. Odanın tamamı sise boğulmaz.
- Kuzine aynı biçimiyle pencereden 47 cm uzağa taşındı. Emaye daha okunur yeşile açıldı; köşe ışığı ve ortam dolgusu artırıldı.
- Duvar/tavan kirişleri ve çıtalar kaldırıldı. Kapı ve pencerenin kendi çerçeveleri kaldı. Alt duvarlarda açık adaçayı tonlu ince seramik motif var.
- Çay ocağı yanındaki sohbet grubu boş döşeme alanına taşındı; üçüncü bir ahşap sandalye eklendi. Misafirlerin konumları `calm_coffeehouse.gd` içinde eşleşir.
- Her Oyna yeni bir oda yönü seçer; son yön tekrar edilmez ve tercih dosyasında tutulur. Oda referans çerçevesi döndürülür: oyuncu oda içinde başka koltuğa geçmiş olurken mantıksal oyuncu indeksi 0, el/taş koordinatları ve sıra sahipliği korunur. Duraklatmadan dönmek koltuğu değiştirmez.
- Yeni yön `game.player_room_seat`; seçim `CafePreferences.next_player_place()`. Menü `_play()` ve tek başına `main.tscn` başlangıcı bu akışı kullanır.

Kontrol: Oyun içinde dört yön, iki kamera konumundan pencere paralaksı, soba ve taşınan sohbet masası incelendi. 12 ardışık koltuk seçiminde tekrar olmadığı ve ıstaka dönüşümlerinin korunması doğrulandı. Görseller ve kontrol kaydı: `screenshots/courtyard_*`.
GitHub'a yükleme ve performans ölçümü yapılmadı.
