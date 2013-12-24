require 'json'
require 'sinatra/base'
require 'stackmate/participants/common'
require 'stackmate/metadata'

module StackMate

  class StackServer < Sinatra::Base
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

    get '/metadata/:stack_id/:logical_id' do
      content_type :json
      Metadata.get_metadata(params[:stack_id],params[:logical_id]).to_json
    end
    run! if app_file == $0
  end

  # class MetadataServer < Sinatra::Base
  #   set :static, false
  #   set :run, true

  #   def initialize()
  #     super
  #   end

  #   get '/api/stacks/:stack_id/resource/:logical_id' do
  #     print "Got GET of ", params[:stack_id], ", resource = ", params[:logical_id], "\n"
  #   end
  # end

  #run! if app_file == $0

end