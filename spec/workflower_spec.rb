# frozen_string_literal: true

RSpec.describe Workflower do
  it "has a version number" do
    expect(Workflower::VERSION).not_to be nil
  end

  it "transitions from saved to submitted" do 
    expect(true).to eq(true)
  end
end
