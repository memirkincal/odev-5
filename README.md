# Öğrenci ve Devamsızlık Kural Motoru

Ruby 3.4 ile yazılmış bu proje, bir öğrencinin 10 oturumluk devamsızlık durumunu üç açık kuralla değerlendirir:

- `riskli?`: devamsızlık `>= 3`
- `kaldi?`: devamsızlık `>= 4`
- `telafi_gerekir?`: öğrenci aktif ve devamsızlığı tam `3`

`Ogrenci` yalnızca `:aktif`, `:donduruldu` ve `:mezun` durumlarını kabul eder. `aktif?`, `donduruldu?` ve `mezun?` sorguları `define_method` ile üretilir; `method_missing` ve monkey patch kullanılmaz.

## Çalıştırma

Gereksinim Ruby 3.4'tür. Harici gem gerekmez; yalnızca Ruby standart kütüphanesi ve Minitest kullanılır.

```sh
ruby bin/kontrol
```

Dosyalar değiştikçe kontrolü yeniden çalıştırmak için:

```sh
ruby bin/kontrol --watch
```

Doğrudan test komutu:

```sh
ruby -Itest test/ogrenci_test.rb
```

## Örnek kullanım

```ruby
require_relative "lib/ogrenci"
require_relative "lib/devamsizlik_kontrol"

ogrenci = Ogrenci.new(ad: "Ada", durum: :aktif, devamsizlik: 3)
kontrol = DevamsizlikKontrol.new(ogrenci)

kontrol.riskli?          # true
kontrol.kaldi?           # false
kontrol.telafi_gerekir?  # true
```

## A/B Koşusu ve Ölçüm Raporu

Her iki geçerli koşu da birbirinden bağımsız `--standalone` OpenCode sunucusunda, `opencode/deepseek-v4.1-flash-free` modeliyle ve aynı tek kullanıcı promptuyla yapıldı:

> Öğrenci devamsızlık kontrolü yap, devamsızlık sınırı %30'dur.

A koşusu tamamen boş bir klasörde başladı. B koşusu uygulama kaynakları bulunmayan fakat `AGENTS.md`, Minitest sensörleri, `.ruby-version` ve `bin/kontrol` içeren temiz bir klasörde başladı.

Bir kullanıcı promptu ve karşılık gelen ajan cevabı bir **tur** olarak sayıldı. `İç adım`, OpenCode JSONL kaydındaki `step_finish`; araç çağrısı `tool_use` olayıdır. Token ve maliyet değerleri OpenCode oturum kaydından alınmıştır.

| Ölçüm | A — rehbersiz | B — harness ile |
|---|---:|---:|
| Kullanıcı turu | 1 | 1 |
| OpenCode iç adımı | 5 | 5 |
| Araç çağrısı | 5 | 8 |
| Girdi tokenı | 19.936 | 11.303 |
| Çıktı tokenı | 781 | 1.736 |
| Reasoning tokenı | 886 | 1.100 |
| Input + output + reasoning | 21.603 | 14.139 |
| Cache read | 49.664 | 48.768 |
| Raporlanan maliyet | 0 | 0 |
| Üretilen uygulama dosyası | 0 | 2 |
| Kabul testi | Uygulama/test yok; başarısız | 15 test, 38 assertion; başarılı |
| İlk tur sonunda teslim edilebilirlik | Hayır | Evet |

### A koşusu gözlemleri

Ajan boş çalışma klasörünü doğruladı fakat görevi bir kural motoru geliştirme işi yerine mevcut öğrenci verisini bulup analiz etme işi olarak yorumladı. Çalışma alanında veri bulamayınca kullanıcıdan CSV/veri veya teknoloji seçimi istedi ve hiçbir uygulama ya da test dosyası üretmedi. Böylece ilk tur sonunda ölçülebilir kabul kriterlerinin hiçbiri çalıştırılamadı.

### Ratchet

A sonucundaki belirsizlikler kalıcı altyapıya çevrildi:

- `AGENTS.md`, istenen Ruby sürümünü, dosya/sınıf mimarisini, 10 oturum modelini ve sert sınır kurallarını tanımladı.
- `test/ogrenci_test.rb`, 2/3/4 sınırlarını, `define_method` sorgularını, geçersiz girdileri, bilinmeyen metodu ve özgün kuralı sensör hâline getirdi.
- `bin/kontrol`, zorunlu dosya, sürüm, sözdizimi, yasaklı desen ve Minitest kontrollerini tek komutta birleştirdi.

### B koşusu gözlemleri

Aynı model aynı ham promptla harness'i okuyarak `lib/ogrenci.rb` ve `lib/devamsizlik_kontrol.rb` dosyalarını üretti. Tek kullanıcı turunda `15 runs, 38 assertions, 0 failures, 0 errors, 0 skips` sonucu elde edildi.

İki koşu da bir kullanıcı turu sürdüğü için tur sayısı azalmadı; başarı niteliği değişti: A bir tur sonunda teslim edilemezken B bir tur sonunda kabul testini geçti. Input + output + reasoning toplamı `21.603` değerinden `14.139` değerine düştü; bu deneyde yaklaşık `%34,6` azalma ölçüldü. Her iki koşunun raporlanan maliyeti `0` oldu.

Olay sırasını koruyan JSONL kayıtları, model/prompt kanıtı, token özeti ve kontrol çıktıları [A koşusu](evidence/a_run/) ile [B koşusu](evidence/b_run/) klasörlerindedir. A kaydındaki ödevle ilgisiz dış araç çıktıları başka projeye ait şema bilgisini yayımlamamak için redakte edilmiştir; boş klasör kanıtı, olaylar, metrikler ve ajan cevabı korunmuştur. Hataların kalıcı kurallara dönüşümü [RATCHET_LOG.md](RATCHET_LOG.md) içinde gösterilir.

## Proje yapısı

```text
lib/ogrenci.rb
lib/devamsizlik_kontrol.rb
test/ogrenci_test.rb
bin/kontrol
AGENTS.md
CLAUDE.md -> AGENTS.md
RATCHET_LOG.md
evidence/a_run/
evidence/b_run/
.ruby-version
```

## Yapamadıklarım

- A koşusunun kaç ek düzeltme turunda başarılı olacağı ölçülmedi. Ham A sonucunu değiştirmemek için aynı oturuma sonradan yönlendirici bir mesaj gönderilmedi.
