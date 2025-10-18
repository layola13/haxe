(*
	The Haxe Compiler
	Copyright (C) 2005-2025  Haxe Foundation

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *)
open Extlib_leftovers
open Globals
open Ast
open Type
open Gctx

(* TypeScript代码生成器 *)

type output_mode =
	| SingleFile
	| ModulePerClass
	| PackagePerDir

type ctx = {
	com : Gctx.t;
	buf : Rbuffer.t;
	dts_buf : Rbuffer.t;
	mutable chan : out_channel option;
	mutable dts_chan : out_channel option;
	packages : (string list,unit) Hashtbl.t;
	ts_version : int;
	output_mode : output_mode;
	emit_decorators : bool;
	emit_namespaces : bool;
	strict_null_checks : bool;
	mutable current : tclass;
	mutable tabs : string;
	mutable in_interface : bool;
	mutable in_value : tvar option;
	mutable in_loop : bool;
	mutable id_counter : int;
	mutable type_accessor : module_type -> string;
	mutable separator : bool;
	mutable statics : (tclass * tclass_field * texpr) list;
	mutable inits : texpr list;
	mutable enum_switch_ctx : tenum option;
}

let dot_path = s_type_path

let s_path ctx = dot_path

(* TypeScript关键字 *)
let ts_kwds = Hashtbl.create 0

let ts_keywords = [
	"abstract"; "any"; "as"; "async"; "await"; "boolean"; "break"; "case"; "catch";
	"class"; "const"; "constructor"; "continue"; "debugger"; "declare"; "default";
	"delete"; "do"; "else"; "enum"; "eval"; "export"; "extends"; "false"; "finally"; "for";
	"from"; "function"; "get"; "if"; "implements"; "import"; "in"; "instanceof";
	"interface"; "is"; "keyof"; "let"; "module"; "namespace"; "never"; "new"; "null";
	"number"; "object"; "of"; "package"; "private"; "protected"; "public"; "readonly";
	"require"; "return"; "set"; "static"; "string"; "super"; "switch"; "symbol";
	"this"; "throw"; "true"; "try"; "type"; "typeof"; "undefined"; "unique"; "unknown";
	"var"; "void"; "while"; "with"; "yield"; "arguments";
]

let setup_kwds () =
	Hashtbl.reset ts_kwds;
	List.iter (fun s -> Hashtbl.add ts_kwds s ()) ts_keywords

let valid_ts_ident s =
	String.length s > 0 && try
		for i = 0 to String.length s - 1 do
			match String.unsafe_get s i with
			| 'a'..'z' | 'A'..'Z' | '$' | '_' -> ()
			| '0'..'9' when i > 0 -> ()
			| _ -> raise Exit
		done;
		true
	with Exit ->
		false

let field s = if not (valid_ts_ident s) then "[\"" ^ s ^ "\"]" else "." ^ s
let ident s = if Hashtbl.mem ts_kwds s then "$" ^ s else s

let flush ctx =
	let chan =
		match ctx.chan with
		| Some chan -> chan
		| None ->
			let chan = open_out_bin ctx.com.file in
			ctx.chan <- Some chan;
			chan
	in
	Rbuffer.output_buffer chan ctx.buf;
	Rbuffer.clear ctx.buf

let flush_dts ctx =
	match ctx.dts_chan with
	| Some chan ->
		Rbuffer.output_buffer chan ctx.dts_buf;
		Rbuffer.clear ctx.dts_buf
	| None -> ()

let spr ctx s =
	ctx.separator <- false;
	Rbuffer.add_string ctx.buf s

let spr_dts ctx s =
	Rbuffer.add_string ctx.dts_buf s

let print ctx =
	ctx.separator <- false;
	Printf.kprintf (fun s -> Rbuffer.add_string ctx.buf s)

let print_dts ctx =
	Printf.kprintf (fun s -> Rbuffer.add_string ctx.dts_buf s)

let newline ctx =
	let len = Rbuffer.length ctx.buf in
	if len = 0 then
		print ctx "\n%s" ctx.tabs
	else
		match Rbuffer.nth ctx.buf (len - 1) with
		| '}' | '{' | ':' | ';' when not ctx.separator -> print ctx "\n%s" ctx.tabs
		| _ -> print ctx ";\n%s" ctx.tabs

let newline_dts ctx =
	spr_dts ctx "\n"

let open_block ctx =
	let oldt = ctx.tabs in
	ctx.tabs <- "\t" ^ ctx.tabs;
	(fun() -> ctx.tabs <- oldt)

let this ctx = match ctx.in_value with None -> "this" | Some _ -> "$this"

let has_feature ctx = Gctx.has_feature ctx.com
let add_feature ctx = Gctx.add_feature ctx.com

(* 类型映射：Haxe类型 -> TypeScript类型 *)
let rec gen_type_hint ctx t =
	match follow t with
	| TInst ({ cl_path = [],"Int" },_)
	| TInst ({ cl_path = [],"Float" },_)
	| TAbstract ({ a_path = [],"Int" },_)
	| TAbstract ({ a_path = [],"Float" },_) ->
		spr ctx "number"
	| TInst ({ cl_path = [],"String" },_)
	| TAbstract ({ a_path = [],"Single" },_) ->
		spr ctx "string"
	| TInst ({ cl_path = [],"Bool" },_)
	| TAbstract ({ a_path = [],"Bool" },_) ->
		spr ctx "boolean"
	| TAbstract ({ a_path = [],"Void" },_)
	| TEnum ({ e_path = [],"Void" },_) ->
		spr ctx "void"
	| TDynamic _ ->
		spr ctx "any"
	| TInst ({ cl_path = [],"Array" },[t]) ->
		gen_type_hint ctx t;
		spr ctx "[]"
	| TInst ({cl_kind = KTypeParameter _} as c, _) ->
		(* 泛型类型参数 - 使用简单名称 *)
		spr ctx (snd c.cl_path)
	| TInst (c,tl) ->
		spr ctx (s_path ctx c.cl_path);
		(match tl with
		| [] -> ()
		| _ ->
			spr ctx "<";
			let rec loop = function
				| [] -> ()
				| [t] -> gen_type_hint ctx t
				| t :: tl ->
					gen_type_hint ctx t;
					spr ctx ", ";
					loop tl
			in
			loop tl;
			spr ctx ">")
	| TEnum (e,_) ->
		spr ctx (s_path ctx e.e_path)
	| TType (t,tl) ->
		spr ctx (s_path ctx t.t_path);
		(match tl with
		| [] -> ()
		| _ ->
			spr ctx "<";
			let rec loop = function
				| [] -> ()
				| [t] -> gen_type_hint ctx t
				| t :: tl ->
					gen_type_hint ctx t;
					spr ctx ", ";
					loop tl
			in
			loop tl;
			spr ctx ">")
	| TFun (args,ret) ->
		spr ctx "(";
		let counter = ref 0 in
		let rec loop = function
			| [] -> ()
			| [(n,opt,t)] ->
				let param_name = if n = "" then (incr counter; "arg" ^ string_of_int !counter) else ident n in
				spr ctx param_name;
				if opt then spr ctx "?";
				spr ctx ": ";
				gen_type_hint ctx t
			| (n,opt,t) :: args ->
				let param_name = if n = "" then (incr counter; "arg" ^ string_of_int !counter) else ident n in
				spr ctx param_name;
				if opt then spr ctx "?";
				spr ctx ": ";
				gen_type_hint ctx t;
				spr ctx ", ";
				loop args
		in
		loop args;
		spr ctx ") => ";
		gen_type_hint ctx ret
	| TAnon a ->
		spr ctx "{ ";
		PMap.iter (fun _ f ->
			spr ctx (ident f.cf_name);
			spr ctx ": ";
			gen_type_hint ctx f.cf_type;
			spr ctx "; "
		) a.a_fields;
		spr ctx "}"
	| TMono r ->
		(match r.tm_type with
		| Some t -> gen_type_hint ctx t
		| None -> spr ctx "any")
	| TAbstract (a,tl) when not (Meta.has Meta.CoreType a.a_meta) ->
		gen_type_hint ctx (Abstract.get_underlying_type a tl)
	| TAbstract (a,_) ->
		spr ctx (s_path ctx a.a_path)
	| TLazy f ->
		gen_type_hint ctx (lazy_type f)

(* 辅助函数：生成类型到字符串 *)
let type_to_string ctx t =
	let temp_buf = Rbuffer.create 256 in
	let temp_ctx = { ctx with buf = temp_buf } in
	gen_type_hint temp_ctx t;
	let temp_file = Filename.temp_file "haxe_type" ".tmp" in
	let temp_chan = open_out_bin temp_file in
	Rbuffer.output_buffer temp_chan temp_buf;
	close_out temp_chan;
	let ic = open_in_bin temp_file in
	let result = really_input_string ic (in_channel_length ic) in
	close_in ic;
	Sys.remove temp_file;
	result

(* 生成常量 *)
let gen_constant ctx p = function
	| TInt i ->
		(* 如果在枚举switch中，将整数转换为枚举构造器名称 *)
		(match ctx.enum_switch_ctx with
		| Some enum_def ->
			let index = Int32.to_int i in
			if index >= 0 && index < List.length enum_def.e_names then
				let constr_name = List.nth enum_def.e_names index in
				print ctx "\"%s\"" constr_name
			else
				print ctx "%ld" i
		| None ->
			print ctx "%ld" i)
	| TFloat s -> spr ctx s
	| TString s -> print ctx "\"%s\"" (StringHelper.s_escape s)
	| TBool b -> spr ctx (if b then "true" else "false")
	| TNull -> spr ctx "null"
	| TThis -> spr ctx (this ctx)
	| TSuper -> spr ctx "super"

(* 检查是否是JS特定的运行时调用或赋值 *)
let is_js_specific_call e =
	match e.eexpr with
	| TCall ({ eexpr = TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "code" | "typeof" | "instanceof" | "construct" })) }, _) ->
		(* code、typeof、instanceof、construct需要被处理，不是JS特定代码 *)
		false
	| TCall ({ eexpr = TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, _)) }, _) ->
		(* 其他js.Syntax调用是JS特定的 *)
		true
	| TCall ({ eexpr = TIdent "__define_feature__" }, _) -> false  (* 需要处理，不是JS特定 *)
	| TCall ({ eexpr = TIdent "__feature__" }, _) -> false  (* 需要处理，不是JS特定 *)
	| TCall ({ eexpr = TIdent "__js__" }, _) -> true
	| TBinop (OpAssign, { eexpr = TField ({ eexpr = TTypeExpr (TClassDecl { cl_path = ["js"],"Boot" }) }, _) }, _) -> true
	| _ -> false

(* 检查表达式是否包含静态main方法调用 *)
let is_main_call e =
	match e.eexpr with
	| TCall ({ eexpr = TField (_, FStatic (c, { cf_name = "main" })) }, []) -> true
	| _ -> false

(* 生成包命名空间结构 *)
let generate_namespace_open ctx path =
	match path with
	| [] -> ()
	| _ ->
		List.iter (fun p ->
			print ctx "export namespace %s {" p;
			newline ctx;
			ctx.tabs <- ctx.tabs ^ "\t"
		) path

let generate_namespace_close ctx path =
	match path with
	| [] -> ()
	| _ ->
		List.iter (fun _ ->
			let len = String.length ctx.tabs in
			if len > 0 then
				ctx.tabs <- String.sub ctx.tabs 0 (len - 1);
			spr ctx "}";
			newline ctx
		) path

(* 生成函数参数和返回类型 *)
let gen_function_signature ctx f with_return =
	(* 参数 *)
	spr ctx "(";
	let rec loop = function
		| [] -> ()
		| [(v,c)] ->
			spr ctx (ident v.v_name);
			(match c with
			| Some { eexpr = TConst TNull } | None -> ()
			| Some _ -> spr ctx "?");
			spr ctx ": ";
			gen_type_hint ctx v.v_type
		| (v,c) :: rest ->
			spr ctx (ident v.v_name);
			(match c with
			| Some { eexpr = TConst TNull } | None -> ()
			| Some _ -> spr ctx "?");
			spr ctx ": ";
			gen_type_hint ctx v.v_type;
			spr ctx ", ";
			loop rest
	in
	loop f.tf_args;
	spr ctx ")";
	
	(* 返回类型 - 可选 *)
	if with_return then begin
		spr ctx ": ";
		(* 使用函数类型的返回类型，而不是表达式类型 *)
		match follow f.tf_type with
		| TFun(_,ret) -> gen_type_hint ctx ret
		| _ -> gen_type_hint ctx f.tf_expr.etype
	end

(* 表达式生成 - 相互递归定义 *)
let rec gen_expr ctx e =
	(* 跳过JS特定的运行时调用 *)
	if is_js_specific_call e then ()
	else match e.eexpr with
	| TConst c -> gen_constant ctx e.epos c
	| TLocal v -> spr ctx (ident v.v_name)
	| TArray (e1,e2) ->
		gen_value ctx e1;
		spr ctx "[";
		gen_value ctx e2;
		spr ctx "]"
	| TBinop (op,e1,e2) ->
		gen_value ctx e1;
		print ctx " %s " (Ast.s_binop op);
		gen_value ctx e2
	| TField (x,f) ->
		gen_value ctx x;
		let fname = field_name f in
		spr ctx (field (ident fname))
	| TTypeExpr t ->
		spr ctx (ctx.type_accessor t)
	| TParenthesis e ->
		spr ctx "(";
		gen_value ctx e;
		spr ctx ")"
	| TMeta (_,e) ->
		gen_expr ctx e
	| TReturn eo ->
		(match eo with
		| None ->
			spr ctx "return"
		| Some e ->
			spr ctx "return ";
			gen_value ctx e)
	| TBreak ->
		spr ctx "break"
	| TContinue ->
		spr ctx "continue"
	| TBlock el ->
		print ctx "{";
		let bend = open_block ctx in
		List.iter (fun e ->
			(* 跳过JS特定代码 *)
			if not (is_js_specific_call e) then begin
				newline ctx;
				gen_expr ctx e
			end
		) el;
		bend();
		newline ctx;
		print ctx "}"
	| TFunction f ->
		let old = ctx.in_value, ctx.in_loop in
		ctx.in_value <- None;
		ctx.in_loop <- false;
		print ctx "function(";
		let args = List.map (fun (v,_) -> ident v.v_name) f.tf_args in
		spr ctx (String.concat "," args);
		spr ctx ") ";
		gen_expr ctx f.tf_expr;
		ctx.in_value <- fst old;
		ctx.in_loop <- snd old
	| TCall (e,el) ->
		(* 特殊处理js.Syntax调用 *)
		(match e.eexpr with
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "typeof" })) ->
			(* typeof(x) -> typeof x *)
			spr ctx "typeof ";
			(match el with
			| [arg] -> gen_value ctx arg
			| _ -> spr ctx "undefined")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "instanceof" })) ->
			(* instanceof(x, T) -> x instanceof T *)
			(match el with
			| [obj; typ] ->
				gen_value ctx obj;
				spr ctx " instanceof ";
				gen_value ctx typ
			| _ -> spr ctx "false")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "construct" })) ->
			(* construct(Class, args...) -> new Class(args...) *)
			(match el with
			| cls :: args ->
				spr ctx "new ";
				gen_value ctx cls;
				spr ctx "(";
				let first = ref true in
				List.iter (fun arg ->
					if not !first then spr ctx ", ";
					first := false;
					gen_value ctx arg
				) args;
				spr ctx ")"
			| _ -> spr ctx "null")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "code" })) ->
			(* code("template", arg0, arg1, ...) -> 替换{0}, {1}等占位符 *)
			(match el with
			| { eexpr = TConst (TString template) } :: args ->
				(* 逐个替换占位符 *)
				let result = ref template in
				List.iteri (fun index arg ->
					let placeholder = "{" ^ string_of_int index ^ "}" in
					let arg_code = expr_to_string ctx arg in
					result := Str.global_replace (Str.regexp_string placeholder) arg_code !result
				) args;
				spr ctx !result
			| _ -> spr ctx "null")
		| TIdent "__ts__" ->
			(* __ts__("code", args...) -> 直接输出TypeScript代码并替换{0}, {1}等 *)
			(match el with
			| { eexpr = TConst (TString template) } :: args ->
				let result = ref template in
				List.iteri (fun index arg ->
					let placeholder = "{" ^ string_of_int index ^ "}" in
					let arg_code = expr_to_string ctx arg in
					result := Str.global_replace (Str.regexp_string placeholder) arg_code !result
				) args;
				spr ctx !result
			| _ -> ())
		| TIdent "__define_feature__" ->
			(* __define_feature__(feature_name, expression) -> 直接生成expression *)
			(match el with
			| [_; e] -> gen_value ctx e
			| _ -> ())
		| TIdent "__feature__" ->
			(* __feature__(feature_name, eif, eelse) -> 根据特性是否启用选择分支 *)
			(match el with
			| { eexpr = TConst (TString f) } :: eif :: eelse ->
				if has_feature ctx f then
					gen_value ctx eif
				else
					(match eelse with
					| [] -> ()
					| e :: _ -> gen_value ctx e)
			| _ -> ())
		| _ ->
			(* 正常的函数调用 *)
			gen_value ctx e;
			spr ctx "(";
			let first = ref true in
			List.iter (fun e ->
				if not !first then spr ctx ",";
				first := false;
				gen_value ctx e
			) el;
			spr ctx ")")
	| TArrayDecl el ->
		spr ctx "[";
		let first = ref true in
		List.iter (fun e ->
			if not !first then spr ctx ",";
			first := false;
			gen_value ctx e
		) el;
		spr ctx "]"
	| TThrow e ->
		spr ctx "throw ";
		gen_value ctx e
	| TVar (v,eo) ->
		spr ctx "let ";
		spr ctx (ident v.v_name);
		(match eo with
		| None -> ()
		| Some e ->
			spr ctx " = ";
			gen_value ctx e)
	| TNew (c,_,el) ->
		print ctx "new ";
		spr ctx (ctx.type_accessor (TClassDecl c));
		spr ctx "(";
		let first = ref true in
		List.iter (fun e ->
			if not !first then spr ctx ",";
			first := false;
			gen_value ctx e
		) el;
		spr ctx ")"
	| TIf (cond,e,eelse) ->
		spr ctx "if (";
		gen_value ctx cond;
		spr ctx ") ";
		gen_expr ctx (mk_block e);
		(match eelse with
		| None -> ()
		| Some e2 ->
			spr ctx " else ";
			gen_expr ctx (match e2.eexpr with | TIf _ -> e2 | _ -> mk_block e2))
	| TUnop (op,Ast.Prefix,e) ->
		spr ctx (Ast.s_unop op);
		gen_value ctx e
	| TUnop (op,Ast.Postfix,e) ->
		gen_value ctx e;
		spr ctx (Ast.s_unop op)
	| TWhile (cond,e,Ast.NormalWhile) ->
		let old_in_loop = ctx.in_loop in
		ctx.in_loop <- true;
		spr ctx "while (";
		gen_value ctx cond;
		spr ctx ") ";
		gen_expr ctx e;
		ctx.in_loop <- old_in_loop
	| TWhile (cond,e,Ast.DoWhile) ->
		let old_in_loop = ctx.in_loop in
		ctx.in_loop <- true;
		spr ctx "do ";
		gen_expr ctx e;
		spr ctx " while (";
		gen_value ctx cond;
		spr ctx ")";
		ctx.in_loop <- old_in_loop
	| TObjectDecl fields ->
		spr ctx "{ ";
		let first = ref true in
		List.iter (fun ((f,_,_),e) ->
			if not !first then spr ctx ", ";
			first := false;
			print ctx "%s: " f;
			gen_value ctx e
		) fields;
		spr ctx " }"
	| TTry (etry,catches) ->
		spr ctx "try ";
		gen_expr ctx etry;
		List.iter (fun (v,ecatch) ->
			print ctx " catch (%s) " (ident v.v_name);
			gen_expr ctx ecatch
		) catches
	| TSwitch {switch_subject = e; switch_cases = cases; switch_default = def} ->
		(* 检查switch subject是否是枚举索引访问(_tag) *)
		let old_enum_ctx = ctx.enum_switch_ctx in
		let enum_from_subject =
			let rec find_enum expr =
				match expr.eexpr with
				| TEnumIndex x ->
					(* x是枚举值，获取其类型 *)
					(match follow x.etype with
					| TEnum (enum_def, _) -> Some enum_def
					| _ -> None)
				| TParenthesis e | TMeta (_, e) | TCast (e, _) -> find_enum e
				| _ -> None
			in
			find_enum e
		in
		ctx.enum_switch_ctx <- enum_from_subject;
		spr ctx "switch (";
		gen_value ctx e;
		spr ctx ") {";
		newline ctx;
		List.iter (fun {case_patterns = el; case_expr = e2} ->
			List.iter (fun case_e ->
				spr ctx "case ";
				gen_value ctx case_e;
				spr ctx ":";
				newline ctx
			) el;
			let bend = open_block ctx in
			gen_expr ctx e2;
			newline ctx;
			spr ctx "break";
			bend();
			newline ctx
		) cases;
		(match def with
		| None -> ()
		| Some e ->
			spr ctx "default:";
			let bend = open_block ctx in
			newline ctx;
			gen_expr ctx e;
			bend();
			newline ctx);
		spr ctx "}";
		ctx.enum_switch_ctx <- old_enum_ctx
	| TCast (e,None) ->
		gen_expr ctx e
	| TCast (e1,Some _) ->
		gen_expr ctx e1
	| TEnumParameter (x,ef,i) ->
		(* 访问枚举对象的字段而不是数组索引 *)
		gen_value ctx x;
		(* 获取参数名 *)
		(match ef.ef_type with
		| TFun (args,_) ->
			(match List.nth_opt args i with
			| Some (arg_name,_,_) ->
				spr ctx (field (ident arg_name))
			| None ->
				print ctx "[%i]" (i + 2))
		| _ ->
			print ctx "[%i]" (i + 2))
	| TEnumIndex x ->
		(* 枚举索引应该访问_tag字段 *)
		gen_value ctx x;
		spr ctx "._tag"
		| TIdent "__resources__" ->
			(* 生成资源数组函数 *)
			spr ctx "(function() { return [";
			let first = ref true in
			Hashtbl.iter (fun name data ->
				if not !first then spr ctx ", ";
				first := false;
				spr ctx "{ name: \"";
				spr ctx (StringHelper.s_escape name);
				spr ctx "\", data: \"";
				spr ctx (StringHelper.s_escape (Codegen.bytes_serialize data));
				spr ctx "\" }";
			) ctx.com.resources;
			spr ctx "]; })";
		| TIdent s ->
			spr ctx s

(* 辅助函数：将表达式生成到字符串 *)
and expr_to_string ctx e =
	(* 简单情况直接处理 *)
	match e.eexpr with
	| TLocal v -> ident v.v_name
	| TConst (TInt i) -> Int32.to_string i
	| TConst (TFloat f) -> f
	| TConst (TString s) -> "\"" ^ s ^ "\""
	| TConst TNull -> "null"
	| TConst (TBool b) -> if b then "true" else "false"
	| _ ->
		(* 复杂表达式：创建临时buffer并使用临时输出 *)
		let temp_buf = Rbuffer.create 256 in
		let temp_ctx = { ctx with buf = temp_buf } in
		gen_value temp_ctx e;
		(* 使用临时字符串收集结果 *)
		let result = ref "" in
		let temp_file = Filename.temp_file "haxe_expr" ".tmp" in
		let temp_chan = open_out_bin temp_file in
		Rbuffer.output_buffer temp_chan temp_buf;
		close_out temp_chan;
		let ic = open_in_bin temp_file in
		result := really_input_string ic (in_channel_length ic);
		close_in ic;
		Sys.remove temp_file;
		!result

and gen_value ctx e =
	match e.eexpr with
	| TConst _
	| TLocal _
	| TArray _
	| TBinop _
	| TField _
	| TTypeExpr _
	| TParenthesis _
	| TObjectDecl _
	| TArrayDecl _
	| TNew _
	| TUnop _
	| TFunction _
	| TIdent _ ->
		gen_expr ctx e
	| TMeta (_,e1) ->
		gen_value ctx e1
	| TCall (e,el) ->
		(* 特殊处理js.Syntax调用 *)
		(match e.eexpr with
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "typeof" })) ->
			spr ctx "typeof ";
			(match el with
			| [arg] -> gen_value ctx arg
			| _ -> spr ctx "undefined")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "instanceof" })) ->
			(match el with
			| [obj; typ] ->
				gen_value ctx obj;
				spr ctx " instanceof ";
				gen_value ctx typ
			| _ -> spr ctx "false")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "construct" })) ->
			(* construct(Class, args...) -> new Class(args...) *)
			(match el with
			| cls :: args ->
				spr ctx "new ";
				gen_value ctx cls;
				spr ctx "(";
				let first = ref true in
				List.iter (fun arg ->
					if not !first then spr ctx ", ";
					first := false;
					gen_value ctx arg
				) args;
				spr ctx ")"
			| _ -> spr ctx "null")
		| TField (_, FStatic ({ cl_path = ["js"],"Syntax" }, { cf_name = "code" })) ->
			(* code("template", arg0, arg1, ...) -> 替换{0}, {1}等占位符 *)
			(match el with
			| { eexpr = TConst (TString template) } :: args ->
				(* 逐个替换占位符 *)
				let result = ref template in
				List.iteri (fun index arg ->
					let placeholder = "{" ^ string_of_int index ^ "}" in
					let arg_code = expr_to_string ctx arg in
					result := Str.global_replace (Str.regexp_string placeholder) arg_code !result
				) args;
				spr ctx !result
			| _ -> spr ctx "null")
		| TIdent "__ts__" ->
			(* __ts__("code", args...) -> 直接输出TypeScript代码并替换{0}, {1}等 *)
			(match el with
			| { eexpr = TConst (TString template) } :: args ->
				let result = ref template in
				List.iteri (fun index arg ->
					let placeholder = "{" ^ string_of_int index ^ "}" in
					let arg_code = expr_to_string ctx arg in
					result := Str.global_replace (Str.regexp_string placeholder) arg_code !result
				) args;
				spr ctx !result
			| _ -> ())
		| TIdent "__define_feature__" ->
			(* __define_feature__(feature_name, expression) -> 直接生成expression *)
			(match el with
			| [_; e] -> gen_value ctx e
			| _ -> ())
		| TIdent "__feature__" ->
			(* __feature__(feature_name, eif, eelse) -> 根据特性是否启用选择分支 *)
			(match el with
			| { eexpr = TConst (TString f) } :: eif :: eelse ->
				if has_feature ctx f then
					gen_value ctx eif
				else
					(match eelse with
					| [] -> ()
					| e :: _ -> gen_value ctx e)
			| _ -> ())
		| _ ->
			gen_value ctx e;
			spr ctx "(";
			let first = ref true in
			List.iter (fun e ->
				if not !first then spr ctx ",";
				first := false;
				gen_value ctx e
			) el;
			spr ctx ")")
	| TCast (e1,None) ->
		gen_value ctx e1
	| TCast (e1,Some _) ->
		gen_value ctx e1
	| TIf (cond,e,eo) ->
		(* 检查分支是否包含return语句 *)
		let has_return e =
			let rec check expr =
				match expr.eexpr with
				| TReturn _ -> true
				| TBlock el -> List.exists check el
				| TIf (_,e1,Some e2) -> check e1 || check e2
				| TIf (_,e1,None) -> check e1
				| _ -> false
			in
			check e
		in
		
		(* 如果任何分支包含return，使用IIFE *)
		let has_return_in_branches = has_return e || (match eo with Some e2 -> has_return e2 | None -> false) in
		
		if has_return_in_branches then begin
			(* 使用IIFE处理包含return的三元运算符 *)
			spr ctx "(function() { if (";
			gen_value ctx cond;
			spr ctx ") { ";
			gen_expr ctx e;
			spr ctx " } else { ";
			(match eo with
			| None -> spr ctx "return null;"
			| Some e2 -> gen_expr ctx e2);
			spr ctx " } })()"
		end else begin
			(* 正常的三元运算符 *)
			gen_value ctx cond;
			spr ctx " ? ";
			gen_value ctx e;
			spr ctx " : ";
			(match eo with
			| None -> spr ctx "null"
			| Some e2 -> gen_value ctx e2)
		end
	| TBlock el ->
		(* TBlock作为表达式使用时，需要用IIFE包裹，并返回最后一个表达式的值 *)
		spr ctx "(function() { ";
		(match List.rev el with
		| [] -> ()
		| last :: rest ->
			(* 先生成所有语句（除了最后一个）*)
			List.iter (fun e ->
				if not (is_js_specific_call e) then begin
					gen_expr ctx e;
					newline ctx
				end
			) (List.rev rest);
			(* 最后一个表达式作为返回值 *)
			if not (is_js_specific_call last) then begin
				(* 检查最后一个表达式是否已经是return语句 *)
				match last.eexpr with
				| TReturn _ ->
					(* 已经是return，直接生成 *)
					gen_expr ctx last
				| _ ->
					(* 不是return，需要添加return关键字 *)
					spr ctx "return ";
					gen_value ctx last
			end);
		spr ctx "; })()";
	| _ ->
		spr ctx "(";
		gen_expr ctx e;
		spr ctx ")"

(* 类生成 *)
let generate_class ctx c =
	let pack, name = match c.cl_path with
		| (pack, name) -> pack, name
	in
	
	(* 生成包命名空间 *)
	generate_namespace_open ctx pack;
	
	(* 生成类声明 *)
	if has_class_flag c CInterface then begin
		spr ctx "export interface ";
		spr ctx name;  (* 只使用接口名，不包含包路径 *)
		
		(* 泛型参数 *)
		(match c.cl_params with
		| [] -> ()
		| params ->
			spr ctx "<";
			let rec loop = function
				| [] -> ()
				| [tp] -> spr ctx tp.ttp_name
				| tp :: rest ->
					spr ctx tp.ttp_name;
					spr ctx ", ";
					loop rest
			in
			loop params;
			spr ctx ">");
		
		(* 继承 *)
		(match c.cl_super with
		| Some (csup,_) ->
			spr ctx " extends ";
			spr ctx (ctx.type_accessor (TClassDecl csup))
		| None -> ());
		
		(* 实现的接口 *)
		(match c.cl_implements with
		| [] -> ()
		| (i,_) :: rest ->
			spr ctx " extends ";
			spr ctx (ctx.type_accessor (TClassDecl i));
			List.iter (fun (i,_) ->
				spr ctx ", ";
				spr ctx (ctx.type_accessor (TClassDecl i))
			) rest);
		
		spr ctx " {";
		newline ctx;
		
		(* 接口成员 *)
		List.iter (fun f ->
			let tabs_old = ctx.tabs in
			ctx.tabs <- ctx.tabs ^ "\t";
			spr ctx (ident f.cf_name);
			spr ctx ": ";
			gen_type_hint ctx f.cf_type;
			spr ctx ";";
			newline ctx;
			ctx.tabs <- tabs_old
		) c.cl_ordered_fields;
		
		spr ctx "}";
		newline ctx;
	end else begin
		spr ctx "export class ";
		spr ctx name;  (* 只使用类名，不包含包路径 *)
		
		(* 泛型参数 *)
		(match c.cl_params with
		| [] -> ()
		| params ->
			spr ctx "<";
			let rec loop = function
				| [] -> ()
				| [tp] -> spr ctx tp.ttp_name
				| tp :: rest ->
					spr ctx tp.ttp_name;
					spr ctx ", ";
					loop rest
			in
			loop params;
			spr ctx ">");
		
		(* 继承 *)
		(match c.cl_super with
		| Some (csup,_) ->
			spr ctx " extends ";
			spr ctx (ctx.type_accessor (TClassDecl csup))
		| None -> ());
		
		(* 实现的接口 *)
		(match c.cl_implements with
		| [] -> ()
		| (i,_) :: rest ->
			spr ctx " implements ";
			spr ctx (ctx.type_accessor (TClassDecl i));
			List.iter (fun (i,_) ->
				spr ctx ", ";
				spr ctx (ctx.type_accessor (TClassDecl i))
			) rest);
		
		spr ctx " {";
		newline ctx;
		
		(* 类成员字段 - 只生成非方法字段 *)
		List.iter (fun f ->
			match f.cf_kind with
			| Var _ ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				(* 访问修饰符 *)
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				if has_class_field_flag f CfStatic then spr ctx "static ";
				
				spr ctx (ident f.cf_name);
				spr ctx ": ";
				gen_type_hint ctx f.cf_type;
				spr ctx ";";
				newline ctx;
				ctx.tabs <- tabs_old
			| Method _ -> () (* 方法稍后处理 *)
		) c.cl_ordered_fields;
		
		(* 构造函数 *)
		(match c.cl_constructor with
		| Some cf ->
			(match cf.cf_expr with
			| Some { eexpr = TFunction fn; epos = pos } ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				spr ctx "constructor";
				gen_function_signature ctx fn false; (* 构造函数不需要返回类型 *)
				spr ctx " ";
				gen_expr ctx fn.tf_expr;
				newline ctx;
				ctx.tabs <- tabs_old
			| _ ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				spr ctx "constructor() {";
				newline ctx;
				spr ctx "}";
				newline ctx;
				ctx.tabs <- tabs_old)
		| None -> ());
		
		(* 方法 - 生成完整的方法实现 *)
		List.iter (fun f ->
			match f.cf_kind, f.cf_expr with
			| Method _, Some { eexpr = TFunction fn; epos = pos } ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				if has_class_field_flag f CfStatic then spr ctx "static ";
				
				spr ctx (ident f.cf_name);
				
				(* 使用字段的声明类型而不是表达式类型 *)
				spr ctx "(";
				let rec loop = function
					| [] -> ()
					| [(v,c)] ->
						spr ctx (ident v.v_name);
						(match c with
						| Some { eexpr = TConst TNull } | None -> ()
						| Some _ -> spr ctx "?");
						spr ctx ": ";
						gen_type_hint ctx v.v_type
					| (v,c) :: rest ->
						spr ctx (ident v.v_name);
						(match c with
						| Some { eexpr = TConst TNull } | None -> ()
						| Some _ -> spr ctx "?");
						spr ctx ": ";
						gen_type_hint ctx v.v_type;
						spr ctx ", ";
						loop rest
				in
				loop fn.tf_args;
				spr ctx "): ";
				
				(* 使用字段的cf_type获取正确的返回类型 *)
				(match follow f.cf_type with
				| TFun(_,ret) -> gen_type_hint ctx ret
				| _ -> spr ctx "any");
				
				spr ctx " ";
				
				(* 生成方法体 *)
				gen_expr ctx fn.tf_expr;
				
				newline ctx;
				ctx.tabs <- tabs_old
			| Method _, None ->
				(* 抽象方法或接口方法 - 只生成签名 *)
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				spr ctx (ident f.cf_name);
				spr ctx "(): ";
				gen_type_hint ctx f.cf_type;
				spr ctx ";";
				newline ctx;
				ctx.tabs <- tabs_old
			| _ -> ()
		) c.cl_ordered_fields;
		
		(* 静态字段 - 只生成非方法静态字段,并收集初始化表达式 *)
		let static_inits = ref [] in
		List.iter (fun f ->
			match f.cf_kind with
			| Var _ ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				(* 访问修饰符 *)
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				spr ctx "static ";
				
				spr ctx (ident f.cf_name);
				spr ctx ": ";
				gen_type_hint ctx f.cf_type;
				spr ctx ";";
				newline ctx;
				ctx.tabs <- tabs_old;
				
				(* 收集初始化表达式 *)
				(match f.cf_expr with
				| Some e -> static_inits := (f, e) :: !static_inits
				| None -> ())
			| Method _ -> () (* 静态方法稍后处理 *)
		) c.cl_ordered_statics;
		
		(* 静态方法 - 生成完整的方法实现 *)
		List.iter (fun f ->
			match f.cf_kind, f.cf_expr with
			| Method _, Some { eexpr = TFunction fn; epos = pos } ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				spr ctx "static ";
				
				spr ctx (ident f.cf_name);
				
				(* 使用字段的声明类型而不是表达式类型 *)
				spr ctx "(";
				let rec loop = function
					| [] -> ()
					| [(v,c)] ->
						spr ctx (ident v.v_name);
						(match c with
						| Some { eexpr = TConst TNull } | None -> ()
						| Some _ -> spr ctx "?");
						spr ctx ": ";
						gen_type_hint ctx v.v_type
					| (v,c) :: rest ->
						spr ctx (ident v.v_name);
						(match c with
						| Some { eexpr = TConst TNull } | None -> ()
						| Some _ -> spr ctx "?");
						spr ctx ": ";
						gen_type_hint ctx v.v_type;
						spr ctx ", ";
						loop rest
				in
				loop fn.tf_args;
				spr ctx "): ";
				
				(* 使用字段的cf_type获取正确的返回类型 *)
				(match follow f.cf_type with
				| TFun(_,ret) -> gen_type_hint ctx ret
				| _ -> spr ctx "any");
				
				spr ctx " ";
				
				(* 生成方法体 *)
				gen_expr ctx fn.tf_expr;
				
				newline ctx;
				ctx.tabs <- tabs_old
			| Method _, None ->
				(* 抽象静态方法 - 只生成签名 *)
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				spr ctx "static ";
				
				spr ctx (ident f.cf_name);
				spr ctx "(): ";
				gen_type_hint ctx f.cf_type;
				spr ctx ";";
				newline ctx;
				ctx.tabs <- tabs_old
			| _ -> ()
		) c.cl_ordered_statics;
		
		spr ctx "}";
		newline ctx;
		
		(* 生成静态字段初始化代码 *)
		List.iter (fun (f, e) ->
			print ctx "%s.%s = " (s_path ctx c.cl_path) (ident f.cf_name);
			gen_value ctx e;
			newline ctx
		) (List.rev !static_inits);
	end;
	
	(* 关闭包命名空间 *)
	generate_namespace_close ctx pack;
	
	flush ctx

(* 枚举生成 *)
let generate_enum ctx e =
	let pack, name = e.e_path in
	
	(* 生成包命名空间 *)
	generate_namespace_open ctx pack;
	
	(* 使用TypeScript的联合类型和namespace来模拟Haxe枚举 *)
	spr ctx "export type ";
	spr ctx name;
	spr ctx " = ";
	
	(* 枚举构造器 *)
	let first = ref true in
	List.iter (fun cname ->
		let f = PMap.find cname e.e_constrs in
		if not !first then begin
			newline ctx;
			spr ctx "\t| "
		end else begin
			first := false
		end;
		
		spr ctx "{ readonly _tag: \"";
		spr ctx cname;
		spr ctx "\"";
		
		(* 枚举参数 *)
		(match f.ef_type with
		| TFun (args,_) ->
			List.iter (fun (arg_name,_,arg_type) ->
				spr ctx "; ";
				spr ctx (ident arg_name);
				spr ctx ": ";
				gen_type_hint ctx arg_type
			) args
		| _ -> ());
		
		spr ctx " }"
	) e.e_names;
	
	spr ctx ";";
	newline ctx;
	newline ctx;
	
	(* 枚举namespace包含构造函数 *)
	spr ctx "export namespace ";
	spr ctx name;
	spr ctx " {";
	newline ctx;
	
	List.iter (fun cname ->
		let f = PMap.find cname e.e_constrs in
		let tabs_old = ctx.tabs in
		ctx.tabs <- ctx.tabs ^ "\t";
		
		(match f.ef_type with
		| TFun (args,_) ->
			spr ctx "export function ";
			spr ctx cname;
			spr ctx "(";
			
			let rec loop = function
				| [] -> ()
				| [(arg_name,_,arg_type)] ->
					spr ctx (ident arg_name);
					spr ctx ": ";
					gen_type_hint ctx arg_type
				| (arg_name,_,arg_type) :: rest ->
					spr ctx (ident arg_name);
					spr ctx ": ";
					gen_type_hint ctx arg_type;
					spr ctx ", ";
					loop rest
			in
			loop args;
			
			spr ctx "): ";
			spr ctx name;  (* 返回枚举类型名 *)
			spr ctx " {";
			newline ctx;
			spr ctx "\treturn { _tag: \"";
			spr ctx cname;
			spr ctx "\"";
			
			List.iter (fun (arg_name,_,_) ->
				spr ctx ", ";
				spr ctx (ident arg_name)
			) args;
			
			spr ctx " };";
			newline ctx;
			spr ctx "}";
			newline ctx
		| _ ->
			spr ctx "export const ";
			spr ctx cname;
			spr ctx ": ";
			spr ctx name;  (* 使用枚举类型名而不是完整路径 *)
			spr ctx " = { _tag: \"";
			spr ctx cname;
			spr ctx "\" };";
			newline ctx);
		
		ctx.tabs <- tabs_old
	) e.e_names;
	
	spr ctx "}";
	newline ctx;
	
	(* 关闭包命名空间 *)
	generate_namespace_close ctx pack;
	
	flush ctx

(* 类型生成入口 *)
let generate_type ctx = function
	| TClassDecl c ->
		(match TClass.get_cl_init c with
		| None -> ()
		| Some e ->
			ctx.inits <- e :: ctx.inits);
		
		if not (has_class_flag c CExtern) then
			generate_class ctx c
	| TEnumDecl e when not (has_enum_flag e EnExtern) ->
		generate_enum ctx e
	| TTypeDecl _ | TAbstractDecl _ | TEnumDecl _ -> ()

let alloc_ctx com =
	let ts_version = 5 in
	
	let output_mode = SingleFile in
	
	let ctx = {
		com = com;
		buf = Rbuffer.create 16000;
		dts_buf = Rbuffer.create 16000;
		chan = None;
		dts_chan = None;
		packages = Hashtbl.create 0;
		ts_version = ts_version;
		output_mode = output_mode;
		emit_decorators = false;
		emit_namespaces = false;
		strict_null_checks = false;
		current = null_class;
		tabs = "";
		in_interface = false;
		in_value = None;
		in_loop = false;
		id_counter = 0;
		type_accessor = (fun _ -> die "" __LOC__);
		separator = false;
		statics = [];
		inits = [];
		enum_switch_ctx = None;
	} in
	
	ctx.type_accessor <- (fun t ->
		match t with
		| TClassDecl c when has_class_flag c CExtern ->
			dot_path c.cl_path
		| TEnumDecl e when has_enum_flag e EnExtern ->
			dot_path e.e_path
		| _ ->
			s_path ctx (t_path t)
	);
	
	ctx

(* 主生成函数 *)
let generate com =
	setup_kwds ();
	
	let ctx = alloc_ctx com in
	
	(* 生成文件头 *)
	spr ctx "// Generated by Haxe ";
	spr ctx (s_version);
	newline ctx;
	spr ctx "// TypeScript Target";
	newline ctx;
	newline ctx;
	
	(* 初始化Haxe运行时变量 *)
	spr ctx "const $hxClasses: any = {};";
	newline ctx;
	spr ctx "const $global: any = typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this;";
	newline ctx;
	newline ctx;
	
	(* 生成所有类型 *)
	List.iter (generate_type ctx) com.types;
	
	(* 生成初始化代码 - 过滤JS特定代码 *)
	List.iter (fun e ->
		if not (is_js_specific_call e) then begin
			gen_expr ctx e;
			newline ctx
		end
	) (List.rev ctx.inits);
	
	(* 生成静态初始化 - 过滤JS特定代码 *)
	List.iter (fun (_,_,e) ->
		if not (is_js_specific_call e) then begin
			gen_expr ctx e;
			newline ctx
		end
	) (List.rev ctx.statics);
	
	(* 生成主函数调用 *)
	(match com.main.main_expr with
	| None -> ()
	| Some e ->
		if not (is_js_specific_call e) then begin
			gen_expr ctx e;
			newline ctx
		end);
	
	flush ctx;
	
	(* 生成.d.ts文件 *)
	let generate_dts = true in
	if generate_dts then begin
		(* 构造.d.ts文件名 - 直接替换扩展名 *)
		let dts_file =
			(* 使用Filename.remove_extension去除扩展名 *)
			let base =
				let len = String.length com.file in
				let rec find_dot i =
					if i < 0 then len
					else if String.get com.file i = '.' then i
					else find_dot (i - 1)
				in
				let dot_pos = find_dot (len - 1) in
				String.sub com.file 0 dot_pos
			in
			base ^ ".d.ts"
		in
		
		(* 先写入头部 *)
		spr_dts ctx "// Generated by Haxe ";
		spr_dts ctx (s_version);
		newline_dts ctx;
		spr_dts ctx "// TypeScript Declaration File";
		newline_dts ctx;
		newline_dts ctx;
		
		(* 打开.d.ts文件 *)
		ctx.dts_chan <- Some (open_out_bin dts_file);
		
		(* 生成所有类型的声明 *)
		List.iter (fun t ->
			match t with
			| TClassDecl c when not (has_class_flag c CExtern) ->
				let pack, name = c.cl_path in
				
				(* 生成包命名空间 *)
				(match pack with
				| [] -> ()
				| _ ->
					List.iter (fun p ->
						print_dts ctx "export namespace %s {" p;
						newline_dts ctx
					) pack);
				
				(* 生成类/接口声明 *)
				if has_class_flag c CInterface then begin
					print_dts ctx "export interface %s" name;
					
					(* 泛型参数 *)
					(match c.cl_params with
					| [] -> ()
					| params ->
						spr_dts ctx "<";
						spr_dts ctx (String.concat ", " (List.map (fun tp -> tp.ttp_name) params));
						spr_dts ctx ">");
					
					(* 继承 *)
					(match c.cl_super with
					| Some (csup,_) ->
						print_dts ctx " extends %s" (s_path ctx csup.cl_path)
					| None -> ());
					
					(* 实现的接口 *)
					(match c.cl_implements with
					| [] -> ()
					| (i,_) :: rest ->
						print_dts ctx " extends %s" (s_path ctx i.cl_path);
						List.iter (fun (i,_) ->
							print_dts ctx ", %s" (s_path ctx i.cl_path)
						) rest);
					
					spr_dts ctx " {";
					newline_dts ctx;
					
					(* 接口成员 *)
					List.iter (fun f ->
						print_dts ctx "\t%s: %s;" (ident f.cf_name) (type_to_string ctx f.cf_type);
						newline_dts ctx
					) c.cl_ordered_fields;
					
					spr_dts ctx "}";
					newline_dts ctx
				end else begin
					print_dts ctx "export class %s" name;
					
					(* 泛型参数 *)
					(match c.cl_params with
					| [] -> ()
					| params ->
						spr_dts ctx "<";
						spr_dts ctx (String.concat ", " (List.map (fun tp -> tp.ttp_name) params));
						spr_dts ctx ">");
					
					(* 继承 *)
					(match c.cl_super with
					| Some (csup,_) ->
						print_dts ctx " extends %s" (s_path ctx csup.cl_path)
					| None -> ());
					
					(* 实现的接口 *)
					(match c.cl_implements with
					| [] -> ()
					| (i,_) :: rest ->
						print_dts ctx " implements %s" (s_path ctx i.cl_path);
						List.iter (fun (i,_) ->
							print_dts ctx ", %s" (s_path ctx i.cl_path)
						) rest);
					
					spr_dts ctx " {";
					newline_dts ctx;
					
					(* 实例字段 *)
					List.iter (fun f ->
						match f.cf_kind with
						| Var _ ->
							print_dts ctx "\t%s%s: %s;"
								(if has_class_field_flag f CfPublic then "public " else "private ")
								(ident f.cf_name)
								(type_to_string ctx f.cf_type);
							newline_dts ctx
						| Method _ ->
							(match follow f.cf_type with
							| TFun(args, ret) ->
								let param_strs = List.map (fun (n,opt,t) ->
									let pname = if n = "" then "arg" else ident n in
									let popt = if opt then "?" else "" in
									pname ^ popt ^ ": " ^ (type_to_string ctx t)
								) args in
								print_dts ctx "\t%s%s(%s): %s;"
									(if has_class_field_flag f CfPublic then "public " else "private ")
									(ident f.cf_name)
									(String.concat ", " param_strs)
									(type_to_string ctx ret);
								newline_dts ctx
							| _ ->
								print_dts ctx "\t%s%s(): any;"
									(if has_class_field_flag f CfPublic then "public " else "private ")
									(ident f.cf_name);
								newline_dts ctx)
					) c.cl_ordered_fields;
					
					(* 静态成员 *)
					List.iter (fun f ->
						match f.cf_kind with
						| Var _ ->
							print_dts ctx "\t%sstatic %s: %s;"
								(if has_class_field_flag f CfPublic then "public " else "private ")
								(ident f.cf_name)
								(type_to_string ctx f.cf_type);
							newline_dts ctx
						| Method _ ->
							(match follow f.cf_type with
							| TFun(args, ret) ->
								let param_strs = List.map (fun (n,opt,t) ->
									let pname = if n = "" then "arg" else ident n in
									let popt = if opt then "?" else "" in
									pname ^ popt ^ ": " ^ (type_to_string ctx t)
								) args in
								print_dts ctx "\t%sstatic %s(%s): %s;"
									(if has_class_field_flag f CfPublic then "public " else "private ")
									(ident f.cf_name)
									(String.concat ", " param_strs)
									(type_to_string ctx ret);
								newline_dts ctx
							| _ ->
								print_dts ctx "\t%sstatic %s(): any;"
									(if has_class_field_flag f CfPublic then "public " else "private ")
									(ident f.cf_name);
								newline_dts ctx)
					) c.cl_ordered_statics;
					
					spr_dts ctx "}";
					newline_dts ctx
				end;
				
				(* 关闭包命名空间 *)
				(match pack with
				| [] -> ()
				| _ ->
					List.iter (fun _ ->
						spr_dts ctx "}";
						newline_dts ctx
					) pack);
				newline_dts ctx
			
			| TEnumDecl e when not (has_enum_flag e EnExtern) ->
				let pack, name = e.e_path in
				
				(* 生成包命名空间 *)
				(match pack with
				| [] -> ()
				| _ ->
					List.iter (fun p ->
						print_dts ctx "export namespace %s {" p;
						newline_dts ctx
					) pack);
				
				(* 生成枚举类型声明 *)
				print_dts ctx "export type %s = " name;
				
				let first = ref true in
				List.iter (fun cname ->
					let f = PMap.find cname e.e_constrs in
					if not !first then begin
						newline_dts ctx;
						spr_dts ctx "\t| "
					end else begin
						first := false
					end;
					
					spr_dts ctx "{ readonly _tag: \"";
					spr_dts ctx cname;
					spr_dts ctx "\"";
					
					(* 枚举参数 *)
					(match f.ef_type with
					| TFun (args,_) ->
						List.iter (fun (arg_name,_,arg_type) ->
							print_dts ctx "; %s: %s" (ident arg_name) (type_to_string ctx arg_type)
						) args
					| _ -> ());
					
					spr_dts ctx " }"
				) e.e_names;
				
				spr_dts ctx ";";
				newline_dts ctx;
				newline_dts ctx;
				
				(* 生成枚举namespace声明 *)
				print_dts ctx "export namespace %s {" name;
				newline_dts ctx;
				
				List.iter (fun cname ->
					let f = PMap.find cname e.e_constrs in
					(match f.ef_type with
					| TFun (args,_) ->
						let param_strs = List.map (fun (arg_name,_,arg_type) ->
							(ident arg_name) ^ ": " ^ (type_to_string ctx arg_type)
						) args in
						print_dts ctx "\texport function %s(%s): %s;" cname (String.concat ", " param_strs) name;
						newline_dts ctx
					| _ ->
						print_dts ctx "\texport const %s: %s;" cname name;
						newline_dts ctx)
				) e.e_names;
				
				spr_dts ctx "}";
				newline_dts ctx;
				
				(* 关闭包命名空间 *)
				(match pack with
				| [] -> ()
				| _ ->
					List.iter (fun _ ->
						spr_dts ctx "}";
						newline_dts ctx
					) pack);
				newline_dts ctx
			
			| _ -> ()
		) com.types;
		
		flush_dts ctx;
		Option.may (fun chan -> close_out chan) ctx.dts_chan
	end;
	
	Option.may (fun chan -> close_out chan) ctx.chan