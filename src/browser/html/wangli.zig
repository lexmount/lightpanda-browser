const Page = @import("../page.zig").Page;

pub const Wangli = struct {
    pub fn get_msg(self: *Wangli, page: *Page) ![]const u8 {
        _ = page;
        _ = self;
        return "test_msg";
    }
};
