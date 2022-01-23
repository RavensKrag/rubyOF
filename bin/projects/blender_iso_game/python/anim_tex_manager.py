from utilities import *
from class_reloader import reload_class


from image_wrapper import ( ImageWrapper, get_cached_image )



ImageWrapper = reload_class(ImageWrapper)


from mathutils import Color
import time
import queue
import functools
import json
import sys
import os





# scanline : array of pixel data (not nested array, just a flat array)
# Set the data for one pixel within an array representing a whole scanline
def scanline_set_px(scanline, px_i, px_data, channels=4):
    for i in range(channels):
        scanline[px_i*channels+i] = px_data[i]

    


# TODO: need to force export of everything if the number of objects changes
    # JSON file will be messed up, the cache will be messed up... really need to make sure everything is regenerated. but that's not really the responsibily of this file, I don't think.

class AnimTexManager ():
    # 
    # setup data
    # 
    def __init__(self, context, to_ruby_fifo):
        self.to_ruby = to_ruby_fifo
        
        mytool = context.scene.my_tool
        
        self.max_tris = mytool.max_tris
        
        
        self.__wrap_textures(mytool)
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)
        pixel_data = [1.0, 0.0, 1.0, 1.0] * self.transform_tex.width
        self.transform_tex.write_scanline(pixel_data, 0)
        
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.position_tex.width
        self.position_tex.write_scanline(pixel_data, 0)
        
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.normal_tex.width
        self.normal_tex.write_scanline(pixel_data, 0)
        
        # ASSUME: position_tex.height == normal_tex.height
        if self.position_tex.height != self.normal_tex.height:
            raise "Mesh data textures are not all the same height."
        
        
        # 
        # data cache
        # 
            # self.mesh_data_cache = [
            #     None,
            #     datablock_name # => 'datablock_name: .data.name'
            # ]
            
            
            # self.object_data_cache = [
            #     [None, None],
            #     [mesh_obj_name, first_material.name]
            #         # => 'name: .name'
            # ]
        self.mesh_data_cache   = [None] * self.position_tex.height
        
        self.object_data_cache = ( [[None, None, None]]
                                   * self.transform_tex.height )
        
        
        self.json_filepath = bpy.path.abspath("//anim_tex_cache.json")
        
        self.on_load()
    
    def __wrap_textures(self, mytool):
        self.position_tex = ImageWrapper(
            get_cached_image(mytool, "position_tex",
                             mytool.name+".position",
                             size=self.__calc_geometry_tex_size(mytool),
                             channels_per_pixel=4),
            mytool.output_dir
        )
        
        self.normal_tex = ImageWrapper(
            get_cached_image(mytool, "normal_tex",
                             mytool.name+".normal",
                             size=self.__calc_geometry_tex_size(mytool),
                             channels_per_pixel=4),
            mytool.output_dir
        )
        
        self.transform_tex = ImageWrapper(
            get_cached_image(mytool, "transform_tex",
                             mytool.name+".transform",
                             size=self.__calc_transform_tex_size(mytool),
                             channels_per_pixel=4),
            mytool.output_dir
        )
    
    def __calc_geometry_tex_size(self, mytool):
        width_px  = mytool.max_tris*3 # 3 verts per triangle
        height_px = mytool.max_frames
        
        return [width_px, height_px]
    
    def __calc_transform_tex_size(self, mytool):
        # the transform texture must encode 3 things:
        
        # 1) a mat4 for the object's transform
        channels_per_pixel = 4
        mat4_size = 4*4;
        pixels_per_transform = mat4_size // channels_per_pixel;
        
        # 2) what mesh to use when rendering this object
        pixels_per_id_block = 1
        
        # 3) values needed by the material (like Unity's material property block)
        pixels_for_material = 4
        
        width_px  = pixels_per_id_block + pixels_per_transform + pixels_for_material
        height_px = mytool.max_num_objects
        
        return [width_px, height_px]
    
    
    # def __del__(self):
    #     pass
    
    
    
    # Find the scanline to use for a mesh with the given name.
    # If a mesh with this name is not currently stored in the texture,
    # the first available open row should be use.
    # Note that this may not be the last row in the texture,
    # as there may have been a row that opened up due to a past deletion.
    def __mesh_name_to_scanline(self, mesh_name):
        output_index = 0
        first_open_scanline = -1
        
        # search for the name
        for i, data in enumerate(self.mesh_data_cache):
            cached_mesh_name = data
            
            if i == 0:
                # skip the first row - always intentially left blank
                continue
            
            if cached_mesh_name is None:
                if first_open_scanline == -1:
                    first_open_scanline = i
            elif cached_mesh_name == mesh_name:
                # If you find the name, use that scanline
                return i
            
        
        # If you don't find the name, use the first open scanline
        if first_open_scanline == -1:
            raise "No open scanlines available in the mesh textures. (Scanline i=0 always intentially left blank.) Try increasing the maximum number of objects (aka frames) allowed in exporter."
        else:
            self.mesh_data_cache[first_open_scanline] = mesh_name
            
            return first_open_scanline
    
    
    # Find the scanline to use for a object with the given name.
    # 
    # code based on __mesh_name_to_scanline()
    def __object_name_to_scanline(self, obj_name):
        output_index = 0
        first_open_scanline = -1
        
        # search for the name
        for i, data in enumerate(self.object_data_cache):
            cached_obj_name, cached_mesh_name, cached_material_name = data
            
            if cached_obj_name is None:
                if first_open_scanline == -1:
                    first_open_scanline = i
            elif cached_obj_name == obj_name:
                # If you find the name, use that scanline
                return i
        
        
        # If you don't find the name, use the first open scanline
        if first_open_scanline == -1:
            raise "No open scanlines available in the object texture. Try increasing the maximum number of objects (aka frames) allowed in exporter."
        else:
            self.object_data_cache[first_open_scanline] = [obj_name, None, None]
            
            return first_open_scanline
    
    # Set object -> mesh binding in cache
    def __cache_object_mesh_binding(self, scanline_index, mesh_name):
        data = self.object_data_cache[scanline_index]
        
        # data[0] = obj_name
        data[1] = mesh_name
        # data[2] = material_name
        
        self.object_data_cache[scanline_index] = data
    
    # Set object -> material binding in cache
    def __cache_material_binding(self, scanline_index, material_name):
        data = self.object_data_cache[scanline_index]
        
        # data[0] = obj_name
        # data[1] = mesh_name
        data[2] = material_name
        
        self.object_data_cache[scanline_index] = data
        
    
    
    
    
    
    # data schema
    # ---
    # vertex data texture
        # each row: [vert_0, vert_1, ..., vert_n]
        # every 3 verts (across x dim) encodes a tri (no compression)
        # every row (across the y dim) encodes a different mesh
    # transform data texture
        # each row: [mesh_id (1px), transform (4px), material_datablock (4px)]
    
    
    
    # extra data stored in manager
    # ---
    # mesh name -> vertex data scanline
            # Map names to scanlines.
            # When using external API, should be able to think
            # completely in terms of names, not scanline numbers.
            # IDs should be for internal use only.
    
        # ^ data structure must manage serialization to/from a JSON file
    
    # (one mesh datablock may result in many exported meshes, because you need one line in the output texture per frame of animation. how do I distinguish between different frames of animation?)
    # does the data format need to know about animation? or does it fundamentally only care about transforms and meshes? may be able to move this part of the API into another class / file / whatever.
    
    
    
    # # (maybe want to generate index / reverse index on init? not sure how yet.)
    # self.vertex_data    = []
    # self.transform_data = []
    
    #     # need mesh name -> scanline number to update the vertex data,
    #     # but for spatial queries in Ruby you need
    #     # to map point in space -> mesh name
        
    #     # point in space -> objectID
    #     # objectID -> meshID
    #     # meshID -> mesh name
        
    #     # so you need a meshID_to_meshDatablock mapping
    #     # which is the reverse of what we currently have.
        
    #     # However, rather than maintain 2 indexes in Python,
    #     # just send the one index to Ruby and let Ruby create the other index.
    #     # (we don't need the reverse index here in Python)
    
    def __example_code():
        # 
        # extract transforms from object
        # 
        
        # this_mat = target_object.matrix_local
        this_mat = target_object.matrix_world
        # print(this_mat)
        # print(type(this_mat))
        
        identity_matrix = this_mat.Identity(4)
        
        # out_mat = identity_matrix
        out_mat = this_mat
        
        
        # 
        # extract material from object
        # 
        
        mat_slots = target_object.material_slots
        if len(mat_slots) > 0:
            mat = mat_slots[0].material.rb_mat
        else:
            mat = None
    
    
    
    # TODO: update all code to use RGB (no alpha) to save some memory
    # TODO: use half instead of float to save memory

    # NOTE: all textures in the same animation set have the same dimensions
    
    
    
    
    
    
    
    
    
    # reset all internal state used by the texture manager
    # TODO: should clear the cache and JSON file as well
        # not strictly necessary, as clear() is normally run before deleting the animation manager instance. see main_file.py for usage
    def clear(self, context):
        mytool = context.scene.my_tool
        
        mytool.position_tex  = None
        mytool.normal_tex    = None
        mytool.transform_tex = None
    
    
    
    # Does an object with this name exist in the texture?
    # ( based on code from __object_name_to_scanline() )
    def has_object(self, obj_name):
        # search for the name
        for i, data in enumerate(self.object_data_cache):
            cached_obj_name, cached_mesh_name, cached_material_name = data
            
            if cached_obj_name == obj_name:
                return True
        
        # object not found
        return False
    
    
    
    # Does a mesh with this name exist in the texture?
    # (more important on the ruby side, but also helpful to optimize export)
    # 
    # mesh_name : string
    def has_mesh(self, mesh_name):
        return (mesh_name in self.mesh_data_cache)
    
    
    # Encode both vertex positions and normals of a mesh into a texture.
    # Every 3 pixels encodes the x,y,z coordinates for a given vertex.
    # Each scanline of the texture encodes one mesh.
    # The scanline to use will be calculated automatically.
    # Must update some mapping of "mesh name" => "mesh data"
    # ( mapping also used by has_mesh() )
    # 
    # mesh_name : string
    # mesh      : mesh datablock
    def export_mesh(self, mesh_name, mesh):
        mesh.calc_loop_triangles()
        # ^ need to call this to populate the mesh.loop_triangles() cache
        
        mesh.calc_normals_split()
        # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
        # ^ normals stored on the tri / face
        
        
        # 
        # allocate scanlines of pixels for mesh encoding
        # 
        
        # (set r,g,b channels of position to the same non-zero value to help with debugging - easy to confirm that something got written if the scanline shows up as non-black)
        scanline_position = [0.2, 0.2, 0.2, 1.0] * self.position_tex.width
        scanline_normals  = [0.0, 0.0, 0.0, 1.0] * self.normal_tex.width
        # pixel_data_tan = [0.0, 0.0, 0.0, 1.0] * width_px
        
        
        # 
        # pack each and every triangle
        # 
        
        # number of actual verts likely to be less than maximum
        # so just measure the list
        num_tris  = len(mesh.loop_triangles)
        num_verts = len(mesh.loop_triangles)*3
        print("num tris:", num_tris)
        print("num verts:", num_verts)

        if num_tris > self.max_tris:
            raise RuntimeError(f'The mesh {mesh} has {num_tris} tris, but the animation texture has a limit of {self.max_tris} tris. Please increase the size of the animation texture.')
        
        
        verts = mesh.vertices
        for i, tri in enumerate(mesh.loop_triangles): # triangles per mesh
            normals = tri.split_normals
            for j in range(3): # verts per triangle
                vert_index = tri.vertices[j]
                vert = verts[vert_index]
                
                scanline_set_px(scanline_position, i*3+j, vec3_to_rgba(vert.co),
                                channels=self.position_tex.channels_per_pixel)
                
                
                normal = normals[j]
                
                scanline_set_px(scanline_normals, i*3+j, vec3_to_rgba(normal),
                                channels=self.normal_tex.channels_per_pixel)
        
        
        # NOTE: only way to be sure that mesh data is deleted is to do a "clean build" - clear the textures and re-export everything from scratch.
        output_frame = self.__mesh_name_to_scanline(mesh_name)
        
        self.position_tex.write_scanline(scanline_position, output_frame)
        self.normal_tex.write_scanline(scanline_normals, output_frame)
        
        
        self.position_tex.save()
        self.normal_tex.save()
    
    
    # Specify the mesh to use for a given object @ t=0 (initial condition)
    # by setting the first pixel in the scanline to r=g=b="mesh scanline number"
    # (3 channels have the same data; helps with visualization of the texture)
    # This mapping will be changed by ruby code during game execution,
    # by dynamically editing the texture in memory. However, the texture
    # on disk will change if and only if the initial condition changes.
    # Raise exception if no mesh with the given name has been exported yet.
    # 
    # obj_name  : string
    # mesh_name : string ( must already be exported using export_mesh() )
    def set_object_mesh(self, obj_name, mesh_name):
        scanline_index = self.__object_name_to_scanline(obj_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.transform_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        print(scanline_transform, flush=True)
        
        # 
        # write mesh id to scanline
        # 
        
        # error if mesh has not been exported yet
        if not self.has_mesh(mesh_name):
            raise f"No mesh with the name {mesh_name} found. Make sure to export the mesh using export_mesh() before mapping the mesh to an object."
        
        mesh_id = self.__mesh_name_to_scanline(mesh_name)
        
        scanline_set_px(scanline_transform, 0, [mesh_id, mesh_id, mesh_id, 1.0],
                        channels=self.transform_tex.channels_per_pixel)
        
        self.__cache_object_mesh_binding(scanline_index, mesh_name)
        
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
    
    
    # Pack 4x4 transformation matrix for an object into 4 pixels
    # of data in the object transform texture.
    # 
    # obj_name  : string
    # transform : 4x4 transform matrix
    def set_object_transform(self, obj_name, transform):
        scanline_index = self.__object_name_to_scanline(obj_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.transform_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        
        
        # 
        # write transforms to scanline
        # 
        for i in range(1, 5): # range is exclusive of high end: [a, b)
            scanline_set_px(scanline_transform, i, vec4_to_rgba(transform[i-1]),
                            channels=self.transform_tex.channels_per_pixel)
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
    
    
    # Bind object to a particular material,
    # and pack material data into 4 pixels in the object transform texture.
    # 
    # obj_name : string
    # material : blender material datablock, containing RubyOF material
    def set_object_material(self, obj_name, material):
        scanline_index = self.__object_name_to_scanline(obj_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.transform_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        
        # 
        # write material properties to scanline
        # (if no material set, default to white)
        # 
        
        # color = c1 = c2 = c3 = c4 = alpha = None
        
        if material is None:
            # default white for unspecified color
            # (ideally would copy this from the default in materials)
            color = Color((1.0, 1.0, 1.0)) # (0,0,0)
            c1 = color
            c2 = color
            c3 = color
            c4 = color
            alpha = 1
        else:
            c1    = material.rb_mat.ambient
            c2    = material.rb_mat.diffuse
            c3    = material.rb_mat.specular
            c4    = material.rb_mat.emissive
            alpha = material.rb_mat.alpha
        
        scanline_set_px(scanline_transform, 5, vec3_to_rgba(c1),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 6, vec3_to_rgba(c2)+ [alpha],
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                        channels=self.transform_tex.channels_per_pixel)
        
        
        self.__cache_material_binding(scanline_index, material.name)
        
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
    
    
    # Update material properties for all objects that use the given material.
    # ( must have previously bound material using set_object_material() )
    # 
    # material : blender material datablock, containing RubyOF material
    def update_material(self, material):
        # FIXME: may actually need the blender material block after all, because that may be where the names are stored
        
        
        # 1) traverse the cache to find all objects that use this material
        # 2) update all of those objects
        
        for data in self.object_data_cache:
            cached_obj_name, cached_mesh_name, cached_material_name = data
            
            if cached_material_name == material.name:
                self.set_object_material(obj_name, material)
    
    
    # Remove object from the transform texture.
    # No good way right now to "garbage collect" unused mesh data.
    # For now, that data will continue to exist in the mesh data textures,
    # and will only be cleared out on a "clean build" of all data.
    # 
    # obj_name : string
    def delete_object(self, obj_name):
        # TODO: Consider storing resource counts in the first pixel
        # 
        # If saving resource counts doesn't work,
        # I can have some update function in the manager class
        # which is called every frame / every update,
        # and which compares the current list of objects to the previous list.
        # The difference set between these two
        # would tell you what objects were deleted.
        
        # (This is the technique I've already been using to parse deletion, but it happened at the Ruby level, after I recieved the entity list from Python.)
        
        
        scanline_index = self.__object_name_to_scanline(obj_name)
        
        
        # This time, you *want* to clobber the data,
        # so don't read what's currently in there.
        scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
        
        
        
    # dict mapping object name -> scanline index
    def get_object_name_map(self):
        pass
    
    
    # dict mapping mesh name -> scanline index
    def get_mesh_name_map(self):
        pass
    
    
    def get_texture_paths(self):
        return (self.position_tex.filepath,
                self.normal_tex.filepath,
                self.transform_tex.filepath)
    
    # 
    # serialization
    # 
    
    def on_save(self):
        data = {
            'mesh_data_cache': self.mesh_data_cache,
            'object_data_cache': self.object_data_cache
        }
        
        # print(json.dumps(data))
        
        # sys.stdout.flush()
        # ^ if you don't flush, python may buffer stdout
        #   This is a feature of python in general, not just Blender
        # Can also use the flush= named parameter on print()
        # https://stackoverflow.com/questions/230751/how-can-i-flush-the-output-of-the-print-function
        
        # print()
        
        
        with open(self.json_filepath, 'w') as f:
            f.write(json.dumps(data, indent=2))
        
    def on_load(self):
        if os.path.isfile(self.json_filepath):
            with open(self.json_filepath, 'r') as f:
                data = json.load(f)
                
                print(data)
                sys.stdout.flush()
                
                self.mesh_data_cache   = data['mesh_data_cache']
                self.object_data_cache = data['object_data_cache']
    
    
    
    # 
    # undo / redo callbacks
    # 
    
    
    def on_undo(self, scene):
        mytool = scene.my_tool
        
        # mytool.position_tex  = None
        # mytool.normal_tex    = None
        # mytool.transform_tex = None
        
        self.__wrap_textures(mytool)
    
    def on_redo(self, scene):
        mytool = scene.my_tool
        
        # mytool.position_tex  = None
        # mytool.normal_tex    = None
        # mytool.transform_tex = None
        
        self.__wrap_textures(mytool)
    
 

# def register_depgraph_handlers():
#     depsgraph_events = bpy.app.handlers.depsgraph_update_post
    
#     if not on_depsgraph_update in depsgraph_events:
#         depsgraph_events.append(on_depsgraph_update)

# def unregister_depgraph_handlers():
#     depsgraph_events = bpy.app.handlers.depsgraph_update_post
    
#     if on_depsgraph_update in depsgraph_events:
#         depsgraph_events.remove(on_depsgraph_update)



# def on_depsgraph_update(scene, depsgraph):
#     global anim_tex_manager
#     if anim_tex_manager is not None:
#         anim_tex_manager.update(scene)


# bpy.app.handlers.undo_post
# ^ use this handler to revert object state after undo
 
# NOTE: may need to re-accuire image handles on undo / redo

# NOTE: depsgraph is not updated when objecs are deleted

