
# need extra help to reload classes:
# https://developer.blender.org/T66924
# by gecko man (geckoman), Jul 22 2019, 9:02 PM

import importlib, sys
# reloads class' parent module and returns updated class
def reload_class(c):
    mod = sys.modules.get(c.__module__)
    importlib.reload(mod)
    return mod.__dict__[c.__name__]
