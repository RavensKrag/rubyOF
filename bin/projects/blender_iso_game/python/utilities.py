import bpy

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

# adapted from a method of the same name in Ruby,
# code based on implementation by nurettin, 2018.12.28
# but adapted for usage with numpy
# src: https://stackoverflow.com/questions/3833589/python-equivalent-of-rubys-each-slicecount
# 
# as in ruby, the last slice may be length < size
def each_slice(arr, chunk_size):
    # batch = 0
    # while batch * size < arr.size:
    #     yield arr[(batch*size):((batch+1)*size)]
    #     batch += 1
    
    # chunk_size = 150*3*4
    offset = 0
    i = 0
    while offset + chunk_size < arr.size:
        print(offset, offset+chunk_size, flush=True)
        yield arr[offset:offset+chunk_size]
        
        i += 1
        offset += chunk_size

    # perhaps store one more chunk that doesn't fill a full line
    if offset < arr.size:
        yield arr[offset:arr.size]



