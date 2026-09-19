require "test_helper"
require "active_storage/service/encrypted_disk_service"

class EncryptedDiskServiceTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir("enc_disk")
    @service = ActiveStorage::Service::EncryptedDiskService.new(root: @root)
    @data = "extracto bancario 123456 saldo 9.999.999".b
  end

  teardown { FileUtils.rm_rf(@root) }

  test "file on disk is ciphertext but download returns the original" do
    @service.upload("abc123", StringIO.new(@data), checksum: OpenSSL::Digest::MD5.base64digest(@data))

    raw = File.binread(@service.path_for("abc123"))
    assert_not_includes raw, "extracto bancario"
    assert @service.encrypted?("abc123")
    assert_equal @data, @service.download("abc123")
    assert_equal @data.byteslice(3, 5), @service.download_chunk("abc123", 3...8)

    streamed = +"".b
    @service.download("abc123") { |c| streamed << c }
    assert_equal @data, streamed
  end

  test "rejects a wrong checksum and writes nothing" do
    assert_raises(ActiveStorage::IntegrityError) do
      @service.upload("bad1", StringIO.new(@data), checksum: OpenSSL::Digest::MD5.base64digest("otro"))
    end
    assert_not @service.exist?("bad1")
  end

  test "legacy plaintext files stay readable and can be converted in place" do
    FileUtils.mkdir_p(File.dirname(@service.path_for("old1")))
    File.binwrite(@service.path_for("old1"), @data)

    assert_equal @data, @service.download("old1")
    assert @service.encrypt_in_place("old1")
    assert @service.encrypted?("old1")
    assert_equal @data, @service.download("old1")
    assert_not @service.encrypt_in_place("old1")
  end

  test "tampered ciphertext is rejected" do
    @service.upload("t1", StringIO.new(@data))
    path = @service.path_for("t1")
    bytes = File.binread(path)
    bytes.setbyte(bytes.bytesize - 1, bytes.getbyte(bytes.bytesize - 1) ^ 1)
    File.binwrite(path, bytes)

    assert_raises(OpenSSL::Cipher::CipherError) { @service.download("t1") }
  end
end
