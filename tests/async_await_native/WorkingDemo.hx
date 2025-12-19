/**
 * 演示当前 async 支持的工作示例
 * 注意：await 需要 Haxe 编译器的核心支持，目前我们已经实现了：
 * 1. @:async 元数据 → 生成 async 关键字 ✓
 * 2. @:await 元数据处理逻辑 ✓
 * 
 * 限制：由于 Haxe 类型系统的限制，await 的完整支持需要编译器前端的更多修改
 */
class WorkingDemo {
	public function new() {
	}
	
	/**
	 * 示例 1: 基本的 async 函数（无 await）
	 */
	@:async
	static function basicAsync():js.lib.Promise<String> {
		trace("基本异步函数");
		return js.lib.Promise.resolve("完成");
	}
	
	/**
	 * 示例 2: 返回 Promise 的 async 函数
	 */
	@:async
	static function fetchUser(id:Int):js.lib.Promise<String> {
		trace('获取用户 $id');
		return js.lib.Promise.resolve('用户 $id 数据');
	}
	
	/**
	 * 示例 3: async 实例方法
	 */
	@:async
	public function saveData(data:String):js.lib.Promise<Bool> {
		trace('保存数据: $data');
		return js.lib.Promise.resolve(true);
	}
	
	/**
	 * 示例 4: 使用 Promise API 的 async 函数
	 */
	@:async
	static function processData():js.lib.Promise<Int> {
		return js.lib.Promise.resolve(42)
			.then(function(value) {
				return value * 2;
			});
	}
	
	static function main() {
		trace("=== Haxe Async/Await 演示 ===");
		trace("");
		
		trace("✓ async 关键字已成功实现");
		trace("✓ 生成正确的 ES2017+ JavaScript");
		trace("");
		
		trace("测试 1: 基本 async 函数");
		basicAsync().then(function(result) {
			trace('结果: $result');
		});
		
		trace("");
		trace("测试 2: async 函数调用链");
		fetchUser(123).then(function(user) {
			trace('获取到: $user');
			return fetchUser(456);
		}).then(function(user) {
			trace('获取到: $user');
		});
		
		trace("");
		trace("测试 3: async 实例方法");
		var demo = new WorkingDemo();
		demo.saveData("重要数据").then(function(success) {
			trace('保存${success ? "成功" : "失败"}');
		});
		
		trace("");
		trace("测试 4: Promise 链式调用");
		processData().then(function(result) {
			trace('处理结果: $result');
		});
		
		trace("");
		trace("=== 所有测试已启动 ===");
	}
}