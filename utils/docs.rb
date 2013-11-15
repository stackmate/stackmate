require 'json'
begin
  #apis = JSON.parse(File.read('apis_user.json'))
  apis = JSON.parse(File.read(ARGV[0]))
  apis = apis['api']
  lookup = {}
  lookup['create'] = 'delete'
  lookup['attach'] = 'detach'
  lookup['add'] = 'remove'
  lookup['authorize'] = 'revoke'
  lookup['enable'] = 'disable'
  lookup['deploy']='destroy'
  lookup['start']='stop'
  lookup['assign']='remove'
  lookup['associate']='disassociate'
  docs = {}
  docs['Resources'] = []
  apis.each do |a|
    lookup.keys.each do |k|
      #will start with only one of them.
      #chuck the inefficiency
      if a['name'].start_with?(k) and !a['name'].include?("Account")
        required={}
        optional = {}
        a['params'].each do |param|
          if param['required'] == true
            required[param['name']] = {"Required" => "Yes","Type"=>param['type'],"Description" => param['description']}
          else
            #optional.push(param['name'])
            optional[param['name']] = {"Required" => "No","Type"=>param['type'],"Description" => param['description']}
          end
        end
        delete_tag = 'id'
        #support only single delte id right now. only couple of APIs have multiple required for delete - like id
        resource = a['name'].sub(k,"")
        delete_api_name = lookup[k]+resource
        delete_api_name.sub!("To","From")
        delete_api_name.sub!("SnapshotPolicy","SnapshotPolicies")
        delete_api = ""
        apis.each do |del|
          if del['name'].eql?(delete_api_name)
            delete_api = del
          end
        end
        delete_api['params'].each do |del_param|
          if del_param['required'] == true
            delete_tag = del_param['name']
          end
        end
        #StackMate::CloudStackFactory.print_class(resource,k,required,optional,a['isasync'],lookup[k],delete_tag,delete_api['isasync'])
        resource = "VirtualMachineOps" if (resource.eql?("VirtualMachine") && k.eql?("start"))
        resource = "VolumeOps" if (resource.eql?("Volume") && k.eql?("attach"))
        docs['Resources'].push( {"Name" => resource,
          "CloudStack API Name" => a['name'],
          "Description" => a['description'],
          "StackMate Type"=>"CloudStack::"+resource,
          "Parameters" => required.merge(optional)
        })
        #puts a['related']
      end
    end
  end
  #p docs.to_json
  File.open("docs/docs.json","w") { |file| file.write(JSON.pretty_generate(docs))}
rescue => e
  p "Unable to generate docs " + e.message
end
