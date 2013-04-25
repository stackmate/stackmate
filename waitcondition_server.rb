require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'sinatra/base'
require_relative 'participants'

class WaitConditionServer < Sinatra::Base
  set :static, false
  set :run, true

  #def initialize(engine)
  def initialize()
      super
  end

  get '/' do
     'Hello world!'
  end

  put '/waitcondition/:wfeid/:waithandle' do
    #print "Got PUT of " , params[:wfeid],  ", name = ", params[:waithandle], "\n"
    WaitCondition.get_conditions.each  do |w|
      w.set_handle(params[:waithandle].to_s)
    end
    'success
    '
  end


  run! if app_file == $0

end
