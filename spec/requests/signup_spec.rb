# frozen_string_literal: true

# Воспроизведение 22.10.2026: регистрация с info@ сразу занимала его теневую учётку — ещё до
# подтверждения по ссылке, — и портал начинал отбрасывать всю почту от info@ (InactiveUserError).
RSpec.describe "регистрация с адресом теневой учётки", type: :request do
  fab!(:info) { Fabricate(:staged, email: "info@wirenboard.com", username: "info_wirenboard.com") }
  fab!(:client) { Fabricate(:staged, email: "client@example.com", username: "client_example.com") }

  before do
    enable_current_plugin
    UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
  end

  def sign_up(email, username)
    post "/u.json",
         params: {
           name: "Посторонний",
           username: username,
           email: email,
           password: "Correct-Horse-Battery-42",
         }
  end

  it "отказывает понятным сообщением и не трогает учётку служебного адреса" do
    expect { sign_up("info@wirenboard.com", "wbtest_claim") }.to change {
      UserHistory.where(custom_type: "wb_staged_claim_refused", target_user_id: info.id).count
    }.by(1)

    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(false)
    expect(response.parsed_body["message"]).to eq(I18n.t("wb_staged_claim_guard.signup_refused"))

    info.reload
    expect(info.staged).to eq(true)
    expect(info.username).to eq("info_wirenboard.com")
    expect(info.custom_fields["from_staged"]).to be_blank
  end

  it "клиент по-прежнему регистрируется поверх своей теневой учётки" do
    sign_up("client@example.com", "client_real")

    expect(response.parsed_body["success"]).to eq(true)
    client.reload
    expect(client.staged).to eq(false)
    expect(client.username).to eq("client_real")
  end

  it "новая регистрация на защищённом домене без теневой учётки проходит" do
    sign_up("new.employee@wirenboard.com", "new_employee")

    expect(response.parsed_body["success"]).to eq(true)
    expect(User.find_by_email("new.employee@wirenboard.com")).to be_present
  end

  it "без предохранителя регистрация занимает учётку info@ — так и ломалось" do
    SiteSetting.wb_staged_claim_guard_enabled = false
    sign_up("info@wirenboard.com", "wbtest_claim")

    info.reload
    expect(info.staged).to eq(false)
    expect(info.active).to eq(false)
    expect(info.username).to eq("wbtest_claim")
  end
end
