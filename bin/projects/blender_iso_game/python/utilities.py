
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


def first_material(mesh_object):
    mat_slots = mesh_object.material_slots
    
    # color = c1 = c2 = c3 = c4 = alpha = None
    
    if len(mat_slots) > 0:
        mat = mat_slots[0].material.rb_mat
        
    else:
        mat = None
    
    return mat

