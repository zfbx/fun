const std = @import("std");
const rl = @import("raylib");

const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    color: rl.Color,

    pub fn intersects(self: @This(), other: @This()) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn draw(self: @This()) void {
        self.drawWithColor(self.color);
    }

    pub fn drawWithColor(self: @This(), color: rl.Color) void {
        rl.drawRectangle(self.x, self.y, self.width, self.height, color);
    }
};

const GameConfig = struct {
    title: [:0]const u8 = "Zig Invaders",
    screen: struct {
        width: i32 = 800,
        height: i32 = 600,
    } = .{},
    player: struct {
        width: i32 = 50,
        height: i32 = 30,
        bullet: struct {
            width: i32 = 4,
            height: i32 = 10,
            max: i32 = 10,
        } = .{},
    } = .{},
    invader: struct {
        rows: i32 = 5,
        cols: i32 = 11,
        width: i32 = 40,
        height: i32 = 30,
        startX: i32 = 100,
        startY: i32 = 50,
        spacingX: i32 = 60,
        spacingY: i32 = 40,
        speed: i32 = 5,
        moveDelay: i32 = 30,
        dropDistance: i32 = 10,
        shootDelay: i32 = 60,
        shootChance: i32 = 5,
        bullet: struct {
            width: i32 = 4,
            height: i32 = 10,
            max: i32 = 10,
        } = .{},
    } = .{},
    shield: struct {
        count: i32 = 4,
        startX: i32 = 150,
        y: i32 = 450,
        width: i32 = 80,
        height: i32 = 60,
        spacing: i32 = 150,
    } = .{},
};

const Player = struct {
    rect: Rectangle,
    speed: i32 = 5,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = rl.Color.blue,
        } };
    }

    pub fn update(self: *@This()) void {
        if (rl.isKeyDown(rl.KeyboardKey.d)) {
            self.rect.x += self.speed;
        }
        if (rl.isKeyDown(rl.KeyboardKey.a)) {
            self.rect.x -= self.speed;
        }
        self.rect.x = std.math.clamp(self.rect.x, 0, rl.getScreenWidth() - self.rect.width);
    }
};

const Bullet = struct {
    rect: Rectangle,
    speed: i32 = 10,
    active: bool = false,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = rl.Color.red,
        } };
    }

    pub fn update(self: *@This()) void {
        if (!self.active) return;
        self.rect.y -= self.speed;
        if (self.rect.y < 0) {
            self.active = false;
        }
    }

    pub fn draw(self: @This()) void {
        if (self.active) self.rect.draw();
    }
};

const Invader = struct {
    rect: Rectangle,
    speed: i32 = 5,
    alive: bool = true,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = rl.Color.green,
        } };
    }

    pub fn draw(self: @This()) void {
        if (self.alive) self.rect.draw();
    }

    pub fn update(self: *@This(), dx: i32, dy: i32) void {
        self.rect.x += dx;
        self.rect.y += dy;
    }
};

const EnemyBullet = struct {
    rect: Rectangle,
    speed: i32 = 5,
    active: bool = false,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = rl.Color.yellow,
        } };
    }

    pub fn update(self: *@This(), screen_height: i32) void {
        if (!self.active) return;
        self.rect.y += self.speed;
        if (self.rect.y > screen_height) self.active = false;
    }

    pub fn draw(self: @This()) void {
        if (self.active) self.rect.draw();
    }
};

const Shield = struct {
    rect: Rectangle,
    health: i32 = 10,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .color = undefined,
        } };
    }

    pub fn draw(self: @This()) void {
        if (self.health == 0) return;
        self.rect.drawWithColor(rl.Color{ .r = 0, .g = 255, .b = 255, .a = @as(u8, @intCast(@min(255, self.health * 25))) });
    }
};

pub fn centerScreenText(text: [:0]const u8, screenwidth: i32, size: i32, y: i32, color: rl.Color) void {
    rl.drawText(text, @divFloor(screenwidth, 2) - @divFloor(rl.measureText(text, size), 2), y, size, color);
}

pub fn resetGame(
    player: *Player,
    bullets: []Bullet,
    enemy_bullets: []EnemyBullet,
    shields: []Shield,
    invaders: anytype,
    invader_direction: *i32,
    score: *i32,
    game: GameConfig,
) void {
    score.* = 0;
    player.* = Player.init(
        @divFloor(game.screen.width, 2) - @divFloor(game.player.width, 2),
        game.screen.height - 60,
        game.player.width,
        game.player.height,
    );
    for (bullets) |*bullet| {
        bullet.active = false;
    }
    for (enemy_bullets) |*bullet| {
        bullet.active = false;
    }
    for (shields) |*shield| {
        shield.health = 10;
    }
    for (invaders, 0..) |*row, i| {
        for (row, 0..) |*invader, j| {
            const x = game.invader.startX + @as(i32, @intCast(j)) * game.invader.spacingX;
            const y = game.invader.startY + @as(i32, @intCast(i)) * game.invader.spacingY;
            invader.* = Invader.init(x, y, game.invader.width, game.invader.height);
        }
    }
    invader_direction.* = 1;
}

pub fn main() void {
    const game = GameConfig{};
    var game_over: bool = false; // turn into a state machine with enums
    var game_won: bool = false; // turn into a state machine with enums
    var invader_direction: i32 = 1;
    var move_timer: i32 = 0;
    var score: i32 = 0;
    var enemy_shoot_timer: i32 = 0;
    rl.setTraceLogLevel(rl.TraceLogLevel.all);
    rl.initWindow(game.screen.width, game.screen.height, game.title);
    defer rl.closeWindow();

    var player = Player.init(
        @divFloor(game.screen.width, 2) - @divFloor(game.player.width, 2),
        game.screen.height - 60,
        game.player.width,
        game.player.height,
    );

    var shields: [game.shield.count]Shield = undefined;
    for (&shields, 0..) |*shield, i| {
        shield.* = Shield.init(game.shield.startX + @as(i32, @intCast(i)) * game.shield.spacing, game.shield.y, game.shield.width, game.shield.height);
    }

    var bullets: [game.player.bullet.max]Bullet = undefined;
    for (&bullets) |*bullet| {
        bullet.* = Bullet.init(0, 0, game.player.bullet.width, game.player.bullet.height);
    }

    var enemy_bullets: [game.invader.bullet.max]EnemyBullet = undefined;
    for (&enemy_bullets) |*ebullet| {
        ebullet.* = EnemyBullet.init(0, 0, game.invader.bullet.width, game.invader.bullet.height);
    }

    var invaders: [game.invader.rows][game.invader.cols]Invader = undefined;
    for (&invaders, 0..) |*row, i| {
        for (row, 0..) |*invader, j| {
            const x = game.invader.startX + @as(i32, @intCast(j)) * game.invader.spacingX;
            const y = game.invader.startY + @as(i32, @intCast(i)) * game.invader.spacingY;
            invader.* = Invader.init(x, y, game.invader.width, game.invader.height);
        }
    }

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.purple);

        if (game_over) {
            centerScreenText("GAMEOVER", game.screen.width, 40, 250, rl.Color.red);
            centerScreenText(rl.textFormat("Final Score %d", .{score}), game.screen.width, 30, 310, rl.Color.white);
            centerScreenText("Press ENTER to play again or ESC to quit", game.screen.width, 25, 370, rl.Color.white);
            if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                game_over = false;
                resetGame(&player, &bullets, &enemy_bullets, &shields, &invaders, &invader_direction, &score, game);
            }
            continue;
        }

        if (game_won) {
            centerScreenText("YOU WIN", game.screen.width, 40, 250, rl.Color.gold);
            centerScreenText(rl.textFormat("Final Score %d", .{score}), game.screen.width, 30, 310, rl.Color.white);
            centerScreenText("Press ENTER to play again or ESC to quit", game.screen.width, 25, 370, rl.Color.white);
            if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                game_won = false;
                resetGame(&player, &bullets, &enemy_bullets, &shields, &invaders, &invader_direction, &score, game);
            }
            continue;
        }

        player.update();
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            for (&bullets) |*bullet| {
                if (bullet.active) continue;
                bullet.rect.x = player.rect.x + @divFloor(player.rect.width, 2) - @divFloor(bullet.rect.width, 2);
                bullet.rect.y = player.rect.y;
                bullet.active = true;
                break;
            }
        }
        for (&bullets) |*bullet| {
            bullet.update();
            if (!bullet.active) continue;
            for (&invaders) |*row| {
                for (row) |*invader| {
                    if (!invader.alive) continue;
                    if (bullet.rect.intersects(invader.rect)) {
                        bullet.active = false;
                        invader.alive = false;
                        score += 10;
                        break;
                    }
                }
            }
            for (&shields) |*shield| {
                if (shield.health == 0) continue;
                if (!bullet.rect.intersects(shield.rect)) continue;
                bullet.active = false;
                shield.health -= 1;
                break;
            }
        }

        for (&enemy_bullets) |*ebullet| {
            ebullet.update(game.screen.height);
            if (!ebullet.active) continue;
            if (ebullet.rect.intersects(player.rect)) {
                ebullet.active = false;
                game_over = true;
            }
            for (&shields) |*shield| {
                if (shield.health == 0) continue;
                if (!ebullet.rect.intersects(shield.rect)) continue;
                ebullet.active = false;
                shield.health -= 1;
                break;
            }
        }

        enemy_shoot_timer += 1;
        if (enemy_shoot_timer >= game.invader.shootDelay) {
            enemy_shoot_timer = 0;
            for (&invaders) |*row| {
                for (row) |*invader| {
                    if (invader.alive and rl.getRandomValue(0, 100) < game.invader.shootChance) {
                        for (&enemy_bullets) |*ebullet| {
                            if (ebullet.active) continue;
                            ebullet.rect.x = invader.rect.x + @divFloor(invader.rect.width, 2) - @divFloor(game.invader.bullet.width, 2);
                            ebullet.rect.y = invader.rect.y + invader.rect.height;
                            ebullet.active = true;
                            break;
                        }
                        break;
                    }
                }
            }
        }

        move_timer += 1;
        if (move_timer >= game.invader.moveDelay) {
            move_timer = 0;

            var hit_edge = false;
            outer_loop: for (&invaders) |*row| {
                for (row) |*invader| {
                    if (!invader.alive) continue;
                    if (invader.rect.intersects(player.rect)) {
                        game_over = true;
                        break :outer_loop;
                    }
                    const next_x = invader.rect.x + (game.invader.speed * invader_direction);
                    if (next_x <= 0 or next_x + invader.rect.width >= game.screen.width) {
                        hit_edge = true;
                        break :outer_loop;
                    }
                }
            }

            var dropDistance: i32 = 0;
            if (hit_edge) {
                invader_direction *= -1;
                dropDistance = game.invader.dropDistance;
            }
            for (&invaders) |*row| {
                for (row) |*invader| {
                    if (dropDistance > 0) invader.update(0, dropDistance) else invader.update(game.invader.speed * invader_direction, 0);
                }
            }
        }

        var all_invaders_dead = true;
        outer_loop: for (&invaders) |*row| {
            for (row) |*invader| {
                if (!invader.alive) continue;
                all_invaders_dead = false;
                break :outer_loop;
            }
        }
        if (all_invaders_dead) {
            game_won = true;
        }

        for (&shields) |*shield| {
            shield.draw();
        }
        player.rect.draw();
        for (&invaders) |*row| {
            for (row) |*invader| {
                invader.draw();
            }
        }
        for (&bullets) |*bullet| {
            bullet.draw();
        }
        for (&enemy_bullets) |*ebullet| {
            ebullet.draw();
        }

        rl.drawText(rl.textFormat("Score %d", .{score}), 20, 20, 20, rl.Color.green);
    }
}
