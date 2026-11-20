# frozen_string_literal: true

require "json"
require "sinatra/base"

$LOAD_PATH.unshift(File.join(Dir.pwd, "lib"), File.join(Dir.pwd, "app", "repositories"))
require "devamsizlik_kontrol"
require "student_repository"
require "attendance_repository"
require "audit_log_repository"

class DevamsizlikApp < Sinatra::Base
  set :root, Dir.pwd
  set :views, File.join(root, "views")
  set :public_folder, File.join(root, "public")
  set :show_exceptions, false
  enable :method_override

  helpers do
    def database
      @database ||= DevamTakip::Database.new.tap(&:migrate!)
    end

    def students
      @students ||= DevamTakip::StudentRepository.new(database)
    end

    def attendance
      @attendance ||= DevamTakip::AttendanceRepository.new(database)
    end

    def audit
      @audit ||= DevamTakip::AuditLogRepository.new(database)
    end

    def student_id
      Integer(params[:id], 10).tap { |id| raise ArgumentError, "Geçersiz öğrenci" unless id.positive? }
    end

    def student_or_404
      students.find(student_id) || halt(404, erb(:not_found))
    end

    def evaluation(row)
      DevamsizlikKontrol.new(Ogrenci.new(ad: row[:name], durum: row[:status], devamsizlik: row[:absence_count]))
    end

    def form_status
      params.fetch("status", "").to_sym
    end
  end

  before do
    headers "X-Content-Type-Options" => "nosniff"
  end

  after do
    @database&.close
  end

  get "/" do
    @records = students.all
    @totals = {
      all: @records.size,
      active: @records.count { |row| row[:status] == :aktif },
      risky: @records.count { |row| evaluation(row).riskli? },
      failed: @records.count { |row| evaluation(row).kaldi? },
      remedy: @records.count { |row| evaluation(row).telafi_gerekir? }
    }
    erb :index
  end

  get "/students" do
    @status = params["status"]
    @query = params["q"]
    @records = students.all(status: @status.nil? || @status.empty? ? nil : @status, query: @query)
    erb :students
  end

  get "/students/new" do
    erb :student_form
  end

  post "/students" do
    row = database.transaction do
      row = students.create(name: params.fetch("name", ""), status: form_status)
      audit.record(student_id: row[:id], action: "create", entity_type: "student", entity_id: row[:id], after_data: row)
      row
    end
    redirect "/students/#{row[:id]}"
  end

  get "/students/:id" do
    @student = student_or_404
    @result = evaluation(@student)
    @sessions = attendance.for_student(@student[:id])
    erb :student
  end

  get "/students/:id/edit" do
    @student = student_or_404
    erb :student_form
  end

  post "/students/:id" do
    row = database.transaction do
      old = student_or_404
      row = students.update(old[:id], name: params.fetch("name", ""), status: form_status)
      audit.record(student_id: row[:id], action: "update", entity_type: "student", entity_id: row[:id], before_data: old, after_data: row)
      row
    end
    redirect "/students/#{row[:id]}"
  end

  post "/students/:id/delete" do
    database.transaction do
      old = student_or_404
      audit.record(student_id: old[:id], action: "delete", entity_type: "student", entity_id: old[:id], before_data: old)
      students.delete(old[:id])
    end
    redirect "/students"
  end

  post "/students/:id/attendance/:session_id" do
    database.transaction do
      row = student_or_404
      session = attendance.sessions.find { |item| item[:id] == Integer(params[:session_id], 10) }
      halt 404 unless session
      before = attendance.for_student(row[:id]).find { |item| item[:course_session_id] == session[:id] }
      absent = { "present" => 0, "absent" => 1 }.fetch(params["attendance"])
      record = attendance.set(student_id: row[:id], course_session_id: session[:id], absent: absent)
      audit.record(student_id: row[:id], action: "attendance", entity_type: "attendance_record", entity_id: record[:id], before_data: before, after_data: record)
    end
    redirect "/students/#{student_id}"
  end

  get "/reports" do
    @records = students.all.map { |row| [row, evaluation(row)] }.select { |_, result| result.riskli? }
    erb :reports
  end

  get "/audit" do
    @entries = audit.recent
    erb :audit
  end

  get "/health" do
    content_type :json
    JSON.generate(
      status: "ok",
      ruby: RUBY_VERSION,
      module: "ogrenci-devamsizlik"
    )
  end

  not_found do
    erb :not_found
  end

  error ArgumentError, KeyError, SQLite3::ConstraintException do
    status 422
    @error = env["sinatra.error"].message
    erb :error
  end
end

DevamsizlikApp.run! if $PROGRAM_NAME == __FILE__
