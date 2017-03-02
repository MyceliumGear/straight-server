# coding: utf-8
require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do
    @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
    allow(@gateway).to receive(:save)
    allow(@gateway).to receive(:order_status_changed)
    allow(@gateway).to receive(:increment_order_counter!)
    allow(@gateway).to receive(:test_mode).and_return(false)
    allow(@gateway).to receive(:current_exchange_rate).and_return(111)
    allow(@gateway).to receive(:default_currency).and_return('USD')
    allow(@gateway).to receive(:last_keychain_id).and_return(222)
    allow(@gateway).to receive(:fetch_transactions_for).and_return([])
    allow(StraightServer::Gateway).to receive(:find_by_id).and_return(@gateway)
    @order = create(:order, gateway_id: @gateway.id)

    websockets = {}
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      websockets[g.id] = {}
    end
    StraightServer::GatewayModule.class_variable_set(:@@websockets, websockets)
  end

  describe StraightServer::Order, '#allowed_tx_block_height' do

    before :each do
      @sa_orders = double("same_address_orders")
      allow(@order).to receive(:same_address_orders).and_return(@sa_orders)
      @order.block_height_created_at = 20
    end

    it "raises AmbiguityError if block_height_created_at undefined" do
      @order.block_height_created_at = nil
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "undefined block_height_created_at")

      @order.block_height_created_at = 0
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "undefined block_height_created_at")

      @order.block_height_created_at = -1
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "undefined block_height_created_at")
    end

    it "returns half-limited range if no same-address orders exist" do
      expect(@sa_orders).to receive(:count).and_return(0)
      expect(@order.allowed_tx_block_height).to eq(21..Float::INFINITY)
    end

    it "raises AmbiguityError if same-address order with undefined block_height_created_at exist" do
      expect(@sa_orders).to receive(:count).and_return(2).exactly(3).times

      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([nil, 21])
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "same-address order with undefined block_height_created_at")

      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([21, 0])
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "same-address order with undefined block_height_created_at")

      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([-1, 21])
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "same-address order with undefined block_height_created_at")
    end

    it "raises AmbiguityError if same-address order with identical block_height_created_at exist" do
      expect(@sa_orders).to receive(:count).and_return(2)

      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([20, 21])
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "same-address order with identical block_height_created_at")
    end

    it "raises AmbiguityError if same-address order with preceding block_height_created_at exist" do
      expect(@sa_orders).to receive(:count).and_return(2)

      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([19, 21])
      expect { @order.allowed_tx_block_height }.to raise_error(described_class::AmbiguityError, "same-address order with preceding block_height_created_at")
    end

    it "returns limited range if newer same-address order exist" do
      expect(@sa_orders).to receive(:count).and_return(1)
      expect(@sa_orders).to receive(:select_map).with(:block_height_created_at).and_return([22, 21])
      expect(@order.allowed_tx_block_height).to eq(21..21)
    end
  end

  describe StraightServer::Order, '#reprocess!' do

    before :each do
      @order.amount                  = 10
      @order.gateway                 = @gateway
      @order.address                 = 'address'
      @order.block_height_created_at = 1234
      @order.instance_variable_set(:@status, 5)

      allow(@gateway).to receive(:confirmations_required).and_return(0)
    end

    it "raise exception non-finished orders" do
      @order.instance_variable_set(:@status, 1)
      expect { @order.reprocess! }.to raise_exception(RuntimeError)
    end

    it "changes expired order's status and runs gateway callbacks if there are new transactions for order" do
      expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return(
        [{ tid: 'xxx1', total_amount: 9, block_height: 1235 }],
        [{ tid: 'xxx1', total_amount: 9, block_height: 1235 }, { tid: 'xxx2', total_amount: 1, block_height: 1236 }]
      )

      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      expect(@order.status).to eq 3
      expect(@order.amount_paid).to eq 9
      expect(@order.accepted_transactions.length).to eq 1

      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      @order.reload
      expect(@order.status).to eq 2
      expect(@order.amount_paid).to eq 10
      expect(@order.accepted_transactions.length).to eq 2
    end

    it "changes order's amount_paid and runs gateway callbacks if there are new transactions for order" do
      expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return(
        [{ tid: 'xxx1', total_amount: 7, block_height: 1235 }],
        [{ tid: 'xxx1', total_amount: 7, block_height: 1235 }, { tid: 'xxx2', total_amount: 1, block_height: 1236 }]
      )

      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      expect(@order.status).to eq 3
      expect(@order.amount_paid).to eq 7
      expect(@order.accepted_transactions.length).to eq 1

      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      @order.reload
      expect(@order.status).to eq 3
      expect(@order.amount_paid).to eq 8
      expect(@order.accepted_transactions.length).to eq 2
    end

    it "counts only transactions with confirmations >= gateway's confirmations_required" do
      expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return(
        [{ tid: 'xxx1', total_amount: 3, block_height: 1235, confirmations: 1 }, { tid: 'xxx2', total_amount: 7, block_height: 1235, confirmations: 2 }]
      )
      expect(@gateway).to receive(:confirmations_required).and_return(2)
      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      expect(@order.status).to eq 3
      expect(@order.amount_paid).to eq 7
      expect(@order.accepted_transactions.length).to eq 1
    end

    it "does nothing if there aren't new transactions for order" do
      @order.instance_variable_set(:@status, 3)
      @order.amount_paid = 5

      expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return(
        [{ tid: 'xxx1', total_amount: 5, block_height: 1235 }]
      )
      expect(@gateway).to_not receive(:order_status_changed)

      @order.reprocess!
    end

    it "ignores new transactions if they could belong to newer order with the same address" do
      another_order = create(
        :order,
        gateway_id:              @gateway.id,
        amount:                  2,
        address:                 @order.address,
        block_height_created_at: @order.block_height_created_at + 5
      )

      expect(@order.same_address_orders.select_map(:id)).to eq([another_order.id])

      expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return(
        [
          { tid: 'not_ok_1', total_amount: 10, confirmations: 8, block_height: @order.block_height_created_at },
          { tid: 'ok_1', total_amount: 2, confirmations: 7, block_height: @order.block_height_created_at + 1 },
          { tid: 'ok_2', total_amount: 1, confirmations: 3, block_height: another_order.block_height_created_at },
          { tid: 'not_ok_2', total_amount: 7, confirmations: 2, block_height: another_order.block_height_created_at + 1 },
          { tid: 'not_ok_3', total_amount: 7, confirmations: 0, block_height: -1 },
        ]
      )
      expect(@gateway).to receive(:order_status_changed).with(@order).exactly(1).times

      @order.reprocess!

      expect(@order.status).to eq 3
      expect(@order.amount_paid).to eq 3
    end
  end

  it "prepares data as http params" do
    allow(@order).to receive(:tid).and_return("tid1")
    expect(@order.to_http_params).to eq(
      "order_id=#{@order.id}&amount=10&amount_in_btc=#{@order.amount_in_btc(as: :string)}&" \
      "amount_paid_in_btc=#{@order.amount_in_btc(field: @order.amount_paid, as: :string)}&" \
      "status=#{@order.status}&address=#{@order.address}&tid=tid1&transaction_ids=[]&keychain_id=#{@order.keychain_id}&" \
      "last_keychain_id=#{@order.gateway.last_keychain_id}&after_payment_redirect_to=#{CGI.escape(@order.after_payment_redirect_to)}&" \
      "auto_redirect=#{@order.auto_redirect}"
    )
  end

  it "generates a payment_id" do
    expect(@order.payment_id).not_to be_nil
  end

  it "starts a periodic status check but subtracts the time passed from order creation from the duration of the check" do
    expect(@order).to receive(:check_status_on_schedule).with(duration: 900)
    @order.start_periodic_status_check

    @order.created_at = (Time.now - 100)
    expect(@order).to receive(:check_status_on_schedule).with(duration: 800)
    @order.start_periodic_status_check
  end

  it "checks DB for a status update first if the respective option for the gateway is turned on" do
    # allow(@order).to receive(:transaction).and_raise("Shouldn't ever be happening!")
    StraightServer::Config.check_order_status_in_db_first = true
    StraightServer::Order.where(id: @order.id).update(status: 2)
    allow(@order.gateway).to receive(:fetch_transactions_for).and_return([])
    allow(@order.gateway).to receive(:order_status_changed)
    expect(@order.status(reload: false)).to eq(0)
    expect(@order.status(reload: true)).to eq(2)
  end

  it "updates order status when the time in which it expires passes (periodic status checks finish)" do
    allow(@order).to receive(:status=) do
      expect(@order).to receive(:status_changed?).and_return(true)
      expect(@order).to receive(:save)
    end
    allow(@order).to receive(:check_status_on_schedule).with(duration: 900) { @order.status = 5 }
    @order.start_periodic_status_check
  end

  it "doesn't allow to create an order for inactive gateway" do
    allow(@gateway).to receive(:active).and_return(false)
    expect( -> { create(:order, gateway_id: @gateway.id) }).to raise_exception(Sequel::ValidationFailed, "gateway is inactive, cannot create order for inactive gateway")
  end

  context "when the gateway address provider doesn't take fees" do
    it "adds exchange rate at the moment of purchase to the data hash" do
      order = create(:order, gateway_id: @gateway.id)
      expect(order.data[:exchange_rate]).to eq({ price: 111, currency: 'USD' })
    end
  end

  context "when the gateway address provider takes fees" do
    it "doesn't add exchange rate at the moment of purchase to the data hash" do
      address_provider = double("address_provider", takes_fees?: true)
      allow(address_provider).to receive(:new_address).and_return('testaddress')
      allow(@gateway).to receive(:address_provider).and_return(address_provider)
      order = create(:order, gateway_id: @gateway.id)
      expect(order.data).to be_nil
    end
  end

  it "returns last_keychain_id for the gateway along with other order data" do
    order = create(:order, gateway_id: @gateway.id)
    expect(order.to_h).to include(keychain_id: order.keychain_id, last_keychain_id: @gateway.last_keychain_id)
  end

  it "returns test_last_keychain_id (as last_keychain_id) for the gateway in test mode" do
    allow(@gateway).to receive(:test_mode).and_return(true)
    allow(@gateway).to receive(:test_last_keychain_id).and_return(123)
    order = create(:order, gateway_id: @gateway.id)
    expect(order.to_h[:last_keychain_id]).to eq(123)
  end

  it 'is cancelable only while new' do
    order = build(:order, gateway_id: @gateway.id, status: 0)
    expect(order.cancelable?).to eq true
    (1..6).each do |status|
      order.instance_variable_set :@status, status
      expect(order.cancelable?).to eq false
    end
  end

  it "calculates amount to pay" do
    @order.amount      = 10000
    @order.amount_paid = 0
    expect(@order.amount_to_pay_in_btc).to eq '0.0001'

    @order.amount_paid = 3001
    expect(@order.amount_to_pay_in_btc).to eq '0.00006999'

    @order.amount_paid = 9999
    expect(@order.amount_to_pay_in_btc).to eq '0.00000001'
  end

  describe "DB interaction" do

    it "saves a new order into the database" do
      expect(StraightServer.db_connection[:orders][id: @order.id]).not_to be_nil
    end

    it "updates an existing order" do
      allow(@order).to receive(:gateway).and_return(@gateway)
      expect(StraightServer.db_connection[:orders][id: @order.id][:status]).to eq(0)
      @order.status = 1
      expect(StraightServer.db_connection[:orders][id: @order.id][:status]).to eq(1)
    end

    it "finds first order in the database by id" do
      expect(StraightServer::Order.find(id: @order.id)).to equal_order(@order)
    end

    it "finds first order in the database by keychain_id" do
      expect(StraightServer::Order.find(keychain_id: @order.keychain_id)).to equal_order(@order)
    end

    it "finds orders in the database by any conditions" do
      order1 = create(:order, gateway_id: @gateway.id)
      order2 = create(:order, gateway_id: @gateway.id)

      expect(StraightServer::Order.where(keychain_id: order1.keychain_id).first).to equal_order(order1)
      expect(StraightServer::Order.where(keychain_id: order2.keychain_id).first).to equal_order(order2)
      expect(StraightServer::Order.where(keychain_id: order2.keychain_id+1).first).to be_nil

    end

    describe "with validations" do

      it "doesn't save order if the order with the same id exists" do
        order = create(:order, gateway_id: @gateway.id)
        expect( -> { create(:order, id: order.id, gateway_id: @gateway.id) }).to raise_error(Sequel::ValidationFailed)
      end

      it "doesn't save order if the amount is invalid" do
        expect( -> { create(:order, amount: -1) }).to raise_error(Sequel::ValidationFailed)
      end

      it "zero amount is valid and means that any payment is acceptable" do
        expect( -> { create(:order, amount: 0) }).not_to raise_error
      end

      it "doesn't save order if gateway_id is invalid" do
        expect( -> { create(:order, gateway_id: 0) }).to raise_error(Sequel::ValidationFailed)
      end

      it "doesn't save order if description is too long" do
        expect( -> { create(:order, description: ("text" * 100)) }).to raise_error(Sequel::ValidationFailed)
      end

      it "doesn't save order if same-address order is active" do
        expect( -> { create(:order, keychain_id: @order.keychain_id, gateway_id: @gateway.id) }).to raise_error(Sequel::ValidationFailed)

        @order.this.update(status: 1)
        expect( -> { create(:order, keychain_id: @order.keychain_id, gateway_id: @gateway.id) }).to raise_error(Sequel::ValidationFailed)

        @order.this.update(status: 2)
        expect( -> { create(:order, keychain_id: @order.keychain_id, gateway_id: @gateway.id) }).not_to raise_error
      end
    end

    describe "accepted transactions" do

      it "persists accepted transactions" do
        transactions = [{tid: '1', amount: 1, confirmations: 1, block_height: 100000}, {tid: '2', amount: 2}, {tid: '3', amount: 3}]

        expect(@order.accepted_transactions.size).to eq 0
        expect {
          @order.accepted_transactions = transactions[0, 1]
        }.to change { StraightServer::Transaction.count }.by(1)
        expect(@order.accepted_transactions.size).to eq 1

        @order.on_accepted_transactions_updated = lambda { }
        expect(@order.on_accepted_transactions_updated).to receive(:call).exactly(2).times.and_raise('meah')

        expect {
          @order.accepted_transactions = Straight::Transaction.from_hashes(transactions[1, 1])
        }.to change { StraightServer::Transaction.count }.by(1)
        expect(@order.accepted_transactions.size).to eq 2

        expect {
          @order.accepted_transactions = [StraightServer::Transaction.new(transactions[2])]
        }.to change { StraightServer::Transaction.count }.by(1)
        expect(@order.accepted_transactions.size).to eq 3

        expect {
          @order.accepted_transactions = transactions
        }.to change { StraightServer::Transaction.count }.by(0)

        (0..2).each do |i|
          expect(@order.accepted_transactions[i].to_hash).to include transactions[i]
          expect(@order.accepted_transactions(as: :straight)[i].to_h).to include transactions[i]
        end

        expect(@order.accepted_transactions.map(&:class).uniq).to eq [StraightServer::Transaction]
        expect(@order.accepted_transactions(as: :straight).map(&:class).uniq).to eq [Straight::Transaction]
      end
    end

  end

end
