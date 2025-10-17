
# Haxe TypeScript 编译目标设计文档

## 1. 概述

本文档描述为Haxe编译器添加TypeScript编译目标的架构设计。该目标将允许Haxe代码编译为原生TypeScript代码（.ts）和类型声明文件（.d.ts）。

## 2. 现有架构分析

### 2.1 Haxe编译器结构

基于对源码的分析，Haxe编译器的代码生成器架构如下：

```
src/
├── compiler/
│   ├── args.ml              # 命令行参数解析
│   ├── compiler.ml          # 编译器主逻辑
│   └── generate.ml          # 代码生成入口
├── generators/
│   ├── genjs.ml            # JavaScript生成器（参考实现）
│   ├── genlua.ml           # Lua生成器
│   ├── genpy.ml            # Python生成器
│   ├── genphp7.ml          # PHP生成器
│   ├── gencpp.ml           # C++生成器
│   ├── genjvm.ml           # JVM生成器
│   └── genshared.ml        # 共享代码生成工具
└── core/
    └── globals.ml          # 平台定义和全局类型
```

### 2.2 JavaScript生成器分析

JavaScript生成器（genjs.ml）是TypeScript生成器的最佳参考，因为：

1. **类型系统相似**：JavaScript和TypeScript都是动态类型语言
2. **语法接近**：TypeScript是JavaScript的超集
3. **特性支持**：ES6类、箭头函数、解构等现代特性
4. **代码组织**：包管理、模块系统类似

关键组件：
- `ctx` 类型：编译上下文，包含缓冲区、包管理、版本信息等
- `gen_expr`：表达式生成函数
- `gen_value`：值生成函数
- `generate_class_es6`/`generate_class_es3`：类生成（支持不同ES版本）
- `generate_enum`：枚举生成
- `generate_type`：类型生成入口

## 3. TypeScript目标设计

### 3.1 平台定义

在 `src/core/globals.ml` 中添加 TypeScript 平台：

```ocaml
type platform =
    | Cross
    | Js
    | Lua
    | Neko
    | Flash
    | Php
    | Cpp
    | Jvm
    | Python
    | Hl
    | Eval
    | TypeScript  (* 新增 *)
    | CustomTarget of string
```

### 3.2 命令行参数

在 `src/compiler/args.ml` 中添加 `--ts` 参数：

```ocaml
("Target",["--ts"],["-ts"],Arg.String (set_platform com TypeScript),
 "<file>","generate TypeScript code and .d.ts declaration file");
```

### 3.3 代码生成器结构

创建 `src/generators/gents.ml`，结构如下：

```ocaml
(* TypeScript代码生成器 *)

type ts_version = int  (* TypeScript版本：4, 5等 *)

type output_mode =
    | SingleFile      (* 单文件输出 *)
    | ModulePerClass  (* 每个类一个模块 *)
    | PackagePerDir   (* 按包目录组织 *)

type ctx = {
    com : Gctx.t;
    buf : Rbuffer.t;                    (* 主代码缓冲区 *)
    dts_buf : Rbuffer.t;                (* .d.ts声明文件缓冲区 *)
    mutable chan : out_channel option;
    mutable dts_chan : out_channel option;
    packages : (string list,unit) Hashtbl.t;
    ts_version : ts_version;
    output_mode : output_mode;
    emit_decorators : bool;              (* 是否生成装饰器 *)
    emit_namespaces : bool;              (* 是否使用namespace *)
    strict_null_checks : bool;           (* 严格null检查 *)
    mutable current : tclass;
    mutable tabs : string;
    mutable in_interface : bool;
    mutable type_params : (string * string list) list; (* 泛型参数映射 *)
}
```

### 3.4 类型映射

Haxe类型到TypeScript类型的映射：

| Haxe类型 | TypeScript类型 | 说明 |
|---------|---------------|------|
| Int | number | 整数 |
| Float | number | 浮点数 |
| Bool | boolean | 布尔值 |
| String | string | 字符串 |
| Void | void | 空类型 |
| Dynamic | any | 动态类型 |
| Null<T> | T \| null | 可空类型 |
| Array<T> | T[] 或 Array<T> | 数组 |
| Map<K,V> | Map<K,V> | 映射 |
| Class<T> | { new(...args: any[]): T } | 类类型 |
| Enum<T> | T | 枚举类型 |
| Abstract | type alias | 抽象类型 |
| Function | (...args) => RetType | 函数类型 |
| Rest<T> | ...T[] | 剩余参数 |
| {x:Int, y:Int} | {x: number, y: number} | 匿名结构 |

### 3.5 代码生成策略

#### 3.5.1 类生成

```typescript
// Haxe代码
class Point {
    public var x:Float;
    public var y:Float;
    
    public function new(x:Float, y:Float) {
        this.x = x;
        this.y = y;
    }
    
    public function distance():Float {
        return Math.sqrt(x * x + y * y);
    }
}

// 生成的TypeScript代码
export class Point {
    public x: number;
    public y: number;
    
    constructor(x: number, y: number) {
        this.x = x;
        this.y = y;
    }
    
    public distance(): number {
        return Math.sqrt(this.x * this.x + this.y * this.y);
    }
}

// 生成的.d.ts文件
export declare class Point {
    x: number;
    y: number;
    constructor(x: number, y: number);
    distance(): number;
}
```

#### 3.5.2 接口生成

```typescript
// Haxe接口
interface IDrawable {
    function draw():Void;
}

// 生成的TypeScript
export interface IDrawable {
    draw(): void;
}
```

#### 3.5.3 枚举生成

```typescript
// Haxe枚举
enum Color {
    Red;
    Green;
    Blue;
    RGB(r:Int, g:Int, b:Int);
}

// 生成的TypeScript（使用联合类型和接口）
export type Color = 
    | { readonly _tag: "Red" }
    | { readonly _tag: "Green" }
    | { readonly _tag: "Blue" }
    | { readonly _tag: "RGB"; r: number; g: number; b: number };

export namespace Color {
    export const Red: Color = { _tag: "Red" };
    export const Green: Color = { _tag: "Green" };
    export const Blue: Color = { _tag: "Blue" };
    export function RGB(r: number, g: number, b: number): Color {
        return { _tag: "RGB", r, g, b };
    }
}
```

#### 3.5.4 泛型生成

```typescript
// Haxe泛型类
class Container<T> {
    private var value:T;
    public function new(value:T) {
        this.value = value;
    }
    public function get():T {
        return value;
    }
}

// 生成的TypeScript
export class Container<T> {
    private value: T;
    
    constructor(value: T) {
        this.value = value;
    }
    
    public get(): T {
        return this.value;
    }
}
```

#### 3.5.5 抽象类型生成

```typescript
// Haxe抽象类型
abstract Meters(Float) {
    inline public function new(v:Float) {
        this = v;
    }
    
    @:op(A + B)
    public function add(other:Meters):Meters {
        return new Meters(this + other);
    }
}

// 生成的TypeScript
export type Meters = number;

export namespace Meters {
    export function create(v: number): Meters {
        return v;
    }
    
    export function add(a: Meters, b: Meters): Meters {
        return a + b;
    }
}
```

### 3.6 核心生成函数

```ocaml
(* 主要生成函数签名 *)

val generate : Gctx.t -> unit
(* 生成入口函数 *)

val gen_type : ctx -> module_type -> unit
(* 生成类型定义 *)

val gen_class : ctx -> tclass -> unit
(* 生成类 *)

val gen_interface : ctx -> tclass -> unit
(* 生成接口 *)

val gen_enum : ctx -> tenum -> unit
(* 生成枚举 *)

val gen_typedef : ctx -> tdef -> unit
(* 生成类型别名 *)

val gen_expr : ctx -> texpr -> unit
(* 生成表达式 *)

val gen_value : ctx -> texpr -> unit
(* 生成值表达式 *)

val gen_type_hint : ctx -> t -> unit
(* 生成TypeScript类型注解 *)

val gen_declaration : ctx -> module_type -> unit
(* 生成.d.ts声明 *)
```

## 4. 实现计划

### 4.1 阶段一：基础设施（1-2天）

1. 在 `globals.ml` 中添加 TypeScript 平台定义
2. 在 `args.ml` 中添加 `--ts` 命令行参数
3. 创建 `gents.ml` 骨架文件
4. 设置编译系统（dune文件）

### 4.2 阶段二：类型系统（2-3天）

1. 实现基本类型映射函数 `gen_type_hint`
2. 实现泛型参数处理
3. 实现可空类型处理
4. 实现函数类型生成

### 4.3 阶段三：类和接口（3-4天）

1. 实现类生成 `gen_class`
2. 实现接口生成 `gen_interface`
3. 实现继承和实现关系
4. 实现访问修饰符（public/private/protected）
5. 实现静态成员

### 4.4 阶段四：枚举和抽象（2-3天）

1. 实现枚举生成 `gen_enum`
2. 实现抽象类型生成
3. 实现枚举模式匹配辅助代码

### 4.5 阶段五：表达式和语句（3-4天）

1. 实现表达式生成 `gen_expr`
2. 实现值生成 `gen_value`
3. 实现控制流语句（if/while/for/switch）
4. 实现异常处理（try/catch）

### 4.6 阶段六：声明文件生成（2-3天）

1. 实现 .d.ts 文件生成
2. 实现声明合并
3. 实现外部类型声明

### 4.7 阶段七：测试和优化（3-5天）

1. 编写单元测试
2. 编写集成测试
3. 性能优化
4. 代码审查和重构

## 5. 配置选项

### 5.1 Define标志

- `-D ts-version=5`：指定TypeScript版本
- `-D ts-module=commonjs|esm`：模块系统
- `-D ts-decorators`：启用装饰器
- `-D ts-namespaces`：使用namespace而不是module
- `-D ts-strict-null`：严格null检查
- `-D ts-no-dts`：不生成.d.ts文件

### 5.2 编译选项示例

```bash
# 基本用法
haxe --ts output.ts --main Main

# 指定TypeScript版本和模块系统
haxe --ts output.ts --main Main -D ts-version=5 -D ts-module=esm

# 生成声明文件
haxe --ts output.ts --main Main  # 自动生成output.d.ts

# 禁用声明文件
haxe --ts output.ts --main Main -D ts-no-dts
```

## 6. 文件组织

```
output/
├── output.ts         # 主TypeScript代码
├── output.d.ts       # 类型声明文件
└── tsconfig.json     # TypeScript配置（可选生成）
```

## 7. 兼容性考虑

### 7.1 TypeScript版本支持

- 最低版本：TypeScript 4.0
- 推荐版本：TypeScript 5.0+
- 目标版本：支持最新稳定版

### 7.2 运行时库

某些Haxe特性需要运行时支持：
- 反射API
- 动态类型操作
- 枚举匹配辅助函数

创建 `haxe-ts-runtime` npm包提供这些功能。

## 8. 与JavaScript目标的区别

| 特性 | JavaScript | TypeScript |
|-----|-----------|-----------|
| 类型注解 | 无 | 完整类型 |
| 接口 | 运行时检查 | 编译时检查 |
| 