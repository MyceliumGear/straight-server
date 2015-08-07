module StraightServer
  class WebsocketInsightClient
    include Celluloid
    include Celluloid::Notifications

    attr_reader :address_monit_list

    def initialize(url)
      @address_monit_list = []
      connect(url)
      subscribe "add_address_for_monit", :add_address
      subscribe "remove_address_from_monit", :remove_address
      subscribe "ws_check_transaction", :check_transaction
    end

    def connect(url)
      socket = SocketIO::Client::Simple.connect url

      socket.on :connect do
        StraightServer.logger.info "Connected to Insight websocket with url: #{url}"
        socket.emit :subscribe, 'inv'
      end

      socket.on :tx do |data|
        Celluloid.publish("ws_check_transaction", data ) if data["vout"]
      end

      socket.on :error do |err|
        StraightServer.logger.warn err
      end
    end

    def add_address(topic, address)
      @address_monit_list.push(address).uniq!
      StraightServer.logger.info "[WS] Added address for tracking: #{@address_monit_list}"
    end

    def remove_address(topic, address)
      @address_monit_list.delete(address)
    end
    
    def check_transaction(topic, data)
      return if @address_monit_list.empty?
      data["vout"].each do |o|
        if index = @address_monit_list.find_index(o.keys.first)
          address = @address_monit_list.delete_at(index)
          StraightServer.logger.info "[WS] Found transaction for address: #{address}"
          StraightServer::Order.set_status_for(address, data)
        end
      end
    end
    
  end

end
