module StraightServer
  class WebsocketInsightClient

    @@address_check_list = []
    
    class << self
      
      def start(url)
        socket = SocketIO::Client::Simple.connect url

        socket.on :connect do
          StraightServer.logger.info "Connected to Insight websocket with url: #{url}"
          socket.emit :subscribe, 'inv'
          @wclient = StraightServer::WebsocketInsightClient.new
        end

        socket.on :tx do |data|
          @wclient.check_transaction(data) if data["vout"]
        end

        socket.on :error do |err|
          StraightServer.logger.warn err
        end
      end

      def address_for_check_list
        @@address_check_list
      end

      def add_address(address)
        @@address_check_list.push(address).uniq!
        StraightServer.logger.info "[WS] Added address for tracking: #{@@address_check_list}"
      end

      def remove_address(address)
        @@address_check_list.delete(address)
      end

      def clear_address_list
        @@address_check_list = []
      end
    end

    def check_transaction(data)
      data["vout"].each do |o|
        if index = @@address_check_list.find_index(o.keys.first)
          address = @@address_check_list.delete_at(index)
          StraightServer.logger.info "[WS] Found transaction for address: #{address}"
          StraightServer::Order.set_status_for(address, data)
        end
      end
    end
    
  end

end
