require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'fileutils'
require 'httpclient'
require 'md5'

def debug content
  File.open("./#{PREFIX_LOG}spide.log","a+") { |file| file.write("#{content}\t" + DateTime.now(:db).to_s + "\n" ) }
end

def blog post
  path = "./#{PREFIX_BLOG}#{post[:title]}.html"
  if !File.exist?(path)
    File.new(path,"w+")
    File.open(path,"a+") do |file|
      file.write(W3C + "\n#{post[:title]}\r" + "#{post[:pub_time]}\n\n" + "#{post[:content]}\n")
    end
  end
end

def spide url , page = 10

  page.times do |p|
    p = p+1
    next  if page_spided? url , p
    page_urls = page_url url , p  
    page_urls.each do |u|
      next if url_spided? u
      File.open("./#{PREFIX_LOG}url.log","a+") { |f| f.write("spide_url|#{u}\n") }
      post =  spide_detail u
      blog post
    end

  end
  
end

# 页面里所有的文章连接(title)
def page_url url , p
  urls = Array.new
  url = url + "/page/#{p}"
  File.open("./#{PREFIX_LOG}page.log","a+") { |f| f.write("spide_page|#{p}|#{url}\n") }
  client = HTTPClient.new
  html = client.get_content(url,UA)
  doc = Hpricot(html)
  doc.search("h2[@class=entry-title]>a")  do |a|
    urls << a['href']
  end

  urls
end

# 解析 HTML
def spide_detail url
  post = Hash.new
  debug "spide #{url}"
  client = HTTPClient.new
  html = client.get_content(url,UA)
  doc = Hpricot(html)

  # 文章标题
  title = doc.search("h2[@class=entry-title]").inner_text
  post[:title] = title

  #发布时间
  pub_time = doc.search("abbr").inner_text
  post[:pub_time] = pub_time

  imgs = Array.new

  doc.search("div[@class=entry-content]").search("img").each do |i|
    imgs <<  i['src']
  end

  save_image imgs

  #内容
  content = doc.search("div[@class=entry-content]").inner_html 
  #   content.gsub!(/src="[a-zA-z]+:\/\/[^\s]*/)
  post[:content] = content 

  post
  
end


def save_image imgs

  FileUtils.mkdir './images' unless File.directory?('./images')
 
  imgs.each do |url|
    begin
      uri = URI.parse(url)
      format = uri.path.split(".").last
      img_name = "#{MD5.hexdigest(url)}.#{format}"

      if File.exist?("./images/#{img_name}")
        debug "exist #{url}"
        return 
      end

      client = HTTPClient.new
      body = client.get_content(url,UA)
      if body
        File.open("./images/#{img_name}","w") { |file| file.write(body) }
      end
     
    rescue => err
      debug err.inspect
      return nil
    end
  end

end

def page_spided? url , p
  path = "./#{PREFIX_LOG}page.log"
  File.new(path,"w+") unless File.exists?(path)
  File.open(path,"r").each_line do |line|
    if line.index("spide_page|#{p}|#{url}")
      return true
    end
  end
  return false
end

def url_spided? url
  path =  "./#{PREFIX_LOG}url.log"
  File.new(path,"w+") unless File.exists?(path)
  File.open(path,"r").each_line do |line|
    return true if line.index("spide_url|#{url}")
  end
  return false
end
