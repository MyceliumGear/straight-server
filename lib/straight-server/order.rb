module StraightServer

  class Order < Sequel::Model

    include Straight::OrderModule
    plugin :validation_helpers
    plugin :timestamps, create: :created_at, update: :updated_at

    plugin :serialization

    # Additional data that can be passed and stored with each order. Not returned with the callback.
    serialize_attributes :marshal, :data

    # data that was provided by the merchan upon order creation and is sent back with the callback
    serialize_attributes :marshal, :callback_data

    # stores the response of the server to which the callback is issued
    serialize_attributes :marshal, :callback_response

    attr_accessor :on_accepted_transactions_updated

    AmbiguityError = Class.new(RuntimeError)

    plugin :after_initialize
    def after_initialize
      @status = self[:status] || 0
    end

    def gateway
      @gateway ||= Gateway.find_by_id(gateway_id)
    end

    def gateway=(g)
      self.gateway_id = g.id
      @gateway        = g
    end

    def accepted_transactions(as: nil)
      result = Transaction.where(order_id: id).all
      case as
      when :straight
        result.map { |item| Straight::Transaction.from_hash(item.to_hash) }
      else
        result
      end
    end

    def accepted_transactions=(items)
      raise "order not persisted" unless id
      items.map do |item|
        item = item.respond_to?(:to_h) ? item.to_h : item.to_hash
        transaction = Transaction[order_id: id, tid: item[:tid]] || Transaction.new(order_id: id)
        begin
          if transaction.update(item)
            # TODO: emit event?
            if @on_accepted_transactions_updated.respond_to?(:call)
              @on_accepted_transactions_updated.call rescue nil
            end
          end
        rescue => ex
          StraightServer.logger.warn "Error during accepted transaction save: #{item.inspect} #{transaction.inspect} #{ex.inspect}"
        end
        transaction
      end
    end

    def self.find_by_address(address)
      where(address: address).order(Sequel.desc(:reused)).limit(1).first
    end

    # Reprocess order:
    # — Order status and amount_paid will be set according to newly found transactions
    # — Callback will run if status or amount_paid actually changed
    # If there is a newer order with the same address, only transactions which
    # couldn't belong to that newer order (their block_height <= new order's block_height_created_at)
    # will be taken into account. Reprocess is impossible if there's an older order with the same address.
    def reprocess!
      raise "Order is not in final state" if status < 2

      confirmations_required = gateway.confirmations_required
      transactions           = Straight::Transaction.from_hashes(gateway.fetch_transactions_for(address))
      allowed_block_height   = allowed_tx_block_height
      transactions.select! { |x|
        (x.block_height.to_i > 0) &&
          allowed_block_height.include?(x.block_height) &&
          (confirmations_required > 0 ? x.confirmations >= confirmations_required : true)
      }

      result = get_transaction_status(transactions: transactions)
      return false if result[:status] == 0
      result[:status] = 3 if result[:status] == -3

      if (result[:status] != @status) || (result[:amount_paid] != amount_paid)
        @old_status = @status
        @status = self[:status] = result[:status]
        self.amount_paid = result[:amount_paid]
        self.accepted_transactions = result[:accepted_transactions]
        save

        Thread.new do
          gateway.order_status_changed(self)
        end
      end
    end

    def same_address_orders
      self.class.exclude(id: id).where(gateway_id: gateway_id, address: address)
    end

    def allowed_tx_block_height
      if block_height_created_at.to_i <= 0
        raise AmbiguityError, "undefined block_height_created_at"
      end
      minimum = block_height_created_at + 1
      maximum =
        if same_address_orders.count > 0
          sao_block_heights = same_address_orders.select_map(:block_height_created_at)
          sao_block_heights.each do |x|
            if x.to_i <= 0
              raise AmbiguityError, "same-address order with undefined block_height_created_at"
            elsif x == block_height_created_at
              raise AmbiguityError, "same-address order with identical block_height_created_at"
            elsif x < block_height_created_at
              raise AmbiguityError, "same-address order with preceding block_height_created_at"
            end
          end
          sao_block_heights.min
        else
          Float::INFINITY
        end
      minimum .. maximum
    end

    # This method is called from the Straight::OrderModule::Prependable
    # using super(). The reason it is reloaded here is because sometimes
    # we want to query the DB first and see if status has changed there.
    #
    # If it indeed changed in the DB and is > 1, then the original
    # Straight::OrderModule::Prependable#status method will not try to
    # query the blockchain (using adapters) because the status has already
    # been changed to be > 1.
    #
    # This is mainly useful for debugging. For example,
    # when testing payments, you don't actually want to pay, you can just
    # run the server console, change order status in the DB and see how your
    # client picks it up, showing you that your order has been paid for.
    #
    # If you want the feature described above on,
    # set StraightServer::Config.check_order_status_in_db_first to true
    def status(as_sym: false, reload: false)
      if reload && StraightServer::Config.check_order_status_in_db_first
        @old_status = self.status
        self.refresh
        unless self[:status] == @old_status
          @status         = self[:status]
          @status_changed = true
          self.gateway.order_status_changed(self)
        end
      end
      self[:status] = @status
    end

    def status=(*)
      self[:status] = @status
      save
    end

    def amount_paid_in_btc
      amount_in_btc(field: amount_paid, as: :string)
    end

    def amount_to_pay
      amount.to_i - amount_paid.to_i
    end

    def amount_to_pay_in_btc
      amount_in_btc(field: amount_to_pay, as: :string)
    end

    def set_data_from_ws(data)
      return if gateway.confirmations_required != 0 || self.status >= 2
      amount_paid = 0
      data["vout"].map { |el| amount_paid += el[address].to_i }
      transaction        = Straight::Transaction.new
      transaction.tid    = data['txid'].to_s
      transaction.amount = amount_paid
      result             = get_transaction_status(transactions: accepted_transactions(as: :straight).push(transaction))
      result.each { |k, v| send :"#{k}=", v }
    end

    def cancelable?
      status == Straight::Order::STATUSES.fetch(:new)
    end

    def cancel
      self.status = Straight::Order::STATUSES.fetch(:canceled)
      save
      StraightServer::Thread.interrupt(label: payment_id)
    end

    def save(*)
      super # calling Sequel::Model save
      @status_changed = false
    rescue Sequel::PoolTimeout
      retry
    end

    def to_h
      super.merge({
        id: id,
        payment_id: payment_id,
        amount_in_btc: amount_in_btc(as: :string),
        amount_paid_in_btc: amount_paid_in_btc,
        amount_to_pay_in_btc: amount_to_pay_in_btc,
        keychain_id: keychain_id,
        last_keychain_id: (self.gateway.test_mode ? self.gateway.test_last_keychain_id : self.gateway.last_keychain_id)
      })
    end

    def to_json
      to_h.to_json
    end

    def validate
      super # calling Sequel::Model validator
      errors.add(:amount,      "is not numeric") if !amount.kind_of?(Numeric)
      errors.add(:amount,      "is less than 0") if amount && amount < 0
      errors.add(:amount_paid, "is not numeric") if !amount.kind_of?(Numeric)
      errors.add(:gateway_id,  "is invalid") if !gateway_id.kind_of?(Numeric) || gateway_id <= 0
      errors.add(:description, "should be shorter than 256 characters") if description.kind_of?(String) && description.length > 255
      errors.add(:gateway,     "is inactive, cannot create order for inactive gateway") if !gateway.active && self.new?
      validates_unique :id
      validates_presence [:address, :keychain_id, :gateway_id, :amount]
      errors.add(:address, "already in use") if (self[:status].to_i < 2) && (same_address_orders.where('status < 2').count > 0)
    end

    def to_http_params
      result = {
        order_id:                  id,
        amount:                    amount,
        amount_in_btc:             amount_in_btc(as: :string),
        amount_paid_in_btc:        amount_in_btc(field: amount_paid, as: :string),
        status:                    status,
        address:                   address,
        tid:                       tid, # @deprecated
        transaction_ids:           accepted_transactions.map(&:tid),
        keychain_id:               keychain_id,
        last_keychain_id:          gateway.last_keychain_id,
        after_payment_redirect_to: CGI.escape(after_payment_redirect_to.to_s),
        auto_redirect:             auto_redirect,
      }.map { |k, v| "#{k}=#{v}" }.join('&')
      if data.respond_to?(:keys)
        keys = data.keys.select { |key| key.kind_of? String }
        if keys.size > 0
          result << '&'
          result << keys.map { |key| "data[#{CGI.escape(key)}]=#{CGI.escape(data[key].to_s)}" }.join('&')
        end
      end
      result
    end

    def before_create
      self.payment_id = gateway.sign_with_secret("#{keychain_id}#{amount}#{created_at}#{(Order.max(:id) || 0)+1}")

      # Save info about current exchange rate at the time of purchase
      if !gateway.address_provider.takes_fees? && gateway.default_currency != 'BTC'
        self.data = {} unless self.data
        self.data[:exchange_rate] = { price: gateway.current_exchange_rate, currency: gateway.default_currency }
      end

      super
    end

    # Update Gateway's order_counters, incrementing the :new counter.
    # All other increments/decrements happen in the the Gateway#order_status_changed callback,
    # but the initial :new increment needs this code because the Gateway#order_status_changed
    # isn't called in this case.
    def after_create
      self.gateway.increment_order_counter!(:new) if StraightServer::Config.count_orders
    end

    # Reloads the method in Straight engine. We need to take
    # Order#created_at into account now, so that we don't start checking on
    # an order that is already expired. Or, if it's not expired yet,
    # we make sure to stop all checks as soon as it expires, but not later.
    def start_periodic_status_check
      if (t = time_left_before_expiration) > 0
        StraightServer.logger.info "Starting periodic status checks of order #{id} (expires in #{t} seconds)"
        @on_accepted_transactions_updated = lambda do
          gateway.order_accepted_transactions_updated self
        end
        check_status_on_schedule(duration: t)
      end
      self.save if self.status_changed?
    end

    def check_status_on_schedule(period: 10, iteration_index: 0, duration: 600, time_passed: 0)
      if StraightServer::Thread.interrupted?(thread: ::Thread.current)
        StraightServer.logger.info "Checking status of order #{self.id} interrupted"
        return
      end
      StraightServer.logger.info "Checking status of order #{self.id}"
      super
      StraightServer.insight_client.remove_address(self.address) if self.status >= 2 && StraightServer.insight_client
    end

    def time_left_before_expiration
      time_passed_after_creation = (Time.now - created_at).to_i
      gateway.orders_expiration_period+(StraightServer::Config.expiration_overtime || 0) - time_passed_after_creation
    end

  end

end
