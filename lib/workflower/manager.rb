require "workflower/errors"
require "workflower/flow"
module Workflower
  class Manager
    attr_reader :events, :flows_container, :allowed_events

    def initialize(calling_model, source)
      @transitions = source.get_workflows[calling_model.workflow_id.to_s.to_sym]
      @current_state = calling_model.send(calling_model.workflower_state_column_name)
      @current_sequence = calling_model.send(:sequence)
      @calling_model    = calling_model
      @source           = source

      # Flows
      @flows_container = buildup_flows
      @events = @flows_container.map(&:event)
      @allowed_events = allowed_transitions.map(&:event)
      @validation_errors = []
    end

    def uninitialize
      @transitions = []
      @current_state = []
      @current_sequence = []
      @calling_model    = []
      @source           = []

      # Flows
      @flows_container = []
      @events = []
      @allowed_events = []
      @validation_errors = []
    end

    def buildup_flows
      possible_transitions.map { |transition| Workflower::Flow.new(transition) }
    end

    def possible_transitions
      # @transitions.where(state: @current_state).where("sequence = :seq OR sequence = :seq_plus", seq: @current_sequence, seq_plus: @current_sequence + 1).order("sequence ASC") || []
      @transitions.select do |item|
        item[:state] == @current_state && (item[:sequence] == @current_sequence || item[:sequence] == @current_sequence + 1)
      end
                  .sort_by do |item|
        item[:sequence]
      end
    end

    def allowed_transitions
      buildup_flows.select { |flow| transition_possible?(flow) }
    end

    def set_initial_state
      "saved"
    end

    def process_transition!(flow)
      if flow.condition_is_met?(@calling_model)
        begin
          flow.call_before_transition(@calling_model)
          @calling_model.assign_attributes flow.updateable_attributes(@calling_model)
          flow.call_after_transition(@calling_model)
          true
        rescue Exception
          @calling_model.errors.add(@calling_model.workflower_state_column_name, :transition_faild)
          false
        end
      else
        @calling_model.errors.add(@calling_model.workflower_state_column_name,
                                  :precondition_not_met_to_process_transition)
      end
    end

    def transition_possible?(flow)
      @calling_model.send(@calling_model.workflower_state_column_name) != flow.transition_into && flow.condition_is_met?(@calling_model)
    end
  end
end
