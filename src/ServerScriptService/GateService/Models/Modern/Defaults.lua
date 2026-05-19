return {
	MainMaterial = Enum.Material.Concrete,
	MainColor    = Color3.new(1, 0.2, 0.7),
	DisplayName  = "ERROR",
	
	InputOffsets = {
		[1] = { Vector2.new( 0.00,  0.50) },
		[2] = { Vector2.new(-0.20,  0.50), Vector2.new( 0.20,  0.50) },
		[3] = { Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50) },
		[4] = { Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50), Vector2.new( 0.50,  0.00) },
		[5] = { Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50), Vector2.new( 0.50,  0.20), Vector2.new( 0.50, -0.20) },
	},
	OutputOffsets = {
		[1] = { Vector2.new( 0.00, -0.50) },
		[2] = { Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50) },
		[3] = { Vector2.new(-0.27, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.27, -0.50) },
		[4] = { Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) },
		[5] = { Vector2.new(-0.27, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.27, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) },
	},
}
