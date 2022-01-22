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



def find_unique_mesh_pairs(all_mesh_objects):
    """Given a list of mesh objects, return
       all pairs (mesh_object, mesh_datablock)
       such that each mesh_datablock is unique"""
    
    unique_mesh_datablocks = set()
    unique_pairs = []
    
    for obj in all_mesh_objects:
        if obj.data in unique_mesh_datablocks:
            pass
        else:
            unique_mesh_datablocks.add(obj.data)
            unique_pairs.append( (obj, obj.data) )
    
    return unique_pairs



# scanline : array of pixel data (not nested array, just a flat array)
# Set the data for one pixel within an array representing a whole scanline
def scanline_set_px(scanline, px_i, px_data, channels=4):
    for i in range(channels):
        scanline[px_i*channels+i] = px_data[i]



def first_material(mesh_object):
    mat_slots = mesh_object.material_slots
    
    # color = c1 = c2 = c3 = c4 = alpha = None
    
    if len(mat_slots) > 0:
        mat = mat_slots[0].material
        
    else:
        mat = bpy.data.materials['Material']
    
    return mat
    




class AnimTexManager ():
    # 
    # setup data
    # 
    def __init__(self, context, to_ruby_fifo):
        self.to_ruby = to_ruby_fifo
        
        mytool = context.scene.my_tool
        
        
        self.__wrap_textures(mytool)
        
        
        self.max_tris = mytool.max_tris
        
        # data for export_mesh()
        self.next_mesh_scanline = 1
        self.mesh_name_to_scanline = {}
        
        # data for set_object_transform()
        self.next_object_scanline = 1
        self.object_name_to_scanline = {}
        
        
        # (maybe want to generate index / reverse index on init? not sure how yet.)
        self.vertex_data    = []
        self.transform_data = []
        
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
    
    
    
    
    
    
    # 
    # write a single row of the texture
    # 
    
    # handles triangulation
    def export_vertex_data(self, mesh, output_frame):
        mesh.calc_loop_triangles()
        # ^ need to call this to populate the mesh.loop_triangles() cache
        
        mesh.calc_normals_split()
        # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
        # ^ normals stored on the tri / face
        
        
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        # NOTE: all textures in the same animation set have the same dimensions
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)
        
        # data for just this object
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.position_tex.width
        
        self.position_tex.write_scanline(pixel_data, 0)
        
        
        
        # 
        # allocate pixel data buffers for mesh
        # 
        
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
        
        self.position_tex.write_scanline(scanline_position, output_frame)
        self.normal_tex.write_scanline(scanline_normals, output_frame)
        
        
        self.position_tex.save()
        self.normal_tex.save()
    
    
    def export_transform_data(self, target_object, scanline=1, mesh_id=1):
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)        
        pixel_data = [1.0, 0.0, 1.0, 1.0] * self.transform_tex.width
        self.transform_tex.write_scanline(pixel_data, 0)
        
        
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
        # write transforms to image
        # 
        
        scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        
        id = mesh_id # TODO: update this to match mesh index
        
        scanline_set_px(scanline_transform, 0, [id, id, id, 1.0],
                        channels=self.transform_tex.channels_per_pixel)
        
        for i in range(1, 5): # range is exclusive of high end: [a, b)
            scanline_set_px(scanline_transform, i, vec4_to_rgba(out_mat[i-1]),
                            channels=self.transform_tex.channels_per_pixel)
        
        
        # 
        # set color (if no material set, default to white)
        # 
        
        
        mat_slots = target_object.material_slots
        
        # color = c1 = c2 = c3 = c4 = alpha = None
        
        if len(mat_slots) > 0:
            mat = mat_slots[0].material.rb_mat
            c1 = mat.ambient
            c2 = mat.diffuse
            c3 = mat.specular
            c4 = mat.emissive
            alpha = mat.alpha
        else:
            color = Color((1.0, 1.0, 1.0)) # (0,0,0)
            c1 = color
            c2 = color
            c3 = color
            c4 = color
            alpha = 1
            # default white for unspecified color
            # (ideally would copy this from the default in materials)
        
        scanline_set_px(scanline_transform, 5, vec3_to_rgba(c1),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 6, vec3_to_rgba(c2)+ [alpha],
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                        channels=self.transform_tex.channels_per_pixel)
        
        self.transform_tex.write_scanline(scanline_transform, scanline)
        
        
        self.transform_tex.save()
    
    
    
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
    
    
    # notes
    # ---
    # mesh object name -> scanline index in vertex data texture
        # ^ data structure must manage serialization to/from a JSON file
    
    # (one mesh datablock may result in many exported meshes, because you need one line in the output texture per frame of animation. how do I distinguish between different frames of animation?)
    # does the data format need to know about animation? or does it fundamentally only care about transforms and meshes? may be able to move this part of the API into another class / file / whatever.
    
    
    
    
    
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
    
    
    
    
    
    
    # Does a mesh with with name exist in the texture?
    # (more important on the ruby side, but also helpful to optimize export)
    # 
    # mesh_name : string
    def has_mesh(mesh_name):
        pass
    
    
    # Write mesh data to texture.
    # Each scanline of the texture encodes one mesh.
    # The scanline to use will be calculated automatically.
    # Must update some mapping of "mesh name" => "mesh data"
    # ( mapping also used by has_mesh() )
    # 
    # mesh_name : string
    # mesh      : mesh datablock
    def export_mesh(mesh_name, mesh):
        mesh.calc_loop_triangles()
        # ^ need to call this to populate the mesh.loop_triangles() cache
        
        mesh.calc_normals_split()
        # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
        # ^ normals stored on the tri / face
        
        
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        # NOTE: all textures in the same animation set have the same dimensions
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)
        
        # data for just this object
        pixel_data = [1.0, 0.0, 0.0, 1.0] * self.position_tex.width
        
        self.position_tex.write_scanline(pixel_data, 0)
        
        
        
        # 
        # allocate pixel data buffers for mesh
        # 
        
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
        if mesh_name not in self.mesh_name_to_scanline:
            # assign new scanline index to this 
            self.mesh_name_to_scanline[mesh_name] = self.next_mesh_scanline
            self.next_mesh_scanline += 1
        
        output_frame = self.mesh_name_to_scanline[mesh_name]
        
        self.position_tex.write_scanline(scanline_position, output_frame)
        self.normal_tex.write_scanline(scanline_normals, output_frame)
        
        
        self.position_tex.save()
        self.normal_tex.save()
    
    
    # Specify the mesh to use for a given object @ t=0 (initial condition).
    # This mapping will be changed by ruby code during game execution,
    # by dynamically editing the texture in memory. However, the texture
    # on disk will change if and only if the initial condition changes.
    # Raise exception if no mesh with the given name has been exported yet.
    # 
    # obj_name  : string
    # mesh_name : string ( must already be exported using export_mesh() )
    def set_object_mesh(obj_name, mesh_name):
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)        
        pixel_data = [1.0, 0.0, 1.0, 1.0] * self.transform_tex.width
        self.transform_tex.write_scanline(pixel_data, 0)
        
        
        
        # 
        # what scanline to save to?
        # 
        if obj_name not in self.object_name_to_scanline:
            self.object_name_to_scanline[obj_name] = self.next_object_scanline
            self.next_object_scanline += 1
        
        scanline_index = self.object_name_to_scanline[obj_name]
        
        
        # 
        # write mesh id to scanline
        # 
        
        # TODO: read out existing scanline so you don't clobber other properties on this line
        scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        mesh_id = self.mesh_name_to_scanline[mesh_name]
        # ^ TODO: need some sort of error if the mesh has not been exported yet
        # mesh exporting is handled in export_mesh()
        
        scanline_set_px(scanline_transform, 0, [mesh_id, mesh_id, mesh_id, 1.0],
                        channels=self.transform_tex.channels_per_pixel)
        
        
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
    def set_object_transform(obj_name, transform):
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)        
        pixel_data = [1.0, 0.0, 1.0, 1.0] * self.transform_tex.width
        self.transform_tex.write_scanline(pixel_data, 0)
        
        
        
        # 
        # what scanline to save to?
        # 
        if obj_name not in self.object_name_to_scanline:
            self.object_name_to_scanline[obj_name] = self.next_object_scanline
            self.next_object_scanline += 1
        
        scanline_index = self.object_name_to_scanline[obj_name]
        
        
        # 
        # write transforms to scanline
        # 
        
        # TODO: read out existing scanline so you don't clobber other properties on this line
        scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        for i in range(1, 5): # range is exclusive of high end: [a, b)
            scanline_set_px(scanline_transform, i, vec4_to_rgba(transform[i-1]),
                            channels=self.transform_tex.channels_per_pixel)
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
    
    
    # Pack material data into 4 pixels
    # in the object transform texture
    # 
    # obj_name : string
    # material : RubyOF material datablock (custom data, not blender material)
    def set_object_material(obj_name, material):
        # TODO: update all code to use RGB (no alpha) to save some memory
        # TODO: use half instead of float to save memory
        
        
        # (bottom row of pixels will always be full red)
        # This allows for the easy identification of one edge,
        # like a "this side up" sign, but it also allows for
        # the user to create frames completely free of any
        # visible geometry. (useful with GPU instancing)        
        pixel_data = [1.0, 0.0, 1.0, 1.0] * self.transform_tex.width
        self.transform_tex.write_scanline(pixel_data, 0)
        
        
        
        # 
        # what scanline to save to?
        # 
        if obj_name not in self.object_name_to_scanline:
            self.object_name_to_scanline[obj_name] = self.next_object_scanline
            self.next_object_scanline += 1
        
        scanline_index = self.object_name_to_scanline[obj_name]
        
        
        # 
        # write material properties to scanline
        # (if no material set, default to white)
        # 
        
        # TODO: read out existing scanline so you don't clobber other properties on this line
        scanline_transform = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
        
        
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
            c1    = material.ambient
            c2    = material.diffuse
            c3    = material.specular
            c4    = material.emissive
            alpha = material.alpha
        
        scanline_set_px(scanline_transform, 5, vec3_to_rgba(c1),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 6, vec3_to_rgba(c2)+ [alpha],
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                        channels=self.transform_tex.channels_per_pixel)
        
        
        # 
        # write to scanline to texture
        # 
        
        self.transform_tex.write_scanline(scanline_transform, scanline_index)
        
        self.transform_tex.save()
    
    
    # Update material for all objects that use it.
    # 
    # material : RubyOF material datablock (custom data, not blender material)
    def set_material(material):
        pass
    
    
    
    
    
    # 
    # manipulate cache for data in the textures
    # 
    
    # This method should never actually be called.
    # I just want a space to sketch out the schema
    # of the cache and get syntax highlighting.
    def __cache_schema(self):
        # Don't store names in the lists - if you need to hang on to an object in Python, use a pointer to the object instead. Only need to pass names to Ruby so that the game can acquire the pointers in the first place. This aquisition phase is like how the user can pick an item by name from Blender's outliner.
        
        self.vertex_data = [
            None,
            datablock_name # => 'datablock_name: .data.name'
        ]
        # need a pointer to the original object, so we can still ID the thing even if the name has been changed
        
        
        
        self.transform_data = [
            [None, None],
            [mesh_obj_name, first_material.name]
                # => 'name: .name'
        ]
        # need a pointer to the original object, so we can still ID the thing even if the name has been changed
        
        # ^ depsgraph can tell you if the transform has changed, so you don't necessarily need to store a copy of the mat4 here
        
        # ^ need a pointer to the mat, s.t. when the material is changed, it can identify the rows of the texture that need updating
        
        
        
        self.objName_to_transformID = {
            'name: .name' : transformID
        }
        # transformID == index of corresponding data in transform_data
        # (reverse index used by Ruby game code to select objects by name)
        
        
        self.meshDatablock_to_meshID = {
            'name: .data.name' : meshID
        }
        # meshID == index of corresponding data in self.vertex_data
        # (reverse index used by Python exporter code to only export unique meshes)
        # ^ this is the reverse index of self.vertex_data
        #   you can generate it by walking self.vertex_data
    
    
    # find via name
    def vertex_data_index(self, meshObj_data_name):
        target_datablock_index = None
        
        for i, data in enumerate(self.vertex_data):
            datablock_name = data
            if datablock_name is None:
                continue
            
            if datablock_name == meshObj_data_name:
                target_datablock_index = i
        
        return target_datablock_index
    
    # store via datablock object
    def cache_vertex_data(self, meshObj_data):
        data = meshObj_data.name
        
        
        # if a corresponding object already exists in the cache,
        # update the cache
        target_obj_index = self.vertex_data_index(meshObj_data.name)
        if target_obj_index is not None:
            self.vertex_data[target_obj_index] = data
        # else, add new data to the cache
        else:
            target_obj_index = len(self.vertex_data)
            self.vertex_data.append( data )
        
        
        # update reverse index
        self.meshDatablock_to_meshID = {}
        
        for i, data in enumerate(self.vertex_data):
            datablock_name = data
            
            self.meshDatablock_to_meshID[datablock_name] = i
        
        
        return target_obj_index
        
    
    # find via name
    # Find target mesh object and retrieve it's index.
    def transform_data_index(self, mesh_obj_name):
        target_obj_index = None
        
        # print(self.transform_data)
        for i, data in enumerate(self.transform_data):
            obj_name, material_name = data
            if obj_name is None:
                continue
            
            if obj_name == mesh_obj_name:
                target_obj_index = i
        
        return target_obj_index
    
    
    # store via mesh object
    # PROBLEM: when exporting the entire texture, self.transform_data is populated using the normal mesh objects. but when updating the cache, we're looking at / comparing with objects from the depsgraph. I think the depsgraph objects are not as permanent, which is causing errors when I try to access RNA data that has been invalidated.
        # or maybe GC is just being weird to me? not sure, needs more testing
    def cache_transform_data(self, mesh_obj):
        # print("new data:", [mesh_obj, first_material(mesh_obj)] )
        
        data = [ mesh_obj.name, first_material(mesh_obj).name ] 
        
        # if a corresponding object already exists in the cache,
        # update the cache
        target_obj_index = self.transform_data_index(mesh_obj.name)
        if target_obj_index is not None:
            self.transform_data[target_obj_index] = data
        # else, add new data to the cache
        else:
            target_obj_index = len(self.transform_data)
            self.transform_data.append( data )
        
        
        # update the reverse index
        self.objName_to_transformID = {}
        
        for i, data in enumerate(self.transform_data):
            obj_name, material_name = data
            if obj_name is None:
                continue
            
            self.objName_to_transformID[obj_name] = i
            
            
        # TODO: When should this data be set to Ruby land? Is this a good time / place to do that?
        
        # send mapping to RubyOF
        data = {
            'type': 'object_to_id_map',
            'value': self.objName_to_transformID,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        # need mesh datablock -> meshID to update the vertex data,
        # but for spatial queries in Ruby you need
        # to map point in space -> mesh name
        
        # point in space -> transformID
        # transformID -> meshID
        # meshID -> mesh name
        
        # so you need a meshID_to_meshDatablock mapping
        # which is the reverse of what we currently have.
        
        # But meshID_to_meshDatablock is already the reverse index of self.vertex_data, so just send that instead
        
        data = {
            'type': 'meshID_to_meshName',
            'value': self.vertex_data,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        return target_obj_index
        
        

    
        
        
    
    # NOTE: No good way right now to "garbage collect" unused mesh datablocks that continue to be in the animation texture. Maybe we can store resource counts in the first pixel?? But for right now, doing a clean build is the only way to clear out some old data.
    
        # if not, I can have some update function here
        # which is called every frame / every update,
        # and which compares the current list of objects to the previous list.
        # The difference set between these two
        # would tell you what objects were deleted.
        
        # (This is the technique I've already been using to parse deletion, but it happened at the Ruby level, after I recieved the entity list from Python.)
    
    
    # PRECONDITION: assumes that self.transform_data cache is populated
    
    # callback for right after deletion 
    def delete_mesh_object(self, obj_name): 
        print("object", obj_name, "was deleted")
        
        
        i = self.transform_data_index(obj_name)
        
        print(i)
        
        if i is not None:
            print("deleting...")
            # delete the data
            pixel_data = [0.0, 0.0, 0.0, 0.0] * self.transform_tex.width
            self.transform_tex.write_scanline(pixel_data, i)
            self.transform_tex.save()
            
            # tell Ruby to update
            data = {
                'type': 'update_transform',
                'position_tex_path' : self.position_tex.filepath,
                'normal_tex_path'   : self.normal_tex.filepath,
                'transform_tex_path': self.transform_tex.filepath,
            }
            
            self.to_ruby.write(json.dumps(data))
            
            print("delete complete")
        
        
    
    
    # run this while mesh is being edited
    # (precondition: datablock already exists)
    def edit_mesh_data(self, active_object):
        # print("transform data:", self.transform_data)
        # re-export this mesh in the anim texture (one line) and send a signal to RubyOF to reload the texture
        
        mesh_data = active_object.data
        
        # update cache
        i = self.cache_vertex_data( mesh_data )
        
        # write to texture
        self.export_vertex_data(mesh_data, i)
        
        # (this will force reload of all textures, which may not be ideal for load times. but this will at least allow for prototyping)
        data = {
            'type': 'update_geometry',
            'scanline': i,
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
    
    
    # note: in blender, one object can have many material slots, but this exporter only considers the first material slot, at least for now
    
    
    
    
    def update_armature_object(self, update, armature_obj):
        pass
    
    
    
    # PRECONDITION: assumes that self.transform_data cache is populated
    
    # TODO: consider removing 'context' from this function, somehow
    
    # repack for all entities that use this material
    # (like denormalising two database tables)
    # transform with color info          material color info
    def update_material(self, context, updated_material):
        print("updating material...")
        
        mytool = context.scene.my_tool
        
        
        # need to update the pixels in the transform texture
        # that encode the color, but want to keep the other pixels the same.
        # Thus, set individual pixels, rather than the entire scanline.
        
        texture = self.transform_tex
        
        for i, data in enumerate(self.transform_data):
            obj_name, material_name = data
            
            if material_name == updated_material.name:
                print("transform index:",i)
                row = i
                col = 5
                
                mat = updated_material.rb_mat
                
                texture.write_pixel(row, col+0,
                                    vec3_to_rgba(mat.ambient))
                texture.write_pixel(row, col+1, 
                                    vec3_to_rgba(mat.diffuse) + [mat.alpha])
                texture.write_pixel(row, col+2,
                                    vec3_to_rgba(mat.specular))
                texture.write_pixel(row, col+3,
                                    vec3_to_rgba(mat.emissive))
        
        texture.save()
        
        data = {
            'type': 'update_material',
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
    
    
    
    # 
    # serialization
    # 
    
    def on_save(self):
        data = {
            'vertex_data': self.vertex_data,
            'transform_data': self.transform_data,
            'objName_to_transformID' : self.objName_to_transformID,
            'meshDatablock_to_meshID' : self.meshDatablock_to_meshID
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
                
                self.vertex_data    = data['vertex_data']
                self.transform_data = data['transform_data']
                self.objName_to_transformID = data['objName_to_transformID']
                self.meshDatablock_to_meshID = data['meshDatablock_to_meshID']
    
    
    
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

