# Haxe TypeScript 编译目标实现指南

## 概述

本文档描述了为Haxe编译器添加TypeScript编译目标的完整实现过程。此实现允许将Haxe代码直接编译为TypeScript代码（.ts）和类型声明文件（.d.ts）。

## 实现状态

### ✅ 已完成的工作

1. **核心平台定义** (`src/core/globals.ml`)
   - 在平台枚举中添加了 `TypeScript`
   - 实现了平台名称映射和解析

2. **命令行接口** (`src/compiler/args.ml`)
   - 添加了 `--ts` 命令行参数
   - 用法: `haxe --ts output.ts --main Main`

3. **代码生成器骨架** (`src/generators/gents.ml`)
   - 完整的上下文类型定义
   - TypeScript关键字处理
   - 基本类型映射系统
   - 类和接口生成
   - 枚举生成（使用联合类型 + namespace）
   - 双缓冲区系统（主代码 + .d.ts）

4. **编译器集成** (`src/compiler/generate.ml`)
   - 在代码生成分发中注册TypeScript目标

5. **构建系统**
   - dune配置自动包含gents.ml

6. **设计文档**
   - 完整的架构设计 (`docs/typescript-target-design.md`)
   - 实现总结 (`docs/typescript-implementation-summary.md`)

### 🚧 待完成的工作

1. **表达式和语句生成**
   - 目前 `gen_expr` 和 `gen_value` 是占位符实现
   - 需要参考 `genjs.ml` 实现完整的表达式生成

2. **.d.ts 声明文件生成**
   - 需要从主缓冲区提取类型声明
   - 生成单独的 .d.ts 文件

3. **编译器编译和测试**
   - 重新编译Haxe编译器
   - 运行测试用例
   - 修复编译错误

4. **完善功能**
   - 处理特殊情况和边界条件
   - 优化生成的代码
   - 添加更多测试

## 架构设计

### 类型映射策略

```
Haxe类型          → TypeScript类型
─────────────────────────────────
Int, Float        → number
String            → string
Bool              → boolean
Void              → void
Dynamic           → any
Array<T>          → T[]
Null<T>           → T | null
Function          → (...args) => RetType
Class             → class
Interface         → interface
Enum              → type (union) + namespace
```

### 枚举转换示例

**Haxe代码:**
```haxe
enum Color {
    Red;
    RGB(r:Int, g:Int, b:Int);
}
```

**生成的TypeScript:**
```typescript
type Color = 
  | { readonly _tag: "Red" }
  | { readonly _tag: "RGB"; r: number; g: number; b: number };

namespace Color {
  export const Red: Color = { _tag: "Red" };
  export function RGB(r: number, g: number, b: number): Color {
    return { _tag: "RGB", r, g, b };
  }
}
```

## 代码结构

### gents.ml 主要组件

```ocaml
(* 上下文类型 *)
type ctx = {
  com : Common.context;
  buf : Buffer.t;                    (* 主代码缓冲区 *)
  dts_buf : Buffer.t;                (* .d.ts缓冲区 *)
  mutable ts_version : int;          (* TypeScript版本 *)
  mutable use_esm : bool;            (* 使用ES模块 *)
  (* ... 其他字段 *)
}

(* 核心函数 *)
val gen_type_hint : ctx -> Type.t -> string
val generate_class : ctx -> Type.tclass -> unit
val generate_enum : ctx -> Type.tenum -> unit
val generate : Common.context -> unit
```

## 使用方法

### 编译Haxe编译器

```bash
cd /root/Projects/haxe
make
# 或使用 dune
dune build
```

### 使用TypeScript目标

```bash
# 基本用法
./haxe --ts output.ts --main Main -cp src

# 指定TypeScript版本
./haxe --ts output.ts --main Main -D ts-version=5

# 使用ESM模块
./haxe --ts output.ts --main Main -D ts-module=esm

# 禁用.d.ts生成
./haxe --ts output.ts --main Main -D ts-no-dts

# 启用严格null检查
./haxe --ts output.ts --main Main -D ts-strict-null
```

### 与TypeScript编译器链接

```bash
# 1. Haxe → TypeScript
haxe --ts build/output.ts --main Main

# 2. TypeScript → JavaScript
tsc build/output.ts --outDir dist
```

## Define标志

以下自定义define标志可用于配置TypeScript输出：

| Define | 默认值 | 说明 |
|--------|--------|------|
| `ts-version` | 4 | TypeScript版本 (3-5) |
| `ts-module` | esm | 模块系统 (esm/commonjs) |
| `ts-decorators` | false | 启用装饰器 |
| `ts-namespaces` | true | 使用namespace |
| `ts-strict-null` | false | 严格null检查 |
| `ts-no-dts` | false | 禁用.d.ts生成 |

## 开发指南

### 添加新功能

1. **修改 gents.ml**
   - 在相应的生成函数中添加代码
   - 参考 genjs.ml 的实现

2. **测试**
   - 在 `tests/typescript/` 中添加测试用例
   - 重新编译Haxe
   - 运行测试

3. **文档**
   - 更新此文档
   - 添加代码注释

### 调试技巧

1. **查看生成的代码**
   ```bash
   haxe --ts test.ts --main Test
   cat test.ts
   ```

2. **启用详细输出**
   ```bash
   haxe --ts test.ts --main Test -v
   ```

3. **检查OCaml编译错误**
   ```bash
   dune build --verbose
   ```

## 已知限制

1. **表达式生成未完成**
   - 当前版本只生成类型定义
   - 函数体和表达式需要完善

2. **运行时库支持**
   - 某些Haxe特性可能需要运行时库
   - 考虑创建 `haxe-ts-runtime` 包

3. **标准库**
   - 可能需要TypeScript特定的标准库版本

4. **性能**
   - 大型项目可能需要优化
   - 考虑增量编译

## 测试用例

### HelloWorld.hx
```haxe
class HelloWorld {
    static function main() {
        trace("Hello TypeScript from Haxe!");
    }
}
```

编译:
```bash
haxe --ts hello.ts --main HelloWorld
```

### 更多测试用例

在 `tests/typescript/` 目录下创建更多测试:
- 类继承和接口实现
- 泛型类和方法
- 枚举和模式匹配
- 闭包和匿名函数
- 异步操作

## 参考资料

### 相关文件

- `src/generators/genjs.ml` - JavaScript生成器（主要参考）
- `src/generators/genlua.ml` - Lua生成器
- `src/generators/genpy.ml` - Python生成器
- `src/core/type.ml` - Haxe类型定义
- `src/typing/typer.ml` - 类型检查器

### 外部文档

- [TypeScript手册](https://www.typescriptlang.org/docs/)
- [Haxe手册](https://haxe.org/manual/)
- [OCaml文档](https://ocaml.org/docs/)

## 贡献

欢迎贡献！主要需要帮助的领域：

1. 完善表达式和语句生成
2. 实现.d.ts生成逻辑
3. 编写测试用例
4. 优化生成的代码
5. 文档改进

## 许可证

此实现遵循Haxe编译器的许可证（GPL 2.0或更高版本）。

## 联系方式

有问题或建议？请提交issue或pull request到Haxe仓库。

---

**最后更新**: 2025-10-17

**状态**: 🚧 开发中 - 核心框架已完成，表达式生成待实现