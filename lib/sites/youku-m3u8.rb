module VideoFetcher
  class YoukuM3U8
    # M3U8 解析算法
    # GET http://v.youku.com/player/getM3U8/vid/:id/type/:type/vodeo.m3u8
    # 对收费视频无效

    API_URL = 'http://v.youku.com/player/getPlaylist/VideoIDS/'

    attr_reader :url

    # 一个优酷视频的标准地址，应该形如：
    # http://v.youku.com/v_show/id_XNzM2NTc5MjUy.html
    def initialize(url)
      @url = url
    end

    def video_id
      @video_id ||= begin
        p = /^http:\/\/v.youku.com\/v_show\/id_([0-9a-zA-Z]+)(_.*)?\.html/
        match = p.match @url
        raise '无效的优酷视频地址' if match.nil?
        match[1]
      end
    end

    def video_api_url
      "#{API_URL}#{video_id}/Pf/4/ctype/12/ev/1"
      # 加上 /Pf/4/ctype/12/ev/1 这些参数后会多出 ep 等一些返回值
    end

    def video_api_json
      @api_json ||= begin
        open(video_api_url).read
      end
    end

    def video_data
      @youku_data ||= begin
        hash = JSON::parse video_api_json
        Data.new hash['data'][0]
      end
    end

    def video_title
      video_data.title
    end

    def video_image
      video_data.logo
    end

    def video_formats
      video_data.formats
    end

    def files_data
      video_data.files_data
    end

    class Data
      attr_reader :title, :logo

      def initialize(hash_data)
        @data = hash_data

        @title = @data['title']
        @logo  = @data['logo']

        @segs = @data['segs']
      end

      def formats
        @segs.keys
      end

      def files_data
        re = {}
        re[:count] = {}
        re[:m3u8_url] = {}

        formats.each do |format|
          m3u8_url = "http://v.youku.com/player/getM3U8/vid/#{@data['vidEncoded']}/type/#{format}/vodeo.m3u8"

          arr = _get_files(format, m3u8_url)

          re[format] = arr
          re[:count][format] = arr.length
          re[:m3u8_url][format] = m3u8_url
        end
        re
      end

      def _get_files(format, m3u8_url)
        files = _get_m3u8_files(m3u8_url)

        @segs[format].map do |f|
          num = f['no']
          size = f['size']
          seconds = f['seconds']
          file = files[num.to_i]

          {
            :num => num,
            :size => size,
            :seconds => seconds,
            :file => file
          }
        end
      end

      def _get_m3u8_files(m3u8_url)
        str = open(m3u8_url).read

        files = str.lines.select { |line|
          line[0] != '#'
        }.map { |f|
          f.split('.ts?')[0]
        }.uniq
      end

    end
  end
end