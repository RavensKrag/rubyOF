
# 
# coroutine decorator function
# 
# originally by David Beazley
# links:
# + http://www.dabeaz.com/coroutines/
# + https://www.youtube.com/watch?v=Z_OAlIhXziw
# + https://stackoverflow.com/questions/13386277/python-loop-in-a-coroutine
# 
# but next() has been updated to a free function for python 3.x
# src: https://stackoverflow.com/questions/21622193/python-3-2-coroutine-attributeerror-generator-object-has-no-attribute-next/21622696
# 
def coroutine(func):
    def start(*args,**kwargs):
        cr = func(*args,**kwargs)
        next(cr)
        return cr
    return start
