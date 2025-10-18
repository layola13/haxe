package ts;

@:keep
class Boot {
	static function __string_rec(o:Dynamic, s:String):String {
		if (o == null)
			return "null";
		if (s.length >= 5)
			return "<...>";
		var t = js.Syntax.code("typeof {0}", o);
		
		switch (t) {
			case "function":
				return "<function>";
			case "object":
				if (js.Syntax.instanceof(o, Array)) {
					var str = "[";
					s += "\t";
					var a:Array<Dynamic> = o;
					for (i in 0...a.length) {
						str += (i > 0 ? "," : "") + __string_rec(a[i], s);
					}
					str += "]";
					return str;
				}
				
				// Try toString first
				var tostr = try o.toString catch (_:Dynamic) null;
				if (tostr != null && tostr != js.Syntax.code("Object.toString") && js.Syntax.code("typeof {0} == \"function\"", tostr)) {
					var s2 = o.toString();
					if (s2 != "[object Object]")
						return s2;
				}
				
				var str = "{\n";
				s += "\t";
				var hasp = untyped o.hasOwnProperty != null;
				
				// Use Object.keys to get object keys
				var fields:Array<String> = untyped js.Syntax.code("Object.keys({0})", o);
				var i = 0;
				while (i < fields.length) {
					var k = fields[i++];
					if (hasp && !untyped o.hasOwnProperty(k))
						continue;
					if (k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__")
						continue;
					if (str.length != 2)
						str += ", \n";
					str += s + k + " : " + __string_rec(untyped o[k], s);
				}
				
				s = s.substring(1);
				str += "\n" + s + "}";
				return str;
			case "string":
				return o;
			default:
				return js.Syntax.code("String({0})", o);
		}
	}
}