import bpy
import time
import json
import re # regular expressions

from coroutine_decorator import *

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


def get_object_transform(obj):
    # this_mat = obj.matrix_local
    this_mat = obj.matrix_world
    # print(this_mat)
    # print(type(this_mat))

    identity_matrix = this_mat.Identity(4)

    # out_mat = identity_matrix
    out_mat = this_mat
    
    return out_mat


# Export first material on the mesh object,
# or the material called "Material"
def first_material(mesh_object):
    mat_slots = mesh_object.material_slots
    
    # color = c1 = c2 = c3 = c4 = alpha = None
    
    if len(mat_slots) > 0:
        mat = mat_slots[0].material
        
    else:
        mat = bpy.data.materials['Material']
    
    return mat






def typestring(obj):
    klass = type(obj)
    return f'{klass.__module__}.{klass.__qualname__}'


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
        ],
        
        'use_shadow' : obj.data.use_shadow,
        'shadow_clip_start': obj.data.shadow_buffer_clip_start,
        'shadow_clip_end' : obj.data.cutoff_distance,
        
        'shadow_buffer_bias' : obj.data.rb_light.shadow_buffer_bias,
            # need to convert the shadow map size from enum string to a number
        'shadow_map_size'    : int(obj.data.rb_light.shadow_map_size),
        'shadow_ortho_scale' : obj.data.rb_light.shadow_ortho_scale,
        'shadow_intensity'   : obj.data.rb_light.shadow_intensity
        
    }
    
    if data['.data.type'] == 'AREA':
        if obj.data.shape == 'SQUARE':
            data.update({
                'size_x': ['float', obj.data.size],
                'size_y': ['float', obj.data.size]
            })
        elif obj.data.shape == 'RECTANGLE':
            data.update({
                'size_x': ['float', obj.data.size],
                'size_y': ['float', obj.data.size_y]
            })
            
        else:
            pass
            
            
    elif data['.data.type'] == 'SPOT':
        data.update({
            'size': ['radians', obj.data.spot_size]
        })
    
    return data


def pack_transform(obj):
    # 
    # set transform properties
    # 
    
    loc,rot,scale = obj.matrix_world.decompose()
    # ^ decompose the world matrix to get transforms after applying constraints
    
    # loc   = obj.location
    # rot   = obj.rotation_quaternion
    # scale = obj.scale
    
    
    transform = {
        'position':[
            "Vec3",
            loc.x,
            loc.y,
            loc.z
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





class Exporter():
    def __init__(self, to_ruby_fifo):
        self.to_ruby = to_ruby_fifo
        self.msg_count = 0
        
        self.old_light_names = None
    
    # 
    # clean build of animation textures
    # (mostly callbacks that get run by key operators)
    # 


    # TODO: when do I set context / scene? is setting on init appropriate? when do those values get invalidated?

    # yields percentage of task completion, for use with a progress bar
    @coroutine
    def export_all_textures(self, scene, prop_group, tex_manager):
        
        yield(0) # initial yield to just set things up
        
        # 'context' is recieved via the first yield,
        # rather than a standard argument.
        #  This is passed via the class defined in progress_bar.py
        context = yield(0)
        
        
        
        t0 = time.time()
        
        
        mytool = scene.my_tool
        
        
        mytool.status_message = "eval dependencies"
        depsgraph = context.evaluated_depsgraph_get()
        context = yield(0.0)
        
        
        # RubyOF / Ruby:    entities have meshes
        # Blender / Python: objects have datablocks
        
        
        # collect up all the objects to export
        
        # for each object find the associated mesh datablock
            # reduce to the objects with unique mesh datablocks
            # generate evaluated meshes for those objects
            # map object -> mesh -> mesh scanline index
        
        # then export the transforms:
        # for each object
            # export object transform with mesh_id= mesh scanline index
        
        
        
        
        all_objects = prop_group.collection_ptr.all_objects
        
        
        all_mesh_objects = [ obj
                             for obj in prop_group.collection_ptr.all_objects
                             if obj.type == 'MESH' ]
        
        num_objects = len(all_mesh_objects)
        if num_objects > prop_group.max_num_objects:
            raise RuntimeError(f'Trying to export {num_objects} objects, but only have room for {prop_group.max_num_objects} in the texture. Please increase the size of the entity texture.')
        
        
        # 
        # create a list of unique evaluated meshes
        # 
        
        mytool.status_message = "collect mesh data"
        
        unique_pairs = find_unique_mesh_pairs(all_mesh_objects)
        mesh_objects    = [ obj       for obj, datablock in unique_pairs ]
        mesh_datablocks = [ datablock for obj, datablock in unique_pairs ]
        
        # NOTE: If two objects use the same mesh datablock, but have different modifiers, their final meshes could be different. in this case, we ought to export two meshes to the texture. However, I think the current methodology would only export one mesh. In particular, the mesh that appears first in the collection list would have priority.
            # ^ may just ignore this for now. Although blender supports this workflow, I'm not sure that I personally want to use it.
        
        # unique_datablocks = list(set( [ x.data for x in all_mesh_objects ] )) 
        # # ^ will change the order of the data, which is bad
        
        context = yield( 0.0 )
        
        
        # 
        # calculate how many tasks there are
        # 
        
        total_tasks = len(mesh_objects) + len(all_mesh_objects)
        task_count = 0
        
        context = yield( 0.0 )
        
        
        # 
        # export all unique meshes
        # (must export entities first, so linked entities work correctly)
        # 
        submesh_count = {}
        
        mytool.status_message = "export unique meshes"
        for i, obj in enumerate(mesh_objects):
            mesh = obj.evaluated_get(depsgraph).to_mesh()
            
            parts = tex_manager.export_mesh(mesh.name, mesh)
            
            submesh_count[mesh.name] = parts
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        
        # 
        # export all entities
        # 
        
        for i, obj in enumerate(all_mesh_objects):
            m = tex_manager
            
            
            m.set_entity_mesh(     obj.name, obj.data.name)
            m.set_entity_parent(obj.name, obj.name)
            m.set_entity_transform(obj.name, get_object_transform(obj))
            m.set_entity_material( obj.name, first_material(obj))
            
            # add extra linked entities to render additional parts
            self.__create_submesh_entities(tex_manager,
                                           submesh_count[obj.data.name], 
                                           obj.name, obj.data.name)
            
            # end for j
            task_count += 1
            context = yield(task_count / total_tasks)
        # end for i
        
        
        
        
        
        
        # 
        # update json file
        # 
        
        tex_manager.save()
        
        context = yield(task_count / total_tasks)
        
        
        
        # 
        # let RubyOF know that new animation textures have been exported
        # 
        filepaths = tex_manager.get_texture_paths()
        position_filepath, normal_filepath, entity_filepath = filepaths
        
        data = {
            'type': 'update_geometry_data',
            'comment': 'export batch',
            'name': tex_manager.name,
            'json_file_path': tex_manager.get_json_path(),
            'entity_tex_path': entity_filepath,
            'position_tex_path' : position_filepath,
            'normal_tex_path'   : normal_filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        context = yield( task_count / total_tasks )
        
        
        
        t1 = time.time()
        
        print("time elapsed:", t1-t0, "sec")
        
    
    
    def __export_all_submeshes(self):
        pass
    
    # assign extra render entities
    # but skip index 0, because that's the original entity
    # which was already exported
    def __create_submesh_entities(self, tex_manager, part_count, base_entity_name, base_mesh_name):
        m = tex_manager
        for j in range(1, part_count):
            child_entity_name = base_entity_name + ".part" + str(j+1)
            mesh_name         =   base_mesh_name + ".part" + str(j+1)
            m.set_entity_mesh(child_entity_name, mesh_name)
            m.set_entity_parent(child_entity_name, base_entity_name)
            # material and transform are both linked
        
    
    
    # 
    # update animation textures
    # 
    
    # TODO: how do you handle objects that get renamed? is there some other unique identifier that is saved across sessions? (I think names in Blender are actually unique, but Blender works hard to make that happen...)


    # use transform on armature as entity transform
    # (may apply to more than 1 mesh)
    def __update_entity_transform_with_armature(self, scene, update, tex_manager, armature_obj):
        pass
        # print("send update message")
        
        # data = {
        #     'type': 'update_transform',
        #     'position_tex_path' : self.position_tex.filepath,
        #     'normal_tex_path'   : self.normal_tex.filepath,
        #     'entity_tex_path': self.entity_tex.filepath,
        # }
        
        # self.to_ruby.write(json.dumps(data))
    
    # use transform on mesh object as entity transform
    # (will only apply to 1 mesh)
    def __update_entity_transform_without_armature(self, context, update, tex_manager, mesh_obj):
        scene = context.scene
        
        if not update.is_updated_transform:
            return
        
        
        print("transform updated:", mesh_obj.name)
        self.msg_count = self.msg_count + 1;
        if tex_manager.has_entity(mesh_obj.name):
            # 
            # update already existing object to have a new transform
            # 
            
            m = tex_manager
            m.set_entity_transform(mesh_obj.name, get_object_transform(mesh_obj))
            
            
            print("moved entity")
            
            
            filepaths = tex_manager.get_texture_paths()
            position_filepath, normal_filepath, entity_filepath = filepaths
            
            data = {
                'type': 'update_geometry_data',
                'comment': 'moved entity',
                'name': tex_manager.name,
                'json_file_path': tex_manager.get_json_path(),
                'position_tex_path' : position_filepath,
                'normal_tex_path'   : normal_filepath,
                'entity_tex_path': entity_filepath,
                'debug': [self.msg_count, mesh_obj.name, mesh_obj.data.name]
            }
            
            self.to_ruby.write(json.dumps(data))
            
        else:
            # 
            # No entity has existed in texture before
            # but there was an update to the transform?
            # 
            # must be a new entity!
            # 
            print("creating new entity")
            
            # export new mesh (if necessary)
            # (may not need to export the mesh again)
            # bind mesh to entity
            
            m = tex_manager
            obj = mesh_obj
            
            mesh_updated = False
            if not m.has_mesh(mesh_obj.data.name):
                mesh_updated = True
                
                # 
                # export main mesh part
                # 
                depsgraph = context.evaluated_depsgraph_get()
                mesh = obj.evaluated_get(depsgraph).to_mesh()
                parts = m.export_mesh(mesh.name, mesh)
                
                # 
                # export all entities
                # 
                
                # add extra linked entities to render additional parts
                self.__create_submesh_entities(tex_manager,
                                               parts, 
                                               obj.name, mesh.name)
            
            
            m.set_entity_mesh(     obj.name, obj.data.name)
            m.set_entity_parent(obj.name, obj.name) # must be after set mesh
            m.set_entity_transform(obj.name, get_object_transform(obj))
            m.set_entity_material( obj.name, first_material(obj))
            
            
            filepaths = m.get_texture_paths()
            position_filepath, normal_filepath, entity_filepath = filepaths
            
            # update JSON file
            m.save()
            
            if mesh_updated:
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'created new entity with new mesh',
                    'name': tex_manager.name,
                    'json_file_path': tex_manager.get_json_path(),
                    'position_tex_path' : position_filepath,
                    'normal_tex_path'   : normal_filepath,
                    'entity_tex_path': entity_filepath,
                    'debug': [self.msg_count, mesh_obj.name, mesh_obj.data.name]
                }
            else:
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'created new entity with existing mesh',
                    'name': tex_manager.name,
                    'json_file_path': tex_manager.get_json_path(),
                    'position_tex_path' : position_filepath,
                    'normal_tex_path'   : normal_filepath,
                    'entity_tex_path': entity_filepath,
                    'debug': [self.msg_count, mesh_obj.name, mesh_obj.data.name]
                }
                
            
            self.to_ruby.write(json.dumps(data))
            
        
        
        # TODO: only send update message once per frame, not every frame
            # actually, this might still get slow to go through the disk like this... may want to just send a JSON message with the mat4 data in memory to update the live scene, but also update the changed scene on disk so that when it does eventually be reloaded from disk, that version is good too - no need to do a full export again.
        
        print("send update message")
            
            
                
                
        
        
        # You won't get a message from depsgraph about a material being changed
        # until the object you're inspecting is the material.
        # Thus, you need to deal with the denormalization / update
        # of the material, in the material, and not here in the mesh.
        
    
    # first export when blender switches into the RubyOF rendering mode
    def export_initial(self, context, depsgraph, prop_group, tex_manager):
        region = context.region
        view3d = context.space_data
        scene = depsgraph.scene
        
        
        # print("view update ---")
        
        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'start',
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        
        
        active_object = context.active_object
        
        # print(time.time())
        
        
        # Loop over all datablocks used in the scene.
        # for datablock in depsgraph.ids:
        
        # loop over all objects
        for obj in bpy.data.objects:
            if obj.type == 'LIGHT':
                self.to_ruby.write(json.dumps(pack_light(obj)))
                
        #     elif obj.type == 'MESH':
        #         pass
        #         # Don't really need to send this data on startup. the assumption should be that the texture holds most of the transform / vertex data in between sessions of RubyOF.
        
        # # loop over all materials
        # for mat in bpy.data.materials:
        #     if mat.users > 0:
        #         tex_manager.update_material(context, mat)
        
        # # ^ will be hard to test this until I adopt a structure that makes the initial big export unnecessary
        
        
        # TODO: want to separate out lights from meshes (objects)
        # TODO: want to send linked mesh data only once (expensive) but send linked light data every time (no cost savings for me to have linked lights in GPU render)
        
        
        
        
    # every export after the first export
    # (send updated data only, in order to maintain synchronization)
    def export_update(self, context, depsgraph, prop_group, tex_manager):
        region = context.region
        view3d = context.space_data
        scene = depsgraph.scene
        
        
        # print("view update ---")
        
        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'start',
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        # all_objects = prop_group.collection_ptr.all_objects
        
        
        active_object = context.active_object
        
        # print(time.time())
        
        
        if active_object != None and active_object.mode == 'EDIT':
            if active_object.name not in prop_group.collection_ptr.all_objects:
                return
            
            # NOTE: Assumes that object being edited is a mesh object, which is not necessarily true. This assumption causes problems when editing armatures.
            
            if isinstance(active_object, bpy.types.Object) and active_object.type == 'MESH':
                # editing one object: only send edits to that single mesh
                
                # bpy.ops.object.editmode_toggle()
                # bpy.ops.object.editmode_toggle()
                # bpy.ops.object.mode_set(mode= 'OBJECT')
                
                print("mesh edit detected", flush=True)
                # print(active_object, flush=True)
                
                
                # need to update the mesh,
                # but don't need to update bindings
                # (it's like using a pointer - no need to update references)
                
                # depsgraph = context.evaluated_depsgraph_get()
                
                mesh_data = active_object.evaluated_get(depsgraph).to_mesh()
                # ^ use to_mesh() to apply the modifiers
                
                tex_manager.export_mesh(active_object.data.name, mesh_data)
                
                
                filepaths = tex_manager.get_texture_paths()
                position_filepath, normal_filepath, entity_filepath = filepaths
                
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'edit active mesh',
                    'name': tex_manager.name,
                    'json_file_path': tex_manager.get_json_path(),
                    'entity_tex_path': entity_filepath,
                    'position_tex_path' : position_filepath,
                    'normal_tex_path'   : normal_filepath,
                }
                
                self.to_ruby.write(json.dumps(data))
                
                
                # send material data if any of the materials on this object were changed
                # (maybe it the mat for this mesh? no way to tell, so just send it)
                if(depsgraph.id_type_updated('MATERIAL')):
                    if(len(active_object.material_slots) > 0):
                        mat = active_object.material_slots[0].material
                        tex_manager.update_material(mat)
                
                
                # bpy.ops.object.editmode_toggle()
                # bpy.ops.object.editmode_toggle()
                # bpy.ops.object.mode_set(mode= 'EDIT')
            
        else:
            # It is possible multiple things have been updated.
            # Could be a mixture of objects and/or materials.
            # Only send the data that has changed.
            
            # print("there are", len(depsgraph.updates), "updates to process")
            
            # Loop over all object instances in the scene.
            for update in depsgraph.updates:
                obj = update.id
                # print("update: ", update.is_updated_geometry, update.is_updated_shading, update.is_updated_transform)
                
                # TODO: limit this to exporting collection?
                
                
                if isinstance(obj, bpy.types.Object):
                    if obj.type == 'LIGHT':
                        self.to_ruby.write(json.dumps(pack_light(obj)))
                        
                        
                    elif obj.type == 'MESH':
                        if obj.name not in prop_group.collection_ptr.all_objects:
                            return
                        # update mesh object (transform)
                        # sending updates to mesh datablocks if necessary
                        
                        
                        if obj.parent is None:
                            self.__update_entity_transform_without_armature(context, update, tex_manager, obj)
                        elif obj.parent.type == 'ARMATURE':
                            # meshes attached to armatures will be exported with NLA animations, in a separate pass
                            pass
                        else: 
                            pass
                    elif obj.type == 'ARMATURE':
                        self.__update_entity_transform_with_armature(context.scene, update, tex_manager, obj)
                        
                        
                
                # only send data for updated materials
                if isinstance(obj, bpy.types.Material):
                    # repack for all entities that use this material
                    # (like denormalising two database tables)
                    # transform with color info          material color info
                    
                    mat = obj
                    tex_manager.update_material(mat)
                    
                    filepaths = tex_manager.get_texture_paths()
                    position_filepath, normal_filepath, entity_filepath = filepaths
                    
                    data = {
                        'type': 'update_geometry_data',
                        'comment': 'edit material for all instances',
                        'name': tex_manager.name,
                        'json_file_path': tex_manager.get_json_path(),
                        'entity_tex_path': entity_filepath,
                        'position_tex_path' : position_filepath,
                        'normal_tex_path'   : normal_filepath,
                    }
                    
                    self.to_ruby.write(json.dumps(data))
                    
            
            # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material.
         
         # ---
     # ---
    
    
    # Call this function every frame (or every update)
    # and compares the current list of entities to the previous list.
    # The difference set between these two
    # would tell you what entities were deleted.
    # (Was doing this before in Ruby, but now do it in Python)
    def gc(self, scene, prop_group, tex_manager):
        # TODO: Consider storing resource counts in the first pixel instead of alawys looping over all entities
        
        # TODO: how do you delete an entire texture set?
        
        # 
        # gc entities
        # 
        
        mytool = scene.my_tool
        collection_ptr = prop_group.collection_ptr
        
        if collection_ptr is not None:
            old_names = tex_manager.get_entity_parent_names()
            new_names = [ x.name for x in collection_ptr.all_objects ]
            delta = list(set(old_names) - set(new_names))
            
            
            # print("old_names:", len(old_names), flush=True)
            
            if len(delta) > 0:
                print("delta:", delta, flush=True)
                
            for name in delta:
                # print(delete)
                
                # TODO: make sure they're all mesh objects
                # ^ wait, this constraint may not be necessary once you export animations, and it may not actually even hold right now.
                
                tex_manager.delete_entity(name)
                # will this still work for animated things?
                # TODO: how do you delete meshes tha are bound to armatures?
                # TODO: how do you delete animation frames?
            
            
            # send signal to game engine that one or more entities in the texture have been deleted
            if len(delta) > 0: 
                filepaths = tex_manager.get_texture_paths()
                position_filepath, normal_filepath, entity_filepath = filepaths
                
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'delete entity',
                    'name': tex_manager.name,
                    'json_file_path': tex_manager.get_json_path(),
                    'entity_tex_path': entity_filepath,
                    'position_tex_path' : position_filepath,
                    'normal_tex_path'   : normal_filepath,
                }
                
                self.to_ruby.write(json.dumps(data))
        
        
        # 
        # gc lights
        # 
        
        # print("attempt to gc lights", flush=True)
        if self.old_light_names == None:
            self.old_light_names = []
        
        new_light_names = [x.name for x in bpy.data.objects if x.type == 'LIGHT']
        
        delta = list(set(self.old_light_names) - set(new_light_names))
        
        # print(self.old_light_names, flush=True)
        # print(self.old_light_names, flush=True)
        # print(delta, flush=True)
        
        if len(delta) > 0:
            data = {
                'type': 'delete_lights',
                'list': delta
            }
            
            self.to_ruby.write(json.dumps(data))
        
        
        self.old_light_names = new_light_names
        
        
        # ---
    # ---
    
    
