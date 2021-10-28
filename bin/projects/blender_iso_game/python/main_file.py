bl_info = {
    "name": "RubyOF renderer engine",
    "author": "Jason Ko",
    "version": (0, 0, 2),
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
                       FloatVectorProperty)

import time







import queue
import threading


import hashlib

import math


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
        'transform': pack_transform(obj),
        '.data.name': obj.data.name
    }
    
    return obj_data

def pack_mesh_data(mesh, shm_dir):
    mesh.calc_loop_triangles()
    # ^ need to call this to populate the mesh.loop_triangles() cache
    
    mesh.calc_normals_split()
    # normal_data = [ [val for val in tri.normal] for tri in mesh.loop_triangles ]
    # ^ normals stored on the tri / face
    
    
    # 
    # vert positions
    # 
    
    start_time = time.time()
    
    # number of actual verts likely to be less than maximum
    # so just measure the list
    num_verts = len(mesh.vertices)*3 # TODO: rename this variable
    vert_data = [None] * num_verts
    
    
    for i in range(len(mesh.vertices)):
        vert = mesh.vertices[i]
        
        vert_data[i*3+0] = vert.co[0]
        vert_data[i*3+1] = vert.co[1]
        vert_data[i*3+2] = vert.co[2]
    
    
    stop_time = time.time()
    dt = (stop_time - start_time) * 1000
    print("vertex export: ", dt, " msec" )
    
    
    # 
    # index buffer
    # 
    
    start_time = time.time()
    
    
    index_buffer = [ [vert for vert in tri.vertices] for tri in mesh.loop_triangles ]
    
    stop_time = time.time()
    dt = (stop_time - start_time) * 1000
    print("index export: ", dt, " msec" )
    
    
    # 
    # normal vectors
    # 
    
    start_time = time.time()
    
    num_tris = len(mesh.loop_triangles)
    
    num_normals = (num_tris * 3 * 3)
    normal_data = [None] * num_normals
    
    # iter3 = range(3)
    
    for i in range(num_tris):
        tri = mesh.loop_triangles[i]
        for j in range(3):
            normal = tri.split_normals[j]
            for k in range(3):
                idx = 9*i+3*j+k
                # print(idx)
                # print(i, ' ', j, ' ', k)
                normal_data[idx] = normal[k]
    
    
    
    stop_time = time.time()
    dt = (stop_time - start_time) * 1000
    print("normal export: ", dt, " msec" )
    
    
    # 
    # pack Base64 normal vector data
    # 
    
    start_time = time.time()
    
    # array -> binary blob
    binary_data = struct.pack('%df' % num_normals, *normal_data)
    
    # normal binary -> base 64 encoded binary -> ascii
    binary_string = base64.b64encode(binary_data).decode('ascii')
    
    
    sha = hashlib.sha1(binary_data).hexdigest()
    tmp_normal_file_path = os.path.join(shm_dir, "%s.txt" % sha)
    
    
    # tmp_normal_file_path = os.path.join(shm_dir, "normals.txt")
    
    if not os.path.exists(tmp_normal_file_path):
        with open(tmp_normal_file_path, 'w') as f:
            f.write(binary_string)
        
    stop_time = time.time()
    dt = (stop_time - start_time) * 1000
    print("shm file io (normals): ", dt, " msec" )
    
    
    # 
    # pack Base64 vertex data
    # 
    
    start_time = time.time()
    
    # array -> binary blob
    binary_data = struct.pack('%df' % num_verts, *vert_data)
    
    # normal binary -> base 64 encoded binary -> ascii
    binary_string = base64.b64encode(binary_data).decode('ascii')
    
    
    sha = hashlib.sha1(binary_data).hexdigest()
    tmp_vert_file_path = os.path.join(shm_dir, "%s.txt" % sha)
    
    
    # tmp_vert_file_path = os.path.join(self.shm_dir, "verts.txt")
    
    if not os.path.exists(tmp_vert_file_path):
        with open(tmp_vert_file_path, 'w') as f:
            f.write(binary_string)
        
    stop_time = time.time()
    dt = (stop_time - start_time) * 1000
    print("shm file io (verts): ", dt, " msec" )
    
    
    # 
    # Pack final mesh datablock data for FIFO transmission
    # 
    
    data = {
        'type': typestring(mesh),
        'name': mesh.name, # name of the data, not the object
        'verts': [
            'float', num_verts, tmp_vert_file_path
        ],
        'normals': [
            'float', num_normals, tmp_normal_file_path
        ],
        'tris' : index_buffer
    }
    
    return data



def pack_material(mat):
    data = {
        'type': typestring(mat),
        'name': mat.name,
        'color': [
            'FloatColor_rgb',
            mat.rb_mat.color[0],
            mat.rb_mat.color[1],
            mat.rb_mat.color[2],
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
    
to_ruby = IPC_Helper("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm")


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
        
        # collect up two different categories of messages
        # the datablock messages must be sent before entity messages
        # otherwise there will be issues with dependencies
        message_queue   = [] # list of dict
        mesh_datablocks = [] # list of datablock objects (various types)
        
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
                    mesh_datablocks.append(obj.data)
                    message_queue.append(pack_mesh(obj))
            
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
            
            
            mesh_datablocks.append(active_object.data)
            message_queue.append(pack_mesh(active_object))
            # TODO: try removing the object message and only sending the mesh data message. this may be sufficient, as the name linking the two should stay the same, and I don't think the object properties are changing.
            
            
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
                        if update.is_updated_geometry:
                            mesh_datablocks.append(obj.data)
                        message_queue.append(pack_mesh(obj))
                    
                    # if update.is_updated_transform:
                    #     obj_data['transform'] = pack_transform(obj)
                    
                    # if isinstance(obj.data, bpy.types.Light):
                    #     obj_data['data'] = self.__pack_light(obj.data)
                
                # only send data for updated materials
                if isinstance(obj, bpy.types.Material):
                    mat = obj
                    message_queue.append(pack_material(mat))
            
            # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material. Thus, we send a mapping of {mesh object name => material name} for all meshes, every frame. RubyOF will figure out when to actually rebind the materials.
            
        # ----------
        # TODO: if many objects use one mesh datablock, should only need to send that datablock once. old style did this, but the new style does not.
        
        # If many objects use one mesh datablock, 
        # should only send that datablock once.
        # That is why we need to group them all up before sending
        unique_datablocks = list(set(mesh_datablocks))
        for datablock in unique_datablocks:
            msg = pack_mesh_data(datablock, self.shm_dir)
            to_ruby.write(json.dumps(msg))
        
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
                print("found object with mesh")
                
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
                
                to_ruby.write(json.dumps(data))
        
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
        
    my_pointer: bpy.props.PointerProperty(type=bpy.types.Object)
    
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
    
    camera: bpy.props.PointerProperty(
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
    
    color: FloatVectorProperty(
        name = "Color",
        description = "Diffuse color",
        subtype = 'COLOR',
        default = (1.0, 1.0, 1.0), # white is default
        size = 3,
        # min = 0.0,
        # max = 1.0
        )
    
    
    specular: FloatVectorProperty(
        name = "specular color",
        description = "the color of highlights on a material",
        subtype = 'COLOR',
        default = (0.0, 0.0, 0.0), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    diffuse: FloatVectorProperty(
        name = "diffuse color",
        description = "the color of the material when it is illuminated",
        subtype = 'COLOR',
        default = (0.8, 0.8, 0.8), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    ambient: FloatVectorProperty(
        name = "ambient color",
        description = "the color of the material when it is not illuminated",
        subtype = 'COLOR',
        default = (0.2, 0.2, 0.2), # default from OpenFrameworks
        size = 3,
        min = 0.0,
        max = 1.0
        )
    
    emissive: FloatVectorProperty(
        name = "emissive color",
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




class MaterialButtonsPanel:
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "material"
    # COMPAT_ENGINES must be defined in each subclass, external engines can add themselves here

    @classmethod
    def poll(cls, context):
        mat = context.material
        return mat and (context.engine in cls.COMPAT_ENGINES) and not mat.grease_pencil


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
            layout.prop(mat.rb_mat, "color")
            
            layout.prop(mat.rb_mat, "specular")
            layout.prop(mat.rb_mat, "diffuse")
            layout.prop(mat.rb_mat, "ambient")
            layout.prop(mat.rb_mat, "emissive")
            
            col = layout.column()
            col.prop(mat.rb_mat, "alpha")
            col.prop(mat.rb_mat, "shininess")






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
    RUBYOF_MATERIAL_PT_context_material
)

def register():
    # Register the RenderEngine
    bpy.utils.register_class(RubyOF)
    
    for panel in get_panels():
        panel.COMPAT_ENGINES.add('RUBYOF')
    
    
    
    for c in classes:
        bpy.utils.register_class(c)
    
    # Bind variable for properties
    bpy.types.Scene.my_custom_props = bpy.props.PointerProperty(
            type=RubyOF_Properties
        )
    
    bpy.types.Material.rb_mat = bpy.props.PointerProperty(
            type=RubyOF_MATERIAL_Properties
        )
    


def unregister():
    bpy.utils.unregister_class(RubyOF)
    
    for panel in get_panels():
        if 'RUBYOF' in panel.COMPAT_ENGINES:
            panel.COMPAT_ENGINES.remove('RUBYOF')
    
    for c in reversed(classes):
        bpy.utils.unregister_class(c)



def main():
    print("hello world")
    register()
    
    
