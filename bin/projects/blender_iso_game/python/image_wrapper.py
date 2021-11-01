import os
import bpy


def is_valid_anim_tex(image, width_px, height_px):
    if image == None:
        return False
    else:
        width_prev,height_prev = image.size
        if width_px != width_prev or height_px != height_prev:
            return False
        else:
            return True
    

def allocate_texture(name, width=1, height=1, channels_per_pixel=4, alpha=True, float_buffer=True):
    
    input_width = width
    input_height = height
    input_alpha = alpha
    input_float_buff = float_buffer
    
    
    # if an image already exists the blend file with the same name,
    # delete that one before creating a new one
    # (otherwise, creating a new image with the same name create a new image)
    
    if name in bpy.data.images:
        cached_image = bpy.data.images[name]
        bpy.data.images.remove(cached_image)
    
    image = bpy.data.images.new(
        name, 
        width=input_width, height=input_height,
        alpha=input_alpha, float_buffer=input_float_buff
    )
    
    # 
    # something code below appears to reset the image data
    # 
    
    image.file_format = 'OPEN_EXR'
    # image.use_half_precision = False
    
    
    # image.colorspace_settings.name = 'sRGB'
    # image.colorspace_settings.name = 'Linear'
    # image.colorspace_settings.name = 'Raw'
    image.colorspace_settings.name = 'Non-Color'

    if channels_per_pixel == 4:
        # image.use_alpha = True
        image.alpha_mode = 'STRAIGHT'
        # image.alpha_mode = 'PREMUL'
    elif channels_per_pixel == 3:
        image.alpha_mode = 'NONE'
    else:
        pass

    print("alpha mode:", image.alpha_mode)
    
    
    return image


# ASSUME: input variable "cache" implements dictionary-style get and set, but if the key is not defined, the value returned is None. If "cache" is a ProperyGroup which contains a PointerProperty called "property", then this is the exact interface you will get. However, the python dictionary type itself is different. The python dict will instead raise an exception if the key does not exist.
def get_cached_image(cache, property, texture_name, size=[1,1], channels_per_pixel=4):
    
    width  = size[0]
    height = size[1]
    
    if not is_valid_anim_tex(getattr(cache, property), width, height):
        print("new texture for:", property)
        
        setattr(cache, property, allocate_texture(
            texture_name,
            width=width, height=height,
            alpha=True, float_buffer=True,
            channels_per_pixel=channels_per_pixel
        ))
        
        getattr(cache, property).reload()
    
    return getattr(cache, property)


class ImageWrapper():
    
    def __init__(self, image, dir):
        width,height = image.size
        
        self.width = width
        self.height = height
        
        # 
        # create image
        # 
        
        print(image)
        self.image = image
        
        self.channels_per_pixel = image.channels
        
        # 
        # prep path where image will be saved
        # 
        
        # add extension to match format
        path = os.path.join(bpy.path.abspath(dir), self.image.name+'.exr')
        
        # self.image.filepath = path
        self.image.filepath_raw = path
        print(self.image.filepath)
    
    
    # reload from disk
    def reload(self):
        self.image.reload() # "Reload the image from it's source path"
    
    # save image to disk
    def save(self):
        # TODO: insure the image is always an EXR file
        # print("float?:", self.image.is_float)
        
        
        # self.image.save()
        # ^ save using... not sure what settings this uses, honestly
        
        self.image.save_render(
            self.image.filepath_raw,
            scene=bpy.context.scene
        )
        # ^ save using scene settings - easiest way to configure OpenEXR save
        #   However, regaurdless of the addon's settings, the scene's settings must be set to OpenEXR rendering, or the output will become weird. May want to include proper settings in the addon, or may want to eliminate PNG vs EXR setting in the addon, and just alawys use the scene settings.
        
    
    def write_scanline(self, pixel_data, row):
        # print("writing scanline")
        # print([px for px in self.image.pixels])
        
        px_per_scanline = self.width*self.channels_per_pixel
        
        offset = px_per_scanline*row
        
        for i in range(px_per_scanline):
            self.image.pixels[offset+i] = pixel_data[i]
            
        # print([px for px in self.image.pixels])
    
    def write_pixel(self, row,col, pixel_data):
        px_per_scanline = self.width*self.channels_per_pixel
        
        offset = (row*px_per_scanline +
                  col*self.channels_per_pixel)
        
        for i in range(self.channels_per_pixel):
            self.image.pixels[offset+i] = pixel_data[i]
        
    # def __del__(self):
        # bpy.data.images.remove(img)
        # https://blender.stackexchange.com/questions/13849/delete-all-unused-textures-from-blender-using-python
