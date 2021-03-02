module Workflower
  class Flow
    attr_accessor :state, :transition_into, :trigger_action_name, :boolean_action_name, :sequence, :downgrade_sequence, :event, :condition, :condition_type, :before_transit, :after_transit, :metadata, :workflow_id, :deviation_id

    # rubocop:disable Metrics/AbcSize
    def initialize(options)
      @state               = options[:state]
      @transition_into     = options[:transition_into]
      @event               = options[:event]
      @condition           = options[:condition] if options[:condition]
      @condition_type      = options[:condition_type] if options[:condition_type]
      @before_transition   = options[:before_transition] if options[:before_transition]
      @after_transition    = options[:after_transition] if options[:after_transition]
      @sequence            = options[:sequence]
      @downgrade_sequence  = options[:downgrade_sequence] || -1
      @workflow_id         = options[:workflow_id]
      @metadata            = options[:metadata]
      @deviation_id        = options[:deviation_id] || @workflow_id
      @trigger_action_name = "#{event}!"
      @boolean_action_name = "can_#{event}?"
    end

    def before_transition_proc_name
      !@before_transition.blank? ? @before_transition.to_sym : "before_workflow_#{event}".to_sym
    end

    def call_before_transition(calling_model)
      calling_model.send(before_transition_proc_name) if calling_model.respond_to? before_transition_proc_name
    end

    def after_transition_proc_name
      !@after_transition.blank? ? @after_transition.to_sym : "after_workflow_#{event}".to_sym
    end

    def call_after_transition(calling_model)
      calling_model.send(after_transition_proc_name) if calling_model.respond_to? after_transition_proc_name
    end

    def condition_proc_name
      @condition || nil
    end

    def condition_is_met?(calling_model)
      if @condition_type == "expression"

        evaluation_phrase = @condition.split(" ").map do |item|
          if !["||", "&&", "(", ")"].include?(item)
            "calling_model.#{item}"
          else
            item
          end
        end

        return eval(evaluation_phrase.join(" "))
      end

      if !condition_proc_name.blank? && calling_model.respond_to?(condition_proc_name)
        return calling_model.send(condition_proc_name)
      end

      true
    end

    def updateable_attributes(calling_model)
      attributes = Hash[calling_model.workflower_state_column_name, @transition_into]
      attributes[:sequence] = @downgrade_sequence.negative? ? @sequence : @downgrade_sequence

      attributes
    end
  end
end
