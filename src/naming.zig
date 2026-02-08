const std = @import("std");

const adjectives = [26][]const []const u8{
    // A
    &.{ "able", "aged", "airy", "apt" },
    // B
    &.{ "bold", "bare", "blue", "bent" },
    // C
    &.{ "calm", "cold", "crisp", "cool" },
    // D
    &.{ "dark", "deep", "dry", "dim" },
    // E
    &.{ "easy", "even", "edgy", "elm" },
    // F
    &.{ "fast", "fair", "firm", "flat" },
    // G
    &.{ "good", "glad", "gray", "grim" },
    // H
    &.{ "half", "hard", "high", "hazy" },
    // I
    &.{ "idle", "icy", "iron", "ill" },
    // J
    &.{ "just", "jade", "java", "jet" },
    // K
    &.{ "keen", "kind", "knit", "key" },
    // L
    &.{ "last", "late", "lean", "long" },
    // M
    &.{ "mild", "main", "mean", "mint" },
    // N
    &.{ "neat", "new", "next", "nice" },
    // O
    &.{ "odd", "old", "open", "oval" },
    // P
    &.{ "pale", "past", "pink", "pure" },
    // Q
    &.{ "quad", "quay", "quip", "quiz" },
    // R
    &.{ "raw", "real", "rich", "ripe" },
    // S
    &.{ "safe", "slim", "soft", "sure" },
    // T
    &.{ "tall", "tame", "tidy", "trim" },
    // U
    &.{ "used", "uber", "up", "urge" },
    // V
    &.{ "vast", "veil", "void", "vine" },
    // W
    &.{ "warm", "weak", "wide", "wild" },
    // X
    &.{ "xray", "xeno", "xing", "xtra" },
    // Y
    &.{ "yet", "yore", "yawl", "yew" },
    // Z
    &.{ "zen", "zero", "zinc", "zany" },
};

const nouns = [26][]const []const u8{
    // A
    &.{ "arch", "axle", "acre", "ash" },
    // B
    &.{ "barn", "beam", "bolt", "bone" },
    // C
    &.{ "cave", "cask", "coal", "cove" },
    // D
    &.{ "dale", "dock", "dune", "dusk" },
    // E
    &.{ "edge", "echo", "elk", "elm" },
    // F
    &.{ "fern", "fawn", "ford", "fog" },
    // G
    &.{ "glen", "gale", "gate", "grit" },
    // H
    &.{ "haze", "helm", "hive", "hull" },
    // I
    &.{ "isle", "iron", "iris", "ink" },
    // J
    &.{ "jade", "jolt", "jute", "jar" },
    // K
    &.{ "knot", "keel", "kiln", "knob" },
    // L
    &.{ "lake", "lark", "loft", "loom" },
    // M
    &.{ "mill", "mist", "moth", "moss" },
    // N
    &.{ "nest", "node", "nook", "nave" },
    // O
    &.{ "oast", "opal", "orca", "oxen" },
    // P
    &.{ "peak", "pine", "pond", "port" },
    // Q
    &.{ "quay", "quad", "quay", "quiz" },
    // R
    &.{ "reef", "root", "rust", "raft" },
    // S
    &.{ "sage", "silo", "slab", "stem" },
    // T
    &.{ "tarn", "tide", "twig", "turf" },
    // U
    &.{ "urn", "ulna", "unit", "upon" },
    // V
    &.{ "vale", "vine", "volt", "veil" },
    // W
    &.{ "weld", "well", "wick", "wren" },
    // X
    &.{ "xray", "xylo", "xing", "xyst" },
    // Y
    &.{ "yoke", "yarn", "yawl", "yurt" },
    // Z
    &.{ "zone", "zinc", "zeal", "zero" },
};

/// Generate a session name from the current time.
/// Format: adjective-noun-command (e.g. "calm-nest-zsh")
/// Adjective letter chosen by hour (0-23 → A-X), noun letter by minute (0-59 → A-Z).
/// Within each letter bucket, the specific word is chosen pseudo-randomly from the
/// available options to reduce collisions while keeping names time-correlated.
pub fn generate(buf: *[64]u8, command: []const u8) []const u8 {
    const ts = std.time.timestamp();
    const epoch_secs: u64 = @intCast(if (ts > 0) ts else 0);
    const day_secs = epoch_secs % 86400;
    const hour = day_secs / 3600;
    const minute = (day_secs % 3600) / 60;
    const second = day_secs % 60;

    // Use hour (0-23) for adjective letter, wrapping into A-X
    const adj_letter: usize = @intCast(hour % 26);
    // Use minute (0-59) mapped to noun letter - spread across alphabet
    // minute / 2.3 ≈ 0-25, but we'll use a simpler mapping
    const noun_letter: usize = @intCast((minute * 26) / 60);

    // Pick word within bucket using second as jitter
    const adj_bucket = adjectives[adj_letter];
    const noun_bucket = nouns[noun_letter];
    const adj = adj_bucket[second % adj_bucket.len];
    const noun = noun_bucket[(second / 4) % noun_bucket.len];

    // Extract base command name (strip path)
    const cmd_base = if (std.mem.lastIndexOfScalar(u8, command, '/')) |i|
        command[i + 1 ..]
    else
        command;

    // Truncate command to keep total name short
    const cmd_len = @min(cmd_base.len, 12);

    const result = std.fmt.bufPrint(buf, "{s}-{s}-{s}", .{ adj, noun, cmd_base[0..cmd_len] }) catch {
        // Fallback: just use adj-noun
        return std.fmt.bufPrint(buf, "{s}-{s}", .{ adj, noun }) catch return buf[0..0];
    };
    return result;
}

/// Check if a name conflicts with existing sessions in the socket directory.
/// Returns true if the name is already in use.
pub fn nameExists(dir_path: []const u8, name: []const u8) bool {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, name }) catch return false;
    std.fs.accessAbsolute(full_path, .{}) catch return false;
    return true;
}

/// Generate a unique session name, probing with numeric suffixes on collision.
pub fn generateUnique(buf: *[64]u8, command: []const u8, socket_dir: []const u8) []const u8 {
    const base = generate(buf, command);
    if (!nameExists(socket_dir, base)) return base;

    // Collision: try suffixes 2-9
    var suffix_buf: [64]u8 = undefined;
    var i: u8 = 2;
    while (i <= 9) : (i += 1) {
        const suffixed = std.fmt.bufPrint(&suffix_buf, "{s}{d}", .{ base, i }) catch break;
        if (!nameExists(socket_dir, suffixed)) {
            @memcpy(buf[0..suffixed.len], suffixed);
            return buf[0..suffixed.len];
        }
    }

    // Extremely unlikely: just return the base name and let socket creation fail
    return base;
}

test "generate produces non-empty name" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "zsh");
    try std.testing.expect(name.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, name, "-") != null);
    // Should end with command name
    try std.testing.expect(std.mem.endsWith(u8, name, "zsh"));
}

test "generate strips command path" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "/usr/bin/bash");
    try std.testing.expect(std.mem.endsWith(u8, name, "bash"));
    // Should not contain /
    try std.testing.expect(std.mem.indexOf(u8, name, "/") == null);
}

test "generate format is adjective-noun-command" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "fish");
    // Should have exactly 2 dashes (adj-noun-cmd)
    var dash_count: usize = 0;
    for (name) |c| {
        if (c == '-') dash_count += 1;
    }
    try std.testing.expect(dash_count == 2);
}
