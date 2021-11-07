from utilities import *
from class_reloader import reload_class
from coroutine_decorator import *


from image_wrapper import ( ImageWrapper, get_cached_image )

ImageWrapper = reload_class(ImageWrapper)


from mathutils import Color
import time
import queue
import functools
import json



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
        
        self.max_tris = mytool.max_tris
        
        
        
        # (maybe want to generate index / reverse index on init? not sure how yet.)
        # TODO: figure out how to generate index on init, so initial texture export on render startup is not necessary
        self.vertex_data    = []
        self.transform_data = []
    
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
        
        scanline_set_px(scanline_transform, 5, vec3_to_rgba(c1) + [alpha],
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 6, vec3_to_rgba(c2),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                        channels=self.transform_tex.channels_per_pixel)
        
        scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                        channels=self.transform_tex.channels_per_pixel)
        
        self.transform_tex.write_scanline(scanline_transform, scanline)
        
        
        self.transform_tex.save()
    
    
    
    
    
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
        
        
        
        transform_data = [
            [None, None],
            [mesh_obj_name, first_material]
                # => 'name: .name'
        ]
        # need a pointer to the original object, so we can still ID the thing even if the name has been changed
        
        # ^ depsgraph can tell you if the transform has changed, so you don't necessarily need to store a copy of the mat4 here
        
        # ^ need a pointer to the mat, s.t. when the material is changed, it can identify the rows of the texture that need updating
        
        
        
        objName_to_transformID = {
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
            self.vertex_data.append( data )
        
        
        # update reverse index
        self.meshDatablock_to_meshID = {}
        
        for i, data in enumerate(self.vertex_data):
            datablock_name = data
            
            self.meshDatablock_to_meshID[datablock_name] = i
        
    
    # find via name
    # Find target mesh object and retrieve it's index.
    def transform_data_index(self, mesh_obj_name):
        target_obj_index = None
        
        # print(self.transform_data)
        for i, data in enumerate(self.transform_data):
            obj_name, material = data
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
        
        data = [mesh_obj.name, first_material(mesh_obj)] 
        
        # if a corresponding object already exists in the cache,
        # update the cache
        target_obj_index = self.transform_data_index(mesh_obj.name)
        if target_obj_index is not None:
            self.transform_data[target_obj_index] = data
        # else, add new data to the cache
        else:
            self.transform_data.append( data )
        
        
        # update the reverse index
        self.objName_to_transformID = {}
        
        for i, data in enumerate(self.transform_data):
            obj_name, material = data
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
        

    
    
    
    # 
    # main public interface
    # (mostly callbacks that get run by key operators)
    # 
    
    
    # TODO: when do I set context / scene? is setting on init appropriate? when do those values get invalidated?
    
    # yields percentage of task completion, for use with a progress bar
    @coroutine
    def export_all_textures(self):
        
        yield(0) # initial yield to just set things up
        
        # 'context' is recieved via the first yield,
        # rather than a standard argument.
        #  This is passed via the class defined in progress_bar.py
        context = yield(0)
        
        
        t0 = time.time()
        
        
        
        self.vertex_data    = []
        self.transform_data = []
        
        
        mytool = context.scene.my_tool
        
        
        mytool.status_message = "eval dependencies"
        depsgraph = context.evaluated_depsgraph_get()
        context = yield(0.0)
        
        
        # collect up all the objects to export
        
        # for each object find the associated mesh datablock
        # reduce to the objects with unique mesh datablocks
        # generate evaluated meshes for those objects
        # create mapping of obj -> evaulated mesh
        
        # create mapping of evaluated mesh -> scanline index
        # export evaluated meshes to file
        
        # for each object
            # map object -> mesh -> mesh scanline index
            # export object transform with mesh_id= mesh scanline index
        
        
        
        
        all_objects = mytool.collection_ptr.all_objects
        
        
        all_mesh_objects = [ obj
                             for obj in mytool.collection_ptr.all_objects
                             if obj.type == 'MESH' ]
        
        num_objects = len(all_mesh_objects)
        if num_objects > mytool.max_num_objects:
            raise RuntimeError(f'Trying to export {num_objects} objects, but only have room for {mytool.max_num_objects} in the texture. Please increase the size of the transform texture.')
        
        
        # 
        # create a list of unique evaluated meshes
        # AND
        # map mesh datablock -> mesh id
        # so object transfoms and mesh ID can be paired up in transform export
        mytool.status_message = "collect mesh data"
        
        # don't need (obj -> mesh datablock) mapping
        # as each object already knows its mesh datablock
        
        
        unique_pairs = find_unique_mesh_pairs(all_mesh_objects)
        mesh_objects    = [ obj       for obj, datablock in unique_pairs ]
        mesh_datablocks = [ datablock for obj, datablock in unique_pairs ]
        
        self.meshDatablock_to_meshID = { mesh.name : i+1
                                         for i, mesh
                                         in enumerate(mesh_datablocks) }
        
        unqiue_meshes = [ obj.evaluated_get(depsgraph).data
                          for obj in mesh_objects ]
        
        # NOTE: If two objects use the same mesh datablock, but have different modifiers, their final meshes could be different. in this case, we ought to export two meshes to the texture. However, I think the current methodology would only export one mesh. In particular, the mesh that appears first in the collection list would have priority.
            # ^ may just ignore this for now. Although blender supports this workflow, I'm not sure that I personally want to use it.
        
        # unique_datablocks = list(set( [ x.data for x in all_mesh_objects ] )) 
        # # ^ will change the order of the data, which is bad
        
        context = yield( 0.0 )
        
        
        
        # 
        # calculate how many tasks there are
        # 
        
        total_tasks = len(unqiue_meshes) + len(all_mesh_objects)
        task_count = 0
        
        context = yield( 0.0 )
        
        # 
        # export all unique meshes
        # 
        
        self.vertex_data = [ None ]
        
        mytool.status_message = "export unique meshes"
        for i, mesh in enumerate(unqiue_meshes):
            self.export_vertex_data(mesh, i+1)
                # NOTE: This index 'i+1' ends up always being the same as the indicies in self.meshDatablock_to_meshID. Need to do it this way because at this stage, we only have the exportable final meshes, not the orignial mesh datablocks.
            
            self.vertex_data.append( mesh.name )
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        # 
        # export all objects
        # (transforms and associated mesh IDs)
        # 
        
        self.transform_data = [ [None, None] ]
        
        for i, obj in enumerate(all_mesh_objects):
            # use mapping: obj -> mesh datablock -> mesh ID
            self.export_transform_data(
                obj,
                scanline=i+1,
                mesh_id=self.meshDatablock_to_meshID[obj.data.name]
            )
            
            task_count += 1
            
            self.transform_data.append( [obj.name, first_material(obj)] )
            
            context = yield(task_count / total_tasks)
        
        
        # 
        # get name of object -> mesh id mapping
        # 
        
        mytool.status_message = "show object map"
        
        # create map: obj name -> transform ID
        object_map = { obj.name : i+1
                       for i, obj in enumerate(all_mesh_objects)
                       if obj.type == 'MESH' }
        
        self.objName_to_transformID = object_map
        
        # send mapping to RubyOF
        data = {
            'type': 'object_to_id_map',
            'value': self.objName_to_transformID,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        context = yield( task_count / total_tasks )
        
        
        # 
        # let RubyOF know that new animation textures have been exported
        # 
        
        data = {
            'type': 'anim_texture_update',
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        context = yield(task_count / total_tasks)
        
        t1 = time.time()
        
        print("time elapsed:", t1-t0, "sec")
        
    
    
    
    # update data that would have been sent in pack_mesh():
    # so, the transform and what datablock the object is linked to
    
    # TODO: how do you handle objects that get renamed? is there some other unique identifier that is saved across sessions? (I think names in Blender are actually unique, but Blender works hard to make that happen...)
    def update_mesh_object(self, update, mesh_obj):
        if update.is_updated_transform:
            if hasattr(self, 'transform_data'):
                # find existing position in transform texture (if any)
                target_obj_index = self.transform_data_index(mesh_obj.name)
                
                if target_obj_index is not None:
                    # 
                    # update already existing object to have a new transform
                    # 
                    self.export_transform_data(
                        mesh_obj,
                        scanline=target_obj_index,
                        mesh_id=self.meshDatablock_to_meshID[mesh_obj.data.name]
                    )
                    # ^ will update transform, associated mesh, and material data
                    # TODO: split out material data into a separate method
                    
                    
                    # Don't need to update the cache.
                    # This object already exists in the cache, so it's fine.
                    self.cache_transform_data(mesh_obj)
                    
                    print("moved object")
                else:
                    # 
                    # No object has existed in texture before
                    # but there was an update to the transform?
                    # 
                    # must be a new object!
                    # 
                    print("NO OBJECT FOUND")
                    
                    # 
                    # create new mesh datablock if necessary
                    # 
                    datablock_index = self.vertex_data_index(mesh_obj.data.name)
                    if datablock_index is None:
                        # write to texture
                        i = len(self.vertex_data)
                        self.export_vertex_data(mesh_obj.data, i)
                        
                        # update cache
                        self.cache_vertex_data( mesh_obj.data )
                    
                    # 
                    # link the new mesh object to the correct datablock
                    # 
                    
                    self.export_transform_data(
                        mesh_obj,
                        scanline=len(self.transform_data),
                        mesh_id=self.meshDatablock_to_meshID[mesh_obj.data.name]
                    )
                    
                    self.cache_transform_data(mesh_obj)
                
                
                # TODO: create a separate update message type for when transforms update
                # TODO: only send update message once per frame, not every frame
                    # actually, this might still get slow to go through the disk like this... may want to just send a JSON message with the mat4 data in memory to update the live scene, but also update the changed scene on disk so that when it does eventually be reloaded from disk, that version is good too - no need to do a full export again.
                
                print("send update message")
                
                data = {
                    'type': 'geometry_update',
                    'position_tex_path' : self.position_tex.filepath,
                    'normal_tex_path'   : self.normal_tex.filepath,
                    'transform_tex_path': self.transform_tex.filepath,
                }
                
                self.to_ruby.write(json.dumps(data))
                
                
            else:
                print("no transform")
        
        
        # You won't get a message from depsgraph about a material being changed
        # until the object you're inspecting is the material.
        # Thus, you need to deal with the denormalization / update
        # of the material, in the material, and not here in the mesh.
        
        
    
    # NOTE: No good way right now to "garbage collect" unused mesh datablocks that continue to be in the animation texture. Maybe we can store resource counts in the first pixel?? But for right now, doing a clean build is the only way to clear out some old data.
    
        # if not, I can have some update function here
        # which is called every frame / every update,
        # and which compares the current list of objects to the previous list.
        # The difference set between these two
        # would tell you what objects were deleted.
        
        # (This is the technique I've already been using to parse deletion, but it happened at the Ruby level, after I recieved the entity list from Python.)
        
    
    # callback for right after deletion 
    def post_mesh_object_deletion(self, obj_name): 
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
                'type': 'anim_texture_update',
                'position_tex_path' : self.position_tex.filepath,
                'normal_tex_path'   : self.normal_tex.filepath,
                'transform_tex_path': self.transform_tex.filepath,
            }
            
            self.to_ruby.write(json.dumps(data))
            
            print("delete complete")
        
        
    
    
    # run this while mesh is being edited
    # (precondition: datablock already exists)
    def update_mesh_datablock(self, active_object):
        print("transform data:", self.transform_data)
        # re-export this mesh in the anim texture (one line) and send a signal to RubyOF to reload the texture
        
        mesh = active_object.data
        self.export_vertex_data(mesh, self.meshDatablock_to_meshID[mesh.name])
        
        # (this will force reload of all textures, which may not be ideal for load times. but this will at least allow for prototyping)
        data = {
            'type': 'geometry_update',
            'scanline': self.meshDatablock_to_meshID[mesh.name],
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
    
    
    # note: in blender, one object can have many material slots, but this exporter only considers the first material slot, at least for now
    
    
    
    
    # TODO: consider removing 'context' from this function, somehow
    
    # repack for all entities that use this material
    # (like denormalising two database tables)
    # transform with color info          material color info
    def update_material(self, context, updated_material):
        print("updating material...")
        
        mytool = context.scene.my_tool
        
        # don't need this (not writing to the variable)
        # but it helps to remember the scope of globals
        
        
        all_mesh_objects = [ obj
                             for obj in mytool.collection_ptr.all_objects
                             if obj.type == 'MESH' ]
        
        
        obj_and_material_pairs = [ (obj, obj.material_slots[0].material)
                                   for obj in all_mesh_objects
                                   if len(obj.material_slots) > 0 ]
        
        
        # need to update the pixels in the transform texture
        # that encode the color, but want to keep the other pixels the same.
        # Thus, set individual pixels, rather than the entire scanline.
        
        texture = self.transform_tex
        
        for obj, bound_material in obj_and_material_pairs:
            # print(bound_material, updated_material)
            # print(bound_material.name, updated_material.name)
            if bound_material.name == updated_material.name:
                i = self.transform_data_index(obj.name)
                print("mesh index:",i)
                
                if i is not None:
                    row = i
                    col = 5
                    
                    mat = updated_material.rb_mat
                    
                    texture.write_pixel(row,col+0, vec3_to_rgba(mat.ambient))
                    
                    diffuse_with_alpha = vec3_to_rgba(mat.diffuse) + [mat.alpha]
                    texture.write_pixel(row,col+1, diffuse_with_alpha)
                    
                    texture.write_pixel(row,col+2, vec3_to_rgba(mat.specular))
                    texture.write_pixel(row,col+3, vec3_to_rgba(mat.emissive))
        
        texture.save()
        
        data = {
            'type': 'material_update',
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
 
 

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

