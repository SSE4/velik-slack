require "twitter_cldr"

def wordize line
  # if line[/[^а-еж-я .,?!()\[\]]/]
  #   line.localize.casefold.to_s
  # else
  #   line
  # end.
  line.localize.casefold.to_s.
    tr("ё.?!,()[]", "е        ").
    # gsub(/(.+)\1\1\1+/, '\1').
    split.reject{ |word| word.size > 30 }
end
