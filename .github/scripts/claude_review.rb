# frozen_string_literal: true

# claude_review.rb — Performs automated code review using Claude API directly.
#
# Required environment variables:
#   GITHUB_TOKEN   — GitHub token with pull-requests:write permission
#   CLAUDE_API_KEY — Anthropic Claude API key

require "net/http"
require "json"
require "uri"

GITHUB_TOKEN   = ENV.fetch("GITHUB_TOKEN") { raise "Missing required env var: GITHUB_TOKEN" }
CLAUDE_API_KEY = ENV.fetch("CLAUDE_API_KEY") { raise "Missing required env var: CLAUDE_API_KEY" }

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
CLAUDE_MODEL      = ENV.fetch("CLAUDE_MODEL", "claude-sonnet-4-5")
MAX_TOKENS        = 4096

github_ref_match = ENV["GITHUB_REF"]&.match(%r{refs/pull/(\d+)/merge})
raise "Could not parse PR number from GITHUB_REF: #{ENV["GITHUB_REF"].inspect}" unless github_ref_match

PR_NUMBER = github_ref_match[1]
REPO      = ENV.fetch("GITHUB_REPOSITORY") { raise "Missing required env var: GITHUB_REPOSITORY" }

GITHUB_API_BASE = "https://api.github.com"

def github_request(path, accept: "application/vnd.github+json")
  uri = URI.parse("#{GITHUB_API_BASE}#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"]        = "Bearer #{GITHUB_TOKEN}"
  req["Accept"]               = accept
  req["X-GitHub-Api-Version"] = "2022-11-28"
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
end

def fetch_pr_diff
  res = github_request("/repos/#{REPO}/pulls/#{PR_NUMBER}", accept: "application/vnd.github.diff")
  raise "Failed to fetch PR diff: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

  res.body
end

def fetch_pr_metadata
  res = github_request("/repos/#{REPO}/pulls/#{PR_NUMBER}")
  raise "Failed to fetch PR metadata: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

  data = JSON.parse(res.body)
  { sha: data.dig("head", "sha"), url: data["html_url"] }
end

def call_claude(diff)
  uri = URI.parse(ANTHROPIC_API_URL)
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"]      = "application/json"
  req["x-api-key"]         = CLAUDE_API_KEY
  req["anthropic-version"] = ANTHROPIC_VERSION

  prompt = <<~PROMPT
    You are a strict code reviewer. Your job is to analyze the PR diff below and identify meaningful issues.

    Focus on:
    - Bugs, logic errors, and incorrect behavior
    - Security vulnerabilities
    - Missing error handling for critical paths
    - Obvious violations of clean code principles

    Do NOT flag:
    - Style preferences not backed by a documented rule
    - General suggestions or nice-to-have improvements
    - Trivial naming preferences

    ## PR Diff

    ```diff
    #{diff}
    ```

    Respond ONLY with valid JSON in this exact format (no markdown wrapping):
    {
      "summary": "Brief overall assessment of the PR",
      "approved": true,
      "violations": [
        {
          "path": "relative/path/to/file.rb",
          "line": 42,
          "severity": "error",
          "comment": "Description of the issue and why it matters"
        }
      ]
    }

    Rules:
    - Only include violations for added lines (starting with +) in the diff
    - "line" must be the actual line number in the new version of the file
    - "approved" is false only when there are "error" severity violations
    - severity "error": bug, security issue, or critical logic error
    - severity "warning": non-critical concern worth addressing
    - If no violations found, return empty array and approved: true
  PROMPT

  body = {
    model: CLAUDE_MODEL,
    max_tokens: MAX_TOKENS,
    messages: [ { role: "user", content: prompt } ]
  }

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req, body.to_json) }
  raise "Claude API failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

  parsed = JSON.parse(res.body)
  raw_text = parsed.dig("content", 0, "text").to_s.strip
  parse_claude_response(raw_text)
end

def parse_claude_response(raw_text)
  JSON.parse(raw_text)
rescue JSON::ParserError => first_error
  json_match = raw_text.match(/(\{.*\})/m)
  if json_match
    begin
      return JSON.parse(json_match[1])
    rescue JSON::ParserError
      nil
    end
  end

  markdown_match = raw_text.match(/```json\s*(.*?)\s*```/m)
  if markdown_match
    begin
      return JSON.parse(markdown_match[1])
    rescue JSON::ParserError
      nil
    end
  end

  puts "ERROR: Could not parse Claude response. Raw response:\n#{raw_text}"
  raise first_error
end

def submit_review(commit_id, summary, approved, violations)
  uri = URI.parse("#{GITHUB_API_BASE}/repos/#{REPO}/pulls/#{PR_NUMBER}/reviews")
  req = Net::HTTP::Post.new(uri)
  req["Authorization"]        = "Bearer #{GITHUB_TOKEN}"
  req["Accept"]               = "application/vnd.github+json"
  req["Content-Type"]         = "application/json"
  req["X-GitHub-Api-Version"] = "2022-11-28"

  inline_comments = Array(violations)
    .select { |v| v["path"] && v["line"] }
    .map { |v| { path: v["path"], line: v["line"].to_i, side: "RIGHT", body: v["comment"].to_s } }

  payload = {
    commit_id: commit_id,
    body: summary.to_s,
    event: approved ? "COMMENT" : "REQUEST_CHANGES"
  }
  payload[:comments] = inline_comments if inline_comments.any?

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req, payload.to_json) }
  raise "Failed to submit review: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body)
end

diff     = fetch_pr_diff
metadata = fetch_pr_metadata

puts "Reviewing PR ##{PR_NUMBER}: #{metadata[:url]}"
puts "Sending diff to Claude (#{diff.length} chars)..."

analysis = call_claude(diff)

puts "Claude response — approved: #{analysis['approved']}, violations: #{Array(analysis['violations']).length}"

result = submit_review(metadata[:sha], analysis["summary"], analysis["approved"], analysis["violations"])
puts "Review submitted: id=#{result['id']}"
