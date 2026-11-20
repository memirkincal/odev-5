# DeepSeek Database Ajanı Görevi

## Rol

Ruby 3.4 ve SQLite konusunda çalışan persistence mühendisisin. Bu çalışma alanı `db-agent` dalıdır. Başka bir ajan aynı anda web iskeletini geliştirmektedir; dosya sahipliği sınırını kesinlikle aşma.

Önce `AGENTS.md` ve `docs/APP_SCOPE.md` dosyalarını tamamen oku.

## Yazabileceğin dosyalar

Yalnızca aşağıdaki dosyaları oluştur veya değiştir:

- `db/schema.sql`
- `db/migrate.rb`
- `db/seeds.rb`
- `app/repositories/database.rb`
- `app/repositories/student_repository.rb`
- `app/repositories/attendance_repository.rb`
- `app/repositories/audit_log_repository.rb`
- `test/database_test.rb`

Bu listenin dışındaki hiçbir dosyayı değiştirme. Özellikle `lib/**`, `app.rb`, `Gemfile`, `views/**`, `public/**`, `README.md`, `AGENTS.md` ve A/B kanıtlarına dokunma.

## Teknik sınırlar

- Ruby 3.4 kullan.
- Yalnız mevcut `sqlite3` gem'i, stdlib ve Minitest kullan.
- Harici servis, Supabase, PostgreSQL, MCP veya ağ bağlantısı kullanma.
- SQL enjeksiyonuna karşı her kullanıcı değerini parametreli sorguyla işle.
- Her SQLite bağlantısında `PRAGMA foreign_keys = ON` etkin olsun.
- Domain eşiklerini (`>= 3`, `>= 4`) repository içinde tekrar yazma. Repository yalnız veri sağlar.
- Varsayılan veritabanı yolu `data/devamsizlik.db`; `DB_PATH` ortam değişkeniyle değiştirilebilir.
- Testler gerçek `data/devamsizlik.db` dosyasını kullanamaz; `Dir.mktmpdir` altında geçici DB oluşturmalıdır.

## Şema

### `students`

- `id` INTEGER primary key autoincrement
- `name` TEXT, boş olamaz
- `status` TEXT; yalnız `aktif`, `donduruldu`, `mezun`
- `created_at`, `updated_at` TEXT ve boş olamaz

### `course_sessions`

- `id` INTEGER primary key autoincrement
- `session_no` INTEGER; yalnız 1..10 ve unique
- `session_date` TEXT nullable
- `title` TEXT boş olamaz
- `created_at` TEXT boş olamaz

### `attendance_records`

- `id` INTEGER primary key autoincrement
- `student_id` foreign key; öğrenci silinince cascade
- `course_session_id` foreign key; oturum silinince cascade
- `absent` INTEGER; yalnız 0 veya 1
- `created_at`, `updated_at` TEXT
- Öğrenci + oturum çifti unique

### `audit_logs`

- `id` INTEGER primary key autoincrement
- `student_id` nullable foreign key; öğrenci silinince null
- `action` TEXT boş olamaz
- `entity_type` TEXT boş olamaz
- `entity_id` INTEGER nullable
- `before_json`, `after_json` TEXT nullable
- `created_at` TEXT boş olamaz

Gerekli indexleri ekle. `schema.sql` tekrar çalıştırıldığında hata vermemeli.

## Ruby sınıf sözleşmeleri

Sınıfları `DevamTakip` modülü altında tanımla.

### `DevamTakip::Database`

- `initialize(path: ENV.fetch("DB_PATH", ...))`
- parent dizini güvenli biçimde oluşturur
- bağlantıyı açar, hash sonuçlarını etkinleştirir, foreign key açar
- `execute`, `get_first_row`, `transaction`, `close`
- `migrate!` şemayı idempotent uygular

### `DevamTakip::StudentRepository`

- `all(status: nil, query: nil)`
- `find(id)`
- `create(name:, status:)`
- `update(id, name:, status:)`
- `delete(id)`
- Dönen kayıtlar symbol-keyed Hash olsun.
- Liste kayıtlarında `absence_count`, 10 oturum üzerinden hesaplanmış olarak yer alsın.

### `DevamTakip::AttendanceRepository`

- `set(student_id:, course_session_id:, absent:)` upsert yapar
- `for_student(student_id)` on oturum sırasıyla kayıt döndürür
- `absence_count(student_id)`
- `session_summary(course_session_id)`

### `DevamTakip::AuditLogRepository`

- `record(student_id:, action:, entity_type:, entity_id:, before_data:, after_data:)`
- Hash verilerini JSON olarak saklar
- `recent(limit: 50)`
- `for_student(student_id, limit: 50)`

Repository katmanında zaman damgalarını UTC ISO 8601 olarak üret.

## Migration ve demo verileri

- `ruby db/migrate.rb` idempotent çalışsın.
- `ruby db/seeds.rb` önce migration çalıştırsın.
- Seed işlemi 1..10 arasındaki on oturumu unique biçimde oluştursun.
- En az beş demo öğrenci eklesin: normal, tam 3 riskli, 4+ kalmış, dondurulmuş ve mezun örnekleri.
- Seed tekrar çalıştırıldığında demo verileri çoğalmamalı.

## Testler

`test/database_test.rb` en az şunları doğrulasın:

1. Migration iki kez çalışabilir.
2. On ders oturumu oluşturulabilir; 0, 11 ve duplicate oturum reddedilir.
3. Öğrenci CRUD çalışır.
4. Geçersiz durum ve boş ad reddedilir.
5. Devam kaydı upsert çalışır ve duplicate üretmez.
6. Devamsızlık sayısı doğru hesaplanır.
7. Öğrenci silinince devam kayıtları cascade silinir.
8. Audit log JSON verisini geri okuyabilir.
9. Arama ve durum filtresi parametreli sorguyla çalışır.
10. Test sonunda geçici DB kapatılır ve temizlenir.

## Bitirme koşulları

Sırayla çalıştır:

```text
bundle check
bundle exec ruby test/database_test.rb
bundle exec ruby bin/kontrol
git diff --check
```

Tümü yeşil olmadan görevi tamamlanmış sayma. Testleri başarısız davranışı gizlemek için gevşetme.

Başarılı olduğunda yalnız izin verilen dosyaları şu mesajla commit et:

```text
SQLite persistence katmanını ekle
```

Final yanıtında oluşturulan dosyaları, test sayısını, commit hashini ve bilinen sınırlamaları yaz.
