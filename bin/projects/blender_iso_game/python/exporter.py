import bpy
import time
import json

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


class Exporter():
    def __init__(self, resource_manager_ref, to_ruby_fifo):
        self.resource_manager = resource_manager_ref
        self.to_ruby = to_ruby_fifo
    
    # 
    # clean build of animation textures
    # (mostly callbacks that get run by key operators)
    # 


    # TODO: when do I set context / scene? is setting on init appropriate? when do those values get invalidated?

    # yields percentage of task completion, for use with a progress bar
    @coroutine
    def export_all_textures(self):
        
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
        # 
        
        mytool.status_message = "collect mesh data"
        
        unique_pairs = find_unique_mesh_pairs(all_mesh_objects)
        mesh_objects    = [ obj       for obj, datablock in unique_pairs ]
        mesh_datablocks = [ datablock for obj, datablock in unique_pairs ]
        
        unqiue_meshes = [ obj.evaluated_get(depsgraph).data
                          for obj in mesh_objects ]
        
        # NOTE: If two objects use the same mesh datablock, but have different modifiers, their final meshes could be different. in this case, we ought to export two meshes to the texture. However, I think the current methodology would only export one mesh. In particular, the mesh that appears first in the collection list would have priority.
            # ^ may just ignore this for now. Although blender supports this workflow, I'm not sure that I personally want to use it.
        
        # unique_datablocks = list(set( [ x.data for x in all_mesh_objects ] )) 
        # # ^ will change the order of the data, which is bad
        
        context = yield( 0.0 )
        
        
        tex_manager = self.resource_manager.get_texture_manager(context)
        
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
            tex_manager.export_mesh(mesh.name, mesh)
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        # 
        # export all objects
        # 
        
        for i, obj in enumerate(all_mesh_objects):
            m = tex_manager
            m.set_object_mesh(     obj.name, obj.data.name)
            m.set_object_transform(obj.name, get_object_transform(obj))
            m.set_object_material( obj.name, first_material(obj))
            
            task_count += 1
            context = yield(task_count / total_tasks)
        
        
        # 
        # export name -> index mappings
        # 
            
        data = {
            'type': 'entity_name_map',
            'value': tex_manager.get_object_name_map(),
        }
        
        self.to_ruby.write(json.dumps(data))
        
        data = {
            'type': 'mesh_name_map',
            'value': tex_manager.get_mesh_name_map(),
        }
        
        self.to_ruby.write(json.dumps(data))
        
        context = yield( task_count / total_tasks )
        
        
        # 
        # let RubyOF know that new animation textures have been exported
        # 
        filepaths = tex_manager.get_texture_paths()
        position_filepath, normal_filepath, transform_filepath = filepaths
        
        data = {
            'type': 'update_anim_textures',
            'position_tex_path' : position_filepath,
            'normal_tex_path'   : normal_filepath,
            'transform_tex_path': transform_filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
        
        
        context = yield(task_count / total_tasks)
        
        
        # 
        # update json file
        # 
        
        tex_manager.save()
        
        context = yield(task_count / total_tasks)
        
        
        
        t1 = time.time()
        
        print("time elapsed:", t1-t0, "sec")
        
    
    # 
    # update animation textures
    # 

    # update data that would have been sent in pack_mesh():
    # so, the transform and what datablock the object is linked to

    # TODO: how do you handle objects that get renamed? is there some other unique identifier that is saved across sessions? (I think names in Blender are actually unique, but Blender works hard to make that happen...)


    # use transform on armature as entity transform
    # (may apply to more than 1 mesh)
    def __update_entity_transform_with_armature(self, context, update, armature_obj):
        pass
        # print("send update message")
        
        # data = {
        #     'type': 'update_transform',
        #     'position_tex_path' : self.position_tex.filepath,
        #     'normal_tex_path'   : self.normal_tex.filepath,
        #     'transform_tex_path': self.transform_tex.filepath,
        # }
        
        # self.to_ruby.write(json.dumps(data))
    
    # use transform on mesh object as entity transform
    # (will only apply to 1 mesh)
    def __update_entity_transform_without_armature(self, context, update, mesh_obj):
        tex_manager = self.resource_manager.get_texture_manager(context)
        
        if update.is_updated_transform:
            if tex_manager.has_object(mesh_obj.name):
                # 
                # update already existing object to have a new transform
                # 
                
                m = tex_manager
                m.set_object_transform(mesh_obj.name, get_object_transform(mesh_obj))
                
                
                print("moved object")
            else:
                # 
                # No object has existed in texture before
                # but there was an update to the transform?
                # 
                # must be a new object!
                # 
                print("NO OBJECT FOUND")
                
                # export new mesh (if necessary)
                # (may not need to export the mesh again)
                # bind mesh to object
                
                m = tex_manager
                
                if not m.has_mesh(mesh_obj.data.name):
                    m.export_mesh(mesh_obj.data.name, mesh_obj.data)
                
                m.set_object_mesh(mesh_obj.name, mesh_obj.data.name)
                
            
            
            # TODO: create a separate update message type for when transforms update
            # TODO: only send update message once per frame, not every frame
                # actually, this might still get slow to go through the disk like this... may want to just send a JSON message with the mat4 data in memory to update the live scene, but also update the changed scene on disk so that when it does eventually be reloaded from disk, that version is good too - no need to do a full export again.
            
            print("send update message")
            
            filepaths = tex_manager.get_texture_paths()
            position_filepath, normal_filepath, transform_filepath = filepaths
            
            data = {
                'type': 'update_transform',
                'position_tex_path' : position_filepath,
                'normal_tex_path'   : normal_filepath,
                'transform_tex_path': transform_filepath,
            }
            
            self.to_ruby.write(json.dumps(data))
                
                
        
        
        # You won't get a message from depsgraph about a material being changed
        # until the object you're inspecting is the material.
        # Thus, you need to deal with the denormalization / update
        # of the material, in the material, and not here in the mesh.
        
    
    # first export when blender switches into the RubyOF rendering mode
    def export_initial(self, context, depsgraph):
        tex_manager = self.resource_manager.get_texture_manager(context)
        
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
        
        
        
        # collect up two different categories of messages
        # the datablock messages must be sent before entity messages
        # otherwise there will be issues with dependencies
        message_queue   = [] # list of dict
        
        active_object = context.active_object
        
        # print(time.time())
        
        
        # Loop over all datablocks used in the scene.
        # for datablock in depsgraph.ids:
        
        # loop over all objects
        for obj in bpy.data.objects:
            if obj.type == 'LIGHT':
                message_queue.append(pack_light(obj))
                
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
        
        self.__export_ending(depsgraph, message_queue)
        
        
        
    # every export after the first export
    # (send updated data only, in order to maintain synchronization)
    def export_update(self, context, depsgraph):
        tex_manager = self.resource_manager.get_texture_manager(context)
        
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
        
        
        
        
        # collect up two different categories of messages
        # the datablock messages must be sent before entity messages
        # otherwise there will be issues with dependencies
        message_queue   = [] # list of dict
        
        active_object = context.active_object
        
        # print(time.time())
        
        
        if active_object != None and active_object.mode == 'EDIT':
            # NOTE: Assumes that object being edited is a mesh object, which is not necessarily true. This assumption causes problems when editing armatures.
            
            if isinstance(active_object, bpy.types.Object) and active_object.type == 'MESH':
                # editing one object: only send edits to that single mesh
                
                bpy.ops.object.editmode_toggle()
                bpy.ops.object.editmode_toggle()
                # bpy.ops.object.mode_set(mode= 'OBJECT')
                
                print("mesh edit detected")
                print(active_object)
                
                
                # need to update the mesh,
                # but don't need to update bindings
                # (it's like using a pointer - no need to update references)
                
                tex_manager.export_mesh(active_object.name, active_object)
                
                
                # (this will force reload of all textures, which may not be ideal for load times. but this will at least allow for prototyping)
                data = {
                    'type': 'update_geometry',
                    'scanline': i,
                    'position_tex_path' : self.position_tex.filepath,
                    'normal_tex_path'   : self.normal_tex.filepath,
                    'transform_tex_path': self.transform_tex.filepath,
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
                        message_queue.append(pack_light(obj))
                        
                    elif obj.type == 'MESH':
                        # update mesh object (transform)
                        # sending updates to mesh datablocks if necessary
                        
                        
                        if obj.parent is None:
                            self.__update_entity_transform_without_armature(context, update, obj)
                        elif obj.parent.type == 'ARMATURE':
                            # meshes attached to armatures will be exported with NLA animations, in a separate pass
                            pass
                        else: 
                            pass
                    elif obj.type == 'ARMATURE':
                        self.__update_entity_transform_with_armature(context, update, obj)
                        
                        
                
                # only send data for updated materials
                if isinstance(obj, bpy.types.Material):
                    # repack for all entities that use this material
                    # (like denormalising two database tables)
                    # transform with color info          material color info
                    
                    mat = obj
                    tex_manager.update_material(mat)
                    
            
            # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material.
            
        self.__export_ending(depsgraph, message_queue)
    
    
    
    # send data generated in export_initial() or export_update()
    # from python -> ruby
    def __export_ending(self, depsgraph, message_queue):
        # send out all the regular messages after the datablocks
        # to prevent dependency issues
        for msg in message_queue:
            self.to_ruby.write(json.dumps(msg))

        # full list of all objects, by name (helps Ruby delete old objects)
        data = {
            'type': 'all_entity_names',
            'list': [ instance.object.name_full for instance 
                        in depsgraph.object_instances ]
        }

        self.to_ruby.write(json.dumps(data))



        data = {
            'type': 'timestamp',
            'value': time.time(),
            'memo': 'end',
        }

        self.to_ruby.write(json.dumps(data))
    
