# frozen_string_literal: true

module WbStagedClaimGuard
  module UsersControllerExtension
    # Форма регистрации. Ядро занимает теневую учётку с тем же адресом сразу, ещё до подтверждения
    # по ссылке (users_controller: user.unstage!), — для служебного адреса отвечаем понятным отказом
    # и учётку не трогаем. Защита от ботов (honeypot) срабатывает раньше, в before_action.
    def create
      if (user = WbStagedClaimGuard.protected_staged_user(params[:email]))
        WbStagedClaimGuard.log_refused(user, path: "регистрация", ip: request.remote_ip)
        return fail_with("wb_staged_claim_guard.signup_refused")
      end

      super
    end
  end
end
