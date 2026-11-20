# frozen_string_literal: true

require "minitest/autorun"
require "rack/test"
require "tmpdir"

ENV["RACK_ENV"] = "test"
load File.join(Dir.pwd, "app.rb")

class WebTest < Minitest::Test
  include Rack::Test::Methods

  def app
    DevamsizlikApp
  end

  def setup
    @directory = Dir.mktmpdir("devam-web-")
    ENV["DB_PATH"] = File.join(@directory, "test.db")
    database = DevamTakip::Database.new
    database.migrate!
    @session = DevamTakip::AttendanceRepository.new(database).create_session(session_no: 1, title: "Ders 1")
    database.close
  end

  def teardown
    ENV.delete("DB_PATH")
    FileUtils.remove_entry(@directory)
  end

  def test_pages_and_student_lifecycle
    get "/"
    assert last_response.ok?, last_response.body
    get "/students"
    assert last_response.ok?, last_response.body
    post "/students", name: "Ada", status: "aktif"
    assert_equal 302, last_response.status, last_response.body
    path = last_response.headers.fetch("location")
    get path
    assert_includes last_response.body, "Ada"
    post "#{path}/attendance/#{@session[:id]}", attendance: "absent"
    assert_equal 302, last_response.status, last_response.body
    get path
    assert_includes last_response.body, "1/10"
    post path, name: "Ada Byron", status: "mezun"
    assert_equal 302, last_response.status, last_response.body
    get "/audit"
    assert last_response.ok?, last_response.body
    assert_includes last_response.body, "attendance"
    post "#{path}/delete"
    assert_equal 302, last_response.status, last_response.body
    get "/students"
    refute_includes last_response.body, "Ada Byron"
  end

  def test_validation_and_missing_record
    post "/students", name: " ", status: "aktif"
    assert_equal 422, last_response.status
    get "/students/999"
    assert_equal 404, last_response.status
  end

  def test_three_absences_are_risky_and_reported
    database = DevamTakip::Database.new
    repository = DevamTakip::AttendanceRepository.new(database)
    sessions = [@session]
    sessions << repository.create_session(session_no: 2, title: "Ders 2")
    sessions << repository.create_session(session_no: 3, title: "Ders 3")
    student = DevamTakip::StudentRepository.new(database).create(name: "Riskli Ada", status: :aktif)
    sessions.each { |session| repository.set(student_id: student[:id], course_session_id: session[:id], absent: true) }
    database.close

    get "/students/#{student[:id]}"
    assert last_response.ok?, last_response.body
    assert_includes last_response.body, "3/10"
    assert_includes last_response.body, "Telafi gerekir"
    get "/reports"
    assert_includes last_response.body, "Riskli Ada"
    get "/reports.csv"
    assert last_response.ok?, last_response.body
    assert_includes last_response.headers.fetch("content-type"), "text/csv"
    assert_includes last_response.body, "Riskli Ada"
    get "/"
    assert last_response.ok?, last_response.body
    get "/students", status: "aktif", q: "Riskli"
    assert_includes last_response.body, "Riskli Ada"
  end
end
