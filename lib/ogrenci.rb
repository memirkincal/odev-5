# frozen_string_literal: true

# Bir öğrencinin kimlik ve devam bilgisini taşıyan değer nesnesi.
# Kurallar bu sınıfta değil, DevamsizlikKontrol içinde tutulur.
class Ogrenci
  DURUMLAR = %i[aktif donduruldu mezun].freeze
  DEVAMSIZLIK_ARALIGI = (0..10).freeze

  attr_reader :ad, :durum, :devamsizlik

  def initialize(ad:, durum:, devamsizlik:)
    @ad = dogrulanmis_ad(ad)
    @durum = dogrulanmis_durum(durum)
    @devamsizlik = dogrulanmis_devamsizlik(devamsizlik)
  end

  # Durum sorguları tek bir listeden üretilir; yeni durum eklemek
  # yalnızca DURUMLAR sabitini güncellemeyi gerektirir.
  DURUMLAR.each do |durum_adi|
    define_method("#{durum_adi}?") { durum == durum_adi }
  end

  def to_s
    "#{ad} (#{durum}, devamsızlık: #{devamsizlik})"
  end

  private

  def dogrulanmis_ad(deger)
    raise ArgumentError, "ad boş olmayan bir String olmalıdır" unless deger.is_a?(String) && !deger.strip.empty?

    deger
  end

  def dogrulanmis_durum(deger)
    return deger if DURUMLAR.include?(deger)

    raise ArgumentError, "durum #{DURUMLAR.map(&:inspect).join(', ')} değerlerinden biri olmalıdır"
  end

  def dogrulanmis_devamsizlik(deger)
    return deger if deger.is_a?(Integer) && DEVAMSIZLIK_ARALIGI.cover?(deger)

    raise ArgumentError, "devamsizlik #{DEVAMSIZLIK_ARALIGI} aralığında bir Integer olmalıdır"
  end
end
