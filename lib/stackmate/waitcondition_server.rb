require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'sinatra/base'
require 'stackmate/participants/common'

module StackMate

  class WaitConditionServer < Sinatra::Base
    @@url_base = ENV['WAIT_COND_URL_BASE']?ENV['WAIT_COND_URL_BASE']:StackMate::WAIT_COND_URL_BASE_DEFAULT
    set :static, false
    set :run, true
    set :bind, Proc.new { URI.parse(@@url_base).host}
    set :port, Proc.new { URI.parse(@@url_base).port}

    def initialize()
      super
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

end
