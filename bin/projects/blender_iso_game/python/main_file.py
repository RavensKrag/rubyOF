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

import sys
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


from class_reloader import reload_class
from utilities import *






handler_types = {
    'on_save' : bpy.app.handlers.save_post,
    'on_load' : bpy.app.handlers.load_post,
    'on_undo' : bpy.app.handlers.undo_post,
    'on_redo' : bpy.app.handlers.redo_post
}

def register_callback(handler_type, function):
    # unregister_callbacks()
    
    depsgraph_events = handler_types[handler_type]
    
    if not function in depsgraph_events:
        depsgraph_events.append(function)
        # callbacks[handler_type].append(function)
    
    print(depsgraph_events)
    sys.stdout.flush()

def unregister_callbacks():
    for depsgraph_events in handler_types.values():
        for handler in depsgraph_events:
            if "rubyof__" in handler.__name__:
                depsgraph_events.remove(handler)
        
        print("events:", depsgraph_events)
        sys.stdout.flush()


from bpy.app.handlers import persistent

@persistent
def rubyof__on_load(*args):
    context = bpy.context
    tex_manager = anim_texture_manager_singleton(context)
    tex_manager.on_load()


@persistent
def rubyof__on_save(*args):
    context = bpy.context
    tex_manager = anim_texture_manager_singleton(context)
    tex_manager.on_save()


def rubyof__on_undo(scene):
    # print("on undo")
    # print(args)
    # sys.stdout.flush()
    
    context = bpy.context
    tex_manager = anim_texture_manager_singleton(context)
    tex_manager.on_undo(scene)

def rubyof__on_redo(scene):
    # print("on undo")
    # print(args)
    # sys.stdout.flush()
    
    context = bpy.context
    tex_manager = anim_texture_manager_singleton(context)
    tex_manager.on_redo(scene)
    

def register_event_handlers():
    register_callback('on_save', rubyof__on_save)
    register_callback('on_load', rubyof__on_load)
    register_callback('on_redo', rubyof__on_redo)
    register_callback('on_undo', rubyof__on_undo)
    
    
def unregister_event_handlers():
    unregister_callbacks()


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
        
        # print("-----")
        # print("=> FIFO open")
        pipe = open(self.fifo_path, 'w')
        
        
        start_time = time.time()
        try:
            # text = text.encode('utf-8') # <-- not needed
            
            pipe.write(message + "\n")
            
            # print(message)
            # print("=> msg len:", len(message))
        except IOError as e:
            pass
            # print("broken pipe error (suppressed exception)")
        
        stop_time = time.time()
        dt = (stop_time - start_time) * 1000
        # print("=> fifo data transfer: ", dt, " msec" )
        
        pipe.close()
        # print("=> FIFO closed")
        # print("-----")
    
    
    # def __del__(self):
    #     pass
        
        # self.fifo.close()
        # print("FIFO closed")














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
    
    
    
    def update_sync_deletions(self, context):
        if self.sync_deletions:
            bpy.ops.wm.sync_deletions('INVOKE_DEFAULT')
        
        return None
    
    sync_deletions : BoolProperty(
        name="Sync Deletions",
        default=False,
        update=update_sync_deletions
    )
    
    
    
    

# Use modal over the timer api, because the timer api involves threading,
# which then requires that you make your operation thread safe.
# That's all a huge pain just to get concurrency, 
# so for our use case, the modal operator is much better.
    # timer api:
    # self.timer = functools.partial(self.detect_deletions, mytool)
    # bpy.app.timers.register(self.timer, first_interval=self.timer_dt)
class OT_TexAnimSyncDeletions (bpy.types.Operator):
    """Watch for object deletions and sync them to the anim texture"""
    bl_idname = "wm.sync_deletions"
    bl_label = "Sync Deletions"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def __init__(self):
        
        self._timer = None
        self.timer_dt = 1/60
        
        self.old_names = None
        self.new_names = None
        
    
    def modal(self, context, event):
        mytool = context.scene.my_tool
        
        if event.type == 'TIMER':
            self.run(context)
        
        if not mytool.sync_deletions:
            context.window_manager.event_timer_remove(self._timer)
            return {'FINISHED'}
        
        return {'PASS_THROUGH'}
    
    def invoke(self, context, event):
        wm = context.window_manager
        
        self._timer = wm.event_timer_add(self.timer_dt, window=context.window)
        wm.modal_handler_add(self)
        
        mytool = context.scene.my_tool
        
        self.old_names = [ x.name for x in mytool.collection_ptr.all_objects ]
        
        return {'RUNNING_MODAL'}
    
    
    def run(self, context):
        # print("running", time.time())
        # print("objects: ", len(context.scene.objects))
        
        mytool = context.scene.my_tool
        
        self.new_names = [ x.name for x in mytool.collection_ptr.all_objects ]
        
        delta = list(set(self.old_names) - set(self.new_names))
        
        # print("delta:", delta)
        
        if len(delta) > 0:
            self.old_names = self.new_names
            
            tex_manager = anim_texture_manager_singleton(context)
            
            for name in delta:
                # print(delete)
                
                # TODO: make sure they're all mesh objects
                tex_manager.post_mesh_object_deletion(name)
                
                # tex_manager.post_mesh_object_deletion(mesh_obj_name)















# ------------------------------------------------------------------------
#   Helpers needed to manipulate OpenEXR data
#   (live in-memory data)
# ------------------------------------------------------------------------

import os


from anim_tex_manager import ( AnimTexManager )
AnimTexManager = reload_class(AnimTexManager)




















# ------------------------------------------------------------------------
#   Things that need to be accessed in mulitple places,
#   so I declared them global for now
# ------------------------------------------------------------------------


# initialize in global scope - doesn't open FIFO until IPC_Helper.write()
to_ruby = IPC_Helper("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm")





# TODO: reset this "singleton" if the dimensions of the animation texture have changed
anim_tex_manager = None

def anim_texture_manager_singleton(context):
    global anim_tex_manager
    if anim_tex_manager == None:
        anim_tex_manager = AnimTexManager(context, to_ruby)
    
    return anim_tex_manager

def reset_anim_tex_manager(context):
    global anim_tex_manager
    mytool = context.scene.my_tool
    
    mytool.position_tex  = None
    mytool.normal_tex    = None
    mytool.transform_tex = None
    
    anim_tex_manager = None
















# ------------------------------------------------------------------------
#   User interface for animation texture export
#   (front end to OpenEXR export)
# ------------------------------------------------------------------------


import time
from progress_bar import ( OT_ProgressBarOperator )
OT_ProgressBarOperator = reload_class(OT_ProgressBarOperator)

from coroutine_decorator import *

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
        context = yield(0.0)
        
        tex_manager = anim_texture_manager_singleton(context)
        
        # Delegating to a subgenerator
        # https://www.python.org/dev/peps/pep-0380/
        # https://stackoverflow.com/questions/9708902/in-practice-what-are-the-main-uses-for-the-new-yield-from-syntax-in-python-3
        yield from tex_manager.export_all_textures()



class OT_TexAnimClearAllTextures (bpy.types.Operator):
    """Clear both animation textures"""
    bl_idname = "wm.texanim_clear_all_textures"
    bl_label = "Clear All 3 Textures"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        # clear_textures(context.scene.my_tool)
        
        reset_anim_tex_manager(context)
        
        mytool = context.scene.my_tool
        mytool.sync_deletions = False
        
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
        
        
        
        
        layout.row().separator()
        
        
        layout.label(text="check for deletions?")
        label = "Operator ON" if mytool.sync_deletions else "Operator OFF"
        layout.prop(mytool, 'sync_deletions', text=label, toggle=True)
        # ^ updated by OT_TexAnimSyncDeletions



























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
    # print('ortho scale -> sensor size')
    sensor_size = ortho_scale * space.lens / rv3d.view_distance
    # print(sensor_size)
    
    # then, with that constant sensor size, compute the dynamic ortho scale
    # print('that sensor size -> ortho scale')
    sensor_size = 71.98320027323571
    ortho_scale = rv3d.view_distance * sensor_size / space.lens
    # print(ortho_scale)
    
    # ^ this works now!
    #   but now I need to be able to automatically compute the sensor size...
    
    # (in the link below, there's supposed to be a factor of 2 involved in converting lens to FOV. Perhaps the true value of sensor size is 72, which differs from the expected 36mm by a factor of 2 ???)
    
    return ortho_scale

def calc_viewport_fov(rv3d):
    # src: https://blender.stackexchange.com/questions/46391/how-to-convert-spaceview3d-lens-to-field-of-view
    vmat_inv = rv3d.view_matrix.inverted()
    pmat = rv3d.perspective_matrix @ vmat_inv # @ is matrix multiplication
    fov = 2.0*math.atan(1.0/pmat[1][1])*180.0/math.pi;
    # print('rv3d fov:')
    # print(fov)
    
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
        self.__render_viewport(context, depsgraph)
        
    
    
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
    
    def __render_viewport(self, context, depsgraph):
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
        
        
        tex_manager = anim_texture_manager_singleton(context)
        
        
        # tex_manager.update(context)
        
        
        
        # collect up two different categories of messages
        # the datablock messages must be sent before entity messages
        # otherwise there will be issues with dependencies
        message_queue   = [] # list of dict
        
        active_object = context.active_object
        
        print(time.time())
        
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
                    # Don't really need to send this data on startup. the assumption should be that the texture holds most of the transform / vertex data in between sessions of RubyOF.
            
            # loop over all materials
            for mat in bpy.data.materials:
                if mat.users > 0:
                    tex_manager.update_material(context, mat)
            
            # ^ will be hard to test this until I adopt a structure that makes the initial big export unnecessary
            
            
            # TODO: want to separate out lights from meshes (objects)
            # TODO: want to send linked mesh data only once (expensive) but send linked light data every time (no cost savings for me to have linked lights in GPU render)
            
            
        elif active_object != None and active_object.mode == 'EDIT':
            # editing one object: only send edits to that single mesh
            
            bpy.ops.object.editmode_toggle()
            bpy.ops.object.editmode_toggle()
            # bpy.ops.object.mode_set(mode= 'OBJECT')
            
            print("mesh edit detected")
            print(active_object)
            
            
            tex_manager.update_mesh_datablock(active_object)
            
            
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
                print("update: ", update.is_updated_geometry, update.is_updated_shading, update.is_updated_transform)
                
                if isinstance(obj, bpy.types.Object):
                    if obj.type == 'LIGHT':
                        message_queue.append(pack_light(obj))
                        
                    elif obj.type == 'MESH':
                        # update mesh object (transform)
                        # sending updates to mesh datablocks if necessary
                        tex_manager.update_mesh_object(update, obj)
                
                # only send data for updated materials
                if isinstance(obj, bpy.types.Material):
                    # repack for all entities that use this material
                    # (like denormalising two database tables)
                    # transform with color info          material color info
                    
                    mat = obj
                    tex_manager.update_material(context, mat)
                    
            
            # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material.
        
        # ----------
        
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
        
        
        
        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'end',
        }
        
        to_ruby.write(json.dumps(data))
        
        
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
    
    
    def update_detect_playback(self, context):
        if self.detect_playback:
            bpy.ops.render.rubyof_detect_playback('INVOKE_DEFAULT')
        
        return None
    
    detect_playback : BoolProperty(
        name="Detect Playback",
        default=False,
        update=update_detect_playback
    )


# Use modal over the timer api, because the timer api involves threading,
# which then requires that you make your operation thread safe.
# That's all a huge pain just to get concurrency, 
# so for our use case, the modal operator is much better.
    # timer api:
    # self.timer = functools.partial(self.detect_deletions, mytool)
    # bpy.app.timers.register(self.timer, first_interval=self.timer_dt)
class RENDER_OT_RubyOF_DetectPlayback (bpy.types.Operator):
    """Watch for object deletions and sync them to the anim texture"""
    bl_idname = "render.rubyof_detect_playback"
    bl_label = "Detect Playback"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def __init__(self):
        self._timer = None
        self.timer_dt = 1/60
    
    def invoke(self, context, event):
        wm = context.window_manager
        
        self._timer = wm.event_timer_add(self.timer_dt, window=context.window)
        wm.modal_handler_add(self)
        
        self.setup(context)
        return {'RUNNING_MODAL'}
    
    def modal(self, context, event):
        # mytool = context.scene.my_tool
        
        if event.type == 'TIMER':
            self.run(context)
        
        if not context.scene.my_custom_props.detect_playback:
            context.window_manager.event_timer_remove(self._timer)
            return {'FINISHED'}
        
        return {'PASS_THROUGH'}
    
    def setup(self, context):
        self.old_names = None
        self.new_names = None
        
        self.bPlaying = context.screen.is_animation_playing
        self.frame = context.scene.frame_current
        # mytool = context.scene.my_tool
        
        # self.old_names = [ x.name for x in mytool.collection_ptr.all_objects ]
    
    def run(self, context):
        # test if animation is playing:
            # https://blenderartists.org/t/how-to-find-out-if-blender-is-currently-playing/576878/3
            # https://docs.blender.org/api/current/bpy.types.Screen.html#bpy.types.Screen
        # find the current frame:
            # https://blender.stackexchange.com/questions/55637/what-is-the-python-script-to-set-the-current-frame
        
        
        
        # screen = context.screen
        # print(screen.is_animation_playing, screen.is_scrubbing)
        
        # is_scrubbing
        
        if context.screen.is_scrubbing:
            # if scrubbing, we are also playing,
            # so need to check for scrubbing first
            print("scrubbing", context.scene.frame_current)
            # (does not trigger when stepping with arrow keys)
            
            data = {
                'type': 'timeline_command',
                'name': 'seek',
                'time': context.scene.frame_current
            }
            
            to_ruby.write(json.dumps(data))
            
            # Triggers multiple times per frame while scrubbing, if scrubber is held on one frame.
        else:
            # this is a bool, not a function
            if context.screen.is_animation_playing:
                if not self.bPlaying:
                    # transition from paused to playing
                    print("starting animation")
                    
                    data = {
                        'type': 'timeline_command',
                        'name': 'play',
                    }
                    
                    to_ruby.write(json.dumps(data))
                    
                    
            else:
                if self.bPlaying:
                    # transition from playing to paused
                    print("stopping animation")
                    
                    data = {
                        'type': 'timeline_command',
                        'name': 'pause',
                    }
                    
                    to_ruby.write(json.dumps(data))
        
        # NOTE: can't seem to use delta to detect if the animation is playing forward or in reverse. need to check if there is a flag for this that python can access
        
        delta = abs(self.frame - context.scene.frame_current)
        if delta == 1:
            # triggers when stepping with arrow keys,
            # and also on normal playback.
            # Triggers once per frame while scrubbing.
            
            # (is_scrubbing == false while stepping)
            
            print("step - frame", context.scene.frame_current)
            
        elif delta > 1:
            # triggers when using shift+right or shift+left to jump to end/beginning of timeline
            print("jump - frame", context.scene.frame_current)
                
            
        sys.stdout.flush();
        
        self.bPlaying = context.screen.is_animation_playing
        self.frame = context.scene.frame_current




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
        # print(context.engine)
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
        
        
        props = context.scene.my_custom_props
        
        
        if props.detect_playback:
            label = "Syncing Timeline" 
        else:
            label = "No Timeline Sync"
        layout.prop(props, "detect_playback", text=label, toggle=True)

















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
    # OT_DeleteOverride,
    #
    #
    RENDER_OT_RubyOF_StepBack,
    RENDER_OT_RubyOF_MessageStepForward,
    RENDER_OT_RubyOF_MessagePause,
    RENDER_OT_RubyOF_MessagePlay,
    RENDER_OT_RubyOF_MessageReverse,
    RENDER_OT_RubyOF_DetectPlayback,
    RubyOF_Properties,
    RubyOF_MATERIAL_Properties,
    DATA_PT_RubyOF_Properties,
    DATA_PT_RubyOF_light,
    DATA_PT_spot,
    RUBYOF_MATERIAL_PT_context_material,
    # 
    OT_TexAnimSyncDeletions,
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
    print("register")
    sys.stdout.flush()
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
    
    # register_depgraph_handlers()
    register_event_handlers()



def unregister():
    print("unregister")
    sys.stdout.flush()
    
    # unregister_depgraph_handlers()
    unregister_event_handlers()
    
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
    
    
