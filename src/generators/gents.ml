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
open Error
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
}

let dot_path = s_type_path

let s_path ctx = dot_path

(* TypeScript关键字 *)
let ts_kwds = Hashtbl.create 0

let ts_keywords = [
	"abstract"; "any"; "as"; "async"; "await"; "boolean"; "break"; "case"; "catch";
	"class"; "const"; "constructor"; "continue"; "debugger"; "declare"; "default";
	"delete"; "do"; "else"; "enum"; "export"; "extends"; "false"; "finally"; "for";
	"from"; "function"; "get"; "if"; "implements"; "import"; "in"; "instanceof";
	"interface"; "is"; "keyof"; "let"; "module"; "namespace"; "never"; "new"; "null";
	"number"; "object"; "of"; "package"; "private"; "protected"; "public"; "readonly";
	"require"; "return"; "set"; "static"; "string"; "super"; "switch"; "symbol";
	"this"; "throw"; "true"; "try"; "type"; "typeof"; "undefined"; "unique"; "unknown";
	"var"; "void"; "while"; "with"; "yield";
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
	match Rbuffer.nth ctx.buf (Rbuffer.length ctx.buf - 1) with
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
		let rec loop = function
			| [] -> ()
			| [(n,opt,t)] ->
				spr ctx (ident n);
				if opt then spr ctx "?";
				spr ctx ": ";
				gen_type_hint ctx t
			| (n,opt,t) :: args ->
				spr ctx (ident n);
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

(* 表达式生成占位符 *)
let rec gen_expr ctx e =
	spr ctx "/* expression */"

and gen_value ctx e =
	spr ctx "/* value */"

(* 类生成 *)
let generate_class ctx c =
	let p = s_path ctx c.cl_path in
	
	(* 生成类声明 *)
	if has_class_flag c CInterface then begin
		spr ctx "export interface ";
		spr ctx p;
		
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
		spr ctx p;
		
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
		
		(* 类成员字段 *)
		List.iter (fun f ->
			let tabs_old = ctx.tabs in
			ctx.tabs <- ctx.tabs ^ "\t";
			
			(* 访问修饰符 *)
			if has_class_field_flag f CfPublic then spr ctx "public "
			else spr ctx "private ";
			
			spr ctx (ident f.cf_name);
			spr ctx ": ";
			gen_type_hint ctx f.cf_type;
			spr ctx ";";
			newline ctx;
			ctx.tabs <- tabs_old
		) c.cl_ordered_fields;
		
		(* 构造函数 *)
		(match c.cl_constructor with
		| Some cf ->
			let tabs_old = ctx.tabs in
			ctx.tabs <- ctx.tabs ^ "\t";
			spr ctx "constructor() {";
			newline ctx;
			spr ctx "}";
			newline ctx;
			ctx.tabs <- tabs_old
		| None -> ());
		
		(* 方法 *)
		List.iter (fun f ->
			match f.cf_kind with
			| Method _ ->
				let tabs_old = ctx.tabs in
				ctx.tabs <- ctx.tabs ^ "\t";
				
				if has_class_field_flag f CfPublic then spr ctx "public "
				else spr ctx "private ";
				
				spr ctx (ident f.cf_name);
				spr ctx "(): ";
				gen_type_hint ctx f.cf_type;
				spr ctx " {";
				newline ctx;
				spr ctx "}";
				newline ctx;
				ctx.tabs <- tabs_old
			| _ -> ()
		) c.cl_ordered_fields;
		
		spr ctx "}";
		newline ctx;
	end;
	
	flush ctx

(* 枚举生成 *)
let generate_enum ctx e =
	let p = s_path ctx e.e_path in
	
	(* 使用TypeScript的联合类型和namespace来模拟Haxe枚举 *)
	spr ctx "export type ";
	spr ctx p;
	spr ctx " =";
	newline ctx;
	
	(* 枚举构造器 *)
	let first = ref true in
	List.iter (fun name ->
		let f = PMap.find name e.e_constrs in
		if not !first then begin
			newline ctx;
			spr ctx "| "
		end else begin
			spr ctx "  | ";
			first := false
		end;
		
		spr ctx "{ readonly _tag: \"";
		spr ctx name;
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
	spr ctx p;
	spr ctx " {";
	newline ctx;
	
	List.iter (fun name ->
		let f = PMap.find name e.e_constrs in
		let tabs_old = ctx.tabs in
		ctx.tabs <- ctx.tabs ^ "\t";
		
		(match f.ef_type with
		| TFun (args,_) ->
			spr ctx "export function ";
			spr ctx name;
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
			spr ctx p;
			spr ctx " {";
			newline ctx;
			spr ctx "\treturn { _tag: \"";
			spr ctx name;
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
			spr ctx name;
			spr ctx ": ";
			spr ctx p;
			spr ctx " = { _tag: \"";
			spr ctx name;
			spr ctx "\" };";
			newline ctx);
		
		ctx.tabs <- tabs_old
	) e.e_names;
	
	spr ctx "}";
	newline ctx;
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
	
	(* 生成所有类型 *)
	List.iter (generate_type ctx) com.types;
	
	(* 生成初始化代码 *)
	List.iter (fun e ->
		gen_expr ctx e;
		newline ctx
	) (List.rev ctx.inits);
	
	(* 生成静态初始化 *)
	List.iter (fun (_,_,e) ->
		gen_expr ctx e;
		newline ctx
	) (List.rev ctx.statics);
	
	(* 生成主函数调用 *)
	(match com.main.main_expr with
	| None -> ()
	| Some e ->
		gen_expr ctx e;
		newline ctx);
	
	flush ctx;
	
	(* 生成.d.ts文件 *)
	let generate_dts = true in
	if generate_dts then begin
		let dts_file = com.file ^ "d.ts" in
		ctx.dts_chan <- Some (open_out_bin dts_file);
		
		spr_dts ctx "// Generated by Haxe ";
		spr_dts ctx (s_version);
		newline_dts ctx;
		spr_dts ctx "// TypeScript Declaration File";
		newline_dts ctx;
		newline_dts ctx;
		
		(* TODO: 生成声明 *)
		
		flush_dts ctx;
		Option.may (fun chan -> close_out chan) ctx.dts_chan
	end;
	
	Option.may (fun chan -> close_out chan) ctx.chan