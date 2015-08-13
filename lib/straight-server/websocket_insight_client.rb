module StraightServer
  class WebsocketInsightClient

    attr_reader :address_monit_list

    def initialize(url)
      @address_monit_list = {}
      connect(url)
    end

    def connect(url)
      socket = SocketIO::Client::Simple.connect url
      this = self

      socket.on :connect do
        StraightServer.logger.info "Connected to Insight websocket with url: #{url}"
        socket.emit :subscribe, 'inv'
      end
      
      socket.on :tx do |data|
        this.check_transaction(data) if data["vout"]
      end

      socket.on :error do |err|
        StraightServer.logger.warn err
      end
    end

    def add_address(address, &block)
      @address_monit_list[address] = block unless @address_monit_list.has_key? address
      StraightServer.logger.info "[WS] Added address for tracking: #{@address_monit_list}"
    end

    def remove_address(address)
      @address_monit_list.delete(address)
    end
    
    def check_transaction(data)
      return if @address_monit_list.empty?
      data["vout"].each do |o|
        address = o.keys.first
        if res = @address_monit_list[address]
          StraightServer.logger.info "[WS] Found transaction for address: #{address}"
          res.call(data)
        end
      end
    end
    
  end

end
