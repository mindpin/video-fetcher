module VideoFetcher
  class Origin
    attr_reader :id

    def initialize(raw: nil, api_fn: nil, regexp: nil)
      @regexp = regexp
      @raw    = raw
      @api_fn = api_fn
    end

    def id
      @id ||= @regexp.match(@raw)[1]
    end

    def api
      @api ||= @api_fn.call(id)
    end
  end
end

