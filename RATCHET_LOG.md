# Ratchet Günlüğü

Geçerli A koşusu 20 Kasım 2026 tarihinde `opencode/deepseek-v4.1-flash-free` ile bağımsız `--standalone` sunucuda, tamamen boş klasörde ve yalnız genel görev promptuyla yapıldı. Oturum kimliği `ses_e073c9058ffeKmX4XSvBA8DXNs` değeridir. JSONL kaydındaki ilk dosya taraması `No files found` sonucunu verir; koşu sonunda çalışma klasörü yine boştur.

| Karşılaşılan gerçek hata | A koşusu kanıtı | Kalıcı kural veya test | Katman |
|---|---|---|---|
| Ajan görevi kural motoru geliştirmek yerine mevcut öğrenci verisini bulup analiz etmek olarak yorumladı. | `evidence/a_run/opencode.jsonl` son metni kullanıcıdan CSV/veri ya da kontrol aracı seçimi istiyor. | `AGENTS.md`: dış veri arama; doğrudan Ruby kural motorunu ve testlerini üret. | Rehber |
| Bir kullanıcı turu sonunda hiçbir uygulama dosyası üretmedi. | İlk tarama `No files found`; `workspace_listing.txt` koşu sonunda da klasörün boş olduğunu kaydediyor. | Zorunlu `lib/ogrenci.rb` ve `lib/devamsizlik_kontrol.rb`; `bin/kontrol` dosya denetimi | Rehber + Sensör |
| `Ogrenci(ad, durum, devamsizlik)` modeli kurulmadı. | A çalışma alanı boş; final yanıtta sınıf veya Ruby kaynağı yok. | Üç alan, geçerli durumlar ve `0..10 Integer` sözleşmesi; geçerli/geçersiz girdi testleri | Rehber + Sensör |
| `%30` sınırı çalıştırılabilir kurala dönüştürülmedi. | A hiçbir kural metodu veya test üretmedi. | `riskli? >= 3`, `kaldi? >= 4`; 2, 3, 4 ve 10 sınır testleri | Rehber + Sensör |
| Durum sorguları ve istenen metaprogramlama tekniği üretilmedi. | A çalışma alanı boş; `define_method`, `aktif?`, `donduruldu?`, `mezun?` yok. | Üç sorguyu durum listesi üzerinden `define_method` ile üretme; kaynak ve davranış testleri | Rehber + Sensör |
| Özgün üçüncü kural üretilmedi. | A final yanıtında akademik kural veya uygulama kaynağı yok. | `telafi_gerekir?`: aktif ve tam 3; olumlu/olumsuz testler | Rehber + Sensör |
| Minitest sensörü üretilmedi. | A çalışma alanı koşu sonunda boş. | `test/ogrenci_test.rb`; bilinmeyen metotta doğal `NoMethodError` dahil 15 test | Sensör |
| Ruby sürümü sabitlenmedi. | A çalışma alanında `.ruby-version` yok. | `.ruby-version` içeriği `3.4`; kancada çalışan sürüm denetimi | Rehber + Sensör |

## B sonucu

Dokuz ratchet kuralının tamamını içeren temiz B klasöründe aynı model ve aynı prompt bir kullanıcı turunda iki uygulama dosyasını üretti. `ruby bin/kontrol` sonucu `15 runs, 38 assertions, 0 failures, 0 errors, 0 skips` ve `KONTROL BAŞARILI` oldu. B oturum kimliği `ses_e07331e7affebzAUwhzKjrry5f` değeridir.

## Yasakların durumu

A koşusu hiç kod üretmediği için `method_missing`, monkey patch veya harici gem ihlali gözlenmedi. Bu yasaklar ödevin sıfır puan koşulları nedeniyle yine de `AGENTS.md`, test ve `bin/kontrol` içinde önleyici güvenlik katmanı olarak tutulur; A'nın yapmış olduğu hata gibi sunulmaz.
