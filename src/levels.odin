package main

import rl "vendor:raylib"

GameLevel :: struct {
	image:    rl.Texture2D,
	img_data: rl.Image,
	width:    i32,
	height:   i32,
}

levels: [dynamic]GameLevel

load_level_from_data :: proc(data: []u8) {
	img := rl.LoadImageFromMemory(".png", raw_data(data), i32(len(data)))
	tex := rl.LoadTextureFromImage(img)
	rl.SetTextureFilter(tex, .TRILINEAR)
	append(&levels, GameLevel{
		image    = tex,
		img_data = img,
		width    = tex.width,
		height   = tex.height,
	})
}

load_levels :: proc() {
	load_level_from_data(#load("assets/level1.png"))
	load_level_from_data(#load("assets/level2.png"))
	load_level_from_data(#load("assets/level3.png"))
	load_level_from_data(#load("assets/level4.png"))
	load_level_from_data(#load("assets/level5.png"))
	load_level_from_data(#load("assets/level6.png"))
}