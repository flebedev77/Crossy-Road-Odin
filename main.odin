package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import "core:time"
import utils "utils"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

PLAYER_SPEED: f32 : 300
PLAYER_FRICTION: f32 : 0.9

GAMEOVER_TEXT :: "GAME OVER!!!"

CAR_SPEED :: 160
CAR_SPAWN_RATE :: 1.5
CAR_WIDTH :: 100
CAR_HEIGHT :: 30

MAX_CARS_PER_ROAD :: 10

DEV :: true

ScreenState :: enum {
	Boot,
	Menu,
	Game,
	GameOver,
}

currentScreenState := ScreenState.Boot

bootScreenDelay: f32 = 0
bootScreenDuration: f32 = 3

Player :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	radius:   f32,
	speed:    f32,
	color:    rl.Color,
}

Keyboard :: struct {
	left:  bool,
	right: bool,
	up:    bool,
	down:  bool,
}

keys := Keyboard{}
images: [dynamic]rl.Texture2D
player := Player{}
camera := rl.Camera2D{}
frameIndex: u64 = 0

imageFilenames :: [?]string{"logo.png", "grasstile.png"}

score: u32 = 0

isGameOver: bool = false

TileEntity :: struct {
	position: rl.Vector2,
}
tileAmountWidth :: 10
tileAmountHeight :: 11
tileWidth: f32 = math.ceil(f32(WINDOW_WIDTH / tileAmountWidth))
tileHeight: f32 = math.ceil(f32(WINDOW_HEIGHT / (tileAmountHeight - 1)))
tiles: [dynamic]TileEntity


CarEntity :: struct {
	position: rl.Vector2,
	width:    f32,
	height:   f32,
}

RoadEntity :: struct {
	yPosition:     f32,
	cars:          [dynamic]CarEntity,
	carSpawnDelay: f32,
}

ROAD_WIDTH :: 260
roads: [dynamic]RoadEntity

init :: proc() {
	isGameOver = false

	camera = rl.Camera2D{}
	camera.zoom = 1

	player = Player {
		rl.Vector2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		rl.Vector2{0, 0},
		20,
		PLAYER_SPEED,
		rl.BLACK,
	}

	keys = Keyboard{false, false, false, false}

	images = make([dynamic]rl.Texture2D, 0, 0)

	for fileName in imageFilenames {
		filePath := strings.concatenate({"assets/", fileName})
		append(&images, utils.loadTexture(filePath))
	}

	tiles = make([dynamic]TileEntity, 0, 0)
	for w in 0 ..< tileAmountWidth {
		for h in 0 ..< tileAmountHeight {
			tile := TileEntity{rl.Vector2{f32(w) * tileWidth, f32(h) * tileHeight}}
			append(&tiles, tile)
		}
	}

	roads = make([dynamic]RoadEntity, 0, 0)
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Crossy road")

	rl.SetTargetFPS(60)

	init()

	for !rl.WindowShouldClose() {
		deltaTime: f32 = rl.GetFrameTime()
		frameIndex += 1

		{ 	//input
			keys.left = rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)
			keys.right = rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)
			keys.up = rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)
			keys.down = rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)

			if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
				movePlayer(-1, 0)
			}

			if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
				movePlayer(1, 0)
			}

			if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
				score += 1
				movePlayer(0, -1)
			}

			if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
				if score == 0 {
					gameOver()
				} else {
					score -= 1
				}
				movePlayer(0, 0.5)
			}

			player.position.x += player.velocity.x * deltaTime
			player.position.y += player.velocity.y * deltaTime

			player.position.x = math.min(WINDOW_WIDTH, player.position.x)
			player.position.x = math.max(0, player.position.x)

			player.velocity.x *= PLAYER_FRICTION
			player.velocity.y *= PLAYER_FRICTION
		}
		{ 	//camera movement
			// dont follow player on x axis
			//camera.target.x = utils.eased(
			//	camera.target.x,
			//	player.position.x - WINDOW_WIDTH / 2,
			//	0.1,
			//)
			camera.target.y = utils.eased(
				camera.target.y,
				player.position.y - WINDOW_HEIGHT / 2,
				0.1,
			)
			camera.target.y = math.min(0, player.position.y - WINDOW_HEIGHT / 2)
		}


		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)

		switch currentScreenState {
		case .Game:
			renderGame(deltaTime)
			break
		case .Menu:
			//Temporary: just skip the menu
			renderMenu(deltaTime)
			if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				currentScreenState = .Game
			}
			break

		case .Boot:
			currentScreenState = .Game
			renderBootScreen(deltaTime)
			bootScreenDelay += deltaTime
			if bootScreenDelay > bootScreenDuration {
				bootScreenDelay = 0
				currentScreenState = .Menu
			}
			break

		case .GameOver:
			renderGameOver()
			break

		}

		rl.EndDrawing()

		when DEV {
			if rl.IsKeyDown(.END) {
				rl.CloseWindow()
			}
		}
	}

	rl.CloseWindow()
}

movePlayer :: proc(x: f32, y: f32) {
	player.velocity.x += x * player.speed
	player.velocity.y += y * player.speed
	player.velocity = utils.normaliseVec2(player.velocity)
	player.velocity.x *= player.speed
	player.velocity.y *= player.speed
	if y == 0.5 {
		player.velocity.y *= 0.8
	}
}

renderGameOver :: proc(deltaTime: f32 = 0) {
	textWidth := rl.MeasureText(GAMEOVER_TEXT, 20)
	rl.DrawText(
		GAMEOVER_TEXT,
		WINDOW_WIDTH / 2 - textWidth / 2,
		WINDOW_HEIGHT / 2,
		20,
		rl.RAYWHITE,
	)
}

menuTextBobOffset: f32 = 0
renderMenu :: proc(deltaTime: f32 = 0) {
	menuTextBobOffset = f32(math.sin(f16(frameIndex) / 100)) * 10
	rl.DrawText(
		"Press space to start...",
		WINDOW_WIDTH / 2 - 110,
		WINDOW_HEIGHT / 2 - i32(menuTextBobOffset),
		20,
		rl.RAYWHITE,
	)
}

bootScreenAdditiveDeltaTime: f32 = 0
renderBootScreen :: proc(deltaTime: f32 = 0) {
	bootScreenAdditiveDeltaTime += deltaTime
	lerpAmt: f32 = (bootScreenAdditiveDeltaTime / (bootScreenDuration - 2))
	size: f32 = utils.eased(30, 100, lerpAmt) //70 * utils.ease_out(lerpAmt) + 30 //rl.Lerp(30, 100, lerpAmt)
	angle: f32 = utils.eased(45, 0, lerpAmt)

	source := rl.Rectangle{0, 0, 128, 128}

	fadingAway := false
	fadeAwayOffset: f32 = 1.5
	if bootScreenAdditiveDeltaTime > bootScreenDuration - fadeAwayOffset {
		fadingAway = true
		lerpAmt =
			((bootScreenAdditiveDeltaTime - fadeAwayOffset) /
				(bootScreenDuration - fadeAwayOffset))
	}

	bootScreenColor := rl.ColorLerp(rl.Color{0, 0, 0, 0}, rl.Color{255, 255, 255, 255}, lerpAmt)
	if fadingAway {
		bootScreenColor = rl.ColorLerp(rl.Color{255, 255, 255, 255}, rl.Color{0, 0, 0, 0}, lerpAmt)
		angle = utils.eased(0, -45, lerpAmt)
		size = utils.eased(100, 30, lerpAmt)
	}
	targetRect := rl.Rectangle{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2, size, size}
	rl.DrawTexturePro(
		images[0],
		source,
		targetRect,
		rl.Vector2{size / 2, size / 2},
		angle,
		bootScreenColor,
	)
}

renderGame :: proc(deltaTime: f32 = 0) {
	rl.BeginMode2D(camera)

	{ 	// tiles
		topMostTilePosY: f32 = getTopMostTilePosition()
		bottomMostTilePosY: f32 = getBottomMostTilePosition()
		hasCalledRoadGen: bool = false
		for &tileEntity in tiles {
			if tileEntity.position.y < camera.target.y - tileHeight * 1 {
				tileEntity.position.y = bottomMostTilePosY + tileHeight * 1
			}
			if tileEntity.position.y > camera.target.y + WINDOW_HEIGHT {
				tileEntity.position.y = topMostTilePosY - tileHeight
				if !hasCalledRoadGen {
					hasCalledRoadGen = true
					genRoad(tileEntity.position.y - ROAD_WIDTH)
				}
			}

			source := rl.Rectangle{0, 0, 32, 32}
			dest := rl.Rectangle {
				tileEntity.position.x,
				tileEntity.position.y,
				tileWidth,
				tileHeight,
			}
			rl.DrawTexturePro(images[1], source, dest, rl.Vector2{0, 0}, 0, rl.RAYWHITE)
		}
	}
	{ 	// roads
		for &road in roads {
			rl.DrawRectangle(0, i32(road.yPosition), WINDOW_WIDTH, ROAD_WIDTH, rl.BLACK)

			for &car in road.cars {
				rl.DrawRectangle(
					i32(car.position.x),
					i32(car.position.y),
					i32(car.width),
					i32(car.height),
					rl.GRAY,
				)

				car.position.x += CAR_SPEED * deltaTime

				if car.position.x > WINDOW_WIDTH {
					car.position.x = -CAR_WIDTH
				}
			}

			road.carSpawnDelay += deltaTime
			if road.carSpawnDelay > CAR_SPAWN_RATE && len(road.cars) < MAX_CARS_PER_ROAD {
				road.carSpawnDelay = 0
				rand.reset(frameIndex + u64(len(road.cars)) + u64(time.now()._nsec))
				yCarOffset := (rand.uint32() % 3) * ROAD_WIDTH / 3 // random 3 lane position
				yCarPadding: f32 = (ROAD_WIDTH / 3 - CAR_HEIGHT) / 2
				car := CarEntity {
					rl.Vector2{-CAR_WIDTH, road.yPosition + f32(yCarOffset) + yCarPadding},
					CAR_WIDTH,
					CAR_HEIGHT,
				}
				append(&road.cars, car)
			}

		}
	}

	rl.DrawCircleV(player.position, player.radius, rl.MAROON)

	rl.EndMode2D()
	scoreStr := fmt.aprintf("Score: %d", score)
	scoreCStr := strings.clone_to_cstring(scoreStr)
	rl.DrawText(scoreCStr, 10, 9, 19, rl.RAYWHITE)
}

getTopMostTilePosition :: proc() -> f32 {
	topY: f32 = 10000
	for &tile in tiles {
		topY = math.min(topY, tile.position.y)
	}
	return topY
}

getBottomMostTilePosition :: proc() -> f32 {
	bottomY: f32 = -10000
	for &tile in tiles {
		bottomY = math.max(bottomY, tile.position.y)
	}
	return bottomY
}

genRoad :: proc(yPos: f32) {
	if !isRoadCollidingWithOtherRoadsAtPos(yPos) && rand.float64_range(0, 1) > 0.9 {
		cars := make([dynamic]CarEntity, 0, 0)
		road := RoadEntity{yPos, cars, 0}
		append(&roads, road)
	}
}

isRoadCollidingWithOtherRoadsAtPos :: proc(yPos: f32) -> bool {
	for &road in roads {
		if road.yPosition + ROAD_WIDTH > yPos && road.yPosition < yPos + ROAD_WIDTH {
			return true
		}
	}
	return false
}

gameOver :: proc() {
	isGameOver = true
	currentScreenState = .GameOver
}

