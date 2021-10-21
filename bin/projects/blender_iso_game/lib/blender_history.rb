class BlenderHistory
  # EMPTY = {}.freeze
  
  def initialize
    @all_data   = Hash.new
    @last_delta = Hash.new
  end
  
  def write(data)
    merge!(@last_delta, data) # merge with existing diff
    
    return self
  end
  
  def read
    # unless @all_data.equal? @last_delta
      merge!(@all_data, @last_delta)
      
      out = @last_delta
      @last_delta = {} # or equivalent empty collection
    # end
    
    return out
  end
  
  # After this method is called, the next call to #read
  # should return the full state up to this point.
  # This will allow for the full restoration of the state.
  def on_reload
    File.open(PROJECT_DIR/'bin'/'data'/'tmp_all.json', 'w') do |f|
      f.puts JSON.pretty_generate @all_data
    end
    
    File.open(PROJECT_DIR/'bin'/'data'/'tmp_delta.json', 'w') do |f|
      f.puts JSON.pretty_generate @last_delta
    end
    
    
    merge!(@all_data, @last_delta)
    @last_delta = @all_data
    
    
    # # merge data with existing diff
    # # but ignore the interrupt commands
    # if @last_delta.has_key? 'interrupt'
    #   @last_delta.delete('interrupt')
    # end
    
    # # also remove the timestamps
    # if @last_delta.has_key? 'timestamps'
    #   @last_delta.delete('timestamps')
    # end
    
    
    File.open(PROJECT_DIR/'bin'/'data'/'blender_data.json', 'w') do |f|
      f.puts JSON.pretty_generate @last_delta
    end
    
    
    return self
  end
  
  
  private
  
  # Can't just merge the top-level hash objects,
  # because there are some lists that need to be merged too.
  def merge!(existing_data, new_data)
    # data = {
    #     'timestamps' : {
    #         'start_time': total_t0,
    #         'end_time':   total_t1
    #     },
        
    #     'all_entity_names' : object_list,
        
    #     'objects' : obj_export,
    #     'datablocks' : datablock_export,
        
    #     'materials' : material_export,
    #     'material_map' : material_map
    # }
    
    # ^ from __init__.py
    
    
    # existing_data.merge! new_data
    
    
    
    existing_data.tap do |out|
      # viewport camera
      if new_data.has_key? 'viewport_camera'
        out['viewport_camera'] = new_data['viewport_camera']
      end
      
      # viewport for window sync
      if new_data.has_key? 'viewport_region'
        out['viewport_region'] = new_data['viewport_region']
      end
      
      
      # merge lists
      if new_data.has_key? 'all_entity_names'
        old_list = existing_data['all_entity_names'] || []
        list = new_data['all_entity_names'] + old_list
        
        out['all_entity_names'] = list.uniq
      end
      
      if new_data.has_key? 'objects'
        old_list = existing_data['objects'] || []
        list = new_data['objects'] + old_list
        
        out['objects'] = list.uniq{|data|  data['name']  }
      end
      
      # NOTE: currently only mesh datablocks are supported
      if new_data.has_key? 'datablocks'
        old_list = existing_data['datablocks'] || []
        list = new_data['datablocks'] + old_list
        
        out['datablocks'] = list.uniq{|data|  data['mesh_name']  }
      end
      
      if new_data.has_key? 'materials'
        old_list = existing_data['materials'] || []
        list = new_data['materials'] + old_list
        
        out['materials'] = list.uniq{|data|  data['name']  }
      end
      
      
      # merge inner maps
      [
        'material_map'
      ].each do |map_name|
        if new_data.has_key? map_name
          if existing_data.has_key? map_name
            out.merge! new_data[map_name]
          else
            out[map_name] = new_data[map_name]
          end
        end
      end
    end
  end
end
