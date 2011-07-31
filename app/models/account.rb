class Account < ActiveRecord::Base
  
  CONSUMER_KEY = APP_CONFIG[:twitter][:consumer_key]
  CONSUMER_SECRET = APP_CONFIG[:twitter][:consumer_secret]
  OPTIONS = {:site => "http://api.twitter.com", :request_endpoint => "https://api.twitter.com/oauth/request_token"}
  
  FACEBOOK_CLIENT_ID = APP_CONFIG[:facebook][:consumer_key]
  FACEBOOK_CLIENT_SECRET = APP_CONFIG[:facebook][:consumer_key]
  
  def twitter_authorize_url(callback_url = '')
    if self.oauth_authorize_url.blank?
      # Step one, generate a request URL with a request token and secret
      signing_consumer = OAuth::Consumer.new(Account::CONSUMER_KEY, Account::CONSUMER_SECRET, Account::OPTIONS)
      request_token = signing_consumer.get_request_token(:oauth_callback => callback_url)
      self.oauth_token = request_token.token
      self.oauth_token_secret = request_token.secret
      self.oauth_authorize_url = request_token.authorize_url
      self.save!
    end
    self.oauth_authorize_url
  end
  
  def twitter_validate_oauth_token(oauth_verifier, callback_url = '')
    begin
      signing_consumer = OAuth::Consumer.new(Account::CONSUMER_KEY, Account::CONSUMER_SECRET, Account::OPTIONS)
      access_token = OAuth::RequestToken.new(signing_consumer, self.oauth_token, self.oauth_token_secret).
                                         get_access_token(:oauth_verifier => oauth_verifier)
      self.oauth_token = access_token.params[:oauth_token]
      self.oauth_token_secret = access_token.params[:oauth_token_secret]
      self.stream_url = "http://twitter.com/#{access_token.params[:screen_name]}"
      self.active = true
    rescue OAuth::Unauthorized
      self.errors.add(:oauth_token, "Invalid OAuth token, unable to connect to twitter")
      self.active = false
    end
    self.save!
  end
  
  def twitter_post(message)
    Twitter.configure do |config|
      config.consumer_key = Account::CONSUMER_KEY
      config.consumer_secret = Account::CONSUMER_SECRET
      config.oauth_token = self.oauth_token
      config.oauth_token_secret = self.oauth_token_secret
    end
    client = Twitter::Client.new
    begin
      client.update(message)
      return true
    rescue Exception => e
      self.errors.add(:oauth_token, "Unable to send to twitter: #{e.to_s}")
      return false
    end
  end
  
  def fb_authorize_url(callback_url = '')
    if self.oauth_authorize_url.blank?
      self.oauth_authorize_url = "https://graph.facebook.com/oauth/authorize?client_id=#{FACEBOOK_CLIENT_ID}&redirect_uri=#{callback_url}&scope=offline_access,publish_stream"
      self.save!
    end
    self.oauth_authorize_url
  end
  
  def fb_validate_oauth_token(oauth_verifier, callback_url = '')
    response = RestClient.get 'https://graph.facebook.com/oauth/access_token', :params => {
                   :client_id => FACEBOOK_CLIENT_ID,
                   :redirect_uri => callback_url.html_safe,
                   :client_secret => FACEBOOK_CLIENT_SECRET,
                   :code => oauth_verifier.html_safe
                }
    # callback_url = "http://tweetaninsult.com/callback/facebook"
    # oauth_verifier="AQDvBBy5RkE-IAjv4ykx_7gFYAd9cqV6S4J2lFmKKRtZ1JGu4VgPtWOvxU4JgabMN6QqPqcz5gxZCv2Y4sPAbAI-wW1_2uuIyXMU5BUOceDe29oLFbS0wpJuE8fGNMPnQkG94VaFoXKMu08uZ7rRNtiKN8na-5H0FmCmKtUfMU0r57EKU0ytL8XK8sEJ3JSCrpQ"
    # response = RestClient.get 'https://graph.facebook.com/oauth/access_token', :params => {
    #                :client_id => '190960770964408',
    #                :redirect_uri => callback_url.html_safe,
    #                :client_secret => '667b79e3e9ea2f376cd8731dad8d4ff4',
    #                :code => oauth_verifier.html_safe
    #             }        

# https://graph.facebook.com/oauth/access_token?client_id=190960770964408&redirect_uri=http://tweetaninsult.com/callback/facebook/&code=AQDj-DftXFKyfJo3Q9XvCru6X9TBXU5_64Zl1sIdEwRLxdE9lHQvOFumynDeBtKQdQpmp-2cYsVgdxho-pshoBWmSsN68PUnphQEPhOBm4d6TKMIQrg2MydE4Fmg4Ka3UfpvaTdpUQuwYZiGYEKt8ZBHSyzDkFjIy1iYLiT-GtufWrjXwAWRSmrzAt9M7suUtCc&client_secret=667b79e3e9ea2f376cd8731dad8d4ff4

    pair = response.body.split("&")[0].split("=")
    if (pair[0] == "access_token")
      self.access_token = pair[1]
      response = RestClient.get 'https://graph.facebook.com/me', :params => { :access_token => self.access_token }
      self.stream_url = JSON.parse(response.body)["link"]
      self.active = true
    else 
      self.errors.add(:oauth_verifier, "Invalid token, unable to connect to facebook: #{pair[1]}")
      self.active = false
    end
    self.save!
  end
  
  def fb_post(message)
    RestClient.post 'https://graph.facebook.com/me/feed', { :access_token => self.access_token, :message => message }
  end
  
end
