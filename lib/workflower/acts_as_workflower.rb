module Workflower
    mattr_accessor :workflower_state_column_name, :default_workflow_id
    module ActsAsWorkflower
        extend ActiveSupport::Concern

        module InstanceMethods 
          #mattr_accessor :workflower_base
          attr_accessor :possible_events, :allowed_events, :allowed_transitions

          def set_intial_state
            write_attribute self.class.workflower_state_column_name, self.workflower_initial_state
          end

          def workflower_initial_state
            workflower_base.set_initial_state
          end

          def workflower_base
            return @workflower_base
          end

          def source_workflow
            @source_workflow_instance ||= self.source.new(self)
            @source_workflow_instance.get_workflows_for_workflow_id(workflow_id)
          end

          def workflower_initializer
            @source_workflow_instance ||= self.source.new(self)

            @workflower_base ||= Workflower::Manager.new(self, @source_workflow_instance)
            
            @workflower_base.allowed_transitions.each do |flow|
              define_singleton_method "#{flow.trigger_action_name}" do 
                @workflower_base.process_transition!(flow)
              end

              define_singleton_method "#{flow.boolean_action_name}" do 
                @workflower_base.transition_possible?(flow)
              end
            end

            @possible_events     ||= @workflower_base.events
            @allowed_events      ||= @workflower_base.allowed_events
            @allowed_transitions ||= @workflower_base.allowed_transitions
          end 

          def initialize(*)
            super 
            write_attribute :workflow_id, self.default_workflow_id if workflow_id.blank?
            
            workflower_initializer
            
          end
        end
        
        
        module ClassMethods
          def workflower(workflower_state_column_name: "workflow_state", default_workflow_id:, source:)
            raise Workflower::WorkflowerError.new("Options can't be blank") if source.blank? || default_workflow_id.blank?
            cattr_accessor :source,                       default: source
            cattr_accessor :workflower_state_column_name, default: workflower_state_column_name
            cattr_accessor :default_workflow_id,          default: default_workflow_id

            self.workflower_state_column_name = workflower_state_column_name
            self.source                       = source
            self.default_workflow_id          = default_workflow_id
            
            #self.validates  "#{workflow_model.tableize.singularize}_id", presence: true
            self.before_create :set_intial_state
            
          end

          def workflower_abilities
            load = source.new(self.new).get_workflows.values.flatten.uniq

            unless load.blank?
              #transitions = load.transitions.where("(metadata->>'roles') IS NOT NULL") 
              transitions = load.select { |item| item.try(:[], :metadata).try(:key?, :roles)}
              
              roles = transitions.map{ |item| item[:metadata][:roles] }.flatten.uniq

              roles_hash = Hash.new

              roles.each do |role|
                roles_hash[role] = transitions.select { |trans| trans[:metadata][:roles].to_a.include?(role) }.map {|item| item[:event] }.uniq 
              end

              return roles_hash
            end
          end
        end
        
        def self.included(base)
          base.send  :include, InstanceMethods
          base.extend(ClassMethods)
        end
    end 
end
