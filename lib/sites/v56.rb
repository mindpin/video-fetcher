module VideoFetcher
  class V56
    attr_reader :url

    def initialize(url)
      api_fn = ->(id) {"http://vxml.56.com/json/#{id}/?src=out"}
      regexp = /http:\/\/www\.56\.com\/u27\/v_(\w+)\.html/

      @url = Origin.new(:raw => url, :api_fn => api_fn, :regexp => regexp)
    end

    def raw
      @raw ||= Request.new(url.api).response.data
    end

    def data
      raw["info"]
    end

    def video_title
      data["Subject"]
    end

    def video_image
      data["bimg"]
    end

    def formats
      %W(clear normal super)
    end

    def files
      data["rfiles"]
    end

    def count
      @count ||= formats.reduce({}) do |hash, format|
        hash[format.to_sym] = format_select(format).size
        hash
      end
    end

    def files_data
      @files_data ||= formats.reduce({}) do |hash, format|
        hash[format.to_sym] = format_select(format).each_with_index
                                                   .map(&file_data_fn)
        hash
      end.merge(:count => count)
    end

    private

    def format_select(format)
      files.select do |f|
        f["type"] == format
      end
    end

    def file_data_fn
      proc do |rfile, index|
        {
          :num     => index,
          :size    => rfile["filesize"],
          :seconds => rfile["totaltime"],
          :file    => rfile["url"]
        }
      end
    end
  end
end
