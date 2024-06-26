# frozen_string_literal: true

require "spec_helper"

describe Admin::VouchersController, type: :request do
  let(:enterprise) { create(:supplier_enterprise, name: "Feedme") }
  let(:enterprise_user) { create(:user, enterprise_limit: 1) }

  before do
    Flipper.enable(:vouchers)

    enterprise_user.enterprise_roles.build(enterprise: enterprise).save
    sign_in enterprise_user
  end

  describe "GET /admin/enterprises/:enterprise_id/vouchers/new" do
    it "loads the new voucher page" do
      get new_admin_enterprise_voucher_path(enterprise)

      expect(response).to render_template("admin/vouchers/new")
    end
  end

  describe "POST /admin/enterprises/:enterprise_id/vouchers" do
    subject(:create_voucher) { post admin_enterprise_vouchers_path(enterprise), params: params }

    let(:params) do
      {
        voucher: {
          code: code,
          amount: amount
        }
      }
    end
    let(:code) { "new_code" }
    let(:amount) { 15 }

    it "creates a new voucher" do
      expect { create_voucher }.to change(Voucher, :count).by(1)

      voucher = Voucher.last
      expect(voucher.code).to eq(code)
      expect(voucher.amount).to eq(amount)
    end

    it "redirects to admin enterprise setting page, voucher panel" do
      create_voucher

      expect(response).to redirect_to("#{edit_admin_enterprise_path(enterprise)}#vouchers_panel")
    end
  end
end
