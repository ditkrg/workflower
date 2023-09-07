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

### Workflow Definition Usage Example

The below example shows a directory structure for a workflow definition directory. The directory structure is based on
the model name. The model name is the name of the model that the workflow is being defined for. The model name is used
to identify the workflow definition directory. The workflow definition directory contains the workflow definition files.
The workflow definition files are named after the user roles that are associated with the workflow state. The workflow definition
files contain the workflow state definitions (Examples provided below). The workflow definition files are Ruby files that are evaluated at runtime.

[//]: # "TODO: Add a finite state machine diagram image for the below example."

<center>
    <img src="https://drive.google.com/u/2/uc?id=1NIvX8fd0MaI21hYraxTJrlwgvtFeuVva&export=download" alt="Workflow Definition Example" width="500"/>

</center>
    The above diagram is a finite state machine diagram for the workflow definition example. Which is a hypothetical illustration of a workflow where an applicant submits an application for review by an auditor. The auditor reviews the application and sends it back to the applicant for correction. The applicant corrects the application and submits it back to the auditor for review. The auditor reviews the application and approves it or rejects it.

<br>

**Directory Structure Example:**

```
lib
└── workflow_definitions
├── model_name
│ ├── applicant.rb
│ ├── auditor.rb
```

**Workflow Definition File Example:**

Consider a hypothetical workflow definition file for the `applicant` role. The workflow definition file is named
`applicant.rb` and is located in the `lib/workflow_definitions/model_name` directory.

<br>
<details>
<summary>Click here to toggle the contents of applicant.rb</summary>

```ruby
  # applicant.rb

    module WorkflowDefinitions
        module ModelName
            module V1
                def self.own_actions(seq = 1)
        [
          {
            state: 'saved',
            transition_into: 'submitted_for_review_by_applicant_to_auditor',
            event: 'submit_for_review_by_applicant_to_auditor',
            sequence: seq,
            downgrade_sequence: -1,
            metadata: {
              roles: %w[guest],
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

</details>

<br>

<details>
<summary>Click here to toggle the contents of auditor.rb</summary>

```ruby
# auditor.rb

module WorkflowDefinitions
  module ModelName
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

</details>

<br>

**Workflow Initialization:**

In order for the workflow to be initialized, the following steps must be taken:

- The `workflow_state`, `sequence`, `workflow_id` columns must be added to the model's table.
- The `workflow_state` column must be initialized with the `saved` value.
- The `Workflows::WorkflowSource` module should be defined in model's concern.
    <details>
    <summary>See the example:</summary>

  ```ruby
  module Workflows
    class WorkflowSource
      Dir["#{Rails.application.root}/lib/workflow_definitions/model_name/*.rb"].each { |file| require file }

      def initialize(_model = nil)
        @workflows = {
          '1': [
            *WorkflowDefinitions::ModelNameApplicant::V1.formulate,
            *WorkflowDefinitions::ModelNameAuditor::V1.formulate
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

    </details>

- Include the `include Workflower::ActsAsWorkflower` module in the model which comes with gem.
- Add the following lines under the `include Workflower::ActsAsWorkflower` line in the model:
  ```
    workflower source: Workflows::WorkflowSource,
    workflower_state_column_name: 'workflow_state',
    default_workflow_id: 1,
    skip_setting_initial_state: true
  ```

### Workflow Methods

The followings are some methods provided by the gem.

| Method                   | Description                                  |
| ------------------------ | -------------------------------------------- |
| workflower_initializer   | Used for initializing workflow for a model   |
| workflower_uninitializer | Used for uninitializing workflow for a model |
| source_workflow          | Returns source of a workflow                 |
| workflower_initial_state | Return initial state of a workflow           |

<!-- attr_accessor :possible_events, :allowed_events, :allowed_transitions, :workflow_transition_event_name, :workflow_transition_flow -->

### Workflow Attribute Accessors

The followings are some attribute accessors provided by the gem.
| Attribute | Description |
|---------------------------------|----------------------------------------------|
| possible_events | Returns possible events for a instance |
| allowed_events | Returns allowed events for a instance |
| allowed_transitions | Returns allowed transitions for a instance |
| workflow_transition_event_name | Returns event name for a transition |
| workflow_transition_flow | Returns possible flows for a transition |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/workflower. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Workflower project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/workflower/blob/master/CODE_OF_CONDUCT.md).
