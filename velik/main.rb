STDOUT.sync = true

require "velik-slack"

require_relative "../../../awsstatus/2.rb" unless ENV["LOGNAME"] == "nakilon"

SLACK_CLIENT.on :message do |data|
  AWSStatus::touch
end


chat = lambda do
  next ->*{} if ENV["LOGNAME"] == "nakilon"
  require_relative "wordize"
  require "digest"
  require "set"
  hash = Hash[ File.read("array.txt.lfs").scan(/(\d+) (.+)/).map do |i, s|
    [i.to_i, s.split.map(&:to_i).each_slice(2)]
  end ]
  good = Set.new File.read("good.txt.lfs").split
  base = File.open "text.txt.lfs"
  lambda do |data|
    h = wordize(data["text"]).flat_map do |word|
      next unless good.include? word
      t = word.size * 100 / data["text"].split.join.size
      [*hash[Digest::MD5.hexdigest(word)[0,6].hex]].map do |percent, phrase|
        [phrase, t * percent / 100]
      end
    end.compact.group_by(&:first).map{ |l, s| [l, s.map(&:last).inject(:+)] }.sort
    next if h.empty?

    base.rewind
    result = []
    i = -2
    until h.empty? do
      a, b = b, base.gets.chomp
      next unless h[0][0] == i += 1
      v = h.shift
      result << [(v[1].zero? ? 1 : v[1]), b] unless a.split.size < 2
    end
    next if result.empty?

    best10 = result.sort_by(&:first).last(10)
    best = best10.map do |chance, text|
      [chance ** 4 * 100 / best10.map(&:first).max ** 4, chance, text]
    end
    puts best.map{ |x| "%3s %3s%% '%s'" % x }.join ?\n
    text, chance = best.flat_map do |chance, true_chance, text|
      [[text, true_chance]] * chance
    end.sample

    text if rand(100) < chance
  end
end.call
SLACK_BINDS << [nil, [[/\S/, chat]]]

require_relative "wa"
SLACK_BINDS << ["спросить у Wolfram Alpha", [
  [/\A!(?:wa|цф|ва)\s+(\S.*?)\s*$/i, lambda do |data, query|
    # SLACK_CLIENT.typing channel: data["channel"]
    # [data, query].inspect
    wa(query).join ?\n
  end],
] ]


# client.typing channel: data["channel"]
# client.message channel: data["channel"], text: "Sorry <@#{data["user"]}>, what?"
SLACK_CLIENT.start!
