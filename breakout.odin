package breakout

import rl "vendor:raylib"
import "core:math"
import "core:math/linalg"
import "core:fmt"
import "core:math/rand"

SCREEN_SIZE :: 400
PADDLE_WIDTH :: 50
PADDLE_HEIGHT :: 6
PADDLE_POS_Y :: 320
PADDLE_SPEED :: 200
paddle_pos_x: f32

ball_pos: rl.Vector2
ball_dir: rl.Vector2
BALL_SPEED :: 260
BALL_RADIUS :: 4
BALL_START_Y :: 200

NUM_BLOCKS_X :: 10
NUM_BLOCKS_Y :: 8
BLOCK_WIDTH :: 36
BLOCK_HEIGHT :: 10
blocks: [NUM_BLOCKS_X][NUM_BLOCKS_Y]bool
Block_color :: enum {
    Yellow,
    Green,
    Orange,
    Red,
}
// Color của mỗi row
row_colors := [NUM_BLOCKS_Y]Block_color {
    .Yellow,
    .Yellow,
    .Green,
    .Green,
    .Orange,
    .Orange,
    .Red,
    .Red,
}
// Gán mã màu cho mỗi cái trong enum, [Block_color]rl.Color tương đương với enum có bao nhiêu thì array có bấy nhiêu phần tử
blocks_color_value := [Block_color]rl.Color {
    .Yellow = { 253, 249, 150, 255},
    .Green = { 180, 245, 190, 255},
    .Orange = { 170, 120, 250, 255},
    .Red = { 250, 90, 250, 255},
}

block_color_score := [Block_color]int {
    .Yellow = 10,
    .Green = 8,
    .Orange = 6,
    .Red = 4
}

score: int
started: bool
gameover: bool

restart :: proc() {
    paddle_pos_x = SCREEN_SIZE / 2 - PADDLE_WIDTH / 2
    ball_pos = { SCREEN_SIZE / 2, BALL_START_Y }
    started = false
    gameover = false
    score = 0

    for x in 0..<NUM_BLOCKS_X {
        for y in 0..<NUM_BLOCKS_Y {
            blocks[x][y] = true
        }
    }
}

reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
    new_direction := linalg.reflect(dir, linalg.normalize(normal))
    return linalg.normalize(new_direction)
}

cacl_block_rect :: proc(x, y: int) -> rl.Rectangle {
    return rl.Rectangle {
        f32(20 + x * BLOCK_WIDTH), f32(40 + y * BLOCK_HEIGHT),
        BLOCK_WIDTH, BLOCK_HEIGHT
    }
}

block_exists :: proc(x, y: int) -> bool {
    if (x < 0 || y < 0 || x >= NUM_BLOCKS_X || y >= NUM_BLOCKS_Y) {
        return false
    }

    return blocks[x][y]
}

main :: proc() {
    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(800, 800, "Breakout!")
    rl.SetTargetFPS(500)
    rl.InitAudioDevice()

    ball_texture := rl.LoadTexture("ball.png")
    paddle_texture := rl.LoadTexture("paddle.png")

    hit_block_sound := rl.LoadSound("hit_block.wav")
    hit_paddle_sound := rl.LoadSound("hit_paddle.wav")
    game_over_sound := rl.LoadSound("game_over.wav")

    restart()

    for !rl.WindowShouldClose() {
        dt: f32

        if (!started) {
            // Nếu chưa bắt đầu game thì sẽ di chuyển qua bóng qua lại theo hàm cos
            ball_pos = {
                SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 2.5),
                BALL_START_Y
            }

            if (rl.IsKeyPressed(.SPACE)) {
                // Tính cái điểm giữa của cái paddle
                paddle_middle := rl.Vector2 {
                    paddle_pos_x + PADDLE_WIDTH / 2,
                    PADDLE_POS_Y + PADDLE_HEIGHT / 2
                }
                // Tính vector từ ball tới paddle và normalize nó
                ball_to_paddle := paddle_middle - ball_pos
                ball_dir = linalg.normalize0(ball_to_paddle)
                started = true
            }
        } else if (gameover) {
            if (rl.IsKeyPressed(.SPACE)) {
                restart()
            }
        } else {
            dt = rl.GetFrameTime()                                                                                                                                                                                          
        }

        previous_ball_pos := ball_pos
        ball_pos += ball_dir * BALL_SPEED * dt

        // Kiểm tra nếu bóng chạm vào tường bên phải
        if (ball_pos.x + BALL_RADIUS > SCREEN_SIZE) {
            ball_pos.x = SCREEN_SIZE - BALL_RADIUS
            ball_dir = reflect(ball_dir, rl.Vector2 { -1, 0})
        }

        // Kiểm tra nếu bóng chạm vào tường bên trái 
        if (ball_pos.x - BALL_RADIUS < 0) {
            ball_pos.x = BALL_RADIUS
            ball_dir = reflect(ball_dir, rl.Vector2 { 1, 0})
        }

        // Kiểm tra nếu bóng chạm vào sàn
        if (ball_pos.y + BALL_RADIUS < 0) {
            ball_pos.y = BALL_RADIUS
            ball_dir = reflect(ball_dir, rl.Vector2 { 0, 1})
        }

        // Kiểm tra nếu bóng đã vượt quá màn hình
        if (!gameover && ball_pos.y > SCREEN_SIZE + BALL_RADIUS * 6) {
            gameover = true
            rl.PlaySound(game_over_sound)
        }

        paddle_move_velocity: f32

        if (rl.IsKeyDown(.LEFT)) {
            paddle_move_velocity -= PADDLE_SPEED
        }

        if (rl.IsKeyDown(.RIGHT)) {
            paddle_move_velocity += PADDLE_SPEED
        }

        paddle_pos_x += paddle_move_velocity * dt
        paddle_pos_x = clamp(paddle_pos_x, 0, SCREEN_SIZE - PADDLE_WIDTH)

        paddle_rect := rl.Rectangle({
            paddle_pos_x, PADDLE_POS_Y,
            PADDLE_WIDTH, PADDLE_HEIGHT
        })

        // Kiểm tra va chạm giữa bóng và paddle, sau đó tính toán hướng mới của bóng
        if (rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, paddle_rect)) {
            collision_normal: rl.Vector2            
            
            // Va chạm trên bề mắt
            if (previous_ball_pos.y < paddle_rect.y + paddle_rect.height) {
                collision_normal += { 0, -1 }
                ball_pos.y = paddle_rect.y - BALL_RADIUS
            }
            
            // Va chạm dưới bề mắt
            if (previous_ball_pos.y > paddle_rect.y + paddle_rect.height) {
                collision_normal += { 0, 1 }
                ball_pos.y = paddle_rect.y + paddle_rect.height + BALL_RADIUS
            }

            // Va chạm bên phải
            if (previous_ball_pos.x < paddle_rect.x) {
                collision_normal += { -1, 0 }
                ball_pos.x = paddle_rect.x - BALL_RADIUS
            }

            // Va chạm bên trái
            if (previous_ball_pos.x > paddle_rect.x + paddle_rect.width) {
                collision_normal += { 1, 0 }
                ball_pos.x = paddle_rect.x + paddle_rect.width + BALL_RADIUS
            }

            if (collision_normal != 0) {
                ball_dir = reflect(ball_dir, collision_normal)
            }

            rl.PlaySound(hit_paddle_sound)
        }
        
        block_x_loop: for x in 0..<NUM_BLOCKS_X {
            for y in 0..<NUM_BLOCKS_Y {
                if !blocks[x][y] {
                    continue
                }

                block_rect := cacl_block_rect(x, y)

                if (rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, block_rect)) {
                    collision_normal: rl.Vector2

                    if (previous_ball_pos.y < block_rect.y + block_rect.height) {
                        collision_normal += { 0, -1 }
                    }

                    if (previous_ball_pos.y > block_rect.y + block_rect.height) {
                        collision_normal += { 0, 1 }
                    } 

                    if (previous_ball_pos.x < block_rect.x) {
                        collision_normal += { -1, 0 } 
                    }

                    if (previous_ball_pos.x > block_rect.x + block_rect.width) {
                        collision_normal += { 1, 0 }
                    }

                    if (block_exists(x + int(collision_normal.x), y)) {
                        collision_normal.x = 0
                    }

                    if (block_exists(x, y + int(collision_normal.y))) {
                        collision_normal.y = 0
                    }

                    if (collision_normal != 0) {
                        ball_dir = reflect(ball_dir, collision_normal)
                    }

                    blocks[x][y] = false

                    score += block_color_score[row_colors[y]]

                    rl.SetSoundPitch(hit_block_sound, rand.float32_range(0.8, 1.2))
                    rl.PlaySound(hit_block_sound)

                    break block_x_loop
                }
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground({ 150, 190, 220, 255 })

        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE)
        }

        rl.BeginMode2D(camera)

        rl.DrawTextureV(paddle_texture, { paddle_pos_x, PADDLE_POS_Y }, rl.WHITE)
        rl.DrawTextureV(ball_texture, ball_pos - { BALL_RADIUS, BALL_RADIUS }, rl.WHITE)

        // Vẽ blocks
        for x in 0..<NUM_BLOCKS_X {
            for y in 0..<NUM_BLOCKS_Y {
                if !blocks[x][y] {
                    continue;
                }

                block_rect := cacl_block_rect(x, y)

                top_left := rl.Vector2 {
                    block_rect.x, block_rect.y
                }
                top_right := rl.Vector2 {
                    block_rect.x + block_rect.width, block_rect.y
                }
                bottom_left := rl.Vector2 {
                    block_rect.x, block_rect.y + block_rect.height
                }
                bottom_right := rl.Vector2 {
                    block_rect.x + block_rect.width, block_rect.y + block_rect.height
                }

                rl.DrawRectangleRec(block_rect, blocks_color_value[row_colors[y]])
                rl.DrawLineEx(top_left, top_right, 1, { 50, 60, 168, 100})
                rl.DrawLineEx(top_left, bottom_left, 1, { 50, 60, 168, 100})
                rl.DrawLineEx(bottom_right, bottom_left, 1, { 50, 60, 168, 100})
                rl.DrawLineEx(bottom_right, top_right, 1, { 50, 60, 168, 100})
            }
        }

        score_text := fmt.ctprint(score)
        rl.DrawText(score_text, 5, 5, 10, rl.WHITE)

        if (!started) {
            start_game_text := fmt.ctprint("Start: SPACE")
            start_game_text_width := rl.MeasureText(start_game_text, 15)
            rl.DrawText(start_game_text, SCREEN_SIZE / 2 - start_game_text_width / 2, BALL_START_Y - 30, 15, rl.WHITE)
        }

        if (gameover) {
            game_over_text := fmt.ctprintf("Score: %v. Reset: SPACE", score)
            game_over_text_width := rl.MeasureText(game_over_text, 15)
            rl.DrawText(game_over_text, SCREEN_SIZE / 2 - game_over_text_width / 2, BALL_START_Y - 30, 15, rl.WHITE)
        }

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}