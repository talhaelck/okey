# Yapılacaklar

Sneaky Okey'in yol haritası. Bitenin kutusunu işaretle (`[x]`). Ayrıntılı tasarım: [master.md](master.md) ve [docs/design/](docs/design/).

## 1. Temel oyun
- [x] Kahvehane, masa, ıstakalar, taşlar, dağıtma
- [x] Gözlem ve ıstaka modu, buğu (depth of field)
- [x] Gerçekçi birinci şahıs eller (MPFB), parmak tutuşu, parmakla tempo tutma
- [x] Istakada anında sürükle-bırak; yandaki taşlar kayıp yer açar (sırala tuşu yok)
- [ ] 101 kural motoru: per, seri, okey, açma barajı, işleme, cezalar, puanlama ([101_rules.md](docs/design/101_rules.md))
- [ ] Sıra sistemi: desteden ya da soldan çek, aç / işle, at
- [ ] Masa bölgeleri: herkesin atılan taş yığını, açılan perler alanı
- [ ] Botlar: 101 oynayan, kişilikli (temkinli / hırsız)

## 2. Ses ve his
- [ ] Taş sesleri: tıkırtı, ıstakaya oturma, desteden çekme, masaya atma
- [ ] Kahvehane ortamı: uğultu, televizyondan maç sesi, kaşığın bardağa vurması, sandalye gıcırtısı
- [ ] Oda yankısı (reverb), sesin yönü belli (3D ses)
- [ ] Dayı sesleri: "cık cık", laf atmalar, gülme

## 3. Fiziksel ve riskli çalma
- [ ] Kol masanın üstünden gerçekten uzanır; diğer oyuncular uzanan kolu görür
- [ ] Çalma bölgeleri: yandaki ıstakalar, atılan taşların herhangi biri (sadece üstteki değil), açılmış perlerdeki okey, ortadaki deste ([stealing.md](docs/design/stealing.md))
- [ ] El ve kol çarpışmalı: uzanırken çay bardağına çarparsa bardak şıngırdar, çay dökülür, herkes sese döner
- [ ] Taşlar fizikli: masaya atılan taş seker, kola çarpan taş devrilir
- [ ] "Yakala!" tuşu (otomatik yakalama kalkar), "Taş say!" itirazı, 101 ceza, arkadaş modu
- [ ] Botlar da çalar ve botlar da yakalar

## 4. Çaycı
- [ ] Masanın etrafında dolaşan çaycı NPC, çay dağıtır, boş bardağı toplar
- [ ] Önünden geçtiği an görüşü keser: çalma fırsatı
- [ ] "Ocakçı, iki çay!" diye çağrılabilir

## 5. Kahvehane olayları
- [ ] Televizyonda maç: rastgele "GOOOL!", herkesin dikkati oraya kayar
- [ ] Elektrik kesintisi (karanlık mod)
- [ ] Kapıdan biri girer, kafalar döner
- [ ] Dikkat dağıtma: masaya vurma, tespih şakırdatma ([guncellemeOnerisi.md](guncellemeOnerisi.md))

## 6. Yakalama tekrarı ve klipler
- [ ] Biri yakalanınca son 3 saniye, yakalayanın gözünden ağır çekimde tekrar oynar
- [ ] Bütün ellerin, kafaların ve taşların konumu kare kare kaydedilir (ucuz geri oynatma)
- [ ] Klibi video olarak kaydet / paylaş (TikTok, Shorts)

## 7. Online
- [ ] GodotSteam: Steam lobisi, arkadaş daveti, sunucusuz bağlantı
- [ ] Sunucu-otoriteli: kurallar ve taşların fiziği kurucu oyuncuda çalışır, diğerlerine konumlar gider
- [ ] Sesli sohbet (Steam Voice), konuşan dayının ağzı ve bıyığı oynar
- [ ] Kafa yönü, el pozisyonu, parmak tutuşu senkron

## 8. Görsel ve teknik kalite
- [ ] Gerçek modellenmiş okey taşları: krem bakalit gövde, oyma rakamlar (doku ve normal map), hafif aşınma
- [ ] Oda ışığı önceden hesaplanmış (LightmapGI), yansıma probları, kenar yumuşatma (TAA / FSR)
- [ ] Keçe kumaş shader'ı, masada çay lekesi ve bardak izi (decal), bardaktan buhar, ışıkta toz zerreleri
- [ ] Dayılara iskelet: uzanma, taş alma, işaret etme (Yakala!), gülme, masaya vurma animasyonları; kollarda IK
- [ ] Dayı yüzü: göz kırpma, kaş, ağız açma (sesli sohbet için)
- [ ] Dayılarda deri, kırışıklık ve kumaş detay dokuları (Blender'da bake)
- [ ] Ceza animasyonu: dayıya fizikli şaplak (ragdoll)
- [ ] Performans: orta seviye bilgisayarda 60 FPS

## 9. Ekranlar ([screens.md](docs/design/screens.md))
- [ ] Ana menü (kahvehane önünde)
- [ ] Lobi: oyuncu / bot yuvaları, kural ön ayarları
- [ ] Çok detaylı ve güzel ev kuralları ayar sayfası: her kural açılıp kapanabilir
- [ ] Oyun içi HUD: sıra, süre, puan tablosu
- [ ] El sonu puan tablosu
- [ ] Karakter oluşturucu: bıyık, kasket, kıyafet, aksesuar
