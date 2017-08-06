module RubyOF

module Graphics
	def style_stack(&block)
		begin
			ofPushStyle()
			yield
		ensure 
			ofPopStyle()
		end
	end
	
	def matrix_stack(&block)
		begin
			ofPushMatrix()
			yield
		ensure 
			ofPopMatrix()
		end
	end
end

end
