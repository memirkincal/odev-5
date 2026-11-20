# Proje Anayasası

1. Ruby sürümü `3.4` olmalıdır. Yalnızca standart kütüphane ve Minitest kullanılabilir.
2. Uygulama yalnızca `lib/ogrenci.rb` ve `lib/devamsizlik_kontrol.rb` dosyalarında tutulmalıdır.
3. `Ogrenci`, `ad`, `durum` ve `devamsizlik` alanlarını anahtar sözcüklerle alır. `durum` yalnızca `:aktif`, `:donduruldu`, `:mezun`; `devamsizlik` yalnızca `0..10` aralığında bir `Integer` olabilir. Geçersiz girdi `ArgumentError` üretmelidir.
4. `aktif?`, `donduruldu?` ve `mezun?` sorguları bir durum listesi üzerinden `define_method` ile üretilmelidir. `method_missing` ve standart sınıflara monkey patch kesinlikle yasaktır.
5. `DevamsizlikKontrol.new(ogrenci)` üç açık sorgu sunar: `riskli?` devamsızlık `>= 3`, `kaldi?` devamsızlık `>= 4`, `telafi_gerekir?` ise öğrenci aktif ve devamsızlığı tam `3` olduğunda doğrudur.
6. Tam `3` devamsızlık risklidir fakat kalmış değildir. Bu sınır değer değiştirilemez.
7. Bilinmeyen sorgular Ruby'nin doğal `NoMethodError` hatasını üretmelidir.
8. Tamamlanma koşulu: `ruby bin/kontrol` başarıyla bitmelidir.
9. Bu görev dış veri analizi değildir. CSV, veritabanı veya öğrenci kaydı arama; doğrudan yeniden kullanılabilir Ruby kural motorunu ve testlerini üret.
