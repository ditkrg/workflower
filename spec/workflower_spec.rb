# frozen_string_literal: true

require "dummy_feature"

RSpec.describe Workflower do
  it "has a version number" do
    expect(Workflower::VERSION).not_to be nil
  end

  it "transitions from saved to submitted" do 
    @test = DummyFeature.new
    @test.workflower_initializer

    @test.submit!
    expect(@test.workflow_state).to eq("submitted")
  end
end
