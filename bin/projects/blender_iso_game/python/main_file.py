bl_info = {
    "name": "RubyOF renderer engine",
    "author": "Jason Ko",
    "version": (0, 0, 3),
    "blender": (2, 90, 1),
    "location": "Render",
    "description": "Integration with external real-time RubyOF renderer for games, etc",
    "category": "Render",
}

import json
import base64
import struct

import os
import fcntl
import posix

import os.path

import bpy
import bgl

import bpy_extras
import bpy_extras.view3d_utils

from bpy.props import (StringProperty,
                       BoolProperty,
                       IntProperty,
                       FloatProperty,
                       EnumProperty,
                       FloatVectorProperty,
                       PointerProperty)

from mathutils import Color

import time

import queue
import threading


import hashlib

import math



# need extra help to reload classes:
# https://developer.blender.org/T66924
# by gecko man (geckoman), Jul 22 2019, 9:02 PM

import importlib, sys
# reloads class' parent module and returns updated class
def reload_class(c):
    mod = sys.modules.get(c.__module__)
    importlib.reload(mod)
    return mod.__dict__[c.__name__]










# ------------------------------------------------------------------------
#   utility functions
# ------------------------------------------------------------------------

def vec3_to_rgba(vec):
    # allocate data for one pixel (RGBA)
    px = [0.0, 0.0, 0.0, 1.0]
    
    px[0] = vec[0]
    px[1] = vec[1]
    px[2] = vec[2]
    # no data to put in alpha channel
    
    return px

def vec4_to_rgba(vec):
    # allocate data for one pixel (RGBA)
    px = [0.0, 0.0, 0.0, 1.0]
    
    px[0] = vec[0]
    px[1] = vec[1]
    px[2] = vec[2]
    px[3] = vec[3]
    
    return px


















# ------------------------------------------------------------------------
#   Live communication between Blender (python) and RubyOF (Ruby)
#   (uses FIFO to send JSON messages)
# ------------------------------------------------------------------------


class IPC_Helper():
    def __init__(self, fifo_path):
        self.fifo_path = fifo_path
    
    def write(self, message):
        if not os.path.exists(self.fifo_path):
            return
        
        print("-----")
        print("=> FIFO open")
        pipe = open(self.fifo_path, 'w')
        
        
        start_time = time.time()
        try:
            # text = text.encode('utf-8')
            
            pipe.write(message + "\n")
            
            print(message)
            print("=> msg len:", len(message))
        except IOError as e:
            print("broken pipe error (suppressed exception)")
        
        stop_time = time.time()
        dt = (stop_time - start_time) * 1000
        print("=> fifo data transfer: ", dt, " msec" )
        
        pipe.close()
        print("=> FIFO closed")
        print("-----")
    
    
    # def __del__(self):
    #     pass
        
        # self.fifo.close()
        # print("FIFO closed")



# initialize in global scope - doesn't open FIFO until IPC_Helper.write()
to_ruby = IPC_Helper("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm")


meshDatablock_to_meshID = None
# ^ TODO: think about a better way to grant access to this key variable


















# ------------------------------------------------------------------------
#   properties needed for mesh export to OpenEXR
#   (serialized data)
# ------------------------------------------------------------------------


class PG_MyProperties (bpy.types.PropertyGroup):
    
    def limit_output_frame(self, context):
        # print(self)
        mytool = context.scene.my_tool
        
        max_frame_index = mytool.max_frames-1
        
        if mytool.output_frame > max_frame_index:
            mytool.output_frame = max_frame_index
        
        return None
    
    def limit_num_objects(self, context):
        # print(self)
        mytool = context.scene.my_tool
        
        max_index = mytool.max_num_objects-1
        
        if mytool.transform_scanline > max_index:
            mytool.transform_scanline = max_index
        
        return None
    
    output_dir : StringProperty(
        name="Output directory",
        description="Directory where all animation textures will be written (vertex animation data)",
        default="//",
        subtype='DIR_PATH'
    )
    
    name : StringProperty(
        name="Name",
        description="base name for all texture files",
        default="animation",
    )
    
    target_object : PointerProperty(
        name="Target object",
        description="object to be exported",
        type=bpy.types.Object
    )
    
    collection_ptr : PointerProperty(
        name="Collection",
        description="will export all geometry and transforms for all objects in this collection",
        type=bpy.types.Collection
    )
    
    max_tris : IntProperty(
        name = "Max tris",
        description="Total number of tris per frame",
        default = 100,
        min = 1,
        max = 1000000
    )
    
    max_frames : IntProperty(
        name = "Max frames",
        description="frame number where output vertex data should be stored",
        default = 20,
        min = 1,
        max = 1000000
    )
    
    output_frame : IntProperty(
        name = "Output frame",
        description="frame number where output vertex data should be stored",
        default = 3,
        min = 1,
        max = 1000000,
        update=limit_output_frame
    )
        
    
    position_tex : PointerProperty(
        name="Position texture",
        description="texture encoding position information",
        type=bpy.types.Image
    )
    
    normal_tex : PointerProperty(
        name="Normal texture",
        description="texture encoding normal vector data",
        type=bpy.types.Image
    )
    
    transform_tex : PointerProperty(
        name="Transform mat4 texture",
        description="texture encoding object mat4 transformse",
        type=bpy.types.Image
    )
    
    
    max_num_objects : IntProperty(
        name = "Max number of objects",
        description="maximum number of objects whose transforms can be saved",
        default = 20,
        min = 1,
        max = 1000000
    )
    
    transform_scanline : IntProperty(
        name = "Transform scanline",
        description="Scanline in texture where object transform will be stored",
        default = 3,
        min = 1,
        max = 1000000,
        update=limit_num_objects
    )
    
    transform_id : IntProperty(
        name = "Transform ID",
        description="ID value to be written to the next transform scanline",
        default = 3,
        min = 0,
        max = 65504
    )
    
    progress : FloatProperty(
        name="Progress",
        subtype="PERCENTAGE",
        soft_min=0, 
        soft_max=100, 
        precision=0,
    )
    
    running : BoolProperty(
        name="Running",
        default=False
    )
    
    status_message : StringProperty(
        name="Status message",
        default="exporting..."
    )



# global anim_tex_manager
#         if anim_tex_manager == None:
#             anim_tex_manager = Foo()
        


# ------------------------------------------------------------------------
#   Helpers needed to manipulate OpenEXR data
#   (live in-memory data)
# ------------------------------------------------------------------------

import os
from image_wrapper import ( ImageWrapper, get_cached_image )

ImageWrapper = reload_class(ImageWrapper)

from coroutine_decorator import *

class Foo ():
    def __init__(self):
        pass
    
    def __del__(self):
        pass
    
    
    
    # TODO: when do I set context / scene? is setting on init appropriate? when do those values get invalidated?
    
    
    def update_textures(self):
        pass



# scanline : array of pixel data (not nested array, just a flat array)
# Set the data for one pixel within an array representing a whole scanline
def scanline_set_px(scanline, px_i, px_data, channels=4):
    for i in range(channels):
        scanline[px_i*channels+i] = px_data[i]





def export_vertex_data(mytool, mesh, output_frame):
    mesh.calc_loop_triangles()
    # ^ need to call this to populate the mesh.loop_triangles() cache
    
    mesh.calc_normals_split()
    # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
    # ^ normals stored on the tri / face
    
    
    # TODO: update all code to use RGB (no alpha) to save some memory
    # TODO: use half instead of float to save memory
    
    
    # NOTE: all textures in the same animation set have the same dimensions
    
    # output_path = bpy.path.abspath("//")
    
    
    pos_texture = ImageWrapper(
        get_cached_image(mytool, "position_tex",
                         mytool.name+".position",
                         size=calc_geometry_tex_size(mytool),
                         channels_per_pixel=4),
        mytool.output_dir
    )
    
    norm_texture = ImageWrapper(
        get_cached_image(mytool, "normal_tex",
                         mytool.name+".normal",
                         size=calc_geometry_tex_size(mytool),
                         channels_per_pixel=4),
        mytool.output_dir
    )
    
    # (bottom row of pixels will always be full red)
    # This allows for the easy identification of one edge,
    # like a "this side up" sign, but it also allows for
    # the user to create frames completely free of any
    # visible geometry. (useful with GPU instancing)
    
    # data for just this object
    pixel_data = [1.0, 0.0, 0.0, 1.0] * pos_texture.width
    
    pos_texture.write_scanline(pixel_data, 0)
    
    
    
    # 
    # allocate pixel data buffers for mesh
    # 
    
    scanline_position = [0.2, 0.2, 0.2, 1.0] * pos_texture.width
    scanline_normals  = [0.0, 0.0, 0.0, 1.0] * norm_texture.width
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

    if num_tris > mytool.max_tris:
        raise RuntimeError(f'The mesh {mesh} has {num_tris} tris, but the animation texture has a limit of {mytool.max_tris} tris. Please increase the size of the animation texture.')
    
    
    verts = mesh.vertices
    for i, tri in enumerate(mesh.loop_triangles): # triangles per mesh
        normals = tri.split_normals
        for j in range(3): # verts per triangle
            vert_index = tri.vertices[j]
            vert = verts[vert_index]
            
            scanline_set_px(scanline_position, i*3+j, vec3_to_rgba(vert.co),
                            channels=pos_texture.channels_per_pixel)
            
            
            normal = normals[j]
            
            scanline_set_px(scanline_normals, i*3+j, vec3_to_rgba(normal),
                            channels=norm_texture.channels_per_pixel)
    
    pos_texture.write_scanline(scanline_position, output_frame)
    norm_texture.write_scanline(scanline_normals, output_frame)
    
    
    pos_texture.save()
    norm_texture.save()


def export_transform_data(mytool, target_object, scanline=1, mesh_id=1):
    # TODO: update all code to use RGB (no alpha) to save some memory
    # TODO: use half instead of float to save memory
    
    
    # TODO: consider using black and white for these textures, if that saves on pixels / somehow makes calculation easier (need to consider entire pipeline, so this must be delayed for a while)
    
    # output_path = bpy.path.abspath("//")
    
    
    
    transform_tex = ImageWrapper(
        get_cached_image(mytool, "transform_tex",
                         mytool.name+".transform",
                         size=calc_transform_tex_size(mytool),
                         channels_per_pixel=4),
        mytool.output_dir
    )
    
    # (bottom row of pixels will always be full red)
    # This allows for the easy identification of one edge,
    # like a "this side up" sign, but it also allows for
    # the user to create frames completely free of any
    # visible geometry. (useful with GPU instancing)
    
    # data for just this object
    pixel_data = [1.0, 0.0, 1.0, 1.0] * transform_tex.width
    
    transform_tex.write_scanline(pixel_data, 0)
    
    
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
    
    scanline_transform = [0.0, 0.0, 0.0, 0.0] * transform_tex.width
    
    
    id = mesh_id # TODO: update this to match mesh index
    
    scanline_set_px(scanline_transform, 0, [id, id, id, 1.0],
                    channels=transform_tex.channels_per_pixel)
    
    for i in range(1, 5): # range is exclusive of high end: [a, b)
        scanline_set_px(scanline_transform, i, vec4_to_rgba(out_mat[i-1]),
                        channels=transform_tex.channels_per_pixel)
    
    
    
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
                    channels=transform_tex.channels_per_pixel)
    
    scanline_set_px(scanline_transform, 6, vec3_to_rgba(c2),
                    channels=transform_tex.channels_per_pixel)
    
    scanline_set_px(scanline_transform, 7, vec3_to_rgba(c3),
                    channels=transform_tex.channels_per_pixel)
    
    scanline_set_px(scanline_transform, 8, vec3_to_rgba(c4),
                    channels=transform_tex.channels_per_pixel)
    
    transform_tex.write_scanline(scanline_transform, scanline)
    
    
    transform_tex.save()


def calc_geometry_tex_size(mytool):
    width_px  = mytool.max_tris*3 # 3 verts per triangle
    height_px = mytool.max_frames
    
    return [width_px, height_px]


# 
# This transform matrix data used by the GPU in the context of GPU instancing
# to draw various geometries that have been encoded onto textures.
# 
# This is not intended as an interchange format between Blender and RubyOF
# (it may be better to send individual position / rotation / scale instead)
# (so that way the individual components of the transform can be edited)
# 

def calc_transform_tex_size(mytool):
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





# bring in some code from mesh edit to update meshes
# maybe?
# but also need to detect:
    # new mesh object created
    # new mesh datablock created
def update_mesh_object(context, mesh_obj):
    pass
    
    # mytool = context.scene.my_tool
    # if "new object created":
    #     # add a new row to the 
        
    #     export_transform_data(mytool, mesh_obj,
    #                           scanline=i+1,
    #                           mesh_id=meshDatablock_to_meshID[mesh_obj.data])



# run this while mesh is being updated
def update_mesh_datablock(context, active_object):
    mytool = context.scene.my_tool
    
    # re-export this mesh in the anim texture (one line) and send a signal to RubyOF to reload the texture
    
    mesh = active_object.data
    export_vertex_data(mytool, mesh, meshDatablock_to_meshID[mesh])
    
    # (this will force reload of all textures, which may not be ideal for load times. but this will at least allow for prototyping)
    data = {
        'type': 'geometry_update',
        'scanline': meshDatablock_to_meshID[mesh],
        'normal_tex_path'  : os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".normal"+'.exr'),
        'position_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".position"+'.exr'),
        'transform_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".transform"+'.exr')
    }
    
    to_ruby.write(json.dumps(data))
    
    
    # # TODO: try removing the object message and only sending the mesh data message. this may be sufficient, as the name linking the two should stay the same, and I don't think the object properties are changing.



# repack for all entities that use this material
# (like denormalising two database tables)
# transform with color info          material color info
def update_material(context, updated_material):
    print("updating material...")
    
    mytool = context.scene.my_tool
    
    
    # don't need this (not writing to the variable)
    # but it helps to remember the scope of globals
    global meshDatablock_to_meshID
    
    
    all_mesh_objects = [ obj
                         for obj in mytool.collection_ptr.all_objects
                         if obj.type == 'MESH' ]
    
    
    tuples = [ (obj, obj.material_slots[0].material, i)
               for i, obj in enumerate(all_mesh_objects)
               if len(obj.material_slots) > 0 ]
    
    
    # need to update the pixels in the transform texture
    # that encode the color, but want to keep the other pixels the same
    
    # really need to update the API to remove the "scanline" notion before I can implement this correctly.
    
    # If the API allows for setting a pixel at a time, instead of setting a whole scanline all at once, then this can become much easier.
    
    transform_tex = ImageWrapper(
        get_cached_image(mytool, "transform_tex",
                         mytool.name+".transform",
                         size=calc_transform_tex_size(mytool),
                         channels_per_pixel=4),
        mytool.output_dir
    )
    
    
    i = 0
    for obj, bound_material, i in tuples:
        # print(bound_material, updated_material)
        # print(bound_material.name, updated_material.name)
        if bound_material.name == updated_material.name:
            print("mesh index:",i)
            row = i+1
            # i = meshDatablock_to_meshID[obj.data]
            # ^ oops
            # this is an index in the position / normal textures. I need a position in the transform texture
            col = 5
            
            mat = updated_material.rb_mat
            
            transform_tex.write_pixel(row,col+0, vec3_to_rgba(mat.ambient))
            
            diffuse_with_alpha = vec3_to_rgba(mat.diffuse) + [mat.alpha]
            transform_tex.write_pixel(row,col+1, diffuse_with_alpha)
            
            transform_tex.write_pixel(row,col+2, vec3_to_rgba(mat.specular))
            transform_tex.write_pixel(row,col+3, vec3_to_rgba(mat.emissive))
            
    transform_tex.save()
    
    data = {
        'type': 'material_update',
        'normal_tex_path'  : os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".normal"+'.exr'),
        'position_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".position"+'.exr'),
        'transform_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".transform"+'.exr')
    }
    
    to_ruby.write(json.dumps(data))
    




def register_depgraph_handlers():
    depsgraph_events = bpy.app.handlers.depsgraph_update_post
    
    if not on_depsgraph_update in depsgraph_events:
        depsgraph_events.append(on_depsgraph_update)

def unregister_depgraph_handlers():
    depsgraph_events = bpy.app.handlers.depsgraph_update_post
    
    if on_depsgraph_update in depsgraph_events:
        depsgraph_events.remove(on_depsgraph_update)



def on_depsgraph_update(scene, depsgraph):
    # print(args)
    
    # 
    # update entity mappings
    # 
    
    mytool = scene.my_tool
    
    all_mesh_objects = [ obj
                         for obj in mytool.collection_ptr.all_objects
                         if obj.type == 'MESH' ]
    
    # create map: obj name -> transform ID
    object_map = { obj.name : i+1
                   for i, obj in enumerate(all_mesh_objects) }
    
    # send mapping to RubyOF
    data = {
        'type': 'object_to_id_map',
        'value': object_map,
    }
    
    to_ruby.write(json.dumps(data))
    
    
    # # Loop over all object instances in the scene.
    # for update in depsgraph.updates:
    #     obj = update.id
        
    #     if isinstance(obj, bpy.types.Object):
    #         if obj.type == 'LIGHT':
    #             message_queue.append(pack_light(obj))
                
    #         elif obj.type == 'MESH':


anim_tex_manager = None





@coroutine
def export_all_textures():
    yield(0) # initial yield to just set things up
    
    # 'context' is recieved via the first yield,
    # rather than a standard argument.
    #  This is passed via the class defined in progress_bar.py
    context = yield(0)
    
    
    t0 = time.time()
    
    
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
    
    global meshDatablock_to_meshID
    
    unique_pairs = find_unique_mesh_pairs(all_mesh_objects)
    mesh_objects    = [ obj       for obj, datablock in unique_pairs ]
    mesh_datablocks = [ datablock for obj, datablock in unique_pairs ]
    
    meshDatablock_to_meshID = { mesh : i+1
                                for i, mesh in enumerate(mesh_datablocks) }
    
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
    
    mytool.status_message = "export unique meshes"
    for i, mesh in enumerate(unqiue_meshes):
        export_vertex_data(mytool, mesh, i+1) # handles triangulation
            # NOTE: This index 'i+1' ends up always being the same as the indicies in meshDatablock_to_meshID. Need to do it this way because at this stage, we only have the exportable final meshes, not the orignial mesh datablocks.
        
        task_count += 1
        context = yield(task_count / total_tasks)
    
    # 
    # export all objects
    # (transforms and associated mesh IDs)
    # 
    for i, obj in enumerate(all_mesh_objects):
        # use mapping: obj -> mesh datablock -> mesh ID
        export_transform_data(mytool, obj,
                              scanline=i+1,
                              mesh_id=meshDatablock_to_meshID[obj.data])
        
        task_count += 1
        context = yield(task_count / total_tasks)
    
    
    # 
    # get name of object -> mesh id mapping
    # 
    
    mytool.status_message = "show object map"
    
    # create map: obj name -> transform ID
    object_map = { obj.name : i+1
                   for i, obj in enumerate(all_mesh_objects) }
    
    # send mapping to RubyOF
    data = {
        'type': 'object_to_id_map',
        'value': object_map,
    }
    
    to_ruby.write(json.dumps(data))
    
    context = yield( task_count / total_tasks )
    
    
    # 
    # let RubyOF know that new animation textures have been exported
    # 
    
    data = {
        'type': 'anim_texture_update',
        'normal_tex_path'  : os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".normal"+'.exr'),
        'position_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".position"+'.exr'),
        'transform_tex_path': os.path.join(
                                bpy.path.abspath(mytool.output_dir),
                                mytool.name+".transform"+'.exr'),
    }
    
    to_ruby.write(json.dumps(data))
    
    
    context = yield(task_count / total_tasks)
    
    t1 = time.time()
    
    print("time elapsed:", t1-t0, "sec")































# ------------------------------------------------------------------------
#   User interface for animation texture export
#   (front end to OpenEXR export)
# ------------------------------------------------------------------------


import time
from progress_bar import ( OT_ProgressBarOperator )
OT_ProgressBarOperator = reload_class(OT_ProgressBarOperator)



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


class OT_TexAnimExportCollection (OT_ProgressBarOperator):
    """Export all objects in target collection"""
    bl_idname = "wm.texanim_export_collection"
    bl_label = "Export ENTIRE Collection"
    
    def setup(self, context):
        self.setup_properties(property_group=context.scene.my_tool,
                              percent_field='progress',
                              bool_field='running')
        
        self.delay_interval = 2
        self.timer_dt = 1/60
    
    def update_label(self):
        global Operations
        # context.object.progress_label = list(Operations.keys())[self.step]
    
    # called every tick
    @coroutine
    def run(self):
        # Delegating to a subgenerator
        # https://www.python.org/dev/peps/pep-0380/
        # https://stackoverflow.com/questions/9708902/in-practice-what-are-the-main-uses-for-the-new-yield-from-syntax-in-python-3
        yield from export_all_textures()



class OT_TexAnimClearAllTextures (bpy.types.Operator):
    """Clear both animation textures"""
    bl_idname = "wm.texanim_clear_all_textures"
    bl_label = "Clear All 3 Textures"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        # clear_textures(context.scene.my_tool)
        
        mytool = context.scene.my_tool
        
        mytool.position_tex  = None
        mytool.normal_tex    = None
        mytool.transform_tex = None
        
        
        return {'FINISHED'}


class DATA_PT_texanim_panel3 (bpy.types.Panel):
    COMPAT_ENGINES= {"RUBYOF"}
    
    bl_idname = "DATA_PT_texanim_panel3"
    bl_label = "AnimTex - all in collection"
    # bl_category = "Tool"  # note: replaced by preferences-setting in register function 
    bl_region_type = "WINDOW"
    bl_context = "output"   
    bl_space_type = "PROPERTIES"


  # def __init(self):
  #     super( self, Panel ).__init__()
  #     bl_category = bpy.context.preferences.addons[__name__].preferences.category 

    @classmethod
    def poll(cls, context):
        print(context.engine)
        return (context.engine in cls.COMPAT_ENGINES)

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        mytool = scene.my_tool
        
        layout.prop( mytool, "collection_ptr")
        layout.prop( mytool, "output_dir")
        layout.prop( mytool, "name")
        
        layout.prop( mytool, "max_tris")
        layout.prop( mytool, "max_frames")
        layout.prop( mytool, "max_num_objects")
        
        layout.row().separator()
        
        if mytool.running: 
            layout.prop( mytool, "progress")
            layout.label(text=mytool.status_message)
        else:
            layout.operator("wm.texanim_export_collection")
        
        layout.row().separator()
        
        layout.operator("wm.texanim_clear_all_textures")




























def typestring(obj):
    klass = type(obj)
    return f'{klass.__module__}.{klass.__qualname__}'


def focallength_to_fov(focal_length, sensor):
    return 2.0 * math.atan((sensor / 2.0) / focal_length)

def BKE_camera_sensor_size(sensor_fit, sensor_x, sensor_y):
    if (sensor_fit == CAMERA_SENSOR_FIT_VERT):
        return sensor_y;
    
    return sensor_x;
    
def pack_light(obj):
    data = {
        'type': typestring(obj), # 'bpy.types.Object'
        'name': obj.name_full,
        '.type': obj.type, # 'LIGHT'
        '.data.type': obj.data.type,  # 'POINT', etc
        
        'transform': pack_transform(obj),
        
        'color': [
            'rgb',
            obj.data.color[0],
            obj.data.color[1],
            obj.data.color[2]
        ],
        'ambient_color': [
            'rgb',
        ],
        'diffuse_color': [
            'rgb'
        ],
        'attenuation':[
            'rgb'
        ]
    }
    
    if data['.data.type'] == 'AREA':
        data.update({
            'size_x': ['float', obj.data.size],
            'size_y': ['float', obj.data.size_y]
        })
    elif data['.data.type'] == 'SPOT':
        data.update({
            'size': ['radians', obj.data.spot_size]
        })
    
    return data


def pack_mesh(obj):
    obj_data = {
        'type': typestring(obj), # 'bpy.types.Object'
        'name': obj.name_full,
        '.type' : obj.type, # 'MESH'
        'transform': pack_transform_mat4(obj),
        '.data.name': obj.data.name
    }
    
    return obj_data

def pack_material(mat):
    data = {
        'type': typestring(mat),
        'name': mat.name,
        'color': [
            'FloatColor_rgb',
            mat.rb_mat.diffuse[0],
            mat.rb_mat.diffuse[1],
            mat.rb_mat.diffuse[2]
        ],
        'alpha': [
            'float',
            mat.rb_mat.alpha
        ],
        'shininess': [
            'float',
            mat.rb_mat.shininess
        ]
    }
    
    return data


def pack_transform(obj):
    # 
    # set transform properties
    # 
    
    pos   = obj.location
    rot   = obj.rotation_quaternion
    scale = obj.scale
    
    transform = {
        'position':[
            "Vec3",
            pos.x,
            pos.y,
            pos.z
        ],
        'rotation':[
            "Quat",
            rot.w,
            rot.x,
            rot.y,
            rot.z
        ],
        'scale':[
            "Vec3",
            scale.x,
            scale.y,
            scale.z
        ]
    }
    
    return transform

def pack_transform_mat4(obj):
    nested_array = [None, None, None, None]
    
    mat = obj.matrix_world
    
    nested_array[0] = vec4_to_rgba(mat[0])
    nested_array[1] = vec4_to_rgba(mat[1])
    nested_array[2] = vec4_to_rgba(mat[2])
    nested_array[3] = vec4_to_rgba(mat[3])
    
    
    return nested_array
    

    
#  sub.prop(light, "size", text="Size X")
# sub.prop(light, "size_y", text="Y")

# col.prop(light, "spot_size", text="Size")
# ^ angle of spotlight



# col.prop(light, "color")
# col.prop(light, "energy")

# blender EEVEE properties:
    # color
    # power (wats)
    # specular
    # radius
    # shadow
# OpenFrameworks properties:
    # setAmbientColor()
    # setDiffuseColor()
    # setSpecularColor()
    # setAttenuation()
        # 3 args: const, linear, quadratic
    # setup() 
    # setAreaLight()
    # setDirectional()
    # setPointLight()
    # setSpotlight() # 2 args to set the following:
        # setSpotlightCutOff()
            # 0 to 90 degs, default 45
        # setSpotConcentration()
            # 0 to 128 exponent, default 16


def pack_viewport_camera(rotation, position,
                        lens, perspective_fov, ortho_scale,
                        near_clip, far_clip,
                        view_perspective):
    return {
        'type': 'viewport_camera',
        'rotation':[
            "Quat",
            rotation.w,
            rotation.x,
            rotation.y,
            rotation.z
        ],
        'position':[
            "Vec3",
            position.x,
            position.y,
            position.z
        ],
        'lens':[
            "mm",
            lens
        ],
        'fov':[
            "deg",
            perspective_fov
        ],
        'near_clip':[
            'm',
            near_clip
        ],
        'far_clip':[
            'm',
            far_clip
        ],
        # 'aspect_ratio':[
        #     "???",
        #     context.scene.my_custom_props.aspect_ratio
        # ],
        'ortho_scale':[
            "factor",
            ortho_scale
        ],
        'view_perspective': view_perspective,
    }


def calc_ortho_scale(scene, space, rv3d):
    # 
    # blender-git/blender/source/blender/blenkernel/intern/camera.c:293
    # 
    
    # rv3d->dist * sensor_size / v3d->lens
    # ortho_scale = rv3d.view_distance * sensor_size / space.lens;
    
        # (ortho_scale * space.lens) / rv3d.view_distance = sensor_size
    
    # with estimated ortho scale, compute sensor size
    ortho_scale = scene.my_custom_props.ortho_scale
    print('ortho scale -> sensor size')
    sensor_size = ortho_scale * space.lens / rv3d.view_distance
    print(sensor_size)
    
    # then, with that constant sensor size, compute the dynamic ortho scale
    print('that sensor size -> ortho scale')
    sensor_size = 71.98320027323571
    ortho_scale = rv3d.view_distance * sensor_size / space.lens
    print(ortho_scale)
    
    # ^ this works now!
    #   but now I need to be able to automatically compute the sensor size...
    
    # (in the link below, there's supposed to be a factor of 2 involved in converting lens to FOV. Perhaps the true value of sensor size is 72, which differs from the expected 36mm by a factor of 2 ???)
    
    return ortho_scale

def calc_viewport_fov(rv3d):
    # src: https://blender.stackexchange.com/questions/46391/how-to-convert-spaceview3d-lens-to-field-of-view
    vmat_inv = rv3d.view_matrix.inverted()
    pmat = rv3d.perspective_matrix @ vmat_inv # @ is matrix multiplication
    fov = 2.0*math.atan(1.0/pmat[1][1])*180.0/math.pi;
    print('rv3d fov:')
    print(fov)
    
    return fov
    




























class RubyOF(bpy.types.RenderEngine):
    # These three members are used by blender to set up the
    # RenderEngine; define its internal name, visible name and capabilities.
    bl_idname = "RUBYOF"
    bl_label = "RubyOF"
    bl_use_preview = True

    # Init is called whenever a new render engine instance is created. Multiple
    # instances may exist at the same time, for example for a viewport and final
    # render.
    def __init__(self):
        self.first_time = True
        
        
        # data = {
        #     'type':"interrupt"
        #     'value': "RESET"
        # }
        # to_ruby.write(json.dumps(data))
        
        # # data to send to ruby, as well as None to tell the io thread to stop
        # self.outbound_queue = queue.Queue()
        
        # # self.io_thread = threading.Thread(target=worker(), args=(i,))
        # self.io_thread = threading.Thread(target=self._io_worker)
        # self.io_thread.start()
        
        self.shm_dir = '/dev/shm/Blender_RubyOF/'
        if not os.path.exists(self.shm_dir):
            os.mkdir(self.shm_dir)
    

    # When the render engine instance is destroy, this is called. Clean up any
    # render engine data here, for example stopping running render threads.
    def __del__(self):
        pass
        # os.rmdir(self.shm_dir)
        # ^ can't remove this on exit, as there may still be files inside that RubyOF needs. Not sure who should delete this dir or when, but it's not as straightforward as I thought.
        # Also, I don't think this function can delete a directory that still has files inside.
        
        
        # self.outbound_queue.put(None) # signal the thread to stop
        # self.io_thread.join() # wait for thread to finish
    
    
    # This is the method called by Blender for both final renders (F12) and
    # small preview for materials, world and lights.
    def render(self, depsgraph):
        scene = depsgraph.scene
        scale = scene.render.resolution_percentage / 100.0
        self.size_x = int(scene.render.resolution_x * scale)
        self.size_y = int(scene.render.resolution_y * scale)

        # Fill the render result with a flat color. The framebuffer is
        # defined as a list of pixels, each pixel itself being a list of
        # R,G,B,A values.
        if self.is_preview:
            color = [0.1, 0.2, 0.1, 1.0]
        else:
            color = [0.2, 0.1, 0.1, 1.0]
        
        pixel_count = self.size_x * self.size_y
        rect = [color] * pixel_count
        
        # Here we write the pixel values to the RenderResult
        result = self.begin_result(0, 0, self.size_x, self.size_y)
        layer = result.layers[0].passes["Combined"]
        layer.rect = rect
        self.end_result(result)
    
    # For viewport renders, this method is called whenever Blender redraws
    # the 3D viewport. The renderer is expected to quickly draw the render
    # with OpenGL, and not perform other expensive work.
    # Blender will draw overlays for selection and editing on top of the
    # rendered image automatically.
    # 
    # NOTE: if this function is too slow it causes viewport flicker
    def view_draw(self, context, depsgraph):
        # send data to RubyOF about the viewport / camera
        self.__update_viewport(context, depsgraph)
        
        #
        # Render the viewport
        #
        region = context.region
        scene = depsgraph.scene
        
        # Get viewport dimensions
        dimensions = region.width, region.height
        
        # Bind shader that converts from scene linear to display space,
        bgl.glEnable(bgl.GL_BLEND)
        bgl.glBlendFunc(bgl.GL_ONE, bgl.GL_ONE_MINUS_SRC_ALPHA)
        self.bind_display_space_shader(scene)
        
        
        a = context.scene.my_custom_props.alpha
        bgl.glClearColor(0*a,0*a,0*a,a)
        bgl.glClear(bgl.GL_COLOR_BUFFER_BIT|bgl.GL_DEPTH_BUFFER_BIT)
        
        
        self.unbind_display_space_shader()
        bgl.glDisable(bgl.GL_BLEND)
    
    
    # For viewport renders, this method gets called once at the start and
    # whenever the scene or 3D viewport changes. This method is where data
    # should be read from Blender in the same thread. Typically a render
    # thread will be started to do the work while keeping Blender responsive.
    def view_update(self, context, depsgraph):
        region = context.region
        view3d = context.space_data
        scene = depsgraph.scene
        
        # send info to RubyOF about the data in the scene
        self.__update_scene(context, depsgraph)
    
        
    # ---- private helper methods ----
    
    def __update_viewport(self, context, depsgraph):
        #
        # Update the viewport camera
        #
        region = context.region
        rv3d = context.region_data # RegionView3D(bpy_struct)
        coord = (region.width/2.0, region.height/2.0)
        
        v3du = bpy_extras.view3d_utils
        camera_direction = v3du.region_2d_to_vector_3d(region, rv3d, coord)
        camera_origin    = v3du.region_2d_to_origin_3d(region, rv3d, coord)
        
        space = context.space_data # SpaceView3D(Space)
        
        # print(camera_direction)
        # # ^ note: camera objects have both lens (mm) and angle (fov degrees)
        
        
        
        data = pack_viewport_camera(
            rotation         = rv3d.view_rotation,
            position         = camera_origin,
            lens             = space.lens,
            perspective_fov  = calc_viewport_fov(rv3d),
            ortho_scale      = calc_ortho_scale(context.scene, space, rv3d),
            # ortho_scale      = context.scene.my_custom_props.ortho_scale,
            near_clip        = space.clip_start,
            far_clip         = space.clip_end,
            view_perspective = rv3d.view_perspective
        )
        
        to_ruby.write(json.dumps(data))
        
        
        
        if context.scene.my_custom_props.b_windowLink:
            data = {
                'type': 'viewport_region',
                'width':  region.width,
                'height': region.height,
                'pid': os.getpid()
            }
            
            to_ruby.write(json.dumps(data))
        
        
    
    def __update_scene(self, context, depsgraph):
        region = context.region
        view3d = context.space_data
        scene = depsgraph.scene
        
        
        print("view update ---")
        
        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'start',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        # # 
        # # update entity mappings
        # # 
        
        # mytool = context.scene.my_tool
        
        # all_mesh_objects = [ obj
        #                      for obj in mytool.collection_ptr.all_objects
        #                      if obj.type == 'MESH' ]
        
        # # create map: obj name -> transform ID
        # object_map = { obj.name : i+1
        #                for i, obj in enumerate(all_mesh_objects) }
        
        # # send mapping to RubyOF
        # data = {
        #     'type': 'object_to_id_map',
        #     'value': object_map,
        # }
        
        # to_ruby.write(json.dumps(data))
        
        
        # 
        # create meshDatablock_to_meshID mapping if it does not already exist
        # 
        
        global meshDatablock_to_meshID
        if meshDatablock_to_meshID is None:
            mytool = context.scene.my_tool
            
            all_mesh_objects = [ obj
                                 for obj
                                 in mytool.collection_ptr.all_objects
                                 if obj.type == 'MESH' ]
            
            unique_pairs = find_unique_mesh_pairs(all_mesh_objects)
            mesh_datablocks = [ datablock
                                for obj, datablock in unique_pairs ]
            
            meshDatablock_to_meshID = { mesh : i+1
                                        for i, mesh
                                        in enumerate(mesh_datablocks) }
        
        
        
        # collect up two different categories of messages
        # the datablock messages must be sent before entity messages
        # otherwise there will be issues with dependencies
        message_queue   = [] # list of dict
        
        active_object = context.active_object
        
        if self.first_time:
            # First time initialization
            self.first_time = False
            
            # Loop over all datablocks used in the scene.
            # for datablock in depsgraph.ids:
            
            # loop over all objects
            for obj in bpy.data.objects:
                if obj.type == 'LIGHT':
                    message_queue.append(pack_light(obj))
                    
                elif obj.type == 'MESH':
                    pass
                    # TODO: re-export this mesh in the anim texture (one line) and send a signal to RubyOF to reload the texture
                    
                    # message_queue.append(pack_mesh(obj))
                    
                    # ^ Don't really need to send this data on startup. the assumption should be that the texture holds most of the transform / vertex data in between sessions of RubyOF.
            
            # loop over all materials
            for mat in bpy.data.materials:
                if mat.users > 0:
                    message_queue.append(pack_material(mat))
            
            # TODO: want to separate out lights from meshes (objects)
            # TODO: want to send linked mesh data only once (expensive) but send linked light data every time (no cost savings for me to have linked lights in GPU render)
            
            
        elif active_object != None and active_object.mode == 'EDIT':
            # editing one object: only send edits to that single mesh
            
            bpy.ops.object.editmode_toggle()
            bpy.ops.object.editmode_toggle()
            # bpy.ops.object.mode_set(mode= 'OBJECT')
            
            print("mesh edit detected")
            print(active_object)
            
            
            update_mesh_datablock(context, active_object)
            
            
            # send material data if any material was changed
            # (maybe it was this material? no way to be sure, so just send it)
            if(depsgraph.id_type_updated('MATERIAL')):
                if(len(active_object.material_slots) > 0):
                    mat = active_object.material_slots[0].material
                    message_queue.append(pack_material(mat))
            
            
            bpy.ops.object.editmode_toggle()
            bpy.ops.object.editmode_toggle()
            # bpy.ops.object.mode_set(mode= 'EDIT')
            
        else:
            # It is possible multiple things have been updated.
            # Could be a mixture of objects and/or materials.
            # Only send the data that has changed.
            
            print("there are", len(depsgraph.updates), "updates to process")
            
            # Loop over all object instances in the scene.
            for update in depsgraph.updates:
                obj = update.id
                
                if isinstance(obj, bpy.types.Object):
                    if obj.type == 'LIGHT':
                        message_queue.append(pack_light(obj))
                        
                    elif obj.type == 'MESH':
                        # TODO: re-export this mesh in the anim texture (one line) and send a signal to RubyOF to reload the texture
                        
                        # if update.is_updated_geometry:
                        #     mesh_datablocks.append(obj.data)
                        
                        # send message to update mesh object transform, etc
                        message_queue.append(pack_mesh(obj))
                        
                        # update mesh datablock
                        update_mesh_object(context, obj)
                        
                        
                        
                    
                    # if update.is_updated_transform:
                    #     obj_data['transform'] = pack_transform(obj)
                    
                    # if isinstance(obj.data, bpy.types.Light):
                    #     obj_data['data'] = self.__pack_light(obj.data)
                
                # only send data for updated materials
                if isinstance(obj, bpy.types.Material):
                    # repack for all entities that use this material
                    # (like denormalising two database tables)
                    # transform with color info          material color info
                    
                    mat = obj
                    update_material(context, mat)
                    
                    message_queue.append(pack_material(mat))
            
            # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material. Thus, we send a mapping of {mesh object name => material name} for all meshes, every frame. RubyOF will figure out when to actually rebind the materials.
            
        # ----------
        # TODO: if many objects use one mesh datablock, should only need to send that datablock once. old style did this, but the new style does not.
        
        # If many objects use one mesh datablock, 
        # should only send that datablock once.
        # That is why we need to group them all up before sending
        
        # (DELETED OLD CODE FOR MESH EXPORT)
        
        # send out all the regular messages after the datablocks
        # to prevent dependency issues
        for msg in message_queue:
            to_ruby.write(json.dumps(msg))
        
        # full list of all objects, by name (helps Ruby delete old objects)
        data = {
            'type': 'all_entity_names',
            'list': [ instance.object.name_full for instance 
                        in depsgraph.object_instances ]
        }
        
        to_ruby.write(json.dumps(data))
        
        
        # information about material linkages
        # (send all info every frame)
        # (RubyOF will figure out whether to rebind or not)
        for obj in bpy.data.objects:
            if isinstance(obj.data, bpy.types.Mesh):
                # print("found object with mesh")
                
                material_name = ''
                # ^ default material name
                #   tells RubyOF to bind default material
                
                # if there is a material bound, use that instead of the default
                if(len(obj.material_slots) > 0):
                    mat = obj.material_slots[0].material
                    material_name = mat.name
                
                data = {
                    'type': 'material_mapping',
                    'object_name': obj.name_full,
                    'material_name': material_name
                }
                
                # TODO: silence material linkage for now, but need to re-instate an equivalent way to send this data later. Have to turn it off for now because I'm deliberately not sending some mesh datablocks to RubyOF. If the meshes don't exist over there, then trying to set the linkage will cause a crash.
                
                # to_ruby.write(json.dumps(data))
        
        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'end',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        # TODO: serialize and send materials that have changed
        
        # note: in blender, one object can have many material slots
    
    # --------------------------------















#
# Properties
#

class RubyOF_Properties(bpy.types.PropertyGroup):
    my_bool: BoolProperty(
        name="Enable or Disable",
        description="A bool property",
        default = False
        )
        
    my_float: FloatProperty(
        name = "Float Value",
        description = "A float property",
        default = 23.7,
        min = 0.01,
        max = 30.0
        )
        
    my_pointer: PointerProperty(type=bpy.types.Object)
    
    alpha: FloatProperty(
        name = "Alpha",
        description = "Alpha transparency for the window",
        default = 0.25,
        min = 0.0,
        max = 1.0
        )
        
    b_windowLink: BoolProperty(
        name="window link",
        description="Automatically reposition and resize the RubyOF window to be directly under the Blender 3D view",
        default = False
        )
    
    camera: PointerProperty(
        type=bpy.types.Camera,
        name="camera",
        description="Camera to be used by the RubyOF game engine")
    
    # aspect_ratio: FloatProperty(
    #     name = "Aspect ratio",
    #     description = "Viewport aspect ratio",
    #     default = 16.0/9.0,
    #     min = 0.0001,
    #     max = 100.0000
    #     )
    
    ortho_scale: FloatProperty(
        name = "Ortho scale",
        description = "Scale for orthographic render mode (manual override)",
        default = 1,
        min = 0,
        max = 100000
        )


#
# Panel for general renderer properties (under Render Properties tab)
#
class DATA_PT_RubyOF_Properties(bpy.types.Panel):
    COMPAT_ENGINES= {"RUBYOF"}
    
    bl_idname = "RUBYOF_PT_HELLOWORLD"
    bl_label = "Properties (custom renderer)"
    bl_region_type = 'WINDOW'
    bl_context = "render"
    bl_space_type = 'PROPERTIES'
    
    # poll allows panel to only be shown in certain contexts (ie, when the function returns true)
    # Here, we check to make sure that the active render engine is in the list of compatible engines.
    @classmethod
    def poll(cls, context):
        print(context.engine)
        return (context.engine in cls.COMPAT_ENGINES)
    
    def draw(self, context):
        layout = self.layout
        
        # layout.label(text="Hello World")
        
        # layout.prop(context.scene.my_custom_props, "my_bool")
        # layout.prop(context.scene.my_custom_props, "my_float")
        # layout.prop(context.scene.my_custom_props, "my_pointer")
        
        # layout.label(text="Real Data Below")
        layout.prop(context.scene.my_custom_props, "alpha")
        layout.prop(context.scene.my_custom_props, "b_windowLink")
        layout.prop(context.scene.my_custom_props, "camera")
        # layout.prop(context.scene.my_custom_props, "aspect_ratio")
        layout.prop(context.scene.my_custom_props, "ortho_scale")
        
        layout.row().separator()
        
        row = layout.row()
        row.operator("render.rubyof_reverse", text="<--")
        row.operator("render.rubyof_pause", text=" || ")
        row.operator("render.rubyof_play", text="-->")
        
        row = layout.row()
        row.operator("render.rubyof_step_back", text="back")
        row.operator("render.rubyof_step_forward", text="forward")


class RENDER_OT_RubyOF_StepBack (bpy.types.Operator):
    """move execution one frame backwards"""
    bl_idname = "render.rubyof_step_back"
    bl_label = "Step Back"
    
    @classmethod
    def poll(cls, context):
        return True
    
    def execute(self, context):
        data = {
            'type': 'timeline_command',
            'value': 'step back',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        return {'FINISHED'}

class RENDER_OT_RubyOF_MessageStepForward (bpy.types.Operator):
    """move execution one frame forwards"""
    bl_idname = "render.rubyof_step_forward"
    bl_label = "Step Forward"
    
    @classmethod
    def poll(cls, context):
        return True
    
    def execute(self, context):
        data = {
            'type': 'timeline_command',
            'value': 'step forward',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        return {'FINISHED'}

class RENDER_OT_RubyOF_MessagePause (bpy.types.Operator):
    """pause execution"""
    bl_idname = "render.rubyof_pause"
    bl_label = "||"
    
    @classmethod
    def poll(cls, context):
        return True
    
    def execute(self, context):
        data = {
            'type': 'timeline_command',
            'value': 'pause',
        }
        
        to_ruby.write(json.dumps(data))
        
        return {'FINISHED'}

class RENDER_OT_RubyOF_MessagePlay (bpy.types.Operator):
    """let execution play forwards, generating new history"""
    bl_idname = "render.rubyof_play"
    bl_label = "-->"
    
    @classmethod
    def poll(cls, context):
        return True
    
    def execute(self, context):
        data = {
            'type': 'timeline_command',
            'value': 'play',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        return {'FINISHED'}

class RENDER_OT_RubyOF_MessageReverse (bpy.types.Operator):
    """let execution play backwards, using saved history"""
    bl_idname = "render.rubyof_reverse"
    bl_label = "<--"
    
    @classmethod
    def poll(cls, context):
        return True
    
    def execute(self, context):
        data = {
            'type': 'timeline_command',
            'value': 'reverse',
        }
        
        to_ruby.write(json.dumps(data))
        
        
        return {'FINISHED'}





















#
# Panel for light (under "object data" tab for a light object)
# (based on blender source code:
#    blender-git/build_linux_debug/bin/2.90/scripts/startup/bl_ui/properties_data_light.py
# )
class DataButtonsPanel:
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "data"

    @classmethod
    def poll(cls, context):
        engine = context.engine
        return context.light and (engine in cls.COMPAT_ENGINES)

class DATA_PT_RubyOF_light(DataButtonsPanel, bpy.types.Panel):
    bl_label = "Light"
    COMPAT_ENGINES = {'RUBYOF'}
    
    def draw(self, context):
        layout = self.layout
        light = context.light
        
        # Compact layout for node editor.
        if self.bl_space_type == 'PROPERTIES':
            layout.row().prop(light, "type", expand=True)
            layout.use_property_split = True
        else:
            layout.use_property_split = True
            layout.row().prop(light, "type")
        
        col = layout.column()
        col.prop(light, "color")
        col.prop(light, "energy")
        col.prop(light, "specular_factor", text="Specular")
        
        col.separator()
        
        if light.type in {'POINT', 'SPOT'}:
            col.prop(light, "shadow_soft_size", text="Radius")
        elif light.type == 'SUN':
            col.prop(light, "angle")
        elif light.type == 'AREA':
            col.prop(light, "shape")
            
            sub = col.column(align=True)
            
            if light.shape in {'SQUARE', 'DISK'}:
                sub.prop(light, "size")
            elif light.shape in {'RECTANGLE', 'ELLIPSE'}:
                sub.prop(light, "size", text="Size X")
                sub.prop(light, "size_y", text="Y")


class DATA_PT_spot(DataButtonsPanel, bpy.types.Panel):
    bl_label = "Spot Shape"
    bl_parent_id = "DATA_PT_RubyOF_light"
    COMPAT_ENGINES= {"RUBYOF"}

    @classmethod
    def poll(cls, context):
        light = context.light
        engine = context.engine
        return (light and light.type == 'SPOT') and (engine in cls.COMPAT_ENGINES)

    def draw(self, context):
        layout = self.layout
        layout.use_property_split = True

        light = context.light

        col = layout.column()

        col.prop(light, "spot_size", text="Size")
        col.prop(light, "spot_blend", text="Blend", slider=True)

        col.prop(light, "show_cone")

























# def update_rgb_nodes(self, context):
#     pass
    # mat = self.id_data
    # nodes = [n for n in mat.node_tree.nodes
    #         if isinstance(n, bpy.types.ShaderNodeRGB)]

    # for n in nodes:
    #     n.outputs[0].default_value = self.rgb_controller

class RubyOF_MATERIAL_Properties(bpy.types.PropertyGroup):
    # diffuse color
    # alpha
    # shininess
    
    ambient: FloatVectorProperty(
        name = "Ambient Color",
        description = "the color of the material when it is not illuminated",
        subtype = 'COLOR',
        default = (0.2, 0.2, 0.2), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    diffuse: FloatVectorProperty(
        name = "Diffuse Color",
        description = "the color of the material when it is illuminated",
        subtype = 'COLOR',
        default = (0.8, 0.8, 0.8), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    specular: FloatVectorProperty(
        name = "Specular Color",
        description = "the color of highlights on a material",
        subtype = 'COLOR',
        default = (0.0, 0.0, 0.0), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    emissive: FloatVectorProperty(
        name = "Emissive Color",
        description = "the color the material illuminated from within",
        subtype = 'COLOR',
        default = (0.0, 0.0, 0.0), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    alpha: FloatProperty(
        name = "alpha",
        description = "Alpha transparency. Varies 0-1, where 0 is fully transparent",
        default = 1,
        min = 0,
        max = 1,
        precision = 2,
        step = 0.01
        )
    
    shininess: FloatProperty(
        name = "shininess",
        description = "Specular exponent; Varies 0-128, where 128 is the most shiny",
        default = 0.2,
        min = 0,
        max = 128
        )



class MaterialButtonsPanel:
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "material"
    # COMPAT_ENGINES must be defined in each subclass, external engines can add themselves here

    @classmethod
    def poll(cls, context):
        mat = context.material
        return mat and (context.engine in cls.COMPAT_ENGINES) and not mat.grease_pencil


class RUBYOF_MATERIAL_PT_context_material(MaterialButtonsPanel, bpy.types.Panel):
    bl_label = ""
    bl_context = "material"
    bl_options = {'HIDE_HEADER'}
    COMPAT_ENGINES = {'RUBYOF'}

    @classmethod
    def poll(cls, context):
        ob = context.object
        mat = context.material

        if (ob and ob.type == 'GPENCIL') or (mat and mat.grease_pencil):
            return False

        return (ob or mat) and (context.engine in cls.COMPAT_ENGINES)

    def draw(self, context):
        layout = self.layout

        mat = context.material
        ob = context.object
        slot = context.material_slot
        space = context.space_data
        if ob:
            is_sortable = len(ob.material_slots) > 1
            rows = 3
            if is_sortable:
                rows = 5

            row = layout.row()

            row.template_list("MATERIAL_UL_matslots", "", ob, "material_slots", ob, "active_material_index", rows=rows)

            col = row.column(align=True)
            col.operator("object.material_slot_add", icon='ADD', text="")
            col.operator("object.material_slot_remove", icon='REMOVE', text="")

            col.separator()

            col.menu("MATERIAL_MT_context_menu", icon='DOWNARROW_HLT', text="")

            if is_sortable:
                col.separator()

                col.operator("object.material_slot_move", icon='TRIA_UP', text="").direction = 'UP'
                col.operator("object.material_slot_move", icon='TRIA_DOWN', text="").direction = 'DOWN'

        row = layout.row()
        
        if ob:
            row.template_ID(ob, "active_material", new="material.new")

            if slot:
                icon_link = 'MESH_DATA' if slot.link == 'DATA' else 'OBJECT_DATA'
                row.prop(slot, "link", icon=icon_link, icon_only=True)

            if ob.mode == 'EDIT':
                row = layout.row(align=True)
                row.operator("object.material_slot_assign", text="Assign")
                row.operator("object.material_slot_select", text="Select")
                row.operator("object.material_slot_deselect", text="Deselect")

        elif mat:
            row.template_ID(space, "pin_id")
        
        # when you create a new texture slot, it is initialized empty
        # so you need to make sure there's actually a material there
        # or you get a Python error.
        # (Blender won't crash, but this is still not good behavior.)
        if mat:
            # layout.prop(mat.rb_mat, "color")
            
            layout.prop(mat.rb_mat, "ambient")
            layout.prop(mat.rb_mat, "diffuse")
            layout.prop(mat.rb_mat, "specular")
            layout.prop(mat.rb_mat, "emissive")
            
            col = layout.column()
            col.prop(mat.rb_mat, "alpha")
            col.prop(mat.rb_mat, "shininess")



# class MATERIAL_PT_preview(MaterialButtonsPanel, Panel):
#     bl_label = "Preview"
#     bl_options = {'DEFAULT_CLOSED'}
#     COMPAT_ENGINES = {'BLENDER_EEVEE'}

#     def draw(self, context):
#         self.layout.template_preview(context.material)


# class MATERIAL_PT_custom_props(MaterialButtonsPanel, PropertyPanel, Panel):
#     COMPAT_ENGINES = {'BLENDER_RENDER', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'}
#     _context_path = "material"
#     _property_type = bpy.types.Material

# class MATERIAL_PT_viewport(MaterialButtonsPanel, Panel):
#     bl_label = "Viewport Display"
#     bl_context = "material"
#     bl_options = {'DEFAULT_CLOSED'}
#     bl_order = 10

#     @classmethod
#     def poll(cls, context):
#         mat = context.material
#         return mat and not mat.grease_pencil

#     def draw(self, context):
#         layout = self.layout
#         layout.use_property_split = True

#         mat = context.material

#         col = layout.column()
#         col.prop(mat, "diffuse_color", text="Color")
#         col.prop(mat, "metallic")
#         col.prop(mat, "roughness")


























# RenderEngines also need to tell UI Panels that they are compatible with.
# We recommend to enable all panels marked as BLENDER_RENDER, and then
# exclude any panels that are replaced by custom panels registered by the
# render engine, or that are not supported.
def get_panels():
    exclude_panels = {
        'VIEWLAYER_PT_filter',
        'VIEWLAYER_PT_layer_passes',
        
        "CYCLES_RENDER_PT_light_paths",
        "CYCLES_LIGHT_PT_light",
        "CYCLES_LIGHT_PT_nodes",
        "CYCLES_LIGHT_PT_preview",
        "CYCLES_LIGHT_PT_spot",
        "CYCLES_RENDER_PT_light_paths_caustics",
        "CYCLES_RENDER_PT_light_paths_clamping",
        "CYCLES_RENDER_PT_light_paths_max_bounces",
        "CYCLES_RENDER_PT_passes_light",
        "CYCLES_VIEW3D_PT_shading_lighting",
        # "DATA_PT_context_light",
        "DATA_PT_context_lightprobe",
        # "DATA_PT_custom_props_light",
        "DATA_PT_EEVEE_light",
        "DATA_PT_EEVEE_light_distance",
        "DATA_PT_light",
        "DATA_PT_lightprobe",
        "DATA_PT_lightprobe_display",
        "DATA_PT_lightprobe_parallax",
        "DATA_PT_lightprobe_visibility",
        "NODE_CYCLES_LIGHT_PT_light",
        "NODE_CYCLES_LIGHT_PT_spot",
        "NODE_DATA_PT_EEVEE_light",
        "NODE_DATA_PT_light",
        "RENDER_PT_eevee_indirect_lighting",
        "RENDER_PT_eevee_indirect_lighting_display",
        "RENDER_PT_eevee_volumetric_lighting",
        "RENDER_PT_opengl_lighting",
        "USERPREF_PT_studiolight_light_editor",
        "USERPREF_PT_studiolight_lights",
        "USERPREF_PT_studiolight_matcaps",
        "USERPREF_PT_studiolight_world",
        "VIEW3D_PT_shading_lighting",
        "VIEWLAYER_PT_eevee_layer_passes_light"
        # "DATA_PT_RubyOF_light",
    }
    
    panels = []
    for panel in bpy.types.Panel.__subclasses__():
        # print(panel.__name__)
        if hasattr(panel, 'COMPAT_ENGINES') and 'BLENDER_RENDER' in panel.COMPAT_ENGINES:
            if panel.__name__ not in exclude_panels:
                panels.append(panel)
    
    return panels

classes = (
    RENDER_OT_RubyOF_StepBack,
    RENDER_OT_RubyOF_MessageStepForward,
    RENDER_OT_RubyOF_MessagePause,
    RENDER_OT_RubyOF_MessagePlay,
    RENDER_OT_RubyOF_MessageReverse,
    RubyOF_Properties,
    RubyOF_MATERIAL_Properties,
    DATA_PT_RubyOF_Properties,
    DATA_PT_RubyOF_light,
    DATA_PT_spot,
    RUBYOF_MATERIAL_PT_context_material,
    #
    #
    #
    PG_MyProperties,
    OT_ProgressBarOperator,
    OT_TexAnimExportCollection,
    OT_TexAnimClearAllTextures,
    DATA_PT_texanim_panel3
)

def register():
    # Register the RenderEngine
    bpy.utils.register_class(RubyOF)
    
    for panel in get_panels():
        panel.COMPAT_ENGINES.add('RUBYOF')
    
    
    
    for c in classes:
        bpy.utils.register_class(c)
    
    # Bind variable for properties
    bpy.types.Scene.my_custom_props = PointerProperty(
            type=RubyOF_Properties
        )
    
    bpy.types.Material.rb_mat = PointerProperty(
            type=RubyOF_MATERIAL_Properties
        )
    
    bpy.types.Scene.my_tool = PointerProperty(type=PG_MyProperties)
    
    register_depgraph_handlers()


def unregister():
    unregister_depgraph_handlers()
    
    bpy.utils.unregister_class(RubyOF)
    
    for panel in get_panels():
        if 'RUBYOF' in panel.COMPAT_ENGINES:
            panel.COMPAT_ENGINES.remove('RUBYOF')
    
    for c in reversed(classes):
        bpy.utils.unregister_class(c)
        
    
    del bpy.types.Scene.my_tool
    
    

def main():
    print("hello world")
    register()
    
    
