const std = @import("std");
const posix = std.posix;
const net = std.net;

const Auth = @import("auth.zig");
const protocol = @import("protocol.zig");
const VTerminal = @import("terminal.zig");
const config = @import("config.zig");
const paths = @import("paths.zig");
const vthtml = @import("vthtml.zig");

const index_html = @embedFile("static/index.html");

pub const HttpServer = @This();

alloc: std.mem.Allocator,
auth: Auth,
cfg: *const config.Config,
listen_sock4: ?posix.socket_t = null,
listen_sock6: ?posix.socket_t = null,
clients: std.ArrayList(HttpClient),
sse_clients: std.ArrayList(SseClient),
running: bool = true,
bind_addr: []const u8,
port: u16,

const HttpClient = struct {
    fd: posix.socket_t,
    state: enum { reading_request, sending_response },
    request_buf: [8192]u8 = undefined,
    request_len: usize = 0,
    response_buf: []u8 = &.{},
    response_sent: usize = 0,
};

const SseClient = struct {
    http_fd: posix.socket_t,
    session_fd: posix.socket_t,
    session_name: []const u8,
    vterm: VTerminal,
    screen_buf: vthtml.ScreenBuffer,
    last_update: i64 = 0,
    cols: u16 = 120,
    rows: u16 = 40,
    is_primary: bool = false,

    fn deinit(self: *SseClient, alloc: std.mem.Allocator) void {
        posix.close(self.http_fd);
        posix.close(self.session_fd);
        alloc.free(self.session_name);
        self.screen_buf.deinit();
        self.vterm.deinit();
    }
};

pub fn init(alloc: std.mem.Allocator, cfg: *const config.Config, bind: []const u8, port: u16) !HttpServer {
    var auth = try Auth.init(alloc);
    errdefer auth.deinit();

    return HttpServer{
        .alloc = alloc,
        .auth = auth,
        .cfg = cfg,
        .clients = .empty,
        .sse_clients = .empty,
        .bind_addr = bind,
        .port = port,
    };
}

pub fn deinit(self: *HttpServer) void {
    for (self.clients.items) |c| {
        posix.close(c.fd);
        if (c.response_buf.len > 0) self.alloc.free(c.response_buf);
    }
    self.clients.deinit(self.alloc);

    for (self.sse_clients.items) |*c| {
        c.deinit(self.alloc);
    }
    self.sse_clients.deinit(self.alloc);

    if (self.listen_sock4) |s| posix.close(s);
    if (self.listen_sock6) |s| posix.close(s);
    self.auth.deinit();
}

pub fn start(self: *HttpServer) !void {
    // Create listening sockets
    if (std.mem.eql(u8, self.bind_addr, "127.0.0.1") or std.mem.eql(u8, self.bind_addr, "0.0.0.0")) {
        self.listen_sock4 = try createTcpSocket4(self.bind_addr, self.port);
    }

    if (std.mem.eql(u8, self.bind_addr, "::1") or std.mem.eql(u8, self.bind_addr, "::")) {
        self.listen_sock6 = try createTcpSocket6(self.bind_addr, self.port);
    }

    // Default: listen on both localhost addresses
    if (self.listen_sock4 == null and self.listen_sock6 == null) {
        self.listen_sock4 = createTcpSocket4("127.0.0.1", self.port) catch null;
        self.listen_sock6 = createTcpSocket6("::1", self.port) catch null;

        if (self.listen_sock4 == null and self.listen_sock6 == null) {
            return error.CouldNotBind;
        }
    }

    // Warn if binding publicly
    if (std.mem.eql(u8, self.bind_addr, "0.0.0.0") or std.mem.eql(u8, self.bind_addr, "::")) {
        _ = posix.write(posix.STDERR_FILENO, "WARNING: Binding to public interface. This provides shell access!\n") catch {};
    }

    if (self.listen_sock4 != null) {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Listening on http://127.0.0.1:{d}\n", .{self.port}) catch return;
        _ = posix.write(posix.STDOUT_FILENO, msg) catch {};
    }
    if (self.listen_sock6 != null) {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Listening on http://[::1]:{d}\n", .{self.port}) catch return;
        _ = posix.write(posix.STDOUT_FILENO, msg) catch {};
    }
}

pub fn run(self: *HttpServer) !void {
    try self.start();
    try self.eventLoop();
}

fn eventLoop(self: *HttpServer) !void {
    var poll_fds: std.ArrayList(posix.pollfd) = .empty;
    defer poll_fds.deinit(self.alloc);

    while (self.running) {
        poll_fds.clearRetainingCapacity();

        // Add listening sockets
        if (self.listen_sock4) |s| {
            try poll_fds.append(self.alloc, .{ .fd = s, .events = posix.POLL.IN, .revents = 0 });
        }
        if (self.listen_sock6) |s| {
            try poll_fds.append(self.alloc, .{ .fd = s, .events = posix.POLL.IN, .revents = 0 });
        }

        // Add HTTP clients
        for (self.clients.items) |c| {
            const events: i16 = switch (c.state) {
                .reading_request => posix.POLL.IN,
                .sending_response => posix.POLL.OUT,
            };
            try poll_fds.append(self.alloc, .{ .fd = c.fd, .events = events, .revents = 0 });
        }

        // Add SSE clients (listen for session output and client disconnect)
        for (self.sse_clients.items) |c| {
            try poll_fds.append(self.alloc, .{ .fd = c.session_fd, .events = posix.POLL.IN, .revents = 0 });
            try poll_fds.append(self.alloc, .{ .fd = c.http_fd, .events = posix.POLL.IN, .revents = 0 });
        }

        const timeout: i32 = if (self.sse_clients.items.len > 0) 1000 else -1; // 1s timeout for keyframes
        const ready = posix.poll(poll_fds.items, timeout) catch |err| {
            if (err == error.Interrupted) continue;
            return err;
        };

        if (ready == 0) {
            // Timeout - send keyframes to SSE clients if needed
            try self.sendPeriodicKeyframes();
            continue;
        }

        var idx: usize = 0;

        // Check listening sockets
        if (self.listen_sock4 != null) {
            if (poll_fds.items[idx].revents & posix.POLL.IN != 0) {
                self.acceptConnection(self.listen_sock4.?) catch {};
            }
            idx += 1;
        }
        if (self.listen_sock6 != null) {
            if (poll_fds.items[idx].revents & posix.POLL.IN != 0) {
                self.acceptConnection(self.listen_sock6.?) catch {};
            }
            idx += 1;
        }

        // Handle HTTP clients
        var client_idx: usize = 0;
        while (client_idx < self.clients.items.len) {
            const poll_idx = idx + client_idx;
            if (poll_idx >= poll_fds.items.len) break;

            const revents = poll_fds.items[poll_idx].revents;
            if (revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                self.removeClient(client_idx);
                continue;
            }
            if (revents & posix.POLL.IN != 0) {
                self.handleClientRead(client_idx) catch {
                    self.removeClient(client_idx);
                    continue;
                };
            }
            if (revents & posix.POLL.OUT != 0) {
                self.handleClientWrite(client_idx) catch {
                    self.removeClient(client_idx);
                    continue;
                };
            }
            client_idx += 1;
        }
        idx += self.clients.items.len;

        // Handle SSE clients
        var sse_idx: usize = 0;
        while (sse_idx < self.sse_clients.items.len) {
            const session_poll_idx = idx + sse_idx * 2;
            const http_poll_idx = session_poll_idx + 1;
            if (http_poll_idx >= poll_fds.items.len) break;

            // Check for client disconnect
            if (poll_fds.items[http_poll_idx].revents & (posix.POLL.HUP | posix.POLL.ERR | posix.POLL.IN) != 0) {
                self.removeSseClient(sse_idx);
                continue;
            }

            // Check for session output
            if (poll_fds.items[session_poll_idx].revents & posix.POLL.IN != 0) {
                self.handleSseSessionOutput(sse_idx) catch {
                    self.removeSseClient(sse_idx);
                    continue;
                };
            }
            if (poll_fds.items[session_poll_idx].revents & posix.POLL.HUP != 0) {
                self.removeSseClient(sse_idx);
                continue;
            }

            sse_idx += 1;
        }
    }
}

fn acceptConnection(self: *HttpServer, sock: posix.socket_t) !void {
    const conn = try posix.accept(sock, null, null, posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK);
    try self.clients.append(self.alloc, .{
        .fd = conn,
        .state = .reading_request,
    });
}

fn handleClientRead(self: *HttpServer, idx: usize) !void {
    var client = &self.clients.items[idx];

    const remaining = client.request_buf.len - client.request_len;
    if (remaining == 0) return error.RequestTooLarge;

    const n = try posix.read(client.fd, client.request_buf[client.request_len..]);
    if (n == 0) return error.ConnectionClosed;

    client.request_len += n;

    // Check if we have a complete request
    const request = client.request_buf[0..client.request_len];
    if (std.mem.indexOf(u8, request, "\r\n\r\n")) |header_end| {
        // Check Content-Length for body
        const content_length = getContentLength(request[0..header_end]);
        const body_start = header_end + 4;
        const body_len = client.request_len - body_start;

        if (body_len >= content_length) {
            // Complete request - process it
            try self.processRequest(idx, request[0..header_end], request[body_start..][0..content_length]);
        }
    }
}

fn handleClientWrite(self: *HttpServer, idx: usize) !void {
    var client = &self.clients.items[idx];

    const remaining = client.response_buf[client.response_sent..];
    const n = try posix.write(client.fd, remaining);
    client.response_sent += n;

    if (client.response_sent >= client.response_buf.len) {
        // Response complete - close connection
        self.removeClient(idx);
    }
}

fn processRequest(self: *HttpServer, client_idx: usize, headers: []const u8, body: []const u8) !void {
    const client = &self.clients.items[client_idx];

    // Parse first line
    const first_line_end = std.mem.indexOf(u8, headers, "\r\n") orelse return error.InvalidRequest;
    const first_line = headers[0..first_line_end];

    var parts = std.mem.splitScalar(u8, first_line, ' ');
    const method = parts.next() orelse return error.InvalidRequest;
    const path = parts.next() orelse return error.InvalidRequest;

    // Route the request
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/")) {
        try self.handleIndex(client);
    } else if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/auth")) {
        try self.handleAuth(client, headers, body);
    } else if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/api/sessions")) {
        try self.handleListSessions(client, headers);
    } else if (std.mem.startsWith(u8, path, "/api/sessions/") and std.mem.endsWith(u8, path, "/stream")) {
        // SSE stream - extract session name
        const name_start = "/api/sessions/".len;
        const name_end = path.len - "/stream".len;
        if (name_end > name_start) {
            const session_name = path[name_start..name_end];
            try self.handleSseStream(client_idx, headers, session_name);
            return; // Don't remove client - it's now an SSE client
        }
        try self.sendError(client, 400, "Invalid session name");
    } else if (std.mem.startsWith(u8, path, "/api/sessions/") and std.mem.endsWith(u8, path, "/input")) {
        if (std.mem.eql(u8, method, "POST")) {
            const name_start = "/api/sessions/".len;
            const name_end = path.len - "/input".len;
            if (name_end > name_start) {
                const session_name = path[name_start..name_end];
                try self.handleInput(client, headers, body, session_name);
            } else {
                try self.sendError(client, 400, "Invalid session name");
            }
        } else {
            try self.sendError(client, 405, "Method Not Allowed");
        }
    } else if (std.mem.startsWith(u8, path, "/api/sessions/") and std.mem.endsWith(u8, path, "/resize")) {
        if (std.mem.eql(u8, method, "POST")) {
            const name_start = "/api/sessions/".len;
            const name_end = path.len - "/resize".len;
            if (name_end > name_start) {
                const session_name = path[name_start..name_end];
                try self.handleResize(client, headers, body, session_name);
            } else {
                try self.sendError(client, 400, "Invalid session name");
            }
        } else {
            try self.sendError(client, 405, "Method Not Allowed");
        }
    } else if (std.mem.startsWith(u8, path, "/api/sessions/") and std.mem.endsWith(u8, path, "/takeover")) {
        if (std.mem.eql(u8, method, "POST")) {
            const name_start = "/api/sessions/".len;
            const name_end = path.len - "/takeover".len;
            if (name_end > name_start) {
                const session_name = path[name_start..name_end];
                try self.handleTakeover(client, headers, session_name);
            } else {
                try self.sendError(client, 400, "Invalid session name");
            }
        } else {
            try self.sendError(client, 405, "Method Not Allowed");
        }
    } else {
        try self.sendError(client, 404, "Not Found");
    }
}

fn handleIndex(self: *HttpServer, client: *HttpClient) !void {
    const response = try std.fmt.allocPrint(self.alloc,
        "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/html; charset=utf-8\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "\r\n" ++
            "{s}", .{ index_html.len, index_html });

    client.response_buf = response;
    client.response_sent = 0;
    client.state = .sending_response;
}

fn handleAuth(self: *HttpServer, client: *HttpClient, headers: []const u8, body: []const u8) !void {
    _ = headers;

    // Parse OTP from body (expect: otp=<code>)
    var code: ?[]const u8 = null;
    var iter = std.mem.splitScalar(u8, body, '&');
    while (iter.next()) |pair| {
        var kv = std.mem.splitScalar(u8, pair, '=');
        const key = kv.next() orelse continue;
        const value = kv.next() orelse continue;
        if (std.mem.eql(u8, key, "otp")) {
            code = value;
            break;
        }
    }

    if (code == null) {
        try self.sendError(client, 400, "Missing OTP");
        return;
    }

    const token = self.auth.exchangeOtp(code.?) catch {
        try self.sendError(client, 401, "Invalid or expired OTP");
        return;
    };
    defer self.alloc.free(token);

    // Set JWT as HttpOnly cookie and redirect to /
    const response = try std.fmt.allocPrint(self.alloc,
        "HTTP/1.1 302 Found\r\n" ++
            "Set-Cookie: jwt={s}; HttpOnly; SameSite=Strict; Path=/\r\n" ++
            "Location: /\r\n" ++
            "Content-Length: 0\r\n" ++
            "\r\n", .{token});

    client.response_buf = response;
    client.response_sent = 0;
    client.state = .sending_response;
}

fn handleListSessions(self: *HttpServer, client: *HttpClient, headers: []const u8) !void {
    const payload = self.validateAuth(headers) catch {
        try self.sendError(client, 401, "Unauthorized");
        return;
    };
    defer if (payload.session) |s| self.alloc.free(s);

    // Get socket directory
    const socket_dir = paths.getDefaultSocketDir(self.alloc, self.cfg) catch {
        try self.sendJson(client, "{\"sessions\":[]}");
        return;
    };
    defer self.alloc.free(socket_dir);

    var dir = std.fs.openDirAbsolute(socket_dir, .{ .iterate = true }) catch {
        try self.sendJson(client, "{\"sessions\":[]}");
        return;
    };
    defer dir.close();

    var json: std.ArrayList(u8) = .empty;
    defer json.deinit(self.alloc);

    try json.appendSlice(self.alloc, "{\"sessions\":[");
    var first = true;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .unix_domain_socket) continue;

        // Filter by session scope if applicable
        if (payload.scope == .session) {
            if (payload.session) |allowed| {
                if (!std.mem.eql(u8, entry.name, allowed)) continue;
            }
        }

        if (!first) try json.append(self.alloc, ',');
        first = false;

        try json.appendSlice(self.alloc, "{\"name\":\"");
        try paths.appendJsonEscaped(self.alloc, &json, entry.name);
        try json.appendSlice(self.alloc, "\"}");
    }

    try json.appendSlice(self.alloc, "]}");
    try self.sendJson(client, json.items);
}

fn handleInput(self: *HttpServer, client: *HttpClient, headers: []const u8, body: []const u8, session_name: []const u8) !void {
    const payload = self.validateAuth(headers) catch {
        try self.sendError(client, 401, "Unauthorized");
        return;
    };
    defer if (payload.session) |s| self.alloc.free(s);

    if (payload.scope == .session) {
        if (payload.session) |allowed| {
            if (!std.mem.eql(u8, session_name, allowed)) {
                try self.sendError(client, 403, "Session not allowed");
                return;
            }
        }
    }

    // Find SSE client for this session and send input through its connection
    for (self.sse_clients.items) |*sse| {
        if (std.mem.eql(u8, sse.session_name, session_name) and sse.is_primary) {
            protocol.writeMsg(sse.session_fd, @intFromEnum(protocol.ClientMsg.input), body) catch {
                try self.sendError(client, 500, "Failed to send input");
                return;
            };
            try self.sendJson(client, "{\"ok\":true}");
            return;
        }
    }

    try self.sendError(client, 409, "No active primary connection (use takeover first)");
}

fn handleResize(self: *HttpServer, client: *HttpClient, headers: []const u8, body: []const u8, session_name: []const u8) !void {
    _ = body;
    _ = session_name;

    const payload = self.validateAuth(headers) catch {
        try self.sendError(client, 401, "Unauthorized");
        return;
    };
    defer if (payload.session) |s| self.alloc.free(s);

    // Resize is handled per-SSE client, not globally
    // For now, just acknowledge
    try self.sendJson(client, "{\"ok\":true}");
}

fn handleTakeover(self: *HttpServer, client: *HttpClient, headers: []const u8, session_name: []const u8) !void {
    const payload = self.validateAuth(headers) catch {
        try self.sendError(client, 401, "Unauthorized");
        return;
    };
    defer if (payload.session) |s| self.alloc.free(s);

    if (payload.scope == .session) {
        if (payload.session) |allowed| {
            if (!std.mem.eql(u8, session_name, allowed)) {
                try self.sendError(client, 403, "Session not allowed");
                return;
            }
        }
    }

    // Find SSE client for this session and send takeover through its connection
    for (self.sse_clients.items) |*sse| {
        if (std.mem.eql(u8, sse.session_name, session_name)) {
            protocol.writeMsg(sse.session_fd, @intFromEnum(protocol.ClientMsg.takeover), &.{}) catch {
                try self.sendError(client, 500, "Failed to send takeover");
                return;
            };
            sse.is_primary = true;
            try self.sendJson(client, "{\"ok\":true}");
            return;
        }
    }

    try self.sendError(client, 404, "No active stream for session");
}

fn handleSseStream(self: *HttpServer, client_idx: usize, headers: []const u8, session_name: []const u8) !void {
    const client = &self.clients.items[client_idx];

    const payload = self.validateAuth(headers) catch {
        try self.sendError(client, 401, "Unauthorized");
        return;
    };
    defer if (payload.session) |s| self.alloc.free(s);

    // Check session scope
    if (payload.scope == .session) {
        if (payload.session) |allowed| {
            if (!std.mem.eql(u8, session_name, allowed)) {
                try self.sendError(client, 403, "Session not allowed");
                return;
            }
        }
    }

    // Connect to session as viewer
    const socket_path = try paths.resolveSocketPath(self.alloc, session_name, self.cfg);
    defer self.alloc.free(socket_path);

    const sess_sock = connectToSession(socket_path) catch {
        try self.sendError(client, 404, "Session not found");
        return;
    };
    errdefer posix.close(sess_sock);

    // Send hello as viewer
    var hello = protocol.Hello{ .role = .viewer, .cols = 120, .rows = 40 };
    hello.setTerm("xterm-256color");
    try protocol.writeStruct(sess_sock, @intFromEnum(protocol.ClientMsg.hello), hello);

    // Read welcome
    const welcome_hdr = try protocol.readHeader(sess_sock);
    if (welcome_hdr.msg_type == @intFromEnum(protocol.ServerMsg.denied)) {
        try self.sendError(client, 409, "Connection denied");
        return;
    }

    var welcome_buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
    try protocol.readExact(sess_sock, &welcome_buf);
    const welcome = std.mem.bytesToValue(protocol.Welcome, &welcome_buf);

    // Create VTerminal and screen buffer for this SSE client
    var vterm = try VTerminal.init(self.alloc, welcome.session_cols, welcome.session_rows);
    errdefer vterm.deinit();

    var screen_buf = try vthtml.ScreenBuffer.init(self.alloc, welcome.session_cols, welcome.session_rows);
    errdefer screen_buf.deinit();

    // Send SSE headers
    const sse_headers =
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/event-stream\r\n" ++
        "Cache-Control: no-cache\r\n" ++
        "Connection: keep-alive\r\n" ++
        "Access-Control-Allow-Origin: *\r\n" ++
        "\r\n";

    _ = try posix.write(client.fd, sse_headers);

    // Read initial state and send keyframe
    const state_hdr = try protocol.readHeader(sess_sock);
    if (state_hdr.msg_type == @intFromEnum(protocol.ServerMsg.full)) {
        const state_data = try protocol.readPayload(self.alloc, sess_sock, state_hdr.len);
        defer self.alloc.free(state_data);

        vterm.feed(state_data);

        // Send initial keyframe (full screen)
        const updates = try screen_buf.fullScreen(&vterm);
        defer self.alloc.free(updates);
        try self.sendSseUpdate(client.fd, updates, vterm.cols, vterm.rows, true);
    }

    // Move client to SSE list
    const owned_name = try self.alloc.dupe(u8, session_name);
    errdefer self.alloc.free(owned_name);

    try self.sse_clients.append(self.alloc, .{
        .http_fd = client.fd,
        .session_fd = sess_sock,
        .session_name = owned_name,
        .vterm = vterm,
        .screen_buf = screen_buf,
        .last_update = std.time.timestamp(),
        .cols = welcome.session_cols,
        .rows = welcome.session_rows,
    });

    // Remove from regular clients list (without closing fd)
    _ = self.clients.orderedRemove(client_idx);
}

fn handleSseSessionOutput(self: *HttpServer, sse_idx: usize) !void {
    var sse = &self.sse_clients.items[sse_idx];

    // Read protocol message from session
    const header = try protocol.readHeader(sse.session_fd);

    switch (@as(protocol.ServerMsg, @enumFromInt(header.msg_type))) {
        .output, .full => {
            const data = try protocol.readPayload(self.alloc, sse.session_fd, header.len);
            defer self.alloc.free(data);

            // Feed to vterm
            sse.vterm.feed(data);

            // Compute delta from previous screen state and send updates
            const updates = try sse.screen_buf.updateFromVTerm(&sse.vterm);
            defer self.alloc.free(updates);

            if (updates.len > 0) {
                try self.sendSseUpdate(sse.http_fd, updates, sse.cols, sse.rows, false);
            }
            sse.last_update = std.time.timestamp();
        },
        .session_resize => {
            var resize_buf: [@sizeOf(protocol.SessionResize)]u8 = undefined;
            try protocol.readExact(sse.session_fd, &resize_buf);
            const resize = std.mem.bytesToValue(protocol.SessionResize, &resize_buf);

            try sse.vterm.resize(resize.cols, resize.rows);
            try sse.screen_buf.resize(resize.cols, resize.rows);
            sse.cols = resize.cols;
            sse.rows = resize.rows;

            // Send full screen after resize
            const updates = try sse.screen_buf.fullScreen(&sse.vterm);
            defer self.alloc.free(updates);
            try self.sendSseUpdate(sse.http_fd, updates, sse.cols, sse.rows, true);
            sse.last_update = std.time.timestamp();
        },
        .exit => {
            // Session ended
            const event = "event: exit\ndata: {}\n\n";
            _ = posix.write(sse.http_fd, event) catch {};
            return error.SessionEnded;
        },
        .role_change => {
            if (header.len == @sizeOf(protocol.RoleChange)) {
                var rc_buf: [@sizeOf(protocol.RoleChange)]u8 = undefined;
                try protocol.readExact(sse.session_fd, &rc_buf);
                const rc = std.mem.bytesToValue(protocol.RoleChange, &rc_buf);
                sse.is_primary = (rc.new_role == .primary);
            }
        },
        else => {
            // Skip unknown messages
            if (header.len > 0) {
                var remaining = header.len;
                var skip_buf: [4096]u8 = undefined;
                while (remaining > 0) {
                    const chunk: usize = @min(remaining, skip_buf.len);
                    try protocol.readExact(sse.session_fd, skip_buf[0..chunk]);
                    remaining -= @intCast(chunk);
                }
            }
        },
    }
}

fn sendPeriodicKeyframes(self: *HttpServer) !void {
    const now = std.time.timestamp();
    for (self.sse_clients.items) |*sse| {
        if (now - sse.last_update >= 30) {
            // Send full screen refresh periodically
            const updates = sse.screen_buf.fullScreen(&sse.vterm) catch continue;
            defer self.alloc.free(updates);
            self.sendSseUpdate(sse.http_fd, updates, sse.cols, sse.rows, true) catch continue;
            sse.last_update = now;
        }
    }
}

fn sendSseUpdate(self: *HttpServer, fd: posix.socket_t, updates: []const vthtml.CellUpdate, cols: u16, rows: u16, is_keyframe: bool) !void {
    const json = try vthtml.updatesToJson(self.alloc, updates, cols, rows);
    defer self.alloc.free(json);

    var event: std.ArrayList(u8) = .empty;
    defer event.deinit(self.alloc);

    // Use different event type for keyframes vs deltas
    const event_type = if (is_keyframe) "keyframe" else "delta";
    try event.appendSlice(self.alloc, "event: ");
    try event.appendSlice(self.alloc, event_type);
    try event.appendSlice(self.alloc, "\ndata: ");
    try event.appendSlice(self.alloc, json);
    try event.appendSlice(self.alloc, "\n\n");

    _ = try posix.write(fd, event.items);
}

fn validateAuth(self: *HttpServer, headers: []const u8) !Auth.TokenPayload {
    // Extract JWT from Cookie header
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, "cookie:")) {
            const cookie_value = std.mem.trimLeft(u8, line["cookie:".len..], " ");
            // Parse cookies
            var cookies = std.mem.splitSequence(u8, cookie_value, "; ");
            while (cookies.next()) |cookie| {
                if (std.mem.startsWith(u8, cookie, "jwt=")) {
                    const token = cookie["jwt=".len..];
                    return try self.auth.validateToken(token);
                }
            }
        }
    }
    return error.NoToken;
}

fn sendError(self: *HttpServer, client: *HttpClient, code: u16, message: []const u8) !void {
    const status = switch (code) {
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        409 => "Conflict",
        500 => "Internal Server Error",
        else => "Error",
    };

    const body = try std.fmt.allocPrint(self.alloc, "{{\"error\":\"{s}\"}}", .{message});
    defer self.alloc.free(body);

    const response = try std.fmt.allocPrint(self.alloc,
        "HTTP/1.1 {d} {s}\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "\r\n" ++
            "{s}", .{ code, status, body.len, body });

    client.response_buf = response;
    client.response_sent = 0;
    client.state = .sending_response;
}

fn sendJson(self: *HttpServer, client: *HttpClient, json: []const u8) !void {
    const response = try std.fmt.allocPrint(self.alloc,
        "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "\r\n" ++
            "{s}", .{ json.len, json });

    client.response_buf = response;
    client.response_sent = 0;
    client.state = .sending_response;
}

fn removeClient(self: *HttpServer, idx: usize) void {
    const client = self.clients.items[idx];
    posix.close(client.fd);
    if (client.response_buf.len > 0) self.alloc.free(client.response_buf);
    _ = self.clients.orderedRemove(idx);
}

fn removeSseClient(self: *HttpServer, idx: usize) void {
    var sse = self.sse_clients.items[idx];
    sse.deinit(self.alloc);
    _ = self.sse_clients.orderedRemove(idx);
}

fn getContentLength(headers: []const u8) usize {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
            const value = std.mem.trimLeft(u8, line["content-length:".len..], " ");
            return std.fmt.parseInt(usize, value, 10) catch 0;
        }
    }
    return 0;
}

fn createTcpSocket4(bind_addr: []const u8, port: u16) !posix.socket_t {
    const sock = try posix.socket(posix.AF.INET, posix.SOCK.STREAM | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK, 0);
    errdefer posix.close(sock);

    // Set SO_REUSEADDR
    const optval: u32 = 1;
    try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEADDR, std.mem.asBytes(&optval));

    const addr = net.Address.parseIp4(bind_addr, port) catch net.Address.parseIp4("127.0.0.1", port) catch unreachable;
    try posix.bind(sock, &addr.any, addr.getOsSockLen());
    try posix.listen(sock, 128);

    return sock;
}

fn createTcpSocket6(bind_addr: []const u8, port: u16) !posix.socket_t {
    const sock = try posix.socket(posix.AF.INET6, posix.SOCK.STREAM | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK, 0);
    errdefer posix.close(sock);

    // Set SO_REUSEADDR
    const optval: u32 = 1;
    try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEADDR, std.mem.asBytes(&optval));

    const addr = net.Address.parseIp6(bind_addr, port) catch net.Address.parseIp6("::1", port) catch unreachable;
    try posix.bind(sock, &addr.any, addr.getOsSockLen());
    try posix.listen(sock, 128);

    return sock;
}

fn connectToSession(path: []const u8) !posix.socket_t {
    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    var addr = net.Address.initUnix(path) catch return error.PathTooLong;
    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    return sock;
}

