CLAUDE NOTE: you are being run in a loop. pick one thing to do, and do it. it
need not be code, but should advance the project. code, documentation, hammock
time (with notes), etc etc. just make sure you update the log every time.

I can't respond to questions. If you need to ask something, put it near the top
of this file and stop. This should be a last resort, exercise agency.

If you're spending a lot of time on a task, it's preferable to stop rather than
exhaust your context window. Take notes, stop, and come back to it in the next
iteration.

# Requests:

Ongoing:

- You may tag releases or branch/merge as you wish. !Under no circumstances
  should you push.!
- Manage this file. Archive old sessions as needed, and summarize.
- You are developing strong opinions over time, which is good, but you have also
  calcified a bit. Every now and then, write the best possible case for making
  different decisions. Then, the next iteration, write a response. In the next,
  a reflection. No ego, just good, simple, clean software. It's okay to have
  been wrong, it's okay to have been right.
- It's okay to leave the code in a broken state between iterations, either while
  working on a longer task (consider making subtasks), or if a larger-scale
  project is worth it. We're not shipping the intermediate states and you are
  the primary dev. Just clearly indicate in documentation what the state is, and
  have a plan.
- Maintain a detailed specification document, and keep track of individual
  features / usecases / edge cases / regressions. You may want to go commit by
  commit (do this in a few iterations) to make sure you understand everything,
  and haven't forgotten anything along the way.
- Stylistically, there are a lot of longer functions with comments explaining
  individual steps. More smaller (and simpler (decomplected)) functions are
  preferable.
- Every 3 sessions, take some time to interrogate your abstractions. Is the
  architecture sound? Is the code maintainable? What's working? What isn't?
  What's simple, and what's complected? Think about the long term. You'll have
  to maintain this, don't make that hard on yourself.

Inbox: keep this up to date.

New: (triaged in session 48)

- ✗ "No framework bloat" in the README - resolved: no datastar in codebase,
  README already says "No framework dependencies." Pure vanilla JS.
- ✓ TUIs seem to break every so often - fixed in session 55: resize handlers now
  re-render viewport and clear screen. Was missing re-render on both
  session_resize and SIGWINCH.
- ✓ Keybinds are broken on TUI viewer sessions - likely fixed by session 55
  resize re-render fix (rendering corruption made it look like input didn't
  work). Needs confirmation.
- ✓ Pressing a key in the browser takes over a session automatically - fixed in
  session 49: input blocked for non-primary, explicit takeover required.
- ✓ We should have some notion of read-only OTPs. - done in session 52.
- ✓ Browser feels laggier than it should on localhost - fixed in session 50:
  replaced innerHTML HTML-string parsing with structured JSON + createElement.
- ✓ Rendering architecture redesign: targeted fixes (resize re-render S55,
  cursor tracking S56) resolved the concrete bugs. Full redesign rejected as
  unnecessary. Echo/noecho mode detection deferred (no bug reports driving it).
- spend many iterations hammocking about the problem. it's complete - but could
  it be better? what would make you proud to have done in this codebase?

Current:

- None. v1.0.0 tagged. Future work driven by usage.

Done (Sessions 55-66): Resize re-render fix (S55), cursor position fix (S56),
architecture review (S57), Arch PKGBUILD + LICENSE (S58), session list SSE
(S59), architecture review + http.zig devil's advocate (S60), http.zig
reflection + archive cleanup (S61), docs audit + dual-bind fix (S62), v1.0.0 tag
(S63), index.html splitting devil's advocate (S64), response (S65), index.html
reflection + architecture review (S66).

Done (Sessions 26-58): See [doc/sessions-archive.md](doc/sessions-archive.md)
for detailed notes. Key milestones: HTML deltas (S26), web input fix (S32),
resize+measurement (S34), cell gaps (S35), Ctrl+Space (S36), status bar (S37),
auto-naming (S38-40), autostart serve (S41), main.zig dedup (S43), docs (S45),
mobile toolbar (S46/53), Nix fix (S47), browser perf (S50), read-only OTPs
(S52), XSS fix (S54).

The task at hand

# Vanish

lightweight libghostty terminal session multiplexer with web access

## Core

- dtach is great, but the fact that it only passes bytes through limits it.
- to preserve the state of the terminal as a user would see it, and for
  scrollback, a terminal emulator is needed (tmux does this)
- most terminal emulators are bad
- libghostty is good

## Sessions

- supports up to 1 primary consumer per session at a time. this session
  determines the height/width, and can write to the session.
- supports any number of view-only consumers
- session management is like dtach - a socket.
- by default, closing the process exits the session, but there's a keybinding /
  command to detach. (the intent is to make this convinient to use for every
  terminal, and detach when needed.

## Native Client

- for output that's scrolling, it'll keep track of scrollback and adapt it to
  the consumer's terminal size if necessary
- for something like nvim, just let it get cut off, and allow consumers to move
  around with hjkl (configurable).
- there is a configurable leader key that most binds are behind
- the ui is typically nothing. you shouldn't even be able to tell that you're in
  one of these sessions as a writer until you press the leader key, at which
  point keybinding assistance pops up
- there is a toggleable status bar as well - it shows when the keybinding menu
  is active, and users can toggle it with a bind to have it show up all the
  time.
- when there are binds available (except under leader under the default config),
  the keybinding help pops up. this means it has to be unobtrusive (there may be
  a need for a larger one if there are many binds - there should be a clearly
  indicated ? or more key or something to pop up something larger.). _consumers
  typically have scrolling commands available on hjkl, so they should always see
  those available._
- for the scrollback mode, handle it by literally just dumping n lines of
  scrollback to the terminal - we don't want to have to deal with our own
  scrolling, just use the terminals. for the non-scrollback mode, just show the
  state of the terminal.

## Web Access

- `vanish serve` starts an HTTP server for browser-based access to sessions
- JWT/HMAC authentication with OTP exchange for security
- SSE (Server-Sent Events) for streaming terminal output to browsers
- server-side VT→HTML rendering with cell-level delta streaming
- each SSE client maintains a ScreenBuffer; only changed cells sent over wire
- vanilla JS frontend, no framework dependencies

## Design Principles

- scope this out. make it elegant, minimal, don't trust i've framed the problem
  perfectly, make sure it's extremely performant and well-tested. code should be
  clean, idiomatic, with only the essential comments. you're not writing
  clojure, but imagine what rich hickey would do.
- keep detailed notes at all points through the process. you will be run in a
  loop on this prompt.md. feel free to edit it.
- conventional, idiomatic commits. the git history should be useful.
- prioritize designing - both the architecture as well as the interface (user
  interface, the config, documentation, etc.).
- goal is to be a minimal, inoffensive, out-of-the-way, but extrordinarily
  useful tool.

# Env note:

- you are on a nixos system. you will want to create a default.nix that exposes
  the package, as well as an overlay.
- don't make a flake.nix
- make a shell.nix that enables working on this project, as well as an .envrc.
- WRITE THIS IN ZIG 0.15!!!
- idiomatic nix, idiomatic zig, idiomatic posix.
- keep comments to a minimum unless they genuinely explain things
- relentlessly think and refine your abstractions. every piece of this should be
  simple (as opposed to easy). functions should almost always be small.

---

# Progress Notes

## 2026-02-09: Session 67 - Devil's Advocate: The Protocol Design

### Settled Decisions (from previous debates)

1. **http.zig monolithic:** Keep. (Sessions 60-61)
2. **index.html single-file:** Keep. (Sessions 64-66)

Both settled on the same heuristic: the split trigger is "understanding concern A
requires understanding concern B," not file size or count.

### Devil's Advocate: The Case Against the Protocol

The protocol has been praised repeatedly as simple, clean, minimal. 192 lines,
5-byte header, 17 message types, extern structs. It has never been seriously
challenged. Here is the best case a thoughtful critic would make.

**1. Native byte order is a time bomb.**

`std.mem.asBytes` and `std.mem.bytesToValue` serialize structs in the CPU's
native byte order. Today, every machine running vanish is little-endian x86_64.
But Zig targets 60+ architectures. The protocol is a wire format — it goes over
Unix domain sockets between processes. If vanish ever runs on a big-endian
system, or if someone cross-compiles a client for a different architecture that
shares the same socket directory (NFS, container bind mounts), the wire format
silently produces garbage. Every serious binary protocol (protobuf, msgpack,
cap'n proto, even HTTP/2) specifies byte order. This one doesn't.

The fix is trivial (`std.mem.nativeTo`/`std.mem.toNative` with `.little`), but
the current code would need to change every `asBytes`/`bytesToValue` call. The
longer you wait, the more client code exists that assumes native order.

**2. extern struct alignment is fragile and undertested.**

The protocol relies on `extern struct` to get C-compatible layout, but the
actual wire sizes depend on field ordering and platform alignment rules.
Consider:

- `Header` is 5 bytes. There's a test for this. Good.
- `Welcome` is logically 21 bytes (1 + 16 + 2 + 2) but actually 24 due to
  alignment padding after the `role: u8` field. **There is no test for this.**
- `ClientInfo` is logically 9 bytes (4 + 1 + 2 + 2) but actually 10 bytes due
  to padding after `role: u8`. **There is no test for this.** The `client_list`
  message parses it as `header.len / @sizeOf(ClientInfo)` — if the size
  assumption is wrong, the parser silently reads garbage.
- `Hello` is 76 bytes with a [64]u8 array. No size test.

These struct sizes are part of the wire format. They should all have size tests
like `Header` does. Without them, a Zig compiler update that changes extern
struct layout rules (or a platform with different alignment) silently breaks the
protocol. The Header test was the right instinct — the mistake was stopping at
one.

**3. No version negotiation means no evolution path.**

The `hello`/`welcome` handshake has no version field. This means:

- You cannot add a field to `Hello` (it would change the struct size, and old
  servers would read garbage from the extra bytes or fail on EndOfStream).
- You cannot add a field to `Welcome` (same problem in reverse).
- You cannot change the semantics of any existing message type.
- You cannot deprecate a message type (old clients would still send it).

The only extension mechanism is adding new `ClientMsg`/`ServerMsg` enum values.
But there's no way for a client to know if the server supports a given message
type. If a v1.1 client sends `list_sessions` (0x0A) to a v1.0 server, the
server hits the `else` branch in its switch and... what? Drops the connection?
Ignores it? The behavior is whatever the current `else` branch does, which is
not negotiated or specified.

"We're at v1.0.0, we don't need versioning" is a common argument. But the cost
of adding a version byte to the hello handshake is 1 byte and ~5 lines of code
_now_. The cost of retrofitting versioning later is a breaking change to the
wire format, which means either a flag day (all clients and servers upgrade
simultaneously) or maintaining two protocol parsers.

**4. No message-level integrity checking.**

There is no checksum, CRC, or MAC on individual messages. Unix domain sockets
are reliable — they don't corrupt data like UDP might. But the protocol is also
used over TCP (the HTTP bridge connects to the session socket). And there's a
subtler issue: if the framing gets out of sync (a bug causes a partial read, or
a message length field is corrupted in memory), every subsequent message is
garbage. A per-message checksum would detect this immediately. Without one, a
framing desync manifests as mysterious "invalid message type" errors or silent
data corruption that's extremely hard to debug.

**5. The fixed-size term field in Hello is a C-ism.**

`term: [64]u8` with null termination is a C pattern, not a Zig pattern. It
wastes 50+ bytes per hello message (most TERM values are 10-20 chars), it has
a hard truncation limit, and it requires manual null-termination logic
(`setTerm`/`getTerm`). The Zig-idiomatic approach would be a length-prefixed
string in the variable payload section. This is a minor point, but it reveals a
tension: the protocol uses `extern struct` for zero-copy parsing (a C
optimization), but this means it inherits C's limitations around variable-length
data. The protocol can't represent a string longer than 63 bytes without
redesigning the message format.

**6. The output/full distinction is implicit and underdocumented.**

`output` (0x82) sends incremental terminal output. `full` (0x83) sends a full
screen state. But from the wire format alone, there's no way to distinguish
"this is a full redraw because the terminal resized" from "this is a full redraw
because a new client connected." The client must infer semantics from context
(did I just send a hello? did I just receive a session_resize?). This is fine
for two tightly-coupled implementations, but it's the kind of implicit coupling
that makes writing a third-party client harder — you'd need to read the vanish
source to understand the state machine, not just the protocol spec.

**7. The enum value scheme is arbitrary and wastes space.**

Client messages use 0x01-0x09. Server messages use 0x81-0x88. The high-bit
convention (server messages have bit 7 set) is undocumented but consistent. This
is fine. But the msg_type field is a u8 in the header, giving 256 possible
values. With 17 used, 239 are undefined. There's no "unknown message" handling
strategy. A receiver that encounters an unknown msg_type must... skip
`header.len` bytes? Drop the connection? The protocol doesn't say. This matters
the moment you add a message type: old receivers have undefined behavior.

**In summary:** The protocol is simple and correct for the current single-
platform, single-version deployment. The critique is not that it's broken — it's
that it has made several "works for now" choices (native byte order, no
versioning, no struct size tests, no integrity checks) that are trivially cheap
to fix now but expensive to fix later. A protocol that crosses process
boundaries is an API contract. It deserves the same care as a public function
signature.

### What this critique does NOT argue

This is not an argument for protobuf, msgpack, or any serialization framework.
The hand-rolled binary protocol is the right call for vanish. The argument is
that the hand-rolled protocol should be more rigorous about the things that
matter for wire formats: byte order, size stability, version negotiation, and
error handling for unknown messages.

### Recommendations for Next Session

Session 68 should write the response defending the current protocol design.
Session 69 will be the reflection.

---

> Earlier session notes (1-66) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).
