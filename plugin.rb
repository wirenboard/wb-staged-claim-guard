# frozen_string_literal: true

# name: wb-staged-claim-guard
# about: Не даёт занять теневую учётку служебного адреса компании регистрацией, приглашением или входом: иначе портал перестаёт принимать почту с этого адреса
# version: 1.0.0
# authors: Wiren Board
# url: https://github.com/wirenboard/wb-staged-claim-guard
# required_version: 2026.7.0

enabled_site_setting :wb_staged_claim_guard_enabled

module ::WbStagedClaimGuard
  PLUGIN_NAME = "wb-staged-claim-guard"

  def self.enabled?
    SiteSetting.wb_staged_claim_guard_enabled
  end

  # запись настройки — домен целиком или, если в ней есть @, ровно этот адрес
  def self.protected_email?(email)
    return false if !enabled?
    email = email.to_s.strip.downcase
    return false if !email.include?("@")

    domain = email.split("@", 2).last
    SiteSetting
      .wb_staged_claim_guard_protected
      .to_s
      .split("|")
      .map { |entry| entry.strip.downcase }
      .reject(&:blank?)
      .any? { |entry| entry.include?("@") ? entry == email : entry == domain }
  end

  # защищаем только уже существующую теневую учётку: новые регистрации на этих доменах и
  # теневые учётки клиентов живут как раньше
  def self.protected_staged_user(email)
    return nil if !protected_email?(email)
    User.where(staged: true).with_email(email.to_s.strip.downcase).first
  end

  def self.log_refused(user, path:, ip: nil)
    Rails.logger.warn(
      "[#{PLUGIN_NAME}] не дали занять теневую учётку ##{user.id} <#{user.email}>: #{path}, ip #{ip || "?"}",
    )
    UserHistory.create!(
      action: UserHistory.actions[:custom_staff],
      custom_type: "wb_staged_claim_refused",
      acting_user_id: Discourse.system_user.id,
      target_user_id: user.id,
      subject: user.email.to_s[0, 100],
      ip_address: ip,
      details: "путь: #{path}",
    )
  rescue StandardError => e
    Rails.logger.warn("[#{PLUGIN_NAME}] не удалось записать в журнал действий: #{e.message}")
  end
end

after_initialize do
  require_relative "lib/wb_staged_claim_guard/users_controller_extension"
  require_relative "lib/wb_staged_claim_guard/user_extension"

  UsersController.prepend(WbStagedClaimGuard::UsersControllerExtension)
  User.prepend(WbStagedClaimGuard::UserExtension)
end
