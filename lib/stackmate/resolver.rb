#require 'stackmate/logging'
require 'stackmate/intrinsic_functions'

module StackMate
	module Resolver
		@devicename_map=
		{
			'/dev/sdb' => '1',
			'/dev/sdc' => '2',
			'/dev/sdd' => '3',
			'/dev/sde' => '4',
			'/dev/sdf' => '5',
			'/dev/sdg' => '6',
			'/dev/sdh' => '7',
			'/dev/sdi' => '8',
			'/dev/sdj' => '9',
			'/dev/xvdb' => '1',
			'/dev/xvdc' => '2',
			'/dev/xvdd' => '3',
			'/dev/xvde' => '4',
			'/dev/xvdf' => '5',
			'/dev/xvdg' => '6',
			'/dev/xvdh' => '7',
			'/dev/xvdi' => '8',
			'/dev/xvdj' => '9',
			'xvdb' => '1',
			'xvdc' => '2',
			'xvdd' => '3',
			'xvde' => '4',
			'xvdf' => '5',
			'xvdg' => '6',
			'xvdh' => '7',
			'xvdi' => '8',
			'xvdj' => '9',
		}
		#comes from awsapi reference
		def get_resolved(lookup_data,workitem)
			case lookup_data
			when String
				 lookup_data
			when Hash
				 intrinsic(lookup_data,workitem)
			end
		end

		def get_named_tag(tag_name,properties,workitem,default)
			result = default
			unless properties['Tags'].nil?
      			properties['Tags'].each do |tag|
        			k = tag['Key']
        			v = tag['Value']
        			if k.eql?(tag_name)
          				result = get_resolved(v,workitem)
        			end
        		end
        	end
        	result
		end

		def resolve_to_deviceid(devicename)
			@devicename_map[devicename.downcase]
		end
	end
end


