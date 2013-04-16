
require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'

class Stacker
    def initialize(templatefile)
        @stack = {}
        @resources = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        #resolve_param_refs
        #order_resources
    end

    def pdef()
        @templ['Resources'].keys.each do |k|
            t = @templ['Resources'][k]['Type']
            if ! @resources.has_key?(t)
                @resources[t] = []
            end
            @resources[t] << k
        end
        p @resources
    end
end


p = Stacker.new('LAMP_Single_Instance.template')
p.pdef()
