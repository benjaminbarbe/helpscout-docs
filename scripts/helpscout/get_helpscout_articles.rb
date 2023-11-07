require 'httparty'
require 'json'
require 'ruby-progressbar'

class HelpScoutAPI
  # Base URL for Help Scout Docs API
  BASE_URL = "https://docsapi.helpscout.net/v1"

  def initialize(api_key)
    # Store the API key
    @auth = { username: api_key, password: 'X' } # Help Scout API key as the username, 'X' as a placeholder password
  end

  def get_articles(collection_id)
    # Initialize an empty array to hold articles
    articles = []
    page = 1

    # Start a progress bar
    progressbar = ProgressBar.create(format: '%a |%b>>%i| %p%% %t', total: nil, title: 'Fetching Articles', autostart: false, output: STDERR)

    begin
      loop do
        # Make the GET request to the Help Scout API
        response = HTTParty.get(
          "#{BASE_URL}/collections/#{collection_id}/articles",
          basic_auth: @auth,
          query: { page: page },
          verify: false # Disable SSL verification
        )

        # Raise an exception if the response was not successful
        unless response.success?
          raise "Failed to retrieve articles: #{response.code} #{response.message}"
        end

        parsed_response = JSON.parse(response.body)

        # Stop if there are no more articles
        break if parsed_response['articles']['items'].empty?

        # Add the retrieved article IDs to the articles array
        articles.concat(parsed_response['articles']['items'].map { |article| article['id'] })

        # Increment the page number for pagination
        page += 1

        # Update the progress bar
        progressbar.total = parsed_response['count']
        progressbar.increment
      end
    rescue StandardError => e
      # If an error occurs, print it out and abort the script
      abort("Error while fetching articles: #{e.message}")
    ensure
      progressbar.finish
    end

    articles
  end

  def get_article_details(article_id)
    # Fetch detailed information of a single article by its ID
    response = HTTParty.get(
      "#{BASE_URL}/articles/#{article_id}",
      basic_auth: @auth,
      verify: false # Disable SSL verification
    )

    if response.success?
      JSON.parse(response.body)['article']
    else
      raise "Failed to retrieve article details: #{response.code} #{response.message}"
    end
  rescue StandardError => e
    warn("Error while fetching article details: #{e.message}")
    nil
  end
end

# Check if the collection ID is provided as an argument
if ARGV.length != 1
  puts "Usage: #{$0} collection_id"
  exit(1)
end

# Read the collection ID from the first command-line argument
collection_id = ARGV[0]

# Read the API key from the HELPSCOUT_API_KEY environment variable
api_key = ENV['HELPSCOUT_API_KEY']

unless api_key
  puts "Please set the HELPSCOUT_API_KEY environment variable."
  exit(1)
end

# Create an instance of the HelpScoutAPI class
helpscout = HelpScoutAPI.new(api_key)

# Retrieve all article IDs from the specified collection
article_ids = helpscout.get_articles(collection_id)

# limit to 20 articles for testing
article_ids = article_ids[0..19]

# Initialize a new progress bar for fetching article details
details_progressbar = ProgressBar.create(format: '%a |%b>>%i| %p%% %t', total: article_ids.size, title: 'Fetching Article Details', output: STDERR)

# Retrieve the details for each article and update the progress bar
articles_details = article_ids.map do |article_id|
  details = helpscout.get_article_details(article_id)
  details_progressbar.increment
  details
end.compact # Remove any nil entries

# Finish the progress bar
details_progressbar.finish

# Output the article details to STDOUT in JSON format
puts JSON.pretty_generate(articles_details)
