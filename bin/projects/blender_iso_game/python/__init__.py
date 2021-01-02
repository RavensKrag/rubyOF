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



def focallength_to_fov(focal_length, sensor):
    return 2.0 * math.atan((sensor / 2.0) / focal_length)

def BKE_camera_sensor_size(sensor_fit, sensor_x, sensor_y):
    if (sensor_fit == CAMERA_SENSOR_FIT_VERT):
        return sensor_y;
    
    return sensor_x;
    
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
        
        self.to_ruby = IPC_Helper("/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm")
        
        
        data = {
            'interrupt': 'RESET'
        }
        output_string = json.dumps(data)
        self.to_ruby.write(output_string)
        
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
        os.rmdir(self.shm_dir)
        
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
        
        data = self.__pack_viewport_camera(
            rotation         = rv3d.view_rotation,
            position         = camera_origin,
            lens             = space.lens,
            perspective_fov  = self.__viewport_fov(rv3d),
            ortho_scale      = self.__ortho_scale(context.scene, space, rv3d),
            # ortho_scale      = context.scene.my_custom_props.ortho_scale,
            near_clip        = space.clip_start,
            far_clip         = space.clip_end,
            view_perspective = rv3d.view_perspective
        )
        
        if context.scene.my_custom_props.b_windowLink:
            data['viewport_region'] = {
                'width':  region.width,
                'height': region.height,
                'pid': os.getpid()
            }
        
        output_string = json.dumps(data)
        self.to_ruby.write(output_string)
        
        
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

        # Get viewport dimensions
        dimensions = region.width, region.height
        print("view update ---")
        
        if self.first_time:
            # First time initialization
            self.first_time = False
            
            
            total_t0 = time.time()
            
            # Loop over all datablocks used in the scene.
            # for datablock in depsgraph.ids:
            
            datablock_list = [ obj.data for obj in bpy.data.objects ]
            
            datablock_export = self.export_unique_datablocks(datablock_list)
            
            
            obj_export = []
            
            # loop over all objects
            for obj in bpy.data.objects:
                obj_data = {
                    'name': obj.name_full,
                    'type': obj.type,
                }
                
                obj_data['transform'] = self.pack_transform(obj)
                obj_data['data'] = obj.data.name
                
                obj_export.append(obj_data)
            
            
            # TODO: want to separate out lights from meshes (objects)
            # TODO: want to send linked mesh data only once (expensive) but send linked light data every time (no cost savings for me to have linked lights in GPU render)
            
            
            total_t1 = time.time()
            dt = (total_t1 - total_t0) * 1000
            print("TOTAL TIME: ", dt, " msec" )
            
            
            data = {
                'timestamps' : {
                    'start_time': total_t0,
                    'end_time':   total_t1
                },
                
                'datablocks' : datablock_export,
                'objects' : obj_export
            }
            output_string = json.dumps(data)
            self.to_ruby.write(output_string)
        elif context.active_object.mode == 'EDIT':
            # editing one object: only send edits to that single mesh
            
            bpy.ops.object.editmode_toggle()
            bpy.ops.object.editmode_toggle()
            # bpy.ops.object.mode_set(mode= 'OBJECT')
            
            
            print("mesh edit detected")
            print(active_object)
            
            total_t0 = time.time()
            
            
            # full list of all objects, by name (helps Ruby delete old objects)
            object_list = [ instance.object.name_full for instance 
                            in depsgraph.object_instances ]
            
            
            obj_export = [
                {
                    'name': active_object.name_full,
                    'type': active_object.type,
                    'data': active_object.data.name
                }
            ]
            
            
            datablock_export = [
                self.pack_mesh_data(active_object.data)
            ]
            
            
            
            total_t1 = time.time()
            dt = (total_t1 - total_t0) * 1000
            print("TOTAL TIME: ", dt, " msec" )
            
            
            data = {
                'timestamps' : {
                    'start_time': total_t0,
                    'end_time':   total_t1
                },
                
                'all_entity_names' : object_list,
                
                'datablocks' : datablock_export,
                'objects' : obj_export
            }
            
            
            
            output_string = json.dumps(data)
            self.to_ruby.write(output_string)
            
            # bpy.ops.object.mode_set(mode= 'EDIT')
            bpy.ops.object.editmode_toggle()
            bpy.ops.object.editmode_toggle()
            
        elif depsgraph.id_type_updated('OBJECT'):
            # one or more objects have changed
            # only send the data that has changed.
            
            total_t0 = time.time()
            
            # Loop over all object instances in the scene.
            
            datablock_list = [] # datablocks that need to be packed up
            
            obj_export = []
            
            print("there are", len(depsgraph.updates), "updates to process")
            
            for update in depsgraph.updates:
                obj = update.id
                
                if isinstance(obj, bpy.types.Object):
                    obj_data = {
                        'name': obj.name_full,
                        'type': obj.type,
                    }
                    
                    if update.is_updated_transform:
                        obj_data['transform'] = self.pack_transform(obj)
                    
                    if update.is_updated_geometry:
                        obj_data['data'] = obj.data.name
                        datablock_list.append(obj.data)
                    
                    
                    obj_export.append(obj_data)
            
            
            datablock_export = self.export_unique_datablocks(datablock_list)
            
            
            # full list of all objects, by name (helps Ruby delete old objects)
            object_list = [ instance.object.name_full for instance 
                            in depsgraph.object_instances ]
            
            
            total_t1 = time.time()
            dt = (total_t1 - total_t0) * 1000
            print("TOTAL TIME: ", dt, " msec" )
            
            
            data = {
                'timestamps' : {
                    'start_time': total_t0,
                    'end_time':   total_t1
                },
                
                'all_entity_names' : object_list,
                
                'datablocks' : datablock_export,
                'objects' : obj_export
            }
            
            output_string = json.dumps(data)
            self.to_ruby.write(output_string)
            
        else:
            pass
        
        
        
        # print("not first time")
        
        
        # Test if any material was added, removed or changed.
        if depsgraph.id_type_updated('MATERIAL'):
            print("Materials updated")
            
            # for obj in bpy.data.objects:
            #     if isinstance(obj, bpy.types.Mesh):
                    
        
        
        # TODO: serialize and send materials that have changed
        # TODO: send information on which objects are using which materials
        
        # note: in blender, one object can have many material slots
    
    # ---- private helper methods ----
    
    
    def export_unique_datablocks(self, datablock_list):
        datablock_export = []
        
        unique_datablocks = list(set(datablock_list))
        for datablock in unique_datablocks:
            if isinstance(datablock, bpy.types.Mesh):
                datablock_export.append( self.pack_mesh_data(datablock) )
            elif isinstance(datablock, bpy.types.Light):
                datablock_export.append( self.__pack_light(datablock) )
            else:
                continue
        
        return datablock_export
        
    
    def pack_transform(self, obj):
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
        
    
    def pack_mesh_data(self, mesh):
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
        tmp_normal_file_path = os.path.join(self.shm_dir, "%s.txt" % sha)
        
        
        # tmp_normal_file_path = os.path.join(self.shm_dir, "normals.txt")
        
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
        tmp_vert_file_path = os.path.join(self.shm_dir, "%s.txt" % sha)
        
        
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
            'type': 'bpy.types.Mesh',
            'mesh_name': mesh.name, # name of the data, not the object
            'verts': [
                'float', num_verts, tmp_vert_file_path
            ],
            'normals': [
                'float', num_normals, tmp_normal_file_path
            ],
            'tris' : index_buffer
        }
        
        return data
    
        
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
    
    
    
    
    
    
    
    
    
    @staticmethod
    def __pack_light(light):
        data = {
            'light_name': light.name,
            'type': 'bpy.types.Light', 
            'color': [
                'rgb',
                light.color[0],
                light.color[1],
                light.color[2]
            ],
            'light_type': light.type,
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
        
        if light.type == 'AREA':
            data.update({
                'size_x': ['float', light.size],
                'size_y': ['float', light.size_y]
            })
        elif light.type == 'SPOT':
            data.update({
                'size': ['radians', light.spot_size]
            })
        
        return data
    
    
    @staticmethod
    def __pack_viewport_camera(rotation, position,
                            lens, perspective_fov, ortho_scale,
                            near_clip, far_clip,
                            view_perspective):
        return {
            'viewport_camera' : {
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
        }
    
    
    @staticmethod
    def __ortho_scale(scene, space, rv3d):
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
    
    @staticmethod
    def __viewport_fov(rv3d):
        # src: https://blender.stackexchange.com/questions/46391/how-to-convert-spaceview3d-lens-to-field-of-view
        vmat_inv = rv3d.view_matrix.inverted()
        pmat = rv3d.perspective_matrix @ vmat_inv # @ is matrix multiplication
        fov = 2.0*math.atan(1.0/pmat[1][1])*180.0/math.pi;
        print('rv3d fov:')
        print(fov)
        
        return fov
        
    
    
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
        # self.layout.label(text="Hello World")
        
        # self.layout.prop(context.scene.my_custom_props, "my_bool")
        # self.layout.prop(context.scene.my_custom_props, "my_float")
        # self.layout.prop(context.scene.my_custom_props, "my_pointer")
        
        # self.layout.label(text="Real Data Below")
        self.layout.prop(context.scene.my_custom_props, "alpha")
        self.layout.prop(context.scene.my_custom_props, "b_windowLink")
        self.layout.prop(context.scene.my_custom_props, "camera")
        # self.layout.prop(context.scene.my_custom_props, "aspect_ratio")
        self.layout.prop(context.scene.my_custom_props, "ortho_scale")
        
    
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
        
        
        col = layout.column()
        col.prop(mat.rb_mat, "color",)
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
    
    for c in classes:
        bpy.utils.unregister_class(c)
    


if __name__ == "__main__":
    print("hello world")
    register()
