# CDP 消息日志指南

## 已添加的日志

### 1. 接收 CDP 消息日志

**文件**：`src/cdp/cdp.zig` 第 109-110 行

```zig
pub fn processMessage(self: *Self, msg: []const u8) !void {
    // Log incoming CDP message
    log.info(.cdp, "CDP received", .{ .message = msg });
    
    const arena = &self.message_arena;
    defer _ = arena.reset(.{ .retain_with_limit = 1024 * 16 });
    return self.dispatch(arena.allocator(), self, msg);
}
```

### 2. 发送 CDP 消息日志

**文件**：`src/cdp/cdp.zig` 第 283-296 行

```zig
pub fn sendJSON(self: *Self, message: anytype) !void {
    // Log outgoing CDP message (before sending)
    const json_str = json.stringifyAlloc(self.allocator, message, .{
        .emit_null_optional_fields = false,
    }) catch "[JSON stringify error]";
    defer if (!std.mem.eql(u8, json_str, "[JSON stringify error]")) {
        self.allocator.free(json_str);
    };
    log.info(.cdp, "CDP sending", .{ .message = json_str });
    
    return self.client.sendJSON(message, .{
        .emit_null_optional_fields = false,
    });
}
```

---

## 使用方法

### 启动服务器并查看日志

```bash
./lightpanda serve --host 127.0.0.1 --port 9222 --log_level info
```

**注意**：必须设置 `--log_level info` 或更详细的级别（如 `debug`）才能看到日志。

### 日志输出示例

```
info(cdp): CDP received: {"id":1,"method":"Target.setAutoAttach","params":{"autoAttach":true,"waitForDebuggerOnStart":false}}
info(cdp): CDP sending: {"id":1,"result":{}}
info(cdp): CDP sending: {"method":"Target.attachedToTarget","params":{"sessionId":"STARTUP","targetInfo":{"type":"page","targetId":"TID-STARTUP-P","title":"New Private Tab","url":"chrome://newtab/","browserContextId":"BID-STARTUP"}}}
info(cdp): CDP received: {"id":2,"method":"Page.getFrameTree","sessionId":"STARTUP"}
info(cdp): CDP sending: {"id":2,"result":{}}
info(cdp): CDP received: {"id":3,"method":"Target.createTarget","params":{"url":"https://example.com"}}
info(cdp): CDP sending: {"id":3,"result":{"targetId":"TID-0"}}
info(cdp): CDP received: {"id":4,"method":"Page.navigate","params":{"url":"https://example.com"},"sessionId":"SID-0"}
info(cdp): CDP sending: {"id":4,"result":{"frameId":"TID-0","loaderId":"LID-0"}}
info(cdp): CDP sending: {"method":"Page.frameStartedLoading","params":{"frameId":"TID-0"}}
```

---

## 日志级别控制

### 所有可用的日志级别

```bash
--log_level debug    # 最详细（包括 debug、info、warn、err）
--log_level info     # 信息级别（包括 info、warn、err）
--log_level warn     # 警告级别（包括 warn、err）
--log_level err      # 仅错误
```

### 只查看 CDP 相关日志

使用日志作用域过滤：

```bash
./lightpanda serve --log_level debug --log_filter_scopes cdp
```

这样只会显示 `cdp` 作用域的日志。

### 查看所有日志

```bash
./lightpanda serve --log_level debug
```

会显示所有作用域的日志：
- `cdp` - CDP 协议相关
- `http` - HTTP 请求
- `browser` - 浏览器核心
- `web_api` - Web API 调用
- `app` - 应用程序
- 等等...

---

## 日志格式

### 默认格式（结构化）

```
info(cdp): CDP received: {"id":1,"method":"Page.getFrameTree"}
```

格式：`level(scope): message: details`

### JSON 格式（适合机器解析）

```bash
./lightpanda serve --log_format json
```

输出：
```json
{"level":"info","scope":"cdp","message":"CDP received","data":{"message":"{\"id\":1,\"method\":\"Page.getFrameTree\"}"}}
{"level":"info","scope":"cdp","message":"CDP sending","data":{"message":"{\"id\":1,\"result\":{...}}"}}
```

---

## 实际使用示例

### 示例 1：调试 CDP 通信

```bash
# 终端 1：启动 lightpanda
./lightpanda serve --log_level info

# 终端 2：运行 Puppeteer 脚本
node your_script.js

# 在终端 1 中会看到所有 CDP 消息的收发
```

### 示例 2：保存日志到文件

```bash
./lightpanda serve --log_level info 2>&1 | tee cdp_log.txt
```

### 示例 3：只看 CDP 消息，过滤其他日志

```bash
./lightpanda serve --log_level info 2>&1 | grep "CDP"
```

输出：
```
info(cdp): CDP received: {"id":1,...}
info(cdp): CDP sending: {"id":1,...}
info(cdp): CDP received: {"id":2,...}
info(cdp): CDP sending: {"id":2,...}
```

### 示例 4：美化 JSON 输出（使用 jq）

```bash
# 提取并美化 CDP 消息
./lightpanda serve --log_level info 2>&1 | \
  grep "CDP received" | \
  sed 's/.*CDP received: //' | \
  jq .
```

---

## 在 Docker 中使用

### Dockerfile 已配置日志级别

当前 Dockerfile 的 CMD：
```dockerfile
CMD ["/bin/lightpanda", "serve", "--host", "0.0.0.0", "--port", "9222", "--log_level", "info"]
```

已经设置了 `--log_level info`，所以 CDP 日志会自动输出。

### 查看 Docker 容器日志

```bash
# 运行容器
docker run -d --name lightpanda -p 9222:9222 lightpanda-browser

# 查看日志（包括 CDP 消息）
docker logs -f lightpanda

# 输出示例：
# info(cdp): CDP received: {"id":1,"method":"Page.getFrameTree"}
# info(cdp): CDP sending: {"id":1,"result":{"frameTree":{...}}}
```

### 修改 Docker 日志级别

如果需要更详细的日志：

```bash
docker run -d --name lightpanda -p 9222:9222 \
  lightpanda-browser \
  /bin/lightpanda serve --host 0.0.0.0 --port 9222 --log_level debug
```

或者修改 Dockerfile 的 CMD 行。

---

## 日志 Scope 列表

所有可用的日志作用域（在 `src/log.zig` 中定义）：

- `app` - 应用程序级别
- `cdp` - ⭐ CDP 协议消息
- `http` - HTTP 请求/响应
- `browser` - 浏览器核心逻辑
- `web_api` - Web API 调用
- `websocket` - WebSocket 连接
- `js` - JavaScript 执行
- 等等...

### 查看特定 scope

```bash
# 只看 cdp 和 http
./lightpanda serve --log_level debug --log_filter_scopes cdp,http
```

---

## 性能考虑

### 日志对性能的影响

发送日志使用了 `json.stringifyAlloc`，会有一定的开销：

```zig
const json_str = json.stringifyAlloc(self.allocator, message, .{
    .emit_null_optional_fields = false,
}) catch "[JSON stringify error]";
```

**影响**：
- ⚠️ 每条发送的 CDP 消息都会序列化两次（一次用于日志，一次用于发送）
- ⚠️ 高频 CDP 消息（如 Network 事件）可能影响性能

### 优化建议

#### 选项 1：使用 debug 级别（推荐）

将发送日志改为 debug 级别：

```zig
log.debug(.cdp, "CDP sending", .{ .message = json_str });
```

然后：
- 开发/调试时：`--log_level debug`（看到日志）
- 生产环境：`--log_level info`（不会序列化，性能更好）

#### 选项 2：条件日志

只在需要时才序列化：

```zig
pub fn sendJSON(self: *Self, message: anytype) !void {
    // 只在 info 级别或更详细时才记录
    if (log.opts.level.asInt() <= log.Level.info.asInt()) {
        const json_str = json.stringifyAlloc(self.allocator, message, .{
            .emit_null_optional_fields = false,
        }) catch "[JSON stringify error]";
        defer if (!std.mem.eql(u8, json_str, "[JSON stringify error]")) {
            self.allocator.free(json_str);
        };
        log.info(.cdp, "CDP sending", .{ .message = json_str });
    }
    
    return self.client.sendJSON(message, .{
        .emit_null_optional_fields = false,
    });
}
```

#### 选项 3：简化日志（不序列化完整 JSON）

只记录方法名和 ID：

```zig
// 接收
log.info(.cdp, "CDP received", .{ .method = input.method, .id = input.id });

// 发送（需要根据消息类型提取）
log.info(.cdp, "CDP sending", .{ .type = "result", .id = message.id });
```

---

## 日志输出格式定制

### 当前输出格式

```
info(cdp): CDP received: {"id":1,"method":"Page.getFrameTree","sessionId":"STARTUP"}
info(cdp): CDP sending: {"id":1,"result":{"frameTree":{"frame":{...}}}}
```

### 自定义格式（修改 src/log.zig）

可以在 `src/log.zig` 中定制日志输出格式。

---

## 完整测试示例

### 测试脚本

```javascript
// test_cdp_logging.js
const CDP = require('chrome-remote-interface');

async function test() {
  console.log('连接到 Lightpanda...');
  const client = await CDP({ port: 9222 });
  
  console.log('\n发送 Page.getFrameTree...');
  const result = await client.send('Page.getFrameTree', {}, 'STARTUP');
  
  console.log('\n收到响应：');
  console.log(JSON.stringify(result, null, 2));
  
  await client.close();
}

test().catch(console.error);
```

### 运行测试

```bash
# 终端 1：启动 lightpanda（会看到日志）
./lightpanda serve --log_level info

# 终端 2：运行测试
node test_cdp_logging.js
```

### 预期输出（终端 1）

```
info(websocket): starting blocking worker to listen on 127.0.0.1:9222
info(server): accepting new conn...
info(cdp): CDP received: {"id":1,"method":"Target.setAutoAttach","params":{"autoAttach":true,"waitForDebuggerOnStart":false}}
info(cdp): CDP sending: {"id":1,"result":{}}
info(cdp): CDP sending: {"method":"Target.attachedToTarget","params":{...}}
info(cdp): CDP received: {"id":2,"method":"Page.getFrameTree","sessionId":"STARTUP"}
info(cdp): CDP sending: {"id":2,"result":{}}
```

---

## 修改建议（可选）

如果您觉得 info 日志太多，可以改为 debug 级别：

### 方案 A：改为 debug 级别

```zig
// 接收
log.debug(.cdp, "CDP received", .{ .message = msg });

// 发送
log.debug(.cdp, "CDP sending", .{ .message = json_str });
```

然后使用 `--log_level debug` 查看，生产环境用 `--log_level info` 就看不到了。

### 方案 B：添加编译时开关

在 `build.zig` 中添加选项：

```zig
const enable_cdp_logging = b.option(bool, "enable_cdp_logging", "Enable CDP message logging") orelse false;
opts.addOption(bool, "enable_cdp_logging", enable_cdp_logging);
```

然后在代码中：

```zig
const config = @import("build_config");

pub fn sendJSON(self: *Self, message: anytype) !void {
    if (config.enable_cdp_logging) {
        const json_str = json.stringifyAlloc(...);
        defer self.allocator.free(json_str);
        log.info(.cdp, "CDP sending", .{ .message = json_str });
    }
    
    return self.client.sendJSON(message, .{
        .emit_null_optional_fields = false,
    });
}
```

编译时控制：
```bash
# 启用日志
zig build -Denable_cdp_logging=true

# 禁用日志（更高性能）
zig build -Denable_cdp_logging=false
```

---

## 总结

### ✅ 已实现

1. **接收日志**：`src/cdp/cdp.zig:110`
   - 每次收到 CDP 消息时打印
   - 格式：`info(cdp): CDP received: <JSON>`

2. **发送日志**：`src/cdp/cdp.zig:291`
   - 每次发送 CDP 消息时打印
   - 格式：`info(cdp): CDP sending: <JSON>`

### 🎯 使用方法

```bash
# 查看 CDP 日志
./lightpanda serve --log_level info

# 只看 CDP，不看其他日志
./lightpanda serve --log_level info --log_filter_scopes cdp

# 保存日志到文件
./lightpanda serve --log_level info 2>&1 | tee cdp.log
```

### 📊 性能影响

- ⚠️ 发送日志会序列化 JSON，有一定开销
- ✅ 可以通过日志级别控制
- ✅ 可以改为 debug 级别减少生产影响

现在您可以完整地追踪所有 CDP 消息的收发了！🎉

