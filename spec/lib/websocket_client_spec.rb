require 'spec_helper'

RSpec.describe StraightServer::WebsocketClient do

  let(:address) {  "mttHG8y4rDrGCXhzSo5udNz8cuDRUSXSZL" }
  before(:each) { StraightServer::WebsocketClient.add_address(address) }
  after(:each) { StraightServer::WebsocketClient.remove_address(address) }

  it "add address for monitoring" do
    expect(StraightServer::WebsocketClient.address_for_check_list).to eq [address]
  end

  it "remove address from monitorin array" do
    StraightServer::WebsocketClient.remove_address(address)
    expect(StraightServer::WebsocketClient.address_for_check_list).to eq([])
  end

  it "not add same address for monitorin array" do
    StraightServer::WebsocketClient.add_address(address)
    expect(StraightServer::WebsocketClient.address_for_check_list).to eq([address])
  end

  it "fill order data if transaction found for specific address", foc: true do
    order = create(:order, address: address, amount: 14830000)
    data = {"txid"=>"fe0318641f3d79e8519abf4f1e84d6f01e1680f15c5c17ed9730f2bac0f8d60a", "valueOut"=>0.22735632, "vout"=>[{address =>14830000}, {"188UbhMD23Lbp25gJFBHQvjTLHD5SjLcjk"=>7905632}]}
    inst = StraightServer::WebsocketClient.new
    inst.check_transaction(data)
    order = StraightServer::Order.find(address: address)
    expect(order.tid).to eq(data["txid"])
    expect(order[:status]).to eq(Straight::Order::STATUSES[:paid])
  end
end
