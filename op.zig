
pub fn Op(comptime T: type) type {
    return struct {
        nextFn: fn (op: *Op(T), rand: *Random) T;

        pub fn next(op: *Op(T), rand: *Random) T {
            return self.nextFn(op, rand);
        }
    };
};

pub fn steps_next_fn(op: *Op(usize), rand: *Random) usize {
    var self = @fieldParentPtr(Steps, "nextFn", op);

    // TODO return the next in the geometric sequence

    return 0;
}

pub struct Steps = Op(usize) {
    nextFn = steps_next_fn,
};

 
pub fn step_pos_next(op: *Op(usize), rand: *Random) usize {
    var self = @fieldParentPtr(StepPos, "nextFn", op);

    // TODO use the underlying step function next
    // TODO update the current structures position with the
    // next position

    return 0;
}

pub struct StepPos = Op(usize) {
    nextFn = step_pos_next,
    steps: Steps,

    pub fn init(steps: Steps) StepPos {
        return StepPos { nextFn = step_pos_next, steps = steps };
    }
};

// TODO capped StepPos that ends after a certain distance
// TODO split StepPos that takes a StepPos and a pair of sizes,
//   and returns pair positions perhaps
//
// TODO crossover ops
// TODO selection ops
 
