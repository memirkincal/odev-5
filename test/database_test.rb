# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"

# Windows Ruby mutlak yolu Türkçe karakterlerle OEM kod sayfasında
# çözebildiği için repository dosyaları çalışma dizinine göre yüklenir.
# `require` kullanılır; böylece repository içindeki `require_relative`
# çağrıları aynı dosyayı ikinci kez yüklemez.
$LOAD_PATH.unshift(File.join(Dir.pwd, "app", "repositories"))
require "student_repository"
require "attendance_repository"
require "audit_log_repository"

class DatabaseTest < Minitest::Test
  ISO_8601_UTC = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\z/

  def setup
    @tmpdir = Dir.mktmpdir("devam-takip-test")
    @db_path = File.join(@tmpdir, "test.db")
    @db = DevamTakip::Database.new(path: @db_path)
    @db.migrate!

    @students = DevamTakip::StudentRepository.new(@db)
    @attendance = DevamTakip::AttendanceRepository.new(@db)
    @audit = DevamTakip::AuditLogRepository.new(@db)
  end

  def teardown
    @db&.close
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
    @db = nil
  end

  # --- Migration -----------------------------------------------------------

  def test_migration_is_idempotent
    @db.migrate!
    @db.migrate!

    %w[students course_sessions attendance_records audit_logs].each do |table|
      assert @db.table_exists?(table), "#{table} tablosu oluşmadı"
    end
    assert_equal 1, @db.schema_version
  end

  def test_foreign_keys_are_enabled
    assert @db.foreign_keys_enabled?
  end

  def test_default_database_path_is_outside_test_directory
    default = DevamTakip::Database::DEFAULT_PATH

    assert_equal File.join("data", "devamsizlik.db"), default
    refute_equal File.expand_path(default), File.expand_path(@db_path)
    assert_includes @db_path, @tmpdir
  end

  # --- Ders oturumları -----------------------------------------------------

  def test_ten_course_sessions_can_be_created
    create_sessions(1..10)

    sessions = @attendance.sessions

    assert_equal 10, sessions.size
    assert_equal (1..10).to_a, sessions.map { |row| row[:session_no] }
    assert_equal "Ders 1", sessions.first[:title]
    refute_nil sessions.first[:id]
  end

  def test_out_of_range_session_numbers_are_rejected
    [0, 11, -1, 1.0, "1", nil].each do |number|
      assert_raises(ArgumentError, "#{number.inspect} kabul edilmemeliydi") do
        @attendance.create_session(session_no: number, title: "Geçersiz")
      end
    end

    assert_empty @attendance.sessions
  end

  def test_duplicate_session_number_is_rejected
    create_session(1)

    error = assert_raises(ArgumentError) { create_session(1) }

    refute_empty error.message
    assert_equal 1, @attendance.sessions.size
  end

  def test_session_requires_title
    ["", "   ", nil].each do |title|
      assert_raises(ArgumentError) do
        @attendance.create_session(session_no: 1, title: title)
      end
    end
  end

  def test_session_date_can_be_empty_or_iso_date
    create_session(1, session_date: nil)
    create_session(2, session_date: Date.new(2026, 10, 5))

    assert_nil @attendance.sessions.first[:session_date]
    assert_equal "2026-10-05", @attendance.sessions.last[:session_date]
  end

  # --- Öğrenci CRUD --------------------------------------------------------

  def test_student_create_find_update_delete
    student = @students.create(name: "Ada Lovelace", status: :aktif)

    assert_equal "Ada Lovelace", student[:name]
    assert_equal :aktif, student[:status]
    assert_equal 0, student[:absence_count]
    refute_nil student[:id]

    found = @students.find(student[:id])
    assert_equal student[:id], found[:id]

    updated = @students.update(student[:id], name: "Ada Byron", status: :mezun)
    assert_equal "Ada Byron", updated[:name]
    assert_equal :mezun, updated[:status]

    assert @students.delete(student[:id])
    assert_nil @students.find(student[:id])
    refute @students.delete(student[:id])
  end

  def test_records_are_symbol_keyed_hashes
    student = @students.create(name: "Grace Hopper", status: "aktif")

    assert(student.keys.all? { |key| key.is_a?(Symbol) })
    %i[id name status created_at updated_at absence_count].each do |key|
      assert_includes student.keys, key
    end
  end

  def test_missing_student_update_returns_nil
    assert_nil @students.update(999, name: "Hayalet", status: :aktif)
  end

  def test_timestamps_are_utc_iso_8601
    student = @students.create(name: "Tim Berners-Lee", status: :aktif)

    assert_match ISO_8601_UTC, student[:created_at]
    assert_match ISO_8601_UTC, student[:updated_at]
  end

  def test_invalid_student_status_is_rejected
    [:beklemede, "kayitli", nil, 3].each do |status|
      assert_raises(ArgumentError, "#{status.inspect} kabul edilmemeliydi") do
        @students.create(name: "Geçersiz", status: status)
      end
    end

    assert_empty @students.all
  end

  def test_blank_student_name_is_rejected
    ["", "   ", nil, 5].each do |name|
      assert_raises(ArgumentError) { @students.create(name: name, status: :aktif) }
    end
  end

  def test_invalid_id_is_rejected
    [0, -1, "1", 1.0, nil].each do |id|
      assert_raises(ArgumentError) { @students.find(id) }
    end
  end

  # --- Devam kayıtları -----------------------------------------------------

  def test_attendance_upsert_does_not_duplicate
    student = create_student
    create_sessions(1..10)
    session = @attendance.session(1)

    first = @attendance.set(student_id: student[:id], course_session_id: session[:id], absent: 1)
    second = @attendance.set(student_id: student[:id], course_session_id: session[:id], absent: 0)

    assert_equal first[:id], second[:id]
    assert_equal 0, second[:absent]
    stored = @attendance.for_student(student[:id]).find { |row| row[:session_no] == 1 }
    assert_equal 0, stored[:absent]
    assert_equal 1, @attendance.for_student(student[:id]).count { |row| row[:attendance_id] }
  end

  def test_for_student_returns_ten_sessions_in_order
    student = create_student
    create_sessions(1..10)

    rows = @attendance.for_student(student[:id])

    assert_equal 10, rows.size
    assert_equal (1..10).to_a, rows.map { |row| row[:session_no] }
    assert(rows.all? { |row| row[:absent].nil? })
    assert(rows.all? { |row| row[:attendance_id].nil? })
  end

  def test_absence_count_is_calculated_from_sessions
    student = create_student
    create_sessions(1..10)
    [1, 4, 10].each do |number|
      @attendance.set(
        student_id: student[:id],
        course_session_id: @attendance.session(number)[:id],
        absent: 1
      )
    end
    @attendance.set(
      student_id: student[:id],
      course_session_id: @attendance.session(2)[:id],
      absent: 0
    )

    assert_equal 3, @attendance.absence_count(student[:id])
    assert_equal 3, @students.find(student[:id])[:absence_count]
  end

  def test_attendance_boolean_absent_is_accepted
    student = create_student
    create_sessions(1..10)
    session = @attendance.session(1)

    @attendance.set(student_id: student[:id], course_session_id: session[:id], absent: true)

    assert_equal 1, @attendance.absence_count(student[:id])
  end

  def test_invalid_absent_value_is_rejected
    student = create_student
    create_sessions(1..10)
    session = @attendance.session(1)

    [2, -1, "1", nil].each do |absent|
      assert_raises(ArgumentError) do
        @attendance.set(student_id: student[:id], course_session_id: session[:id], absent: absent)
      end
    end
  end

  def test_session_summary_counts_records
    create_sessions(1..10)
    session = @attendance.session(3)
    ada = create_student(name: "Ada Lovelace")
    grace = create_student(name: "Grace Hopper")

    @attendance.set(student_id: ada[:id], course_session_id: session[:id], absent: 1)
    @attendance.set(student_id: grace[:id], course_session_id: session[:id], absent: 0)

    summary = @attendance.session_summary(session[:id])

    assert_equal 3, summary[:session_no]
    assert_equal 2, summary[:total_records]
    assert_equal 1, summary[:absent_count]
    assert_equal 1, summary[:present_count]
    assert_nil @attendance.session_summary(999)
  end

  def test_deleting_student_cascades_attendance
    student = create_student
    create_sessions(1..10)
    @attendance.set(
      student_id: student[:id],
      course_session_id: @attendance.session(1)[:id],
      absent: 1
    )
    assert_equal 1, @attendance.absence_count(student[:id])

    @students.delete(student[:id])

    assert_equal 0, @attendance.absence_count(student[:id])
    assert(@attendance.for_student(student[:id]).all? { |row| row[:absent].nil? })
  end

  # --- Audit log -----------------------------------------------------------

  def test_audit_log_round_trips_json
    student = create_student
    before_data = { name: "Ada Lovelace", status: :aktif }
    after_data = { name: "Ada Byron", status: :mezun }
    expected_before = { name: "Ada Lovelace", status: "aktif" }
    expected_after = { name: "Ada Byron", status: "mezun" }

    entry = @audit.record(
      student_id: student[:id],
      action: "update",
      entity_type: "student",
      entity_id: student[:id],
      before_data: before_data,
      after_data: after_data
    )

    refute_nil entry[:id]
    assert_equal expected_before, entry[:before_data]
    assert_equal expected_after, entry[:after_data]

    listed = @audit.recent(limit: 10)
    assert_equal 1, listed.size
    assert_equal expected_before, listed.first[:before_data]
    assert_equal expected_after, listed.first[:after_data]
    assert_match ISO_8601_UTC, listed.first[:created_at]

    by_student = @audit.for_student(student[:id], limit: 10)
    assert_equal [entry[:id]], by_student.map { |row| row[:id] }
  end

  def test_audit_log_allows_null_data_and_student
    entry = @audit.record(
      student_id: nil,
      action: "seed",
      entity_type: "system",
      entity_id: nil,
      before_data: nil,
      after_data: { count: 5 }
    )

    assert_nil entry[:student_id]
    assert_nil entry[:before_data]
    assert_equal({ count: 5 }, entry[:after_data])
  end

  def test_audit_log_validates_input
    assert_raises(ArgumentError) do
      @audit.record(student_id: nil, action: "", entity_type: "student")
    end
    assert_raises(ArgumentError) do
      @audit.record(student_id: nil, action: "update", entity_type: " ")
    end
    assert_raises(ArgumentError) do
      @audit.record(student_id: 0, action: "update", entity_type: "student")
    end
    assert_raises(ArgumentError) do
      @audit.record(student_id: nil, action: "update", entity_type: "student", before_data: "metin")
    end
    assert_raises(ArgumentError) { @audit.recent(limit: 0) }
  end

  def test_audit_log_student_is_nullified_on_delete
    student = create_student
    @audit.record(
      student_id: student[:id],
      action: "create",
      entity_type: "student",
      entity_id: student[:id],
      after_data: { name: student[:name] }
    )

    @students.delete(student[:id])

    entry = @audit.recent(limit: 10).first
    assert_nil entry[:student_id]
    assert_empty @audit.for_student(student[:id])
  end

  def test_audit_log_recent_respects_limit
    3.times do |index|
      @audit.record(student_id: nil, action: "seed", entity_type: "system", entity_id: index + 1)
    end

    assert_equal 2, @audit.recent(limit: 2).size
    assert_equal 3, @audit.recent(limit: 50).size
  end

  # --- Arama ve filtreleme -------------------------------------------------

  def test_status_filter_and_name_search
    create_student(name: "Ada Lovelace", status: :aktif)
    create_student(name: "Grace Hopper", status: :mezun)
    create_student(name: "Ayşe O'Brien", status: :donduruldu)

    assert_equal 1, @students.all(status: :aktif).size
    assert_equal "Ada Lovelace", @students.all(status: "aktif").first[:name]
    assert_equal 3, @students.all.size
    assert_equal ["Grace Hopper"], @students.all(query: "hopper").map { |row| row[:name] }
    assert_equal ["Ayşe O'Brien"], @students.all(query: "O'Brien").map { |row| row[:name] }
    assert_empty @students.all(query: "' OR 1=1 --")
    assert_empty @students.all(status: :aktif, query: "hopper")
  end

  def test_like_wildcards_are_treated_as_literal_text
    create_student(name: "Yüzde % Öğrenci")
    create_student(name: "Alt Çizgi _ Öğrenci")

    assert_equal ["Yüzde % Öğrenci"], @students.all(query: "%").map { |row| row[:name] }
    assert_equal ["Alt Çizgi _ Öğrenci"], @students.all(query: "_").map { |row| row[:name] }
  end

  def test_invalid_status_filter_is_rejected
    assert_raises(ArgumentError) { @students.all(status: :beklemede) }
  end

  private

  def create_student(name: "Test Öğrenci", status: :aktif)
    @students.create(name: name, status: status)
  end

  def create_sessions(numbers)
    numbers.each { |number| create_session(number) }
  end

  def create_session(number, session_date: nil)
    @attendance.create_session(
      session_no: number,
      title: "Ders #{number}",
      session_date: session_date
    )
  end
end
