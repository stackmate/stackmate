require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'sinatra/base'

class WaitConditionServer < Sinatra::Base
    include Ruote::ReceiverMixin
  set :static, false
  set :run, true

  #def initialize(engine)
  def initialize()
      super
  end

  get '/' do
     'Hello world!'
  end

  put '/hello/:wfeid/:waithandle' do
    print "Got PUT of " , params[:wfeid],  ", name = ", params[:waithandle], "\n"
  end


  run! if app_file == $0

end

