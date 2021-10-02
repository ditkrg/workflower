# frozen_string_literal: true

require "active_support"

# Workflower Module Defintion
module Workflower
  mattr_accessor :workflower_state_column_name
  mattr_accessor :workflow_model
  mattr_accessor :transition_model
  mattr_accessor :conditions

  # ActsAsWorkflower Module Definition
  module ActsAsWorkflower
    extend ActiveSupport::Concern

    # InstanceMethods
    module InstanceMethods
      # mattr_accessor :workflower_base
      attr_accessor :possible_events, :allowed_events, :allowed_transitions, :workflow_transition_event_name,
                    :workflow_transition_flow

      def set_intial_state
        write_attribute self.class.workflower_state_column_name, workflower_initial_state
      end

      def workflower_initial_state
        workflower_base.set_initial_state
      end

      def workflower_base
        @workflower_base
      end

      def source_workflow
        source.get_workflows_for_workflow_id(workflow_id)
      end

      def workflower_initializer
        @workflower_base ||= Workflower::Manager.new(self, source)

        @workflower_base.allowed_transitions.each do |flow|
          define_singleton_method flow.trigger_action_name.to_s do
            @workflow_transition_event_name = flow.event
            @workflow_transition_flow = flow
            @workflower_base.process_transition!(flow)
          end

          define_singleton_method flow.boolean_action_name.to_s do
            @workflower_base.transition_possible?(flow)
          end
        end

        @possible_events     ||= @workflower_base.events
        @allowed_events      ||= @workflower_base.allowed_events
        @allowed_transitions ||= @workflower_base.allowed_transitions
      end

      def initialize(*)
        super
        write_attribute :workflow_id, source.get_workflows.keys.last.to_s.to_i if workflow_id.blank?

        workflower_initializer
      end
    end

    # Class Methods
    module ClassMethods
      # rubocop:disable Metrics/AbcSize
      def workflower(options = { workflower_state_column_name: "workflow_state" })
        if options[:source].blank? || options[:conditions].blank?
          raise Workflower::WorkflowerError, "Options can't be blank"
        end

        cattr_accessor :source,                       default: options[:source]
        cattr_accessor :conditions,                   default: options[:conditions]
        cattr_accessor :workflower_state_column_name, default: options[:workflower_state_column_name]

        self.workflower_state_column_name = options[:workflower_state_column_name]
        self.source                       = options[:source]
        self.conditions                   = options[:conditions]

        # self.validates  "#{workflow_model.tableize.singularize}_id", presence: true
        before_create :set_intial_state
      end

      def workflower_abilities
        load = source.get_workflows.values.flatten.uniq

        return [] if load.blank?

        # transitions = load.transitions.where("(metadata->>'roles') IS NOT NULL")
        transitions = load.select { |item| item.try(:[], :metadata).try(:key?, :roles) }

        roles = transitions.map { |item| item[:metadata][:roles] }.flatten.uniq

        roles_hash = {}

        roles.each do |role|
          roles_hash[role] = transitions.select do |trans|
                               trans[:metadata][:roles].to_a.include?(role)
                             end.map { |item| item[:event] }.uniq
        end

        roles_hash
      end
    end

    def self.included(base)
      base.send :include, InstanceMethods
      base.extend(ClassMethods)
    end
  end
end
