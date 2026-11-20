# frozen_string_literal: true

require "json"
require "time"
require_relative "database"

module DevamTakip
  # Veri değişikliklerinin denetim kayıtlarını tutar.
  #
  # Önce/sonra durumları JSON metni olarak saklanır; okurken tekrar Hash'e
  # çevrilir. Zaman damgaları UTC ISO 8601 biçimindedir.
  class AuditLogRepository
    def initialize(database)
      unless database.is_a?(Database)
        raise ArgumentError, "database bir DevamTakip::Database olmalıdır"
      end

      @database = database
    end

    def record(student_id:, action:, entity_type:, entity_id: nil, before_data: nil, after_data: nil)
      student = normalize_optional_id(student_id, "student_id")
      entity = normalize_optional_id(entity_id, "entity_id")
      clean_action = normalize_text(action, "action")
      clean_entity_type = normalize_text(entity_type, "entity_type")

      sql = <<~SQL
        INSERT INTO audit_logs (student_id, action, entity_type, entity_id, before_json, after_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      SQL

      params = [
        student,
        clean_action,
        clean_entity_type,
        entity,
        encode_json(before_data, "before_data"),
        encode_json(after_data, "after_data"),
        now
      ]

      @database.execute(sql, params)

      find_by_id(last_insert_id)
    end

    def recent(limit: 50)
      fetch(<<~SQL, [normalize_limit(limit)])
        SELECT id, student_id, action, entity_type, entity_id,
               before_json, after_json, created_at
          FROM audit_logs
         ORDER BY created_at DESC, id DESC
         LIMIT ?
      SQL
    end

    def for_student(student_id, limit: 50)
      student = normalize_optional_id(student_id, "student_id")
      raise ArgumentError, "student_id pozitif bir Integer olmalıdır" if student.nil?

      fetch(<<~SQL, [student, normalize_limit(limit)])
        SELECT id, student_id, action, entity_type, entity_id,
               before_json, after_json, created_at
          FROM audit_logs
         WHERE student_id = ?
         ORDER BY created_at DESC, id DESC
         LIMIT ?
      SQL
    end

    private

    def fetch(sql, params)
      @database.all(sql, params).map { |row| build(row) }
    end

    def find_by_id(id)
      row = @database.get_first_row(<<~SQL, [id])
        SELECT id, student_id, action, entity_type, entity_id,
               before_json, after_json, created_at
          FROM audit_logs
         WHERE id = ?
      SQL
      row.nil? ? nil : build(row)
    end

    def build(row)
      row.merge(
        before_data: decode_json(row[:before_json]),
        after_data: decode_json(row[:after_json])
      )
    end

    def last_insert_id
      @database.get_first_row("SELECT last_insert_rowid() AS id")[:id]
    end

    def now
      Time.now.utc.iso8601(6)
    end

    def encode_json(value, label)
      return nil if value.nil?
      raise ArgumentError, "#{label} bir Hash olmalıdır" unless value.is_a?(Hash)

      JSON.generate(value)
    end

    def decode_json(value)
      return nil if value.nil?

      JSON.parse(value, symbolize_names: true)
    end

    def normalize_text(value, label)
      return value.strip if value.is_a?(String) && !value.strip.empty?

      raise ArgumentError, "#{label} boş olmayan bir String olmalıdır"
    end

    def normalize_optional_id(value, label)
      return nil if value.nil?
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{label} nil ya da pozitif bir Integer olmalıdır"
    end

    def normalize_limit(value)
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "limit pozitif bir Integer olmalıdır"
    end
  end
end
