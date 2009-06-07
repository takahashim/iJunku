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
  #  html = elem.to_html
  html = elem.text
  list = html.split(/<br>/i)
  ## グレーの文字を消す
  list.each{|line|
    line.gsub!(%r|<font color=['"]?#777777["']?>.*?</font>|ui,'')
  }

  ## タグを全て消す
  list.each{ |line|
    if line
      line.gsub!( %r|<[^>]*>|i, '')
    end
  }
  list
end

set :run, true   # HTTPサーバを立ち上げないならfalse
#set :run, false
set :environment, :production
set :server, "thin"

get '/' do
  @title = "iJunku(非公式版)"
  erb :index
end

get '' do
  @title = "iJunku(非公式版)"
  erb :index
end

get '/search' do
  redirect "/search/#{URI.escape(params[:word])}" if params[:word]
  recirect '/'
end

##get '/search/:word/:page' do
get '/search/:word' do
  @word = params[:word]
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
        author_pub = list[1].collect{|elem|  elem.text.gsub(/　/,' ')}
        other_info = list[2].collect{|elem|  elem.text}.to_s
        other_info += list[3].collect{|elem|  elem.text}.to_s
      rescue
      end
      bookinfo[:shelf] = "?"
      bookinfo[:shelf] = ((/書棚は、(.*)です/ =~ other_info) ? $1 : "?")

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
  @url = "http://www.junkudo.co.jp/detail2.jsp?ID=#{URI.encode(params[:id])}"
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

  erb :search
end
