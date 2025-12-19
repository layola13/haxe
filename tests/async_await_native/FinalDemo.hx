/**
 * Haxe JS Async/Await 最终演示
 * 使用 js.Syntax.code 直接生成 await 关键字
 */
class FinalDemo {
	public function new() {
	}
	
	/**
	 * 示例 1: 使用 js.Syntax.code 生成 await
	 */
	@:async
	static function fetchDataWithAwait(url:String):js.lib.Promise<String> {
		trace('正在获取: $url');
		// 使用 js.Syntax.code 直接生成 await 表达式
		var result:String = js.Syntax.code("await {0}", js.lib.Promise.resolve('来自 $url 的数据'));
		trace('获取到: $result');
		return js.lib.Promise.resolve(result);
	}
	
	/**
	 * 示例 2: 顺序执行多个 await 操作
	 */
	@:async
	static function sequentialAwait():js.lib.Promise<String> {
		trace("开始顺序操作");
		
		var data1:String = js.Syntax.code("await {0}", js.lib.Promise.resolve("数据1"));
		trace('获取到: $data1');
		
		var data2:String = js.Syntax.code("await {0}", js.lib.Promise.resolve("数据2"));
		trace('获取到: $data2');
		
		var data3:String = js.Syntax.code("await {0}", js.lib.Promise.resolve("数据3"));
		trace('获取到: $data3');
		
		return js.lib.Promise.resolve(data1 + ", " + data2 + ", " + data3);
	}
	
	/**
	 * 示例 3: async 实例方法中使用 await
	 */
	@:async
	public function processData(value:Int):js.lib.Promise<Int> {
		trace('处理数据: $value');
		
		var step1:Int = js.Syntax.code("await {0}", js.lib.Promise.resolve(value * 2));
		trace('步骤1结果: $step1');
		
		var step2:Int = js.Syntax.code("await {0}", js.lib.Promise.resolve(step1 + 10));
		trace('步骤2结果: $step2');
		
		return js.lib.Promise.resolve(step2);
	}
	
	/**
	 * 示例 4: 错误处理
	 */
	@:async
	static function withErrorHandling(shouldFail:Bool):js.lib.Promise<String> {
		try {
			trace("开始操作");
			
			if (shouldFail) {
				var error:Dynamic = js.Syntax.code("await {0}", 
					js.lib.Promise.reject(new js.lib.Error("模拟错误")));
			}
			
			var result:String = js.Syntax.code("await {0}", 
				js.lib.Promise.resolve("成功的数据"));
			
			return js.lib.Promise.resolve(result);
		} catch (e:Dynamic) {
			trace('捕获错误: $e');
			return js.lib.Promise.reject(e);
		}
	}
	
	/**
	 * 示例 5: 函数调用链
	 */
	@:async
	static function chainedCalls():js.lib.Promise<String> {
		var data1:String = js.Syntax.code("await {0}", fetchDataWithAwait("https://api1.com"));
		trace('第一次调用: $data1');
		
		var data2:String = js.Syntax.code("await {0}", fetchDataWithAwait("https://api2.com"));
		trace('第二次调用: $data2');
		
		return js.lib.Promise.resolve('$data1 + $data2');
	}
	
	static function main() {
		trace("=== Haxe 完整 Async/Await 演示 ===");
		trace("");
		
		trace("测试 1: 基本 await 用法");
		fetchDataWithAwait("https://example.com").then(function(result) {
			trace('最终结果: $result');
		});
		
		trace("");
		trace("测试 2: 顺序 await 操作");
		sequentialAwait().then(function(result) {
			trace('顺序操作结果: $result');
		});
		
		trace("");
		trace("测试 3: 实例方法中的 await");
		var demo = new FinalDemo();
		demo.processData(5).then(function(result) {
			trace('处理结果: $result');
		});
		
		trace("");
		trace("测试 4: 错误处理 - 成功情况");
		withErrorHandling(false).then(function(result) {
			trace('成功: $result');
		}, function(error) {
			trace('失败: $error');
		});
		
		trace("");
		trace("测试 5: 错误处理 - 失败情况");
		withErrorHandling(true).then(function(result) {
			trace('成功: $result');
		}, function(error) {
			trace('预期的失败: $error');
		});
		
		trace("");
		trace("测试 6: 函数调用链");
		chainedCalls().then(function(result) {
			trace('调用链结果: $result');
		});
		
		trace("");
		trace("=== 所有测试已启动 ===");
	}
}