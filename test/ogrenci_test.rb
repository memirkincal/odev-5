# frozen_string_literal: true

require "minitest/autorun"
# Windows Ruby, Türkçe karakter içeren mutlak `__dir__` yolunu OEM kod
# sayfasıyla çözebildiği için testler proje kökünün UTF-8 çalışma dizininden
# yüklenir. `devamsizlik_kontrol.rb` zaten `ogrenci.rb` dosyasını require eder;
# böylece dosya iki kez yüklenmez ve sabit yeniden tanımlama uyarısı çıkmaz.
load File.join(Dir.pwd, "lib", "devamsizlik_kontrol.rb")

class OgrenciTest < Minitest::Test
  DURUMLAR = %i[aktif donduruldu mezun].freeze

  def ogrenci(durum: :aktif, devamsizlik: 0)
    Ogrenci.new(ad: "Ada Lovelace", durum: durum, devamsizlik: devamsizlik)
  end

  def test_alanlari_okunabilir
    kayit = ogrenci(durum: :mezun, devamsizlik: 2)

    assert_equal "Ada Lovelace", kayit.ad
    assert_equal :mezun, kayit.durum
    assert_equal 2, kayit.devamsizlik
  end

  def test_durum_sorgulari
    DURUMLAR.each do |durum|
      kayit = ogrenci(durum: durum)

      DURUMLAR.each do |sorgu|
        assert_equal durum == sorgu, kayit.public_send("#{sorgu}?")
      end
    end
  end

  def test_durum_sorgulari_define_method_ile_uretilir
    kaynak = File.read(File.join(Dir.pwd, "lib", "ogrenci.rb"), encoding: "UTF-8")

    assert_includes kaynak, "define_method"
    refute_match(/\bmethod_missing\b/, kaynak)
  end

  def test_bilinmeyen_sorgu_no_method_error_uretir
    assert_raises(NoMethodError) { ogrenci.beklemede? }
  end

  def test_gecersiz_durum_reddedilir
    hata = assert_raises(ArgumentError) { ogrenci(durum: :beklemede) }

    refute_empty hata.message
  end

  def test_devamsizlik_sinir_degerleri_kabul_edilir
    assert_equal 0, ogrenci(devamsizlik: 0).devamsizlik
    assert_equal 10, ogrenci(devamsizlik: 10).devamsizlik
  end

  def test_aralik_disindaki_devamsizlik_reddedilir
    [-1, 11].each do |deger|
      assert_raises(ArgumentError) { ogrenci(devamsizlik: deger) }
    end
  end

  def test_integer_olmayan_devamsizlik_reddedilir
    [3.0, "3", nil].each do |deger|
      assert_raises(ArgumentError) { ogrenci(devamsizlik: deger) }
    end
  end
end

class DevamsizlikKontrolTest < Minitest::Test
  def kontrol(devamsizlik:, durum: :aktif)
    ogrenci = Ogrenci.new(ad: "Grace Hopper", durum: durum, devamsizlik: devamsizlik)
    DevamsizlikKontrol.new(ogrenci)
  end

  def test_iki_devamsizlik_riskli_degil
    refute kontrol(devamsizlik: 2).riskli?
  end

  def test_tam_uc_devamsizlik_riskli
    assert kontrol(devamsizlik: 3).riskli?
  end

  def test_tam_uc_devamsizlikta_kalmadi
    refute kontrol(devamsizlik: 3).kaldi?
  end

  def test_dort_devamsizlikta_kaldi
    assert kontrol(devamsizlik: 4).kaldi?
  end

  def test_on_devamsizlik_hem_riskli_hem_kaldi
    sonuc = kontrol(devamsizlik: 10)

    assert sonuc.riskli?
    assert sonuc.kaldi?
  end

  def test_aktif_ve_tam_uc_devamsizlikta_telafi_gerekir
    assert kontrol(devamsizlik: 3, durum: :aktif).telafi_gerekir?
  end

  def test_diger_durumlarda_ve_degerlerde_telafi_gerekmez
    refute kontrol(devamsizlik: 3, durum: :donduruldu).telafi_gerekir?
    refute kontrol(devamsizlik: 3, durum: :mezun).telafi_gerekir?
    refute kontrol(devamsizlik: 2, durum: :aktif).telafi_gerekir?
    refute kontrol(devamsizlik: 4, durum: :aktif).telafi_gerekir?
  end
end
