# frozen_string_literal: true

module WbStagedClaimGuard
  module UserExtension
    # Остальные пути, которыми ядро снимает «теневость»: ссылка-приглашение
    # (InviteRedeemer.create_user_from_invite), вход по коду из письма
    # (User::Action::CreateFromVerifiedEmail), DiscourseConnect и сам вход (log_on_user).
    # Отказываем исключением валидации: вызывающий код ничего не сохраняет, а контроллер
    # приглашений показывает текст ошибки вместо падения.
    def unstage!
      if staged && WbStagedClaimGuard.protected_email?(email)
        WbStagedClaimGuard.log_refused(
          self,
          path: "снятие теневости из #{caller_locations(1, 1).first&.label || "?"}",
        )
        errors.add(:base, I18n.t("wb_staged_claim_guard.unstage_refused"))
        raise ActiveRecord::RecordInvalid.new(self)
      end

      super
    end
  end
end
