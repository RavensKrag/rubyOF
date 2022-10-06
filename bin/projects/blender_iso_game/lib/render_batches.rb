# based on VertexAnimationTextureSet
# Only manages render data (storage and serialization).
# 
# Does not perform rendering (see OIT_RenderPipeline instead)
# Does not update entity data (see RenderEntityManager instead)
# Does not move data from cache -> pixels -> texture (see World#update instead)
class RenderBatch
  include RubyOF::Graphics
  
  attr_reader :name
  
  def initialize(data_dir, name)
    @data_dir = data_dir
    @name = name
    
    @storage = FixedSchemaTree.new({
      :mesh_data => {
        :pixels => {
          :positions  => RubyOF::FloatPixels.new,
          :normals    => RubyOF::FloatPixels.new,
        },
        
        :textures => {
          :positions  => RubyOF::Texture.new,
          :normals    => RubyOF::Texture.new,
        }
      },
      
      :entity_data => {
        :pixels  => RubyOF::FloatPixels.new,
        :texture => RubyOF::Texture.new,
      },
      
      :entity_cache => RubyOF::Project::EntityCache.new, # size == num dynamic entites
      
      :entity_history => HistoryBuffer.new,
      
      :names => TextureJsonCache.new, # <- "json file"
        # ^ convert name to scanline AND scanline to name
      
      :geometry => BatchGeometry.new # size == max tris per mesh in batch
      
    })
    
    [
      @storage[:mesh_data][:textures][:positions],
      @storage[:mesh_data][:textures][:normals],
      @storage[:entity_data][:texture]
    ].each do |texture|
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical   => :clamp_to_edge,
                        :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
    end
    
  end
  
  # allow hash-style access to the FixedSchemaTree
  # (FixedSchemaTree not not allow adding elements, so this is fine)
  def [](key)
    return @storage[key]
  end
  
  
  def load_json_data(json_file_path)
    @storage[:names].load json_file_path
    
    # @storage[:static][:cache].load @storage[:static][:entity_data][:pixels]
  end
  
  # load data from disk -> pixels
  def load_entity_pixels(entity_tex_path)
    [
      [ entity_tex_path,
        @storage[:entity_data][:pixels] ],
    ].each do |path_to_file, pixels|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
    end
  end
  
  # position and normals will always be updated in tandem
  # load data from disk -> pixels
  def load_mesh_pixels(position_tex_path, normal_tex_path)
    [
      [ position_tex_path,
        @storage[:mesh_data][:pixels][:positions] ],
      [ normal_tex_path,
        @storage[:mesh_data][:pixels][:normals] ]
    ].each do |path_to_file, pixels|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
    end
  end
  
  # ASSUME: pixels and texture are the same dimensions, as they correspond to CPU and GPU representations of the same data
  
  # show an abbreviated version of the data inside the batch, as the entire thing would be many pages long
  def inspect
    "#<#{self.class}:object_id=#{self.object_id} @name=#{@name}>"
  end
  
  class TextureJsonCache
    def initialize
      @json = nil
    end
    
    def load(json_filepath)
      unless File.exist? json_filepath
        # TODO: raises execption after export, but if you restart the game engine everything is fine. need to debug that.
        raise "No file found at '#{json_filepath}'. Expected JSON file with names of meshes and entities. Try re-exporting from Blender."
      end
      
      json_string   = File.readlines(json_filepath).join("\n")
      json_data     = JSON.parse(json_string)
      
      @json = json_data
    end
    
    
    def num_meshes
      return @json["mesh_data_cache"].size
    end
    
    
    
    def entity_scanline_to_name(i)
      data = @json['entity_data_cache'][i]
      return data['entity name']
    end
    
    def mesh_scanline_to_name(i)
      return @json['mesh_data_cache'][i]
    end
    
    
    
    def entity_name_to_scanline(target_entity_name)
      entity_idx = nil
      
      # TODO: try using #find_index instead
      @json['entity_data_cache'].each_with_index do |data, i|
        if data['entity name'] == target_entity_name
          # p data
          entity_idx = i
          break
        end
      end
      
      return entity_idx
    end
    
    # @json includes a blank entry for scanline index 0
    # even though that scanline is not represented in the cache
    def mesh_name_to_scanline(target_mesh_name)
      mesh_idx = nil
      
      # TODO: try using #find_index instead
      @json['mesh_data_cache'].each_with_index do |mesh_name, i|
        if mesh_name == target_mesh_name
          # p data
          mesh_idx = i
          break
        end
      end
      
      return mesh_idx
    end
    
  end
  
  
  class BatchGeometry
    def initialize
      @mesh = nil
    end
    
    def generate(vertex_count)
      @mesh = create_mesh(vertex_count)
    end
    
    def draw_instanced(instance_count)
      @mesh.draw_instanced(instance_count)
    end
    
    private
    
    def create_mesh(num_verts)
      # 
      # Create a mesh consiting of a line of unconnected triangles
      # the verticies in this mesh will be transformed by the textures
      # so it doesn't matter what their exact positons are.
      # 
      RubyOF::VboMesh.new.tap do |mesh|
        mesh.setMode(:triangles)
        # ^ TODO: maybe change ruby interface to mode= or similar?
        
        num_tris = num_verts / 3
        
        size = 1 # useful when prototyping to increase this for visualization
        num_tris.times do |i|
          a = i*3+0
          b = i*3+1
          c = i*3+2
          # DEBUG PRINT: show indicies assigned to tris an verts
          # p [i, [a,b,c]]
          
          
          # UV coordinates specified in pixel indicies
          # will offset by half a pixel in the shader
          # to sample at the center of each pixel
          
          mesh.addVertex(GLM::Vec3.new(size*i,0,0))
          mesh.addTexCoord(GLM::Vec2.new(a, 0))
          
          mesh.addVertex(GLM::Vec3.new(size*i+size,0,0))
          mesh.addTexCoord(GLM::Vec2.new(b, 0))
          
          mesh.addVertex(GLM::Vec3.new(size*i,size,0))
          mesh.addTexCoord(GLM::Vec2.new(c, 0))
          
        end
      end
      
    end
  end


end


class RenderBatchContainer
  def initialize(world, geometry_texture_directory:nil, buffer_length:3600)
    @world = world
    
    @geom_data_dir = geometry_texture_directory
    @buffer_length = buffer_length
    @batches = Array.new
  end
  
  # 
  # mimic parts of the Array interface
  # 
  def each() # &block
    return enum_for(:each) unless block_given?
    
    @batches.each do |b|
      yield b
    end
  end
  
  include Enumerable
  
  def zip(list)
    return @batches.zip(list)
  end
  
  
  # 
  # custom interface for this collection
  # 
  
  def setup
    # allocate 1 RenderBatch object for each texture set
    # that has already been exported from Blender
    # and now currently lives on the disk
    @batches = 
      batch_names_on_disk(@geom_data_dir)
      .collect do |name|
        RenderBatch.new(@geom_data_dir, name)
      end
    
    # load the data from the disk, allocating memory as needed
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
    end
  end
  
  # Question:
  # How are the batches reloaded?
  # If I export different batches from blender, or update an existing batch
  # the files need to be reloaded in the engine.
  # Where in the codebase does that actually happen?
  # 
  # in the mainline file,
  # BlenderSync#update_geometry_data
  # -> World#load_json_data
  # -> World#load_entity_texture
  # -> World#load_mesh_textures
  # which then calls methods on VertexAnimationTextureSet
  # 
  # That load logic only handles reloading textures that are already defined.
  # It recieves a name of a file that was updated,
  # so it needs to match that against a batch to figure out what to reload.
  # But because of that, the side-effect is that it can't load a completely
  # new batch. At least, I don't think it should be able to.
  # 
  # What about deleting a batch?
  # How would that work?
  # When we delete entities, we match against a list of known entities.
  # Can I easily get a list of known batches with the current structure,
  # or do I need to export more data?
  
  
  # update existing batches
  # and create new batches as necessary
  def on_full_export(ipc, texture_dir, collection_name)
    batch_names = batch_names_on_disk(@geom_data_dir)
    new_names = Set.new(batch_names) - Set.new(@batches.collect{|x| x.name})
    
    # update 
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
    end
    
    
    # create new
    
    
    @world.history.branch
  end
  
  
  
  
  
  # all texture sets have been exported from scratch
  def on_clean_build(ipc, texture_dir, collection_name)
    @geom_data_dir = texture_dir
    self.setup()
  end
  
  # create one new texture set
  def on_texture_set_created(ipc, texture_dir, collection_name)
    RenderBatch.new(@geom_data_dir, name).tap do |b|
      batch_dsl(b) do |x|
        x.json.disk_to_hash
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
      
      @batches << b
    end
    
    
    @world.history.branch
  end
  
  # delete one existing texture set
  def on_texture_set_deleted(ipc, texture_dir, collection_name)
    @batches.delete_if{|b| b.name == collection_name }
    
    # NOTE: this may cause errors if the current code in the update block depends on the entities that are being deleted
    # NOTE: this also deletes a chunk of history that was associated with that texture set
    
    # (maybe we should push the system back to t=0, as so much of the initial state has changed?)
    
    @world.history.branch
  end
  
  
  # Question: initial state, or state over time?
  def on_entity_moved(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        # x.entity.pixels_to_texture
        # x.entity.pixels_to_cache
      end
    end
    
    
    
    @world.history.branch
  end
  
  # (not hooked up yet)
  def on_entity_deleted(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @world.history.branch
  end
  
  def on_entity_created(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @world.history.branch
  end
  
  def on_entity_created_with_new_mesh(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @world.history.branch
  end
  
  # note - can't just create new mesh, would have to create a new entity too
  
  # (for now) mesh only effects apperance; should not change history
  # (later when we have animations: may want to branch state based on animation frame, like checking for active frames during an attack animation)
  def on_mesh_edited(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture        
      end
    end
    
    @world.history.branch
  end
  
  # update material data (in entity texture) as well as material names (in json)
  # (for now, material only effects apperance; editingshould not change history)
  def on_material_edited(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
      end
    end
    
    # @world.history.branch
  end
  
  # this seems to function on all batches,
  # rather than on a single target batch
  def on_gc(ipc, texture_dir, collection_name)
    
    
    @world.history.branch
  end
  
  
  # if message['json_file_path'] || message['entity_tex_path']
  #   @world.space.update
  # end
  # TODO: query some hash of queries over time, to figure out if the changes to geometry would have effected spatial queries (see "current issues" notes for details)
  
  private
  
  def batch_names_on_disk(directory)
    directory.children
    .select{ |file| file.basename.to_s.end_with? ".cache.json" }
    .collect do |file|
      # p file
      file.basename.to_s.split('.').first # => name
    end
  end
  
  
  def batch_dsl(batch)
    yield DSL_Helper.new(@geom_data_dir, batch)
  end
  
  class DSL_Helper
    attr_reader :json, :entity, :mesh
    
    def initialize(geom_data_dir, batch)
      args = [
        batch,
        geom_data_dir/"#{batch.name}.cache.json",
        geom_data_dir/"#{batch.name}.position.exr",
        geom_data_dir/"#{batch.name}.normal.exr",
        geom_data_dir/"#{batch.name}.entity.exr"
      ]
      
      @json   = JsonDSL.new(*args)
      @entity = EntityDSL.new(*args)
      @mesh   = MeshDSL.new(*args)
    end
    
    class InnerDSL
      def initialize(b,j,p,n,e)
        @batch = b
        @json_file_path    = j
        @position_tex_path = p
        @normal_tex_path   = n
        @entity_tex_path   = e
      end
    end
    
    # json names API
    class JsonDSL < InnerDSL
      def disk_to_hash
        @batch.load_json_data(@json_file_path)
        return self
      end
    end
    
    # entity texture API
    class EntityDSL < InnerDSL
      # disk -> pixels (entity)
      def disk_to_pixels
        @batch.load_entity_pixels(@entity_tex_path)
        return self
      end
      
      # pixels -> texture (entity)
      def pixels_to_texture
        @batch[:entity_data][:texture].load_data @batch[:entity_data][:pixels]
        return self
      end
      
      # pixels -> cache
      def pixels_to_cache
        @batch[:entity_cache].load @batch[:entity_data][:pixels]
        return self
      end
      
      # cache -> pixels
      def cache_to_pixels
        @batch[:entity_cache].update @batch[:entity_data][:pixels]
        return self
      end
    end
    
    class MeshDSL < InnerDSL
      # disk -> pixels (mesh)
      def disk_to_pixels
        @batch.load_mesh_pixels(@position_tex_path, @normal_tex_path)
        return self
      end
      
      # pixels -> texture (mesh)
      def pixels_to_texture
        [
          [
            @batch[:mesh_data][:textures][:positions],
            @batch[:mesh_data][:pixels][:positions]
          ],
          [
            @batch[:mesh_data][:textures][:normals],
            @batch[:mesh_data][:pixels][:normals]
          ]
        ].each do |texture, pixels|
          texture.load_data pixels
        end
        
        return self
      end
      
      # pixels (mesh) -> geometry
      def pixels_to_geometry
        # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
        vertex_count = @batch[:mesh_data][:pixels][:positions].width.to_i
        @batch[:geometry].generate vertex_count
        
        return self
      end
    end
    
  end
  
end

  # NOTE: BlenderSync triggers @world.space.update when either json file or entity texture is reloaded
  # ^ currently commented out, so this isn't actually happening

# if the textures are reloaded, then you need to update the entity cache too





