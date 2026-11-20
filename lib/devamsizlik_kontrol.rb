# frozen_string_literal: true

require_relative "ogrenci"

# Öğrencinin devamsızlık durumunu değerlendiren kural motoru.
# Sınır değerler tek yerde tanımlıdır ve dışarıdan değiştirilemez.
class DevamsizlikKontrol
  # 0..10 aralığının %30'u tam olarak 3 gündür; risk eşiği bu sınırdır.
  RISK_SINIRI = 3
  KALMA_SINIRI = 4

  attr_reader :ogrenci

  def initialize(ogrenci)
    raise ArgumentError, "ogrenci bir Ogrenci olmalıdır" unless ogrenci.is_a?(Ogrenci)

    @ogrenci = ogrenci
  end

  # %30 sınırına ulaşan öğrenci risk altındadır (3 ve üzeri).
  def riskli?
    ogrenci.devamsizlik >= RISK_SINIRI
  end

  # Sınırı aşan öğrenci dersi kaybetmiştir (4 ve üzeri).
  def kaldi?
    ogrenci.devamsizlik >= KALMA_SINIRI
  end

  # Yalnızca aktif ve tam 3 gün devamsızlığı olan öğrenci telafi yapar.
  def telafi_gerekir?
    ogrenci.aktif? && ogrenci.devamsizlik == RISK_SINIRI
  end
end
