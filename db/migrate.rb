#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../app/repositories/database"

# Şemayı uygular. Idempotenttir; mevcut veritabanı üzerinde tekrar
# çalıştırıldığında tabloları ve kayıtları korur.
database = DevamTakip::Database.new

begin
  database.migrate!
  puts "Şema uygulandı: #{database.path} (user_version: #{database.schema_version})"
ensure
  database.close
end
