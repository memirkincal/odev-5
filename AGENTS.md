# Proje Anayasası

1. Ruby sürümü `3.4` olmalıdır. Ödevin domain çekirdeği yalnızca standart kütüphane ve Minitest kullanabilir; web katmanının sabitlenmiş bağımlılıkları `Gemfile` ile sınırlıdır.
2. Bütün akademik iş kuralları yalnızca `lib/ogrenci.rb` ve `lib/devamsizlik_kontrol.rb` dosyalarında tutulmalıdır. Web, repository ve görünüm katmanları bu kuralları tekrar yazamaz.
3. `Ogrenci`, `ad`, `durum` ve `devamsizlik` alanlarını anahtar sözcüklerle alır. `durum` yalnızca `:aktif`, `:donduruldu`, `:mezun`; `devamsizlik` yalnızca `0..10` aralığında bir `Integer` olabilir. Geçersiz girdi `ArgumentError` üretmelidir.
4. `aktif?`, `donduruldu?` ve `mezun?` sorguları bir durum listesi üzerinden `define_method` ile üretilmelidir. `method_missing` ve standart sınıflara monkey patch kesinlikle yasaktır.
5. `DevamsizlikKontrol.new(ogrenci)` üç açık sorgu sunar: `riskli?` devamsızlık `>= 3`, `kaldi?` devamsızlık `>= 4`, `telafi_gerekir?` ise öğrenci aktif ve devamsızlığı tam `3` olduğunda doğrudur.
6. Tam `3` devamsızlık risklidir fakat kalmış değildir. Bu sınır değer değiştirilemez.
7. Bilinmeyen sorgular Ruby'nin doğal `NoMethodError` hatasını üretmelidir.
8. Tamamlanma koşulu: `ruby bin/kontrol` başarıyla bitmelidir.
9. Bu görev dış veri analizi değildir. CSV, veritabanı veya öğrenci kaydı arama; doğrudan yeniden kullanılabilir Ruby kural motorunu ve testlerini üret.
10. Tam uygulama katmanı Sinatra + SQLite kullanır. SQL yalnızca `db/` ve `app/repositories/` altında bulunabilir; HTTP rotaları SQL içeremez.
11. Gerçek `data/*.db` dosyaları Git'e eklenmez. Database testleri geçici dosya kullanır ve kendi verisini temizler.
12. A/B deney kanıtları ve mevcut domain testleri geçmiş kayıt kabul edilir; web geliştirmesi bunları değiştiremez.
