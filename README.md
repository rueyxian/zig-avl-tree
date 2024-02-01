# zig-avl-tree
An AVL tree data structure library for Zig.


## Features
- An [AVL tree](https://en.wikipedia.org/wiki/AVL_tree) data structure with minimal abstractions.
- An alternative [binary search tree](https://en.wikipedia.org/wiki/Binary_search_tree) to [`std.Treap`](https://ziglang.org/documentation/master/std/#A;std:Treap).
- To maintain consistency, the API calls mirror those of `std.Treap`.


## Installation


To add `avl_tree` to your `build.zig.zon`:

```
.{
    .name = "<YOUR PROGRAM>",
    .version = "0.0.0",
    .dependencies = .{
        .avl_tree = .{
            .url = "https://github.com/rueyxian/zig-avl-tree/archive/refs/tags/v0.0.0.tar.gz",
            .hash = "<CORRECT HASH WILL BE SUGGESTED>",
        },
    },
}
```

To add `avl_tree` to your `build.zig`:

```zig
const dep_avl_tree = b.dependency("avl_tree", .{
    .target = target,
    .optimize = optimize,
});
exe.addModule("avl_tree", dep_avl_tree("avl"));
```

## Examples


To run an example:

```
$ zig build <EXAMPLE>
```
where `<EXAMPLE>` is one of:

- `run_basic`
- `run_memory_pool`


### Basic

```zig
const std = @import("std");
const debug = std.debug;
const AvlTree = @import("avl_tree").AvlTree;

pub fn main() !void {
    const Avl = AvlTree(u16, std.math.order);
    const Node = Avl.Node;
    var avl = Avl{};
    var nodes = [_]Node{undefined} ** 20;

    @constCast(&avl.getEntryFor(24)).set(&nodes[0]);
    @constCast(&avl.getEntryFor(60)).set(&nodes[1]);
    @constCast(&avl.getEntryFor(76)).set(&nodes[2]);
    @constCast(&avl.getEntryFor(31)).set(&nodes[3]);
    @constCast(&avl.getEntryFor(21)).set(&nodes[4]);
    @constCast(&avl.getEntryFor(39)).set(&nodes[5]);
    @constCast(&avl.getEntryFor(42)).set(&nodes[6]);
    @constCast(&avl.getEntryFor(83)).set(&nodes[7]);
    @constCast(&avl.getEntryFor(50)).set(&nodes[8]);
    @constCast(&avl.getEntryFor(25)).set(&nodes[9]);
    @constCast(&avl.getEntryFor(47)).set(&nodes[10]);
    @constCast(&avl.getEntryFor(34)).set(&nodes[11]);
    @constCast(&avl.getEntryFor(94)).set(&nodes[12]);
    @constCast(&avl.getEntryFor(49)).set(&nodes[13]);
    @constCast(&avl.getEntryFor(54)).set(&nodes[14]);
    @constCast(&avl.getEntryFor(30)).set(&nodes[15]);
    @constCast(&avl.getEntryFor(82)).set(&nodes[16]);
    @constCast(&avl.getEntryFor(29)).set(&nodes[17]);
    @constCast(&avl.getEntryFor(55)).set(&nodes[18]);
    @constCast(&avl.getEntryFor(46)).set(&nodes[19]);

    var it = avl.inorderIterator();
    while (it.next()) |e| {
        debug.print("{} ", .{e.key});
    }
    debug.print("\n", .{});
}

```