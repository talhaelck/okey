# Sneaky Okey

Arkadaşlarla oynanan, taş çalmalı, şirin 3D okey oyunu (Godot 4.7). Detaylı vizyon: [master.md](master.md).

## Kurulum (Windows)
1. Godot **4.7.2 standart sürümünü (.NET olmayan)** indir: https://godotengine.org/download/archive/4.7.2-stable/
2. Zip'i `C:\Tools\Godot\` klasörüne aç. İçinde `Godot_v4.7.2-stable_win64_console.exe` olmalı.
3. Repoyu klonla, klasörde `.\oyna.cmd` çalıştır ya da dosyaya çift tıkla.
   - İlk açılışta Godot modelleri içe aktarırken birkaç saniye bekleyebilir.

## Kontroller
| Tuş | Ne yapar |
|-----|----------|
| Fare | Etrafa bak |
| Space / Sağ tık | Istakana odaklan (etraf buğulanır) ya da geri dön |
| Sol tık | Taş al / bırak (gözlem modunda nişangâhla, ıstaka modunda fareyle) |
| Esc | Fareyi serbest bırak |

## Demo'da ne var
- **Son El gece kahvehanesi:** sıcak sarkıtlar, yağmurlu pencereler, ahşap paneller, çay ocağı ve bakır semaver.
- Taranmış ahşap/sıva yüzeyleri, kumaş/keçe/kürk/pul ayrıntıları, pirinç kenarlar ve çay buharı. PBR dokular CC0 lisanslıdır; kaynaklar `assets/CREDITS.md` içinde.
- Üç orta kilolu, oturan 3D karakter: yeşil kapüşonlu panda, pembe kapüşonlu tavşan ve sarı kapüşonlu dinozor. Nefes alma, göz kırpma, baş çevirme ve yakalayınca baş sallama hareketleri vardır.
- Kendi ıstakandaki taşları sürükleyip dizebilir, ortadaki desteden taş çekebilir, masaya taş atabilirsin.
- Yanındakilerin ıstakasından taş çalabilirsin. Elinde çalıntı taş varken biri sana bakarsa **yakalanırsın**.
- Kafasının üstünde sarı "!" çıkan karakter sana bakıyor demektir.

## Claude Code ile geliştirme
Proje kuralları ve mimari [CLAUDE.md](CLAUDE.md) dosyasında. Claude Code bu dosyayı otomatik okur.

## Karakterleri inceleme
- Godot'ta `scenes/character_preview.tscn` sahnesini açıp **F6**'ya bas: üç karakteri nötr ışıkta yakından gösterir.
- Modeller referans görselden esinlenen, kodla oluşturulmuş stilize 3D uyarlamalardır; harici model eklentisi gerektirmez.
- Karakter ve etkileşim kontrolü: `godot --headless --path . --script tests/mascot_smoke.gd`.

## Görsel kontroller
- Genel görünüm: `godot --path . -- --screenshot=screenshots/son-el-overview.png`.
- Istaka ve elde taş: `godot --path . -- --screenshot=screenshots/son-el-focus.png --focus --hold`.
- Pencere tarafı: `godot --path . -- --screenshot=screenshots/son-el-window.png --yaw=1.15 --pitch=0.02`.
- Kısa GPU ölçümü: `godot --path . --script scripts/debug/render_check.gd`. Isınmadan sonra 240 kare ölçer; bu kısa sahne testi tam oyun performansı garantisi değildir.
- Görsel değişikliklerle birlikte taş çekme, yan ıstakalara erişme, çalma, bırakma, yakalanma ve eski glTF karakter desteği test edilir.
