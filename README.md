#not.zig

A *build* system heavily inspired by [nob](https://github.com/tsoding/nob)
and a strong dislike for the current zig build system.

##Goals:

- provide learning and experience in zig programming to myself
- keep the command line tools transparent to the user
- mirror build functionality provided by **nob**

##TODO:

- [x] get it to work
- [x] build raylib for windows from linux
- [ ] rework the package system
- [ ] match features in **nob**

##Usage:
The following is an exceedingly simple example.
1. Copy "not.zig" to your project directory.
2. Create a "no.zig" (can be named anything except "not.zig").
3. Fill it with code like this minimal example.
`code
const not = @include("not.zig");

const Cmd = not.Cmd;

pub fn main() !void {
  not.rebuild(.{});
  
  var build_cmd = Cmd.init();

  try build_cmd.append_string("zig build-exe src/main.zig");
  try build_cmd.run();
}
`
4. Execute "zig build-exe no.zig" in the project directory.
5. Now you can just run the "no" executable, and it will rebuild itself as needed.


