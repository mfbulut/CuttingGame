package main

SAVE_FILE :: "progress.json"

import "core:os"
import "core:fmt"
import "core:encoding/json"

LevelProgress :: struct {
	accuracy: f32,
	attempts: int,
}

GameProgress :: struct {
	levels: [6]LevelProgress,
}

progress: GameProgress

load_progress :: proc() {
	if !os.exists(SAVE_FILE) {
		return
	}

	data, os_err := os.read_entire_file(SAVE_FILE, context.allocator)
	if os_err != nil {
		return
	}

	err := json.unmarshal(data, &progress)
	if err != nil {
		return
	}
}

save_progress :: proc() {
	data, err := json.marshal(progress)
	if err != nil {
		fmt.eprintln("Failed to marshal progress:", err)
		return
	}
	_ = os.write_entire_file(SAVE_FILE, data)
}