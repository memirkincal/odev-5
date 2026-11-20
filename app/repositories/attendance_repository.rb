# frozen_string_literal: true

require "date"
require "time"
require_relative "database"

module DevamTakip
  # Ders oturumları ve öğrenci bazlı devam kayıtları.
  #
  # Oturum numarası 1..10 aralığıyla sınırlıdır. Bu sınıf devamsızlığın
  # riskli ya da kalma anlamına gelip gelmediğine karar vermez; yalnızca
  # ham kayıtları ve sayıları sağlar.
  class AttendanceRepository
    SESSION_NO_RANGE = (1..10).freeze

    def initialize(database)
      unless database.is_a?(Database)
        raise ArgumentError, "database bir DevamTakip::Database olmalıdır"
      end

      @database = database
    end

    # Yeni bir ders oturumu ekler. Aralık dışı veya tekrarlanan numara reddedilir.
    def create_session(session_no:, title:, session_date: nil)
      number = normalize_session_no(session_no)
      clean_title = normalize_title(title)
      date = normalize_date(session_date)

      if session(number)
        raise ArgumentError, "#{number} numaralı oturum zaten kayıtlıdır"
      end

      @database.execute(
        "INSERT INTO course_sessions (session_no, session_date, title, created_at) VALUES (?, ?, ?, ?)",
        [number, date, clean_title, now]
      )
      session(number)
    rescue SQLite3::ConstraintException => error
      raise ArgumentError, "oturum kaydedilemedi: #{error.message}"
    end

    # On oturumu numara sırasıyla döndürür.
    def sessions
      @database.all(<<~SQL)
        SELECT id, session_no, session_date, title, created_at
          FROM course_sessions
         ORDER BY session_no ASC
      SQL
    end

    def session(session_no)
      @database.get_first_row(
        "SELECT id, session_no, session_date, title, created_at FROM course_sessions WHERE session_no = ?",
        [normalize_session_no(session_no)]
      )
    end

    # Öğrenci/oturum çifti için kayıt varsa günceller, yoksa ekler (upsert).
    def set(student_id:, course_session_id:, absent:)
      student = normalize_id(student_id, "student_id")
      course_session = normalize_id(course_session_id, "course_session_id")
      flag = normalize_absent(absent)
      timestamp = now

      @database.execute(<<~SQL, [student, course_session, flag, timestamp, timestamp])
        INSERT INTO attendance_records (student_id, course_session_id, absent, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (student_id, course_session_id)
        DO UPDATE SET absent = excluded.absent, updated_at = excluded.updated_at
      SQL

      find_record(student, course_session)
    end

    # On oturumun tamamını sırayla döndürür. Kaydı olmayan oturumlarda
    # `absent` ve `attendance_id` nil olur.
    def for_student(student_id)
      student = normalize_id(student_id, "student_id")

      @database.all(<<~SQL, [student])
        SELECT cs.id AS course_session_id,
               cs.session_no,
               cs.session_date,
               cs.title,
               ar.id AS attendance_id,
               ar.absent,
               ar.created_at,
               ar.updated_at
          FROM course_sessions cs
          LEFT JOIN attendance_records ar
                 ON ar.course_session_id = cs.id
                AND ar.student_id = ?
         WHERE cs.session_no BETWEEN 1 AND 10
         ORDER BY cs.session_no ASC
      SQL
    end

    def absence_count(student_id)
      student = normalize_id(student_id, "student_id")
      row = @database.get_first_row(<<~SQL, [student])
        SELECT COUNT(*) AS total
          FROM attendance_records ar
          JOIN course_sessions cs ON cs.id = ar.course_session_id
         WHERE ar.student_id = ?
           AND ar.absent = 1
           AND cs.session_no BETWEEN 1 AND 10
      SQL

      row[:total]
    end

    # Oturum yoksa nil; varsa toplam/gelen/gelmeyen sayılarını döndürür.
    def session_summary(course_session_id)
      session_id = normalize_id(course_session_id, "course_session_id")
      row = @database.get_first_row(<<~SQL, [session_id])
        SELECT cs.id AS course_session_id,
               cs.session_no,
               cs.title,
               COUNT(ar.id) AS total_records,
               COALESCE(SUM(ar.absent), 0) AS absent_count
          FROM course_sessions cs
          LEFT JOIN attendance_records ar ON ar.course_session_id = cs.id
         WHERE cs.id = ?
         GROUP BY cs.id
      SQL
      return nil if row.nil?

      row.merge(present_count: row[:total_records] - row[:absent_count])
    end

    private

    def find_record(student_id, course_session_id)
      @database.get_first_row(<<~SQL, [student_id, course_session_id])
        SELECT id, student_id, course_session_id, absent, created_at, updated_at
          FROM attendance_records
         WHERE student_id = ?
           AND course_session_id = ?
      SQL
    end

    def now
      Time.now.utc.iso8601(6)
    end

    def normalize_session_no(value)
      return value if value.is_a?(Integer) && SESSION_NO_RANGE.cover?(value)

      raise ArgumentError, "session_no #{SESSION_NO_RANGE} aralığında bir Integer olmalıdır"
    end

    def normalize_title(value)
      return value.strip if value.is_a?(String) && !value.strip.empty?

      raise ArgumentError, "başlık boş olmayan bir String olmalıdır"
    end

    def normalize_date(value)
      return nil if value.nil?
      return value.to_s if value.is_a?(Date)

      if value.is_a?(String) && !value.strip.empty?
        return Date.parse(value.strip).to_s
      end

      raise ArgumentError, "session_date nil, Date ya da ISO 8601 tarih metni olmalıdır"
    rescue Date::Error
      raise ArgumentError, "session_date geçerli bir tarih olmalıdır"
    end

    def normalize_id(value, label)
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{label} pozitif bir Integer olmalıdır"
    end

    def normalize_absent(value)
      return 1 if value == true
      return 0 if value == false
      return value if [0, 1].include?(value)

      raise ArgumentError, "absent true, false, 0 veya 1 olmalıdır"
    end
  end
end
