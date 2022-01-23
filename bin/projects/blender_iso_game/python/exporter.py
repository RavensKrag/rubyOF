
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


def get_object_transform(object):
    # this_mat = target_object.matrix_local
    this_mat = target_object.matrix_world
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



# 
# clean build of animation textures
# (mostly callbacks that get run by key operators)
# 


# TODO: when do I set context / scene? is setting on init appropriate? when do those values get invalidated?

# yields percentage of task completion, for use with a progress bar
@coroutine
def export_all_textures():
    
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
    
    
    tex_manager = anim_texture_manager_singleton(context)
    
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
    
    data = {
        'type': 'update_anim_textures',
        'position_tex_path' : self.position_tex.filepath,
        'normal_tex_path'   : self.normal_tex.filepath,
        'transform_tex_path': self.transform_tex.filepath,
    }
    
    self.to_ruby.write(json.dumps(data))
    
    
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
def update_entity_transform_with_armature(context, update, armature_obj):
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
def update_entity_transform_without_armature(context, update, mesh_obj):
    tex_manager = anim_texture_manager_singleton(context)
    
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
        
        data = {
            'type': 'update_transform',
            'position_tex_path' : self.position_tex.filepath,
            'normal_tex_path'   : self.normal_tex.filepath,
            'transform_tex_path': self.transform_tex.filepath,
        }
        
        self.to_ruby.write(json.dumps(data))
            
            
    
    
    # You won't get a message from depsgraph about a material being changed
    # until the object you're inspecting is the material.
    # Thus, you need to deal with the denormalization / update
    # of the material, in the material, and not here in the mesh.
    

# first export when blender switches into the RubyOF rendering mode
def export_initial(context, depsgraph):
    region = context.region
    view3d = context.space_data
    scene = depsgraph.scene
    
    
    # print("view update ---")
    
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
    
    return message_queue
    
    
    
# every export after the first export
# (send updated data only, in order to maintain synchronization)
def export_update(context, depsgraph):
    region = context.region
    view3d = context.space_data
    scene = depsgraph.scene
    
    
    # print("view update ---")
    
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
            
            to_ruby.write(json.dumps(data))
            
            
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
                        update_entity_transform_without_armature(context, update, obj)
                    elif obj.parent.type == 'ARMATURE':
                        # meshes attached to armatures will be exported with NLA animations, in a separate pass
                        pass
                    else: 
                        pass
                elif obj.type == 'ARMATURE':
                    update_entity_transform_with_armature(context, update, obj)
                    
                    
            
            # only send data for updated materials
            if isinstance(obj, bpy.types.Material):
                # repack for all entities that use this material
                # (like denormalising two database tables)
                # transform with color info          material color info
                
                mat = obj
                tex_manager.update_material(mat)
                
        
        # NOTE: An object does not get marked as updated when a new material slot is added / changes are made to its material.
        
    return message_queue
    


# send data generated in export_initial() or export_update() from python -> ruby
def export_ending(depsgraph, message_queue):
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
        
        print("syncing deletions", flush=True)
        # print("running", time.time())
        # print("objects: ", len(context.scene.objects))
        
        mytool = context.scene.my_tool
        
        self.new_names = [ x.name for x in mytool.collection_ptr.all_objects ]
        
        delta = list(set(self.old_names) - set(self.new_names))
        
        # print("old_names:", len(self.old_names), flush=True)
        # print("delta:", delta, flush=True)
        
        if len(delta) > 0:
            self.old_names = self.new_names
            
            tex_manager = anim_texture_manager_singleton(context)
            
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
    

