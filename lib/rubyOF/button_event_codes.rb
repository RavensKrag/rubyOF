# (these need to stay as ints, unfortunately. can't use symbols. this is because letter keys and special keys are both sent as ints, but the letter keys occupy a standard range (assuming ASCII?) but )

# I just copied these constants from the following file:
	# ext/openFrameworks/libs/openFrameworks/events/ofEvents.h
# and made some slight adjustmtents, like changing comment syntax
# and removing the commas at the end of lines.
OF_KEY_RETURN	=	13
OF_KEY_ESC		=	27
OF_KEY_TAB      =    9


OF_KEY_BACKSPACE =	8
OF_KEY_DEL		 =	127


# // For legacy reasons we are mixing up control keys
# // and unicode codepoints when sending key events,
# // for the modifiers that need to be usable as bitmask
# // we are using some control codes that have nothing to do
# // with the keys being represented and then 0x0ee0.. and 0x0e60...
# // which are free in the unicode table

OF_KEY_SHIFT	=	 0x1
OF_KEY_CONTROL	=	 0x2
OF_KEY_ALT		=	 0x4
OF_KEY_SUPER	=	 0x10
OF_KEY_COMMAND  =    OF_KEY_SUPER
OF_KEY_LEFT_SHIFT    =	 0xe60
OF_KEY_RIGHT_SHIFT   =	 0xe61
OF_KEY_LEFT_CONTROL  =	 0xe62
OF_KEY_RIGHT_CONTROL = 0xe63
OF_KEY_LEFT_ALT		= 0xe64
OF_KEY_RIGHT_ALT	= 0xe65
OF_KEY_LEFT_SUPER	= 0xe66
OF_KEY_RIGHT_SUPER	= 0xe67
OF_KEY_LEFT_COMMAND = OF_KEY_LEFT_SUPER
OF_KEY_RIGHT_COMMAND = OF_KEY_RIGHT_SUPER

# // Use values from the Unicode private use codepoint range E000 - F8FF. 
# // See https://www.unicode.org/faq/private_use.html
OF_KEY_F1        = 0xe000
OF_KEY_F2        = 0xe001
OF_KEY_F3        = 0xe002
OF_KEY_F4        = 0xe003
OF_KEY_F5        = 0xe004
OF_KEY_F6        = 0xe005
OF_KEY_F7        = 0xe006
OF_KEY_F8        = 0xe007
OF_KEY_F9        = 0xe008
OF_KEY_F10       = 0xe009
OF_KEY_F11       = 0xe00A
OF_KEY_F12       = 0xe00B
OF_KEY_LEFT      = 0xe00C
OF_KEY_UP        = 0xe00D
OF_KEY_RIGHT     = 0xe00E
OF_KEY_DOWN      = 0xe00F
OF_KEY_PAGE_UP   = 0xe010
OF_KEY_PAGE_DOWN = 0xe011
OF_KEY_HOME      = 0xe012
OF_KEY_END       = 0xe013
OF_KEY_INSERT    = 0xe014

OF_MOUSE_BUTTON_1 =    0
OF_MOUSE_BUTTON_2 =    1
OF_MOUSE_BUTTON_3 =    2
OF_MOUSE_BUTTON_4 =    3
OF_MOUSE_BUTTON_5 =    4
OF_MOUSE_BUTTON_6 =    5
OF_MOUSE_BUTTON_7 =    6
OF_MOUSE_BUTTON_8 =    7
OF_MOUSE_BUTTON_LAST   = OF_MOUSE_BUTTON_8
OF_MOUSE_BUTTON_LEFT   = OF_MOUSE_BUTTON_1
OF_MOUSE_BUTTON_MIDDLE = OF_MOUSE_BUTTON_2
OF_MOUSE_BUTTON_RIGHT  = OF_MOUSE_BUTTON_3
