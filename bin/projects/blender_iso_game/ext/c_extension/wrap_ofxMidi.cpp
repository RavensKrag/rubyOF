#include "wrap_ofxMidi.h"

using namespace Rice;

void wrap_ofxMidi(Module rb_mOFX){
	Data_Type<ofxMidiOut> rb_c_ofxMidiOut =
		define_class_under<ofxMidiOut>(rb_mOFX, "MidiOut");
	
	rb_c_ofxMidiOut
		.define_constructor(Constructor<ofxMidiOut>())
		.define_method("sendNoteOn",   &ofxMidiOut::sendNoteOn)
		.define_method("sendNoteOff",  &ofxMidiOut::sendNoteOff)
		.define_method("listOutPorts", &ofxMidiOut::listOutPorts)
		
		// .define_method("openPort",     &ofxMidiOut::openPort)
		.define_method("openPort_uint",
			static_cast< bool (ofxMidiOut::*)
			(unsigned int portNumber)
			>(&ofxMidiOut::openPort)
		)
		.define_method("openPort_string",
			static_cast< bool (ofxMidiOut::*)
			(std::string deviceName)
			>(&ofxMidiOut::openPort)
		)
	;
	
	
	Data_Type<ofxMidiMessage> rb_c_ofxMidiMessage =
		define_class_under<ofxMidiMessage>(rb_mOFX, "MidiMessage");
	
	rb_c_ofxMidiMessage
		.define_constructor(Constructor<ofxMidiMessage>())
		
		.define_method("getStatus", &ofxMidiMessage__get_status)
		
		.define_method("channel",   &ofxMidiMessage__get_channel)
		.define_method("pitch",     &ofxMidiMessage__get_pitch)
		.define_method("velocity",  &ofxMidiMessage__get_velocity)
		.define_method("value",     &ofxMidiMessage__get_value)
		
		.define_method("deltatime", &ofxMidiMessage__get_deltatime)
		
		.define_method("portNum",   &ofxMidiMessage__get_portNum)
		.define_method("portName",  &ofxMidiMessage__get_portName)
		
		.define_method("get_num_bytes",  &ofxMidiMessage__get_num_bytes)
		.define_method("get_byte",       &ofxMidiMessage__get_byte)
		
		.define_method("cpp_equality", &ofxMidiMessage__equality)
	;
	
	
	// TODO: write glue code to access these fields:
	
	
	// ofxMidiOut midiOut
	
	
}
	



// 
// ext/openFrameworks/addons/ofxMidi/src/ofxMidiMessage.h
// 

int ofxMidiMessage__get_status(ofxMidiMessage &self){
	// do not need to explictly state array size
	// src: https://stackoverflow.com/questions/32918448/is-it-bad-to-not-define-a-static-array-size-in-a-class-but-rather-to-let-it-au
	static const MidiStatus STATUS_IDS[] = {
		MIDI_UNKNOWN,
		
		// channel voice messages
		MIDI_NOTE_OFF           ,
		MIDI_NOTE_ON            ,
		MIDI_CONTROL_CHANGE     ,
		MIDI_PROGRAM_CHANGE     ,
		MIDI_PITCH_BEND         ,
		MIDI_AFTERTOUCH         ,
		MIDI_POLY_AFTERTOUCH    ,
		
		// system messages
		MIDI_SYSEX              ,
		MIDI_TIME_CODE          ,
		MIDI_SONG_POS_POINTER   ,
		MIDI_SONG_SELECT        ,
		MIDI_TUNE_REQUEST       ,
		MIDI_SYSEX_END          ,
		MIDI_TIME_CLOCK         ,
		MIDI_START              ,
		MIDI_CONTINUE           ,
		MIDI_STOP               ,
		MIDI_ACTIVE_SENSING     ,
		MIDI_SYSTEM_RESET       
	};
	
	
	MidiStatus status = self.status;
	
	int ary_size = sizeof(STATUS_IDS)/sizeof(STATUS_IDS[0]);
	for(int i=0; i < ary_size; i++){
		if(status == STATUS_IDS[i]){
			return i;
		}
	}
	
	
	return -1; // return -1 on error
}

int ofxMidiMessage__get_channel(ofxMidiMessage &self){
	return self.channel;
}
int ofxMidiMessage__get_pitch(ofxMidiMessage &self){
	return self.pitch;
}
int ofxMidiMessage__get_velocity(ofxMidiMessage &self){
	return self.velocity;
}
int ofxMidiMessage__get_value(ofxMidiMessage &self){
	return self.value;
}

double ofxMidiMessage__get_deltatime(ofxMidiMessage &self){
	return self.deltatime;
}

int ofxMidiMessage__get_portNum(ofxMidiMessage &self){
	return self.portNum;
}
std::string ofxMidiMessage__get_portName(ofxMidiMessage &self){
	return self.portName;
}


int ofxMidiMessage__get_num_bytes(ofxMidiMessage &self){
	return self.bytes.size();
}

unsigned char ofxMidiMessage__get_byte(ofxMidiMessage &self, int i){
	return self.bytes[i];
}


bool ofxMidiMessage__equality(ofxMidiMessage &self, ofxMidiMessage &other){
	if(self.bytes.size() != other.bytes.size()){
		return false;
	}
	else{
		int size = self.bytes.size();
		
		for(int i=0; i<size; i++){
			if(self.bytes[i] != other.bytes[i]){
				return false;
			}
		}
		
		return true;
	}
}
