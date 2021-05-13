const std = @import("std");

const expect = std.testing.expect;
const assert = std.debug.assert;

const Ind = struct {
    locs: []u8,

    pub fn init(locs: []u8) Ind {
        return Ind{ .locs = locs };
    }
};

const Pop = struct {
    inds: []Ind,

    pub fn init(inds: []Ind) Pop {
        return Pop{ .inds = inds };
    }

    pub fn new(pop_size: usize, ind_size: usize, allocator: *std.mem.Allocator) !Pop {
        const byte_count = pop_size * ind_size / @bitSizeOf(u8);
        var bytes = try allocator.alloc(u8, byte_count);
        std.mem.set(u8, bytes, 0);

        var inds: []Ind = try allocator.alloc(Ind, pop_size);

        {
            var ind_index: usize = 0;
            while (ind_index < pop_size) : (ind_index += 1) {
                const start = ind_index * ind_size / @bitSizeOf(u8);
                const end = (ind_index + 1) * ind_size / @bitSizeOf(u8);
                inds[ind_index] = Ind.init(bytes[start..end]);
            }
        }

        var pop: Pop = Pop.init(inds);
        return pop;
    }

    pub fn randomize(pop: *Pop, random: *std.rand.Random) void {
        var ind_index: usize = 0;
        while (ind_index < pop.inds.len) : (ind_index += 1) {
            var loc_index: usize = 0;
            while (loc_index < pop.inds[ind_index].locs.len) : (loc_index += 1) {
                pop.inds[ind_index].locs[loc_index] = random.int(u8);
            }
        }
    }

    pub fn print(pop: *Pop) !void {
        const stdout = std.io.getStdOut();

        var ind_index: usize = 0;
        while (ind_index < pop.inds.len) : (ind_index += 1) {
            var loc_index: usize = 0;
            var ind = pop.inds[ind_index];
            while (loc_index < ind.locs.len) : (loc_index += 1) {
                var bit_index: u8 = 0;
                while (bit_index < @bitSizeOf(u8)) : (bit_index += 1) {
                    const shift: u3 = @intCast(u3, bit_index);
                    if (pop.inds[ind_index].locs[loc_index] & (@shlExact(@as(u8, 1), shift)) != 0) {
                        try stdout.writer().print("1", .{});
                    } else {
                        try stdout.writer().print("0", .{});
                    }
                }
            }
            try stdout.writer().print("\n", .{});
        }

        try stdout.writer().print("\n", .{});
    }
};

pub fn point_mutation(pop: *Pop, rand: *std.rand.Random, pm: f32) void {
    var ind_index: usize = 0;
    while (ind_index < pop.inds.len) : (ind_index += 1) {
        var loc_index: usize = 0;
        var ind = pop.inds[ind_index];
        while (loc_index < ind.locs.len) : (loc_index += 1) {
            var bit_index: u8 = 0;
            while (bit_index < @bitSizeOf(u8)) : (bit_index += 1) {
                if (rand.float(f32) < pm) {
                    const shift: u3 = @intCast(u3, bit_index);
                    ind.locs[loc_index] ^= @shlExact(@as(u8, 1), shift);
                }
            }
        }
    }
}

pub fn one_point_crossover(pop: *Pop, rand: *std.rand.Random, pc: f32) void {
    const ind_len = pop.inds[0].locs.len;

    var pair_index: usize = 0;
    while (pair_index < (pop.inds.len / 2)) : (pair_index += 1) {
        if (rand.float(f32) < pc) {
            const first_index = pair_index * 2;
            const second_index = pair_index * 2 + 1;

            const cross_point = rand.intRangeAtMost(usize, 0, ind_len - 1);
            cross(cross_point, pop.inds[first_index].locs, pop.inds[second_index].locs);
        }
    }
}

pub fn cross(cross_point: usize, first: []u8, second: []u8) void {
    assert(first.len == second.len);
    assert(cross_point < first.len);
    assert(cross_point < second.len);

    var loc_index: usize = 0;
    while (loc_index < cross_point) : (loc_index += 1) {
        std.mem.swap(u8, &first[loc_index], &second[loc_index]);
    }
}

test "cross" {
    const allocator = std.heap.page_allocator;

    const byte_count = 10;
    var bytes = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes, 0);

    var bytes2 = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes2, 1);

    expect(bytes[0] == 0);
    expect(bytes[byte_count - 1] == 0);
    expect(bytes2[0] == 1);
    expect(bytes2[byte_count - 1] == 1);

    cross(byte_count / 2, bytes, bytes2);

    expect(bytes[0] == 1);
    expect(bytes[byte_count - 1] == 0);
    expect(bytes2[0] == 0);
    expect(bytes2[byte_count - 1] == 1);
}

pub fn ones_evaluation(pop: *Pop, fitnesses: []f32) void {
    const ind_len = pop.inds[0].locs.len;

    var ind_index: usize = 0;
    while (ind_index < pop.inds.len) : (ind_index += 1) {
        fitnesses[ind_index] = @intToFloat(f32, count_ones(pop.inds[ind_index].locs));
    }
}

pub fn count_ones(bytes: []const u8) usize {
    var count: usize = 0;
    for (bytes) |byte| {
        count += @popCount(u8, byte);
    }
    return count;
}

test "count ones" {
    expect(count_ones(([_]u8{1})[0..]) == 1);
    expect(count_ones(([_]u8{ 1, 0xA, 7 })[0..]) == 6);
    expect(count_ones(([_]u8{})[0..]) == 0);
}

pub fn two_tournament_selection(src: *Pop, dest: *Pop, fitnesses: []f32, ps: f32, random: *std.rand.Random) void {
    var ind_index: usize = 0;
    while (ind_index < dest.inds.len) : (ind_index += 1) {
        var first_index = random.intRangeAtMost(usize, 0, src.inds.len - 1);
        var second_index = random.intRangeAtMost(usize, 0, src.inds.len - 1);

        if (fitnesses[first_index] < fitnesses[second_index]) {
            std.mem.swap(usize, &first_index, &second_index);
        }

        var selected: usize = 0;
        if (random.float(f32) < ps) {
            selected = first_index;
        } else {
            selected = second_index;
        }
        std.mem.copy(u8, dest.inds[ind_index].locs, src.inds[selected].locs);
    }
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

pub fn main() !void {
    const POP_SIZE = 10;
    const IND_SIZE = 64;
    const GENS = 10;

    const allocator = std.heap.page_allocator;

    var rng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = &rng.random;

    var pop = try Pop.new(POP_SIZE, IND_SIZE, allocator);

    pop.randomize(rand);

    var pop_other = try Pop.new(POP_SIZE, IND_SIZE, allocator);

    var pop_src = &pop;
    var pop_dest = &pop_other;

    const stdout = std.io.getStdOut();

    var gens: usize = 0;
    while (gens < GENS) : (gens += 1) {
        //try stdout.writer().print("-----------------------\n", .{});
        var fitnesses: []f32 = try allocator.alloc(f32, POP_SIZE);
        ones_evaluation(pop_src, fitnesses);

        var fitest: f32 = 0.0;
        var fit_index: usize = 0;
        while (fit_index < POP_SIZE) : (fit_index += 1) {
            fitest = std.math.max(fitest, fitnesses[fit_index]);
        }
        try stdout.writer().print("{:4.2}\n", .{fitest});

        two_tournament_selection(pop_src, pop_dest, fitnesses, 0.7, rand);

        std.mem.swap(*Pop, &pop_src, &pop_dest);

        //[try pop_src.print();
        point_mutation(pop_src, rand, 0.05);

        //[try pop_src.print();
        one_point_crossover(pop_src, rand, 0.6);
        //[try pop_src.print();

        //try pop_src.print();
    }

    var fitnesses: []f32 = try allocator.alloc(f32, POP_SIZE);
    ones_evaluation(pop_src, fitnesses);

    try pop_src.print();
    var fit_index: usize = 0;
    while (fit_index < POP_SIZE) : (fit_index += 1) {
        try stdout.writer().print("{d} ", .{fitnesses[fit_index]});
    }
    try stdout.writer().print("\n", .{});
}
