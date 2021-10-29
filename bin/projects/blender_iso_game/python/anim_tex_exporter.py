# based on blender addon template from stackexchange
# https://blender.stackexchange.com/questions/57306/how-to-create-a-custom-ui


# need extra help to reload classes:
# https://developer.blender.org/T66924
# by gecko man (geckoman), Jul 22 2019, 9:02 PM

import importlib, sys
# reloads class' parent module and returns updated class
def reload_class(c):
    mod = sys.modules.get(c.__module__)
    importlib.reload(mod)
    return mod.__dict__[c.__name__]


import os
from image_wrapper import ( ImageWrapper, get_cached_image )

ImageWrapper = reload_class(ImageWrapper)


import time
from progress_bar import ( OT_ProgressBarOperator, coroutine )
OT_ProgressBarOperator = reload_class(OT_ProgressBarOperator)




import bpy

#import collections

#import mathutils
#import math


from bpy.utils import ( register_class, unregister_class )
from bpy.props import ( StringProperty,
                        BoolProperty,
                        IntProperty,
                        FloatProperty,
                        FloatVectorProperty,
                        EnumProperty,
                        PointerProperty,
                       )
from bpy.types import ( Panel,
                        AddonPreferences,
                        Operator,
                        PropertyGroup,
                      )



# this must match the addon name, use '__package__'
# when defining this in a submodule of a python package.
addon_name = __name__      # when single file 
#addon_name = __package__   # when file in package 


# ------------------------------------------------------------------------
#   settings in addon-preferences panel 
# ------------------------------------------------------------------------


# panel update function for PREFS_PT_MyPrefs panel 
def _update_panel_fnc (self, context):
    #
    # load addon custom-preferences 
    print( addon_name, ': update pref.panel function called' )
    #
    main_panel =  OBJECT_PT_texanim_panel
    #
    main_panel .bl_category = context .preferences.addons[addon_name] .preferences.tab_label
    # re-register for update 
    unregister_class( main_panel )
    register_class( main_panel )


class PREFS_PT_MyPrefs( AddonPreferences ):
    ''' Custom Addon Preferences Panel - in addon activation panel -
    menu / edit / preferences / add-ons  
    '''

    bl_idname = addon_name

    tab_label: StringProperty(
            name="Tab Label",
            description="Choose a label-name for the panel tab",
            default="New Addon",
            update=_update_panel_fnc
    )

    def draw(self, context):
        layout = self.layout

        row = layout.row()
        col = row.column()
        col.label(text="Tab Label:")
        col.prop(self, "tab_label", text="")





# ------------------------------------------------------------------------
#   properties visible in the addon-panel 
# ------------------------------------------------------------------------


class PG_MyProperties (PropertyGroup):
    
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
    
    target_collection : PointerProperty(
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
    
    progress : bpy.props.FloatProperty(
        name="Progress",
        subtype="PERCENTAGE",
        soft_min=0, 
        soft_max=100, 
        precision=0,
    )
    
    running : bpy.props.BoolProperty(
        name="Running",
        default=False
    )
    
    status_message : bpy.props.StringProperty(
        name="Status message",
        default="exporting..."
    )

















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


def export_object_transforms(mytool, target_object, scanline=1, mesh_id=1):
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
    
    
    transform_tex.write_scanline(scanline_transform, scanline)
    
    
    transform_tex.save()























# ------------------------------------------------------------------------
#   operators
# ------------------------------------------------------------------------


def calc_geometry_tex_size(mytool):
    width_px  = mytool.max_tris*3 # 3 verts per triangle
    height_px = mytool.max_frames
    
    return [width_px, height_px]

class OT_TexAnimExport (bpy.types.Operator):
    """Export animations to vertex data, encoded in a texture"""
    bl_idname = "wm.texanim_export"
    bl_label = "Export Animation"
    
    def execute(self, context):
        scene = context.scene
        mytool = scene.my_tool
        
        for i in range(3):
            print("")
        
        # print the values to the console
        print("Hello World")
        print("target object:", mytool.target_object)
        print("max tris:", mytool.max_tris)
        
        
        
        # 
        # prepare target mesh
        # 
        
        # print(mytool.target_object)
        
        # mesh = mytool.target_object.data # basic mesh data before modifiers
        
        # get mesh data after modifiers are evaluated
        depsgraph = context.evaluated_depsgraph_get()
        object_eval = mytool.target_object.evaluated_get(depsgraph)
        mesh = object_eval.data
        
        export_vertex_data(mytool, mesh, mytool.output_frame);
        
        
        return {'FINISHED'}

class OT_TexAnimClearTextures (bpy.types.Operator):
    """Clear both animation textures"""
    bl_idname = "wm.texanim_clear_textures"
    bl_label = "Clear Textures"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        mytool = context.scene.my_tool
        
        mytool.position_tex = None
        mytool.normal_tex = None
        
        
        return {'FINISHED'}

class OT_TexAnimClearFrame (bpy.types.Operator):
    """Clear a single frame"""
    bl_idname = "wm.texanim_clear_frame"
    bl_label = "Clear Selected Frame"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        mytool = context.scene.my_tool
        
        # 
        # wrap images from property pointer in wrapper for convient API
        # 
        
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
        
        
        scanline_position = [0.0, 0.0, 0.0, 1.0] * pos_texture.width
        scanline_normals  = [0.0, 0.0, 0.0, 1.0] * norm_texture.width
        
        
        pos_texture.write_scanline(scanline_position, mytool.output_frame)
        norm_texture.write_scanline(scanline_normals, mytool.output_frame)
        
        
        return {'FINISHED'}


# ------------------------------------------------------------------------
#   addon - panel -- visible in objectmode
# ------------------------------------------------------------------------

class OBJECT_PT_texanim_panel (Panel):
    bl_idname = "OBJECT_PT_texanim_panel"
    bl_label = "AnimTex - vert data"
    bl_space_type = "VIEW_3D"   
    bl_region_type = "UI"
    bl_category = "Tool"  # note: replaced by preferences-setting in register function 
    bl_context = "objectmode"   


#   def __init(self):
#       super( self, Panel ).__init__()
#       bl_category = bpy.context.preferences.addons[__name__].preferences.category 

    @classmethod
    def poll(self,context):
        return context.object is not None

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        mytool = scene.my_tool
        
        layout.prop( mytool, "target_object")
        layout.prop( mytool, "output_dir")
        
        layout.prop( mytool, "name")
        
        
        # col = layout.column()
        # row = col.row(align=True)
        # row.operator("wm.texanim_use_exr", text="EXR")
        # row.operator("wm.texanim_use_png", text="PNG")
        
        layout.prop( mytool, "max_tris")
        layout.prop( mytool, "max_frames")
        layout.prop( mytool, "output_frame")
        
        layout.operator("wm.texanim_export")
        
        layout.row().separator()
        
        layout.operator("wm.texanim_clear_frame")
        layout.operator("wm.texanim_clear_textures")
        
        
        
        layout.menu( "OBJECT_MT_select_test", text="Presets", icon="SCENE")

# ------------------------------------------------------------------------
#   menus
# ------------------------------------------------------------------------

class MT_BasicMenu (bpy.types.Menu):
    bl_idname = "OBJECT_MT_select_test"
    bl_label = "Select"

    def draw(self, context):
        layout = self.layout

        # built-in example operators
        layout.operator("object.select_all", text="Select/Deselect All").action = 'TOGGLE'
        layout.operator("object.select_all", text="Inverse").action = 'INVERT'
        layout.operator("object.select_random", text="Random")
















# 
# This transform matrix data used by the GPU in the context of GPU instancing
# to draw various geometries that have been encoded onto textures.
# 
# This is not intended as an interchange format between Blender and RubyOF
# (it may be better to send individual position / rotation / scale instead)
# (so that way the individual components of the transform can be edited)
# 

def calc_transform_tex_size(mytool):
    # the transform texture must encode 2 things:
    
    # 1) a mat4 for the object's transform
    channels_per_pixel = 4
    mat4_size = 4*4;
    pixels_per_transform = mat4_size // channels_per_pixel;
    
    # 2) what mesh to use when rendering this object
    pixels_per_id_block = 1
    
    width_px  = pixels_per_id_block + pixels_per_transform
    height_px = mytool.max_num_objects
    
    return [width_px, height_px]

class OT_TexAnimExportTransforms (bpy.types.Operator):
    """Export animations to vertex data, encoded in a texture"""
    bl_idname = "wm.texanim_export_transforms"
    bl_label = "Export Transforms"
    
    def execute(self, context):
        scene = context.scene
        mytool = scene.my_tool
        
        for i in range(3):
            print("")
        
        # print the values to the console
        print("Hello World")
        print("target object:", mytool.target_object)
        
        
        export_object_transforms(mytool, mytool.target_object,
                                 scanline=mytool.transform_scanline,
                                 mesh_id=mytool.transform_id)
        
        
        return {'FINISHED'}


class OT_TexAnimClearOneTransform (bpy.types.Operator):
    """Clear both animation textures"""
    bl_idname = "wm.texanim_clear_one_transform"
    bl_label = "Clear One Transform"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        # clear_textures(context.scene.my_tool)
        
        mytool = context.scene.my_tool
        
        # 
        # wrap images from property pointer in wrapper for convient API
        # 
        
        transform_tex = ImageWrapper(
            get_cached_image(mytool, "transform_tex",
                             mytool.name+".transform",
                             size=calc_transform_tex_size(mytool),
                             channels_per_pixel=4),
            mytool.output_dir
        )
        
        
        scanline_transform = [0.0, 0.0, 0.0, 1.0] * transform_tex.width
        
        transform_tex.write_scanline(scanline_transform, mytool.transform_scanline)
        
        
        return {'FINISHED'}

class OT_TexAnimClearAllTransforms (bpy.types.Operator):
    """Clear a single frame"""
    bl_idname = "wm.texanim_clear_all_transforms"
    bl_label = "Clear ALL Transforms"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def execute(self, context):
        # clear_frame(context.scene.my_tool)
        
        mytool = context.scene.my_tool
        mytool.transform_tex = None
        
        return {'FINISHED'}




class OBJECT_PT_texanim_panel2 (Panel):
    bl_idname = "OBJECT_PT_texanim_panel2"
    bl_label = "AnimTex - transforms"
    bl_space_type = "VIEW_3D"   
    bl_region_type = "UI"
    bl_category = "Tool"  # note: replaced by preferences-setting in register function 
    bl_context = "objectmode"   


#   def __init(self):
#       super( self, Panel ).__init__()
#       bl_category = bpy.context.preferences.addons[__name__].preferences.category 

    @classmethod
    def poll(self,context):
        return context.object is not None

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        mytool = scene.my_tool
        
        layout.prop( mytool, "target_object")
        layout.prop( mytool, "output_dir")
        
        layout.prop( mytool, "name")
        
        layout.prop( mytool, "max_num_objects")
        layout.prop( mytool, "transform_scanline")
        layout.prop( mytool, "transform_id")
        
        layout.operator("wm.texanim_export_transforms")
        
        layout.row().separator()
        
        layout.operator("wm.texanim_clear_one_transform")
        layout.operator("wm.texanim_clear_all_transforms")
        




















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
        t0 = time.time()
        
        context = yield(0)
        
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
        
        
        
        
        all_objects = mytool.target_collection.all_objects
        
        
        
        # 
        # create a list of unique evaluated meshes
        # AND
        # map mesh datablock -> mesh id
        # so object transfoms and mesh ID can be paired up in transform export
        mytool.status_message = "collect mesh data"
        
        # don't need (obj -> mesh datablock) mapping
        # as each object already knows its mesh datablock
        
        meshID = 1
        
        unique_evaluated_meshes = []
        
        unique_mesh_datablocks = set()
        meshDatablock_to_meshID = {}
        
        for obj in all_objects:
            if obj.type == 'MESH':
                if obj.data in unique_mesh_datablocks:
                    pass
                    # if this datablock has already been seen,
                    # then the mapping to meshID is already set up
                else:
                    # never seen this datablock before
                    
                    # ASSUME: need the object to get the evaluated mesh
                    # (^ this assumption should be challenged)
                    
                    unique_mesh_datablocks.add(obj.data)
                    
                    
                    # evaluate meshes
                    object_eval = obj.evaluated_get(depsgraph)
                    mesh = object_eval.data
                    
                    # map datablock -> mesh id
                    meshDatablock_to_meshID[obj.data] = meshID
                    meshID += 1
                    
                    unique_evaluated_meshes.append(mesh)
        
        context = yield( 0.0 )
        
        # 
        # calculate how many tasks there are
        # 
        
        total_tasks = len(unique_evaluated_meshes) + len(all_objects)
        task_count = 0
        
        
        # 
        # export all unique meshes
        # 
        
        mytool.status_message = "export unique meshes"
        for i, mesh in enumerate(unique_evaluated_meshes):
            export_vertex_data(mytool, mesh, i+1) # handles triangulation
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        # 
        # export all objects
        # (transforms and associated mesh IDs)
        # 
        object_map = {}
        
        mytool.status_message = "export object transforms"
        for i, obj in enumerate(all_objects):
            export_object_transforms(mytool, obj,
                                     scanline=i+1,
                                     mesh_id=meshDatablock_to_meshID[obj.data])
            # map obj -> mesh ID
            
            object_map[obj.name] = i+1
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        # images = [
        #     mytool.position_tex,
        #     mytool.normal_tex,
        #     mytool.transform_tex
        # ]
        
        # for image in images:
        #     image.save_render(
        #         image.filepath_raw,
        #         scene=bpy.context.scene
        #     )
        
        mytool.status_message = "show object map"
        
        print(object_map)
        # ^ TODO: when integrated with main Blender -> RubyOF tools, need to dynamically send this mapping to RubyOF
        
        context = yield(task_count / total_tasks)
        
        t1 = time.time()
        
        print("time elapsed:", t1-t0, "sec")





class DATA_PT_texanim_panel3 (Panel):
    COMPAT_ENGINES= {"BLENDER_EEVEE"}
    
    bl_idname = "DATA_PT_texanim_panel3"
    bl_label = "AnimTex - all in collection"
    # bl_category = "Tool"  # note: replaced by preferences-setting in register function 
    bl_region_type = "WINDOW"
    bl_context = "output"   
    bl_space_type = "PROPERTIES"


#   def __init(self):
#       super( self, Panel ).__init__()
#       bl_category = bpy.context.preferences.addons[__name__].preferences.category 

    @classmethod
    def poll(self,context):
        return True

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        mytool = scene.my_tool
        
        layout.prop( mytool, "target_collection")
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






# ------------------------------------------------------------------------
# register and unregister
# ------------------------------------------------------------------------

classes = (
    PG_MyProperties,
    #
    OT_TexAnimExport,
    OT_TexAnimClearTextures,
    OT_TexAnimClearFrame,
    # 
    MT_BasicMenu,
    OBJECT_PT_texanim_panel, 
    #
    PREFS_PT_MyPrefs, 
    #
    #
    OT_TexAnimExportTransforms,
    OT_TexAnimClearOneTransform,
    OT_TexAnimClearAllTransforms,
    #
    # 
    OBJECT_PT_texanim_panel2,
    #
    #
    DATA_PT_texanim_panel3,
    OT_TexAnimExportCollection,
    OT_ProgressBarOperator
)

def register():
    #
    for cls in classes:
        register_class(cls)
    #
    bpy.types.Scene.my_tool = PointerProperty(type=PG_MyProperties)
    
    # print("test")
    #

def unregister():
    #
    for cls in reversed(classes):
        unregister_class(cls)
    #
    del bpy.types.Scene.my_tool  # remove PG_MyProperties 
