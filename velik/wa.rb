# WA_APPID="..." bundle exec irb -r ./wa.rb

require "open-uri"
require "nokogiri"
require "digest"
require "fileutils"
require "mll"

FileUtils.mkdir_p "cache"
def cache_text_for_a_day id
  Dir.glob("cache/*").each do |path|
    FileUtils.rm_r path if Time.now.to_i - 3600*24 > File.basename(path).to_i
  end
  Dir.glob("cache/*/*").each do |path|
    return File.read path if id == File.basename(path)
  end
  yield.tap do |result|
    dir = "cache/#{Time.now.to_i / 1000 * 1000}"
    FileUtils.mkdir_p dir
    File.write "#{dir}/#{id}", result
  end
end

fail "Missing ENV[\"WA_APPID\"]!" unless ENV["WA_APPID"]
def wa query
  text = cache_text_for_a_day(Digest::MD5.hexdigest query.inspect) do
    open "http://api.wolframalpha.com/v2/query?input=#{CGI.escape query}&appid=#{ENV["WA_APPID"]}&excludepodid=NumberName&excludepodid=Illustration", &:read
  end
  xml = Nokogiri::XML text
  [].tap do |results|
    unless %w{ queryresult } == node_names = xml.element_children.map(&:node_name)
      next results.push "top level nodes are not ['queryresult']: #{node_names}"
    end
    next results.push "number of <queryresult> tags is not 1" unless 1 == xml.search("queryresult").size
    push_table = lambda do |title, array|
      results.push "#{title}:\n```" + MLL::grid[array.map{ |line| line.split /\s+\|\s+/ }, spacings: [2, 0], frame: :all].
        sub(/\A.+\n/, "").gsub(/┃ (.+)\s+┃\n/, "\\1\n").sub(/\n.+\n\z/, "```")
    end
    data = []
    data_title = nil
    xml.element_children.first.element_children.each do |node|
      case node.node_name
      when "pod"
        unless (weird = node.keys - %w{ primary title scanner id position error numsubpods }).empty?
          next results.push "unknown attributes #{weird} of pod: ```#{node}```"
        end
        next results.push "pod[\"error\"] != false: ```#{node}```" unless "false" == node["error"]
        poddata = []
        # TODO move higher and check that it happends only once?
        poddata_title = nil
        node.element_children.each do |subpod|
          case subpod.node_name
          when "subpod"
            output_stack = []
            subpod.element_children.each do |subsub|
              case subsub.node_name
              when "img"
                unless (weird = subsub.keys - %w{ src alt title width height }).empty?
                  next results.push "unknown attributes #{weird} of <#{subsub.node_name}>: ```#{node}```"
                end
                # output_stack.push "#{subsub["src"]}" unless "Numeric" == node["scanner"]
              when "plaintext"
                unless (weird = subsub.keys - %w{}).empty?
                  next results.push "unknown attributes #{weird} of <#{subsub.node_name}>: ```#{node}```"
                end
                unless subsub.text.empty?
                  if node["id"] != "Input" && node["scanner"] == "Data"
                    poddata_title = node["title"]
                    rows = subsub.text.split("\n")
                    if rows.last[/^\(.*\)$/]
                      pop = rows.pop
                    end
                    if rows.size == 1
                      data.push [poddata_title, *rows]
                    else
                      poddata_title.concat " #{pop}" if pop
                      poddata.concat rows
                    end
                  else
                    output_stack.push node["primary"] ? "*#{subsub.text}*" : subsub.text
                  end
                end
              else ; results.push "unknown subsub node_name <#{subsub.node_name}>: ```#{subsub}```"
              end
            end
            case output_stack.size
            when 0
            when 1 ; results.push "#{node["title"]}: #{node["id"] == "Input" ? "*#{output_stack.first}*" : output_stack.first}"
            else ; push_table[node["title"], output_stack]
            end
          when "states"
            unless (weird = subpod.keys - %w{ count }).empty?
              next results.push "unknown attributes #{weird} of <#{subpod.node_name}>: ```#{node}```"
            end
          when "infos"
            unless (weird = subpod.keys - %w{ count }).empty?
              next results.push "unknown attributes #{weird} of <#{subpod.node_name}>: ```#{node}```"
            end
            # TODO?
          else results.push "unknown node_name of subpod: ```#{subpod}```"
          end
        end
        case poddata.size
        when 0
        when 1 ; puts node; p poddata; fail "WUT?"
        else ; push_table[poddata_title, poddata]
        end
      when "assumptions" ; node.element_children.each do |assumption|
        unless (weird = assumption.keys - %w{ type word template count }).empty?
          next results.push "unknown attributes #{weird} of assumption: ```#{assumption}```"
        end
        assumptions_stack = []
        assumption.element_children.each do |variant|
          next results.push "unknown tag <#{variant.node_name}> among assumption variants" unless "value" == variant.node_name
          unless (weird = variant.keys - %w{ name desc input word }).empty?
            next results.push "unknown attributes #{weird} of assumption variant: ```#{variant}```"
          end
          assumptions_stack.push variant["name"]
        end
        results.push "possible assumptions are: #{assumptions_stack.join ", "}" unless assumptions_stack.empty?
      end
      when "sources" ; # TODO?
      when "warnings"
        unless (weird = node.keys - %w{ count }).empty?
          next results.push "unknown attributes #{weird} of <#{node.node_name}>: ```#{node}```"
        end
        warnings = []
        node.element_children.each do |warning|
          next warnings.push "unknown warning node_name <#{warning.node_name}>" unless %w{ spellcheck }.include? warning.node_name
          unless (weird = warning.keys - %w{ word suggestion text }).empty?
            next results.push "unknown attributes #{weird} of warning>: ```#{warning}```"
          end
          warnings.push CGI.unescapeHTML warning["text"]
        end
        case warnings.size
        when 0
        when 1 ; results.push "*warning*: #{warnings.first}"
        else ; results.push "*warnings*:", *warnings.map{ |warning| "\t#{warning}" }
        end
      else ; results.push "unknown high level node_name <#{node.node_name}>: ```#{node}```"
      end
    end
    push_table["other", data.map{ |row| row.join " | " }] unless data.empty?
  end
end

__END__

            # TODO?
            # states_stack = []
            # subpod.element_children.each do |state|
            #   next states_stack.push "unknown state node_name <#{state.node_name}>" unless "state" == state.node_name
            #   unless (weird = state.keys - %w{ name input }).empty?
            #     next results.push "unknown attributes #{weird} of <state>: ```#{state}```"
            #   end
            #   states_stack.push "for #{state["name"]} add podstate=#{state["input"]}"
            # end
            # case states_stack.size
            # when 0
            # when 1 ; results.push "one more state possible: #{states_stack.first}"
            # else ; results.push "more states:", *states_stack.map{ |state| "\t#{state}" }
            # end
