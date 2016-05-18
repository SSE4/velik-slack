require "slack-ruby-client"

Slack::RealTime::Api::Message.module_eval do
  alias :message_old :message
  def message **args
    return unless args[:text]
    message_old **args
    sleep 1
  end
end

Slack::RealTime::Client.class_eval do
  alias :old_initialize :initialize
  def initialize *args
    old_initialize *args
    @callbacks = Hash.new{ |h, k| h[k] = [] }
  end
  protected
  def dispatch event
    return false unless event.data
    data = JSON.parse event.data
    return false unless type = data["type"]
    return false unless callbacks = @callbacks[type] + @callbacks["everything"]
    callbacks.each do |c|
      c.call data unless self.self["id"] == data["user"]
    end.empty? ^ true
  end
end


Slack.configure do |config|
  fail "missing ENV[\"SLACK_BOT_TOKEN\"]" unless config.token = ENV["SLACK_BOT_TOKEN"] || File.read("/var/tmp/secrets/SLACK_BOT_TOKEN")
end
SLACK_CLIENT = Slack::RealTime::Client.new
SLACK_CLIENT.on :hello do
  puts "connected as '#{SLACK_CLIENT.self["name"]}' to the '#{SLACK_CLIENT.team["name"]}' team at https://#{SLACK_CLIENT.team["domain"]}.slack.com"
end

SLACK_CLIENT.on :everything do |data|
  File.open("log", "a"){ |f| f.puts data.inspect }
end

SLACK_BINDS = [
  ["проверить пульс (свой, конечно, не мой же)", [
    %w{ ping pong },
    %w{ pong ping },
    %w{ пинг понг },
    %w{ понг пинг },
    %w{ gbyu gjyu },
  ] ],
  ["получить список доступных команд", [
    [["help", "рудз", "хелп", "[tkg"], ->_{ [
      "И что бы вы без меня делали? *Команды:*",
      *SLACK_BINDS.select(&:first).map{ |help, array| "`#{array.map(&:first).join ?|}` – #{help}" }
    ].join "\n" } ]
  ] ],
]

SLACK_CLIENT.on :message do |data|
  SLACK_BINDS.flat_map do |help, commands|
    commands.flat_map do |command, action|
      [*command].map{ |i| [i, action] }
    end
  end.each do |pattern, answer|
    next unless data["text"] && data["text"][pattern]
    answer = answer[data, *( (
      captures = pattern.match(data["text"]).captures
      captures if !captures.empty?
    ) if pattern.is_a? Regexp )] if answer.respond_to? :call
    SLACK_CLIENT.message channel: data["channel"], text: answer if answer
  end
end
