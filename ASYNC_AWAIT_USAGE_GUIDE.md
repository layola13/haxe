# Haxe 原生 Async/Await 使用指南

本指南详细说明如何在 Haxe 中使用原生 JavaScript async/await 功能。

## 目录

1. [概述](#概述)
2. [前提条件](#前提条件)
3. [基本用法](#基本用法)
4. [高级用法](#高级用法)
5. [最佳实践](#最佳实践)
6. [常见模式](#常见模式)
7. [性能考虑](#性能考虑)
8. [与其他异步方案对比](#与其他异步方案对比)

## 概述

Haxe 现在支持通过 `@:async` 和 `@:await` 元数据直接生成原生 JavaScript async/await 代码，而不需要转换为状态机或使用 Promise 链。

### 优势

- ✅ **原生性能**: 直接生成浏览器/Node.js 原生 async/await
- ✅ **代码可读性**: 同步风格编写异步代码
- ✅ **错误处理**: 使用标准的 try/catch
- ✅ **调试友好**: 浏览器开发工具完全支持
- ✅ **互操作性**: 与现有 JavaScript Promise 生态系统无缝集成

### 要求

- Haxe 编译器: 使用本仓库重新编译的版本
- JavaScript 目标: ES2017+ (`-D js-es=2017`)
- 浏览器支持: Chrome 55+, Firefox 52+, Safari 10.1+, Edge 15+
- Node.js: 版本 7.6+

## 前提条件

### 1. 编译器配置

在 `.hxml` 文件中添加：

```hxml
# 启用 ES2017+ 支持
-D js-es=2017

# 或更高版本
# -D js-es=2018
# -D js-es=2019
# -D js-es=2020
```

### 2. 导入必要的类型

```haxe
import js.lib.Promise;
import js.lib.Error;
```

## 基本用法

### 1. 声明 Async 函数

使用 `@:async` 元数据标记函数：

```haxe
class MyClass {
    @:async
    static function fetchData():Promise<String> {
        // 函数体
        return Promise.resolve("数据");
    }
}
```

**生成的 JavaScript:**
```javascript
async function fetchData() {
    return Promise.resolve("数据");
}
```

### 2. 使用 Await

使用 `@:await` 元数据等待 Promise：

```haxe
@:async
static function getData():Promise<String> {
    var result = @:await Promise.resolve("Hello");
    return Promise.resolve(result);
}
```

**生成的 JavaScript:**
```javascript
async function getData() {
    var result = await Promise.resolve("Hello");
    return Promise.resolve(result);
}
```

### 3. 完整示例

```haxe
class AsyncExample {
    @:async
    static function fetchUserData(userId:Int):Promise<User> {
        // 获取用户信息
        var userInfo = @:await apiCall('/users/$userId');
        
        // 获取用户帖子
        var posts = @:await apiCall('/users/$userId/posts');
        
        // 组合数据
        var user = new User(userInfo, posts);
        return Promise.resolve(user);
    }
    
    @:async
    static function apiCall(url:String):Promise<Dynamic> {
        // 模拟 API 调用
        return js.Browser.window.fetch(url)
            .then(function(response) return response.json());
    }
}
```

## 高级用法

### 1. 错误处理

#### Try/Catch 方式

```haxe
@:async
static function fetchWithErrorHandling():Promise<String> {
    try {
        var data = @:await riskyOperation();
        return Promise.resolve(data);
    } catch (e:Error) {
        trace('错误: ${e.message}');
        return Promise.reject(e);
    }
}
```

#### Promise.catch 方式

```haxe
@:async
static function fetchWithCatch():Promise<String> {
    var promise = riskyOperation().catchError(function(e:Error) {
        trace('捕获错误: ${e.message}');
        return Promise.resolve("默认值");
    });
    
    var result = @:await promise;
    return Promise.resolve(result);
}
```

### 2. 并行执行

```haxe
@:async
static function parallelFetch():Promise<Array<String>> {
    // 创建多个 Promise
    var promise1 = fetchData("url1");
    var promise2 = fetchData("url2");
    var promise3 = fetchData("url3");
    
    // 并行等待所有 Promise
    var results = @:await Promise.all([promise1, promise2, promise3]);
    
    return Promise.resolve(results);
}
```

### 3. 条件 Await

```haxe
@:async
static function conditionalAsync(useCache:Bool):Promise<String> {
    var data:String;
    
    if (useCache) {
        data = getFromCache();
    } else {
        data = @:await fetchFromServer();
    }
    
    return Promise.resolve(data);
}
```

### 4. 循环中的 Await

```haxe
@:async
static function sequentialFetch(urls:Array<String>):Promise<Array<String>> {
    var results = [];
    
    for (url in urls) {
        var data = @:await fetchData(url);
        results.push(data);
        trace('已获取: $url');
    }
    
    return Promise.resolve(results);
}
```

### 5. 类方法中使用

```haxe
class DataManager {
    var cache:Map<String, String>;
    
    public function new() {
        cache = new Map();
    }
    
    @:async
    public function getData(key:String):Promise<String> {
        if (cache.exists(key)) {
            return Promise.resolve(cache.get(key));
        }
        
        var data = @:await fetchFromAPI(key);
        cache.set(key, data);
        
        return Promise.resolve(data);
    }
    
    @:async
    function fetchFromAPI(key:String):Promise<String> {
        // API 调用逻辑
        return Promise.resolve("数据");
    }
}
```

## 最佳实践

### 1. 始终返回 Promise

```haxe
// ✅ 好
@:async
static function goodAsync():Promise<String> {
    var result = @:await someOperation();
    return Promise.resolve(result);
}

// ❌ 不好 - 没有返回 Promise
@:async
static function badAsync():Void {
    @:await someOperation();
}
```

### 2. 适当的错误处理

```haxe
// ✅ 好 - 处理错误
@:async
static function goodErrorHandling():Promise<String> {
    try {
        return @:await riskyOperation();
    } catch (e:Error) {
        trace('错误: ${e.message}');
        return Promise.resolve("默认值");
    }
}

// ⚠️ 注意 - 错误会传播
@:async
static function errorPropagation():Promise<String> {
    // 如果失败，Promise 会被拒绝
    return @:await riskyOperation();
}
```

### 3. 避免不必要的 Await

```haxe
// ❌ 不好 - 不必要的 await
@:async
static function unnecessary():Promise<String> {
    return @:await Promise.resolve("data");
}

// ✅ 好 - 直接返回 Promise
static function better():Promise<String> {
    return Promise.resolve("data");
}
```

### 4. 合理使用并行执行

```haxe
// ❌ 不好 - 串行执行（慢）
@:async
static function sequential():Promise<Array<String>> {
    var result1 = @:await fetch("url1");
    var result2 = @:await fetch("url2");
    var result3 = @:await fetch("url3");
    return Promise.resolve([result1, result2, result3]);
}

// ✅ 好 - 并行执行（快）
@:async
static function parallel():Promise<Array<String>> {
    var promises = [
        fetch("url1"),
        fetch("url2"),
        fetch("url3")
    ];
    return @:await Promise.all(promises);
}
```

## 常见模式

### 1. 重试模式

```haxe
@:async
static function fetchWithRetry(url:String, maxRetries:Int = 3):Promise<String> {
    var lastError:Error = null;
    
    for (i in 0...maxRetries) {
        try {
            var result = @:await fetch(url);
            return Promise.resolve(result);
        } catch (e:Error) {
            lastError = e;
            trace('重试 ${i + 1}/$maxRetries');
            @:await delay(1000 * (i + 1)); // 指数退避
        }
    }
    
    return Promise.reject(lastError);
}

@:async
static function delay(ms:Int):Promise<Void> {
    return new Promise(function(resolve, reject) {
        js.Browser.window.setTimeout(resolve, ms);
    });
}
```

### 2. 超时模式

```haxe
@:async
static function fetchWithTimeout(url:String, timeoutMs:Int):Promise<String> {
    var timeoutPromise = new Promise(function(resolve, reject) {
        js.Browser.window.setTimeout(function() {
            reject(new Error("请求超时"));
        }, timeoutMs);
    });
    
    var fetchPromise = fetch(url);
    
    return @:await Promise.race([fetchPromise, timeoutPromise]);
}
```

### 3. 缓存模式

```haxe
class CachedFetcher {
    static var cache:Map<String, String> = new Map();
    
    @:async
    public static function fetchCached(url:String):Promise<String> {
        if (cache.exists(url)) {
            trace('缓存命中: $url');
            return Promise.resolve(cache.get(url));
        }
        
        trace('缓存未命中，正在获取: $url');
        var data = @:await fetch(url);
        cache.set(url, data);
        
        return Promise.resolve(data);
    }
}
```

### 4. 批量处理模式

```haxe
@:async
static function batchProcess(items:Array<String>, batchSize:Int = 5):Promise<Array<String>> {
    var results = [];
    
    for (i in 0...Math.ceil(items.length / batchSize)) {
        var batch = items.slice(i * batchSize, (i + 1) * batchSize);
        var batchPromises = batch.map(item -> processItem(item));
        var batchResults = @:await Promise.all(batchPromises);
        results = results.concat(batchResults);
        
        trace('已处理批次 ${i + 1}');
    }
    
    return Promise.resolve(results);
}
```

## 性能考虑

### 1. 并行 vs 串行

```haxe
// 串行: 总时间 = time1 + time2 + time3
@:async
static function serial():Promise<Void> {
    @:await operation1(); // 1秒
    @:await operation2(); // 1秒
    @:await operation3(); // 1秒
    // 总计: 3秒
    return Promise.resolve(null);
}

// 并行: 总时间 = max(time1, time2, time3)
@:async
static function parallel():Promise<Void> {
    @:await Promise.all([
        operation1(), // 1秒
        operation2(), // 1秒
        operation3()  // 1秒
    ]);
    // 总计: 1秒
    return Promise.resolve(null);
}
```

### 2. 避免过度使用 Await

```haxe
// ❌ 不必要的复杂度
@:async
static function overcomplex():Promise<Int> {
    var a = @:await Promise.resolve(1);
    var b = @:await Promise.resolve(2);
    var sum = @:await Promise.resolve(a + b);
    return Promise.resolve(sum);
}

// ✅ 简化版本
static function simple():Promise<Int> {
    return Promise.resolve(3);
}
```

## 与其他异步方案对比

### Haxe 原生 Async/Await vs Promise 链

```haxe
// Promise 链方式
static function promiseChain():Promise<String> {
    return fetchUser()
        .then(function(user) {
            return fetchPosts(user.id);
        })
        .then(function(posts) {
            return processPosts(posts);
        })
        .then(function(result) {
            return result;
        });
}

// Async/Await 方式 - 更清晰
@:async
static function asyncAwait():Promise<String> {
    var user = @:await fetchUser();
    var posts = @:await fetchPosts(user.id);
    var result = @:await processPosts(posts);
    return Promise.resolve(result);
}
```

### Haxe 原生 Async/Await vs 回调

```haxe
// 回调方式 - 回调地狱
static function callbackHell(callback:String->Void):Void {
    fetchData(function(data1) {
        processData(data1, function(data2) {
            validateData(data2, function(data3) {
                callback(data3);
            });
        });
    });
}

// Async/Await 方式 - 扁平结构
@:async
static function asyncFlat():Promise<String> {
    var data1 = @:await fetchData();
    var data2 = @:await processData(data1);
    var data3 = @:await validateData(data2);
    return Promise.resolve(data3);
}
```

## 调试技巧

### 1. 使用 console.log

```haxe
@:async
static function debugAsync():Promise<String> {
    trace("开始");
    var data = @:await fetchData();
    trace('获取到数据: $data');
    var processed = @:await processData(data);
    trace('处理完成: $processed');
    return Promise.resolve(processed);
}
```

### 2. 捕获和记录错误

```haxe
@:async
static function debugErrors():Promise<String> {
    try {
        var result = @:await riskyOperation();
        return Promise.resolve(result);
    } catch (e:Error) {
        trace('错误详情:');
        trace('  消息: ${e.message}');
        trace('  堆栈: ${e.stack}');
        return Promise.reject(e);
    }
}
```

## 浏览器兼容性

### 支持的浏览器

- Chrome 55+ (2016年12月)
- Firefox 52+ (2017年3月)
- Safari 10.1+ (2017年3月)
- Edge 15+ (2017年4月)
- Opera 42+ (2016年12月)

### Polyfill 方案

对于旧浏览器，使用 Babel 或类似工具转换：

```bash
# 使用 Babel 转换
npm install --save-dev @babel/core @babel/preset-env
babel main.js --out-file main-es5.js --presets=@babel/preset-env
```

## 下一步

- 查看 `tests/async_await_native/Main.hx` 获取更多示例
- 阅读 `TROUBLESHOOTING.md` 了解常见问题
- 参考 `expected_output.js` 查看生成的 JavaScript 代码

## 参考资源

- [MDN: async function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function)
- [MDN: await](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await)
- [JavaScript Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)