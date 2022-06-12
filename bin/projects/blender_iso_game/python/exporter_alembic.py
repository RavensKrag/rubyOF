import bpy
import time
import json

import os

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





class ExporterAlembic():
    def __init__(self, to_ruby_fifo):
        self.to_ruby = to_ruby_fifo
        self.msg_count = 0
    
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
        
        # 
        # select all items in the specified collection for this texture set
        # 
        
        print("selection:", bpy.context.selected_objects)
        sel = bpy.context.selected_objects # returns immutable collection
        
        print("=>", prop_group.collection_ptr, flush=True)
        
        # adjust selection set
        # (may be a better way to select a whole collection, idk)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in prop_group.collection_ptr.all_objects:
            obj.select_set(True)
        
        
        context = yield( 1 / 3 )
        
        # 
        # export to alembic
        # 
        
        # name = prop_group.collection_ptr.name
        name = prop_group.name
        path = os.path.join(bpy.path.abspath(tex_manager.output_dir),
                            name+'.abc')
        
        bpy.ops.wm.alembic_export(
            filepath=path,
            start=0,
            end=1,
            selected=True,
            visible_objects_only=True,
            flatten=False,
            uvs=False, packuv=False,
            normals=True,
            face_sets=False,
            apply_subdiv=True,
            use_instancing=True,
            triangulate=True, quad_method='BEAUTY',
            export_hair=False,
            export_particles=False,
            export_custom_properties=False,
            # evaluation_mode='VIEWPORT'
            )
        
        context = yield( 2 / 3 )
        
        
        # 
        # restore previous selection set
        # 
        
        bpy.ops.object.select_all(action='DESELECT')
        for obj in sel:
            obj.select_set(True)
        # prop_group.collection_ptr
        
        # verify that selection is restored
        print("selection:", bpy.context.selected_objects, flush=True)
        
        
        
        
        # 
        # let RubyOF know that new animation textures have been exported
        # 
        filepaths = tex_manager.get_texture_paths()
        position_filepath, normal_filepath, entity_filepath = filepaths
        
        data = {
            'type': 'update_geometry_data',
            'comment': 'export all textures',
            'path': path,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        # context = yield( task_count / total_tasks )
        context = yield( 3 / 3 )
        
        
        t1 = time.time()
        
        print("time elapsed:", t1-t0, "sec")
        
    
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
    def __update_entity_transform_without_armature(self, scene, update, tex_manager, mesh_obj):
        
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
            
            mesh_updated = False
            if not m.has_mesh(mesh_obj.data.name):
                mesh_updated = True
                m.export_mesh(mesh_obj.data.name, mesh_obj.data)
            
            m.set_entity_transform(mesh_obj.name, get_object_transform(mesh_obj))
            m.set_entity_mesh(mesh_obj.name, mesh_obj.data.name)
            
            
            # must export material as well (just for this one entity)
            if(len(mesh_obj.material_slots) > 0):
                mat = mesh_obj.material_slots[0].material
                m.set_entity_material(mesh_obj.name, mat)
            
            
            filepaths = m.get_texture_paths()
            position_filepath, normal_filepath, entity_filepath = filepaths
            
            # update JSON file
            m.save()
            
            if mesh_updated:
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'created new entity with new mesh',
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
                
                bpy.ops.object.editmode_toggle()
                bpy.ops.object.editmode_toggle()
                # bpy.ops.object.mode_set(mode= 'OBJECT')
                
                print("mesh edit detected", flush=True)
                print(active_object, flush=True)
                
                
                # need to update the mesh,
                # but don't need to update bindings
                # (it's like using a pointer - no need to update references)
                
                mesh_data = active_object.evaluated_get(depsgraph).data
                
                tex_manager.export_mesh(active_object.data.name, mesh_data)
                
                
                filepaths = tex_manager.get_texture_paths()
                position_filepath, normal_filepath, entity_filepath = filepaths
                
                data = {
                    'type': 'update_geometry_data',
                    'comment': 'edit active mesh',
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
                
                
                bpy.ops.object.editmode_toggle()
                bpy.ops.object.editmode_toggle()
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
                            self.__update_entity_transform_without_armature(context.scene, update, tex_manager, obj)
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
        
        mytool = scene.my_tool
        collection_ptr = prop_group.collection_ptr
        
        if collection_ptr is None:
            return
        
        old_names = tex_manager.get_entity_names()
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
            
            
            filepaths = tex_manager.get_texture_paths()
            position_filepath, normal_filepath, entity_filepath = filepaths
            
            data = {
                'type': 'update_geometry_data',
                'comment': 'run garbage collection',
                'json_file_path': tex_manager.get_json_path(),
                'entity_tex_path': entity_filepath,
                'position_tex_path' : position_filepath,
                'normal_tex_path'   : normal_filepath,
            }
            
            self.to_ruby.write(json.dumps(data))
        # ---
    # ---
    
    