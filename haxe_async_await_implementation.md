# Haxe @async/@await 实现补充文档

## 完整的实现指南

### 1. 元数据定义更新

#### 1.1 修改 src-json/meta.json

在数组末尾添加以下两个元数据定义：

```json
{
    "name": "Async",
    "metadata": ":async",
    "doc": "Marks a function as async, generating native JavaScript async function. Requires ES2017+.",
    "platforms": ["js"],
    "targets": ["TClassField"],
    "links": ["https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function"]
},
{
    "name": "Await",
    "metadata": ":await",
    "doc": "Marks an expression as await, generating native JavaScript await expression. Must be used inside async functions.",
    "platforms": ["js"],
    "targets": ["TExpr"],
    "links": ["https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await"]
}
```

### 2. 上下文增强

#### 2.1 修改 ctx 结构 (genjs.ml: 27-49)

```ocaml
type ctx = {
    com : Gctx.t;
    buf : Rbuffer.t;
    mutable chan : out_channel option;
    packages : (string list,unit) Hashtbl.t;
    smap : sourcemap option;
    js_modern : bool;
    js_flatten : bool;
    has_resolveClass : bool;
    has_interface_check : bool;
    es_version : int;
    mutable current : tclass;
    mutable statics : (tclass * tclass_field * texpr) list;
    mutable inits : texpr list;
    mutable tabs : string;
    mutable in_value : tvar option;
    mutable in_loop : bool;
    mutable in_async : bool;  (* 新增：追踪是否在 async 函数内 *)
    mutable id_counter : int;
    mutable type_accessor : module_type -> string;
    mutable separator : bool;
    mutable found_expose : bool;
    mutable catch_vars : texpr list;
}
```

#### 2.2 更新 alloc_ctx (genjs.ml: 1606-1659)

```ocaml
let alloc_ctx com es_version =
    (* ... 现有代码 ... *)
    let ctx = {
        com = com;
        buf = Rbuffer.create 16000;
        chan = None;
        packages = Hashtbl.create 0;
        smap = smap;
        js_modern = not (Gctx.defined com Define.JsClassic);
        js_flatten = not (Gctx.defined com Define.JsUnflatten);
        has_resolveClass = Gctx.has_feature com "Type.resolveClass";
        has_interface_check = Gctx.has_feature com "js.Boot.__interfLoop";
        es_version = es_version;
        statics = [];
        inits = [];
        current = null_class;
        tabs = "";
        in_value = None;
        in_loop = false;
        in_async = false;  (* 新增初始化 *)
        id_counter = 0;
        type_accessor = (fun _ -> die "" __LOC__);
        separator = false;
        found_expose = false;
        catch_vars = [];
    } in
    (* ... 其余代码 ... *)
```

### 3. 函数生成修改

#### 3.1 完整的 gen_function 修改

```ocaml
and gen_function ?(keyword="function") ?(cf_meta=[]) ctx f pos =
    (* 保存旧的上下文状态 *)
    let old = ctx.in_value, ctx.in_loop, ctx.in_async in
    ctx.in_value <- None;
    ctx.in_loop <- false;
    
    (* 检查是否有 @:async 元数据 *)
    let is_async = Meta.has Meta.Async cf_meta in
    ctx.in_async <- is_async;
    
    (* 处理 rest 参数 - 保留现有逻辑 *)
    let mk_non_rest_arg_names =
        List.map (fun (v,_) ->
            check_var_declaration v;
            ident v.v_name
        )
    in
    let f,args =
        match List.rev f.tf_args with
        | (v,None) :: args_rev when ExtType.is_rest (follow v.v_type) ->
            if ctx.es_version >= 6 then
                f, List.map (fun (a,_) ->
                    check_var_declaration a;
                    if a == v then ("..." ^ ident a.v_name)
                    else ident a.v_name
                ) f.tf_args
            else begin
                check_var_declaration v;
                let non_rest_args = List.rev args_rev in
                let args_decl = declare_rest_args_legacy ctx.com (List.length non_rest_args) v in
                let body =
                    let el =
                        match f.tf_expr.eexpr with
                        | TBlock el -> args_decl @ el
                        | _ -> args_decl @ [f.tf_expr]
                    in
                    mk (TBlock el) f.tf_expr.etype f.tf_expr.epos
                in
                { f with tf_args = non_rest_args; tf_expr = body }, mk_non_rest_arg_names non_rest_args
            end
        | _ ->
            f, mk_non_rest_arg_names f.tf_args
    in
    
    (* 添加 async 关键字 *)
    let keyword = if is_async && ctx.es_version >= 7 then
        "async " ^ keyword
    else if is_async && ctx.es_version < 7 then begin
        (* 生成警告 *)
        print ctx "/* Warning: @:async requires ES2017+, ignored */ ";
        keyword
    end else
        keyword
    in
    
    print ctx "%s(%s) " keyword (String.concat "," args);
    gen_expr ctx (fun_block ctx f pos);
    
    (* 恢复上下文 *)
    ctx.in_value <- (match old with (a,_,_) -> a);
    ctx.in_loop <- (match old with (_,b,_) -> b);
    ctx.in_async <- (match old with (_,_,c) -> c);
    ctx.separator <- true
```

### 4. 表达式生成修改

#### 4.1 gen_expr 中添加 await 支持

在 `gen_expr` 函数的模式匹配中，在 TMeta 之前添加：

```ocaml
and gen_expr ctx e =
    let clear_mapping = add_mapping ctx.smap e in
    (match e.eexpr with
    | TConst c -> gen_constant ctx e.epos c
    | TLocal v -> spr ctx (ident v.v_name)
    (* ... 其他现有模式 ... *)
    
    (* 新增：处理 @:await 元数据 *)
    | TMeta ((Meta.Await,_,_), e1) ->
        if ctx.es_version >= 7 then begin
            if not ctx.in_async then
                (* 可选：生成警告 *)
                spr ctx "/* Warning: await outside async function */ ";
            spr ctx "await ";
            gen_expr ctx e1
        end else begin
            (* ES7 之前不支持，生成警告并忽略 *)
            spr ctx "/* Warning: await requires ES2017+, ignored */ ";
            gen_expr ctx e1
        end
    
    | TMeta (_,e) ->
        gen_expr ctx e
    
    (* ... 其余模式 ... *)
    );
    clear_mapping ()
```

#### 4.2 gen_value 中添加 await 支持

```ocaml
and gen_value ctx e =
    let clear_mapping = add_mapping ctx.smap e in
    (* ... assign 和 value 函数定义 ... *)
    (match e.eexpr with
    (* ... 现有模式 ... *)
    
    (* 新增：处理 @:await 元数据 *)
    | TMeta ((Meta.Await,_,_), e1) ->
        if ctx.es_version >= 7 then begin
            spr ctx "await ";
            gen_value ctx e1
        end else
            gen_value ctx e1
    
    | TMeta (_,e1) ->
        gen_value ctx e1
    
    (* ... 其余模式 ... *)
    );
    clear_mapping ()
```

### 5. 类方法生成修改

#### 5.1 ES6 类方法 (genjs.ml: ~1289)

```ocaml
List.filter (fun cf ->
    match cf.cf_kind, cf.cf_expr with
    | Method _, Some { eexpr = TFunction f; epos = pos } ->
        check_field_name c cf;
        newline ctx;
        
        (* 检查 async 并修改关键字 *)
        let base_keyword = method_def_name cf in
        let keyword = if Meta.has Meta.Async cf.cf_meta && ctx.es_version >= 7 then
            "async " ^ base_keyword
        else
            base_keyword
        in
        
        gen_function ~cf_meta:cf.cf_meta ~keyword:keyword ctx f pos;
        ctx.separator <- false;
        false
    | _ ->
        true
) c.cl_ordered_fields
```

#### 5.2 ES6 构造函数 (genjs.ml: ~1278)

```ocaml
(match c.cl_constructor with
| Some { cf_expr = Some ({ eexpr = TFunction f; epos = p } as e); cf_meta = meta } ->
    newline ctx;
    let keyword = if Meta.has Meta.Async meta && ctx.es_version >= 7 then
        "async constructor"
    else
        "constructor"
    in
    gen_function ~cf_meta:meta ~keyword:keyword ctx f p;
    ctx.separator <- false
| _ -> ());
```

### 6. 使用示例

#### 6.1 Haxe 代码

```haxe
import js.lib.Promise;

class AsyncAPI {
    @:async
    public static function getData(): Promise<String> {
        var response = @:await fetch("https://api.example.com/data");
        var json = @:await response.json();
        return json;
    }
    
    @:async
    public function processData(): Promise<Void> {
        var data = @:await getData();
        trace("Received: " + data);
    }
}
```

#### 6.2 编译命令

```bash
haxe -main AsyncAPI -js output.js -D js-es=2017
```

#### 6.3 生成的 JS (ES2017)

```javascript
class AsyncAPI {
    static async getData() {
        var response = await fetch("https://api.example.com/data");
        var json = await response.json();
        return json;
    }
    
    async processData() {
        var data = await AsyncAPI.getData();
        console.log("Received: " + data);
    }
}
```

### 7. 测试用例

#### 7.1 基本 async 函数

```haxe
@:async
function test1(): js.lib.Promise<Int> {
    return 42;
}
// 生成: async function test1() { return 42; }
```

#### 7.2 await 表达式

```haxe
@:async
function test2(): js.lib.Promise<Int> {
    var x = @:await Promise.resolve(10);
    var y = @:await Promise.resolve(20);
    return x + y;
}
// 生成: async function test2() { 
//   var x = await Promise.resolve(10);
//   var y = await Promise.resolve(20);
//   return x + y;
// }
```

#### 7.3 箭头函数

```haxe
var handler = @:async () -> {
    @:await delay(1000);
    trace("Done");
};
// 生成: var handler = async () => {
//   await delay(1000);
//   console.log("Done");
// };
```

#### 7.4 类方法

```haxe
class MyClass {
    @:async
    public function method(): js.lib.Promise<Void> {
        @:await something();
    }
}
// 生成: class MyClass {
//   async method() {
//     await something();
//   }
// }
```

### 8. 潜在问题和解决方案

#### 8.1 问题：await 在非 async 函数中

**检测**: 使用 `ctx.in_async` 标志  
**处理**: 生成警告注释

#### 8.2 问题：ES版本不支持

**检测**: 检查 `ctx.es_version < 7`  
**处理**: 生成警告注释并忽略 async/await 关键字

#### 8.3 问题：返回类型不是 Promise

**检测**: 这应该在类型检查阶段处理  
**代码生成器**: 不做检查，信任类型系统

### 9. 实现步骤

1. ✅ 分析现有架构
2. ⬜ 修改 `meta.json` 添加元数据定义
3. ⬜ 更新 `ctx` 结构添加 `in_async` 字段
4. ⬜ 修改 `gen_function` 支持 `async` 关键字
5. ⬜ 修改 `gen_expr` 支持 `@:await`
6. ⬜ 修改 `gen_value` 支持 `@:await`
7. ⬜ 更新所有 `gen_function` 调用点传递 `cf_meta`
8. ⬜ 编写测试用例
9. ⬜ 文档更新

### 10. 总结

本实现方案提供了一个完整的、最小侵入的方式来为 Haxe JS 代码生成器添加原生 async/await 支持。主要修改点包括：

- 新增两个元数据：`@:async` 和 `@:await`
- 