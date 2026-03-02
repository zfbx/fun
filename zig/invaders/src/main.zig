const std = @import("std");
const rl = @import("raylib");

const State = enum {
    running,
    endscreen,
    gameover,
    won,
};

const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn intersects(self: @This(), other: @This()) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn draw(self: @This(), color: rl.Color) void {
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
    } = .{},
    invader: struct {
        width: i32 = 40,
        height: i32 = 30,
        startX: i32 = 100,
        startY: i32 = 50,
        spacingX: i32 = 60,
        spacingY: i32 = 40,
        moveDelay: i32 = 30,
        dropDistance: i32 = 10,
        shootDelay: i32 = 60,
        shootChance: i32 = 5,
    } = .{},
    shield: struct {
        startX: i32 = 150,
        y: i32 = 450,
        width: i32 = 80,
        height: i32 = 60,
        spacing: i32 = 150,
    } = .{},
    bullet: struct {
        width: i32 = 4,
        height: i32 = 10,
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
        } };
    }

    pub fn update(self: *@This(), screen_width: i32) void {
        self.rect.x = std.math.clamp(self.rect.x, 0, screen_width - self.rect.width);
    }
};

const Bullet = struct {
    rect: Rectangle,
    active: bool = false,
    speed: i32,
    is_player: bool,

    pub fn init(x: i32, y: i32, width: i32, height: i32, speed: i32, is_player: bool) @This() {
        return .{
            .rect = .{ .x = x, .y = y, .width = width, .height = height },
            .speed = speed,
            .is_player = is_player,
        };
    }

    pub fn update(self: *@This(), game: *Game) void {
        if (!self.active) return;
        if (self.is_player) {
            self.rect.y -= self.speed;
            if (self.rect.y < 0) {
                self.active = false;
                game.active_bullets -= 1;
            }
        } else {
            self.rect.y += self.speed;
            if (self.rect.y > game.conf.screen.height) {
                self.active = false;
                game.active_ebullets -= 1;
            }
        }
    }

    pub fn draw(self: @This()) void {
        if (!self.active) return;
        if (self.is_player) self.rect.draw(rl.Color.red) else self.rect.draw(rl.Color.yellow);
    }
};

const Invader = struct {
    rect: Rectangle,
    speed: i32 = 5,
    alive: bool = true,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{ .x = x, .y = y, .width = width, .height = height } };
    }

    pub fn draw(self: @This()) void {
        if (self.alive) self.rect.draw(rl.Color.green);
    }

    pub fn update(self: *@This(), dx: i32, dy: i32) void {
        self.rect.x += dx;
        self.rect.y += dy;
    }
};

const Shield = struct {
    health: u8 = 10,
    rect: Rectangle,

    pub fn init(x: i32, y: i32, width: i32, height: i32) @This() {
        return .{ .rect = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        } };
    }

    pub fn draw(self: @This()) void {
        if (self.health == 0) return;
        self.rect.draw(rl.Color{ .r = 0, .g = 255, .b = 255, .a = @as(u8, @intCast(@min(255, self.health * 25))) });
    }
};

const Game = struct {
    invader_move_right: bool = true,
    active_shields: u8 = 0,
    move_timer: u8 = 0,
    alive_invaders: u8 = 0,
    active_bullets: u8 = 0,
    active_ebullets: u8 = 0,
    enemy_shoot_timer: u8 = 0,
    state: State = State.running,
    score: u16 = 0,
    conf: GameConfig,
    shields: [4]Shield = undefined,
    bullets: [10]Bullet = undefined,
    enemy_bullets: [10]Bullet = undefined,
    invaders: [11][5]Invader = undefined,
    rng: std.Random.DefaultPrng,
    player: Player,

    pub fn handleInput(self: *@This()) void {
        switch (self.state) {
            .gameover, State.won => {
                if (rl.isKeyPressed(rl.KeyboardKey.enter)) resetGame(self);
            },
            .running => {
                if (rl.isKeyDown(rl.KeyboardKey.d)) self.player.rect.x += self.player.speed;
                if (rl.isKeyDown(rl.KeyboardKey.a)) self.player.rect.x -= self.player.speed;
                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    for (&self.bullets) |*bullet| {
                        if (bullet.active) continue;
                        bullet.rect.x = self.player.rect.x + @divFloor(self.player.rect.width, 2) - @divFloor(bullet.rect.width, 2);
                        bullet.rect.y = self.player.rect.y;
                        bullet.active = true;
                        self.active_bullets += 1;
                        break;
                    }
                }
            },
            else => {},
        }
    }

    pub fn update(self: *@This()) void {
        if (self.state != .running) return;

        self.player.update(self.conf.screen.width);

        for (&self.bullets) |*bullet| {
            if (self.active_bullets == 0) break;
            bullet.update(self);
            if (!bullet.active or bullet.rect.y < self.conf.invader.startY) continue;
            bullet_skip: {
                for (&self.invaders) |*col| {
                    for (col) |*invader| {
                        if (!invader.alive) continue;
                        if (bullet.rect.intersects(invader.rect)) {
                            bullet.active = false;
                            self.active_bullets -= 1;
                            invader.alive = false;
                            self.alive_invaders -= 1;
                            self.score += 10;
                            break :bullet_skip;
                        }
                    }
                }
                if (self.active_shields == 0 or bullet.rect.y < self.conf.shield.y) break :bullet_skip;
                for (&self.shields) |*shield| {
                    if (shield.health == 0) continue;
                    if (!bullet.rect.intersects(shield.rect)) continue;
                    bullet.active = false;
                    self.active_bullets -= 1;
                    shield.health -= 1;
                    if (shield.health == 0) self.active_shields -= 1;
                    break :bullet_skip;
                }
            }
        }

        self.enemy_shoot_timer += 1;
        if (self.enemy_shoot_timer >= self.conf.invader.shootDelay) {
            self.enemy_shoot_timer = 0;
            invader_fired: {
                for (&self.invaders) |*col| {
                    if (self.rng.random().intRangeAtMost(i32, 0, 100) > self.conf.invader.shootChance) continue;
                    for (col) |*invader| {
                        if (!invader.alive) continue;
                        for (&self.enemy_bullets) |*bullet| {
                            if (bullet.active) continue;
                            bullet.rect.x = invader.rect.x + @divFloor(invader.rect.width, 2) - @divFloor(bullet.rect.width, 2);
                            bullet.rect.y = invader.rect.y + invader.rect.height;
                            bullet.active = true;
                            self.active_ebullets += 1;
                            break :invader_fired;
                        }
                    }
                }
            }
        }

        for (&self.enemy_bullets) |*bullet| {
            if (self.active_ebullets == 0) break;
            bullet.update(self);
            if (!bullet.active) continue;
            if (bullet.rect.intersects(self.player.rect)) {
                bullet.active = false;
                self.active_ebullets -= 1;
                self.state = State.gameover;
            }
            for (&self.shields) |*shield| {
                if (shield.health == 0) continue;
                if (!bullet.rect.intersects(shield.rect)) continue;
                bullet.active = false;
                self.active_ebullets -= 1;
                shield.health -= 1;
                break;
            }
        }

        self.move_timer += 1;
        if (self.move_timer >= self.conf.invader.moveDelay) {
            var all_invaders_dead = true;
            self.move_timer = 0;
            var hit_edge = false;
            invader_move: for (&self.invaders) |*col| {
                for (col) |*invader| {
                    if (!invader.alive) continue;
                    all_invaders_dead = false;
                    if (invader.rect.y + invader.rect.height >= self.conf.shield.y) {
                        self.state = State.gameover;
                        break :invader_move;
                    }
                    const dx = if (self.invader_move_right) invader.speed else -invader.speed;
                    const next_x = invader.rect.x + dx;
                    if (next_x <= 0 or next_x + invader.rect.width >= self.conf.screen.width) {
                        hit_edge = true;
                        break :invader_move;
                    }
                }
            }
            if (hit_edge) self.invader_move_right = !self.invader_move_right;
            for (&self.invaders) |*col| {
                for (col) |*invader| {
                    if (!invader.alive) continue;
                    if (hit_edge) {
                        invader.update(0, self.conf.invader.dropDistance);
                    } else {
                        const dx = if (self.invader_move_right) invader.speed else -invader.speed;
                        invader.update(dx, 0);
                    }
                }
            }
            if (all_invaders_dead) self.state = State.won;
        }
    }

    pub fn draw(self: @This()) void {
        rl.clearBackground(rl.Color.purple);
        sw: switch (self.state) {
            .gameover => {
                centerScreenText("GAMEOVER", self.conf.screen.width, 40, 250, rl.Color.red);
                continue :sw State.endscreen;
            },
            .won => {
                centerScreenText("YOU WIN", self.conf.screen.width, 40, 250, rl.Color.gold);
                continue :sw State.endscreen;
            },
            .endscreen => {
                centerScreenText(rl.textFormat("Final Score %d", .{self.score}), self.conf.screen.width, 30, 310, rl.Color.white);
                centerScreenText("Press ENTER to play again or ESC to quit", self.conf.screen.width, 25, 370, rl.Color.white);
            },
            .running => {
                for (&self.shields) |*shield| shield.draw();
                self.player.rect.draw(rl.Color.blue);
                for (&self.invaders) |*col| {
                    for (col) |*invader| {
                        invader.draw();
                    }
                }
                for (&self.bullets) |*bullet| bullet.draw();
                for (&self.enemy_bullets) |*bullet| bullet.draw();
                rl.drawText(rl.textFormat("Score %d", .{self.score}), 20, 20, 20, rl.Color.green);
                centerScreenText("A and D to move, SPACE to fire", self.conf.screen.width, 20, 0, rl.Color.white);
            },
        }
    }
};

pub fn createGame() Game {
    const conf = GameConfig{};
    var game = Game{
        .conf = conf,
        .player = Player.init(
            @divFloor(conf.screen.width, 2) - @divFloor(conf.player.width, 2),
            conf.screen.height - 60,
            conf.player.width,
            conf.player.height,
        ),
        .rng = std.Random.DefaultPrng.init(@as(u64, std.crypto.random.int(u64))),
    };
    for (&game.shields, 0..) |*shield, i| {
        game.active_shields += 1;
        shield.* = Shield.init(conf.shield.startX + @as(i32, @intCast(i)) * conf.shield.spacing, conf.shield.y, conf.shield.width, conf.shield.height);
    }
    for (&game.bullets) |*bullet| {
        bullet.* = Bullet.init(0, 0, conf.bullet.width, conf.bullet.height, 10, true);
    }
    for (&game.enemy_bullets) |*bullet| {
        bullet.* = Bullet.init(0, 0, conf.bullet.width, conf.bullet.height, 5, false);
    }
    for (&game.invaders, 0..) |*col, i| {
        for (col, 0..) |*invader, j| {
            game.alive_invaders += 1;
            const row = 5 - j; // flip order
            const x = conf.invader.startX + @as(i32, @intCast(i)) * conf.invader.spacingX;
            const y = conf.invader.startY + @as(i32, @intCast(row)) * conf.invader.spacingY;
            invader.* = Invader.init(x, y, conf.invader.width, conf.invader.height);
        }
    }
    return game;
}

pub fn resetGame(game: *Game) void {
    game.* = createGame();
}

pub fn centerScreenText(text: [:0]const u8, screenWidth: i32, size: u16, y: i32, color: rl.Color) void {
    rl.drawText(text, @divFloor(screenWidth, 2) - @divFloor(rl.measureText(text, size), 2), y, size, color);
}

pub fn main() void {
    const conf = GameConfig{};
    rl.initWindow(conf.screen.width, conf.screen.height, conf.title);
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var game = createGame();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        game.handleInput();
        game.update();
        game.draw();
    }
}
