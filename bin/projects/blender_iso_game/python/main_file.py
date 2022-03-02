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

from exporter import Exporter
Exporter = reload_class(Exporter)






handler_types = {
    'on_save' : bpy.app.handlers.save_post,
    'on_load' : bpy.app.handlers.load_post,
    'on_undo' : bpy.app.handlers.undo_post,
    'on_redo' : bpy.app.handlers.redo_post,
    'before_frame_change' : bpy.app.handlers.frame_change_pre,
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
    tex_manager = resource_manager.get_texture_manager(context)
    tex_manager.load()


@persistent
def rubyof__on_save(*args):
    context = bpy.context
    tex_manager = resource_manager.get_texture_manager(context)
    tex_manager.save()


def rubyof__on_undo(scene):
    # print("on undo")
    # print(args)
    # sys.stdout.flush()
    
    context = bpy.context
    tex_manager = resource_manager.get_texture_manager(context)
    tex_manager.on_undo(scene)

def rubyof__on_redo(scene):
    # print("on undo")
    # print(args)
    # sys.stdout.flush()
    
    context = bpy.context
    tex_manager = resource_manager.get_texture_manager(context)
    tex_manager.on_redo(scene)


    

def register_event_handlers():
    register_callback('on_save', rubyof__on_save)
    register_callback('on_load', rubyof__on_load)
    register_callback('on_redo', rubyof__on_redo)
    register_callback('on_undo', rubyof__on_undo)
    
    register_callback('before_frame_change', rubyof__before_frame_change)
    
    
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












# TODO: move these class definitions to a separate file


# ------------------------------------------------------------------------
#   Live communication between Blender (python) and RubyOF (Ruby)
#   (uses FIFO to send JSON messages)
# ------------------------------------------------------------------------
import fcntl

class IPC_Writer():
    def __init__(self, fifo_path):
        self.fifo_path = fifo_path
        self.pipe = None
    
    def write(self, message):
        try:
            # If the pipe exists,
            # open it for writing
            if os.path.exists(self.fifo_path) and self.pipe is None:
                # opening file will throw exception if the file does not exist
                print("FIFO: open", flush=True)
                self.pipe = open(self.fifo_path, "w")
                
                # NOTE: open() and os.open() are different functions
                # https://stackoverflow.com/questions/30172428/python-non-block-read-file
                
                # # set NONBLOCK status flag
                # fd = self.pipe.fileno()
                # flag = fcntl.fcntl(fd, fcntl.F_GETFL)
                # fcntl.fcntl(fd, fcntl.F_SETFL, flag | os.O_NONBLOCK)
            
            
            # Once you have the pipe open, try to write messages into the pipe.
            # Subsequent calls to write() will write to the same pipe
            # until the pipe is broken. (no need to ever call close)
            if self.pipe is not None:
                start_time = time.time()
                # text = text.encode('utf-8') # <-- not needed
                
                self.pipe.write(message + "\n")
                self.pipe.flush()
                
                # print(message)
                # print("=> msg len:", len(message))
                stop_time = time.time()
                dt = (stop_time - start_time) * 1000
                
                # print("=> fifo data transfer: ", dt, " msec", flush=True)
                
            else:
                print("(no FIFO available; suppressing message)", flush=True)
            
        except FileNotFoundError as e:
            print("FIFO file not found", flush=True)
        # except IOError as e:
        except BrokenPipeError as e:
            # When all readers close, the writer will get a broken pipe signal.
            # At this point, the FIFO is invalid. (no need to call close)
            # 
            # You will get this signal even if the FIFO is removed
            # from the filesystem, as the file is not truely deleted
            # until the last file handle closes
                # https://stackoverflow.com/questions/2028874/what-happens-to-an-open-file-handle-on-linux-if-the-pointed-file-gets-moved-or-d
            # Additionally, the operating system will close all
            # open file handles when the application exits.
            # Thus, if Blender maintains a handle to the FIFO
            # after RubyOF terminates, it will be closed
            # when Python tries to write to the FIFO, or Blender exits,
            # whichever comes first.
                # https://stackoverflow.com/questions/45762323/what-happens-to-open-files-which-are-not-properly-closed?noredirect=1&lq=1
            
            print("FIFO: broken pipe error", flush=True)
            
            # self.pipe.close()
            # print("=> FIFO closed", flush=True)
            # ^ can't close the pipe at this point
            #   => ValueError: I/O operation on closed file.
            # Just need to set to None so future calls to write()
            # don't try to put more data into this invalid pipe.
            self.pipe = None
            
            # NOTE: deletion of the FIFO from the filesystem happens in Ruby code, blender_sync.rb
    
    
    # def __del__(self):
    #     if self.pipe is not None:
    #         self.pipe.close()
    #         print("outgoing FIFO closed", flush=True)


class IPC_Reader():
    def __init__(self, fifo_path):
        self.fifo_path = fifo_path
        self.pipe = None
        
        self.wait_flag = False # used for when Ruby resets and Blender must wait for FIFOs to be reestablished
    
    def read(self):
        # If you were told to wait, then short circuit if the FIFO path does not yet exist on the filesystem. We are waiting for Ruby to create the resources, so we'll just supress Blender messages.
        if self.wait_flag:
            if os.path.exists(self.fifo_path):
                self.wait_flag = False
                # (continue to the standard portion of function)
            else:
                # end here - do not perform the standard part of function
                return None
        
        
        
        
        # If the pipe exists,
        # open it for writing
        if os.path.exists(self.fifo_path) and self.pipe is None:
            # opening file will throw exception if the file does not exist
            print("FIFO: open", flush=True)
            self.pipe = open(self.fifo_path, "r")
            
            # NOTE: open() and os.open() are different functions
            # https://stackoverflow.com/questions/30172428/python-non-block-read-file
            
            # set NONBLOCK status flag
            fd = self.pipe.fileno()
            flag = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, flag | os.O_NONBLOCK)
        
        
        # Once you have the pipe open, try to write messages into the pipe.
        # Subsequent calls to write() will write to the same pipe
        # until the pipe is broken. (no need to ever call close)
        if self.pipe is not None:
            try:
                # text = text.encode('utf-8') # <-- not needed
                
                message_string = self.pipe.readline()
                # https://docs.python.org/3/library/io.html#io.StringIO
                # read() goes until EOF
                # readlines() goes until newline or EOF
                    # will return the empty string, "", when at EOF
                
                if message_string != "":
                    # print(message_string)
                    message = json.loads(message_string)
                    
                    return message
                else:
                    return None
                
            except FileNotFoundError as e:
                print("FIFO file not found", flush=True)
            
        else:
            return None
            
    
    def close(self):
        if self.pipe is not None:
            self.pipe.close()
            print("incoming FIFO closed", flush=True)
            
            self.pipe = None
    
    def wait_for_connection(self):
        self.wait_flag = True
        self.close()
    
    def __del__(self):
        if self.pipe is not None:
            self.pipe.close()
            print("incoming FIFO closed", flush=True)












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


# initialize in global scope - doesn't open FIFO until IPC_Writer.write()
# (hold paths to FIFOs in separate variables so they can be used in other code)

to_ruby = IPC_Writer("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm")

from_ruby = IPC_Reader("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm_reverse")




class ResourceManager():
    def __init__(self):
        # print("init resource manager", flush=True)
        self.anim_tex_manager = None
    
    
    # TODO: reset this "singleton" if the dimensions of the animation texture have changed
    def get_texture_manager(self, context):
        if self.anim_tex_manager is None:
            self.anim_tex_manager = AnimTexManager(context, to_ruby)
        
        return self.anim_tex_manager
    
    def clear_texture_manager(self, context):
        # print("try to clear texture manager", flush=True)
        if self.anim_tex_manager is not None:
            # print("clearing texture manager", flush=True)
            self.anim_tex_manager.clear(context)
            self.anim_tex_manager = None

resource_manager = ResourceManager()

# def anim_texture_manager_singleton(context):
#     global anim_tex_manager
#     if anim_tex_manager == None:
#         anim_tex_manager = AnimTexManager(context, to_ruby)
    
#     return anim_tex_manager

# def reset_anim_tex_manager(context):
#     global anim_tex_manager
    
#     anim_tex_manager.clear(context)
    
#     anim_tex_manager = None


# TODO: make it so the animation manager singleton can be accessed from anywhere where you have a reference to context

# maybe something similar to context.scene.my_tool ??
# need to then implement that calling structure in exporter.py
# before you can actually get any of these code to run
# (exporter.py currently calls anim_texture_manager_singleton(), which I don't think it is allowed to do)

# (but maybe you can't do that? are all classes like that necessarily saved in the Blend file? is that going to mess with things somehow?)

# if you can't do that,

# then every time you use tex_manager, it has to be passed in to that function,
# as only code in this file can call anim_texture_manager_singleton(),
# which is necessary to retrieve the texture manager

# ^ that is really annoying and non-intuitive if Exporter class exists. You would expect you could pass the object once when you init Exporter, but that probaby doesn't work. It seems like you sometimes need to regenerate the texture manager, given a new context object (re-wrapping the images)



export_helper = Exporter(resource_manager, to_ruby)














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
        
        
        tex_manager = resource_manager.get_texture_manager(context)
        # Delegating to a subgenerator
        # https://www.python.org/dev/peps/pep-0380/
        # https://stackoverflow.com/questions/9708902/in-practice-what-are-the-main-uses-for-the-new-yield-from-syntax-in-python-3
        yield from export_helper.export_all_textures()
        # ^ TODO: update this to the new export_all_textures() function in exporter.py



class OT_TexAnimClearAllTextures (bpy.types.Operator):
    """Clear both animation textures"""
    bl_idname = "wm.texanim_clear_all_textures"
    bl_label = "Clear All 3 Textures"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        # clear_textures(context.scene.my_tool)
        
        resource_manager.clear_texture_manager(context)
        
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
        
        
        
        # layout.row().separator()
        
        









































def focallength_to_fov(focal_length, sensor):
    return 2.0 * math.atan((sensor / 2.0) / focal_length)

def BKE_camera_sensor_size(sensor_fit, sensor_x, sensor_y):
    if (sensor_fit == CAMERA_SENSOR_FIT_VERT):
        return sensor_y;
    
    return sensor_x;

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
        
        
        data = {
            'type':"interrupt",
            'value': "RESET"
        }
        to_ruby.write(json.dumps(data))
        
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
        if self.first_time:
            # First time initialization
            self.first_time = False
            
            export_helper.export_initial(context, depsgraph)
        else:
            export_helper.export_update(context, depsgraph)
        
        
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
    
    
    
    ruby_buffer_size: IntProperty(
        name = "Ruby buffer size",
        description = "number of frames known to RubyOF history",
        default = 0,
        )
    
    
    
    def update_modal_loop(self, context):
        if self.b_modalUpdateActive:
            bpy.ops.render.rubyof_modal_update('INVOKE_DEFAULT')
        
        return None
    
    b_modalUpdateActive : BoolProperty(
        name="Modal update active",
        default=False,
        update=update_modal_loop
    )
    

# Use modal over the timer api, because the timer api involves threading,
# which then requires that you make your operation thread safe.
# That's all a huge pain just to get concurrency, 
# so for our use case, the modal operator is much better.
    # timer api:
    # self.timer = functools.partial(self.detect_deletions, mytool)
    # bpy.app.timers.register(self.timer, first_interval=self.timer_dt)
class ModalLoop (bpy.types.Operator):
    # bl_idname = "render.rubyof_modal_update"
    # bl_label = "modal operator update loop"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def __init__(self):
        
        self._timer = None
        self.timer_dt = 1/60
        
        self.old_names = None
        self.new_names = None
        
    
    def modal(self, context, event):
        if event.type == 'TIMER':
            self.run(context)
            
            # print("-------", flush=True)
            
            
            # why does it appear that I'm getting timer events on undo?
            # can the undo somehow cancel the modal entirely?
            
            
            
            # this strategy doesn't break blender on undo,
            # but it does put the update loop into an invalid state
            # (can also get into an invalid state if redo sets boolean flag)
            
            attr = getattr(self.rubyof_PropContext, self.rubyof_BoolPropName)
            # print(attr)
            # print(event)
            if attr is None:
                pass
                # property can't be read on undo.
                # why? not sure, but need to guard against it.
                
                # must gauard against this first, otherwise it will be matched by the 'attr == False' clause in the next branch
            elif attr == False:
                self.on_exit(context)
                
                context.window_manager.event_timer_remove(self._timer)
                return {'FINISHED'}
            else:
                pass
            
            
            
            
            # 
            # this strategy results in some sort of exception
            # or segfault that python can not recover from
            # 
            
            # try:
            #     if not self.rubyof_PropContext[self.rubyof_BoolPropName]:
            #         self.on_exit(context)
                    
            #         context.window_manager.event_timer_remove(self._timer)
            #         return {'FINISHED'}
            #     else:
            #         pass
            # except KeyError as e:
            #     # could not find property
            #     # assuming this happened because of undo
                
            #     # oops, can't progress from here - hit some sort of exception or segfault here
            #     pass
            
            
        
        return {'PASS_THROUGH'}
    
    def invoke(self, context, event):
        wm = context.window_manager
        
        self._timer = wm.event_timer_add(self.timer_dt, window=context.window)
        self.setup(context)
        
        
        wm.modal_handler_add(self)
        return {'RUNNING_MODAL'}
    
    
    def setup(self, context):
        self.rubyof_PropContext = context.scene.my_custom_props
        self.rubyof_BoolPropName = "read_from_ruby"
    
    def run(self, context):
        pass
    
    def on_exit(self, context):
        pass









class RENDER_OT_RubyOF_ModalUpdate (ModalLoop):
    """Use timer API and modal operator to generate periodic update tick"""
    bl_idname = "render.rubyof_modal_update"
    bl_label = "modal operator update loop"
    
    def setup(self, context):
        # these two variables must always be set,
        # otherwise the modal loop can not function
        self.rubyof_PropContext = context.scene.my_custom_props
        self.rubyof_BoolPropName = "b_modalUpdateActive"
        
        
        # other stuff can be set after that
        
        self.counter = 0
        
        data = {
            'type':"timeline_command",
            'name': "reset"
        }
        to_ruby.write(json.dumps(data))
        
        
        mytool = context.scene.my_tool
        
        self.old_names = [ x.name for x in mytool.collection_ptr.all_objects ]
        
        
        self.new_names = None
        
        self.bPlaying = context.screen.is_animation_playing
        self.frame = context.scene.frame_current
        # mytool = context.scene.my_tool
        
    
    def run(self, context):
        # 
        # sync object deletions
        # 
        
        # print("syncing deletions", flush=True)
        # print("running", time.time())
        # print("objects: ", len(context.scene.objects))
        
        mytool = context.scene.my_tool
        
        self.new_names = [ x.name for x in mytool.collection_ptr.all_objects ]
        
        delta = list(set(self.old_names) - set(self.new_names))
        
        # print("old_names:", len(self.old_names), flush=True)
        # print("delta:", delta, flush=True)
        
        if len(delta) > 0:
            self.old_names = self.new_names
            
            tex_manager = resource_manager.get_texture_manager(context)
            
            for name in delta:
                # print(delete)
                
                # TODO: make sure they're all mesh objects
                tex_manager.delete_object(name)
        
        
        # 
        # sync timeline
        # 
        
        self.counter = (self.counter + 1) % 10000
        
        scene = context.scene
        props = context.scene.my_custom_props
        
        # print("---", flush=True)
        
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
            self.print("scrubbing", context.scene.frame_current)
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
                    
                    self.print(f"starting animation @ {scene.frame_current}")
                    # self.print("scene.frame_end", scene.frame_end)
                    
                    
                    data = {
                        'type': 'timeline_command',
                        'name': 'play',
                    }
                    
                    to_ruby.write(json.dumps(data))
                    
                    
                    
                    # 
                    # Only expand timeline range when generating
                    # new state, not when replaying old state
                    # 
                    
                    
                    
                    # do not expand when hitting play in the past
                    # if scene.frame_current < scene.frame_end:
                    #     pass
                    #     # NO-OP
                    # else:
                    #     # expand when going past end of history, but not if we hit the Finished state
                    #     if self.bFinished:
                            # if scene.frame_current == scene.frame_end:
                                # props.ruby_buffer_size = 1000
                                # scene.frame_end = props.ruby_buffer_size
                        #     else:
                        #         pass
                        # else:
                        #     pass
                    
                    
                    
                        
                    # ^ this doesn't work.
                    #   forces pause when playing and transition from old state to new state, and allows for running off the end of the history buffer when hitting play during the Finished state.
                    
                    
                    
                    
                    # context.scene.my_custom_props.read_from_ruby = True
                    
                    
            else:
                if self.bPlaying:
                    # transition from playing to paused
                    
                    self.print("stopping animation")
                    
                    data = {
                        'type': 'timeline_command',
                        'name': 'pause',
                    }
                    
                    to_ruby.write(json.dumps(data))
        
        # Only expand timeline range when generating
        # new state, not when replaying old state
        # 
        # Can't compute this with a loopback callback
        # because it needs to happen right away -
        # can't wait in an async style for Ruby to respond.
        if context.screen.is_animation_playing and not context.screen.is_scrubbing and scene.frame_current == scene.frame_end:
            self.print("expand timeline")
            props.ruby_buffer_size = 1000
            scene.frame_end = props.ruby_buffer_size
            
        # NOTE: can't seem to use delta to detect if the animation is playing forward or in reverse. need to check if there is a flag for this that python can access
        
        if not context.screen.is_animation_playing:
            delta = abs(self.frame - context.scene.frame_current)
            if delta == 1:
                # triggers when stepping with arrow keys,
                # and also on normal playback.
                # Triggers once per frame while scrubbing.
                
                # (is_scrubbing == false while stepping)
                
                self.print("step - frame", context.scene.frame_current)
                
                data = {
                    'type': 'timeline_command',
                    'name': 'seek',
                    'time': context.scene.frame_current
                }
                
                to_ruby.write(json.dumps(data))
                
                
            elif delta > 1:
                # triggers when using shift+right or shift+left to jump to end/beginning of timeline
                self.print("jump - frame", context.scene.frame_current)
                
                data = {
                    'type': 'timeline_command',
                    'name': 'seek',
                    'time': context.scene.frame_current
                }
                
                to_ruby.write(json.dumps(data))
        
        
        # print("render.rubyof_detect_playback -- end of run", flush=True)
        
        self.bPlaying = context.screen.is_animation_playing
        self.frame = context.scene.frame_current
        
        
        
        
        message = from_ruby.read()
        if message is not None:
            # print("from ruby:", message, flush=True)
            
            
            if message['type'] == 'loopback_play+finished':
                self.print("finished - clamp to end of timeline")
                
                bpy.ops.screen.animation_cancel(restore_frame=False)
                
                props.ruby_buffer_size = message['history.length']-1
                scene.frame_end = props.ruby_buffer_size
                scene.frame_current = scene.frame_end
                
            
            # if message['type'] == 'loopback_started':
                # self.print("loopback - started generate new frames")
                
                
                # props.ruby_buffer_size = 1000
                # scene.frame_end = props.ruby_buffer_size
            
            # don't clamp timeline when pausing in the past
            if message['type'] == 'loopback_paused_old':
                self.print("loopback - paused old")
                
                self.print("history.length: ", message['history.length'])
                
                # props.ruby_buffer_size = message['history.length']-1
                # scene.frame_end = props.ruby_buffer_size
                
                # scene.frame_current = message['history.frame_index']
            
            # do clamp timeline when pausing while generating new state
            if message['type'] == 'loopback_paused_new':
                self.print("loopback - paused new")
                
                self.print("history.length: ", message['history.length'])
                
                props.ruby_buffer_size = message['history.length']-1
                scene.frame_end = props.ruby_buffer_size
                
                scene.frame_current = message['history.frame_index']
            
            if message['type'] == 'loopback_finished':
                self.print("loopback - finished")
                
                props.ruby_buffer_size = message['history.length']-1
                scene.frame_end = props.ruby_buffer_size
                
                bpy.ops.screen.animation_cancel(restore_frame=False)
                
                # scene.frame_current = scene.frame_end
                # ^ can't set to final frame every time,
                #   because that makes it very hard to
                #   leave the final timepoint by scrubbing etc.
                
            # After Blender's sync button is toggled off,
            # python will send a "reset" message to ruby,
            # to which ruby will respond back with 'loopback_reset'
            if message['type'] == 'loopback_reset':
                self.print("loopback - reset")
                
                props.ruby_buffer_size = message['history.length']-1
                scene.frame_end = props.ruby_buffer_size
                
                scene.frame_current = message['history.frame_index']
                
                bpy.ops.screen.animation_cancel(restore_frame=False)
            
            
            # ruby says sync needs to stop
            # maybe there was a crash, or maybe the program exited cleanly.
            if message['type'] == 'sync_stopping':
                self.print("sync_stopping")
                # scene.my_custom_props.read_from_ruby = False
                
                props.ruby_buffer_size = message['history.length']-1
                scene.frame_end = props.ruby_buffer_size
                
                props = context.scene.my_custom_props
                # props.b_modalUpdateActive = False
                
                from_ruby.wait_for_connection()
            
            if message['type'] == 'first_setup':
                self.print("first_setup")
                self.print("")
                self.print("")
                
                # reset timeline
                props.ruby_buffer_size = 0
                scene.frame_end = props.ruby_buffer_size
                
                scene.frame_current = scene.frame_end
                
                # send all scene data
                # (not yet implemented)
                
        
        
        
    
    def on_exit(self, context):
        self.print("on exit")
        context.scene.my_custom_props.b_modalUpdateActive = False
        
        from_ruby.close()
    
    # print with a 4-digit timestamp (wrapping counter of frames)
    # so its clear how much time elapsed between different
    # sections of the code.
    def print(self, *args):
        print(f'{self.counter:04}', *args, flush=True)

def rubyof__before_frame_change(scene):
    # pass 
    # print(args, flush=True)
    props = scene.my_custom_props
    
    # props.ruby_buffer_size = 10
    # print("buffer size:", props.ruby_buffer_size, flush=True)
    # print("current frame:", scene.frame_current, flush=True)
    
    # scene.frame_end = props.ruby_buffer_size
    
    
    if scene.frame_current == props.ruby_buffer_size:
        # stop and the end - otherwise blender will loop by jumping back to frame=0, which is not currently supported by the RubyOF connection
        bpy.ops.screen.animation_cancel(restore_frame=False)
    elif scene.frame_current > props.ruby_buffer_size:
        # prevent seeking past the end
        scene.frame_current = props.ruby_buffer_size
    

















































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
        
        
        
        props = context.scene.my_custom_props
        
        
        layout.prop(context.scene.my_custom_props, "ruby_buffer_size")
        
        if props.b_modalUpdateActive:
            label = "update loop enabled" 
        else:
            label = "update loop disabled"
        layout.prop(props, "b_modalUpdateActive", text=label, toggle=True)


























































































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
    RENDER_OT_RubyOF_ModalUpdate,
    # 
    RubyOF_Properties,
    RubyOF_MATERIAL_Properties,
    DATA_PT_RubyOF_Properties,
    DATA_PT_RubyOF_light,
    DATA_PT_spot,
    RUBYOF_MATERIAL_PT_context_material,
    # 
    #
    #
    #
    PG_MyProperties,
    OT_ProgressBarOperator,
    OT_TexAnimExportCollection,
    OT_TexAnimClearAllTextures,
    DATA_PT_texanim_panel3
)

# called on reload, to load in the new code
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
    
    
    # enable sync button
    props = bpy.context.scene.my_custom_props
    props.b_modalUpdateActive = False
    props.b_modalUpdateActive = True
    # (intentionally toggle on and off to force callback)
    
    
    

# called on reload, to unload the old code
def unregister():
    print("unregister")
    sys.stdout.flush()
    
    
    # disable sync button
    props = bpy.context.scene.my_custom_props
    props.b_modalUpdateActive = False
    # ^ calls from_ruby.close()
    
    
    # unregister_depgraph_handlers()
    unregister_event_handlers()
    
    bpy.utils.unregister_class(RubyOF)
    
    for panel in get_panels():
        if 'RUBYOF' in panel.COMPAT_ENGINES:
            panel.COMPAT_ENGINES.remove('RUBYOF')
    
    for c in reversed(classes):
        bpy.utils.unregister_class(c)
        
    
    del bpy.types.Scene.my_tool
    
    
    


# called on first load, to load up code that was never loaded before
def main():
    print("hello world")
    register()
    
    
