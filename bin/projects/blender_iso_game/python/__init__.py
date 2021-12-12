bl_info = {
    "name": "RubyOF renderer engine",
    "author": "Jason Ko",
    "version": (0, 0, 2),
    "blender": (2, 90, 1),
    "location": "Render",
    "description": "Integration with external real-time RubyOF renderer for games, etc",
    "category": "Render",
}






# 
# requiring other files in a Blender extension
# 

import main_file
from main_file import *


# # 
# # dynamic reload in Blender
# # 

# # https://developer.blender.org/T66924
# # https://stackoverflow.com/questions/31410419/python-reload-file

# import importlib
# importlib.reload(main_file)
# from main_file import *



if __name__ == "__main__":
    main()
