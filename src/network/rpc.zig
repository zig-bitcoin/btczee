const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Mempool = @import("../core/mempool.zig").Mempool;
const Storage = @import("../storage/storage.zig").Storage;
const httpz = @import("httpz");

/// RPC Server handler.
///
/// The RPC server is responsible for handling the RPC requests from the clients.
///
/// See https://developer.bitcoin.org/reference/rpc/
pub const RPC = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    mempool: *Mempool,
    storage: *Storage,

    pub fn init(
        allocator: std.mem.Allocator,
        config: *const Config,
        mempool: *Mempool,
        storage: *Storage,
    ) !RPC {
        const rpc = RPC{
            .allocator = allocator,
            .config = config,
            .mempool = mempool,
            .storage = storage,
        };

        return rpc;
    }

    pub fn deinit(self: *RPC) void {
        _ = self;
    }

    pub fn start(self: *RPC) !void {
        std.log.info("Starting RPC server on port {}", .{self.config.rpc_port});
        var handler = Handler{};

        var server = try httpz.Server(*Handler).init(self.allocator, .{ .port = self.config.rpc_port }, &handler);
        var router = server.router(.{});
        // Register routes.
        router.get("/", index, .{});
        router.get("/error", @"error", .{});

        std.debug.print("Listening http://localhost:{d}/\n", .{self.config.rpc_port});

        // Starts the server, this is blocking.
        // TODO: Make it non-blocking. cc @StringNick
        //try server.listen();
    }
};

const Handler = struct {

    // If the handler defines a special "notFound" function, it'll be called
    // when a request is made and no route matches.
    pub fn notFound(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
        res.status = 404;
        res.body = "NOPE!";
    }

    // If the handler defines the special "uncaughtError" function, it'll be
    // called when an action returns an error.
    // Note that this function takes an additional parameter (the error) and
    // returns a `void` rather than a `!void`.
    pub fn uncaughtError(_: *Handler, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
        std.debug.print("uncaught http error at {s}: {}\n", .{ req.url.path, err });

        // Alternative to res.content_type = .TYPE
        // useful for dynamic content types, or content types not defined in
        // httpz.ContentType
        res.headers.add("content-type", "text/html; charset=utf-8");

        res.status = 505;
        res.body = "<!DOCTYPE html>(╯°□°)╯︵ ┻━┻";
    }
};

fn index(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    res.body =
        \\<!DOCTYPE html>
        \\ <p>Running Bitcoin.
    ;
}

fn @"error"(_: *Handler, _: *httpz.Request, _: *httpz.Response) !void {
    return error.ActionError;
}
