# A dummy class to showcase the use of the Gem

require "workflower"
require "workflow_source"
class DummyFeature
  attr_accessor :workflow_id, :workflow_state, :sequence

  include Workflower::ActsAsWorkflower

  def initialize
    @workflow_id = 1
    @workflow_state = "saved"
    @sequence = 1
  end

  def self.before_create(method_name); end

  def assign_attributes(attrs)
    @workflow_state = attrs["workflow_state"]
    @sequence = attrs["sequence"]
  end

  workflower source: WorkflowSource,
             workflower_state_column_name: "workflow_state",
             default_workflow_id: 1
end
