module StraightServer
  class WebsocketInsightClient

    attr_reader :address_monit_list, :sockets

    def initialize(urls=nil)
      @sockets            = {}
      @address_monit_list = {}
      [urls].flatten.compact.each do |url|
        @sockets[url] = connect(url)
      end
    end

    def connect(url)
      socket =
        Timeout.timeout(15, SocketError) do
          SocketIO::Client::Simple.connect(url)
        end
      client = self

      socket.on :connect do
        StraightServer.logger.info "Connected to Insight websocket with url: #{url}"
        socket.emit :subscribe, 'inv'
      end

      socket.on :tx do |data|
        client.check_transaction(data, url) if data["vout"]
      end

      socket.on :error do |err|
        StraightServer.logger.warn err
      end

      socket
    end

    def add_address(address, &block)
      @address_monit_list[address] = block unless @address_monit_list.has_key?(address)
      StraightServer.logger.info "[WS] Added address for tracking: #{address}"
    end

    def remove_address(address)
      @address_monit_list.delete(address)
    end

    def check_transaction(data, origin=nil)
      return if @address_monit_list.empty?
      data["vout"].each do |o|
        address = o.keys.first
        if (callback = @address_monit_list[address])
          StraightServer.logger.info "[WS] Got transaction for address #{address} via #{origin}"
          callback.call(data)
        end
      end
    end
  end
end
