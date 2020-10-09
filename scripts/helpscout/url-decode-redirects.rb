require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'faraday'
  gem 'json'
  gem 'uri'
end

conn = Faraday.new('https://docsapi.helpscout.net')
conn.basic_auth(ENV['API_KEY'], 'X')

page = 1
items = []
while true
  puts "/v1/redirects/site/#{ENV['SITE_ID']}?page=#{page}"
  response = conn.get("/v1/redirects/site/#{ENV['SITE_ID']}?page=#{page}")
  body = JSON.parse(response.body)
  current_items = body.dig('redirects', 'items')
  if current_items.nil? || current_items.empty?
    break
  else
    page += 1
    items += current_items
  end
end

items.each do |item|
  url_mapping = URI.decode(item['urlMapping'])
  if item['urlMapping'] != url_mapping
    puts url_mapping
    resp = conn.put(
      "/v1/redirects/#{item['id']}",
      JSON.generate(
        {
          siteId: ENV['SITE_ID'],
          urlMapping: url_mapping,
          redirect: item['redirect']
        }
      ),
      "Content-Type" => "application/json"
    )
  end
end