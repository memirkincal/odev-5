# frozen_string_literal: true

require "json"
require "sinatra/base"

require_relative "lib/ogrenci"
require_relative "lib/devamsizlik_kontrol"

class DevamsizlikApp < Sinatra::Base
  set :root, __dir__
  set :views, File.join(root, "views")
  set :public_folder, File.join(root, "public")
  set :show_exceptions, false

  before do
    headers "X-Content-Type-Options" => "nosniff"
  end

  get "/" do
    erb :index
  end

  get "/health" do
    content_type :json
    JSON.generate(
      status: "ok",
      ruby: RUBY_VERSION,
      module: "ogrenci-devamsizlik"
    )
  end

  not_found do
    erb :not_found
  end
end

DevamsizlikApp.run! if $PROGRAM_NAME == __FILE__
