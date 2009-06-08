#!/usr/local/ruby187/bin/ruby
# -*- encoding: utf-8 -*-

require 'rubygems'
require 'sinatra'
require 'cgi'
require 'uri'
require 'erb'
require 'nokogiri'
require 'open-uri'
require 'nkf'

set :run, true  ## for application server, not CGI
set :environment, :production
set :server, "thin"

include Rack::Utils
alias h escape_html

BASE_IMG_URL = "http://www.junkudo.co.jp/"

def format_search_elem(elem)
  e_list = []
  buf = []
  elem.children.each{|elem2|
    if elem2.name == 'br'
      e_list << buf
      buf = []
    else
      buf << elem2
    end
  }
  e_list
end

def format_detail_elem(elem)
  ## グレーの文字を消す
  elem.css('font[@color="#777777"]').remove()
  html = elem.text
  list = html.split(/<br>/i)

  ## タグを全て消す
  list.each{ |line|
    if line
      line.gsub!( %r|<[^>]*>|i, '')
    end
  }
  list
end

get '/?' do
  @title = "iJunku(非公式版)"
  erb :index
end

get '/search/?' do
  redirect "/search/#{URI.escape(params[:word])}" if params[:word]
  redirect '/'
end

##get '/search/:word/:page' do
get '/search/:word' do
  @word = params[:word]
  redirect "/" if !@word or @word.empty?
  @page = params[:page] || "1"
  @rows = "50"
  word_sjis = NKF::nkf("-Ws",@word)
  url = "http://www.junkudo.co.jp/search2.jsp?VIEW=word&ARGS=#{URI.encode(word_sjis)}&RCNT=36&PAGE=#{URI.encode(@page)}&MODE=0&ROWS=#{URI.encode(@rows)}"
  str = open(url).read
  doc = Nokogiri::HTML(str,nil,'cp932')
  @books = Array.new
  doc.css('table td table td').each do |elem|
    title_elem = elem.css('a.lLink')
    if !title_elem.empty?
      bookinfo = Hash.new
      bookinfo[:title] = title_elem.text
      bookinfo[:id] = title_elem.attr('href').to_s.sub(/.*ID=/,'')
      list = format_search_elem(elem)
      begin
        author_pub = list[1].collect{|elem2|  elem2.text.gsub(/　/,' ')}
        other_info = list[2].collect{|elem2|  elem2.text}.to_s
        other_info += list[3].collect{|elem2|  elem2.text}.to_s
      rescue
      end
      bookinfo[:shelf] = "?"
      bookinfo[:shelf] = ((/書棚は、(.*)です/ =~ other_info) ? $1 : "?")

      ## 画像追加
      elem.css('img').each do |img_elem|
        if img_elem.get_attribute('src') =~ /jpg/
          bookinfo[:image] = BASE_IMG_URL+img_elem.get_attribute('src')
        end
      end

      ## 怖いので「在庫無し」のときのみ0
      bookinfo[:num] = "?"
      if /池袋本店(.*)冊/ =~ other_info
        bookinfo[:num] = $1
      elsif /在庫無し/ =~ other_info
        bookinfo[:num] = 0
      end

      bookinfo[:auther_pub] = author_pub.to_s
      bookinfo[:id] ||= "dummy"
      @books << bookinfo
    end
  end
  @title = "キーワード検索"
  @leftnav = '<a href="/"><img alt="home" src="/images/home.png" /></a>'
  erb :search
end

get '/book/:id' do
  @id = params[:id]
  redirect "/" if !@id or @id.empty?
  @url = "http://www.junkudo.co.jp/detail2.jsp?ID=#{URI.encode(@id)}"
  str = open(@url).read
  doc = Nokogiri::HTML(str,nil,'cp932')

  @title = ""
  @description = ""
  @leftnav = ""
  doc.css('table td table td table td').each do |elem|
    title_elem = elem.css('h1')
    if !title_elem.empty?
      @title = title_elem.text
      list = format_detail_elem(elem)

      @description = list.to_s.gsub(/\n/, "<br>\n")
      @leftnav = '<a href="/"><img alt="home" src="/images/home.png" /></a>'
    else
      text = elem.text()
      if /書棚は、(.*?)です。/ =~ text
        @shelf = $1
      else
        elem.css('table td').each do |elem2|
          zaiko = elem2.text
          if /池袋本店/ =~ zaiko
            @zaiko = zaiko.gsub(/<br>/i, "\n").gsub(/<[^>]*?>/, "")
          end
        end
      end

    end
  end

  erb :book
end
  
get '/isbn' do
  @isbn = params[:isbn]
  redirect "/" if !@isbn or @isbn.empty?
  @url = "http://www.junkudo.co.jp/search2.jsp?VIEW=isbn&ARGS=#{URI.encode(@isbn)}"
  str = open(@url).read
  doc = Nokogiri::HTML(str,nil,'cp932')

  doc.css('table td table td').each do |elem|
    title_elem = elem.css('a.lLink')
    if !title_elem.empty?
      book_id = title_elem.attr('href').to_s.sub(/.*ID=/,'')
      redirect "/book/#{book_id}"
    end
  end

  erb :index
end
