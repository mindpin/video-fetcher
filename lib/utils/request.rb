require "net/http"

module VideoFetcher
  class Request
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def response
      @response ||= Response.new(Net::HTTP.get(URI url))
    end
  end
end
