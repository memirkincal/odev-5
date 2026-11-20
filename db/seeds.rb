#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require_relative "../app/repositories/database"
require_relative "../app/repositories/student_repository"
require_relative "../app/repositories/attendance_repository"

module DevamTakip
  # Demo verileri. Tüm işlemler repository katmanı üzerinden yapılır ve
  # tekrar çalıştırıldığında aynı kayıtlar güncellenir, çoğalmaz.
  module Seeds
    SESSION_TITLES = {
      1 => "Ruby'ye Giriş",
      2 => "Nesne Yönelimli Tasarım",
      3 => "Bloklar ve Proc'lar",
      4 => "Modüller ve Mixin'ler",
      5 => "Hata Yönetimi",
      6 => "Dosya ve IO İşlemleri",
      7 => "Test ve Minitest",
      8 => "Harness ve Otomasyon",
      9 => "SQLite ile Kalıcılık",
      10 => "Ajan Mimarisi ve Değerlendirme"
    }.freeze

    FIRST_SESSION_DATE = Date.new(2026, 9, 21)

    DEMO_STUDENTS = [
      { name: "Deniz Yılmaz", status: :aktif, absent_sessions: [] },
      { name: "Ece Demir", status: :aktif, absent_sessions: [1, 2, 3] },
      { name: "Kaan Aydın", status: :aktif, absent_sessions: [1, 2, 3, 4, 5] },
      { name: "Selin Kaya", status: :donduruldu, absent_sessions: [2] },
      { name: "Mert Çelik", status: :mezun, absent_sessions: [] }
    ].freeze

    def self.run(database)
      database.migrate!

      attendance = AttendanceRepository.new(database)
      students = StudentRepository.new(database)

      sessions = ensure_sessions(attendance)
      ensure_students(students, attendance, sessions)

      database
    end

    def self.ensure_sessions(attendance)
      existing = attendance.sessions.to_h { |row| [row[:session_no], row] }

      SESSION_TITLES.each do |number, title|
        next if existing.key?(number)

        attendance.create_session(
          session_no: number,
          title: title,
          session_date: FIRST_SESSION_DATE + (number - 1)
        )
      end

      attendance.sessions
    end
    private_class_method :ensure_sessions

    def self.ensure_students(students, attendance, sessions)
      sessions_by_number = sessions.to_h { |row| [row[:session_no], row] }

      DEMO_STUDENTS.each do |demo|
        student = students.all(query: demo[:name]).find { |row| row[:name] == demo[:name] }
        student ||= students.create(name: demo[:name], status: demo[:status])

        if student[:status] != demo[:status]
          student = students.update(student[:id], name: demo[:name], status: demo[:status])
        end

        demo[:absent_sessions].each do |number|
          session = sessions_by_number.fetch(number)
          attendance.set(
            student_id: student[:id],
            course_session_id: session[:id],
            absent: 1
          )
        end
      end
    end
    private_class_method :ensure_students
  end
end

if $PROGRAM_NAME == __FILE__
  database = DevamTakip::Database.new

  begin
    DevamTakip::Seeds.run(database)
    students = DevamTakip::StudentRepository.new(database)
    sessions = DevamTakip::AttendanceRepository.new(database)
    puts "Demo veriler hazır: #{database.path}"
    puts "  Öğrenci: #{students.all.size}"
    puts "  Oturum:  #{sessions.sessions.size}"
  ensure
    database.close
  end
end
