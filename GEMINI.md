## Son oynanış sadeleştirmesi — yalnızca çay devirme
Masaya vurma, Q/K kısayolları, otomatik/manüel elektrik kesintileri, botun masaya vurma şakası ve diğer eşya sabotajları main.gd'den çıkarıldı. Çay içme/boost yok. Üç rakip çayı tekrar etkileşimli; sol tık/E çayı devirir, ilgili ıstaka 5.4sn açılır. Eski -24 derece yeterince açmıyordu; -68 derece ve .059m yükselme ile taş yüzleri görünür, arka destek masaya girmez. Bardak ayrı CupPivot ile devrilir, tabak sabit kalır. Tekrar basma süreyi yenilemez. cafe_plaster.gdshader hafif boya/sıva aşınması verir; Blender kaynağının duvar malzemesi de güncellendi. tests/table_actions_smoke.gd ve plain_table_interaction.gd güncel akışla geçti. GitHub'a yüklenmedi.

## Son düzeltme — eski ıstaka, kapalı masa köşeleri ve ahşap paneller
Aktif oda kahvehane_balanced.glb, masa okey_table_joined.glb. Istaka özgün okey_rack.glb'ye döndü. Yerel ıstaka mesafesi 0.50m; çini yok. Blender'da Kahvehane_Dengeli çalışma sahnesi görünür; PREVIEW koleksiyonu GLB'ye aktarılmaz. Ayrıntılar assets/models/environment/BALANCED_ROOM.md. Eski kaynakları kullanarak bu düzeltmeleri ezme. GitHub'a yüklenmedi.

## 30 Ekim — pencere, avlu ve rastgele koltuk
Aktif oda kahvehane_courtyard.glb. Kaynaklar, ışık, taşınan masalar ve rastgele oyuncu yönü assets/models/environment/COURTYARD_ROOM.md içinde. Duvar/tavan çıtaları kaldırıldı; dar pencerenin arkasında 3D avlu var. Önceki unified kaynağı korunuyor. GitHub'a yüklenmedi.

## Son ortam düzenlemesi
Aktif oda artık kahvehane_unified.glb; aktif ıstaka okey_rack_refined.glb. Ayrı Blender kaynakları ve ayrıntılar assets/models/environment/UNIFIED_ROOM.md içinde. Eski ortam kaynaklarına dönerek bu düzenlemeyi ezme. Ana masa çaysız; arka masalar eski karakterlerle dolu; ana masanın karakter ve oynanış akışı korunuyor. GitHub'a yüklenmedi.

# Son iş: sade 360 derece kahvehane ve yazısız oyun ekranı

Son UI çalışması: ortak `scripts/ui/cafe_ui.gd` temasıyla ana menü, karakterler, ayarlar ve duraklatma/yardım yenilendi. Oyna doğrudan açar; işlevsiz mekân/davet/iki kişilik seçenekler ve sahte karakter özellik çubukları kaldırıldı. Ayarlar anında kaydedilir. Karakter sunumunda tüm yeni dayılar baş üstü–kalça mesafesiyle uniform ölçeklenir; eski modeller ve kaynak varlıklar korunur. `tests/menu_flow.gd` ve `tests/rigged_patrons_integration.gd` geçti. Ayrıntılar `scripts/ui/DESIGN_NOTES.md` içinde. GitHub'a yüklenmedi.

En güncel çevre revizyonu: oda artık `kahvehane_atmosphere.glb`, kaynak `tools/blender/source/kahvehane_atmosphere.blend`. Yan sehpalar çay/soda/kül tablası ile geri geldi; çaylar asimetrik dağıtıldı. Tuğla bayrak bölümü, dekoratif eski tüfek, detaylı tüplü TV, askılık/ceket ve radyatör eklendi. Blender üretim adımı `tools/blender/enrich_coffeehouse.py`; önce temel odayı üret, sonra `enrich(base)` uygula. Ayrıntılar `CALM_ROOM.md` başındadır. Önceki sade masa ve görünmez atma alanı korunur. Son oyun görüntüsü/kesinti ve taş etkileşimi kontrolleri geçti; GitHub'a yüklenmedi.

Son ek revizyon: salon en/boy %20 büyütüldü; arka plan masalarına üç oturan dayı, kül tablası ve tespihler eklendi. Ana masada yalnızca dört köşe çayı kaldı; yan sehpalar, aksesuarlar, masa köşe süsleri, keçe kenar deseni ve taş atma işaretleri kaldırıldı. Masa artık `okey_table_plain.glb` kullanır; Blender kaynağı `okey_table_plain.blend`. Görünmez geniş atma alanı `Table.is_in_discard_zone` ile el/masa arasında ortaktır. `tests/plain_table_interaction.gd` geçti. Ayrıntılar `assets/models/environment/CALM_ROOM.md` başındadır.

29 Ekim 2026: Ana oyun artık `scripts/world/calm_coffeehouse.gd` ve `assets/models/environment/kahvehane_calm.glb` kullanır. Blender kaynağı `tools/blender/source/kahvehane_calm.blend` / `Kahvehane_Sade_360`. Önceki oda ve karakterler korunmuştur. Çevre dört yöne dağıtıldı; sağ yanda pencere, farklı köşede soba, sade çay ocağı, iki küçük masa ve üç sandalye bulunur. Yeni ince belli bardaklar etkileşimli masaya da bağlandı. Oyun içi HUD/konuşma/tabela yazıları kaldırıldı; taş rakamları ve açılan menüler korunur. Ayrıntılar `assets/models/environment/CALM_ROOM.md` içinde. Dört yönün görünüşü ve yazısız HUD/kesinti/geri dönüş kontrolleri geçti. Performans ölçümü ve GitHub yüklemesi yapılmadı.

# Önceki iş: kahvehane kaplamaları ve soba/çay ocağı

29 Ekim 2026: Oda `assets/models/environment/muhabbet_surfacepass.glb` üzerinden açılıyor. Blender kaynağı `tools/blender/source/muhabbet_surfacepass.blend`; ortak malzeme sistemi `scripts/world/coffeehouse_materials.gd`. Bakır/döküm demir/mermer/sıva/ahşaplar revize edildi, soba ve semaver ayrıntıları eklendi; slogan levhası yerine Boğaz resmi kondu. Ayrıntılar `assets/textures/coffeehouse_pbr/README.md` içinde. Oyun içi görünüş ve kesinti/geri dönüş kontrolleri geçti; performans ölçümü ve GitHub yüklemesi yapılmadı. Aşağıdaki karakter çalışmaları korunmuştur.

# Önceki iş: üç ekstra iskeletli karakter entegre edildi

29 Ekim 2026: GitHub 620674b kaydındaki gözlüklü/tespihli/yaşlı dayılar artık karakter seçimine eklenmiştir. Dört eski karakter korunmuştur. Yeni sunum scripts/world/rigged_patron.gd, kol IK scripts/character/rig_patron_ik.gd dosyasında; ayrıntılar assets/models/dayi_rig/UPSTREAM_NOTES.md içindedir. Entegrasyon testi tests/rigged_patrons_integration.gd geçti. Değişiklikler henüz GitHub'a yüklenmedi. Sabri varyantının asıl modelden bağımsız kalması hâlâ geçerlidir.

# Okey — Gemini için başlangıç

Önce `AGENTS.md`, ardından `GEMINI_DEVIR.md` dosyasını oku.

- Tek çalışma klasörü bu `okey` klasörüdür. Codex, Antigravity ve Gemini aynı yerel dosyalar üzerinden devam eder.
- Güncel karakter çalışması **Sabri Varyant 01**; düzenlenebilir son kaynak `tools/blender/source/sabri_varyant01.blend`.
- Bu dosya, GitHub'daki `ffefb13` kaydından sonra yapılmış ve henüz Git'e kaydedilip yüklenmemiş yerel çalışmadır. Pull/reset ile üzerine yazma.
- Asıl Sabri'yi koru. Varyantı kullanıcı istemeden asıl modelin yerine koyma.
- Kullanıcı göz düzeltmesini beğendi. Gözleri koru; son talep omuz/bilek düzeltmesi ve bilekliğin kaldırılmasıydı.
- Meshy veya başka ücretli üretim servisi çağırma. Model üzerinde Blender MCP ile çalış.
- GitHub'a yalnızca yeni, açık kullanıcı talimatıyla yükle. Performans testi döngülerine girme.
- Güncel dosya ve son durum için `GEMINI_DEVIR.md` esas alınır; eski Antigravity devir metnindeki bilgiler tarihsel olabilir.
