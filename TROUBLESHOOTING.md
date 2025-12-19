# Haxe Async/Await 故障排除指南

本指南提供常见问题的解决方案和调试技巧。

## 目录

1. [编译错误](#编译错误)
2. [运行时错误](#运行时错误)
3. [生成的代码问题](#生成的代码问题)
4. [性能问题](#性能问题)
5. [浏览器兼容性](#浏览器兼容性)
6. [调试技巧](#调试技巧)

## 编译错误

### 错误 1：未识别的元数据

**错误信息**:
```
Warning : @:async is not a recognized metadata
Warning : @:await is not a recognized metadata
```

**原因**: 使用的是未修改的 Haxe 编译器

**解决方案**:
1. 确认你使用的是重新编译的编译器：
   ```bash
   haxe --version
   which haxe
   ```

2. 检查 `src-json/meta.json` 是否包含 `@:async` 和 `@:await` 定义

3. 重新编译 Haxe 编译器：
   ```bash
   cd /home/sonygod/projects/haxe
   make clean
   make
   ```

### 错误 2：ES 版本不足

**错误信息**:
```
/* Warning: @:async requires ES2017+, ignored */
/* Warning: await requires ES2017+, ignored */
```

**原因**: JavaScript ES 版本设置低于 ES2017

**解决方案**:
在 `.hxml` 文件中添加或修改：
```hxml
-D js-es=2017
```

或使用命令行：
```bash
haxe -main Main -js output.js -D js-es=2017
```

### 错误 3：在非 async 函数中使用 await

**错误信息**:
```
/* Warning: await outside async function */
```

**原因**: `@:await` 用在没有 `@:async` 标记的函数中

**解决方案**:
```haxe
// ❌ 错误
static function normalFunction():Void {
    var result = @:await somePromise(); // 警告！
}

// ✅ 正确
@:async
static function asyncFunction():Promise<Void> {
    var result = @:await somePromise(); // OK
    return Promise.resolve(null);
}
```

### 错误 4：返回类型不匹配

**错误信息**:
```
Type mismatch: expected Promise<T>, got T
```

**原因**: async 函数应该返回 Promise

**解决方案**:
```haxe
// ❌ 错误
@:async
static function badReturn():String {
    return "hello"; // 类型错误
}

// ✅ 正确
@:async
static function goodReturn():Promise<String> {
    return Promise.resolve("hello");
}
```

## 运行时错误

### 错误 5：未捕获的 Promise 拒绝

**错误信息**:
```
Uncaught (in promise) Error: ...
```

**原因**: Promise 被拒绝但没有错误处理

**解决方案**:

**方法 1: 使用 try/catch**
```haxe
@:async
static function withTryCatch():Promise<String> {
    try {
        var result = @:await riskyOperation();
        return Promise.resolve(result);
    } catch (e:js.lib.Error) {
        trace('错误: ${e.message}');
        return Promise.reject(e);
    }
}
```

**方法 2: 使用 .catchError()**
```haxe
@:async
static function withCatch():Promise<String> {
    return riskyOperation().catchError(function(e) {
        trace('错误: $e');
        return Promise.resolve("默认值");
    });
}
```

**方法 3: 全局错误处理**
```haxe
static function main() {
    js.Browser.window.addEventListener("unhandledrejection", function(event) {
        trace('未处理的 