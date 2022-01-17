class WorkflowSource
  def initialize(_model)
    @workflows = {
      "1": [
        {
          state: "saved",
          transition_into: "submitted",
          event: "submit",
          sequence: 1
        }
      ].flatten
    }
  end

  def get_workflows
    @workflows
  end

  def get_workflows_for_workflow_id(workflow_id)
    get_workflows[workflow_id.to_s.to_sym]
  end
end
