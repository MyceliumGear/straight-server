require 'spec_helper'

RSpec.describe StraightServer::WebsocketInsightClient do

  let(:address) { "mttHG8y4rDrGCXhzSo5udNz8cuDRUSXSZL" }
  before(:each) do
    @insight_client = StraightServer::WebsocketInsightClient.new("wss://insight.mycelium.com")
    @order = create(:order, address: address, amount: 14830000)
    allow(@order.gateway).to receive(:websockets).and_return([false])
    @insight_client.add_address(address) { |data| @order.set_data_from_ws(data) }
  end

  it "adds address for monitoring" do
    expect(@insight_client.address_monit_list.keys).to eq [address]
  end

  it "removes address from monitoring array" do
    @insight_client.remove_address(address)
    expect(@insight_client.address_monit_list).to eq({})
  end

  it "dosn't add the same address in monitoring array" do
    @insight_client.add_address(address)
    expect(@insight_client.address_monit_list.keys).to eq([address])
  end

  it "fills order data if transaction was found for a specific address" do
    allow_any_instance_of(StraightServer::Gateway).to receive(:fetch_transactions_for).and_return([])
    stub_request(:get, /(.*)/).to_return(:status => 200, :body => '', :headers => {})
    data = {"txid"=>"fe0318641f3d79e8519abf4f1e84d6f01e1680f15c5c17ed9730f2bac0f8d60a", "valueOut"=>0.22735632, "vout"=>[{address =>14830000}, {"188UbhMD23Lbp25gJFBHQvjTLHD5SjLcjk"=>7905632}]}
    @insight_client.check_transaction(data)
    order = StraightServer::Order.find_by_address(address)
    expect(order.accepted_transactions[0].tid).to eq(data["txid"])
    expect(order[:status]).to eq(Straight::Order::STATUSES[:paid])
  end

  it "raises error on bad url" do
    expect {
      StraightServer::WebsocketInsightClient.new("wss://wrong.ad")
    }.to raise_error(SocketError)
  end

  it "allows multiple connections" do
    client = StraightServer::WebsocketInsightClient.new(["wss://insight.mycelium.com", "wss://test-insight.bitpay.com"])
    expect(client.sockets.size).to eq 2
  end

end
