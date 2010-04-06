# Trazzler API with HTTParty Gem

require 'rubygems'
require 'httparty'
require 'hashie'
require 'json'

module Trazzler
  include HTTParty
  base_uri "http://birdfoot.trazzler.com/trips"
  
  class Unavailable < StandardError; end
  class ClientError < StandardError; end
  class InformTrazzler < StandardError; end
  class NotFound < StandardError; end
  
  def self.get_trip(options={})
    id = options.delete(:id) || options.delete(:permalink)
    raise ArgumentError unless id
    make_friendly(get("/#{id}.json", {:query => options}))
  end
  
  def self.trip_stack(options={})
    options = {:page => 1, :details => 'false', :browsing_mode_id => 3}.merge(options)
    make_friendly(get("/stack.json", {:query => options}))
  end
  
  private
  
  def self.make_friendly(response)
    raise_errors(response)
    data = parse(response)
    # Don't mash arrays of integers
    if data && data.is_a?(Array) && data.first.is_a?(Integer)
      data
    else
      mash(data)
    end
  end
 
  def self.raise_errors(response)
    case response.code.to_i
      when 404
        raise NotFound, "(#{response.code}): #{response.message}"
      when 405..499
        raise ClientError, "(#{response.code}): #{response.message}"
      when 500
        raise InformTwitter, "Trazzler had an internal error. Please let them know. (#{response.code}): #{response.message}"
      when 502..503
        raise Unavailable, "(#{response.code}): #{response.message}"
    end
  end
 
  def self.parse(response)
    return '' if response.body == ''
    JSON.parse(response.body)
  end
 
  def self.mash(obj)
    if obj.is_a?(Array)
      obj.map{|item| make_mash_with_consistent_hash(item)}
    elsif obj.is_a?(Hash)
      make_mash_with_consistent_hash(obj)
    else
      obj
    end
  end
 
  # Lame workaround for the fact that mash doesn't hash correctly
  def self.make_mash_with_consistent_hash(obj)
    m = Hashie::Mash.new(obj)
    def m.hash
      inspect.hash
    end
    return m
  end
end

module Hashie
  class Mash
 
    # Converts all of the keys to strings, optionally formatting key name
    def rubyify_keys!
      keys.each{|k|
        v = delete(k)
        new_key = k.to_s.underscore
        self[new_key] = v
        v.rubyify_keys! if v.is_a?(Hash)
        v.each{|p| p.rubyify_keys! if p.is_a?(Hash)} if v.is_a?(Array)
      }
      self
    end
 
  end
end