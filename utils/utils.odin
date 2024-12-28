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

SoundEntity :: struct {
	isPlaying: bool,
	isLooping: bool,
	hasEnded:  bool,
	duration:  f32,
	delay:     f32,
	data:      rl.Music,
}

loadMusicFromMem :: proc(data: rawptr, dataLen: i32) -> SoundEntity {
	m: rl.Music = rl.LoadMusicStreamFromMemory(".mp3", data, dataLen)
	mlen: f32 = rl.GetMusicTimeLength(m)
	return SoundEntity{false, false, false, mlen, 0, m}
}

playSound :: proc(sound: ^SoundEntity) {
	sound.hasEnded = false
	sound.isPlaying = true
	rl.StopMusicStream(sound.data)
	rl.PlayMusicStream(sound.data)
}

updateAudioSystem :: proc(sounds: ^[dynamic]SoundEntity, deltaTime: f32) {
	snds := sounds^
	for &sound in snds {
		if sound.isPlaying {
			rl.UpdateMusicStream(sound.data)
			sound.delay += deltaTime
			if sound.delay > sound.duration {
				sound.delay = 0
				sound.isPlaying = false
				sound.hasEnded = true
				rl.StopMusicStream(sound.data)
			}
		}
	}
}

//loadFontFromMem :: proc(data: rawptr, dataLen: i32) -> rl.Font {
//	font := rl.LoadFontFromMemory(".ttf", data, dataLen)
//}

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

aabb :: proc(
	aPos: rl.Vector2,
	aWidth: f32,
	aHeight: f32,
	bPos: rl.Vector2,
	bWidth: f32,
	bHeight: f32,
) -> bool {
	return(
		aPos.x < bPos.x + bWidth &&
		aPos.x + aWidth > bPos.x &&
		aPos.y < bPos.y + bHeight &&
		aPos.y + aHeight > bPos.y \
	)

}


entireBoxInBox :: proc(
	aPos: rl.Vector2,
	aWidth: f32,
	aHeight: f32,
	bPos: rl.Vector2,
	bWidth: f32,
	bHeight: f32,
) -> bool {
	topLeftCorner := rl.Vector2{aPos.x, aPos.y}
	topRightCorner := rl.Vector2{aPos.x + aWidth, aPos.y}
	bottomLeftCorner := rl.Vector2{aPos.x, aPos.y + aHeight}
	bottomRightCorner := rl.Vector2{aPos.x + aWidth, aPos.y + aHeight}

	return(
		aabb(topLeftCorner, 1, 1, bPos, bWidth, bHeight) &&
		aabb(topRightCorner, 1, 1, bPos, bWidth, bHeight) &&
		aabb(bottomLeftCorner, 1, 1, bPos, bWidth, bHeight) &&
		aabb(bottomRightCorner, 1, 1, bPos, bWidth, bHeight) \
	)
}

PopupState :: enum {
	FromTo,
	Idle,
	ToFrom,
}

Popup :: struct {
	fromPos:   rl.Vector2,
	toPos:     rl.Vector2,
	position:  rl.Vector2,
	width:     f32,
	height:    f32,
	text:      string,
	textWidth: i32,
	fontSize:  f32,
	lifeTime:  f32,
	time:      f32,
	state:     PopupState,
}

addPopup :: proc(
	popups: ^[dynamic]Popup,
	text: string,
	fromPos: rl.Vector2,
	toPos: rl.Vector2,
	w: f32,
	h: f32,
) {
	assert(popups != nil, "Popups pointer cant be nil")
	append(popups, Popup{fromPos, toPos, fromPos, w, h, text, 0, 0, 5, 0, .FromTo}) // if fontsize 0 then auto calculate
}

drawPopups :: proc(popups: ^[dynamic]Popup, deltaTime: f32) {
	assert(popups != nil, "Popups pointer cant be nil")
	ps := popups^
	for i in 0 ..< len(ps) {
		if ps[i].time > ps[i].lifeTime {
			unordered_remove(popups, i)
		}
	}
	for &p in ps {
		p.time += deltaTime

		totalMoveDuration := p.lifeTime / 3
		lerpAmt := (deltaTime / totalMoveDuration)
		idleStartTime := (p.lifeTime / 3) / 2
		idleStopTime := (p.lifeTime / 3) * 2
		if p.time >= 0 {
			p.state = .FromTo
		}
		if p.time >= idleStartTime {
			p.state = .Idle
		}
		if p.time >= idleStopTime {
			p.state = .ToFrom
		}
		if p.state != .Idle {
			toPosition: rl.Vector2 = (p.state == .FromTo) ? p.toPos : p.fromPos
			//p.position.x = rl.Lerp(p.position.x, toPosition.x, lerpAmt)
			//p.position.y = rl.Lerp(p.position.y, toPosition.y, lerpAmt)

			p.position = toPosition

		}

		rl.DrawRectangle(
			i32(p.position.x),
			i32(p.position.y),
			i32(p.width),
			i32(p.height),
			rl.GRAY,
		)

		t: cstring = strings.clone_to_cstring(p.text)
		if p.fontSize == 0 {
			saftey := 0
			for saftey < 1000 {
				saftey += 1

				p.fontSize += 1
				p.textWidth = rl.MeasureText(t, i32(p.fontSize))
				if p.textWidth >= i32(p.width - 70) {
					break
				}

			}

		}

		padding: f32 = (f32(p.width) - f32(p.textWidth)) / 2
		rl.DrawText(
			t,
			i32(p.position.x + padding),
			i32(p.position.y + 10),
			i32(p.fontSize),
			rl.RAYWHITE,
		)
	}
}

