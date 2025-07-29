package breakout

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

SCREEN_SIZE :: 320
PADDLE_WIDTH :: 50
PADDLE_HEIGHT :: 6
PADDLE_POS_Y :: 260
PADDLE_SPEED :: 200
BALL_RADIUS :: 4
BALL_SPEED :: 260
BALL_POS_Y :: 160
NUM_BLOCK_X :: 10
NUM_BLOCK_Y :: 8
paddle_pos_x: f32 // odin init var to
ball_pos: rl.Vector2
ball_dir: rl.Vector2
started: bool
reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
	new_dir := linalg.reflect(dir, linalg.normalize(normal))
	return linalg.normalize(new_dir)
}
restart :: proc() {paddle_pos_x = SCREEN_SIZE / 2 - PADDLE_WIDTH / 2
	ball_pos = {SCREEN_SIZE / 2, BALL_POS_Y}
	started = false
}

main :: proc() {
	//give game vertical sync which can prevent tearing.
	rl.SetConfigFlags({.VSYNC_HINT}) // setup flag before init window
	rl.InitWindow(640, 640, "Breakout")
	rl.SetTargetFPS(500) // vsync limits this based on system's capabilities
	restart()
	for !rl.WindowShouldClose() {
		dt: f32
		if !started {
			ball_pos = {
				SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 2.5),
				BALL_POS_Y,
			}
			if rl.IsKeyPressed(.SPACE) {
				paddle_middle := rl.Vector2{paddle_pos_x + PADDLE_WIDTH / 2, PADDLE_POS_Y}
				ball_to_paddle := paddle_middle - ball_pos
				ball_dir = linalg.normalize0(ball_to_paddle)
				started = true
			}
		} else {
			dt = rl.GetFrameTime()
		}
		paddle_velocity: f32
		previous_ball_pos := ball_pos // store prev ball pos so we get pos before the ball and paddle overlap/collide
		ball_pos += ball_dir * BALL_SPEED * dt

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
		//when ball goes below paddle or hit down wall
		if ball_pos.y + BALL_RADIUS > SCREEN_SIZE {
			restart()
		}
		if (rl.IsKeyDown(.A)) {

			paddle_velocity -= PADDLE_SPEED
		}
		if (rl.IsKeyDown(.D)) {
			paddle_velocity += PADDLE_SPEED
		}

		paddle_pos_x += paddle_velocity * dt
		paddle_pos_x = clamp(paddle_pos_x, 0, SCREEN_SIZE - PADDLE_WIDTH)
		paddle_rec := rl.Rectangle{paddle_pos_x, PADDLE_POS_Y, PADDLE_WIDTH, PADDLE_HEIGHT}
		if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, paddle_rec) {
			collision_normal: rl.Vector2 // normal to the plane/line with which ball collides
			//if ball collides with top of the paddle
			if previous_ball_pos.y < paddle_rec.y + paddle_rec.height {
				collision_normal += {0, -1} // give a vertical dir
				ball_pos.y = paddle_rec.y - BALL_RADIUS // '-' because we want the ball to sit on the paddle not the center of the ball
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
		}
		rl.BeginDrawing()
		defer rl.EndDrawing() // it will run this after the end
		rl.ClearBackground({190, 220, 180, 250})
		camera := rl.Camera2D {
			zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE), // zooming on the main game screen which is 320
		}

		rl.BeginMode2D(camera)
		rl.DrawRectangleRec(paddle_rec, {50, 150, 90, 255})
		rl.DrawCircleV(ball_pos, BALL_RADIUS, {200, 50, 150, 250})
		rl.EndMode2D()
	}

	rl.CloseWindow()
}
