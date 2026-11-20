# frozen_string_literal: true

require "fileutils"
require "sqlite3"

module DevamTakip
  # Tek bir SQLite bağlantısını yöneten ince sarmalayıcı.
  #
  # Repository sınıfları SQL'i yalnızca bu nesne üzerinden çalıştırır; bağlantı
  # ayarları (hash sonuçlar, yabancı anahtarlar, dosya dizini) tek yerde tutulur.
  class Database
    DEFAULT_PATH = File.join("data", "devamsizlik.db")
    SCHEMA_PATH = File.expand_path("../../db/schema.sql", __dir__)

    attr_reader :path

    def initialize(path: ENV.fetch("DB_PATH", DEFAULT_PATH))
      unless path.is_a?(String) && !path.strip.empty?
        raise ArgumentError, "veritabanı yolu boş olmayan bir String olmalıdır"
      end

      @path = path
      @savepoint_counter = 0
      prepare_dir
      @connection = SQLite3::Database.new(path)
      @connection.results_as_hash = true
      @connection.busy_timeout = 5_000
      @connection.execute("PRAGMA foreign_keys = ON")
    end

    # Parametreli sorgu çalıştırır. Kullanıcı değerleri her zaman `params`
    # üzerinden geçirilmelidir; SQL metnine eklenmemelidir.
    def execute(sql, params = [])
      @connection.execute(sql, params)
    end

    # Sorgu sonucunu symbol-keyed Hash listesi olarak döndürür.
    def all(sql, params = [])
      execute(sql, params).map { |row| symbolize(row) }
    end

    # İlk satırı symbol-keyed Hash olarak döndürür; satır yoksa nil.
    def get_first_row(sql, params = [])
      row = @connection.get_first_row(sql, params)
      row.nil? ? nil : symbolize(row)
    end

    # Blok içindeki işlemleri tek bir transaction olarak çalıştırır.
    # İç içe çağrılarda savepoint kullanılır; blok değeri geri döndürülür.
    def transaction
      raise ArgumentError, "transaction bir blok gerektirir" unless block_given?

      return savepoint_transaction { yield self } if transaction_active?

      @connection.execute("BEGIN IMMEDIATE")
      begin
        result = yield self
      rescue Exception
        @connection.execute("ROLLBACK") if transaction_active?
        raise
      end
      @connection.execute("COMMIT")
      result
    end

    def transaction_active?
      @connection.transaction_active?
    end

    def foreign_keys_enabled?
      get_first_row("PRAGMA foreign_keys")[:foreign_keys] == 1
    end

    def schema_version
      get_first_row("PRAGMA user_version")[:user_version]
    end

    def table_exists?(name)
      row = get_first_row(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [name.to_s]
      )
      !row.nil?
    end

    # Şemayı idempotent biçimde uygular; mevcut tablo ve indexleri korur.
    def migrate!
      execute_batch(File.read(SCHEMA_PATH, encoding: "UTF-8"))
      self
    end

    def close
      @connection.close unless @connection.closed?
      nil
    end

    def closed?
      @connection.closed?
    end

    private

    def execute_batch(sql)
      @connection.execute_batch(sql)
    end

    def savepoint_transaction
      @savepoint_counter += 1
      name = "devam_takip_#{@savepoint_counter}"
      @connection.execute("SAVEPOINT #{name}")
      begin
        result = yield
      rescue Exception
        @connection.execute("ROLLBACK TO #{name}")
        @connection.execute("RELEASE #{name}")
        raise
      end
      @connection.execute("RELEASE #{name}")
      result
    end

    def prepare_dir
      return if path == ":memory:"

      directory = File.dirname(File.expand_path(path))
      FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
    end

    def symbolize(row)
      row.each_with_object({}) do |(key, value), result|
        result[key.is_a?(String) ? key.to_sym : key] = value
      end
    end
  end
end
