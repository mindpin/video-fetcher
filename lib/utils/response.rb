require "json"

module VideoFetcher
  class Response
    attr_reader :raw

    def initialize(raw)
      @raw = raw
    end

    def data
      @data ||= JSON::parse(raw)
    end
  end
end
