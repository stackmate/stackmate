require 'json'
require_relative 'cloudstackfactory.rb'
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
  apis.each do |a|
    lookup.keys.each do |k|
      #will start with only one of them.
      #chuck the inefficiency
      if a['name'].start_with?(k) and !a['name'].include?("Account")
        required={}
        optional = {}
        a['params'].each do |param|
          if param['required'] == true
            required[param['name']] = param['type']
          else
            #optional.push(param['name'])
            optional[param['name']] = param['type']
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
        StackMate::CloudStackFactory.print_class(resource,k,required,optional,a['isasync'],lookup[k],delete_tag,delete_api['isasync'])
        #puts a['related']
      end
    end
  end
rescue => e
  p "Unable to generate participants code " + e.message
end
