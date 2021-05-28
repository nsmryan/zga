const std = @import("std");
const ga = @import("ga.zig");

const expect = std.testing.expect;
const assert = std.debug.assert;

pub fn two_tournament_selection(src: *ga.Pop, dest: *ga.Pop, fitnesses: []f32, ps: f32, random: *std.rand.Random) void {
    var ind_index: usize = 0;
    while (ind_index < dest.inds.len) : (ind_index += 1) {
        var first_index = random.intRangeAtMost(usize, 0, src.inds.len - 1);
        var second_index = random.intRangeAtMost(usize, 0, src.inds.len - 1);

        if (fitnesses[first_index] < fitnesses[second_index]) {
            std.mem.swap(usize, &first_index, &second_index);
        }

        var selected: usize = hold_tournament(first_index, second_index, ps, random);
        std.mem.copy(u8, dest.inds[ind_index].locs, src.inds[selected].locs);
    }
}

/// Hold a two individual tournament. The first individual is assumed to have an equal or greater
/// fitness compared to the second.
pub fn hold_tournament(first_index: usize, second_index: usize, ps: f32, random: *std.rand.Random) usize {
    var selected: usize = 0;
    if (random.float(f32) < ps) {
        selected = first_index;
    } else {
        selected = second_index;
    }
    return selected;
}

test "mem copy slice" {
    const allocator = std.heap.page_allocator;

    const byte_count = 10;
    var bytes = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes, 0);

    var bytes2 = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes2, 1);

    expect(bytes[0] == 0);
    expect(bytes2[0] == 1);
    std.mem.copy(u8, bytes, bytes2);
    expect(bytes[0] == 1);
    expect(bytes2[0] == 1);
}
