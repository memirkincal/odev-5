# Tam Uygulama Kapsamı

## Amaç

Mevcut Ruby kural motorunu değiştirmeden, SQLite kalıcılığı ve Türkçe web yönetim paneli eklemek.

## Mimari sınırlar

- `lib/`: Ödevin bağımsız domain motoru; web veya veritabanı bağımlılığı alamaz.
- `app/repositories/`: SQLite erişimi; domain kurallarını tekrar yazamaz.
- `app.rb`: HTTP rotaları ve yönlendirme; SQL içeremez.
- `views/` ve `public/`: Sunum katmanı; iş kuralı içeremez.
- `db/`: Şema, migration ve demo verileri.
- `test/`: Domain, repository, route ve smoke testleri.

## Veritabanı sözleşmesi

Tablolar:

1. `students`: ad ve akademik durum.
2. `course_sessions`: 1..10 oturum, tarih ve başlık.
3. `attendance_records`: öğrenci/oturum bazında geldi-gelmedi kaydı.
4. `audit_logs`: veri değişikliklerinin zamanı, eylemi ve özet değerleri.

Devamsızlık sayısı `attendance_records` üzerinden hesaplanır ve mevcut `Ogrenci` ile `DevamsizlikKontrol` nesnelerine aktarılır.

## Faz 1 dosya sahipliği

### İskelet kolu

- `Gemfile`
- `config.ru`
- `app.rb`
- `views/**`
- `public/**`
- `docs/APP_SCOPE.md`

### Database ajanı

- `db/schema.sql`
- `db/migrate.rb`
- `db/seeds.rb`
- `app/repositories/database.rb`
- `app/repositories/student_repository.rb`
- `app/repositories/attendance_repository.rb`
- `app/repositories/audit_log_repository.rb`
- `test/database_test.rb`

Database ajanı bu listenin dışındaki dosyalara dokunamaz.

## Faz 1 kabul koşulları

- Mevcut `ruby bin/kontrol` yeşil kalır.
- `/health` JSON olarak `status: ok` döndürür.
- Ana sayfa ve 404 ekranı render edilir.
- Database ajanı boş veritabanını idempotent biçimde kurabilir.
- Şema yabancı anahtarları, benzersiz kısıtları ve 1..10 oturum sınırını korur.
- Repository testleri geçici SQLite dosyasıyla çalışır; gerçek `data/*.db` Git'e girmez.
