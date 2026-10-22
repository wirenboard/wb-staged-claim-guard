# frozen_string_literal: true

RSpec.describe WbStagedClaimGuard do
  before { enable_current_plugin }

  describe ".protected_email?" do
    it "защищает весь домен из настройки без учёта регистра и пробелов" do
      expect(described_class.protected_email?("info@wirenboard.com")).to eq(true)
      expect(described_class.protected_email?("  Sales@WirenBoard.RU ")).to eq(true)
      expect(described_class.protected_email?("info@contactless.ru")).to eq(true)
    end

    it "не трогает чужие домены и поддомены защищённых" do
      expect(described_class.protected_email?("client@example.com")).to eq(false)
      expect(described_class.protected_email?("info@mail.wirenboard.com")).to eq(false)
      expect(described_class.protected_email?("info@notwirenboard.com")).to eq(false)
    end

    it "запись с @ защищает ровно этот адрес" do
      SiteSetting.wb_staged_claim_guard_protected = "partner@example.com"
      expect(described_class.protected_email?("partner@example.com")).to eq(true)
      expect(described_class.protected_email?("other@example.com")).to eq(false)
      expect(described_class.protected_email?("info@wirenboard.com")).to eq(false)
    end

    it "пустой и кривой адрес не защищён" do
      expect(described_class.protected_email?(nil)).to eq(false)
      expect(described_class.protected_email?("")).to eq(false)
      expect(described_class.protected_email?("wirenboard.com")).to eq(false)
    end

    it "выключенный плагин ничего не защищает" do
      SiteSetting.wb_staged_claim_guard_enabled = false
      expect(described_class.protected_email?("info@wirenboard.com")).to eq(false)
    end
  end

  describe ".protected_staged_user" do
    fab!(:info) { Fabricate(:staged, email: "info@wirenboard.com") }
    fab!(:employee) { Fabricate(:user, email: "employee@wirenboard.com") }

    it "находит только теневую учётку защищённого адреса" do
      expect(described_class.protected_staged_user("INFO@wirenboard.com ")).to eq(info)
      expect(described_class.protected_staged_user("employee@wirenboard.com")).to be_nil
      expect(described_class.protected_staged_user("nobody@wirenboard.com")).to be_nil
    end
  end
end
