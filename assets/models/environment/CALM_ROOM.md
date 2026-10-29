# Güncel ortam: sade kahvehane, 360 derece

## En güncel: kahvehane atmosferi ve geri gelen yan sehpalar

Oyun `kahvehane_atmosphere.glb` kullanır; düzenlenebilir ayrı kaynak `tools/blender/source/kahvehane_atmosphere.blend`. `build_calm_coffeehouse.py` temel odasından sonra Blender'da `enrich_coffeehouse.enrich(base)` uygulanır. Önceki kaynaklar korunur.

Üç küçük yan sehpa/stand geri geldi: yerel çay, soda şişesi ve kül tablası ayrı yüzeylerdedir. Çayların diğer üçü ana masanın farklı kenar konumlarına dağıtılmıştır; hepsi köşeye dizilmez. Gözlük/büyüteç veya ana masa süsleri geri gelmedi. Masa ölçüleri ve görünmez taş atma alanı korunur.

Bayrağın arkasında lambri-tavan arasında tuğla bölüm, üstünde dekoratif eski çift namlulu tüfek vardır. Bombeli camı, ayar düğmeleri, havalandırma yarıkları, hoparlörü, kablosu ve duvar askısı modellenmiş tüplü TV eklendi. TV'nin düşük parlaklıklı, yazısız maç görüntüsü `cafe_crt.gdshader` ile çizilir; elektrik kesintisinde kararır. Giriş yanında askılık/ceket, pencere altında dilimli döküm radyatör bulunur. Arka plan dayıları ve masalar korunur.

Yeni soda şişesi, kapak/etiket/boğaz; soba perçinleri/yakıtı ve çaydanlık ağız kıvrımları Blender'da modellenmiştir. TV, tuğla, kumaş ve metaller için Godot'ta uygun pürüzlülük/normal kaplamaları uygulanır. Sahne modelindeki doku düğümleri tek başına Godot görünüşü değildir; `CoffeehouseMaterials` geçersiz kılmaları da gereklidir.

Son kontrol: içe aktarma ve dört yönün oyun görüntüleri; yazısız HUD, kesinti/geri dönüş ve `plain_table_interaction.gd` kontrolleri başarılı. Performans ölçümü ve GitHub yüklemesi yapılmadı.

## Son revizyon: ferah salon ve sade ana masa

Salon yatay eksenlerde %20 büyütüldü (yaklaşık 8,4×8,4 m); mobilyalar ve karakterler esnetilmedi. Çay ocağı takım halinde dış duvara taşındı. Arka plan masalarında üç `RiggedPatron` misafiri oturur; aynı model/iskelet kullanılır, küçük masalara uygun el yüksekliği/uzanma genişliği ayrı sunum değerleridir. Ana oyuncuların değerleri değişmedi. Kül tablaları ve tespihler küçük arka plan masalarına taşındı.

Ana masa modeli artık `assets/models/table_details/okey_table_plain.glb`; düzenlenebilir kaynak `tools/blender/source/okey_table_plain.blend`, Blender sahnesi `OkeyTable_Sade`. Önceki model korunur. Modelden 4 yuvarlak ahşap köşe, 4 pirinç köşe ve 4 pirinç kenar şeridi çıkarıldı. Keçenin desenli şeridi kaldırıldı; masa/ıstaka kaplamaları daha mat ve düşük kontrastlıdır.

Ana masada yalnızca dört köşe çayı vardır; gözlük, büyüteç, kahve, tespih, leblebi, kül tablası ve yazboz oluşturulmaz. Yan sehpalar ile görsel taş atma kaideleri/padleri oluşturulmaz. Eski yardımcı oluşturma fonksiyonları kullanılmadan kaynakta korunur. Kaldırılan eşyalara ait yan sehpa kapışma olayı çalışmaz.

`Table.is_in_discard_zone(point, seat_index)` görünmez taş atma alanının ortak kaynağıdır. El önizlemesi ve masaya bırakma/düşürme aynı sınırları kullanır; merkez ve ıstaka alanını kapsamaz. Atılan taşların sahipliği, sırası ve bir sonraki oyuncunun yandan alması korunur. `tests/plain_table_interaction.gd` dört yönde alan sınırlarını, taş sahipliğini, serbest bırakmayı, dört çay ve kaldırılan eşyaları kontrol eder; başarılıdır. Dört yönün oyun görüntüleri ve kesinti/geri dönüş kontrolleri de geçti. GitHub'a yükleme yapılmadı.

Ana oyun artık `scripts/world/calm_coffeehouse.gd` kullanır. Önceki oda modelleri ve `cinematic_coffeehouse.gd` korunur; ikisini birlikte sahneye eklemeyin.

## Kaynaklar

- `tools/blender/source/kahvehane_calm.blend` — bağımsız `Kahvehane_Sade_360` sahnesi.
- `tools/blender/build_calm_coffeehouse.py` — Blender'da `build(base)` ile tekrar üretilebilir; diğer karakter/oda sahnelerini değiştirmez. Yalnızca kendisine ait `Kahvehane_Sade_360` sahnesini yeniler.
- `assets/models/environment/kahvehane_calm.glb` — oyundaki çevre.
- `assets/models/environment/calm_tea_glass.glb` — yeni ince belli bardak, çay, porselen tabak ve kaşık. Etkileşimli masanın mevcut konumlarını/sahipliğini/hit alanlarını kullanır.
- `scripts/world/coffeehouse_materials.gd` — dünya koordinatlı kaplamalar; cam için ince cam shader'ı; mobilyaların çift taraflı yüzey ayarları korunur. Karakter modellerine uygulanmaz.

## Yerleşim ve görünüş

Oda yaklaşık 7×7 m; ana masa ve oyuncu koltuklarının koordinatları değiştirilmedi. Arka sol tarafta sade kapalı dolaplı çay tezgâhı, tek raf, çift katlı çelik/bakır çaydanlık ve iki bardak var. Sağ duvarda gerçek açıklıklı pencere, pervaz ve kumaş perdeler bulunur. Soba sağ ön köşededir; kapak, ızgara, menteşe, ahşap tutamak, kül çekmecesi, hava girişleri, ocak halkaları ve duvara dönen baca içerir. Giriş karşı taraftadır. Duvar saati sol duvara, küçük nazar kapı yanına dağıtılmıştır. Slogan/tarife/ürün yazıları yoktur.

Arka planda yalnızca iki küçük yuvarlak masa ve üç sandalye vardır: iki plastik, bir ahşap. Sandalyeler masa kenarından ayrı ve duvarların içinde kalacak şekilde yerleştirildi. Krem sıva, adaçayı lambri/perde/aydınlatma ve daha sakin ahşaplar kullanılır. Dört yöne eşit yumuşak dolgu ışığı verilir; pencere ve küçük masa ışıkları yereldir. Yeni yansıma sadece ortam/mobilyayı etkiler. Sürekli yuvarlak buhar parçaları kaldırıldı; oyunun etkin duman/sabotaj akışları korunur.

## Yazısız oyun ekranı

HUD üst paneli, alt komutları, muhabbet/sohbet kutusu, yardım düğmesi, ipucu ve geçici bildirimleri gizlidir. Karakterlerin konuşma ve ünlem yazıları boş bırakılır. Taş rakamları ve oyunu başlatma/duraklatma menüleri korunur. Esc/F1 ile açılan menüler çalışır. Sohbet/komut sunumunun sonraki tasarımı için mevcut altyapı silinmedi.

## Kontrol

Godot 4.7.2 içe aktarımı ve oyun açılışı başarılı. Dört koltuk yönü, tezgâh ve soba oyun içinden gözle kontrol edildi. Gizli ıstaka arka yüzleri malzeme değişiminden sonra da kapalıdır. Yazısız HUD, ışık/emisyon/yansımanın kesinti ve geri dönüş kontrolleri geçti. Performans ölçümü yapılmadı; GitHub'a yüklenmedi.

Yerel görüntüler: `screenshots/calm_seat_0.png`–`calm_seat_3.png`, `calm_counter.png`, `calm_stove.png`, `calm_overview.png`. Kamera açıları çevre kontrolü içindir; çok oyunculu eşitleme veya diğer koltukları yerel oyuncuya dönüştürme bu değişikliğin kapsamında değildir.
