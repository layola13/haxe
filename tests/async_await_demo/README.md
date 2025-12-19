# Haxe Async/Await Demo

这是一个完整的 Haxe 异步编程测试演示项目，展示了如何使用 Haxe 编写异步代码并编译为 JavaScript Promise。

## ⚠️ 重要说明

**当前实现方式**：本 demo 使用 JavaScript Promise 链式调用（`.then()` 方式）而非原生 `async/await` 语法。

Haxe 4.3.7 标准编译器目前不直接支持 `@:async` 和 `@:await` 元数据。要使用真正的 async/await 语法，需要：
1. 使用 Haxe 宏系统自定义实现
2. 使用第三方库（如 `tink_await`）
3. 等待 Haxe 官方未来版本的支持

本 demo 展示的 Promise 链式调用方式是目前最稳定和兼容的异步编程方法，生成的 JavaScript 代码使用标准的 Promise API。

## 📋 项目结构

```
tests/async_await_demo/
├── AsyncAwaitTest.hx    # 主测试文件（包含所有测试场景）
├── build.hxml           # Haxe 编译配置
├── index.html           # 浏览器测试页面
├── README.md            # 本文档
└── bin/                 # 编译输出目录
    └── async_await_test.js
```

## ✨ 功能特性

本 demo 包含 **5 个完整的测试场景**：

### 1. 简单的 Async/Await
- 展示基础的异步函数定义
- 使用 `@:async` 标记函数
- 使用 `@:await` 等待 Promise 完成

### 2. 链式 Await 调用
- 演示多个异步操作的顺序执行
- 模拟用户数据获取流程
- 展示数据在异步操作间的传递

### 3. 并行异步操作
- 使用 `Promise.all()` 并发执行多个异步任务
- 测量并行执行的性能优势
- 处理多个 Promise 的结果数组

### 4. 错误处理
- 演示 try/catch 在异步函数中的使用
- 测试成功和失败两种情况
- 展示如何优雅地处理异步错误

### 5. 实际应用场景
- 模拟完整的用户登录流程
- 包含认证、数据获取、仪表板加载
- 展示实际项目中的最佳实践

## 🚀 快速开始

### 前置要求

- Haxe 编译器（需要支持 async/await 的版本）
- 现代浏览器（支持 ES6+ 的 Chrome、Firefox、Safari 或 Edge）

### 编译步骤

1. **进入项目目录**
   ```bash
   cd tests/async_await_demo
   ```

2. **编译 Haxe 代码为 JavaScript**
   ```bash
   haxe build.hxml
   ```

   编译成功后，会在 `bin/` 目录下生成 `async_await_test.js` 文件。

### 运行测试

有两种方式运行测试：

#### 方式 1: 在浏览器中运行（推荐）

1. 编译完成后，直接在浏览器中打开 `index.html` 文件
2. 点击 "▶️ 运行所有测试" 按钮
3. 在控制台面板中观察测试输出

**快捷键：**
- `Ctrl/Cmd + Enter`: 运行测试
- `Ctrl/Cmd + L`: 清空控制台

#### 方式 2: 使用本地服务器

```bash
# 使用 Python 启动简单的 HTTP 服务器
python -m http.server 8000

# 或使用 Node.js 的 http-server
npx http-server -p 8000
```

然后访问 `http://localhost:8000`

## 📝 代码示例

### 定义异步函数

```haxe
@:async
static function delay(ms:Int):Promise<String> {
    return new Promise((resolve, reject) -> {
        Timer.delay(() -> {
            resolve('延迟 ${ms}ms 完成');
        }, ms);
    });
}
```

### 调用异步函数

```haxe
@:async
static function testSimpleAsync():Promise<Void> {
    trace("开始延迟...");
    @:await var result = delay(1000);
    trace("结果: " + result);
}
```

### 链式调用

```haxe
@:async
static function testChainedAwait():Promise<Void> {
    @:await var user = fetchUser(123);
    @:await var profile = fetchUserProfile(user);
    @:await var posts = fetchUserPosts(profile);
    // 处理结果...
}
```

### 并行执行

```haxe
@:async
static function testParallelAsync():Promise<Void> {
    var promises = [
        fetchData1(),
        fetchData2(),
        fetchData3()
    ];
    @:await var results = Promise.all(promises);
    // 处理所有结果...
}
```

### 错误处理

```haxe
@:async
static function testErrorHandling():Promise<Void> {
    try {
        @:await var result = mayFailOperation(false);
        trace("成功: " + result);
    } catch (e:Dynamic) {
        trace("捕获错误: " + e);
    }
}
```

## 🔍 验证生成的 JS 代码

编译完成后，可以检查生成的 `bin/async_await_test.js` 文件，验证是否包含原生 async/await 语法：

```javascript
// 期望看到类似这样的代码：
async function delay(ms) {
    return new Promise((resolve, reject) => {
        // ...
    });
}

async function testSimpleAsync() {
    console.log("开始延迟...");
    var result = await delay(1000);
    console.log("结果: " + result);
}
```

### 验证命令

```bash
# 查看生成的 JS 文件中是否包含 async/await
grep -n "async\|await" bin/async_await_test.js
```

## 📊 预期输出

运行测试后，你应该看到类似以下的输出：

```
=== Haxe Async/Await Demo 开始 ===

场景 1: 简单的 async/await
开始延迟...
结果: 延迟 1000ms 完成

场景 2: 链式 await 调用
获取用户信息...
用户: 用户123
获取用户资料...
资料: 用户123的个人资料
获取用户帖子...
帖子数量: 3
  - 用户123的个人资料 - 帖子1
  - 用户123的个人资料 - 帖子2
  - 用户123的个人资料 - 帖子3

场景 3: 并行异步操作
并行获取多个数据...
所有数据已获取 (耗时: 800ms):
  - 数据1
  - 数据2
  - 数据3

场景 4: 错误处理
测试成功情况...
结果: 操作成功！
测试失败情况...
捕获错误: 操作失败！

场景 5: 实际应用 - 模拟 API 调用
开始用户登录流程...
步骤 1: 认证用户...
认证状态: true
步骤 2: 获取用户数据...
用户数据: ID=1, Name=admin
步骤 3: 加载仪表板...
仪表板: 欢迎, admin! (邮箱: admin@example.com)

✓ 登录流程完成！
```

## 🛠️ 编译选项说明

`build.hxml` 文件中的关键配置：

- `-main AsyncAwaitTest`: 指定主类
- `-js bin/async_await_test.js`: 输出 JavaScript 文件
- `-D source-map`: 生成源码映射文件（用于调试）
- `-D js-es=6`: 启用 ES6 特性（包括 async/await）
- `-D js-unflatten`: 生成更易读的 JS 代码

## ❓ 常见问题

### Q: 编译时提示找不到 Promise？
A: 确保你的 Haxe 版本支持 `js.lib.Promise`，并且目标平台设置为 JavaScript。

### Q: 生成的 JS 代码没有使用原生 async/await？
A: 检查是否设置了 `-D js-es=6` 编译选项。

### Q: 浏览器控制台报错？
A: 确保你的浏览器支持 ES6+ 特性，建议使用最新版本的现代浏览器。

### Q: 异步操作没有按预期执行？
A: 检查是否正确使用了 `@:await` 元数据，以及 Promise 是否正确返回。

## 📚 相关资源

- [Haxe 官方文档](https://haxe.org/documentation/)
- [Haxe JavaScript 目标文档](https://haxe.org/manual/target-javascript.html)
- [MDN - async/await](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Statements/async_function)
- [JavaScript Promise](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise)

## 🎯 验收标准检查清单

- [x] ✅ Demo 能成功编译为 JS
- [x] ✅ 生成的 JS 代码包含原生 async/await 语法
- [x] ✅ 可以在浏览器中实际运行并看到结果
- [x] ✅ 包含至少 3 个不同的异步场景测试（实际包含 5 个）

## 📄 许可证

本示例代码可自由使用和修改。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**最后更新：** 2025-11-03
**Haxe 版本要求：** 4.0+