# Workflower

The Workflower gem is a Ruby implementation of a workflow state-based pattern tailored for Rails applications. It is a lightweight, flexible, and extensible workflow engine that can be used to implement a wide variety of workflows. The Workflower gem provides the a simple and intuitive way for defining workflows, workflow states, transitions, events, conditions, actions, and much more.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'workflower'
```

And then execute:

    bundle install

If bundler is not being used to manage dependencies, install the gem by executing:

    gem install workflower

## How it Works

The workflower gem consists of three main components:

- [Flow Class](lib/workflower/flow.rb): The Flow class is responsible for defining the workflow state machine.
- [Manager Class](lib/workflower/manager.rb): The Manager class is responsible for processing the workflow state machine.
- [Acts As Workflower Module](lib/workflower/acts_as_workflower.rb): The Acts As Workflower module is an ActiveSupport::Concern that is responsible for adding the workflow functionality to the model. This is done by defining some class and some instance methods. Under the hood both of the above classes are utilized to do all the heavy lifting.

### Flow Class (State Machine Definition)

The Flow class is responsible for defining the workflow state machine. It is mainly responsible for handling the workflow definition files. A workflow definition file is a ruby file that defines the workflow state machine check the **[Annex: 1.0: Workflow Definition File Example](#annex-10-workflow-definition-file-example)** to see how to define a workflow definition file.

The Flow class requires each state machine to be defined as a hash, and each state machine must have the following keys:

- `state`: The state name.
- `transition_into`: The state name that this state can transition into.
- `event`: The event name that triggers the transition.
- `sequence`: The sequence number of the transition. Can be used to define the order of the FSM transitions (good for re-usability but adds complexity).
- `downgrade_sequence`: The downgrade sequence number of the transition.
- `metadata`: The metadata hash that contains the following keys:
  - `roles`: An array of roles that are allowed to trigger the transition.
  - `type`: The type of the transition, it can be either `update` or `create`.
  - `required_parameters`: An array of required parameters that must be passed to the transition.
  - Optionally, you can add any other keys to the metadata hash. for example a `send_notifications`, key that can be used to indicate whether to send notifications or not. You can also define a `permitted_parameters` key that can be used to define the permitted parameters in [JSON Schema](https://json-schema.org/) format the **[Annex 1.1: JSON Schema Example](#annex-11-json-schema-example)** to see how to define a JSON Schema and validate them.

Each state can also optionally, have the following keys can be added to the hash:

- `condition`: The name of the method that will be called to check if the transition can be triggered. The method must return true or false.
- `before_transition`: The name of the method that will be called before the transition is triggered. Please check the [Process Flow](#process-flow) section for more details on the sequence in which the methods are called.
- `after_transition`: The name of the method that will be called after the transition is triggered. Please check the [Process Flow](#process-flow) section for more details on the sequence in which the methods are called.
- `condition_type`: The type of the condition, it can be `expression`, if not specified, it will be `method`. If the condition type is `expression`, the condition will be evaluated as an expression, otherwise it will be evaluated as a method.

Typically, the workflow definition files are placed in a directory called `workflow_definitions` in the `lib` directory. However, you can place the workflow definition files anywhere you want, as long as you specify the path to the workflow definition files in the `source` option when initializing the workflower gem. We recommend defining the workflow definition files like the given example in the **[Annex 1.0: Workflow Definition File Example](#annex-10-workflow-definition-file-example)**.

### Manager Class (State Machine Processor)

The Manager class is responsible for processing the workflow state machine. When initialized, it requires the following parameters:

- `calling_model`: The model that is calling the workflow state machine.
- `source`: The source of the workflow state machine. The source must be an object that responds to the `get_workflows` method and returns a hash of workflow state machines.

See the **[Annex 1.2: WorkflowSource Class Definition](#annex-12-workflow-source-example)** to see how to define a workflow source class.

The Manager class is responsible for the following:

- Initializing the workflow state machine.
- Processing the workflow state machine.
- Validating the workflow state machine.
- Providing the allowed events.
- Providing the allowed transitions.
- Providing the validation errors.

It also provides the following methods and accessors:

- `uninitialize`: Uninitializes the workflow state machine.
- `set_initial_state`: Sets the initial state of the workflow state machine (defaults to `saved`, but can be overridden).
- `process_transition!`: Processes the transition, please check the [Process Flow](#process-flow) section for more details on the sequence in which the methods are called.
- `allowed_events`: Returns the allowed events for the current state machine.
- `allowed_transitions`: Returns the allowed transitions from the current state machine.
- `validation_errors`: Returns the validation errors.
- `transition_possible?`: Checks if the transition is possible on the current state machine.

Please check the **[Annex 1.3: Workflowable](#annex-13-workflowable)** section for more details on how to use these methods and accessors.

<br>

#### Process Flow

The workflower's `process_transition!` method is responsible for processing the state transition. It uses the following steps to accomplish a transition:

  1. It first checks if the `condition`. If the condition is met, it proceeds with the transition. If the condition is not met, it adds an error on the field `workflow_state` with key `transition_faild` to the model.
  2. The first step in the transition process is calling the `before_transition` method. This method is provided either by explicitly defining it in the workflow definition file, or by defining it in the model. If the model, responds to a method with the name `before_<event_name>`.

     ```ruby
      class <ModelName> < ApplicationRecord
        # ...
        def before_event_name
          # ...
        end
        # ...
      end
      ```

     ```ruby
     # ./lib/workflow_definitions/<model_name>/<role_name>.rb
      # ...
      {
        state: '...',
        transition_into: '...',
        event: '...',
        #...
        before_transition: 'before_event_name_or_custom_method_name'
      }
     ```

  3. After invoking the before transition callback, the workflow fields (columns) are updated, as well as the required parameters defined in the metadata are assigned to the model. The record has not been saved yet.
  4. The next step is to call the `after_transition` method. This method is provided either by explicitly defining it in the workflow definition file, or by defining it in the model. If the model, responds to a method with the name `after_<event_name>`.

     ```ruby
      class <ModelName> < ApplicationRecord
        # ...
        def after_event_name
          # ...
        end
        # ...
      end
      ```

     ```ruby
     # ./lib/workflow_definitions/<model_name>/<role_name>.rb
      # ...
      {
        state: '...',
        transition_into: '...',
        event: '...',
        #...
        after_transition: 'after_event_name_or_custom_method_name'
      }
     ```

<br>

**IMPORTANT NOTE:**

- The `before_transition` and `after_transition` in the state definition have precedence over the `before_<event_name>` and `after_<event_name>` methods defined in the model.
- These callbacks are not transactional, so if you want to rollback the transaction, you have to wrap your controller action in a transaction block and make sure to raise an exception in the callback method if you want to rollback the transaction. Alternatively, you can take a look at [Annex 1.5: Before Save Callback Example](#annex-15-before-save-callback-example) to see how to use the `before_save` callback for a more transactional approach.

<br>

### Acts As Workflower Module (The concern that adds the workflow functionality to the model)

The Acts As Workflower module is an ActiveSupport::Concern that is responsible for adding the workflow functionality to the model. It consists of two main parts:

- **Instance Methods**: The instance methods are responsible for initializing the workflow state machine, processing the workflow state machine, and uninitializing the workflow state machine.
- **Class Methods**: The class methods are responsible for defining the workflow state machine, and defining the workflow abilities.

#### Instance Methods

This module allows the model to initialize, process, and uninitialize the workflow state machine. It also allows the model to access the allowed events, allowed transitions, and validation errors. Under the hood, it uses the [Manager Class](#manager-class-state-machine-processor) class to do all the heavy lifting.

Here is the list of instance methods and attributes provided by this module:

- `possible_events`: Returns the possible events for the current state machine.
- `allowed_events`: Returns the allowed events for the current state machine.
- `allowed_transitions`: Returns the allowed transitions from the current state machine.
- `workflow_transition_event_name`: Returns the name of the event that triggered the transition.
- `workflow_transition_flow`: Returns the flow object that contains the transition information.
- `set_initial_state`: Sets the initial state of the workflow state machine (defaults to `saved`, but can be overridden).
- `workflower_initial_state`: Returns the initial state of the workflow state machine (defaults to `saved`, but can be overridden).
- `workflower_base`: Returns the workflow manager object.
- `source_workflow`: Returns the workflow source object.
- `workflower_initializer`: Initializes the workflow state machine.
- `workflower_uninitializer`: Uninitializes the workflow state machine.

#### Class Methods

This module allows the model to define the workflow state machine, and define the workflow abilities. Under the hood, it uses the [Flow Class](#flow-class-state-machine-definition) class to do all the heavy lifting.

Here is the list of class methods provided by this module:

- `workflower`: Defines the workflow state machine. This is a must to be invoked in order for the workflow state machine to be initialized. See the **[Annex 1.4: Workflower Initialization](#annex14-workflower-class-definition)**.
- `workflower_abilities`: Defines the workflow abilities based on the `roles` defined in the workflow definition files.

## Annex

This section contains the annexes that are referenced in the above sections, please use them wisely to fully understand how the workflower gem works, you don't necessarily need to follow them all, but they are there to help you understand how to use the workflower gem.

### Annex 1.0: Workflow Definition File Example

```ruby
# ./lib/workflow_definitions/<model_name>/<role_name>.rb

module WorkflowDefinitions
  module <ModelName><RoleName>
    module V1
      def self.own_actions(seq = 1)
        [
          {
            state: "...",
            transition_into: "...",
            event: "...",
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[...],
              type: 'update',
              required_parameters: %i[]
            }
          }

          #...
        ]
      end

      def self.formulate(seq = 1)
        [
          *own_actions(seq)
        ]
      end
    end
  end
end
```

### Annex 1.1: JSON Schema Example

```ruby
# ./lib/workflow_definitions/<model_name>/<role_name>.rb
# ...
  metadata: { 
#   ...
    permitted_parameters: {
    '$schema': 'http://json-schema.org/draft-07/schema#',
      '$id': 'http://json-schema.org/draft-07/schema#',
      type: 'object',
      properties: {
        workflow_comment: { type: 'string' }
      },
      required: %i[workflow_comment]
    }
#   ...
  }
# ...
```

```ruby
# ./app/controllers/<model_name>_controller.rb
# ...
  def check_required_params_in_workflow(required_parameters = {})
    metadata = @resource.workflow_transition_flow&.metadata&.dig(:permitted_parameters)
  
    return if metadata.blank?
  
    metadata.except!(:$id, :$schema)
  
    errors = JSON::Validator.fully_validate(metadata, required_parameters)
  
    nil if errors.blank?
  end
# ...
```

### Annex 1.2: Workflow Source Example

```ruby
# ./app/models/concerns/workflows/<model_name>/workflow_source.rb

module Workflows
  class WorkflowSource
    Dir["#{Rails.application.root}/lib/workflow_definitions/<model_name>/*.rb"].each { |file| require file }

    def initialize(_model = nil)
      @workflows = {
        '1': [
          *WorkflowDefinitions::<ModelName><RoleName>::V1.formulate,
          *WorkflowDefinitions::<ModelName><RoleName>::V1.formulate
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
end
```

### Annex 1.3: Workflowable

```ruby
# ./app/models/concerns/workflows/<model_name>/workflowable.rb

module Workflowable
  def workflow_is_accessible_roles(given_workflow = workflow_state)
    source_workflow.select do |item|
      item[:state] == given_workflow && item.dig(:metadata, :roles).present?
    end.flat_map do |flow|
      condition_flow = flow[:condition]
      if condition_flow.blank?
        flow.dig(:metadata, :roles)
      else
        condition_type = flow[:condition_type] || ''
        if condition_type.present? && condition_type == 'expression'
          flow.dig(:metadata, :roles) if eval(condition_flow)
        elsif send(condition_flow)
          flow.dig(:metadata, :roles)
        end
      end
    end.compact.uniq
  end

  def reached_flow_stage_for_role?(role)
    workflow_is_accessible_roles.map(&:to_sym).include?(role.to_sym)
  end

  def apply_transition(event, &proc)
    workflower_initializer if allowed_transitions.nil?
    return false unless allowed_transitions.map(&:event).include?(event)

    proc.call
    return false unless send("can_#{event}?")

    send("#{event}!")
  end

  def selected_flow(event)
    allowed_transitions&.select { |flow| flow.event == event }.try(:first)
  end

  # rubocop:disable Style/OpenStructUse
  def structified_flow_metadata(event)
    selected = selected_flow(event)
    return [] if selected.blank? || selected.try(:metadata).blank?

    OpenStruct.new(selected.metadata)
  end

  def applicable_transitions_as_response(&callback)
    workflower_initializer

    workflower_base.allowed_transitions.map do |flow|
      { command: flow.event.to_sym, metadata: flow.metadata.try(:slice, :permitted_parameters) || {} }
    end
                   .reject { |action| callback.call(action) }
  end

  # Utilities
  def workflow_state_is?(state)
    workflow_state.to_sym == state.to_sym
  end

  def workflow_state_is_any_of?(*states)
    states.flatten.map { |item| item.to_sym if item.respond_to?(:to_sym) }.include?(workflow_state.to_sym)
  end

  def given_state_is_any_of?(*states, given_state:)
    states.flatten.map { |item| item.to_sym if item.respond_to?(:to_sym) }.include?(given_state.to_sym)
  end
end
```

### Annex 1.4: Workflower Class Definition

```ruby
# ./app/models/<model_name>.rb
# ...
  include Workflower::ActsAsWorkflower
# ...
  workflower source: Workflows::<ModelName>::WorkflowSource,
             workflower_state_column_name: 'workflow_state',
             default_workflow_id: 1,
             skip_setting_initial_state: true
# ...
```

### Annex 1.5: Before Save Callback Example

```ruby
# ./app/models/<model_name>.rb
class <ModelName> < ApplicationRecord  
  before_save :send_notification_for_application_approval, if: proc { |obj| obj.workflow_state_changed? && obj.workflow_transition_flow.try(:event) == 'approve_on_application_by_auditor' }
  before_save :set_applicant_status, if: proc { |obj| obj.workflow_transition_flow.try(:metadata).try(:[], :applicant_status).present? }


  def send_notification_for_application_approval
    # ...
  end
  
  def set_applicant_status
    # ...
  end
end
```

<br>

## Workflower Gem Usage with an Example

To fully understand how the workflower gem works, we will use a hypothetical example.

---
**Scenario**

To apply for a competition, an applicant creates an application. The applicant then submits the application for review by an auditor. The auditor reviews the application and decides whether to accept, reject, or ask for changes to the application. If any changes are requested, the applicant makes the changes and resubmits the application for review by the auditor. The auditor reviews the application and decides whether to accept, ask for more changes or reject the application.

---

---
**Finite State Machine Diagram:**

<img src="https://github.com/muhammadnawzad/workflower/assets/58137134/f948fc88-7e2d-4e6f-a8ff-5be4af165010" alt="Workflow Definition Example" width="500"/>

---

**Directory Structure Example:**

```
lib
└── workflow_definitions
├──── application
│ ├──── applicant.rb
│ ├──── auditor.rb
```

#### Workflow Definition Filesadsa Example

```ruby
# ./lib/workflow_definitions/applications/applicant.rb

module WorkflowDefinitions
  module ApplicationApplicant
    module V1
      def self.own_actions(seq = 1)
        [
          {
            state: 'saved',
            transition_into: 'submitted_for_review_by_applicant_to_auditor',
            event: 'submit_for_review_by_applicant_to_auditor',
            
            # Can optionally add a condition (method name in the model that return true/false):
            # condition: 'can_submit_for_review_by_applicant_to_auditor?',

            # Can optionally add an after_transition method (method name in the model):
            # after_transition: 'process_submission',

            # Can optionally add a before_transition method (method name in the model):
            # before_transition: 'process_submission',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[applicant],
              type: 'update',
              permitted_parameters: {
                '$schema': 'http://json-schema.org/draft-07/schema#',
                '$id': 'http://json-schema.org/draft-07/schema#',
                type: 'object',
                properties: {
                  workflow_comment: { type: 'string' }
                },
                required: %i[workflow_comment]
              },
              required_parameters: %i[workflow_comment]
            }
          },
          {
            state: 'sent_for_correction_by_auditor_to_applicant',
            transition_into: 'submitted_after_correction_by_applicant_to_auditor',
            event: 'submit_after_correction_by_applicant_to_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[guest],
              type: 'update',
              required_parameters: %i[]
            }
          }
        ]
      end

      def self.formulate(seq = 1)
        [
          *own_actions(seq)
        ]
      end
    end
  end
end
```

```ruby
# ./lib/workflow_definitions/applications/auditor.rb

module WorkflowDefinitions
  module ApplicationAuditor
    module V1
      def self.own_actions(seq = 1)
        [
          {
            state: 'submitted_for_review_by_applicant_to_auditor',
            transition_into: 'sent_for_correction_by_auditor_to_applicant',
            event: 'send_for_correction_by_auditor_to_applicant',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          },
          {
            state: 'submitted_for_review_by_applicant_to_auditor',
            transition_into: 'rejected_by_auditor',
            event: 'reject_application_by_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          },
          {
            state: 'submitted_for_review_by_applicant_to_auditor',
            transition_into: 'approved_by_auditor',
            event: 'approve_on_application_by_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          },
          {
            state: 'submitted_after_correction_by_applicant_to_auditor',
            transition_into: 'rejected_by_auditor',
            event: 'reject_application_by_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          },
          {
            state: 'submitted_after_correction_by_applicant_to_auditor',
            transition_into: 'approved_by_auditor',
            event: 'approve_on_application_by_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          },
          {
            state: 'submitted_after_correction_by_applicant_to_auditor',
            transition_into: 'sent_for_correction_by_auditor_to_applicant',
            event: 'send_for_correction_by_auditor_to_applicant',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[auditor],
              type: 'update',
              required_parameters: %i[]
            }
          }
        ]
      end

      def self.formulate(seq = 1)
        [
          *own_actions(seq)
        ]
      end
    end
  end
end
```

**Workflow Initialization:**

In order for the workflow to be initialized, the following steps must be taken:

1. Add the following columns to your model's table (e.g. Application model):

    ```ruby
        # ...
        t.string  :workflow_state, null: false, default: 'saved', index: true
        t.integer :sequence, null: false, default: 1
        t.integer :workflow_id, null: false, default: 1
        # ...
    ```

2. Add the following lines to your model:

    ```ruby
    class Application < ApplicationRecord
      include Workflower::ActsAsWorkflower # Example is given below
      
      # Workflower
      workflower source: Workflows::Applications::WorkflowSource,
                 workflower_state_column_name: 'workflow_state',
                 default_workflow_id: 1,
                 skip_setting_initial_state: true
    end
    ```

3. Let's define `Workflows::WorkflowSource` module.

    ```ruby
    # ./app/models/concerns/workflows/applications/workflow_source.rb

    module Workflows
      class WorkflowSource
        Dir["#{Rails.application.root}/lib/workflow_definitions/application/*.rb"].each { |file| require file }
  
        def initialize(_model = nil)
          @workflows = {
            '1': [
              *WorkflowDefinitions::ApplicationApplicant::V1.formulate,
              *WorkflowDefinitions::ApplicationAuditor::V1.formulate
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
    end
    ```

4. Add the [Workflowable](#annex-13-workflowable) concern module to your model:

    ```ruby
    class Application < ApplicationRecord
      # ...
      include Workflowable # Example is given below
      
      #...
    end
    ```

5. Add [CanCanCan](https://github.com/CanCanCommunity/cancancan) abilities, or your choice of authorizations, in our case, add the following lines to your `Ability` class:

   ```ruby
   class Ability
     include CanCan::Ability

     def initialize(user)
       # ...
       if user.role_is_a?('applicant')
         can %i[submit_for_review_by_applicant_to_auditor], Application
         can %i[submit_after_correction_by_applicant_to_auditor], Application
       elsif user.role_is_a?('auditor')
         can %i[send_for_correction_by_auditor_to_applicant], Application
         can %i[reject_application_by_auditor], Application
         can %i[approve_on_application_by_auditor], Application
       end
     
       # Or you can use the following dynamic approach for a more advanced approach:
       #   (Applicant.workflower_abilities.try(:with_indifferent_access).try(:[], :guest) || []).each do |action|
       #     can action.to_sym, Applicant do |instance|
       #       instance.reached_flow_stage_for_role?(:guest) && instance.creator_id == user.id
       #     end
       #   end 
  
       # ...
     end
   end
   ```

6. Handle the workflow transition in your controller (the following example is for the sake of simplicity, you can use a service object or any other approach):

   ```ruby
   class ApplicationsController < ApplicationController
     # ...
   def transit
      @resource = Application.where(id: params[:id])# .include(eager_loads)

      raise ActiveRecord::RecordNotFound if @resource.blank?
      @resource = @resource.first
   
      event = params[:event]
      @resource.workflower_initializer
      selected_flow_metadata = @resource.structified_flow_metadata(event)
      @resource.assign_attributes(transition_extra_params(selected_flow_metadata)) if %w[update amend].include?(selected_flow_metadata.try(:type))

      transition_check = @resource.apply_transition(event) do
        authorize! event.to_sym, @resource
      end

      if transition_check
        # Now save
        if @resource.save
          @resource.workflower_uninitializer
          render jsonapi: @resource and return
        else
          # render errors and return if @resource.errors.any?
        end
      end

      # render errors if reached here
    end
   
    def transition_extra_params(given_flow)
      return flow_extra_parameters(given_flow) if given_flow.present? && given_flow.try(:permitted_parameters).present?
    end
     # ...
   end
   ```

7. Add the following lines to your `routes.rb` file:

   ```ruby
   # ...
   resources :applications do
     member do
       post '/transit/:event', to: "applications#transit"
     end
   end
   # ...
   ```

<br>

The above steps are the minimum required steps to initialize the workflow state machine. However, you can add more steps to customize the workflow state machine to your needs. There is a lot more room for customization.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/[USERNAME]/workflower>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Workflower project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).
