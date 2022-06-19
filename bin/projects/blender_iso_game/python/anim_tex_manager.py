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

import math

import numpy



# scanline : array of pixel data (not nested array, just a flat array)
# Set the data for one pixel within an array representing a whole scanline
def scanline_set_px(scanline, px_i, px_data, channels=4):
    for i in range(channels):
        scanline[px_i*channels+i] = px_data[i]



# TODO: need to force export of everything if the number of entities changes
    # JSON file will be messed up, the cache will be messed up... really need to make sure everything is regenerated. but that's not really the responsibily of this file, I don't think.

class AnimTexManager ():
    # 
    # setup data
    # 
    def __init__(self, scene, texture_set_name):
        # Storing name and not texture set directly so that the proper data can be rebound on undo / redo. Name change is automatically updated when ResourceManager.rename is called.
        self.name = texture_set_name
        
        mytool = scene.my_tool.texture_sets[self.name]
        
        self.max_tris = mytool.max_tris
        
        self.output_dir = scene.my_tool.output_dir
        self.__wrap_textures(scene, self.name, self.output_dir)
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)
        
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.position_tex.width
        self.position_tex.write_scanline(pixel_data, 0)
        
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.normal_tex.width
        self.normal_tex.write_scanline(pixel_data, 0)
        
        # ASSUME: position_tex.height == normal_tex.height
        if self.position_tex.height != self.normal_tex.height:
            raise RuntimeError("Mesh data textures are not all the same height.")
        
        
        # 
        # data cache
        # 
            # self.mesh_data_cache = [
            #     None,
            #     datablock_name # => 'datablock_name: .data.name'
            # ]
            
            
            # self.entity_data_cache = [
            #     [None, None],
            #     [mesh_obj_name, first_material.name]
            #         # => 'name: .name'
            # ]
        self.mesh_data_cache   = [None] * self.position_tex.height
        
        self.entity_data_schema = {
            'parent' : None,
            'entity name' : None,
            'mesh name' : None,
            'material name' : None,
        }
        self.entity_data_cache = ( [ self.entity_data_schema.copy() ]
                                   * self.entity_tex.height )
        
        
        self.json_filepath = os.path.join(bpy.path.abspath(self.output_dir),
                                          self.name+'.cache'+'.json')
        
        
        self.load()
    
    def __wrap_textures(self, scene, name, output_dir):
        mytool = scene.my_tool.texture_sets[name]
        
        self.position_tex = ImageWrapper(
            get_cached_image(mytool, "position_tex",
                             mytool.name+".position",
                             size=self.__calc_geometry_tex_size(mytool),
                             channels_per_pixel=4),
            output_dir
        )
        
        self.normal_tex = ImageWrapper(
            get_cached_image(mytool, "normal_tex",
                             mytool.name+".normal",
                             size=self.__calc_geometry_tex_size(mytool),
                             channels_per_pixel=4),
            output_dir
        )
        
        self.entity_tex = ImageWrapper(
            get_cached_image(mytool, "entity_tex",
                             mytool.name+".entity",
                             size=self.__calc_entity_tex_size(mytool),
                             channels_per_pixel=4),
            output_dir
        )
    
    def __calc_geometry_tex_size(self, mytool):
        width_px  = mytool.max_tris*3 # 3 verts per triangle
        height_px = mytool.max_frames
        
        return [width_px, height_px]
    
    def __calc_entity_tex_size(self, mytool):
        # the transform texture must encode 3 things:
        
        # 1) a mat4 for the entity's transform
        channels_per_pixel = 4
        mat4_size = 4*4;
        pixels_per_transform = mat4_size // channels_per_pixel;
        
        # 2) what mesh to use when rendering this entity
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
            raise RuntimeError("No open scanlines available in the mesh textures. (Scanline i=0 always intentially left blank.) Try increasing the maximum number of entities (aka frames) allowed in exporter.")
        else:
            self.mesh_data_cache[first_open_scanline] = mesh_name
            
            return first_open_scanline
    
    
    # Find the scanline to use for an entity with the given name.
    # 
    # code based on __mesh_name_to_scanline()
    def __entity_name_to_scanline(self, entity_name):
        output_index = 0
        first_open_scanline = -1
        
        # search for the name
        for i, data in enumerate(self.entity_data_cache):
            if data['entity name'] is None:
                if first_open_scanline == -1:
                    first_open_scanline = i
            elif data['entity name'] == entity_name:
                # If you find the name, use that scanline
                return i
        
        
        # If you don't find the name, use the first open scanline
        if first_open_scanline == -1:
            raise RuntimeError("No open scanlines available in the entity texture. Try increasing the maximum number of entities (aka frames) allowed in exporter.")
        else:
            data = self.entity_data_schema.copy()
            data['entity name'] = entity_name
            data['parent'] = entity_name
            self.entity_data_cache[first_open_scanline] = data
            
            return first_open_scanline
    
    # Set entity -> mesh binding in cache
    def __cache_entity_mesh_binding(self, scanline_index, mesh_name):
        data = self.entity_data_cache[scanline_index]
        
        # data['entity name'] = obj_name
        data['mesh name'] = mesh_name
        # data['material name'] = material_name
        
        self.entity_data_cache[scanline_index] = data
    
    # Set entity -> material binding in cache
    def __cache_material_binding(self, scanline_index, material_name):
        data = self.entity_data_cache[scanline_index]
        
        # data['entity name'] = obj_name
        # data['mesh name'] = mesh_name
        data['material name'] = material_name
        
        self.entity_data_cache[scanline_index] = data
    
    def __cache_entity_parent(self, scanline_index, parent_name):
        data = self.entity_data_cache[scanline_index]
        
        data['parent'] = parent_name
        
        self.entity_data_cache[scanline_index] = data
        
        
    
    
    
    
    
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
        
    #     # point in space -> entityID
    #     # entityID -> meshID
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
    def clear(self, scene):
        mytool = scene.my_tool
        
        tex_set = mytool.texture_sets[self.name]
        
        tex_set.position_tex  = None
        tex_set.normal_tex    = None
        tex_set.entity_tex    = None
        
        
        # print("checking json path", flush=True)
        if os.path.isfile(self.json_filepath):
            # print("clearing old json file", flush=True)
            os.remove(self.json_filepath)
        
        # print("images: ", len(bpy.data.images), flush=True)
        # for block in bpy.data.images:
        #     if block.users == 0:
        #         bpy.data.images.remove(block)
            
    
    
    
    # Does an entity with this name exist in the texture?
    # ( based on code from __entity_name_to_scanline() )
    def has_entity(self, obj_name):
        # search for the name
        for i, data in enumerate(self.entity_data_cache):
            if data['entity name'] == obj_name:
                print(data['entity name'], " found in the cache", flush=True)
                return True
        
        # entity not found
        print("ENTITY NOT FOUND: ", obj_name, flush=True)
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
    # 
    # returns: number of exported mesh segments
    def export_mesh(self, mesh_name, mesh):
        mesh.calc_loop_triangles()
        # ^ need to call this to populate the mesh.loop_triangles() cache
        
        mesh.calc_normals_split()
        
        # after splitting, vertex normal == split normal
        mesh.split_faces()
        mesh.calc_normals()
        
        
        # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
        # ^ normals stored on the tri / face
        
        
        # 
        # allocate scanlines of pixels for mesh encoding
        # 
        
        # (set r,g,b channels of position to the same non-zero value to help with debugging - easy to confirm that something got written if the scanline shows up as non-black)
        
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
        print("max tris:", self.max_tris)
        
        print(self.position_tex.filepath, flush=True)
        print(self.normal_tex.filepath, flush=True)
        
        
        # if num_tris > self.max_tris:
        #     raise RuntimeError(f'The mesh {mesh} has {num_tris} tris, but the animation texture has a limit of {self.max_tris} tris. Please increase the size of the animation texture.')
        
        
        # NOTE: only way to be sure that mesh data is deleted is to do a "clean build" - clear the textures and re-export everything from scratch.
        scanline_index = self.__mesh_name_to_scanline(mesh_name)
        
        
        
        
        # https://devtalk.blender.org/t/bpy-data-images-perf-issues/6459
        
        # https://blender.stackexchange.com/questions/240587/calculating-split-normals-using-python
        
        # print("loops length: ", mesh.name, len(mesh.loops), flush=True)
        # norms = numpy.empty(3 * len(mesh.loops))
        # mesh.loops.foreach_get("normal", norms)
        # nx, ny, nz = norms.reshape((-1, 3)).T
        # na = numpy.ones(len(nz))
        
        # norm_pixels = numpy.array([nx, ny, nz, na]).T.ravel()
        
        # # t1 = numpy.empty(3 * len(mesh.loops))
        # # t2 = numpy.empty(3 * len(mesh.loops))
        # # t1.data.foreach_set("uv", numpy.array([nx, ny]).T.ravel())
        # # t2.data.foreach_set("uv", numpy.array([nz, nw]).T.ravel())
        
        
        # self.normal_tex.write_scanline(norm_pixels, scanline_index)
        
        
        
        
        
        
        
        
        # 
        # reference position implementation
        # 
        
        
        # verts = mesh.vertices
        # for i, tri in enumerate(mesh.loop_triangles): # triangles per mesh
        #     for j in range(3): # verts per triangle
        #         vert_index = tri.vertices[j]
        #         vert = verts[vert_index]
                
        #         self.position_tex.write_pixel(
        #                      scanline_index, i*3+j,
        #                      vec3_to_rgba(vert.co))
              
        
        
        
        
        # 
        # numpy position implementation
        # 
        
        vert_idxs = numpy.empty(3 * len(mesh.loop_triangles))
        mesh.loop_triangles.foreach_get("vertices", vert_idxs)
        vert_idxs = vert_idxs.astype(numpy.int)
        
        # create 3 numpy arrays: xs, ys, and zs
        # each containing one component of position
        positions = numpy.empty(3 * len(mesh.vertices))
        mesh.vertices.foreach_get("co", positions)
        xs, ys, zs = positions.reshape((-1, 3)).T
        
        # index into each array using the vertex index array
        px = numpy.take(xs, vert_idxs)
        py = numpy.take(ys, vert_idxs)
        pz = numpy.take(zs, vert_idxs)
        
        # convert into proper linear form
        pa = numpy.ones(len(pz))
        
        position_pixels = numpy.array([px, py, pz, pa]).T.ravel()
        
        
        # If the amount of pixels to encode is greater than the amount that can fit on one scanline, then split the pixels up into multiple "batches"
        # 
        # ASSUME: the texture is sized s.t. it can fit a clean number of triangles in a single line, so you put a line break anywhere
        # ASSUME: normal data is encoded as split normals, so meshes can be split into arbitrary sub-meshes without distortion
        
        
        # print("position texture chunk size: ", chunk_size, flush=True)
        # print("pixel data size: ", position_pixels.size, flush=True)
        # print(position_pixels, flush=True)
        
        
        
        
        # 
        # reference
        # 
        
        # for i, tri in enumerate(mesh.loop_triangles): # triangles per mesh
        #     normals = tri.split_normals
        #     for j in range(3): # verts per triangle
        #         normal = normals[j]
                
        #         self.normal_tex.write_pixel(
        #                      scanline_index, i*3+j,
        #                      vec3_to_rgba(normal))
        
        
        
        # 
        # numpy
        # 
        
        # NOTE: Does not support split normals. If you want split normals, divide the mesh into separate parts
        # oh wait, if you don't have split normals, you can't do flat shading...
        # hmm that sucks.
        
        # create 3 numpy arrays: xs, ys, and zs
        # each containing one component of normal vector
        
        # normals = numpy.empty( (len(mesh.loop_triangles), 3,3) )
        # mesh.loop_triangles.foreach_get("split_normals", normals)
        
        normals = numpy.empty( 3*len(mesh.vertices) )
        mesh.vertices.foreach_get("normal", normals)
        
        xs, ys, zs = normals.reshape((-1, 3)).T
        
        # index into each array using the vertex index array
        nx = numpy.take(xs, vert_idxs)
        ny = numpy.take(ys, vert_idxs)
        nz = numpy.take(zs, vert_idxs)
        # nx = xs
        # ny = ys
        # nz = zs
        
        # convert into proper linear form
        na = numpy.ones(len(nz))
        
        norm_pixels = numpy.array([nx, ny, nz, na]).T.ravel()
        
        
        
        
        # 
        # write scanlines
        # 
        
        
        # TODO: just dump all the pixels in all at once
        # you don't need to split the mesh into chunks like this,
        # because then chunks will always be contiguous. (ASSUME)
        # As the memory for textures is just linear pixel memory (not 2D array)
        # you can just dump in all in there.
        # Still need to set the names in the mesh data cache.
        
        # NOTE: you should probably check to make sure there's enough free space in the texture so you don't run off the end of the array, but you don't need to split things up.
        
        # TODO: make sure to update the section with the normal texture too.
        
        
        # if self.position_tex.size != self.normal_tex.size:
        #     raise RuntimeError(f"Dimensions of normal position texture and normal texture are not the same for {mesh_name}. {repr(self.position_tex.size)} != {repr(self.normal_tex.size)}")
        
        channels_per_pixel = 4
        chunk_size = self.position_tex.width * channels_per_pixel
        empty_line = numpy.zeros(chunk_size)
        
        # the / operator in python always does float division
        # use // for int division
        num_chunks = math.ceil(position_pixels.size / chunk_size)
        
        # override the last incomplete line with blank data before writing
        offset = num_chunks-1
        self.position_tex.write_scanline(empty_line, scanline_index+offset)
        self.normal_tex.write_scanline(empty_line, scanline_index+offset)
        
        # write all data
        self.position_tex.write_scanline(position_pixels, scanline_index)
        self.normal_tex.write_scanline(norm_pixels, scanline_index)
        
        
        
        for i in range(num_chunks):
            if i == 0:
                # leave name unchanged for the first part
                # so that you can lookup the first part using the
                # name of the blender mesh
                name = mesh_name
            else:
                # change the name slightly for the additional mesh pieces
                name = mesh_name + ".part" + str(i+1)    
            self.mesh_data_cache[scanline_index+i] = name
            # ^ extend the cache to handle textures that span many lines
        
        
                
        
        
        
        self.position_tex.save()
        self.normal_tex.save()
        
        return num_chunks
    
    
    # Use the b channel in the first pixel like a pointer,
    # which indicates which row in the entity texture
    # should be used to determine the transform and material of this entity.
    # In this way, you create 2 linked entities
    # that move with the same transform.
    # 
    # ASSUME: must be called after set_entity_mesh()
    def set_entity_parent(self, entity_name, parent_entity_name):
        scanline_index = self.__entity_name_to_scanline(entity_name)
        parent_id      = self.__entity_name_to_scanline(parent_entity_name)
        
        self.__cache_entity_parent(scanline_index, parent_entity_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.entity_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.entity_tex.width
        
        
        # pixel_data = [mesh_id, mesh_id, parent_id, 1.0]
        
        # read out existing data, so you don't clobber mesh linkage
        pixel_data = self.entity_tex.read_pixel(scanline_index, 0)
        
        # set link on pixel data
        pixel_data[2] = parent_id
        # print(pixel_data, flush=True)
        
        # set pixel in scanline
        scanline_set_px(scanline_transform, 0, pixel_data)
        
        
        # 
        # clear transforms in scanline
        # 
        blank_pixel = vec4_to_rgba([0.0, 0.0, 0.0, 1.0])
        for i in range(1, 5): # range is exclusive of high end: [a, b)
            scanline_set_px(scanline_transform, i, blank_pixel,
                            channels=self.entity_tex.channels_per_pixel)
        
        # 
        # write scanline to texture
        # 
        
        self.entity_tex.write_scanline(scanline_transform, scanline_index)
        
        self.entity_tex.save()
    
    
    # Specify the mesh to use for a given entity @ t=0 (initial condition)
    # by setting the first pixel in the scanline to r=g=b="mesh scanline number"
    # (3 channels have the same data; helps with visualization of the texture)
    # This mapping will be changed by ruby code during game execution,
    # by dynamically editing the texture in memory. However, the texture
    # on disk will change if and only if the initial condition changes.
    # Raise exception if no mesh with the given name has been exported yet.
    # 
    # entity_name  : string
    # mesh_name : string ( must already be exported using export_mesh() )
    def set_entity_mesh(self, entity_name, mesh_name):
        scanline_index = self.__entity_name_to_scanline(entity_name)
        
        # 
        # write mesh id to scanline
        # 
        
        # error if mesh has not been exported yet
        if not self.has_mesh(mesh_name):
            raise RuntimeError(f"No mesh with the name {mesh_name} found. Make sure to export the mesh using export_mesh() before mapping the mesh to an entity.")
        
        print("mesh name:", mesh_name, flush=True)
        mesh_id = self.__mesh_name_to_scanline(mesh_name)
        
        pixel_data = [mesh_id, mesh_id, mesh_id, 1.0]
        
        
        self.__cache_entity_mesh_binding(scanline_index, mesh_name)
        
        
        # 
        # write scanline to texture
        # 
        
        self.entity_tex.write_pixel(scanline_index, 0,
                                    pixel_data)
        
        self.entity_tex.save()
    
    
    # Pack 4x4 transformation matrix for an entity into 4 pixels
    # of data in the entity texture.
    # 
    # entity_name  : string
    # transform : 4x4 transform matrix
    def set_entity_transform(self, entity_name, transform):
        scanline_index = self.__entity_name_to_scanline(entity_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.entity_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.entity_tex.width
        
        
        
        # 
        # write transforms to scanline
        # 
        for i in range(1, 5): # range is exclusive of high end: [a, b)
            scanline_set_px(scanline_transform, i, vec4_to_rgba(transform[i-1]),
                            channels=self.entity_tex.channels_per_pixel)
        
        # 
        # write scanline to texture
        # 
        
        self.entity_tex.write_scanline(scanline_transform, scanline_index)
        
        self.entity_tex.save()
    
    
    # Bind entity to a particular material,
    # and pack material data into 4 pixels in the entity texture.
    # 
    # entity_name : string
    # material : blender material datablock, containing RubyOF material
    def set_entity_material(self, entity_name, material):
        scanline_index = self.__entity_name_to_scanline(entity_name)
        
        
        # read out existing scanline data
        # so you don't clobber other properties on this line
        scanline_transform = self.entity_tex.read_scanline(scanline_index)
        # scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.entity_tex.width
        
        
        # 
        # write material properties to scanline
        # (if no material set, default to white)
        # 
        
        # color = c1 = c2 = c3 = c4 = alpha = None
        
        if material is None:
            # if no material specified
            # set magenta color to signify an error
            color = Color((1.0, 0.0, 1.0)) # (0,0,0)
            c1 = color
            c2 = color
            c3 = color
            c4 = color
            alpha = 1
            mat_name = "<ERROR - no material specified>"
        else:
            c1    = material.rb_mat.ambient
            c2    = material.rb_mat.diffuse
            c3    = material.rb_mat.specular
            c4    = material.rb_mat.emissive
            alpha = material.rb_mat.alpha
            mat_name = material.name
        
        scanline_set_px(scanline_transform, 5, vec3_to_rgba(c1),
                        channels=self.entity_tex.channels_per_pixel)
        
        diffuse = vec3_to_rgba(c2)
        diffuse[3] = alpha
        scanline_set_px(scanline_transform, 6, diffuse,
                        channels=self.entity_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                        channels=self.entity_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                        channels=self.entity_tex.channels_per_pixel)
        
        
        self.__cache_material_binding(scanline_index, mat_name)
        
        
        # 
        # write scanline to texture
        # 
        
        self.entity_tex.write_scanline(scanline_transform, scanline_index)
        
        self.entity_tex.save()
    
    
    # Update material properties for all entities that use the given material.
    # ( must have previously bound material using set_entity_material() )
    # 
    # material : blender material datablock, containing RubyOF material
    def update_material(self, material):
        # FIXME: may actually need the blender material block after all, because that may be where the names are stored
        
        
        # 1) traverse the cache to find all entities that use this material
        # 2) update all of those entities
        
        for data in self.entity_data_cache:
            if data['material name'] == material.name:
                self.set_entity_material(data['entity name'], material)
    
    
    # Remove entity from the transform texture.
    # 
    # Primitive garbage collection exists (see exporter -> gc)
    # but the main way to clear out unused mesh data
    # is to do a "clean build" of all data.
    # 
    # entity_name : string
    def delete_entity(self, entity_name):
        scanline_index = self.__entity_name_to_scanline(entity_name)
        
        
        # This time, you *want* to clobber the data,
        # so don't read what's currently in there.
        scanline_transform = [0.0, 0.0, 0.0, 1.0] * self.entity_tex.width
        
        
        # 
        # write to scanline to texture
        # 
        
        self.entity_tex.write_scanline(scanline_transform, scanline_index)
        
        self.entity_tex.save()
        
        # 
        # remove data from cache
        # 
        
        # clear entity data
        old_entity_data = self.entity_data_cache[scanline_index]
        
        self.entity_data_cache[scanline_index] = self.entity_data_schema.copy()
        
        # if the mesh attached to this entity is no longer being used,
        # then delete the mesh from the cache and from the texture
        count = 0
        for new_entity_data in self.entity_data_cache:
            if new_entity_data['mesh name'] == old_entity_data['mesh name']:
                count += 1
        
        if count == 0:
            i = self.__mesh_name_to_scanline(old_entity_data['mesh name'])
            self.mesh_data_cache[i] = None
            
            # NOTE: this may be slow for large textures
            
            # NOTE: don't necessariy need to override old data - can just leave garbage in there - garbage should be overridden by new data when new data is written
            
            # scanline_position = [0.2, 0.2, 0.2, 1.0] * 10
            # scanline_normals  = [0.0, 0.0, 0.0, 1.0] * 10
            
            # self.position_tex.write_scanline(scanline_position, i)
            # self.normal_tex.write_scanline(scanline_normals, i)
            
            # self.position_tex.save()
            # self.normal_tex.save()
        
        
        
        # save new JSON file
        self.save()
        
        
        # recursively delete all entities that declare this one as a parent
        for data in self.entity_data_cache:
            if data['parent'] == entity_name:
                self.delete_entity(data['entity name'])
        
    
    
    # Return list of all entity names
    # (same data as what gets saved to JSON file)
    def get_entity_names(self):
        out = list()
        
        for data in self.entity_data_cache:
            if data['entity name'] is not None:
                out.append(data['entity name'])
        
        return out
    
    # Return list of names of all entity parents.
    # These are the entites that control when entities are GCed.
    # Entities with no true parent have their own name in the 'parent' field.
    def get_entity_parent_names(self):
        out = list()
        
        for data in self.entity_data_cache:
            if data['parent'] is not None:
                out.append(data['parent'])
        
        return out
    
    
    
    def get_json_path(self):
        return self.json_filepath
    
    def get_texture_paths(self):
        return (self.position_tex.filepath,
                self.normal_tex.filepath,
                self.entity_tex.filepath)
    
    # 
    # serialization
    # 
    
    def save(self):
        data = {
            'mesh_data_cache': self.mesh_data_cache,
            'entity_data_cache': self.entity_data_cache
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
        
    def load(self):
        if os.path.isfile(self.json_filepath):
            with open(self.json_filepath, 'r') as f:
                data = json.load(f)
                
                print(data)
                sys.stdout.flush()
                
                self.mesh_data_cache   = data['mesh_data_cache']
                self.entity_data_cache = data['entity_data_cache']
    
    
    
    # 
    # undo / redo callbacks
    # 
    
    
    def on_undo(self, scene):
        self.__wrap_textures(scene, self.name, self.output_dir)
    
    def on_redo(self, scene):
        self.__wrap_textures(scene, self.name, self.output_dir)
    
 

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

