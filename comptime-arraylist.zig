const std = @import("std");

pub fn ComptimeArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []const T = &.{},

        pub inline fn set(comptime self: *Self, comptime index: usize, comptime value: T) void {
            comptime {
                var new_array = self.array().*;
                new_array[index] = value;
                self.items = &new_array;
            }
        }

        pub inline fn setRangeToValue(comptime self: *Self, comptime start: usize, comptime end: usize, comptime value: T) void {
            comptime {
                var new_array = self.array().*;
                new_array[start..end].* = [_]T{value} ** (end - start);
                self.items = &new_array;
            }
        }

        pub inline fn setRangeToSlice(comptime self: *Self, comptime start: usize, comptime slice: []const T) void {
            comptime self.items =
                self.array()[0..start] ++
                slice ++
                self.array()[start + slice.len ..];
        }

        pub inline fn append(comptime self: *Self, comptime value: T) void {
            comptime self.items =
                self.items ++
                &[_]T{value};
        }

        pub inline fn appendSlice(comptime self: *Self, comptime slice: []const T) void {
            comptime self.items =
                self.items ++
                slice;
        }

        pub inline fn resize(comptime self: *Self, comptime new_size: usize) void {
            comptime self.items = if (new_size > self.items.len)
                self.items ++ ([_]T{undefined} ** (new_size - self.items.len))
            else
                self.items[0..new_size];
        }

        pub inline fn insert(comptime self: *Self, comptime index: usize, comptime value: T) void {
            comptime self.items =
                self.items[0..index] ++
                &[_]T{value} ++
                self.items[index..];
        }

        pub inline fn insertSlice(comptime self: *Self, comptime index: usize, comptime slice: []const T) void {
            comptime self.items =
                self.items[0..index] ++
                slice[0..slice.len] ++
                self.items[index..];
        }

        pub inline fn replaceRange(comptime self: *Self, comptime start: usize, comptime len: usize, comptime new_items: []const T) void {
            comptime {
                const after_range = start + len;
                const rangle_len = after_range - start;

                if (rangle_len == new_items.len)
                    self.setRangeToSlice(start, new_items)
                else if (rangle_len < new_items.len) {
                    const first = new_items[0..rangle_len];
                    const rest = new_items[rangle_len..];

                    self.setRangeToSlice(start, first);
                    self.insertSlice(after_range, rest);
                } else {
                    self.setRangeToSlice(start, new_items);
                    const after_subrange = start + new_items.len;

                    for (self.items[after_range..]) |item, i| {
                        self.set(after_subrange + i, item);
                    }

                    self.resize(self.items.len - (len - new_items.len));
                }
            }
        }

        pub inline fn pop(comptime self: *Self) T {
            comptime {
                const result = self.items[self.items.len - 1];
                var new_array = self.array()[0 .. self.items.len - 1].*;
                self.items = &new_array;
                return result;
            }
        }

        pub inline fn popOrNull(comptime self: *Self) ?T {
            comptime {
                if (self.items.len == 0) return null;
                return self.pop();
            }
        }

        inline fn array(comptime self: *Self) *const [self.items.len]T {
            return comptime self.items[0..self.items.len];
        }
    };
}

test {
    comptime var comptime_str: ComptimeArrayList(u8) = .{};
    var runtime_str = std.ArrayList(u8).init(std.testing.allocator);
    defer runtime_str.deinit();

    comptime comptime_str.appendSlice(&[_]u8{'a'} ** 4);
    try runtime_str.appendSlice(&[_]u8{'a'} ** 4);
    try std.testing.expectEqualStrings(runtime_str.items, comptime_str.items);

    comptime comptime_str.appendSlice(&[_]u8{'b'} ** 4);
    try runtime_str.appendSlice(&[_]u8{'b'} ** 4);
    try std.testing.expectEqualStrings(runtime_str.items, comptime_str.items);

    comptime comptime_str.replaceRange(4, 3, "foo");
    try runtime_str.replaceRange(4, 3, "foo");
    try std.testing.expectEqualStrings(runtime_str.items, comptime_str.items);

    try std.testing.expectEqual(runtime_str.pop(), comptime comptime_str.pop());
    try std.testing.expectEqualStrings(runtime_str.items, comptime_str.items);

    try std.testing.expectEqual(runtime_str.popOrNull(), comptime comptime_str.popOrNull());
    try std.testing.expectEqualStrings(runtime_str.items, comptime_str.items);
}
