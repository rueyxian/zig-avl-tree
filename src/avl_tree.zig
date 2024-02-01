const std = @import("std");
const debug = std.debug;
const testing = std.testing;
const math = std.math;
const print = debug.print;
const mem = std.mem;

pub fn AvlTree(comptime Key: type, comptime compareFn: anytype) type {
    return struct {
        root: ?*Node = null,
        const Self = @This();

        fn compare(a: Key, b: Key) math.Order {
            return compareFn(a, b);
        }

        pub const Node = struct {
            key: Key,
            parent: ?*Node,
            children: [2]?*Node,
            height: usize = 0,

            pub fn getMin(self: *Node) *Node {
                var node: *Node = self;
                while (node.children[0]) |curr| : (node = curr) {}
                return node;
            }

            pub fn getMax(self: *Node) *Node {
                var node: *Node = self;
                while (node.children[1]) |curr| : (node = curr) {}
                return node;
            }

            fn balanceFactor(self: *const Node) i8 {
                const lh: isize = @as(isize, @intCast(if (self.children[0]) |n| n.height else 0));
                const rh: isize = @as(isize, @intCast(if (self.children[1]) |n| n.height else 0));
                return @intCast(rh - lh);
            }

            fn updateHeight(self: *Node) void {
                const lh = if (self.children[0]) |n| n.height else 0;
                const rh = if (self.children[1]) |n| n.height else 0;
                self.height = 1 + @max(lh, rh);
            }
        };

        pub fn getMin(self: Self) ?*Node {
            return (self.root orelse return null).getMin();
        }

        pub fn getMax(self: Self) ?*Node {
            return (self.root orelse return null).getMax();
        }

        pub const Entry = struct {
            avl: *Self,
            key: Key,
            node: ?*Node,
            context: union(enum) {
                inserted_under: ?*Node,
                removed,
            },

            pub fn set(self: *Entry, new_node: ?*Node) void {
                defer self.node = new_node;
                const new: *Node = new_node orelse {
                    if (self.node) |node| {
                        self.avl.remove(node);
                        self.context = .removed;
                    }
                    return;
                };
                const old: *Node = self.node orelse {
                    const parent: ?*Node = blk: {
                        var parent: ?*Node = undefined;
                        switch (self.context) {
                            .inserted_under => |p| parent = p,
                            .removed => debug.assert(self.avl.find(self.key, &parent) == null),
                        }
                        break :blk parent;
                    };
                    debug.assert(self.node == null);
                    self.avl.insert(self.key, parent, new);
                    self.context = .{ .inserted_under = parent };
                    return;
                };
                self.avl.replace(old, new);
            }
        };

        pub fn getEntryFor(self: *Self, key: Key) Entry {
            var parent: ?*Node = undefined;
            const node: ?*Node = self.find(key, &parent);
            return Entry{
                .avl = self,
                .key = key,
                .context = .{ .inserted_under = parent },
                .node = node,
            };
        }

        pub fn getEntryForExisting(self: *Self, node: *Node) Entry {
            debug.assert(node.height != 0);
            return Entry{
                .avl = self,
                .key = node.key,
                .node = node,
                .context = .{ .inserted_under = node.parent },
            };
        }

        fn rotate(self: *Self, node: *Node, right: bool) void {
            const parent: ?*Node = node.parent;
            const target: *Node = node.children[@intFromBool(!right)] orelse unreachable;
            const adjacent: ?*Node = target.children[@intFromBool(right)];

            if (adjacent) |adj| adj.parent = node;

            node.parent = target;
            node.children[@intFromBool(!right)] = adjacent;

            target.parent = parent;
            target.children[@intFromBool(right)] = node;

            const link = if (parent) |p| &p.children[@intFromBool(p.children[1] == node)] else &self.root;
            debug.assert(link.* == node);
            link.* = target;

            node.updateHeight();
            target.updateHeight();
        }

        fn rebalance(self: *Self, node_opt: ?*Node) void {
            const node = node_opt orelse return;
            node.updateHeight();
            const right_heavy = switch (node.balanceFactor()) {
                -2 => false,
                2 => true,
                else => |bf| {
                    debug.assert(bf < 2 and bf > -2);
                    self.rebalance(node.parent);
                    return;
                },
            };

            const sub: *Node = node.children[@intFromBool(right_heavy)].?;
            const sub_bf = sub.balanceFactor();
            debug.assert(sub_bf >= -1 and sub_bf <= 1);
            if ((right_heavy and sub_bf == -1) or (!right_heavy and sub_bf == 1)) {
                self.rotate(sub, right_heavy); // to make LR-imba or RL-imba into LL-imba or RR-imba respectively
            }
            self.rotate(node, !right_heavy); // to fix LL-imba or RR-imba
            self.rebalance(node.parent);
        }

        fn find(self: *Self, key: Key, parent_ref: *?*Node) ?*Node {
            var node: ?*Node = self.root;
            parent_ref.* = null;
            while (node) |n| {
                const order = compare(key, n.key);
                if (order == .eq) break;
                parent_ref.* = n;
                node = n.children[@intFromBool(order == .gt)];
            }
            return node;
        }

        fn insert(self: *Self, key: Key, parent: ?*Node, node: *Node) void {
            node.key = key;
            node.parent = parent;
            node.children = [_]?*Node{ null, null };
            node.height = 1;
            const link: *?*Node = if (parent) |p| &p.children[@intFromBool(compare(key, p.key) == .gt)] else &self.root;
            debug.assert(link.* == null);
            link.* = node;
            self.rebalance(node.parent);
        }

        fn replace(self: *Self, old: *Node, new: *Node) void {
            new.key = old.key;
            new.parent = old.parent;
            new.children = old.children;
            new.height = old.height;

            const link: *?*Node = if (old.parent) |p| &p.children[@intFromBool(p.children[0] != old)] else &self.root;
            debug.assert(link.* == old);
            link.* = new;

            for (old.children) |child_opt| {
                const child: *Node = child_opt orelse continue;
                debug.assert(child.parent == old);
                child.parent = new;
            }

            // NOTE: The `std.Treap` does not remove the old node if it's not the same node, and I wonder why.
            // Maybe I missed something, but anyway, here it does differently.
            if (old == new) return;
            old.parent = null;
            old.children = [_]?*Node{ null, null };
            old.height = 0;
        }

        fn remove(self: *Self, node: *Node) void {
            while (true) {
                const inorder = (node.children[0] orelse (node.children[1] orelse break).getMin()).getMax();

                var link: *?*Node = if (node.parent) |p| &p.children[@intFromBool(p.children[1] == node)] else &self.root;
                debug.assert(link.* == node);
                link.* = inorder;

                link = if (inorder.parent) |p| &p.children[@intFromBool(p.children[1] == inorder)] else unreachable;
                debug.assert(link.* == inorder);
                link.* = node;

                mem.swap(usize, &inorder.height, &node.height);
                mem.swap(?*Node, &inorder.parent, &node.parent);
                mem.swap([2]?*Node, &inorder.children, &node.children);

                if (node.children[0]) |n| n.parent = node;
                if (node.children[1]) |n| n.parent = node;
                if (inorder.children[0]) |n| n.parent = inorder;
                if (inorder.children[1]) |n| n.parent = inorder;
            }
            const parent = node.parent;
            const link: *?*Node = if (parent) |p| &p.children[@intFromBool(p.children[1] == node)] else &self.root;
            debug.assert(link.* == node);
            link.* = null;

            debug.assert(node.children[0] == null and node.children[1] == null);
            node.parent = null;
            node.height = 0;

            self.rebalance(parent);
        }

        pub const InorderIterator = struct {
            curr: ?*Node,
            prev: ?*Node = null,

            pub fn next(it: *InorderIterator) ?*Node {
                while (true) {
                    const curr: *Node = it.curr orelse return null;
                    const prev: ?*Node = it.prev;
                    it.prev = curr;

                    if (prev == curr.parent) {
                        if (curr.children[0]) |left| {
                            it.curr = left;
                            continue;
                        }
                        if (curr.children[1]) |right| {
                            it.curr = right;
                        } else {
                            it.curr = curr.parent;
                        }
                        return curr;
                    }
                    if (curr.children[0] == prev) {
                        if (curr.children[1]) |right| {
                            it.curr = right;
                        } else {
                            it.curr = curr.parent;
                        }
                        return curr;
                    }
                    if (curr.children[1] == prev) {
                        it.curr = curr.parent;
                        continue;
                    }
                    unreachable;
                }
            }
        };

        pub fn inorderIterator(self: *Self) InorderIterator {
            return .{ .curr = self.root };
        }
    };
}

// NOTE: copy-pasta from `std.Treap`
fn SliceIterRandomOrder(comptime T: type) type {
    return struct {
        rng: std.rand.Random,
        slice: []T,
        index: usize = undefined,
        offset: usize = undefined,
        co_prime: usize,

        const Self = @This();

        pub fn init(slice: []T, rng: std.rand.Random) Self {
            return Self{
                .rng = rng,
                .slice = slice,
                .co_prime = blk: {
                    if (slice.len == 0) break :blk 0;
                    var prime = slice.len / 2;
                    while (prime < slice.len) : (prime += 1) {
                        var gcd = [_]usize{ prime, slice.len };
                        while (gcd[1] != 0) {
                            const temp = gcd;
                            gcd = [_]usize{ temp[1], temp[0] % temp[1] };
                        }
                        if (gcd[0] == 1) break;
                    }
                    break :blk prime;
                },
            };
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.offset = self.rng.int(usize);
        }

        pub fn next(self: *Self) ?*T {
            if (self.index >= self.slice.len) return null;
            defer self.index += 1;
            return &self.slice[((self.index *% self.co_prime) +% self.offset) % self.slice.len];
        }
    };
}

fn testBalanceFactor(tree: anytype) !void {
    var it = tree.inorderIterator();
    while (it.next()) |n| {
        try testing.expect(n.balanceFactor() < 2 and n.balanceFactor() > -2);
    }
}

test "insert, find, replace, remove" {
    // if (true) return error.SkipZigTest;

    const TestTree = AvlTree(u64, std.math.order);
    const TestNode = TestTree.Node;

    var tree = TestTree{};
    var nodes: [20]TestNode = undefined;

    var prng = std.rand.DefaultPrng.init(0xdeadbeef);
    var iter = SliceIterRandomOrder(TestNode).init(&nodes, prng.random());

    var max: u64 = 0;
    var min: u64 = math.maxInt(u64);

    // insert check
    iter.reset();
    while (iter.next()) |node| {
        const key = prng.random().int(u64);

        // make sure the current entry is empty.
        var entry = tree.getEntryFor(key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, null);

        // insert the entry and make sure the fields are correct.
        entry.set(node);
        try testing.expectEqual(node.key, key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);
        try testBalanceFactor(&tree);

        max = @max(max, key);
        min = @min(min, key);
    }
    try testing.expectEqual(max, tree.getMax().?.key);
    try testing.expectEqual(min, tree.getMin().?.key);

    // find check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by-key and by-node after having been inserted.
        const entry = tree.getEntryFor(node.key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, tree.getEntryForExisting(node).node);
    }

    // in-order iterator check
    {
        var it = tree.inorderIterator();
        var last_key: u64 = 0;
        while (it.next()) |node| {
            try std.testing.expect(node.key >= last_key);
            last_key = node.key;
        }
    }

    // replace check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by node since we already know it exists
        var entry = tree.getEntryForExisting(node);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);

        var stub_node: TestNode = undefined;

        // replace the node with a stub_node and ensure future finds point to the stub_node.
        entry.set(&stub_node);
        try testing.expectEqual(entry.node, &stub_node);
        try testing.expectEqual(entry.node, tree.getEntryFor(key).node);
        try testing.expectEqual(entry.node, tree.getEntryForExisting(&stub_node).node);
        try testBalanceFactor(&tree);

        // replace the stub_node back to the node and ensure future finds point to the old node.
        entry.set(node);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, tree.getEntryFor(key).node);
        try testing.expectEqual(entry.node, tree.getEntryForExisting(node).node);
        try testBalanceFactor(&tree);
    }
    try testing.expectEqual(max, tree.getMax().?.key);
    try testing.expectEqual(min, tree.getMin().?.key);

    // remove check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by node since we already know it exists
        var entry = tree.getEntryForExisting(node);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);
        try testBalanceFactor(&tree);

        // remove the node at the entry and ensure future finds point to it being removed.
        entry.set(null);
        try testing.expectEqual(entry.node, null);
        try testing.expectEqual(entry.node, tree.getEntryFor(key).node);
        try testBalanceFactor(&tree);

        // insert the node back and ensure future finds point to the inserted node
        entry.set(node);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, tree.getEntryFor(key).node);
        try testing.expectEqual(entry.node, tree.getEntryForExisting(node).node);
        try testBalanceFactor(&tree);

        // remove the node again and make sure it was cleared after the insert
        entry.set(null);
        try testing.expectEqual(entry.node, null);
        try testing.expectEqual(entry.node, tree.getEntryFor(key).node);
        try testBalanceFactor(&tree);
    }
    try testing.expect(tree.getMax() == null);
    try testing.expect(tree.getMin() == null);
}
