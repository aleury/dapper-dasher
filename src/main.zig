const std = @import("std");
const rl = @import("raylib");

const Anim = struct {
    frame: f32,
    frames: f32,
    frame_time: f32,
    update_time: f32,
    pos: rl.Vector2,
    rec: rl.Rectangle,
    fn tick(self: *Anim, dt: f32) void {
        self.frame_time += dt;
        if (self.frame_time >= self.update_time) {
            self.frame += 1;
            self.frame_time = 0.0;
            self.rec.x = self.frame * self.rec.width;
            if (self.frame > self.frames - 1) {
                self.frame = 0;
            }
        }
    }
};

fn create_anim(x: f32, y: f32, width: f32, height: f32, frames: f32, update_time: f32) Anim {
    return Anim{
        .frame = 0,
        .frames = frames,
        .frame_time = 0,
        .update_time = update_time,
        .pos = rl.Vector2{
            .x = x,
            .y = y,
        },
        .rec = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = width,
            .height = height,
        },
    };
}

fn create_hit_box(anim: Anim, pad: f32) rl.Rectangle {
    return rl.Rectangle.init(
        anim.pos.x + pad - pad / 2.0,
        anim.pos.y + pad - pad / 2.0,
        anim.rec.width - pad,
        anim.rec.height - pad,
    );
}

fn is_on_ground(anim: Anim, window_height: comptime_int) bool {
    return anim.pos.y >= window_height - anim.rec.height;
}

pub fn main() !void {
    const window_width = 512;
    const window_height = 380;

    rl.setConfigFlags(.{ .vsync_hint = true });
    rl.initWindow(window_width, window_height, "Dapper Dasher!");
    rl.setTargetFPS(60);
    defer rl.closeWindow();

    // Setup texture for nebula
    const nebula_sprite_sheet = rl.loadTexture("textures/12_nebula_spritesheet.png");
    defer rl.unloadTexture(nebula_sprite_sheet);
    const nebula_sprite_sheet_width: f32 = @floatFromInt(nebula_sprite_sheet.width);
    const nebula_sprite_sheet_height: f32 = @floatFromInt(nebula_sprite_sheet.height);
    const nebula_width = nebula_sprite_sheet_width / 8;
    const nebula_height = nebula_sprite_sheet_height / 8;

    const num_nebulae = 5;
    var nebulae: [num_nebulae]Anim = undefined;
    for (&nebulae, 0..) |*nebula, i| {
        const k: f32 = @floatFromInt(i);
        const update_time: f32 = if (i % 2 > 0) 1.0 / 16.0 else 1.0 / 12.0;
        nebula.* = create_anim(window_width + k * 300, window_height - nebula_height, nebula_width, nebula_height, 8, update_time);
    }

    // x-velocity pixels per second
    const nebula_velocity = -300.0;

    // Setup texture for player sprite
    const scarfy_sprite_sheet = rl.loadTexture("textures/scarfy.png");
    defer rl.unloadTexture(scarfy_sprite_sheet);
    const scarfy_sprite_sheet_width: f32 = @floatFromInt(scarfy_sprite_sheet.width);
    const scarfy_width = scarfy_sprite_sheet_width / 6;
    const scarfy_height: f32 = @floatFromInt(scarfy_sprite_sheet.height);

    var scarfy = create_anim((window_width - scarfy_width) / 2, window_height - scarfy_height, scarfy_width, scarfy_height, 6, 1.0 / 12.0);

    var is_in_air = false;
    const gravity = 1300.0; // pixels per second per second

    var velocity: f32 = 0.0; // pixels per second
    const jump_velocity = -600.0; // pixels per second;

    const background = rl.loadTexture("textures/far-buildings.png");
    defer rl.unloadTexture(background);
    const background_width: f32 = @floatFromInt(background.width);
    var bg1_pos = rl.Vector2.init(0, 0);
    var bg2_pos = rl.Vector2.init(background_width, 0);

    const midground = rl.loadTexture("textures/back-buildings.png");
    defer rl.unloadTexture(midground);
    const midground_width: f32 = @floatFromInt(midground.width);
    var mg1_pos = rl.Vector2.init(0, 0);
    var mg2_pos = rl.Vector2.init(midground_width, 0);

    const foreground = rl.loadTexture("textures/foreground.png");
    defer rl.unloadTexture(foreground);
    const foreground_width: f32 = @floatFromInt(foreground.width);
    var fg1_pos = rl.Vector2.init(0, 0);
    var fg2_pos = rl.Vector2.init(foreground_width * 2, 0);

    var finish_line = nebulae[num_nebulae - 1].pos.x;

    var won_game = false;
    var collision = false;
    const display_hit_boxes = false;
    const nebula_hit_box_padding = 70.0;

    while (!rl.windowShouldClose()) {
        // time since last frame: seconds per frame
        const dt = rl.getFrameTime();

        // update background
        bg1_pos.x -= 20 * dt;
        if (bg1_pos.x <= -background_width * 2) {
            bg1_pos.x = 0.0;
        }

        // update midground
        mg1_pos.x -= 40 * dt;
        if (mg1_pos.x <= -midground_width * 2) {
            mg1_pos.x = 0.0;
        }

        // update foreground
        fg1_pos.x -= 80 * dt;
        if (fg1_pos.x <= -foreground_width * 2) {
            fg1_pos.x = 0.0;
        }

        // do ground check
        if (is_on_ground(scarfy, window_height)) {
            // rectangle is on the ground
            velocity = 0;
            is_in_air = false;
        } else {
            // apply gravity when rectangle is in the air
            velocity += gravity * dt;
            is_in_air = true;
        }

        // check for jump
        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            velocity += if (!is_in_air) jump_velocity else jump_velocity * 1.25;
        }

        // update scarfy position
        scarfy.pos.y += velocity * dt;

        // update nebulae
        for (&nebulae) |*nebula| {
            nebula.pos.x += nebula_velocity * dt;
        }

        // update finish line position
        finish_line += nebula_velocity * dt;
        if (scarfy.pos.x >= finish_line) {
            won_game = true;
        }

        // update scarfy animation frame
        if (!is_in_air) {
            scarfy.tick(dt);
        }

        // update nebula animation frames
        for (&nebulae) |*nebula| {
            nebula.tick(dt);
        }

        // check collisions
        const scarfy_hit_box = create_hit_box(scarfy, 20.0);
        for (nebulae) |nebula| {
            const nebula_hit_box = create_hit_box(nebula, nebula_hit_box_padding);
            if (rl.checkCollisionRecs(scarfy_hit_box, nebula_hit_box)) {
                collision = true;
                break;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        // draw the background
        bg2_pos.x = bg1_pos.x + background_width * 2;
        rl.drawTextureEx(background, bg1_pos, 0.0, 2.0, rl.Color.white);
        rl.drawTextureEx(background, bg2_pos, 0.0, 2.0, rl.Color.white);

        // draw the midground
        mg2_pos.x = mg1_pos.x + midground_width * 2;
        rl.drawTextureEx(midground, mg1_pos, 0.0, 2.0, rl.Color.white);
        rl.drawTextureEx(midground, mg2_pos, 0.0, 2.0, rl.Color.white);

        // draw the foreground
        fg2_pos.x = fg1_pos.x + foreground_width * 2;
        rl.drawTextureEx(foreground, fg1_pos, 0.0, 2.0, rl.Color.white);
        rl.drawTextureEx(foreground, fg2_pos, 0.0, 2.0, rl.Color.white);

        if (collision) {
            rl.drawText("Game Over! :(", window_width / 2 - 120, window_height / 2 - 20, 40, rl.Color.red);
        } else if (won_game) {
            rl.drawTextureRec(scarfy_sprite_sheet, scarfy.rec, scarfy.pos, rl.Color.white);
            if (display_hit_boxes) {
                rl.drawRectangleRec(scarfy_hit_box, rl.fade(rl.Color.lime, 0.50));
            }

            rl.drawText("You won! =D", window_width / 2 - 100, window_height / 2 - 20, 40, rl.Color.ray_white);
        } else {
            rl.drawTextureRec(scarfy_sprite_sheet, scarfy.rec, scarfy.pos, rl.Color.white);
            if (display_hit_boxes) {
                rl.drawRectangleRec(scarfy_hit_box, rl.fade(rl.Color.lime, 0.50));
            }

            for (nebulae, 0..) |nebula, i| {
                const color = if (i % 2 > 0) rl.Color.red else rl.Color.white;
                rl.drawTextureRec(nebula_sprite_sheet, nebula.rec, nebula.pos, color);

                if (display_hit_boxes) {
                    const hit_box = create_hit_box(nebula, nebula_hit_box_padding);
                    rl.drawRectangleRec(hit_box, rl.fade(rl.Color.lime, 0.50));
                }
            }
        }
    }
}
