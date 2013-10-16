require 'ruote'
require 'ruote/storage/hash_storage'
require 'optparse'
require 'stackmate'
require 'stackmate/classmap'
require 'stackmate/waitcondition_server'
#require 'stackmate/logging'
#API for creating stack
#TODO clean up repeated code

module StackMate
    module StackPi
        #class Create
            #include Logging
            def self.create_stack(file,stack_name,params,wait_conditions)
                # Thread.new do
                #     StackMate::WaitConditionServer.run!
                # end
                engine = Ruote::Dashboard.new(
                  Ruote::Worker.new(
                    Ruote::HashStorage.new))
                engine.noisy = ENV['NOISY'] == 'true'
                engine.configure('wait_logger_timeout', 600)
                # engine.on_error = Ruote.process_definition do
                #    p("Error : StackPi create stack for #{stack_name} failed!")
                # end
                unknown = nil
                unresolved = catch(:unresolved) do
                    unknown = catch(:unknown) do
                        api_opts = {:APIKEY => "#{ENV['APIKEY']}", :SECKEY => "#{ENV['SECKEY']}", :URL => "#{ENV['URL']}" }
                        p = StackMate::StackExecutor.new(file,stack_name,params,engine,wait_conditions,api_opts)
                        p.launch()
                        nil
                    end
                    nil
                end
                puts 'Failed to resolve parameters ' + unresolved.to_s if unresolved
                print "Sorry, I don't know how to create resources of type: ", unknown, "\n" if unknown
            end

            def self.delete_stack(file,stack_name,params,wait_conditions)
                
            end
        #end
    end
end