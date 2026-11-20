#!/usr/bin/env ruby
# frozen_string_literal: true

# Windows Ruby mutlak yolu Türkçe karakterlerle OEM kod sayfasında
# çözebildiği için script proje kökünden çalıştırılır ve UTF-8 çalışma
# dizinindeki repository yolu kullanılır.
$LOAD_PATH.unshift(File.join(Dir.pwd, "app", "repositories"))
require "database"

# Şemayı uygular. Idempotenttir; mevcut veritabanı üzerinde tekrar
# çalıştırıldığında tabloları ve kayıtları korur.
database = DevamTakip::Database.new

begin
  database.migrate!
  puts "Şema uygulandı: #{database.path} (user_version: #{database.schema_version})"
ensure
  database.close
end
