class SimpleTypeScriptTest {
	static function main() {
		trace("=== TypeScript Simple Test ===");
		
		// 测试基础类型
		testBasicTypes();
		
		// 测试数组
		testArray();
		
		// 测试字符串
		testString();
		
		// 测试数学
		testMath();
		
		trace("=== All Tests Passed ===");
	}
	
	static function testBasicTypes() {
		trace("Testing basic types...");
		var i:Int = 42;
		var f:Float = 3.14;
		var s:String = "hello";
		var b:Bool = true;
		
		trace('  Int: $i');
		trace('  Float: $f');
		trace('  String: $s');
		trace('  Bool: $b');
	}
	
	static function testArray() {
		trace("Testing arrays...");
		var arr = [1, 2, 3, 4, 5];
		trace('  Length: ${arr.length}');
		trace('  First: ${arr[0]}');
		trace('  Last: ${arr[arr.length - 1]}');
		
		arr.push(6);
		trace('  After push: ${arr.length}');
		
		arr.pop();
		trace('  After pop: ${arr.length}');
	}
	
	static function testString() {
		trace("Testing strings...");
		var str = "Hello, World!";
		trace('  Original: $str');
		trace('  Length: ${str.length}');
		trace('  Upper: ${str.toUpperCase()}');
		trace('  Lower: ${str.toLowerCase()}');
		trace('  Substring: ${str.substr(0, 5)}');
	}
	
	static function testMath() {
		trace("Testing math...");
		trace('  PI: ${Math.PI}');
		trace('  sqrt(16): ${Math.sqrt(16)}');
		trace('  floor(3.7): ${Math.floor(3.7)}');
		trace('  ceil(3.2): ${Math.ceil(3.2)}');
		trace('  round(3.5): ${Math.round(3.5)}');
	}
}