const std = @import("std");

const bucket_size = 16;

const adjectives = [26][bucket_size][]const u8{
    .{ "able", "aged", "airy", "apt", "avid", "arid", "arch", "awry", "ashy", "acute", "agile", "aloof", "ample", "azure", "aft", "alert" }, // A
    .{ "bold", "bare", "blue", "bent", "big", "buff", "blunt", "brisk", "brief", "broad", "base", "boxy", "burly", "bald", "bay", "bland" }, // B
    .{ "calm", "cold", "crisp", "cool", "coy", "curt", "clean", "close", "crude", "civil", "cozy", "cubic", "coral", "curly", "clear", "chief" }, // C
    .{ "dark", "deep", "dry", "dim", "deft", "dense", "due", "dire", "dual", "done", "drab", "damp", "deaf", "dear", "dizzy", "dusty" }, // D
    .{ "easy", "even", "edgy", "epic", "exact", "extra", "empty", "eager", "elfin", "ebon", "early", "elect", "elite", "evil", "every", "equal" }, // E
    .{ "fast", "fair", "firm", "flat", "fond", "free", "frail", "fresh", "faint", "few", "foxy", "full", "fiery", "fuzzy", "far", "fine" }, // F
    .{ "good", "glad", "gray", "grim", "gilt", "grand", "great", "green", "gruff", "giddy", "glib", "gaunt", "glum", "gross", "gory", "grown" }, // G
    .{ "half", "hard", "high", "hazy", "hot", "hale", "harsh", "hefty", "holy", "husky", "huge", "hasty", "hoary", "humid", "handy", "hilly" }, // H
    .{ "idle", "icy", "iron", "ill", "inky", "inner", "irate", "ivory", "itchy", "inert", "ideal", "inane", "inept", "ionic", "inapt", "ired" }, // I
    .{ "just", "jade", "java", "jet", "jaded", "jazzy", "jerky", "joint", "jolly", "juicy", "jumbo", "jumpy", "jowly", "junky", "jivy", "jaunty" }, // J
    .{ "keen", "kind", "knit", "key", "known", "kempt", "kinky", "kooky", "khaki", "kraft", "karst", "kilted", "kingly", "kosher", "knurly", "kindly" }, // K
    .{ "last", "late", "lean", "long", "limp", "lost", "lame", "level", "light", "livid", "local", "lone", "loud", "low", "lucid", "lush" }, // L
    .{ "mild", "main", "mean", "mint", "meek", "moot", "muted", "misty", "mixed", "modal", "moist", "moral", "murky", "musty", "mere", "major" }, // M
    .{ "neat", "new", "next", "nice", "numb", "null", "nasal", "naval", "near", "ninth", "noble", "novel", "nutty", "nosy", "nifty", "north" }, // N
    .{ "odd", "old", "open", "oval", "only", "oaken", "oily", "olive", "optic", "outer", "overt", "oral", "other", "owned", "ocher", "ochre" }, // O
    .{ "pale", "past", "pink", "pure", "plum", "posh", "plain", "plump", "prim", "prone", "proud", "prior", "perky", "petty", "pithy", "polar" }, // P
    .{ "quick", "quiet", "queer", "quasi", "quaint", "quaky", "queasy", "quirky", "quoth", "quare", "quad", "quite", "quip", "queen", "quota", "quest" }, // Q
    .{ "raw", "real", "rich", "ripe", "rosy", "rude", "rapid", "ready", "rigid", "rocky", "rough", "round", "royal", "rum", "rural", "rusty" }, // R
    .{ "safe", "slim", "soft", "sure", "sly", "snug", "sharp", "sheer", "short", "silky", "sleek", "small", "solid", "spare", "steep", "stiff" }, // S
    .{ "tall", "tame", "tidy", "trim", "true", "taut", "thick", "thin", "timid", "tipsy", "total", "tough", "tried", "trite", "tubby", "terse" }, // T
    .{ "used", "uber", "ugly", "ultra", "uncut", "under", "undue", "unfit", "unlit", "upper", "urban", "usual", "utter", "unapt", "unmet", "unset" }, // U
    .{ "vast", "vivid", "void", "vague", "valid", "vapid", "viral", "vital", "vocal", "vexed", "viny", "veiny", "vying", "vowed", "verde", "vinyl" }, // V
    .{ "warm", "weak", "wide", "wild", "wary", "waxy", "weary", "weird", "white", "whole", "wiry", "witty", "woken", "woody", "wordy", "worst" }, // W
    .{ "xray", "xeno", "xeric", "xtra", "xenial", "xerox", "xebec", "xylyl", "xpath", "xored", "xterm", "xunit", "xwing", "xrail", "xwave", "xmas" }, // X
    .{ "young", "yucky", "yummy", "yawl", "yolky", "yappy", "yearly", "yeasty", "yogi", "yore", "yokel", "youth", "yet", "yew", "your", "yearn" }, // Y
    .{ "zen", "zero", "zany", "zippy", "zonal", "zesty", "zingy", "zoic", "zebra", "zilch", "zonky", "zappy", "zombi", "zeroed", "zoned", "zinc" }, // Z
};

const nouns = [26][bucket_size][]const u8{
    .{ "arch", "axle", "acre", "ash", "anvil", "apex", "attic", "alley", "amber", "abyss", "adze", "agate", "atlas", "aisle", "awl", "audit" }, // A
    .{ "barn", "beam", "bolt", "bone", "barge", "basin", "birch", "blade", "bluff", "booth", "briar", "brook", "buoy", "burr", "bay", "brim" }, // B
    .{ "cave", "cask", "coal", "cove", "cairn", "cedar", "chalk", "clasp", "cliff", "cloak", "coast", "crate", "crest", "cross", "crow", "curl" }, // C
    .{ "dale", "dock", "dune", "dusk", "dawn", "dew", "ditch", "dome", "dowel", "drain", "drift", "drum", "dwarf", "dyke", "dart", "dell" }, // D
    .{ "edge", "echo", "elk", "elm", "ember", "epoch", "easel", "egret", "elbow", "ether", "eaves", "eyrie", "earth", "eve", "exile", "essay" }, // E
    .{ "fern", "fawn", "ford", "fog", "flame", "flask", "flint", "forge", "frost", "frond", "fjord", "flume", "foal", "frame", "float", "furze" }, // F
    .{ "glen", "gale", "gate", "grit", "gauge", "gavel", "geode", "girth", "glade", "globe", "gorge", "gourd", "grain", "grove", "guild", "gulf" }, // G
    .{ "haze", "helm", "hive", "hull", "haven", "hawk", "heath", "hedge", "heron", "hill", "holly", "horn", "hutch", "husk", "hymn", "hitch" }, // H
    .{ "isle", "iron", "iris", "ink", "ivory", "inlet", "ingot", "index", "ibis", "idiom", "igloo", "image", "item", "itch", "icon", "imp" }, // I
    .{ "jade", "jolt", "jute", "jar", "jaw", "jewel", "jetty", "joint", "joust", "judge", "junco", "jig", "jib", "jest", "jinn", "jamb" }, // J
    .{ "knot", "keel", "kiln", "knob", "knoll", "kayak", "kelp", "kiosk", "kite", "knife", "kerb", "kid", "king", "kirk", "kudzu", "knock" }, // K
    .{ "lake", "lark", "loft", "loom", "lance", "latch", "ledge", "lever", "lilac", "linen", "lodge", "lotus", "lime", "lynx", "lyric", "lyre" }, // L
    .{ "mill", "mist", "moth", "moss", "mace", "manor", "marsh", "medal", "mesa", "moat", "mound", "mural", "mirth", "maple", "mare", "mule" }, // M
    .{ "nest", "node", "nook", "nave", "nib", "notch", "nymph", "nadir", "nerve", "nexus", "noon", "niche", "night", "noise", "nudge", "nape" }, // N
    .{ "oast", "opal", "orca", "oxen", "oak", "oar", "ocean", "olive", "onyx", "orbit", "organ", "otter", "owl", "oxide", "oyster", "ouzel" }, // O
    .{ "peak", "pine", "pond", "port", "palm", "patch", "plank", "plume", "porch", "prism", "pulse", "purse", "pyre", "pith", "pelt", "pier" }, // P
    .{ "quay", "quad", "quail", "quark", "quartz", "queen", "quest", "queue", "quill", "quirk", "quote", "quince", "qualm", "quota", "quiver", "quiche" }, // Q
    .{ "reef", "root", "rust", "raft", "ridge", "rind", "rivet", "roost", "rope", "rune", "rung", "rail", "ranch", "raven", "realm", "resin" }, // R
    .{ "sage", "silo", "slab", "stem", "shaft", "shawl", "shelf", "shoal", "shrub", "slate", "sling", "snare", "spire", "stone", "stump", "swirl" }, // S
    .{ "tarn", "tide", "twig", "turf", "talon", "thorn", "torch", "tower", "trail", "truss", "trunk", "tulip", "tusk", "twine", "thatch", "trench" }, // T
    .{ "urn", "ulna", "unit", "umbra", "udder", "usher", "umber", "union", "uvula", "ukase", "uhlan", "usage", "upset", "utile", "ultra", "upland" }, // U
    .{ "vale", "vine", "volt", "veil", "valve", "vapor", "vault", "verge", "vigor", "visor", "voile", "vortex", "vow", "vista", "viola", "vigil" }, // V
    .{ "weld", "well", "wick", "wren", "wedge", "wharf", "wheat", "wheel", "whorl", "wrist", "waltz", "warp", "wasp", "weave", "willow", "wraith" }, // W
    .{ "xray", "xylo", "xing", "xyst", "xenon", "xerus", "xylem", "xebec", "xpath", "xterm", "xiber", "xored", "xlamp", "xwave", "xrail", "xeric" }, // X
    .{ "yoke", "yarn", "yawl", "yurt", "yacht", "yard", "yeast", "youth", "yew", "yam", "yuan", "yucca", "yawp", "yield", "yogi", "yearling" }, // Y
    .{ "zone", "zinc", "zeal", "zero", "zenith", "zephyr", "zodiac", "zori", "zebu", "zest", "zigzag", "zilch", "zoom", "zooid", "zipper", "zinnia" }, // Z
};

/// Generate a session name from the current time.
/// Format: adjective-noun-command (e.g. "calm-nest-zsh")
/// Adjective letter chosen by hour (0-23 -> A-X), noun letter by minute (0-59 -> A-Z).
/// Word within each 16-word bucket chosen by second-derived jitter.
pub fn generate(buf: *[64]u8, command: []const u8) []const u8 {
    const ts = std.time.timestamp();
    const epoch_secs: u64 = @intCast(if (ts > 0) ts else 0);
    const day_secs = epoch_secs % 86400;
    const hour = day_secs / 3600;
    const minute = (day_secs % 3600) / 60;
    const second = day_secs % 60;

    const adj_letter: usize = @intCast(hour % 26);
    const noun_letter: usize = @intCast((minute * 26) / 60);

    // Adjective: use second directly (0-59 mod 16 = 0-15, wraps ~4x/min)
    const adj = adjectives[adj_letter][second % bucket_size];
    // Noun: use epoch_secs/4 to decorrelate from adjective selection
    const noun = nouns[noun_letter][(epoch_secs / 4) % bucket_size];

    const cmd_base = if (std.mem.lastIndexOfScalar(u8, command, '/')) |i|
        command[i + 1 ..]
    else
        command;

    const cmd_len = @min(cmd_base.len, 12);

    const result = std.fmt.bufPrint(buf, "{s}-{s}-{s}", .{ adj, noun, cmd_base[0..cmd_len] }) catch {
        return std.fmt.bufPrint(buf, "{s}-{s}", .{ adj, noun }) catch return buf[0..0];
    };
    return result;
}

/// Check if a name conflicts with existing sessions in the socket directory.
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

    var suffix_buf: [64]u8 = undefined;
    var i: u8 = 2;
    while (i <= 9) : (i += 1) {
        const suffixed = std.fmt.bufPrint(&suffix_buf, "{s}{d}", .{ base, i }) catch break;
        if (!nameExists(socket_dir, suffixed)) {
            @memcpy(buf[0..suffixed.len], suffixed);
            return buf[0..suffixed.len];
        }
    }

    return base;
}

test "generate produces non-empty name" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "zsh");
    try std.testing.expect(name.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, name, "-") != null);
    try std.testing.expect(std.mem.endsWith(u8, name, "zsh"));
}

test "generate strips command path" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "/usr/bin/bash");
    try std.testing.expect(std.mem.endsWith(u8, name, "bash"));
    try std.testing.expect(std.mem.indexOf(u8, name, "/") == null);
}

test "generate format is adjective-noun-command" {
    var buf: [64]u8 = undefined;
    const name = generate(&buf, "fish");
    var dash_count: usize = 0;
    for (name) |c| {
        if (c == '-') dash_count += 1;
    }
    try std.testing.expect(dash_count == 2);
}

test "all buckets have exactly 16 unique words" {
    for (&adjectives) |bucket| {
        try std.testing.expectEqual(bucket_size, bucket.len);
        // Check no duplicates within bucket
        for (bucket, 0..) |word, i| {
            for (bucket[0..i]) |prev| {
                try std.testing.expect(!std.mem.eql(u8, word, prev));
            }
        }
    }
    for (&nouns) |bucket| {
        try std.testing.expectEqual(bucket_size, bucket.len);
        for (bucket, 0..) |word, i| {
            for (bucket[0..i]) |prev| {
                try std.testing.expect(!std.mem.eql(u8, word, prev));
            }
        }
    }
}
