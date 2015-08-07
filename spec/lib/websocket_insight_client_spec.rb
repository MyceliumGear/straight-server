require 'spec_helper'

RSpec.describe StraightServer::WebsocketInsightClient do

  let(:address) {  "mttHG8y4rDrGCXhzSo5udNz8cuDRUSXSZL" }
  before(:each) do
    StraightServer::WebsocketInsightClient.clear_address_list 
    StraightServer::WebsocketInsightClient.add_address(address)
  end

  it "adds address for monitoring" do
    expect(StraightServer::WebsocketInsightClient.address_for_check_list).to eq [address]
  end

  it "removes address from monitorin array" do
    StraightServer::WebsocketInsightClient.remove_address(address)
    expect(StraightServer::WebsocketInsightClient.address_for_check_list).to eq([])
  end

  it "dosn't add the same address in monitoring array" do
    StraightServer::WebsocketInsightClient.add_address(address)
    expect(StraightServer::WebsocketInsightClient.address_for_check_list).to eq([address])
  end

  it "fills order data if transaction was found for a specific address" do
    stub_request(:any, /(.*)/).to_return(:status => 200, :body => "{}", :headers => {})
    order = create(:order, address: address, amount: 14830000)
    allow(order.gateway).to receive(:websockets).and_return([false])
    data = {"txid"=>"fe0318641f3d79e8519abf4f1e84d6f01e1680f15c5c17ed9730f2bac0f8d60a", "valueOut"=>0.22735632, "vout"=>[{address =>14830000}, {"188UbhMD23Lbp25gJFBHQvjTLHD5SjLcjk"=>7905632}]}
    inst = StraightServer::WebsocketInsightClient.new
    inst.check_transaction(data)
    order = StraightServer::Order.find(address: address)
    expect(order.tid).to eq(data["txid"])
    expect(order[:status]).to eq(Straight::Order::STATUSES[:paid])
  end
end
