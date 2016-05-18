Gem::Specification.new do |spec|

  ## required for .gemspec
  spec.name = "velik-slack"
  spec.summary = "Slack bot based on an old version of slack-ruby-client"
  spec.authors = ["Victor Maslov"]
  spec.version = "0.0.1"
  spec.files = `git ls-files -z`.split ?\0
  spec.require_path = "./"

  ## not required for .gemspec
  # spec.license = "MIT"
  # spec.add_runtime_dependency "json"
  spec.add_runtime_dependency "slack-ruby-client", "=0.3.0"
  spec.required_ruby_version = ">= 2.0.0"

end
