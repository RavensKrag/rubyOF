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
        self.scene_data = None
        self.draw_data = None
        self.fifo_path = "/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/run/blender_comm"
        
        # self.fifo = open(self.fifo_path, 'w')
        # print("FIFO open")

    # When the render engine instance is destroy, this is called. Clean up any
    # render engine data here, for example stopping running render threads.
    def __del__(self):
        pass
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
        if not self.scene_data:
            # First time initialization
            self.scene_data = []
            first_time = True

            # Loop over all datablocks used in the scene.
            for datablock in depsgraph.ids:
                pass
        else:
            first_time = False

            # Test which datablocks changed
            for update in depsgraph.updates:
                print("Datablock updated: ", update.id.name)

            # Test if any material was added, removed or changed.
            if depsgraph.id_type_updated('MATERIAL'):
                print("Materials updated")
        
        
        
        
        print("FIFO open")
        if os.path.exists(self.fifo_path):
            try:
                # text = text.encode('utf-8')
                pipe = open(self.fifo_path, 'w')
                
                
                # Loop over all object instances in the scene.
                if first_time or depsgraph.id_type_updated('OBJECT'):
                    print("obj update detected")
                    for instance in depsgraph.object_instances:
                        obj = instance.object
                        # print(instance)
                        # print(obj.type)
                        if obj.type == 'MESH':
                            print(obj)
                            
                            rot = obj.rotation_quaternion
                            pos = obj.location
                            
                            data = [
                                {
                                    'name': obj.name_full,
                                    'type': obj.type,
                                    'rotation':[
                                        "Quat",
                                        rot.w,
                                        rot.x,
                                        rot.y,
                                        rot.z
                                    ],
                                    'position':[
                                        "Vec3",
                                        pos.x,
                                        pos.y,
                                        pos.z
                                    ]
                                }
                            ]
                            pipe.write(json.dumps(data) + "\n")
                            pipe.close()
                
                print("---")
            except IOError as e:
                print("broken pipe error (suppressed exception)")
        
        

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
        
        
        print(camera_direction)
        # ^ note: camera objects have both lens (mm) and angle (fov degrees)
        
        print(space.clip_start)
        print(space.clip_end)
        # ^ these are viewport properties, not camera object properties
        
        
        print("FIFO open")
        if os.path.exists(self.fifo_path):
            try:
                # text = text.encode('utf-8')
                pipe = open(self.fifo_path, 'w')
                
                mat_p = rv3d.perspective_matrix
                mat_w = rv3d.window_matrix
                mat_v = rv3d.view_matrix
                
                rot = rv3d.view_rotation
                data = [
                    {
                        'type': 'viewport_camera',
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
                            context.scene.my_custom_props.fov
                        ],
                        'aspect_ratio':[
                            "???",
                            context.scene.my_custom_props.aspect_ratio
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
                ]
                
                if context.scene.my_custom_props.b_windowLink:
                    data += [
                        {
                            'type': 'viewport_region',
                            'width':  region.width,
                            'height': region.height,
                            'pid': os.getpid()
                        }
                    ]
                
                pipe.write(json.dumps(data) + "\n")
                pipe.close()
            except IOError as e:
                print("broken pipe error (suppressed exception)")
        
        
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
    
    fov: FloatProperty(
        name = "FOV",
        description = "Viewport field of view",
        default = 39.6,
        min = 0.0001,
        max = 100.0000
        )
    
    aspect_ratio: FloatProperty(
        name = "Aspect ratio",
        description = "Viewport aspect ratio",
        default = 16.0/9.0,
        min = 0.0001,
        max = 100.0000
        )


#
# Panel for properties (under Render Properties tab)
#
class RubyOF_PropertiesPanel(bpy.types.Panel):
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
        self.layout.prop(context.scene.my_custom_props, "fov")
        self.layout.prop(context.scene.my_custom_props, "aspect_ratio")
        
    











# RenderEngines also need to tell UI Panels that they are compatible with.
# We recommend to enable all panels marked as BLENDER_RENDER, and then
# exclude any panels that are replaced by custom panels registered by the
# render engine, or that are not supported.
def get_panels():
    exclude_panels = {
        'VIEWLAYER_PT_filter',
        'VIEWLAYER_PT_layer_passes',
    }
    
    panels = []
    for panel in bpy.types.Panel.__subclasses__():
        if hasattr(panel, 'COMPAT_ENGINES') and 'BLENDER_RENDER' in panel.COMPAT_ENGINES:
            if panel.__name__ not in exclude_panels:
                panels.append(panel)
    
    return panels

classes = (
    RubyOF_Properties,
    RubyOF_PropertiesPanel
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
