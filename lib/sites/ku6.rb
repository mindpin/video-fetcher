module VideoFetcher
  class Ku6
    attr_reader :url

    def initialize(url)
      api_fn = ->(id) {"http://v.ku6.com/fetchVideo4Player/#{id}.html"}
      regexp  = /http:\/\/v\.ku6\.com\/show\/(\w+)\.\.\.html/

      @url = Origin.new(:raw => url, :api_fn => api_fn, :regexp => regexp)
    end

    def raw
      @raw ||= Request.new(url.api).response.data
    end

    def data
      raw["data"]
    end

    def video_title
      data["t"]
    end

    def video_formats
      %W(f4v)
    end

    def video_image
      data["bigpicpath"]
    end

    def files
      @files ||= data["f"].split(",")
    end

    def count
      {:f4v => files.size}
    end

    def lengths
      @lengths ||= data["vtime"].split(",")[1..-1]
    end

    def files_data
      @files_data ||= {
        :count => count,
        :f4v   => files.zip(lengths).each_with_index.map(&file_data_fn)
      }
    end

    private

    def file_data_fn
      proc do |(file, length), index|
        {
          :num     => index,
          :size    => "-1",
          :seconds => length,
          :file    => file
        }
      end
    end
  end
end
