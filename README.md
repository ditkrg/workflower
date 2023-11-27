# Workflower

The Workflower gem is a Ruby implementation of a workflow state-based pattern tailored for Rails applications. It is a
lightweight, flexible, and extensible workflow engine that can be used to implement a wide variety of workflows.

The Workflower gem provides the a simple and intuitive way for defining workflows, workflow states, transitions, events,
conditions, actions, and much more.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'workflower'
```

And then execute:

    $ bundle install

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install workflower

## Usage

The installation command above will install the Workflower gem and its dependencies. However, the workflower gem does
not provide any workflow definitions. The Workflower gem is designed to be used in conjunction with a workflow
definition directory, usually placed in `lib/workflow_definitions`. In this directory you should define the workflow
state machine as per your need. Below here is a brief example of how to define a workflow state machine, note that
this is an opinionated example and you can define your workflow state machine as per your need and your structure.

### Workflow Definition Usage with Example

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

<br>

**Workflow Definition File Example:**

<br>

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
              required_parameters: %i[]
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


<br>

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

<br>

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


## Process Flow

The workflower's `process_transition!` method is responsible for processing the transition. It first checks if the condition is met. If the condition is met, it calls the `before_transition` method, then it updates the model's attributes, and finally it calls the `after_transition` method. If the condition is not met, it adds an error to the model.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/workflower. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Workflower project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).
