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
- Kendi ıstakandaki taşları sürükleyip dizebilir, ortadaki desteden taş çekebilir, masaya taş atabilirsin.
- Yanındakilerin ıstakasından taş çalabilirsin. Elinde çalıntı taş varken biri sana bakarsa **yakalanırsın**.
- Kafasının üstünde sarı "!" çıkan karakter sana bakıyor demektir.

## Claude Code ile geliştirme
Proje kuralları ve mimari [CLAUDE.md](CLAUDE.md) dosyasında. Claude Code bu dosyayı otomatik okur.
