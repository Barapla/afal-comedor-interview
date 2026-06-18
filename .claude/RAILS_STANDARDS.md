# RAILS_STANDARDS.md — Ruby on Rails Standards
> Stack-specific rules for Rails projects. Complements ENGINEERING_STANDARDS.md.
> Base stack: Rails (API mode), PostgreSQL, Redis, Sidekiq, RSpec.

---

## Result Pattern

Every service object returns a `Result`. Never throw exceptions to the caller — encapsulate them in Result.

```ruby
# Success
Result.success(data: value)
Result.success(record: model_instance)

# Failure
Result.failure(error: :validation_error, message: "human-readable description")
Result.failure(error: e.message)
```

### Verification in the Caller
```ruby
result = PmAgent::MyService.new(params).call

if result.success?
  render json: { record: MySerializer.new(result.data) }
else
  render json: { error: { code: result.error, message: result.message } }, status: :unprocessable_entity
end
```

---

## Service Objects

### Structure
```ruby
module PmAgent
  class MyService
    def initialize(param_one:, param_two:)
      @param_one = param_one
      @param_two = param_two
    end

    def call
      # main logic
      Result.success(data: result)
    rescue => e
      Result.failure(error: e.message)
    end

    private

    attr_reader :param_one, :param_two

    def helper_method
      # ...
    end
  end
end
```

### Namespacing
- `PmAgent::` — main domain logic (tickets, projects)
- `Clickup::` — ClickUp API integration
- `Claude::` — Claude AI integration
- `Github::` — GitHub API integration
- `Projects::` — project logic
- `Automation::` — jobs and automation services

### Rules
- One service, one responsibility
- Any logic that is not simple CRUD → service object
- Controllers only call services and render — no business logic
- Do not use `rescue Exception` — only `rescue StandardError` (or specific subclasses)

---

## Serializers

```ruby
class MySerializer
  def initialize(record)
    @record = record
  end

  def as_json(*)
    {
      id: record.id,
      name: record.name,
      created_at: record.created_at.iso8601
    }
  end

  private

  attr_reader :record
end
```

### Prohibitions
```ruby
render json: @record          # ❌ never — always use serializer
render json: @record.to_json  # ❌ never
```

### Response Format
```ruby
# Single resource
render json: { record: MySerializer.new(@record).as_json }

# Collection
render json: { records: @records.map { |r| MySerializer.new(r).as_json } }

# Error
render json: { error: { code: "not_found", message: "..." } }, status: :not_found
```

---

## Controllers

### Structure
```ruby
module Api
  module V1
    class TicketsController < ApplicationController
      before_action :authenticate!
      before_action :set_record, only: [:show, :update]

      def show
        render json: { record: TicketSerializer.new(@record).as_json }
      end

      def create
        result = PmAgent::CreateTicketService.new(ticket_params).call
        if result.success?
          render json: { record: TicketSerializer.new(result.record).as_json }, status: :created
        else
          render json: { error: { code: result.error, message: result.message } }, status: :unprocessable_entity
        end
      end

      private

      def set_record
        @record = TicketLog.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "not_found", message: "Ticket not found" } }, status: :not_found
      end

      def ticket_params
        params.require(:ticket).permit(:title, :description)
      end
    end
  end
end
```

### Routes
- Always version: `/api/v1/`
- Use `namespace :api do namespace :v1 do` in routes.rb
- snake_case in all parameters and responses

---

## Database

### Migrations
```ruby
class AddStatusToTicketLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :ticket_logs, :status, :string, null: false, default: "pending"
    add_index :ticket_logs, :status
  end
end
```

### Rules
- Migrations always reversible (`change` or `up`/`down` pair)
- Indexes on columns used in `WHERE`, `ORDER`, `JOIN`
- Constraints in DB + validations in model (both layers)
- String columns without explicit `limit` — Rails + PostgreSQL handle the default
- Do not specify charset in migrations — inherited from DB configuration
- Never modify migrations already merged to `development` — create a new migration

### Models
```ruby
class TicketLog < ApplicationRecord
  belongs_to :project

  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :identifier, presence: true, uniqueness: { scope: :project_id }

  VALID_STATUSES = %w[pending success error completed].freeze
end
```

### Prohibitions
```ruby
ENV["CLICKUP_LIST_ID"]  # ❌ list_id lives in DB per project, not in .env
Project.first           # ❌ always search by name or specific attribute
```

---

## RuboCop

### Configuration
The project uses `rubocop-rails-omakase` (Standard). Configuration lives in `.rubocop.yml`.

### Before Each Commit
```bash
bundle exec rubocop
```

### Zero Tolerance
- Push with RuboCop offenses is prohibited
- Do not use `# rubocop:disable` without justification in a comment
- Do not modify `.rubocop.yml` to silence offenses — fix the code

### Common Patterns
```ruby
# ❌ rubocop offense
def method()
end

# ✅ correct
def method
end

# ❌ unnecessary string interpolation
"#{variable}"

# ✅ correct
variable.to_s
```

---

## Brakeman (Security)

### Before Each Commit
```bash
bundle exec brakeman
```

### Rules
- 0 new warnings — compare against project baseline
- If Brakeman reports a warning in code you did not touch → investigate, do not ignore
- Do not use `brakeman --ignore-config` to silence — fix the code

### Most Common Vulnerabilities to Avoid
- Mass assignment without explicit `permit`
- SQL injection via string interpolation in queries
- Command injection via `system`, `exec`, `%x{}`
- Redirect to user-controlled URLs without validation

---

## Testing with RSpec

### File Structure
```
spec/
  requests/api/v1/     # Request specs for endpoints
  services/            # Unit specs for services
  models/              # Model specs (validations, scopes)
  factories/           # FactoryBot factories
  support/             # Shared helpers (api_helpers, etc.)
```

### Conventions
```ruby
RSpec.describe PmAgent::MyService, type: :service do
  subject(:service) { described_class.new(param: value) }

  describe "#call" do
    context "when the input is valid" do
      it "returns a success result" do
        result = service.call
        expect(result).to be_success
        expect(result.data).to eq(expected_value)
      end
    end

    context "when the record is not found" do
      it "returns a failure result" do
        result = service.call
        expect(result).to be_failure
        expect(result.error).to eq(:not_found)
      end
    end
  end
end
```

### Minimum Coverage
- 70% global
- 90% in service objects

### Rules
- FactoryBot always — never fixtures
- Request specs for ALL endpoints
- Validation tests with pure RSpec — do NOT use `shoulda-matchers`
- Factories with `sequence` and `Faker` are valid — semantically descriptive Faker is not required
- Manual DB constraint testing (bypassing model validations) is the correct pattern for verifying unique indexes

### WebMock for HTTP
```ruby
stub_request(:post, "https://api.clickup.com/api/v2/task")
  .with(
    headers: { "Authorization" => "test_token" },
    body: hash_including(name: "Task Title")
  )
  .to_return(
    status: 200,
    body: { id: "abc123", status: { status: "to do" } }.to_json,
    headers: { "Content-Type" => "application/json" }
  )
```

### FactoryBot
```ruby
FactoryBot.define do
  factory :ticket_log do
    sequence(:identifier) { |n| "FEAT-#{n.to_s.rjust(3, '0')}" }
    status { "pending" }
    association :project

    trait :completed do
      status { "completed" }
      completion_data { { pr_url: "https://github.com/..." } }
    end
  end
end
```

---

## Jobs (Sidekiq)

### Structure
```ruby
class MyJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 3

  def perform(ticket_log_id)
    ticket_log = TicketLog.find_by(id: ticket_log_id)
    return unless ticket_log

    result = PmAgent::MyService.new(ticket_log: ticket_log).call
    Rails.logger.info("[MyJob] Completed for #{ticket_log_id}: #{result.success?}")
  end
end
```

### Queues
- `default` — general jobs and polling
- `automation` — automation jobs (Claude execution, back to dev)

### Rules
- Jobs must be idempotent — they can run more than once without adverse effects
- Verify the resource state at the start of the job — do not assume the state is as expected
- External API errors → log without re-raise (do not exhaust retries)
- Internal logic errors → allow Sidekiq to retry