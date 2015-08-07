require 'spec_helper'

RSpec.describe StraightServer::WebsocketInsightClient do

  let(:address) { "mttHG8y4rDrGCXhzSo5udNz8cuDRUSXSZL" }
  before(:each) do
    Celluloid.shutdown; Celluloid.boot
    @insight_client = StraightServer::WebsocketInsightClient.new("wss://insight.mycelium.com")
    Celluloid.publish "add_address_for_monit", address
  end

  it "adds address for monitoring" do
    expect(@insight_client.address_monit_list).to eq [address]
  end

  it "removes address from monitorin array" do
    Celluloid.publish "remove_address_from_monit", address
    expect(@insight_client.address_monit_list).to eq([])
  end

  it "dosn't add the same address in monitoring array" do
    Celluloid.publish "add_address_for_monit", address
    expect(@insight_client.address_monit_list).to eq([address])
  end

  it "fills order data if transaction was found for a specific address", foc: true do
    stub_request(:any, /(.*)/).to_return(:status => 200, :body => "{}", :headers => {})
    order = create(:order, address: address, amount: 14830000)
    allow(order.gateway).to receive(:websockets).and_return([false])
    data = {"txid"=>"fe0318641f3d79e8519abf4f1e84d6f01e1680f15c5c17ed9730f2bac0f8d60a", "valueOut"=>0.22735632, "vout"=>[{address =>14830000}, {"188UbhMD23Lbp25gJFBHQvjTLHD5SjLcjk"=>7905632}]}
    Celluloid.publish "ws_check_transaction", data
    sleep 1
    order = StraightServer::Order.find_by_address(address)
    expect(order.tid).to eq(data["txid"])
    expect(order[:status]).to eq(Straight::Order::STATUSES[:paid])
  end

  it "raise error on bad url" do
    expect {
      StraightServer::WebsocketInsightClient.new("wss://wrong.ad")
    }.to raise_error(SocketError)
  end
  
end
