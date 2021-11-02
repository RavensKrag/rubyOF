

from coroutine_decorator import *

# 
# Code to show progress bar using modal operator
# adapted from code by stackexchange user DB3D, answered Jul 26 at 13:34
# https://blender.stackexchange.com/questions/3219/how-to-show-to-the-user-a-progression-in-a-script
# https://devtalk.blender.org/t/have-modal-called-every-frame/9144
# 
# 
import bpy
import time

#Operation Dict
#operation will  need to be divided in multiple steps

sleep = 1

def _00(): 
    print("f00")
    time.sleep(sleep)
    
def _01(): 
    print("f01")
    time.sleep(sleep)
    
def _02(): 
    print("f02")
    time.sleep(sleep)
    
def _03(): 
    print("f03")
    time.sleep(sleep)
    
def _04(): 
    print("f04")
    time.sleep(sleep)
     
Operations = {
    "First Step":_00,
    "Second Step":_01,
    "Running Stuff":_02,
    "Wait a minute":_03,
    "There's a problem":_04,    
    "ah no it's ok":_04,    
    "we are done":_04,    
    }

class OT_ProgressBarOperator (bpy.types.Operator):
    """Operator that outputs to progress bar"""
    bl_idname = "wm.example_modal_operator"
    bl_label = "Output to progress bar"
    
    # @classmethod
    # def poll(cls, context):
    #     # return True
    
    def __init__(self):
        
        self.timer = None
        self.timer_dt = 1/30
        self.done = False
        
        self.timer_count = 0 #timer count, need to let a little bit of space between updates otherwise gui will not have time to update
        
        self.coroutine = None
        
        self.value = 0
        self.delay_interval = 30
    
    def setup(self, context):
        self.setup_properties() # use defaults
    
    # helper - shouldn't redefine this, but can't make it private because child classes need easy access to call this function
    def setup_properties(self, property_group=None, percent_field='', bool_field=''):
        self.property_group = property_group
        self.percent_property_name = percent_field
        self.bool_property_name = bool_field
    
    def modal(self, context, event):
        #update progress bar
        if not self.done:
            print(f"Updating: {self.value}")
            #update progess bar
            self.set_progress( self.value * 100 )
            
            #update label
            self.update_label()
            #send update signal
            context.area.tag_redraw()
            
            
        #by running a timer at the same time of our modal operator
        #we are guaranteed that update is done correctly in the interface
        
        if event.type == 'TIMER':
            
            #but wee need a little time off between timers to ensure that blender have time to breath, so we have updated inteface
            self.timer_count +=1
            if self.timer_count==self.delay_interval:
                self.timer_count=0
                
                if self.done:
                    print("Finished")
                    self.value = 0
                    self.set_progress( 0 )
                    context.window_manager.event_timer_remove(self.timer)
                    context.area.tag_redraw()
                    
                    self.set_flag( False )
                    
                    return {'FINISHED'}
            
                try:
                    if self.coroutine == None:
                        self.coroutine = self.run()
                        
                        # initialization part
                        self.value = self.coroutine.send(context)
                        
                        # looping part
                        self.value = self.coroutine.send(context)
                        
                    else:
                        self.value = self.coroutine.send(context)
                except StopIteration:
                    self.done=True
                    context.scene.my_tool.status_message = "finishing up..."
                except Exception as e:
                    self.set_flag( False )
                    raise
                
                return {'RUNNING_MODAL'}
        
        return {'RUNNING_MODAL'}
            
    def invoke(self, context, event):
        context.scene.my_tool.status_message = "starting..."
        self.setup(context)
        
        self.set_flag( True )
        
        
        print("")
        print("Invoke")
        
        context.window_manager.modal_handler_add(self)
        
        #run timer 
        self.timer = context.window_manager.event_timer_add(self.timer_dt, window=context.window)
        
        return {'RUNNING_MODAL'}
    
    def set_progress(self, value):
        self.property_group[self.percent_property_name] = value
    
    def set_flag(self, value):
        self.property_group[self.bool_property_name] = value
    
    def update_label(self):
        global Operations
        # context.object.progress_label = list(Operations.keys())[self.step]
    
    @coroutine
    def run(self):
        global Operations
        
        context = yield
        for key,val in Operations:
            val()
            yield
    

