class TweetsController < ApplicationController
  
  def update
    t = params[:tweet][:t]
    to = params[:tweet][:to]
    insult = params[:tweet][:insult]
    
    if t.empty? || to.empty? || insult.empty?
      redirect_to(slight_generator_url, :notice => 'Need to fill out all the fields, ya douche!')
    else
      tweet = Tweet.create()
      tweet.t = t
      tweet.insult = insult
      tweet.to = to
      tweet.save()
      
      twitter_account = TwitterAccount.find_by_oauth_token(t)
      twitter_account.post("#{tweet.to} is a #{tweet.insult} #tweetaninsult")
      
      redirect_to(slight_success_url, :notice => "Sweet! You successfully (and publicly) bashed that no good #{tweet.to} proper!")
    end
  end
  
end
