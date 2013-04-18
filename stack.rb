
require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'cloudstack_ruby_client'
require 'set'
require 'tsort'

class Instance < Ruote::Participant
  URL = 'http://192.168.56.10:8080/client/api/'
  APIKEY = 'yy0sfCPpyKnvREhgpeIWzXORIIvyteq_iCgFpKXnqpdbnHuoYiK78nprSggG4hcx-hxwW897nU-XvGB0Tq8YFw'
  SECKEY = 'Pse4fqYNnr1xvoRXlAe8NQKCSXeK_VGdwUxUzyLEPVQ7B3cI1Q7B8jmZ42FQpz2jIICFax1foIzg2716lJFZVw'
  def initialize()
      @client = CloudstackRubyClient::Client.new(URL, APIKEY, SECKEY, false)
  end
  def on_workitem
    sleep(rand)
    p workitem.fields['Resources'][workitem.participant_name]['Properties']
    #@client.listNetworkOfferings()
    reply
  end
end

class WaitConditionHandle < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class WaitCondition < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class SecurityGroup < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class Finisher < Ruote::Participant
  def on_workitem
    p workitem.fields.keys
    p 'done'
    reply
  end
end


class Stacker
    include TSort
    @@class_map = { "AWS::EC2::Instance" => "Instance",
              "AWS::CloudFormation::WaitConditionHandle" => "WaitConditionHandle",
              "AWS::CloudFormation::WaitCondition" => "WaitCondition",
              "AWS::EC2::SecurityGroup" => "SecurityGroup" }

    def initialize(templatefile, stackid)
        @stackid = stackid
        @engine = Ruote::Dashboard.new(
          Ruote::Worker.new(
            Ruote::FsStorage.new('stacker_work_' + @stackid.to_s())))

        @engine.noisy = ENV['NOISY'] == 'true'
        #@engine.noisy = true
        @stack = {}
        @resources = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        #resolve_param_refs
        #order_resources
        @params = @templ['Parameters']
        @deps = {}
        @templ['Resources'].each { |key,val| deps = Set.new; find_refs(key, val, deps); @deps[key] = deps.to_a}
        p self.strongly_connected_components
        pdef()
    end

    def find_refs (parent, j, deps)
        case j
            when Array
                j.each {|x| find_refs(parent, x, deps)}
            when Hash
                j.keys.each do |k|
                    if k == "Ref"
                        if !@params.keys.index(j[k]) && j[k] != "AWS::Region" && j[k] != "AWS::StackId"
                            print parent, ": ", j[k], "\n"
                            deps << j[k]
                        end
                    else
                        find_refs(parent, j[k], deps)
                    end
                end
        end
        return deps
    end

    def tsort_each_node(&block)
        @deps.each_key(&block)
    end

    def tsort_each_child(name, &block)
        @deps[name].each(&block) if @deps.has_key?(name)
    end

    def pdef()
        participants = []
        @templ['Resources'].keys.each do |k|
            t = @templ['Resources'][k]['Type']
            #for each type of resource, build a list of instances of that resource
            (@resources[t] ||= [])  << k
            @engine.register_participant k, @@class_map[t]
            #one participant per resource instance. FIXME: needs to be ordered
            participants << k
        end
        @engine.register_participant 'finisher', 'Finisher'
        participants << 'finisher'
        p participants
        @pdef = Ruote.define 'mydef'+ @stackid.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
    end
    
    def launch()
        wfid = @engine.launch( @pdef, @templ)
        @engine.wait_for(wfid)
    end
end


p = Stacker.new('LAMP_Single_Instance.template', 3)
p.launch()
