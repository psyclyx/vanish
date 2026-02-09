const std = @import("std");
const posix = std.posix;
const crypto = std.crypto;

/// Token scope determines which HMAC key is used for signing
pub const Scope = enum {
    temporary, // Duration-based tokens
    daemon, // Valid until HTTP server restarts
    indefinite, // Never expires
    session, // Scoped to specific session
};

/// JWT payload structure
pub const TokenPayload = struct {
    scope: Scope,
    session: ?[]const u8 = null, // Only for session-scoped tokens
    exp: ?i64 = null, // Expiration timestamp (null = no expiry)
    iat: i64, // Issued at timestamp
    read_only: bool = false,

    pub fn isExpired(self: TokenPayload) bool {
        if (self.exp) |exp| {
            return std.time.timestamp() > exp;
        }
        return false;
    }
};

/// OTP metadata stored in state directory
pub const OtpMeta = struct {
    scope: Scope,
    session: ?[]const u8 = null,
    exp: ?i64 = null,
    created: i64,
    read_only: bool = false,
};

pub const Auth = @This();

alloc: std.mem.Allocator,
state_dir: []const u8,

// In-memory HMAC keys (loaded/generated on init)
hmac_temporary: [32]u8 = undefined,
hmac_daemon: [32]u8 = undefined,
hmac_indefinite: [32]u8 = undefined,
session_keys: std.StringHashMap([32]u8),

pub fn init(alloc: std.mem.Allocator) !Auth {
    const state_dir = try getStateDir(alloc);
    errdefer alloc.free(state_dir);

    // Ensure state directory exists
    std.fs.makeDirAbsolute(state_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Ensure otps subdirectory exists
    const otps_dir = try std.fmt.allocPrint(alloc, "{s}/otps", .{state_dir});
    defer alloc.free(otps_dir);
    std.fs.makeDirAbsolute(otps_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var auth = Auth{
        .alloc = alloc,
        .state_dir = state_dir,
        .session_keys = std.StringHashMap([32]u8).init(alloc),
    };

    // Load or generate HMAC keys
    auth.hmac_temporary = try auth.loadOrCreateKey("hmac_temporary.key");
    auth.hmac_daemon = try auth.loadOrCreateKey("hmac_daemon.key");
    auth.hmac_indefinite = try auth.loadOrCreateKey("hmac_indefinite.key");

    return auth;
}

pub fn deinit(self: *Auth) void {
    var it = self.session_keys.iterator();
    while (it.next()) |entry| {
        self.alloc.free(entry.key_ptr.*);
    }
    self.session_keys.deinit();
    self.alloc.free(self.state_dir);
}

fn loadOrCreateKey(self: *Auth, filename: []const u8) ![32]u8 {
    const path = try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ self.state_dir, filename });
    defer self.alloc.free(path);

    // Try to read existing key
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // Generate new key
            var key: [32]u8 = undefined;
            crypto.random.bytes(&key);
            try writeKeyFile(path, &key);
            return key;
        }
        return err;
    };
    defer file.close();

    var key: [32]u8 = undefined;
    const n = try file.readAll(&key);
    if (n != 32) return error.InvalidKeyFile;
    return key;
}

fn writeKeyFile(path: []const u8, key: []const u8) !void {
    const file = try std.fs.createFileAbsolute(path, .{ .mode = 0o600 });
    defer file.close();
    try file.writeAll(key);
}

/// Get HMAC key for a given scope
pub fn getKey(self: *Auth, scope: Scope, session: ?[]const u8) ![32]u8 {
    return switch (scope) {
        .temporary => self.hmac_temporary,
        .daemon => self.hmac_daemon,
        .indefinite => self.hmac_indefinite,
        .session => blk: {
            const name = session orelse return error.SessionRequired;
            if (self.session_keys.get(name)) |key| {
                break :blk key;
            }
            // Load or create session key
            const filename = try std.fmt.allocPrint(self.alloc, "hmac_session_{s}.key", .{name});
            defer self.alloc.free(filename);
            const key = try self.loadOrCreateKey(filename);
            const owned_name = try self.alloc.dupe(u8, name);
            try self.session_keys.put(owned_name, key);
            break :blk key;
        },
    };
}

/// Rotate (regenerate) HMAC key for a scope, invalidating all tokens
pub fn rotateKey(self: *Auth, scope: Scope, session: ?[]const u8) !void {
    var key: [32]u8 = undefined;
    crypto.random.bytes(&key);

    const filename = switch (scope) {
        .temporary => "hmac_temporary.key",
        .daemon => "hmac_daemon.key",
        .indefinite => "hmac_indefinite.key",
        .session => blk: {
            const name = session orelse return error.SessionRequired;
            const fname = try std.fmt.allocPrint(self.alloc, "hmac_session_{s}.key", .{name});
            break :blk fname;
        },
    };
    defer if (scope == .session) self.alloc.free(filename);

    const path = try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ self.state_dir, filename });
    defer self.alloc.free(path);

    try writeKeyFile(path, &key);

    switch (scope) {
        .temporary => self.hmac_temporary = key,
        .daemon => self.hmac_daemon = key,
        .indefinite => self.hmac_indefinite = key,
        .session => {
            const name = session.?;
            if (self.session_keys.getEntry(name)) |entry| {
                entry.value_ptr.* = key;
            }
        },
    }
}

/// Generate a one-time password
pub fn generateOtp(self: *Auth, scope: Scope, session: ?[]const u8, duration: ?i64, read_only: bool) ![]const u8 {
    // Generate random OTP code
    var code_bytes: [16]u8 = undefined;
    crypto.random.bytes(&code_bytes);

    // Encode as hex string
    var code: [32]u8 = undefined;
    _ = std.fmt.bufPrint(&code, "{x}", .{code_bytes}) catch unreachable;

    // Hash the code for storage
    var hash: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(&code, &hash, .{});

    var hash_hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hash_hex, "{x}", .{hash}) catch unreachable;

    // Store OTP metadata
    const now = std.time.timestamp();
    const exp: ?i64 = if (duration) |d| now + d else null;

    const meta_path = try std.fmt.allocPrint(self.alloc, "{s}/otps/{s}.json", .{ self.state_dir, hash_hex });
    defer self.alloc.free(meta_path);

    // Build JSON in buffer
    var json_buf: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&json_buf);
    const writer = stream.writer();
    try writer.writeAll("{\"scope\":\"");
    try writer.writeAll(@tagName(scope));
    try writer.writeAll("\"");
    if (session) |s| {
        try writer.writeAll(",\"session\":\"");
        try writer.writeAll(s);
        try writer.writeAll("\"");
    }
    if (exp) |e| {
        try std.fmt.format(writer, ",\"exp\":{d}", .{e});
    }
    if (read_only) {
        try writer.writeAll(",\"read_only\":true");
    }
    try std.fmt.format(writer, ",\"created\":{d}}}", .{now});

    const file = try std.fs.createFileAbsolute(meta_path, .{ .mode = 0o600 });
    defer file.close();
    try file.writeAll(stream.getWritten());

    return try self.alloc.dupe(u8, &code);
}

/// Exchange OTP for JWT token
pub fn exchangeOtp(self: *Auth, code: []const u8) ![]const u8 {
    if (code.len != 32) return error.InvalidOtp;

    // Hash the provided code
    var hash: [32]u8 = undefined;
    crypto.hash.sha2.Sha256.hash(code, &hash, .{});

    var hash_hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hash_hex, "{x}", .{hash}) catch unreachable;

    const meta_path = try std.fmt.allocPrint(self.alloc, "{s}/otps/{s}.json", .{ self.state_dir, hash_hex });
    defer self.alloc.free(meta_path);

    // Read OTP metadata
    const file = std.fs.openFileAbsolute(meta_path, .{}) catch return error.InvalidOtp;
    defer file.close();

    const content = file.readToEndAlloc(self.alloc, 4096) catch return error.InvalidOtp;
    defer self.alloc.free(content);

    // Parse metadata
    const parsed = std.json.parseFromSlice(std.json.Value, self.alloc, content, .{}) catch return error.InvalidOtp;
    defer parsed.deinit();

    const obj = parsed.value.object;

    const scope_str = obj.get("scope").?.string;
    const scope: Scope = std.meta.stringToEnum(Scope, scope_str) orelse return error.InvalidOtp;

    const session: ?[]const u8 = if (obj.get("session")) |v| v.string else null;

    const exp: ?i64 = if (obj.get("exp")) |v| @intCast(v.integer) else null;

    const read_only = if (obj.get("read_only")) |v| (v == .bool and v.bool) else false;

    // Check if OTP itself is expired
    if (exp) |e| {
        if (std.time.timestamp() > e) {
            // Delete expired OTP
            std.fs.deleteFileAbsolute(meta_path) catch {};
            return error.OtpExpired;
        }
    }

    // Delete OTP (single use)
    std.fs.deleteFileAbsolute(meta_path) catch {};

    // Generate JWT
    return try self.createToken(scope, session, exp, read_only);
}

/// Create a JWT token
pub fn createToken(self: *Auth, scope: Scope, session: ?[]const u8, exp: ?i64, read_only: bool) ![]const u8 {
    const key = try self.getKey(scope, session);
    const now = std.time.timestamp();

    // Build payload JSON
    var payload_buf: [512]u8 = undefined;
    var stream = std.io.fixedBufferStream(&payload_buf);
    const writer = stream.writer();

    try writer.writeAll("{\"scope\":\"");
    try writer.writeAll(@tagName(scope));
    try writer.writeAll("\"");
    if (session) |s| {
        try writer.writeAll(",\"session\":\"");
        try writer.writeAll(s);
        try writer.writeAll("\"");
    }
    if (exp) |e| {
        try std.fmt.format(writer, ",\"exp\":{d}", .{e});
    }
    if (read_only) {
        try writer.writeAll(",\"ro\":true");
    }
    try std.fmt.format(writer, ",\"iat\":{d}}}", .{now});

    const payload_json = stream.getWritten();

    // JWT: base64url(header).base64url(payload).base64url(signature)
    const header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

    const header_b64 = try base64UrlEncode(self.alloc, header);
    defer self.alloc.free(header_b64);

    const payload_b64 = try base64UrlEncode(self.alloc, payload_json);
    defer self.alloc.free(payload_b64);

    // Sign header.payload
    const signing_input = try std.fmt.allocPrint(self.alloc, "{s}.{s}", .{ header_b64, payload_b64 });
    defer self.alloc.free(signing_input);

    var hmac = crypto.auth.hmac.sha2.HmacSha256.init(&key);
    hmac.update(signing_input);
    var signature: [32]u8 = undefined;
    hmac.final(&signature);

    const sig_b64 = try base64UrlEncode(self.alloc, &signature);
    defer self.alloc.free(sig_b64);

    return try std.fmt.allocPrint(self.alloc, "{s}.{s}", .{ signing_input, sig_b64 });
}

/// Validate a JWT token and return payload
pub fn validateToken(self: *Auth, token: []const u8) !TokenPayload {
    // Split token into parts
    var parts: [3][]const u8 = undefined;
    var part_idx: usize = 0;
    var start: usize = 0;

    for (token, 0..) |c, i| {
        if (c == '.') {
            if (part_idx >= 2) return error.InvalidToken;
            parts[part_idx] = token[start..i];
            part_idx += 1;
            start = i + 1;
        }
    }
    if (part_idx != 2) return error.InvalidToken;
    parts[2] = token[start..];

    // Decode payload
    const payload_json = try base64UrlDecode(self.alloc, parts[1]);
    defer self.alloc.free(payload_json);

    // Parse payload
    const parsed = std.json.parseFromSlice(std.json.Value, self.alloc, payload_json, .{}) catch return error.InvalidToken;
    defer parsed.deinit();

    const obj = parsed.value.object;

    const scope_str = obj.get("scope").?.string;
    const scope: Scope = std.meta.stringToEnum(Scope, scope_str) orelse return error.InvalidToken;

    const session: ?[]const u8 = if (obj.get("session")) |v| v.string else null;

    // Get the appropriate key and verify signature
    const key = self.getKey(scope, session) catch return error.InvalidToken;

    const signing_input = try std.fmt.allocPrint(self.alloc, "{s}.{s}", .{ parts[0], parts[1] });
    defer self.alloc.free(signing_input);

    var hmac = crypto.auth.hmac.sha2.HmacSha256.init(&key);
    hmac.update(signing_input);
    var expected_sig: [32]u8 = undefined;
    hmac.final(&expected_sig);

    const provided_sig = base64UrlDecode(self.alloc, parts[2]) catch return error.InvalidToken;
    defer self.alloc.free(provided_sig);

    if (provided_sig.len != 32) return error.InvalidToken;
    if (!std.mem.eql(u8, provided_sig, &expected_sig)) return error.InvalidSignature;

    // Build payload struct
    const exp: ?i64 = if (obj.get("exp")) |v| @intCast(v.integer) else null;
    const iat: i64 = @intCast(obj.get("iat").?.integer);
    const read_only = if (obj.get("ro")) |v| (v == .bool and v.bool) else false;

    var payload = TokenPayload{
        .scope = scope,
        .exp = exp,
        .iat = iat,
        .read_only = read_only,
    };

    if (session) |s| {
        payload.session = try self.alloc.dupe(u8, s);
    }

    // Check expiration
    if (payload.isExpired()) {
        if (payload.session) |s| self.alloc.free(s);
        return error.TokenExpired;
    }

    return payload;
}

/// Delete all OTPs matching criteria
pub fn revokeOtps(self: *Auth, scope: ?Scope, session: ?[]const u8) !void {
    const otps_dir = try std.fmt.allocPrint(self.alloc, "{s}/otps", .{self.state_dir});
    defer self.alloc.free(otps_dir);

    var dir = std.fs.openDirAbsolute(otps_dir, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const path = try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ otps_dir, entry.name });
        defer self.alloc.free(path);

        // Read and parse to check scope/session
        const file = std.fs.openFileAbsolute(path, .{}) catch continue;
        const content = file.readToEndAlloc(self.alloc, 4096) catch {
            file.close();
            continue;
        };
        file.close();
        defer self.alloc.free(content);

        const parsed = std.json.parseFromSlice(std.json.Value, self.alloc, content, .{}) catch continue;
        defer parsed.deinit();

        const obj = parsed.value.object;
        const otp_scope_str = obj.get("scope").?.string;
        const otp_scope: Scope = std.meta.stringToEnum(Scope, otp_scope_str) orelse continue;

        const otp_session: ?[]const u8 = if (obj.get("session")) |v| v.string else null;

        // Check if matches revocation criteria
        var should_delete = false;
        if (scope) |s| {
            if (otp_scope == s) {
                if (session) |sess| {
                    if (otp_session != null and std.mem.eql(u8, otp_session.?, sess)) {
                        should_delete = true;
                    }
                } else {
                    should_delete = true;
                }
            }
        } else {
            should_delete = true; // Revoke all
        }

        if (should_delete) {
            std.fs.deleteFileAbsolute(path) catch {};
        }
    }
}

fn getStateDir(alloc: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_STATE_HOME")) |xdg| {
        return try std.fmt.allocPrint(alloc, "{s}/vanish", .{xdg});
    }
    if (std.posix.getenv("HOME")) |home| {
        return try std.fmt.allocPrint(alloc, "{s}/.local/state/vanish", .{home});
    }
    return error.NoHomeDir;
}

fn base64UrlEncode(alloc: std.mem.Allocator, data: []const u8) ![]const u8 {
    const Encoder = std.base64.url_safe_no_pad.Encoder;
    const len = Encoder.calcSize(data.len);
    const buf = try alloc.alloc(u8, len);
    return Encoder.encode(buf, data);
}

fn base64UrlDecode(alloc: std.mem.Allocator, data: []const u8) ![]const u8 {
    const Decoder = std.base64.url_safe_no_pad.Decoder;
    const len = Decoder.calcSizeForSlice(data) catch return error.InvalidBase64;
    const buf = try alloc.alloc(u8, len);
    Decoder.decode(buf, data) catch {
        alloc.free(buf);
        return error.InvalidBase64;
    };
    return buf;
}

// Tests
test "base64url encode/decode" {
    const alloc = std.testing.allocator;

    const original = "Hello, World!";
    const encoded = try base64UrlEncode(alloc, original);
    defer alloc.free(encoded);

    const decoded = try base64UrlDecode(alloc, encoded);
    defer alloc.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "token creation and validation" {
    const alloc = std.testing.allocator;

    var auth = try Auth.init(alloc);
    defer auth.deinit();

    const token = try auth.createToken(.daemon, null, null, false);
    defer alloc.free(token);

    const payload = try auth.validateToken(token);
    if (payload.session) |s| alloc.free(s);

    try std.testing.expectEqual(Scope.daemon, payload.scope);
    try std.testing.expect(payload.exp == null);
    try std.testing.expect(!payload.read_only);
}

test "expired token" {
    const alloc = std.testing.allocator;

    var auth = try Auth.init(alloc);
    defer auth.deinit();

    // Create token that expired 1 second ago
    const exp = std.time.timestamp() - 1;
    const token = try auth.createToken(.temporary, null, exp, false);
    defer alloc.free(token);

    const result = auth.validateToken(token);
    try std.testing.expectError(error.TokenExpired, result);
}

test "session scoped token" {
    const alloc = std.testing.allocator;

    var auth = try Auth.init(alloc);
    defer auth.deinit();

    const token = try auth.createToken(.session, "test-session", null, false);
    defer alloc.free(token);

    const payload = try auth.validateToken(token);
    defer if (payload.session) |s| alloc.free(s);

    try std.testing.expectEqual(Scope.session, payload.scope);
    try std.testing.expectEqualStrings("test-session", payload.session.?);
}

test "key rotation invalidates tokens" {
    const alloc = std.testing.allocator;

    var auth = try Auth.init(alloc);
    defer auth.deinit();

    const token = try auth.createToken(.temporary, null, null, false);
    defer alloc.free(token);

    // Token should be valid
    const payload = try auth.validateToken(token);
    if (payload.session) |s| alloc.free(s);

    // Rotate the key
    try auth.rotateKey(.temporary, null);

    // Token should now be invalid
    const result = auth.validateToken(token);
    try std.testing.expectError(error.InvalidSignature, result);
}

test "read-only token" {
    const alloc = std.testing.allocator;

    var auth = try Auth.init(alloc);
    defer auth.deinit();

    const token = try auth.createToken(.daemon, null, null, true);
    defer alloc.free(token);

    const payload = try auth.validateToken(token);
    if (payload.session) |s| alloc.free(s);

    try std.testing.expectEqual(Scope.daemon, payload.scope);
    try std.testing.expect(payload.read_only);
}
