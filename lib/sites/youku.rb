module VideoFetcher
  class Youku
    # 算法来源
    # https://gist.github.com/ben7th/638203558b95a4d39d3b
    # http://s.4ye.me/C8lXjO
    # 简直无情

    # 2014.7.8 
    # 算法来源的原始出处应为 http://player.youku.com/jsapi
    # 但是发现获取多段视频地址时，由于 k = -1
    # 导致无法算出正确的 K
    # 因此多段视频后面若干段的地址计算不对
    # 先搁置此解析方法，尝试 m3u8 的方法

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

    def common_params
      video_data.common_params
    end

    def files_data
      video_data.files_data
    end

    class Data
      attr_reader :title, :logo

      def initialize(hash_data)
        @util = Util.new
        @data = hash_data

        @title = @data['title']
        @logo  = @data['logo']

        # 计算用的变量
        @ep = @data['ep']
        @oip = @data['ip']
        @sid, @token = _get_sid_token

        @segs = @data['segs']
        @seed = @data['seed']

        @key1 = @data['key1']
        @key2 = @data['key2']
      end

      def _get_sid_token
        # _f = @util._recover_replace("b4eto0b4", [
        #   19, 1,  4,  7,  30, 14, 28, 8,
        #   24, 17, 6,  35, 34, 16, 9,  10, 
        #   13, 22, 32, 29, 31, 21, 18, 3, 
        #   2,  23, 25, 27, 11, 20, 5,  15, 
        #   12, 0, 33, 26
        # ]) # 长度为 36 的数组
        _f = 'becaf9be'
        c = @util._e(_f, Base64.decode64(@ep))
        c.split("_")
      end

      def common_params
        {
          :sid => @sid,
          :token => @token,
          :seed => @seed,
          :ep => @ep,
          :key2 => @key2,
          :key1 => @key1
        }
      end

      def files_data
        re = {}
        re[:count] = {}
        @segs.keys.each do |key|
          arr = _get_files(key)
          re[key] = arr
          re[:count][key] = arr.length
        end
        re
      end

      def _get_files(key)
        streamfileid = @data['streamfileids'][key]
        set = @segs[key]

        fid0 = @util.get_file_id streamfileid, @seed
        fid1 = fid0[0...8]
        fid2 = fid0[10..-1]
        
        set.map { |f|
          # K值
          # 值为 -1 的时候 特殊处理
          k = f['k']
          k2 = f['k2'] # 好像没啥用。。
          if '' == k || -1 == k
            k = @key1 + @key2
          end

          ts = f['seconds']
          size = f['size']

          num = f['no']
          num16 = num.to_i.to_s(16)
          no = "0#{num16}"[-2..-1]

          # 文件ID
          fileid = fid1 + no.upcase + fid2

          fep = _get_fep(fileid)

          # 清晰度
          detail = {
            'flv' => 0,
            'flvhd' => 0,
            'mp4' => 1,
            'hd2' => 2,
            '3gphd' => 1,
            '3gp' => 0
          }[key]

          # 文件类型
          kind = {
            'flv' => 'flv',
            'flvhd' => 'flv',
            'mp4' => 'mp4',
            'hd2' => 'flv',
            '3gphd' => 'mp4',
            '3gp' => 'flv'
          }[key]

          url = "http://k.youku.com/player/getFlvPath/sid/#{@sid}"
          url += "_#{no}/st/#{kind}/fileid/#{fileid}"
          url += "?K=#{k}"
          url += "&hd=#{detail}&myp=0"
          url += "&ts=#{ts}"
          url += "&ypp=0&ctype=12&ev=1"
          url += "&token=#{@token}"
          url += "&oip=#{@oip}"
          url += "&ep=#{fep}"

          # url += "&ypremium=1"

          {
            :k => k,
            :k2 => k2,
            :ts => ts,
            :size => size,
            :detail => detail,
            :kind => kind,
            :no => no,
            :fileid => fileid,
            :fep => fep,
            :url => url
          }
        }
      end

      def _get_fep(fileid)
        # _f1 = @util._recover_replace("boa4poz1", [
        #   19, 1,  4,  7,  30, 14, 28, 8,
        #   24, 17, 6,  35, 34, 16, 9,  10, 
        #   13, 22, 32, 29, 31, 21, 18, 3, 
        #   2,  23, 25, 27, 11, 20, 5,  15, 
        #   12, 0, 33, 26
        # ])
        _f1 = 'bf7e5f01'
        _e1 = @util._e(_f1, "#{@sid}_#{fileid}_#{@token}")
        eep = @util._d(_e1)
        URI.escape(eep, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end
    end

    class Util
      
      # 还原使用逐位替换法加密的字符串
      # 示例：
      #   secret: b4eto0b4
      #   list：  abcdefghijklmnopqrstuvwxyz0123456789
      #   key:    tbeh4o2iyrg98qjknw635vsdcxz1lufpma70
      #   clear： becaf9be
      #   
      # 当传入的 key_arr 是：
      # [
      #   19, 1,  4,  7,  30, 14, 28, 8,
      #   24, 17, 6,  35, 34, 16, 9,  10, 
      #   13, 22, 32, 29, 31, 21, 18, 3, 
      #   2,  23, 25, 27, 11, 20, 5,  15, 
      #   12, 0, 33, 26
      # ] # 36位 （a-z0-9）
      # 对应的 key 是 tbeh4o2iyrg98qjknw635vsdcxz1lufpma70
      def _recover_replace(secret, key_arr)
        list = 'abcdefghijklmnopqrstuvwxyz0123456789'
        key = key_arr.map {|num| list[num]}

        secret.split('').map { |char|
          idx = key.index char
          list[idx]
        }.join
      end

      def _e(a, c)
        b = (0...256).to_a # [0, 1, ..., 255]

        f = 0
        0.upto 255 do |num|
          f = (f + b[num] + a[num % a.length].ord) % 256
          b[num], b[f] = b[f], b[num]
        end

        h = 0
        f = 0
        e = ""
        c.each_char do |char|
          h = (h + 1) % 256
          f = (f + b[h]) % 256
          b[h], b[f] = b[f], b[h]
          e += (char.ord ^ b[(b[h] + b[f]) % 256]).chr
        end

        return e
      end

      def _d(a)
        return "" if !a

        str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

        b = 0
        f = a.length
        c = ""

        while b < f do
          e = a[b].ord & 255
          b += 1

          if b == f
            c += str[e >> 2]
            c += str[(e & 3) << 4]
            c += "=="
            break
          end

          g = a[b].ord
          b += 1
          if b == f
            c += str[e >> 2]
            c += str[(e & 3) << 4 | (g & 240) >> 4]
            c += str[(g & 15) << 2]
            c += "="
            break
          end

          h = a[b].ord
          b += 1
          c += str[e >> 2]
          c += str[(e & 3) << 4 | (g & 240) >> 4]
          c += str[(g & 15) << 2 | (h & 240) >> 6]
          c += str[h & 63]
        end

        c
      end

      def get_file_id(streamfileid, seed)
        mixed = get_mix_string(seed)
        ids = streamfileid.split('*')

        real_id = ''
        ids.each do |x|
          real_id = real_id + mixed[x.to_i]
        end

        return real_id
      end

      def get_mix_string(seed)
        mixed  = ''
        source = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/\:._-1234567890'

        source.length.times do 
          seed = (seed * 211 + 30031) % 65536
          index = (seed.to_f / 65536 * source.length)
          c = source[index]
          mixed = mixed + c
          source.sub! c, ''
        end

        return mixed
      end
    end
  end
end