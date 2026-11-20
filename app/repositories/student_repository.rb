# frozen_string_literal: true

require "time"
require_relative "database"

module DevamTakip
  # Öğrenci kayıtlarının SQLite üzerindeki CRUD işlemleri.
  #
  # Bu sınıf yalnızca veriyi taşır; riskli/kaldı gibi akademik eşikler
  # domain katmanında (DevamsizlikKontrol) kalır.
  class StudentRepository
    STATUSES = %w[aktif donduruldu mezun].freeze

    # Devamsızlık sayısı yalnızca 1..10 numaralı ders oturumları üzerinden
    # hesaplanır; oturum tanımı henüz olmayan kayıtlar sayıya katılmaz.
    ABSENCE_COUNT_SQL = <<~SQL
      (SELECT COUNT(*)
         FROM attendance_records ar
         JOIN course_sessions cs ON cs.id = ar.course_session_id
        WHERE ar.student_id = s.id
          AND ar.absent = 1
          AND cs.session_no BETWEEN 1 AND 10)
    SQL

    SELECT_SQL = <<~SQL
      SELECT s.id, s.name, s.status, s.created_at, s.updated_at,
             #{ABSENCE_COUNT_SQL} AS absence_count
        FROM students s
    SQL

    def initialize(database)
      unless database.is_a?(Database)
        raise ArgumentError, "database bir DevamTakip::Database olmalıdır"
      end

      @database = database
    end

    # Durum ve ad araması isteğe bağlıdır; tüm değerler parametreli sorguya gider.
    def all(status: nil, query: nil)
      conditions = []
      params = []

      unless status.nil?
        conditions << "s.status = ?"
        params << normalize_status(status)
      end

      search = query.to_s.strip
      unless search.empty?
        conditions << "s.name LIKE ? ESCAPE '\\'"
        params << "%#{escape_like(search)}%"
      end

      sql = SELECT_SQL.dup
      sql << " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
      sql << " ORDER BY s.name COLLATE NOCASE ASC, s.id ASC"

      @database.all(sql, params).map { |row| build(row) }
    end

    def find(id)
      row = @database.get_first_row("#{SELECT_SQL} WHERE s.id = ?", [normalize_id(id)])
      row.nil? ? nil : build(row)
    end

    def create(name:, status:)
      clean_name = normalize_name(name)
      clean_status = normalize_status(status)
      timestamp = now

      @database.execute(
        "INSERT INTO students (name, status, created_at, updated_at) VALUES (?, ?, ?, ?)",
        [clean_name, clean_status, timestamp, timestamp]
      )
      find(last_insert_id)
    end

    # Kayıt yoksa nil döndürür; bulunursa güncel kaydı döndürür.
    def update(id, name:, status:)
      clean_name = normalize_name(name)
      clean_status = normalize_status(status)
      student_id = normalize_id(id)
      return nil if find(student_id).nil?

      @database.execute(
        "UPDATE students SET name = ?, status = ?, updated_at = ? WHERE id = ?",
        [clean_name, clean_status, now, student_id]
      )
      find(student_id)
    end

    # Kayıt silindiyse true, bulunamadıysa false döndürür.
    def delete(id)
      student_id = normalize_id(id)
      return false if find(student_id).nil?

      @database.execute("DELETE FROM students WHERE id = ?", [student_id])
      true
    end

    private

    def build(row)
      row.merge(status: row[:status].to_sym)
    end

    def last_insert_id
      @database.get_first_row("SELECT last_insert_rowid() AS id")[:id]
    end

    def now
      Time.now.utc.iso8601(6)
    end

    def normalize_name(name)
      return name.strip if name.is_a?(String) && !name.strip.empty?

      raise ArgumentError, "ad boş olmayan bir String olmalıdır"
    end

    def normalize_status(status)
      value = status.is_a?(Symbol) ? status.to_s : status
      return value if value.is_a?(String) && STATUSES.include?(value)

      raise ArgumentError, "durum #{STATUSES.join(', ')} değerlerinden biri olmalıdır"
    end

    def normalize_id(id)
      return id if id.is_a?(Integer) && id.positive?

      raise ArgumentError, "id pozitif bir Integer olmalıdır"
    end

    # LIKE joker karakterlerini kaçırır; arama metni veri olarak kalır.
    def escape_like(value)
      value.gsub(/[\\%_]/) { |character| "\\#{character}" }
    end
  end
end
