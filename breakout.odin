package breakout

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

SCREEN_SIZE :: 320
PADDLE_WIDTH :: 50
PADDLE_HEIGHT :: 6
PADDLE_POS_Y :: 260
PADDLE_SPEED :: 300
BALL_RADIUS :: 4
BALL_SPEED :: 260
BALL_POS_Y :: 160
NUM_BLOCK_X :: 10
NUM_BLOCK_Y :: 8
BLOCK_WIDTH :: 28
BLOCK_HEIGHT :: 10

Block_Color :: enum {
	Yellow,
	Green,
	Purple,
	Red,
}

row_colors := [NUM_BLOCK_Y]Block_Color {
	.Red,
	.Red,
	.Purple,
	.Purple,
	.Green,
	.Green,
	.Yellow,
	.Yellow,
}

block_color_values := [Block_Color]rl.Color {
	.Yellow = {253, 249, 150, 255},
	.Green  = {180, 245, 190, 255},
	.Purple = {170, 120, 250, 255},
	.Red    = {250, 90, 85, 255},
}

block_color_score := [Block_Color]int {
	.Yellow = 1,
	.Green  = 2,
	.Purple = 3,
	.Red    = 4,
}

blocks: [NUM_BLOCK_X][NUM_BLOCK_Y]bool
paddle_pos_x: f32 // odin init var to
ball_pos: rl.Vector2
ball_dir: rl.Vector2
started: bool
score: int
game_over: bool
accumulated_time: f32
previous_ball_pos: rl.Vector2
previous_paddle_x: f32

reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
	new_dir := linalg.reflect(dir, linalg.normalize(normal))
	return linalg.normalize(new_dir)
}
restart :: proc() {paddle_pos_x = SCREEN_SIZE / 2 - PADDLE_WIDTH / 2
	ball_pos = {SCREEN_SIZE / 2, BALL_POS_Y}
	previous_ball_pos = ball_pos
	previous_paddle_x = paddle_pos_x
	started = false
	game_over = false
	score = 0
	for x in 0 ..< NUM_BLOCK_X {
		for y in 0 ..< NUM_BLOCK_Y {
			blocks[x][y] = true
		}
	}
}
calc_rec :: proc(x, y: int) -> rl.Rectangle {
	return {f32(20 + x * BLOCK_WIDTH), f32(40 + y * BLOCK_HEIGHT), BLOCK_WIDTH, BLOCK_HEIGHT}
}
// check if the block exist on the sides to update the collision normal
block_exist :: proc(x, y: int) -> bool {
	if x < 0 || y < 0 || x >= NUM_BLOCK_X || y >= NUM_BLOCK_Y {
		return false
	}
	return blocks[x][y]
}

main :: proc() {
	//give game vertical sync which can prevent tearing.
	rl.SetConfigFlags({.VSYNC_HINT}) // setup flag before init window
	rl.InitWindow(640, 640, "Breakout")
	rl.InitAudioDevice()
	rl.SetTargetFPS(500) // vsync limits this based on system's capabilities

	ball_texture := rl.LoadTexture("ball.png")
	paddle_texture := rl.LoadTexture("paddle.png")
	hit_block_sound := rl.LoadSound("hit_block.wav")
	hit_paddle_sound := rl.LoadSound("hit_paddle.wav")
	game_over_sound := rl.LoadSound("game_over.wav")
	restart()
	for !rl.WindowShouldClose() {
		DT :: 1.0 / 60.0
		if !started {
			ball_pos = {
				SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 2.5),
				BALL_POS_Y,
			}
			previous_ball_pos = ball_pos
			if rl.IsKeyPressed(.SPACE) {
				paddle_middle := rl.Vector2{paddle_pos_x + PADDLE_WIDTH / 2, PADDLE_POS_Y}
				ball_to_paddle := paddle_middle - ball_pos
				ball_dir = linalg.normalize0(ball_to_paddle)
				started = true
			}
		} else if game_over {
			if (rl.IsKeyPressed(.SPACE)) {
				restart()
			}
		} else {
			accumulated_time += rl.GetFrameTime()
		}

		paddle_velocity: f32
		for accumulated_time >= DT {

			previous_ball_pos = ball_pos // store prev ball pos so we get pos before the ball and paddle overlap/collide
			previous_paddle_x = paddle_pos_x
			ball_pos += ball_dir * BALL_SPEED * DT

			// when ball hits the right wall
			if ball_pos.x + BALL_RADIUS > SCREEN_SIZE {
				ball_pos.x = SCREEN_SIZE - BALL_RADIUS
				ball_dir = reflect(ball_dir, rl.Vector2{-1, 0})
			}
			//when ball hits the top wall
			if ball_pos.y - BALL_RADIUS < 0 {
				ball_pos.y = BALL_RADIUS
				ball_dir = reflect(ball_dir, rl.Vector2{0, 1})
			}
			//when ball hits the left wall
			if ball_pos.x - BALL_RADIUS < 0 {
				ball_pos.x = BALL_RADIUS
				ball_dir = reflect(ball_dir, rl.Vector2{1, 0})
			}
			//when ball goes below paddle or hit down wall ie Game Over
			if !game_over && ball_pos.y + BALL_RADIUS > SCREEN_SIZE {
				game_over = true
				rl.PlaySound(game_over_sound)
			}
			if (rl.IsKeyDown(.A)) {

				paddle_velocity -= PADDLE_SPEED
			}
			if (rl.IsKeyDown(.D)) {
				paddle_velocity += PADDLE_SPEED
			}

			paddle_pos_x += paddle_velocity * DT
			paddle_pos_x = clamp(paddle_pos_x, 0, SCREEN_SIZE - PADDLE_WIDTH)
			paddle_rec := rl.Rectangle{paddle_pos_x, PADDLE_POS_Y, PADDLE_WIDTH, PADDLE_HEIGHT}

			if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, paddle_rec) {
				collision_normal: rl.Vector2 // normal to the plane/line with which ball collides
				//if ball collides with top of the paddle
				if previous_ball_pos.y < paddle_rec.y + paddle_rec.height {
					collision_normal += {0, -1} // give a vertical dir
					ball_pos.y = paddle_rec.y - BALL_RADIUS // '-' because we want the ball to hit on the top of paddle not the center
				}
				// if the ball collides with paddles underside
				if previous_ball_pos.y > paddle_rec.height + paddle_rec.y {
					collision_normal += {0, 1}
					ball_pos.y = paddle_rec.y + paddle_rec.height + BALL_RADIUS
				}
				// if ball comes from right and collides with the paddle on the side
				if previous_ball_pos.x < paddle_rec.x {
					collision_normal += {-1, 0}
				}
				// same as above just from left
				if previous_ball_pos.x > paddle_rec.x + paddle_rec.width {
					collision_normal += {1, 0}
				}
				//Reflect the ball when hit
				if collision_normal != 0 {
					ball_dir = reflect(ball_dir, collision_normal) // normalize used to make sure its a vector
				}
				rl.PlaySound(hit_paddle_sound)
			}

			block_collision_loop: for x in 0 ..< NUM_BLOCK_X {
				for y in 0 ..< NUM_BLOCK_Y {
					if blocks[x][y] == false {
						continue
					}
					block_rect := calc_rec(x, y)
					if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, block_rect) {
						// same as collision check for paddle
						collision_normal: rl.Vector2
						if previous_ball_pos.y < block_rect.y {
							collision_normal += {0, -1}
						}
						if previous_ball_pos.y > block_rect.y + block_rect.height {
							collision_normal += {0, 1}
						}
						if previous_ball_pos.x < block_rect.x {
							collision_normal += {-1, 0}
						}
						if previous_ball_pos.x > block_rect.x + block_rect.width {
							collision_normal += {1, 0}
						}
						if block_exist(x + int(collision_normal.x), y) {
							collision_normal.x = 0
						}
						if block_exist(x, y + int(collision_normal.y)) {
							collision_normal.y = 0
						}
						if collision_normal != 0 {
							ball_dir = reflect(ball_dir, collision_normal)

						}
						blocks[x][y] = false
						row_color := row_colors[y]
						score += block_color_score[row_color]
						rl.SetSoundPitch(hit_block_sound, rand.float32_range(0.8, 1.2))
						rl.PlaySound(hit_block_sound)
						break block_collision_loop
					}
				}
			}
			accumulated_time -= DT
		}
		blend := accumulated_time / DT
		ball_render_pos := math.lerp(previous_ball_pos, ball_pos, blend)
		paddle_render_pos_x := math.lerp(previous_paddle_x, paddle_pos_x, blend)
		rl.BeginDrawing()
		defer rl.EndDrawing() // it will run this after the end
		rl.ClearBackground({190, 220, 180, 250})
		camera := rl.Camera2D {
			zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE), // zooming on the main game screen which is 320
		}
		rl.BeginMode2D(camera)
		for x in 0 ..< NUM_BLOCK_X {
			for y in 0 ..< NUM_BLOCK_Y {
				if blocks[x][y] == false {
					continue
				}
				block_rect := calc_rec(x, y)
				top_left := rl.Vector2{block_rect.x, block_rect.y}
				top_right := rl.Vector2{block_rect.x + block_rect.width, block_rect.y}
				bottom_left := rl.Vector2{block_rect.x, block_rect.y + block_rect.height}
				bottom_right := rl.Vector2 {
					block_rect.x + block_rect.width,
					block_rect.y + block_rect.height,
				}
				rl.DrawRectangleRec(block_rect, block_color_values[row_colors[y]])
				rl.DrawLineEx(top_left, top_right, 1, {255, 255, 170, 100})
				rl.DrawLineEx(top_left, bottom_left, 1, {255, 255, 170, 100})
				rl.DrawLineEx(top_right, bottom_right, 1, {255, 255, 170, 100})
				rl.DrawLineEx(bottom_left, bottom_right, 1, {255, 255, 170, 100})
			}
		}

		rl.DrawTextureV(paddle_texture, {paddle_render_pos_x, PADDLE_POS_Y}, rl.WHITE)
		rl.DrawTextureV(ball_texture, ball_render_pos - {BALL_RADIUS, BALL_RADIUS}, rl.WHITE) // DrawTextureV draws it at top-left pos so we are subtracting radius to draw the texture at the center of the ball
		score_text := fmt.ctprint(score) // takes any value creates a string. 't' stands to temp allocator
		rl.DrawText(score_text, 5, 5, 10, rl.WHITE) //since rl is written in c , it want a cstring

		if !started {
			start_text := fmt.ctprint("Press Space to Start")
			start_text_width := rl.MeasureText(start_text, 15)
			rl.DrawText(
				start_text,
				SCREEN_SIZE / 2 - start_text_width / 2,
				BALL_POS_Y - 30,
				15,
				rl.WHITE,
			)
		}


		if game_over {
			game_over_text := fmt.ctprintf("Score: %v.\n Press Space to Restart", score)
			go_txt_width := rl.MeasureText(game_over_text, 15)
			rl.DrawText(
				game_over_text,
				SCREEN_SIZE / 2 - go_txt_width / 2,
				BALL_POS_Y - 30,
				15,
				rl.WHITE,
			)
		}
		rl.EndMode2D()

		free_all(context.temp_allocator) // free all temp space at end of the loop
	}
	rl.CloseAudioDevice()
	rl.CloseWindow()
}
