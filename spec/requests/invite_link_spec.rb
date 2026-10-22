# frozen_string_literal: true

# Обход формы регистрации: ссылку-приглашение без адреса может сделать любой, кому разрешено
# приглашать, и указать при входе по ней адрес чужой теневой учётки.
RSpec.describe "ссылка-приглашение с адресом теневой учётки", type: :request do
  fab!(:info) { Fabricate(:staged, email: "info@wirenboard.com", username: "info_wirenboard.com") }
  fab!(:client) { Fabricate(:staged, email: "client@example.com") }
  fab!(:invite) { Fabricate(:invite, email: nil, max_redemptions_allowed: 5) }

  before { enable_current_plugin }

  def accept(email, username)
    put "/invites/show/#{invite.invite_key}.json",
        params: {
          email: email,
          username: username,
          password: "Correct-Horse-Battery-42",
        }
  end

  it "отказывает и оставляет учётку служебного адреса теневой" do
    accept("info@wirenboard.com", "wbtest_invite")

    expect(response.status).to eq(412)
    expect(response.parsed_body["message"]).to include(
      I18n.t("wb_staged_claim_guard.unstage_refused"),
    )
    info.reload
    expect(info.staged).to eq(true)
    expect(info.username).to eq("info_wirenboard.com")
  end

  it "без предохранителя ссылка занимает учётку info@ — обход формы регистрации" do
    SiteSetting.wb_staged_claim_guard_enabled = false
    accept("info@wirenboard.com", "wbtest_invite")

    info.reload
    expect(info.staged).to eq(false)
    expect(info.username).to eq("wbtest_invite")
  end

  it "клиенту приглашение по-прежнему открывает его теневую учётку" do
    accept("client@example.com", "client_invited")

    expect(response.status).to eq(200)
    expect(client.reload.staged).to eq(false)
  end
end

RSpec.describe "снятие теневости с учётки служебного адреса" do
  fab!(:info) { Fabricate(:staged, email: "info@wirenboard.com") }

  before { enable_current_plugin }

  it "unstage! отказывает, не стирает уведомления и пишет в журнал действий" do
    Fabricate(:notification, user: info)

    expect { info.unstage! }.to raise_error(
      ActiveRecord::RecordInvalid,
      /#{Regexp.escape(I18n.t("wb_staged_claim_guard.unstage_refused"))}/,
    )
    info.reload
    expect(info.staged).to eq(true)
    expect(info.notifications.count).to eq(1)
    expect(
      UserHistory.where(custom_type: "wb_staged_claim_refused", target_user_id: info.id),
    ).to exist
  end
end
