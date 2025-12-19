# Haxe JS 代码生成器 @async/@await 支持技术方案

## 1. 执行摘要

本文档详细分析了 Haxe 编译器的 JavaScript 代码生成器架构，并为添加原生 `@async`/`@await` 支持设计了完整的技术方案。该方案将允许 Haxe 代码通过元数据标记生成原生 JavaScript 的 async/await 语法，提供更好的异步编程支持。

## 2. 当前架构分析

### 2.1 关键文件列表

| 文件路径 | 作用 | 关键程度 |
|---------|------|---------|
| `src/generators/genjs.ml` | JS 代码生成器主文件（1965行） | ⭐⭐⭐⭐⭐ |
| `src/core/type.ml` | 类型系统定义 | ⭐⭐⭐⭐ |
| `src/core/meta.ml` | 元数据处理（158行） | ⭐⭐⭐⭐⭐ |
| `src/core/ast.ml` | AST 定义（1299行） | ⭐⭐⭐⭐ |
| `src-json/meta.json` | 元数据配置（1142行） | ⭐⭐⭐⭐ |
| `src/generators/gctx.ml` | 生成器上下文 | ⭐⭐⭐ |

### 2.2 JS 代码生成器结构分析

#### 2.2.1 核心上下文结构 (genjs.ml: 27-49)

```ocaml
type ctx = {
    com : Gctx.t;              (* 编译器上下文 *)
    buf : Rbuffer.t;            (* 输出缓冲区 *)
    es_version : int;           (* ECMAScript 版本 *)
    mutable current : tclass;   (* 当前类 *)
    (* ... 其他字段 *)
}
```

#### 2.2.2 函数生成路径 (genjs.ml: 736-778)

**关键函数**: `gen_function`
- **位置**: 第 736 行
- **功能**: 生成函数定义，包括参数处理和函数体
- **参数**: 
  - `keyword`: 函数关键字 (默认 "function")
  - `ctx`: 生成器上下文
  - `f`: 函数定义
  - `pos`: 位置信息

```ocaml
and gen_function ?(keyword="function") ctx f pos =
    let old = ctx.in_value, ctx.in_loop in
    ctx.in_value <- None;
    ctx.in_loop <- false;
    (* ... 参数处理 ... *)
    print ctx "%s(%s) " keyword (String.concat "," args);
    gen_expr ctx (fun_block ctx f pos);
```

#### 2.2.3 表达式生成 (genjs.ml: 459-733)

**关键函数**: `gen_expr` 和 `gen_value`
- 处理所有表达式类型的代码生成
- 使用模式匹配处理不同的表达式节点
- 支持的节点类型：TConst, TLocal, TArray, TBinop, TField, TCall, TFunction 等

#### 2.2.4 调用表达式生成 (genjs.ml: 317-425)

**关键函数**: `gen_call`
- 处理函数调用表达式
- 支持特殊语法如 `js.Syntax.code`
- 处理 super 调用、闭包调用等特殊情况

### 2.3 元数据处理机制

#### 2.3.1 元数据定义 (meta.json)

当前系统中有 141 个预定义元数据，包括：
- `@:inline`