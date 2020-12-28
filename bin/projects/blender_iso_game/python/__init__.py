bl_info = {
    "name": "RubyOF renderer engine",
    "author": "Jason Ko",
    "version": (0, 0, 1),
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
                       )

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
        
        self.fifo_path = "/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm"
        
        
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
        
        
        # self.fifo.close()
        # print("FIFO closed")
        
        
        
    
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
    
    
    def fifo_write(self, message):
        if os.path.exists(self.fifo_path):
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
            
            self.send_initial_data()
        else:
            if depsgraph.id_type_updated('OBJECT'):
                self.send_update_data(depsgraph)
            
            if context.active_object.mode == 'EDIT':
                bpy.ops.object.editmode_toggle()
                bpy.ops.object.editmode_toggle()
                # bpy.ops.object.mode_set(mode= 'OBJECT')
                self.send_mesh_edit_update(depsgraph, context.active_object)
                # bpy.ops.object.mode_set(mode= 'EDIT')
                
                bpy.ops.object.editmode_toggle()
                bpy.ops.object.editmode_toggle()

        
        
        # print("not first time")
        
        # Test if any material was added, removed or changed.
        if depsgraph.id_type_updated('MATERIAL'):
            print("Materials updated")
        
        print("there are", len(depsgraph.updates), "updates to process")
        
        
        
        
    
    
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
    
    def pack_light_data(self, light):
        data = {
            'light_name': light.name,
            'type': 'bpy.types.Light', 
            'color': [
                'rgb',
                light.color[0],
                light.color[1],
                light.color[2]
            ],
            # (there is a property on the object called "color" but that is not what you want)
            
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
    
    
    
    
    def send_initial_data(self):
        total_t0 = time.time()
        
        # Loop over all datablocks used in the scene.
        # for datablock in depsgraph.ids:
        
        
        # not sure whether to use bpy.data.objects or [instance.object for instance in depsgraph.object_instances]. Seems like they are the same unless maybe you're using instances (but linked duplicates are not instances)
        
        
        datablock_export = []
        
        datablock_list = [ obj.data for obj in bpy.data.objects ]
        unique_datablocks = list(set(datablock_list))
        for datablock in unique_datablocks:
            if isinstance(datablock, bpy.types.Mesh):
                datablock_export.append( self.pack_mesh_data(datablock) )
            elif isinstance(datablock, bpy.types.Light):
                datablock_export.append( self.pack_light_data(datablock) )
            else:
                continue
        
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
        
        # # loop over all objects
        # for instance in depsgraph.object_instances:
        #     obj = instance.object
            
        #     obj_data = {
        #         'name': obj.name_full,
        #         'type': obj.type,
        #     }
            
        #     obj_data['transform'] = self.pack_transform(obj)
        #     obj_data['data'] = obj.data.name
            
        #     obj_export.append(obj_data)
        
        
        
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
        self.fifo_write(output_string)
        
        
        
    # TODO: need to update this loop as well - don't want to re-pack all of the data when one mesh being used by 4000 instances gets updated. only want to pack that mesh data up 1x, not 4000x.
    def send_update_data(self, depsgraph):
        total_t0 = time.time()
        
        
        # Loop over all object instances in the scene.
        
        datablock_list = [] # datablocks that need to be packed up
        
        obj_export = []
        for update in depsgraph.updates:
            obj = update.id
            
            if isinstance(obj, bpy.types.Object):
                obj_data = {
                    'name': obj.name_full,
                    'type': obj.type,
                }
                
                if update.is_updated_transform:
                    print("Transform updated: ", update.id.name, '(', type(update.id) ,')')
                    obj_data['transform'] = self.pack_transform(obj)
                
                if update.is_updated_geometry:
                    print("Data updated: ", update.id.name, '(', type(update.id) ,')', '  type: ', obj.type)
                    obj_data['data'] = obj.data.name
                    
                    datablock_list.append(obj.data)
                    
                obj_export.append(obj_data)
        
        
        datablock_export = []
        
        unique_datablocks = list(set(datablock_list))
        for datablock in unique_datablocks:
            if isinstance(datablock, bpy.types.Mesh):
                datablock_export.append( self.pack_mesh_data(datablock) )
            elif isinstance(datablock, bpy.types.Light):
                datablock_export.append( self.pack_light_data(datablock) )
            else:
                continue
        
        
        # full list of all objects, by name (helps Ruby delete old objects)
        object_list = []
        for instance in depsgraph.object_instances:
            obj = instance.object
            object_list.append(obj.name_full)
        
        
        
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
        self.fifo_write(output_string)
        
    
    def send_mesh_edit_update(self, depsgraph, active_object):
        print("mesh edit detected")
        print(active_object)
        
        total_t0 = time.time()
        
        
        # full list of all objects, by name (helps Ruby delete old objects)
        object_list = []
        for instance in depsgraph.object_instances:
            obj = instance.object
            object_list.append(obj.name_full)
        
        
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
        self.fifo_write(output_string)
        
    
    
    # For viewport renders, this method is called whenever Blender redraws
    # the 3D viewport. The renderer is expected to quickly draw the render
    # with OpenGL, and not perform other expensive work.
    # Blender will draw overlays for selection and editing on top of the
    # rendered image automatically.
    def view_draw(self, context, depsgraph):
        # NOTE: if this function is too slow and it causes viewport flicker
        
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
        
        # print(space.clip_start)
        # print(space.clip_end)
        # # ^ these are viewport properties, not camera object properties
        
        
        h = region.height
        w = region.width
        
        # camera sensor size:
        # 36 mm is the default, with sensor fit set to 'AUTO'
        print("focal length: ")
        print(context.space_data.lens)
        
        
        print("FOV (assuming sensor 50mm): ")
        hfov = focallength_to_fov(context.space_data.lens, 50)
        print(hfov / (2*math.pi)*360)
        
        vfov = 2.0 * math.atan( math.tan(hfov/2.0) * h/w )
        print(vfov / (2*math.pi)*360)
        
        
        
        print("FOV (assuming sensor 36mm): ")
        hfov = focallength_to_fov(context.space_data.lens, 36)
        print(hfov / (2*math.pi)*360)
        
        vfov = 2.0 * math.atan( math.tan(hfov/2.0) * h/w )
        print(vfov / (2*math.pi)*360)
        
        
        
        print("FOV (assuming sensor 24mm): ")
        hfov = focallength_to_fov(context.space_data.lens, 24)
        print(hfov / (2*math.pi)*360)
        
        vfov = 2.0 * math.atan( math.tan(hfov/2.0) * h/w )
        print(vfov / (2*math.pi)*360)
        
        
        
        # rv3d->dist * sensor_size / v3d->lens
        # ortho_scale = rv3d.view_distance * sensor_size / context.space_data.lens;
        
            # (ortho_scale * context.space_data.lens) / rv3d.view_distance = sensor_size
        print('ortho scale -> sensor size')
        print((context.scene.my_custom_props.ortho_scale * context.space_data.lens) / rv3d.view_distance)
        
        # src: https://blender.stackexchange.com/questions/46391/how-to-convert-spaceview3d-lens-to-field-of-view
        vmat_inv = rv3d.view_matrix.inverted()
        pmat = rv3d.perspective_matrix @ vmat_inv
        fov = 2.0*math.atan(1.0/pmat[1][1])*180.0/math.pi;
        print('rv3d fov:')
        print(fov)
        
        # print('rv3d fov -> ortho scale')
        # ortho_scale = rv3d.view_distance * sensor_size / context.space_data.lens;
        # print(ortho_scale)
        
        
        mat_p = rv3d.perspective_matrix
        mat_w = rv3d.window_matrix
        mat_v = rv3d.view_matrix
        
        rot = rv3d.view_rotation
        data = {
            'viewport_camera' : {
                'rotation':[
                    "Quat",
                    rot.w,
                    rot.x,
                    rot.y,
                    rot.z
                ],
                'position':[
                    "Vec3",
                    camera_origin.x,
                    camera_origin.y,
                    camera_origin.z
                ],
                'lens':[
                    "mm",
                    context.space_data.lens
                ],
                'fov':[
                    "deg",
                    fov
                ],
                'near_clip':[
                    'm',
                    space.clip_start
                ],
                'far_clip':[
                    'm',
                    space.clip_end
                ],
                # 'aspect_ratio':[
                #     "???",
                #     context.scene.my_custom_props.aspect_ratio
                # ],
                'ortho_scale':[
                    "factor",
                    context.scene.my_custom_props.ortho_scale
                ],
                'view_perspective': rv3d.view_perspective,
                'perspective_matrix':[
                    'Mat4',
                    mat_p[0][0], mat_p[0][1], mat_p[0][2], mat_p[0][3],
                    mat_p[1][0], mat_p[1][1], mat_p[1][2], mat_p[1][3],
                    mat_p[2][0], mat_p[2][1], mat_p[2][2], mat_p[2][3],
                    mat_p[3][0], mat_p[3][1], mat_p[3][2], mat_p[3][3]
                ],
                'window_matrix':[
                    'Mat4',
                    mat_w[0][0], mat_w[0][1], mat_w[0][2], mat_w[0][3],
                    mat_w[1][0], mat_w[1][1], mat_w[1][2], mat_w[1][3],
                    mat_w[2][0], mat_w[2][1], mat_w[2][2], mat_w[2][3],
                    mat_w[3][0], mat_w[3][1], mat_w[3][2], mat_w[3][3]
                ],
                'view_matrix':[
                    'Mat4',
                    mat_v[0][0], mat_v[0][1], mat_v[0][2], mat_v[0][3],
                    mat_v[1][0], mat_v[1][1], mat_v[1][2], mat_v[1][3],
                    mat_v[2][0], mat_v[2][1], mat_v[2][2], mat_v[2][3],
                    mat_v[3][0], mat_v[3][1], mat_v[3][2], mat_v[3][3]
                ]
            }
        }
        
        if context.scene.my_custom_props.b_windowLink:
            data['viewport_region'] = {
                'width':  region.width,
                'height': region.height,
                'pid': os.getpid()
            }
        
        output_string = json.dumps(data)
        # self.outbound_queue.put(output_string)
        self.fifo_write(output_string)
        
        
                
                
        
        
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
        min = 1,
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
    DATA_PT_RubyOF_Properties,
    DATA_PT_RubyOF_light,
    DATA_PT_spot
)

def register():
    # Register the RenderEngine
    bpy.utils.register_class(RubyOF)
    
    for panel in get_panels():
        panel.COMPAT_ENGINES.add('RUBYOF')
    
    
    
    for c in classes:
        bpy.utils.register_class(c)
    
    # Bind variable for properties
    bpy.types.Scene.my_custom_props = bpy.props.PointerProperty(type=RubyOF_Properties)
    


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
