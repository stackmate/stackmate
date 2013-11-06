%w[ base64 cgi openssl uri digest/sha1 net/https net/http json ].each { |f| require f }


module StackMate
	class CloudStackClient 
		#
  # The following is malformed response title in ACS, should be fixed
  #
  MALFORMED_RESPONSES = {
    /(create|list)counter/i => 'counterresponse',
    /createcondition/i => 'conditionresponse',
    /createautoscalepolicy/i => 'autoscalepolicyresponse',
    /createautoscalevmprofile/i => 'autoscalevmprofileresponse',
    /createautoscalevmgroup/i => 'autoscalevmgroupresponse',
    /enableautoscalevmgroup/i => 'enableautoscalevmGroupresponse',
    /disableautoscalevmgroup/i => 'disableautoscalevmGroupresponse',
    /assignvirtualmachine/i => 'moveuservmresponse',
    /resetsshkeyforvirtualmachine/i => 'resetSSHKeyforvirtualmachineresponse',
    /restorevirtualmachine/i => 'restorevmresponse',
    /activateproject/i => 'activaterojectresponse',
    /listnetworkdevice/i => 'listnetworkdevice',
    /listniciranvpdevicenetworks/i => 'listniciranvpdevicenetworks',
    /cancelstoragemaintenance/i => 'cancelprimarystoragemaintenanceresponse',
    /enablestoragemaintenance/i => 'prepareprimarystorageformaintenanceresponse',
    /copyiso/i => 'copytemplateresponse',
    /deleteiso/i => 'deleteisosresponse',
    /listisopermissions/i => 'listtemplatepermissionsresponse'
  }
		def initialize(api_url, api_key, secret_key, use_ssl=nil)
    		@api_url = api_url
    		@api_key = api_key
    		@secret_key = secret_key
    		@use_ssl = use_ssl
  	end

  	def request(params)
	    params['response'] = 'json'
	    params['apiKey'] = @api_key
	    
	    data = params.map{ |k,v| "#{k.to_s}=#{CGI.escape(v.to_s).gsub(/\+|\ /, "%20")}" }.sort.join('&')
	    
	    signature = OpenSSL::HMAC.digest 'sha1', @secret_key, data.downcase
	    signature = Base64.encode64(signature).chomp
	    signature = CGI.escape(signature)
	    
	    url = "#{@api_url}?#{data}&signature=#{signature}"
	    uri = URI.parse(url)
	    http = Net::HTTP.new(uri.host, uri.port)
	    # http.use_ssl = @use_ssl
	    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	    request = Net::HTTP::Get.new(uri.request_uri)

	    http.request(request)
  	end

  	def api_call(command,params)
  		#params = {'command' => command}
			#params.merge!(args) unless args.empty?
			params['command'] = command
			response = request(params)
			json = JSON.parse(response.body)
			resp_title = command.downcase + "response"
			MALFORMED_RESPONSES.each do |k, v|
				if k =~ command
					resp_title = v
				end
			end
			if !response.is_a?(Net::HTTPOK)
				if ((["431","530"].include?(response.code.to_s)) && (["9999","4350"].include?(json[resp_title]['cserrorcode'].to_s)))
					raise ArgumentError, json[resp_title]['errortext']
				end

				raise RuntimeError, json['errorresponse']['errortext'] if response.code == "432"
				raise Error, "Unable to make request from client due to :" + response.to_s
				#raise CloudstackRubyClient::RequestError.new(response, json)
			end
			json[resp_title]
  	end
	end
end