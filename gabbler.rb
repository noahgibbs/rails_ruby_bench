# Copyright (c) 2011 Michael Dvorkin
#
# Gabbler is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
unless [].respond_to?(:sample)
  class Array
    def sample # Comes with Ruby 1.9+
      self[rand(size)]
    end
  end
end

class Gabbler
  def initialize(options = {})
    @depth = options[:depth] || 2
    unlearn!
  end

  # Split text into sentences and add them all to the dictionary.
  #----------------------------------------------------------------------------
  def learn(text)
    text.split(/([.!?])/).each_slice(2) do |sentence, terminator|
      add_to_dictionary(sentence, terminator || '.')
    end
  end

  # Reset internal data in case one needs to re-learn new training set.
  #----------------------------------------------------------------------------
  def unlearn!
    @dictionary, @start = {}, []
  end

  # Generate one pseudo-random sentence.
  #----------------------------------------------------------------------------
  def sentence
    words = @start.sample # Pick random word, then keep appending connected words.
    while next_word = next_word_for(words[-@depth, @depth])
      words << next_word
    end
    words[0..-2].join(" ") + words.last             # Format the sentence.
  end

  private

  # Add given sentence to the dictionary.
  #----------------------------------------------------------------------------
  def add_to_dictionary(sentence, terminator)
    words = sentence.scan(/[\w',-]+/)               # Split sentence to words.
    if words.size > @depth                          # Go on if the sentence is long enogh.
      words << terminator                           # Treat sentence terminator as another word.
      @start << words[0, @depth]                    # This becomes another starting point.
      words.size.times do |i|
        sequence = words[i, @depth + 1]
        if sequence.size == @depth + 1              # Full sequence?
          @dictionary[sequence[0, @depth]] ||= []
          @dictionary[sequence[0, @depth]] << sequence[-1]
        end
      end
    end
  end

  # Return random connected word or nil if there is none.
  #----------------------------------------------------------------------------
  def next_word_for(words)
    @dictionary[words].sample if @dictionary[words]
  end
end
