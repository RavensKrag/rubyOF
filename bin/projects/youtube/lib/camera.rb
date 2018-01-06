class Camera
	include RubyOF::Graphics
	
	attr_accessor :pos, :zoom
	
	def initialize
		@pos = CP::Vec2.new(0,0)
		@zoom = 1.0
	end
	
	def draw(w,h, &block)
		# viewport = _viewport;
		ofPushView();
		
		x,y = [0,0]
		invertY = false;
		ofViewport(x, y, w, h, invertY);
		
	    # parameters.add(farClip.set("Far Clip", 2000, 5000, 10000));
	    # parameters.add(nearClip.set("Near Clip", -1000, -5000, 10000));
		nearClip = -1000; # ( 5000..10000)
		farClip  =  2000; # (-5000..10000)
		ofSetupScreenOrtho(w, h, nearClip, farClip);
		
			ofPushMatrix();
			# ofRotateX(orientation.x);
			# ofRotateY(orientation.y);
			
			
			ofTranslate(@pos.x, @pos.y, 0);
			ofScale(@zoom,@zoom,1);
			# ofTranslate(translation*orientationMatrix);
			# ofScale(scale,scale * (bFlipY?-1:1),scale);
			
			
			block.call()
			
			
			ofPopMatrix();
		ofPopView();
	end
end
