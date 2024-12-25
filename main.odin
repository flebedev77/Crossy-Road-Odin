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
GAMEOVER_TEXT_FONT_SIZE :: 25
GAMEOVER_SUBTEXT_FONT_SIZE :: 15
GAMEOVER_TEXT_FLICKER_SPEED :: 0.6
GAMEOVER_SCREEN_OFF_DELAY :: 3

CAR_SPEED :: 160
CAR_SPAWN_RATE :: 1.5
CAR_WIDTH :: 110
CAR_HEIGHT :: 50

MAX_CARS_PER_ROAD :: 5

ROAD_SPAWN_PROBABILITY_PERCENT :: 50
ROAD_WIDTH :: 260

DEV :: true

ScreenState :: enum {
	Boot,
	Menu,
	Game,
	GameOver,
}

Direction :: enum {
	Up,
	Left,
	Right,
	Down,
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
imageContents :: [?][]u8 {
	#load("assets/logo.png"),
	#load("assets/grasstile.png"),
	#load("assets/car.png"),
	#load("assets/car_flipped.png"),
	#load("assets/road.png"),
}

score: u32 = 0
bestScore: u32 = 0

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
	carDir:        Direction,
}

roads: [dynamic]RoadEntity

//config vs init: init runs when the game has to be reset, so every time the user starts a new game, however config only runs once - on launch

config :: proc() {
	camera = rl.Camera2D{}
	camera.zoom = 1

	keys = Keyboard{false, false, false, false}

	images = make([dynamic]rl.Texture2D, 0, 0)

	//for fileName in imageFilenames {
	//	filePath := strings.concatenate({"assets/", fileName})
	//	append(&images, utils.loadTexture(filePath))
	//}
	for fileContent in imageContents {
		contentPtr := &fileContent[0]
		append(&images, utils.loadTextureFromMem(contentPtr, i32(len(fileContent))))
	}
}

init :: proc() {
	isGameOver = false

	score = 0

	player = Player {
		rl.Vector2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		rl.Vector2{0, 0},
		20,
		PLAYER_SPEED,
		rl.BLACK,
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

	when DEV {
		rl.SetExitKey(rl.KeyboardKey.END)
	}

	config()
	init()

	for !rl.WindowShouldClose() {
		deltaTime: f32 = rl.GetFrameTime()
		frameIndex += 1

		if !isGameOver { 	//input
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
			if score > bestScore {
				bestScore = score
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
			renderGameOver(deltaTime)
			break

		}

		rl.EndDrawing()

	}

	free()
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

isGameOverTextVisible := true
gameOverTextFlickerDelay: f32 = 0
gameOverOffDelay: f32 = 0
renderGameOver :: proc(deltaTime: f32 = 0) {
	gameOverTextFlickerDelay += deltaTime
	gameOverOffDelay += deltaTime
	if gameOverTextFlickerDelay > GAMEOVER_TEXT_FLICKER_SPEED {
		gameOverTextFlickerDelay = 0
		isGameOverTextVisible = !isGameOverTextVisible
	}
	if isGameOverTextVisible {
		textWidth := rl.MeasureText(GAMEOVER_TEXT, GAMEOVER_TEXT_FONT_SIZE)
		rl.DrawText(
			GAMEOVER_TEXT,
			WINDOW_WIDTH / 2 - textWidth / 2,
			WINDOW_HEIGHT / 2,
			GAMEOVER_TEXT_FONT_SIZE,
			rl.RAYWHITE,
		)
		scoreText := strings.clone_to_cstring(fmt.aprintf("Score: %d, Best: %d", score, bestScore))
		textWidth = rl.MeasureText(scoreText, GAMEOVER_SUBTEXT_FONT_SIZE)
		rl.DrawText(
			scoreText,
			WINDOW_WIDTH / 2 - textWidth / 2,
			WINDOW_HEIGHT / 2 + GAMEOVER_SUBTEXT_FONT_SIZE / 2 + GAMEOVER_TEXT_FONT_SIZE,
			GAMEOVER_SUBTEXT_FONT_SIZE,
			rl.RAYWHITE,
		)
	}

	if gameOverOffDelay > GAMEOVER_SCREEN_OFF_DELAY ||
	   rl.IsKeyDown(rl.KeyboardKey.SPACE) ||
	   rl.IsKeyDown(rl.KeyboardKey.ESCAPE) {
		gameOverOffDelay = 0
		isGameOver = false
		currentScreenState = .Menu
		init()
	}
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
			//rl.DrawRectangle(0, i32(road.yPosition), WINDOW_WIDTH, ROAD_WIDTH, rl.BLACK)

			rl.DrawTexture(images[4], 0, i32(road.yPosition), rl.RAYWHITE)


			for &car in road.cars {
				//rl.DrawRectangle(
				//	i32(car.position.x),
				//	i32(car.position.y),
				//	i32(car.width),
				//	i32(car.height),
				//	rl.GRAY,
				//)
				rl.DrawTexture(
					images[(road.carDir == .Right) ? 2 : 3],
					i32(car.position.x),
					i32(car.position.y),
					rl.RAYWHITE,
				)
			}
		}
		roadIndex := 0
		for &road in roads {
			if road.yPosition > camera.target.y + WINDOW_HEIGHT {
				delete(road.cars)
				unordered_remove(&roads, roadIndex)
				continue
			}

			for &car in road.cars {
				car.position.x += ((road.carDir == .Right) ? CAR_SPEED : -CAR_SPEED) * deltaTime

				if car.position.x > WINDOW_WIDTH {
					car.position.x = -CAR_WIDTH
				}
				if car.position.x < -CAR_WIDTH {
					car.position.x = WINDOW_WIDTH
				}

				if !isGameOver {
					if player.position.x - player.radius < car.position.x + car.width &&
					   player.position.x + player.radius > car.position.x &&
					   player.position.y - player.radius < car.position.y + car.height &&
					   player.position.y + player.radius > car.position.y {
						gameOver()
					}
				}
			}

			road.carSpawnDelay += deltaTime
			if road.carSpawnDelay > CAR_SPAWN_RATE && len(road.cars) < MAX_CARS_PER_ROAD {
				road.carSpawnDelay = 0
				rand.reset(frameIndex + u64(len(road.cars)) + u64(time.now()._nsec))
				yCarOffset := (rand.uint32() % 3) * ROAD_WIDTH / 3 // random 3 lane position
				yCarPadding: f32 = (ROAD_WIDTH / 3 - CAR_HEIGHT) / 2
				car := CarEntity {
					rl.Vector2 {
						(road.carDir == .Right) ? -CAR_WIDTH : WINDOW_WIDTH,
						road.yPosition + f32(yCarOffset) + yCarPadding,
					},
					CAR_WIDTH,
					CAR_HEIGHT,
				}
				append(&road.cars, car)
			}
			roadIndex += 1


		}


	}

	{ 	// render player
		//rl.DrawCircleV(player.position, player.radius, rl.MAROON)
		rl.DrawRectangle(
			i32(player.position.x - player.radius),
			i32(player.position.y - player.radius),
			i32(player.radius * 2),
			i32(player.radius * 2),
			rl.MAROON,
		)
	}

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
	rand.reset(frameIndex + u64(time.now()._nsec) * 100)
	if !isRoadCollidingWithOtherRoadsAtPos(yPos) &&
	   rand.float64_range(0, 100) > 100 - ROAD_SPAWN_PROBABILITY_PERCENT {
		cars := make([dynamic]CarEntity, 0, 0)
		dir := rand.uint32() % 2
		road := RoadEntity{yPos, cars, 0, (dir == 0) ? .Right : .Left}
		for i in 0 ..< MAX_CARS_PER_ROAD {
			yCarOffset := (rand.uint32() % 3) * ROAD_WIDTH / 3
			yCarPadding: f32 = (ROAD_WIDTH / 3 - CAR_HEIGHT) / 2

			yCarPos := road.yPosition + f32(yCarOffset) + yCarPadding
			xCarPos: f32 = rand.float32_range(0, WINDOW_WIDTH)
			guessIndex := 0
			for (isCarCollidingWithOtherCarsAtPos(rl.Vector2{xCarPos, yCarPos}, &road.cars)) {
				guessIndex += 1
				if guessIndex > MAX_CARS_PER_ROAD {
					yCarOffset = (rand.uint32() % 3) * ROAD_WIDTH / 3
					yCarPadding = (ROAD_WIDTH / 3 - CAR_HEIGHT) / 2
					yCarPos = road.yPosition + f32(yCarOffset) + yCarPadding
				}
				rand.reset(frameIndex * 10 + u64(time.now()._nsec))
				xCarPos = rand.float32_range(0, WINDOW_WIDTH)
			}

			car := CarEntity{rl.Vector2{xCarPos, yCarPos}, CAR_WIDTH, CAR_HEIGHT}
			append(&road.cars, car)
		}
		delete(cars)
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

isCarCollidingWithOtherCarsAtPos :: proc(pos: rl.Vector2, carsPtr: ^[dynamic]CarEntity) -> bool {
	assert(carsPtr != nil, "Car Ptr is nil")
	cars := carsPtr^
	for &car in cars {
		if pos.x < car.position.x + car.width &&
		   pos.x + CAR_WIDTH > car.position.x &&
		   pos.y < car.position.y + car.height &&
		   pos.y + CAR_HEIGHT > car.position.y {
			return true
		}
	}
	return false
}

gameOver :: proc() {
	isGameOver = true
	currentScreenState = .GameOver
}

free :: proc() {
	delete(tiles)
	delete(roads)
	for &img in images {
		rl.UnloadTexture(img)
	}
	delete(images)
}

