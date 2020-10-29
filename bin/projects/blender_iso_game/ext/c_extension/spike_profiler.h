
// based on "Runtime CPU Performance Spike Detection Using Manual and Compiler Automated Instrumentation" by Adisak Pochanayon, Netherrealm Studios (MK9, Batman Arkham City) [ presented @ GDC 2012 ]


// -> PET_FUNCTION is a scoped marker 		@ 31:17 in video

// WARNING: current implementation is not thread safe!
//          !!! ONLY USE ON MAIN THREAD !!!

// #define PROFILER_TIME_THRESHOLD 20 // threshold time in microseconds

struct ProfilerData{
	uint64_t start_time;
};


// static const int MAX_STACK_HEIGHT = 32;
// static int stack_counter; // file variable
// static ProfilerData* stack_bp; // file variable


class ProfilerHelper{
private:
	
		// NOTE: Although C++ char will be >= 8 bits,
		//       sizeof(char) will always be equal to 1.
		//       Thus, char* is definitely what you want here
		// src: https://en.cppreference.com/w/cpp/language/sizeof
	
	bool pushed; // did this particular call put data on the profiler stack?

public:
	static const int MAX_STACK_HEIGHT = 32;
	static int stack_counter; // file variable
	static ProfilerData* stack_bp; // file variable
	// ^ file variables should ultimately be in source, not header
	
	
	ProfilerHelper(const std::string fn, const char* file, int line){
		// TODO: only run timing function when within a particular section of code. basically, I want to see if some flag is set and only take action if it is set.
		
		// (ideally, I also want to store the 'pushed' state some other way.)
		// (only need it so you know when to pop the stack, but not sure how else to detect that)
		
		pushed = false; // start by assuming no profiler stack data used
		
		if(stack_bp == NULL){
			// cout << endl << endl << endl;
			
			// initialize stack
			// stack_bp = (char*) malloc(MAX_STACK_HEIGHT*sizeof(ProfilerData));
			// TODO: consider just allocating an array. be aware of alignment.
			
			stack_bp = new ProfilerData[MAX_STACK_HEIGHT];
		}
		// TODO: use one static block of memory instead of allocating and deacollating all the time - maybe that will reduce profiling overhead ??
		
		
		// https://www.cprogramming.com/reference/preprocessor/__FILE__.html
		cout << "PROFILER: " <<  stack_counter+1 << ") enter  " << fn << endl;
		// cout << file << ":" << line << endl;
		
		
		// Stack is now ready to use
		
		if(stack_counter < MAX_STACK_HEIGHT-1){
			// cout << "PROFILER: push" << endl;
			
			stack_counter++;
			
			// TODO: put data on the stack
			stack_bp[stack_counter-1] = ProfilerData();
			stack_bp[stack_counter-1].start_time = ofGetElapsedTimeMicros();
			
			pushed = true;
		}else{
			cout << "(stack too deep - no room to push state)" << endl;
		}
	}
	
	~ProfilerHelper(){
		// cout << "PROFILER: function exit" << endl;
		
		
		if(pushed){
			// cout << "PROFILER: pop" << endl;
			
			// TODO: take data off the stack
			uint64_t start_time = stack_bp[stack_counter-1].start_time;
			
			uint64_t now = ofGetElapsedTimeMicros();
			uint64_t dt = now - start_time;
			
			#ifdef PROFILER_TIME_THRESHOLD
			if(dt > PROFILER_TIME_THRESHOLD){
			#endif
				cout << "PROFILER: "<< stack_counter << ") dt = " << dt << endl;
			#ifdef PROFILER_TIME_THRESHOLD
			}
			#endif
			
			stack_counter--;
		}else{
			cout << "(stack too deep - no state to pop)" << endl;
		}
		
		
		// NOTE: must read all data from profiler stack before end of final block
		if(stack_counter == 0){
			delete[] stack_bp;
			stack_bp = NULL;
		}
	}
};

ProfilerData* ProfilerHelper::stack_bp = NULL;
int ProfilerHelper::stack_counter = 0;




void SpikeProfiler_begin(const std::string & fn){
	if(ProfilerHelper::stack_bp == NULL){
		// cout << endl << endl << endl;
		
		// initialize stack
		// ProfilerHelper::stack_bp = (char*) malloc(ProfilerHelper:::MAX_STACK_HEIGHT*sizeof(ProfilerData));
		// TODO: consider just allocating an array. be aware of alignment.
		
		ProfilerHelper::stack_bp = new ProfilerData[ProfilerHelper::MAX_STACK_HEIGHT];
	}
	// TODO: use one static block of memory instead of allocating and deacollating all the time - maybe that will reduce profiling overhead ??


	// https://www.cprogramming.com/reference/preprocessor/__FILE__.html
	cout << "PROFILER: " <<  ProfilerHelper::stack_counter+1 << ") enter  " << fn << endl;
	// cout << file << ":" << line << endl;


	// Stack is now ready to use

	if(ProfilerHelper::stack_counter < ProfilerHelper::MAX_STACK_HEIGHT-1){
		// cout << "PROFILER: push" << endl;
		
		ProfilerHelper::stack_counter++;
		
		// TODO: put data on the stack
		ProfilerHelper::stack_bp[ProfilerHelper::stack_counter-1] = ProfilerData();
		ProfilerHelper::stack_bp[ProfilerHelper::stack_counter-1].start_time = ofGetElapsedTimeMicros();
	}else{
		cout << "(stack too deep - no room to push state)" << endl;
	}
}

void SpikeProfiler_end(){
	// cout << "PROFILER: function exit" << endl;
	
	// cout << "PROFILER: pop" << endl;
	
	// TODO: take data off the stack
	uint64_t start_time = ProfilerHelper::stack_bp[ProfilerHelper::stack_counter-1].start_time;
	
	uint64_t now = ofGetElapsedTimeMicros();
	uint64_t dt = now - start_time;
	
	#ifdef PROFILER_TIME_THRESHOLD
	if(dt > PROFILER_TIME_THRESHOLD){
	#endif
		cout << "PROFILER: "<< ProfilerHelper::stack_counter << ") dt = " << dt << endl;
	#ifdef PROFILER_TIME_THRESHOLD
	}
	#endif
	
	ProfilerHelper::stack_counter--;
	
	
	// NOTE: must read all data from profiler stack before end of final block
	if(ProfilerHelper::stack_counter == 0){
		delete[] ProfilerHelper::stack_bp;
		ProfilerHelper::stack_bp = NULL;
	}
}
