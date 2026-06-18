# frozen_string_literal: true

# PM Agent integration configuration
# The PM Agent manages tickets and automation for this project.
#
# Required environment variables (set in .env):
#   PM_AGENT_URL     — base URL of the PM Agent API
#   PM_AGENT_API_KEY — API key for authenticating requests

PmAgentConfig = Struct.new(:url, :api_key, keyword_init: true).freeze

PM_AGENT = PmAgentConfig.new(
  url: ENV.fetch("PM_AGENT_URL", "http://localhost:3000"),
  api_key: ENV.fetch("PM_AGENT_API_KEY", "")
).freeze
