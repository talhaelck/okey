# Güncel Gemini devri

Son yerel çalışma ve model için önce GEMINI.md ve GEMINI_DEVIR.md okunmalıdır. Aşağıdaki bilgiler eski devir geçmişidir.

# Güncel esas sürüm ve klasör

Esas sürüm ffefb13. Codex ve Antigravity için tek çalışma klasörü bu okey klasörüdür. Üst klasördeki PROJE_KONUMU.md güncel kaynak bilgisidir. Son-Surum-ffefb13 ayrı sabit arşivdir, üzerinde geliştirme yapılmaz. Aşağıdaki devir geçmiş durumu anlatır; eski commit ve yetki hatası bilgileri artık güncel değildir. GitHub yüklemesi başarıyla tamamlandı.

# Okey projesi — geliştirme devri

## Önce oku
- Kullanıcı bu yerel çalışmanın Antigravity üzerinden sürdürülmesini istedi. Başlangıç kuralları AGENTS.md içinde.
- Godot 4 projesi bu klasördür; başka GitHub sürümünü indirerek bunun üzerine yazma.
- Dal: codex/medium-build-mascots. Son çalışma commit'i: 2f2cc01.
- GitHub: https://github.com/talhaelck/okey.git. Push başarısız oldu: bağlı FatihSygl hesabının yazma yetkisi yok (403). Son çalışma yerelde bulunuyor.
- GitHub'a yalnızca kullanıcı istediğinde yükle. Force push veya reset yapma.

## Kullanıcının son görsel hedefi
Sıcak kehribar ışıklı, koyu ahşap ağırlıklı Türk kıraathanesi; detaylı okey masası, ifade sahibi stilize dayılar ve aynı görsel dilde menüler. Referans bir hedef; mevcut modeller henüz referanstaki sinematik ayrıntı seviyesinde değil. Var olan mekanikleri koruyarak görünümü geliştir. Çalışmayı bitmiş veya referans kalitesine ulaşmış gibi sunma.

## Mevcut durum
- Giriş sahnesi scenes/coffeehouse.tscn; scripts/ui/coffeehouse_menu.gd canlı 3D arka planı, karakter seçimini, yerel masa kurulumunu ve ayarları yönetiyor.
- Oyun sahnesi scenes/main.tscn. Masa/ıstaka odak geçişi, taş alma/bırakma/çalma, yakalanma, Q ile masaya vurma ve S ile sıralama mevcut.
- Dayılar: Sabri, Temel, Rıfkı. Hayvanlar: panda, tavşan, dinozor. İki grup seçim ekranında korunuyor; seçim karşı koltuğu değiştiriyor, yerel oyuncunun tüm bedenini seçmiyor.
- Yeni dayılar Blender kaynaklarından üretildi; basit baş takibi, nefes ve göz kırpma var. Tam iskeletli el/kol IK ve ayrıntılı yüz animasyonu tamamlanmış değil.
- assets/models/table_details içinde ölçüleri korunmuş reçine okey taşı, ince belli çay, Türk kahvesi, tespih, leblebi kâsesi, cam küllük ve yazboz bulunuyor.
- scripts/world/cinematic_coffeehouse.gd iç mekânı ve ışıkları kuruyor; Türk bayrağı, motifler, semaver ve çerçeveli Boğaz çizimleri var.
- Menü ve oyun HUD'u sadeleştirildi. Esc duraklatma, F1 yardım. Çevrimiçi oyun ve yeni sabotaj/modlar uygulanmadı.
- Kullanıcı tercihleri user://coffeehouse.cfg içinde. Hayvan/dayı ve yeşil/bordo seçimini kullanıcı değiştirmiş olabilir; bunu hata sanıp zorla sıfırlama.

## Kaynaklar ve çalıştırma
- Blender üretim betikleri: tools/blender/*.py. Düzenlenebilir kaynaklar tools/blender/source/*.blend; Godot çıktıları assets/models altında.
- 3D düzenlemelerde Blender MCP kullan. Kullanıcının diğer Blender sahnelerini ve kaydedilmemiş çalışmalarını koru. Yeni ücretli servis veya dışarı görsel yükleme kullanma.
- Ana klasörün bir üstündeki Oyunu Ac.cmd oyunu açar. Godot çalıştırıcısı üst klasördeki Godot/Godot_v4.7.2-stable_win64_console.exe.
- Godot editöründe bu klasördeki project.godot dosyasını aç.
- screenshots/ yerel ve git tarafından yok sayılıyor. kiraathane_preview.png dayılı oyun görünümünü, kiraathane_final_character.png karakter ekranını gösteriyor. Diğer görüntüler önceki denemeler olabilir.

## Doğrulama ve dikkat
- tests/table_actions_smoke.gd: PASS (sıralama, sahiplik, masa vurma, çalma/yakalanma, duraklatma).
- tests/coffeehouse_flow_smoke.gd: PASS (menü, iki karakter grubu, örtü seçimi, oyuna geçiş ve duraklatma).
- Oyun içi görüntüler açılıp kontrol edildi; son el modelinde sol el için aynalama geometriye işlendi.
- Kullanıcı tekrarlanan performans ölçümlerinden rahatsız. Açıkça istemedikçe benchmark/optimizasyon döngüsüne girme; değişen alanı ve gerekli regresyonları kontrol et.
- Önceki kısıtlı ortamda user:// log ve shader önbelleği yazma hataları görüldü; bunları oyun mantığı hatalarıyla karıştırma.
- scripts/debug/render_check.gd.uid takip edilmeyen, eski kontrol kalıntısı; oyunun parçası değil. Başka dosyaları sebepsiz silme.

## Devam ederken
Önce mevcut oyunu açıp kullanıcının son referansına göre gerçek görünümü değerlendir. En büyük açık karakterlerin yüz, kıyafet ve el animasyonu kalitesi. Önceki başarısız dayı denemelerine veya arkadaşın farklı sürümüne geri dönme. Kullanıcının yeni talimatını bekle; bu devir notu yeni özellikleri kendiliğinden ekleme talimatı değildir.
