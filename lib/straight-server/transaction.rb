module StraightServer
  class Transaction < Sequel::Model
    plugin :timestamps, create: :created_at, update: :updated_at

  end
end
