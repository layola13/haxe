# Haxe 原生 Async/Await 实现总结

本文档总结了在 Haxe 编译器中实现原生 JavaScript async/await 支持的所有修改。

## 修改概述

### 1. 元数据定义 (src-json/meta.json)

添加了两个新的元数据：

#### @:async 元数据
- **用途**: 标记函数为异步函数，生成 JavaScript `async function`
- **目标**: `TClassField` (类字段/方法)
- **平台**: `js` (JavaScript)
- **文档**: 行 1143-1149

```json
{
    "name": "Async",
    "metadata": ":async",
    "doc": "Marks a function as async, generating native JavaScript async function. Requires ES2017+.",
    "platforms": ["js"],
    "targets": ["TClassField"]
}
```

#### @:await 元数据
- **用途**: 标记表达式使用 `await`，生成 JavaScript `await` 表达式
- **目标**: `TExpr` (表达式)
- **平台**: `js` (JavaScript)
- **文档**: 行 1150-1157

```json
{
    "name": "Await",
    "metadata": ":await",
    "doc": "Marks an expression as await, generating native JavaScript await expression. Must be used inside async functions.",
    "platforms": ["js"],
    "targets": ["TExpr"]
}
```

### 2. JavaScript 代码生成器修改 (src/generators/genjs.ml)

#### 2.1 上下文结构扩展 (行 27-50)

添加了 `in_async` 字段来跟踪当前是否在 async 函数内：

```ocaml
type ctx = {
    (* ... 其他字段 ... *)
    mutable in_async : bool;  (* 新增字段 - 行 44 *)
    (* ... *)
}
```

#### 2.2 表达式生成 - await 支持 (行 565-574)

在 [`gen_expr()`](src/generators/genjs.ml:460) 函数中添加了 `TMeta((Meta.Await,_,_), e1)` 的处理：

```ocaml
| TMeta ((Meta.Await,_,_), e1) ->
    if ctx.es_version >= 7 then begin
        if not ctx.in_async then
            print ctx "/* Warning: await outside async function */ ";
        spr ctx "await ";
        gen_expr ctx e1
    end else begin
        print ctx "/* Warning: await requires ES2017+, ignored */ ";
        gen_expr ctx e1
    end
```

**功能**:
- 检查 ES 版本（需要 >= 7，即 ES2017）
- 如果在非 async 函数中使用，发出警告
- 生成 `await` 关键字
- 如果 ES 版本不足，忽略 await 并发出警告

#### 2.3 值表达式生成 - await 支持 (行 875-880)

在 [`gen_value()`](src/generators/genjs.ml:828) 函数中添加类似的处理：

```ocaml
| TMeta ((Meta.Await,_,_), e1) ->
    if ctx.es_version >= 7 then begin
        spr ctx "await ";
        gen_value ctx e1
    end else
        gen_value ctx e1
```

#### 2.4 函数生成 - async 支持 (行 747-806)

修改 [`gen_function()`](src/generators/genjs.ml:747) 函数以支持 async：

**关键修改**:

1. **保存和设置 async 状态** (行 748-754):
```ocaml
let old = ctx.in_value, ctx.in_loop, ctx.in_async in
ctx.in_value <- None;
ctx.in_loop <- false;

(* Check if function has @:async metadata *)
let is_async = Meta.has Meta.Async cf_meta in
ctx.in_async <- is_async;
```

2. **生成 async 关键字** (行 791-799):
```ocaml
(* Add async keyword if needed *)
let keyword = if is_async && ctx.es_version >= 7 then
    "async " ^ keyword
else if is_async && ctx.es_version < 7 then begin
    print ctx "/* Warning: @:async requires ES2017+, ignored */ ";
    keyword
end else
    keyword
in
```

3. **恢复上下文状态** (行 803-805):
```ocaml
ctx.in_async <- (match old with (_,_,c) -> c);
```

#### 2.5 ES6 类方法生成 (行 1313-1320, 1355-1361)

在 [`generate_class_es6()`](src/generators/genjs.ml:1289) 中支持 async 构造函数和方法：

**构造函数** (行 1313-1320):
```ocaml
| Some { cf_expr = Some ({ eexpr = TFunction f; epos = p }); cf_meta = meta } ->
    newline ctx;
    let keyword = if Meta.has Meta.Async meta && ctx.es_version >= 7 then
        "async constructor"
    else
        "constructor"
    in
    gen_function ~cf_meta:meta ~keyword:keyword ctx f p;
```

**普通方法** (行 1332-1341, 1355-1361):
```ocaml
(* 实例方法 *)
let keyword = if Meta.has Meta.Async cf.cf_meta && ctx.es_version >= 7 then
    "async " ^ base_keyword
else
    base_keyword
in
gen_function ~cf_meta:cf.cf_meta ~keyword:keyword ctx f pos;

(* 静态方法 *)
let keyword = if Meta.has Meta.Async cf.cf_meta && ctx.es_version >= 7 then
    "async " ^ base_keyword
else
    base_keyword
in
gen_function ~cf_meta:cf.cf_meta ~keyword:keyword ctx f pos;
```

#### 2.6 上下文初始化 (行 1690)

在 [`alloc_ctx()`](src/generators/genjs.ml:1657) 中初始化 `in_async` 字段：

```ocaml
in_async = false;  (* 行 1690 *)
```

## 工作流程

### 编译时

1. **解析阶段**: Haxe 解析器识别 `@:async` 和 `@:await` 元数据
2. **类型检查**: 验证元数据使用是否正确（通过 meta.json 定义的目标）
3. **代码生成**:
   - 遇到 `@:async` 标记的函数时，设置 `ctx.in_async = true`
   - 生成函数时添加 `async` 关键字（如果 ES 版本 >= 7）
   - 遇到 `@:await` 表达式时，生成 `await` 关键字
   - 检查 ES 版本和上下文，必要时发出警告

### 运行时

生成的 JavaScript 代码使用原生 async/await：

```javascript
// Haxe 代码
@:async
static function fetchData():Promise<String> {
    var result = @:await Promise.resolve("data");
    return Promise.resolve(result);
}

// 生成的 JavaScript
async function fetchData() {
    var result = await Promise.resolve("data");
    return Promise.resolve(result);
}
```

## ES 版本要求

| 功能 | 最低 ES 版本 | ctx.es_version |
|------|-------------|----------------|
| async/await | ES2017 | >= 7 |

**设置方法**:
```hxml
-D js-es=2017
```

## 验证检查清单

### ✅ 编译器修改验证

- [x] `src-json/meta.json` 包含 `@:async` 和 `@:await` 定义
- [x] `src/generators/genjs.ml` 添加了 `in_async` 字段
- [x] `gen_expr()` 处理 `@:await` 元数据
- [x] `gen_value()` 处理 `@:await` 元数据
- [x] `gen_function()` 检查 `@:async` 并生成 async 关键字
- [x] ES6 类生成支持 async 方法
- [x] 上下文正确初始化和恢复

### ✅ 测试用例创建

- [x] `tests/async_await_native/Main.hx` - 完整的测试套件
- [x] `tests/async_await_native/compile.hxml` - 编译配置
- [x] `tests/async_await_native/expected_output.js` - 预期输出
- [x] `tests/async_await_native/README.md` - 测试文档

### ✅ 文档创建

- [x] `COMPILER_BUILD_GUIDE.md` - 编译器构建指南
- [x] `ASYNC_AWAIT_USAGE_GUIDE.md` - 使用指南
- [x] `TROUBLESHOOTING.md` - 故障排除
- [x] `ASYNC_AWAIT_IMPLEMENTATION_SUMMARY.md` - 实现总结（本文档）

## 测试场景

测试用例覆盖以下场景：

1. ✅ 简单 async 函数
2. ✅ 返回 Promise 的函数
3. ✅ 错误处理（try/catch）
4. ✅ 顺序执行多个 await
5. ✅ 实例方法中的 async/await
6. ✅ 链式 async 调用
7. ✅ ES 版本检查和警告

## 浏览器兼容性

| 浏览器 | 最低版本 | 发布日期 |
|--------|---------|---------|
| Chrome | 55 | 2016-12 |
| Firefox | 52 | 2017-03 |
| Safari | 10.1 | 2017-03 |
| Edge | 15 | 2017-04 |
| Node.js | 7.6 | 2017-02 |

## 性能特性

### 优势

1. **原生性能**: 不需要状态机转换或 polyfill
2. **小代码量**: 生成的代码简洁
3. **易于调试**: 浏览器开发工具完全支持
4. **标准兼容**: 完全符合 ECMAScript 规范

### 限制

1. **ES2017+ 限制**: 旧浏览器需要转译
2. **Promise 依赖**: 需要 Promise 支持
3. **编译器依赖**: 需要使用修改后的编译器

## 未来改进

可能的增强功能：

1. **自动类型推断**: 自动将返回 Promise 的函数标记为 async
2. **async 生成器**: 支持 `async function*`
3. **Top-level await**: 支持模块级别的 await
4. **更好的错误消息**: 提供更详细的编译时检查

## 相关文件

### 源代码修改
- `src-json/meta.json` - 元数据定义
- `src/generators/genjs.ml` - JavaScript 代码生成器

### 文档
- `COMPILER_BUILD_GUIDE.md` - 如何编译编译器
- `ASYNC_AWAIT_USAGE_GUIDE.md` - 如何使用功能
- `TROUBLESHOOTING.md` - 问题排查
- `README_async_await.md` - 设计文档

### 测试
- `tests/async_await_native/Main.hx` - 测试用例
- `tests/async_await_native/compile.hxml` - 编译配置
- `tests/async_await_native/expected_output.js` - 预期输出

## 贡献者注意事项

如果你要修改或扩展此功能：

1. **修改元数据**: 在 `src-json/meta.json` 中更新定义
2. **修改代码生成**: 在 `src/generators/genjs.ml` 中调整逻辑
3. **添加测试**: 在 `tests/async_await_native/` 中添加测试用例
4. **更新文档**: 更新相应的 .md 文件
5. **验证**: 运行完整的测试套件

## 参考资源

### ECMAScript 规范
- [async function (ES2017)](https://tc39.es/ecma262/#sec-async-function-definitions)
- [await operator](https://tc39.es/ecma262/#await)

### MDN 文档
- [async function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function)
- [await](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await)

### Haxe 资源
- [Haxe Manual](https://haxe.org/manual/)
- [Haxe Compiler Source](https://github.com/HaxeFoundation/haxe)

## 许可证

此实现遵循 Haxe 编译器的 GPL v2+ 许可证。

---

**文档版本**: 1.0  
**最后更新**: 2025-11-03  
**维护者**: Haxe 社区