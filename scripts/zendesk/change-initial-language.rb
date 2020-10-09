require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'faraday'
  gem 'json'
  gem 'uri'
end

conn = Faraday.new("https://#{ENV['SUBDOMAIN']}.zendesk.com/")
conn.basic_auth(ENV['EMAIL'], ENV['PASSWORD'])
puts "#{ENV['EMAIL']}, #{ENV['PASSWORD']}"

page = 1
articles = []
while true
  puts "/api/v2/help_center/#{ENV['BASE_LOCALE']}/articles.json?page=#{page}"
  response = conn.get("/api/v2/help_center/#{ENV['BASE_LOCALE']}/articles.json?page=#{page}")
  body = JSON.parse(response.body)
  current_articles = body.dig('articles')
  if current_articles.nil? || current_articles.empty?
    break
  else
    page += 1
    articles += current_articles
  end
end

articles.each do |article|
  if article['source_locale'] != ENV['BASE_LOCALE']
    puts article['html_url']
    resp = conn.put(
      "/api/v2/help_center/articles/#{article['id']}/source_locale.json",
      JSON.generate(
        {
          article_locale: ENV['BASE_LOCALE'].split('-').first
        }
      ),
      "Content-Type" => "application/json"
    )
    puts resp.status
    exit
  end
end