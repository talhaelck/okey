# Geliştirme ilkeleri

Amaç, geliştirme kalitesini, oyun performansını ve mevcut özellikleri koruyarak gereksiz token ve araç tüketimini azaltmaktır.

- Her görevde önce ilgili dosyaları ve doğrudan bağımlılıklarını incele; tüm projeyi baştan tarama.
- Önceden incelenmiş, değişmemiş dosyaları gerekmedikçe tekrar okuma. Gerektiğinde değişiklikleri ve hedefli bölümleri kontrol et.
- Küçük görevlerde hedefli düzenlemeler yap; gereksiz yeniden yazım ve kapsam genişletmeden kaçın.
- Büyük görevlerde önce ilgili sistemi analiz et, sonra kontrollü adımlarla uygula.
- Çalışan sistemleri, mekanikleri, tasarımları ve özellikleri koru. Görsel kalite ile oyun performansını birlikte gözet.
- Blender MCP'yi yalnızca 3D model veya sahne işlemi gerektiğinde kullan. Mevcut modelleri gereksiz yere değiştirme; çıktıları Godot 4 ile uyumlu aktar.
- Ekran görüntüsü, render ve araç çağrılarını ihtiyaç kadar kullan; değişmeyen sonucu tekrar tekrar kontrol etme.
- Testleri değişikliğin kapsamı ve riskine göre seç. Kritik değişikliklerde gerekli kontrolleri atlama; yeni bir neden yoksa başarılı kontrolleri tekrarlama.
- Durum mesajlarını, terminal çıktılarını ve açıklamaları kısa ve ilgili tut.
- Görev sonunda yalnızca yapılan değişiklikleri, test sonuçlarını ve varsa önemli sorunları özetle.
- GitHub'a yükleme (push veya PR oluşturma) işlemini yalnızca kullanıcı açıkça istediğinde yap.
- Görsel çalışmalarda önce oyun içi görünüşü tamamla; kullanıcı özellikle istemedikçe performans ölçümü ve optimizasyon döngüsüne girme. Yalnızca açılışı ve değişen görünüşü kontrol et.
