package main

import "core:fmt"
import "core:math/linalg"
import "core:math/ease"
import rl "vendor:raylib"

FONT_DATA :: #load("assets/Inter.ttf")

Cut :: struct {
	start: rl.Vector2,
	end:   rl.Vector2,
}

CutStats :: struct {
	target_pixels: int,
	user_pixels:   int,
	pixels_left:   f32,
	pixels_right:  f32,
	accuracy:      f32,
}

SplitAnimation :: struct {
	active:   bool,
	progress: f32,
	duration: f32,
	piece1:   rl.Texture2D,
	piece2:   rl.Texture2D,
	cut:      Cut,
	offset:   f32,
}

GameState :: enum {
	LevelSelect,
	Playing,
	LevelComplete,
}

font20: rl.Font
font32: rl.Font
font40: rl.Font
font46: rl.Font
font80: rl.Font

LINE_WIDTH :: 4.0
level: int
current_cut: Maybe(Cut)
stats: CutStats
split_anim: SplitAnimation
current_state: GameState
stats_anim_progress: f32
stats_anim_duration: f32 = 1.0

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1200, 800, "Cutting Game")
	font20 = rl.LoadFontFromMemory(".otf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 20, nil, 0)
	font32 = rl.LoadFontFromMemory(".otf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 32, nil, 0)
	font40 = rl.LoadFontFromMemory(".otf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 40, nil, 0)
	font46 = rl.LoadFontFromMemory(".otf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 46, nil, 0)
	font80 = rl.LoadFontFromMemory(".otf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 80, nil, 0)

	load_levels()
	load_progress()
	current_state = .LevelSelect

	for !rl.WindowShouldClose() {
		switch current_state {
		case .LevelSelect:
			update_level_select()
		case .Playing:
			update_playing()
		case .LevelComplete:
			update_level_complete()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{30, 30, 40, 255})

		switch current_state {
		case .LevelSelect:
			draw_level_select()
		case .Playing:
			draw_playing()
		case .LevelComplete:
			draw_level_complete()
		}

		rl.EndDrawing()
	}
}

update_level_select :: proc() {
	THUMB_WIDTH :: 270
	THUMB_HEIGHT :: 250
	COLS :: 3
	PADDING :: 30

	total_width := COLS * THUMB_WIDTH + (COLS - 1) * PADDING
	start_x := (1200 - total_width) / 2
	start_y := 250

	mouse_pos := rl.GetMousePosition()

	for i in 0..<len(levels) {
		col := i % COLS
		row := i / COLS
		rect := rl.Rectangle{
			f32(start_x + col * (THUMB_WIDTH + PADDING)),
			f32(start_y + row * (THUMB_HEIGHT + PADDING)),
			THUMB_WIDTH,
			THUMB_HEIGHT,
		}

		if rl.CheckCollisionPointRec(mouse_pos, rect) && rl.IsMouseButtonReleased(.LEFT) {
			level = i
			current_state = .Playing
			progress.levels[i].attempts += 1
			return
		}
	}
}

draw_level_select :: proc() {
	title: cstring = "Cutting Game"
	title_size := rl.MeasureTextEx(font80, title, 80, 4)
	rl.DrawTextEx(font80, title, {(1200 - title_size.x) / 2, 60}, 80, 4, rl.WHITE)

	THUMB_WIDTH :: 300
	THUMB_HEIGHT :: 250
	COLS :: 3
	PADDING :: 30

	total_width := COLS * THUMB_WIDTH + (COLS - 1) * PADDING
	start_x := (1200 - total_width) / 2
	start_y := 210

	mouse_pos := rl.GetMousePosition()

	for i in 0..<len(levels) {
		l := levels[i]
		p := progress.levels[i].accuracy
		attempts := progress.levels[i].attempts

		col := i % COLS
		row := i / COLS
		rect := rl.Rectangle{
			f32(start_x + col * (THUMB_WIDTH + PADDING)),
			f32(start_y + row * (THUMB_HEIGHT + PADDING)),
			THUMB_WIDTH,
			THUMB_HEIGHT,
		}

		is_over := rl.CheckCollisionPointRec(mouse_pos, rect)

		bg_color := rl.Color{40, 40, 55, 255}
		if is_over {
			bg_color = rl.Color{70, 70, 90, 255}
		}
		rl.DrawRectangleRounded(rect, 0.1, 8, bg_color)
		rl.DrawRectangleRoundedLines(rect, 0.1, 8, {150, 150, 170, 255})

		level_text := fmt.caprintf("Level %d", i + 1)
		level_text_size := rl.MeasureTextEx(font32, level_text, 32, 2)
		rl.DrawTextEx(font32, level_text, {rect.x + (rect.width - level_text_size.x)/2, rect.y + 15}, 32, 2, rl.WHITE)

		attempts_text := fmt.caprintf("Attempts: %d", attempts)
		attempts_text_size := rl.MeasureTextEx(font20, attempts_text, 20, 2)
		rl.DrawTextEx(font20, attempts_text, {rect.x + (rect.width - attempts_text_size.x)/2, rect.y + 50}, 20, 2, {200, 200, 200, 255})

		thumb_inset :: 10
		thumb_y := rect.y + 80
		thumb_height := rect.height - 125
		src_rect := rl.Rectangle{0, 0, f32(l.width), f32(l.height)}
		dest_rect := rl.Rectangle{rect.x + thumb_inset, thumb_y, rect.width - 2*thumb_inset, thumb_height}
		rl.DrawTexturePro(l.image, src_rect, dest_rect, {0, 0}, 0, rl.WHITE)

		bar_y := rect.y + rect.height - 40
		bar_rect_bg := rl.Rectangle{rect.x + 10, bar_y, rect.width - 20, 25}
		rl.DrawRectangleRounded(bar_rect_bg, 0.2, 4, {20, 20, 20, 200})

		bar_width := (bar_rect_bg.width - 4) * (p / 100.0)
		bar_rect_fg := rl.Rectangle{bar_rect_bg.x + 2, bar_rect_bg.y + 2, bar_width, bar_rect_bg.height - 4}
		rl.DrawRectangleRounded(bar_rect_fg, 0.2, 4, {17,178,34,255})

		perc_text := fmt.caprintf("%.0f%%", p)
		perc_size := rl.MeasureTextEx(font20, perc_text, 20, 2)
		rl.DrawTextEx(font20, perc_text, {bar_rect_bg.x + (bar_rect_bg.width - perc_size.x)/2, bar_rect_bg.y + (bar_rect_bg.height - perc_size.y)/2 + 2}, 20, 2, rl.WHITE)
	}
}

update_playing :: proc() {
	mouse_pos := rl.GetMousePosition()
	if rl.IsMouseButtonPressed(.LEFT) {
		current_cut = Cut{start = mouse_pos, end = mouse_pos}
	}
	if rl.IsMouseButtonDown(.LEFT) {
		if cut, ok := current_cut.?; ok {
			cut.end = mouse_pos
			current_cut = cut
		}
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		if cut, ok := current_cut.?; ok {
			if cut.start == cut.end do return

			analyze_cut(cut)
			create_split_animation(cut)
			current_state = .LevelComplete
			stats_anim_progress = 0.0
		}
		current_cut = nil
	}

	update_split_animation()
}

draw_playing :: proc() {
	if level < len(levels) {
		current_level := levels[level]

		if split_anim.active {
			draw_split_animation()
		} else {
			rl.DrawTextureV(current_level.image, {0, 0}, rl.WHITE)
		}

		if cut, ok := current_cut.?; ok && !split_anim.active {
			rl.DrawLineEx(cut.start, cut.end, LINE_WIDTH, rl.RED)
		}
	}
}

update_level_complete :: proc() {
	update_split_animation()

	if !split_anim.active {
		stats_anim_progress = min(stats_anim_progress + rl.GetFrameTime() / stats_anim_duration, 1.0)

		stats_rect := rl.Rectangle{300, 200, 600, 400}
		button_rect := rl.Rectangle{stats_rect.x + (stats_rect.width - 200) / 2, stats_rect.y + stats_rect.height - 80, 200, 50}

		if draw_button(button_rect, "Continue") {
			if stats.accuracy > progress.levels[level].accuracy {
				progress.levels[level].accuracy = stats.accuracy
			}

			save_progress()

			current_state = .LevelSelect
			if split_anim.piece1.id != 0 {
				rl.UnloadTexture(split_anim.piece1)
			}
			if split_anim.piece2.id != 0 {
				rl.UnloadTexture(split_anim.piece2)
			}
			split_anim.active = false
		}
	}
}

draw_level_complete :: proc() {
	if level >= len(levels) {
		return
	}

	draw_split_animation()

	if !split_anim.active {
		stats_rect := rl.Rectangle{300, 200, 600, 400}
		rl.DrawRectangleRounded(stats_rect, 0.1, 16, rl.Color{0, 0, 0, 220})

		title_text: cstring = "Level Complete!"
		title_size := rl.MeasureTextEx(font46, title_text, 46, 2)
		title_pos := rl.Vector2{
			stats_rect.x + (stats_rect.width - title_size.x) / 2,
			stats_rect.y + 40,
		}
		rl.DrawTextEx(font46, title_text, title_pos, 46, 2, rl.WHITE)

		current_anim_acc := ease.cubic_out(stats_anim_progress) * stats.accuracy
		acc_text: cstring = fmt.caprintf("Accuracy: %.1f%%", current_anim_acc)
		text_size := rl.MeasureTextEx(font40, acc_text, 40, 2)
		text_pos := rl.Vector2{
			stats_rect.x + (stats_rect.width - text_size.x) / 2,
			stats_rect.y + 120,
		}
		rl.DrawTextEx(font40, acc_text, text_pos, 40, 2, rl.YELLOW)

		bar_y := text_pos.y + text_size.y + 40
		bar_width := stats_rect.width - 100
		bar_bg_rect := rl.Rectangle{stats_rect.x + 50, bar_y, bar_width, 40}
		rl.DrawRectangleRounded(bar_bg_rect, 0.2, 8, {50, 50, 50, 255})

		current_bar_width := (bar_width - 8) * (current_anim_acc / 100.0)
		bar_fg_rect := rl.Rectangle{bar_bg_rect.x + 4, bar_bg_rect.y + 4, current_bar_width, bar_bg_rect.height - 8}
		rl.DrawRectangleRounded(bar_fg_rect, 0.2, 8, {17,178,34,255})

		button_rect := rl.Rectangle{stats_rect.x + (stats_rect.width - 200) / 2, stats_rect.y + stats_rect.height - 80, 200, 50}
		draw_button(button_rect, "Continue")
	}
}

draw_button :: proc(rect: rl.Rectangle, text: cstring) -> bool {
	mouse_pos := rl.GetMousePosition()
	is_over := rl.CheckCollisionPointRec(mouse_pos, rect)
	is_clicked := is_over && rl.IsMouseButtonReleased(.LEFT)

	bg_color := rl.Color{50, 50, 70, 255}
	if is_over {
		bg_color = rl.Color{80, 80, 100, 255}
	}

	rl.DrawRectangleRounded(rect, 0.2, 8, bg_color)

	text_size := rl.MeasureTextEx(font32, text, 32, 2)
	text_pos := rl.Vector2{
		rect.x + (rect.width - text_size.x) / 2,
		rect.y + (rect.height - text_size.y) / 2,
	}
	rl.DrawTextEx(font32, text, text_pos, 32, 2, rl.WHITE)

	return is_clicked
}

get_pixel :: proc(img: rl.Image, x: i32, y: i32) -> rl.Color {
	if x < 0 || x >= img.width || y < 0 || y >= img.height {
		return rl.Color{0, 0, 0, 0}
	}
	idx := (y * img.width + x) * 4
	data := cast([^]u8)img.data
	return rl.Color{data[idx], data[idx+1], data[idx+2], data[idx+3]}
}

analyze_cut :: proc(cut: Cut) {
	level_data := levels[level]
	img := level_data.img_data
	left_pixels := 0
	right_pixels := 0
	for y in 0..<img.height {
		for x in 0..<img.width {
			color := get_pixel(img, x, y)
			if color.a > 128 {
				side := linalg.cross(cut.end - cut.start, rl.Vector2{f32(x), f32(y)} - cut.start)
				if side > 0 {
					right_pixels += 1
				} else if side < 0 {
					left_pixels += 1
				}
			}
		}
	}

	total_pixels := left_pixels + right_pixels
	target_pixels := total_pixels / 2

	user_pixels := min(left_pixels, right_pixels)
	accuracy := ease.circular_in(f32(user_pixels) / f32(target_pixels)) * 100.0
	stats = CutStats{
		target_pixels = target_pixels,
		user_pixels   = user_pixels,
		pixels_left = f32(left_pixels) / f32(total_pixels),
		pixels_right = f32(right_pixels) / f32(total_pixels),
		accuracy      = accuracy,
	}
}

create_split_animation :: proc(cut: Cut) {
	level_data := levels[level]
	img := level_data.img_data

	split_anim.active = true
	split_anim.progress = 0.0
	split_anim.duration = 0.6
	split_anim.cut = cut
	split_anim.offset = 100.0

	if split_anim.piece1.id != 0 {
		rl.UnloadTexture(split_anim.piece1)
	}
	if split_anim.piece2.id != 0 {
		rl.UnloadTexture(split_anim.piece2)
	}

	img1 := rl.ImageCopy(img)
	img2 := rl.ImageCopy(img)

	erase_side_of_image(&img1, cut, true)
	erase_side_of_image(&img2, cut, false)

	split_anim.piece1 = rl.LoadTextureFromImage(img1)
	split_anim.piece2 = rl.LoadTextureFromImage(img2)

	rl.UnloadImage(img1)
	rl.UnloadImage(img2)
}

erase_side_of_image :: proc(img: ^rl.Image, cut: Cut, keep_left: bool) {
	data := cast([^]u8)img.data

	for y in 0..<img.height {
		for x in 0..<img.width {
			side := linalg.cross(cut.end - cut.start, rl.Vector2{f32(x), f32(y)} - cut.start)
			should_erase := (side > 0 && keep_left) || (side < 0 && !keep_left)

			if should_erase {
				idx := (y * img.width + x) * 4
				data[idx+3] = 0
			}
		}
	}
}

update_split_animation :: proc() {
	if !split_anim.active {
		return
	}

	split_anim.progress += rl.GetFrameTime() / split_anim.duration

	if split_anim.progress >= 1.0 {
		split_anim.progress = 1.0
		split_anim.active = false
	}
}

draw_split_animation :: proc() {
	if split_anim.piece1.id == 0 || split_anim.piece2.id == 0 {
		if level < len(levels) {
			rl.DrawTextureV(levels[level].image, {0, 0}, rl.WHITE)
		}
		return
	}

	cut := split_anim.cut

	dir := linalg.normalize(cut.end - cut.start)
	normal := rl.Vector2{-dir.y, dir.x}

	t := ease.circular_out(split_anim.progress)
	offset_dist := split_anim.offset * t

	pos1 := -normal * offset_dist
	pos2 := normal * offset_dist

	rl.DrawTextureV(split_anim.piece1, pos1, rl.WHITE)
	rl.DrawTextureV(split_anim.piece2, pos2, rl.WHITE)
}