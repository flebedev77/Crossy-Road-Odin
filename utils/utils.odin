package utils

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

normaliseVec2 :: proc(vec: rl.Vector2) -> rl.Vector2 {
	if vec.x == 0 && vec.y == 0 {
		return rl.Vector2(0)
	}
	x := 0 - vec.x
	y := 0 - vec.y
	mag := math.sqrt(x * x + y * y)
	return rl.Vector2{vec.x / mag, vec.y / mag}
}


loadTexture :: proc(path: string) -> rl.Texture2D {
	image: rl.Image = rl.LoadImage(strings.clone_to_cstring(path))
	tex: rl.Texture2D = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	return tex
}

loadTextureFromMem :: proc(data: rawptr, dataLen: i32) -> rl.Texture2D {
	image: rl.Image = rl.LoadImageFromMemory(".png", data, dataLen)
	tex: rl.Texture2D = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	return tex
}

ease_in_out :: proc(t: f32) -> f32 {
	t := t
	t = math.min(t, 1)
	t = math.max(t, 0)
	t = t * 2
	return 1.0 - (1.0 - t) * (1.0 - t)
}

ease_in :: proc(t: f32) -> f32 {
	return t * t
}

ease_out :: proc(t: f32) -> f32 {
	return 1.0 - (1.0 - t) * (1.0 - t)
}

eased :: proc(from: f32, to: f32, t: f32) -> f32 {
	// Make sure t is from 0 to 1
	t := t
	t = math.min(t, 1)
	t = math.max(t, 0)


	return (to - from) * ease_out(t) + from
}

