require 'stackmate/logging'
module StackMate
	class Metadata
		include Logging
		#nothing fancy 
		@@metadata_map = {}
		def self.add_metadata(stack_id, logical_id, metadata)
			#nothing fancy again, can refactor later if needed
			if(!@@metadata_map.has_key?(stack_id))
				@@metadata_map[stack_id] = {}
			end

			@@metadata_map[stack_id][logical_id] = metadata
			#logger.debug("Successfully added metadata for resource #{logical_id} in stack #{stack_id}")
		end

		def self.get_metadata(stack_id,logical_id)
			metadata = {}
			if(@@metadata_map.has_key?(stack_id) && @@metadata_map[stack_id].has_key?(logical_id))
				metadata = @@metadata_map[stack_id][logical_id]
			end
			metadata
		end

		#below may not be needed
		def self.delete_metadata(stack_id, logical_id)
			if(@@metadata_map.has_key?(stack_id) && @@metadata_map[stack_id].has_key?(logical_id))
				@@metadata_map[stack_id].delete(logical_id)
			end
			#logger.debug("Successfully deleted metadata for resource #{logical_id} in stack #{stack_id}")
		end

		def self.clear_stack_metadata(stack_id)
			if(@@metadata_map.has_key?(stack_id))
				@@metadata_map.delete(stack_id)
			end
		end

		def self.clear_metadata()
			@@metadata_map.clear
		end

	end
end