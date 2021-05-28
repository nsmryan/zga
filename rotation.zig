const std = @import("std");
const ga = @import("ga.zig");

const expect = std.testing.expect;
const assert = std.debug.assert;
const Random = std.rand.Random;

pub fn rotation(pop_src: *ga.Pop, pop_dst: *ga.Pop, random: *Random, pr: f32) void {
    var ind_index: usize = 0;

    while (ind_index < pop_src.inds.len) : (ind_index += 1) {
        if (random.float(f32) < pr) {
            var rotation_point = random.intRangeAtMost(usize, 0, pop_src.inds.len - 1);
            rotate(u8, pop_src.inds[ind_index].locs, pop_dst.inds[ind_index].locs, rotation_point);
        }
    }
}

pub fn rotate(comptime T: type, src: []const T, dst: []T, rotation_index: usize) void {
    assert(rotation_index < src.len);
    assert(dst.len == src.len);

    var loc_index: usize = 0;
    while (loc_index < src.len) : (loc_index += 1) {
        const index: usize = @mod(loc_index + rotation_index, src.len);

        dst[loc_index] = src[index];
    }
}

test "rotation" {
    var src = [_]u8{ 0, 0, 1, 1, 1 };
    var dst = [_]u8{ 0, 0, 0, 0, 0 };
    rotate(u8, src[0..], dst[0..], 2);

    expect(dst[0] == 1);
    expect(dst[1] == 1);
    expect(dst[2] == 1);
    expect(dst[3] == 0);
    expect(dst[4] == 0);
}
