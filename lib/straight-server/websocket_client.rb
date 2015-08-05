module StraightServer
  class WebsocketClient

    @@address_check_list = []
    
    class << self
      
      def start(url)
        EM.run do
          socket = SocketIO::Client::Simple.connect url

          socket.on :connect do
            StraightServer.logger.info "Connected to Insight websocket"
            socket.emit :subscribe, 'inv'
            @wclient = StraightServer::WebsocketClient.new
          end

          socket.on :tx do |data| 
            @wclient.check_transaction(data) if data
          end
 
          socket.on :error do |err|
            StraightServer.logger.warn err
          end
        end
      end

      def address_for_check_list
        @@address_check_list
      end

      def add_address(address)
        @@address_check_list.push(address).uniq!
      end

      def remove_address(address)
        @@address_check_list.delete(address)
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
