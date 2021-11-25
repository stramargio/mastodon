require 'rails_helper'

describe Api::V1::Accounts::CredentialsController do
  render_views

  let(:user)  { Fabricate(:user, account: Fabricate(:account, username: 'alice')) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }

  context 'with an oauth token' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token }
    end

    describe 'GET #show' do
      let(:scopes) { 'read:accounts' }

      it 'returns http success' do
        get :show
        expect(response).to have_http_status(200)
      end
    end

    describe 'PATCH #update' do
      let(:scopes) { 'write:accounts' }

      describe 'with valid data', tag: "tag" do
        before do
          allow(ActivityPub::UpdateDistributionWorker).to receive(:perform_async)

          expect(user.account.settings_store).to eq({})
          patch :update, params: {
            display_name: "Alice Isn't Dead",
            note: "Hi!\n\nToot toot!",
            avatar: fixture_file_upload('avatar.gif', 'image/gif'),
            header: fixture_file_upload('attachment.jpg', 'image/jpeg'),
            source: {
              privacy: 'unlisted',
              sensitive: true,
            },
            pleroma_settings_store: { jason: "bateman" }
          }
        end

        it 'returns http success' do
          expect(response).to have_http_status(200)
        end

        it 'updates account info' do
          user.account.reload

          expect(user.account.display_name).to eq("Alice Isn't Dead")
          expect(user.account.note).to eq("Hi!\n\nToot toot!")
          expect(user.account.avatar).to exist
          expect(user.account.header).to exist
          expect(user.setting_default_privacy).to eq('unlisted')
          # TODO @features This setting is not user configurable
          # expect(user.setting_default_sensitive).to eq(true)
          expect(user.account.settings_store).to eq({ "jason" => 'bateman'})
        end

        it 'queues up an account update distribution' do
          expect(ActivityPub::UpdateDistributionWorker).to have_received(:perform_async).with(user.account_id)
        end
      end

      describe 'with empty source list' do
        before do
          patch :update, params: {
            display_name: "I'm a cat",
            source: {},
          }, as: :json
        end

        it 'returns http success' do
          expect(response).to have_http_status(200)
        end
     end

      describe 'with invalid data' do
        before do
          patch :update, params: { note: 'This is too long. ' * 30 }
        end

        it 'returns http unprocessable entity' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  context 'without an oauth token' do
    before do
      allow(controller).to receive(:doorkeeper_token) { nil }
    end

    describe 'GET #show' do
      it 'returns http unauthorized' do
        get :show
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'PATCH #update' do
      it 'returns http unauthorized' do
        patch :update, params: { note: 'Foo' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
