/**
 * 测试原生 async/await 功能
 * 需要使用 -D js-es=2017 或更高版本编译
 *
 * 使用原生 await 关键字语法
 */
class Main {
	/**
	 * 构造函数
	 */
	public function new() {
	}

	/**
	 * 简单的 async 函数示例 - 不返回值
	 */
	@:async
	static function simpleAsyncFunction():Void {
		trace("执行异步函数");
		// 使用原生 await 关键字
		await js.lib.Promise.resolve("完成");
		trace("异步操作完成");
	}

	/**
	 * 返回 Promise 的 async 函数
	 */
	@:async
	static function fetchData(url:String):js.lib.Promise<String> {
		trace('正在获取: $url');
		// 直接返回 Promise
		return js.lib.Promise.resolve('来自 $url 的数据');
	}

	/**
	 * 使用原生 await 的函数
	 */
	@:async
	static function fetchDataWithAwait(url:String):js.lib.Promise<String> {
		trace('正在获取: $url');
		// 使用原生 await 关键字
		var result:String = untyped await js.lib.Promise.resolve('来自 $url 的数据');
		return js.lib.Promise.resolve(result);
	}

	/**
	 * 顺序执行多个异步操作
	 */
	@:async
	static function sequentialOperations():js.lib.Promise<String> {
		trace("步骤1");
		await js.lib.Promise.resolve("步骤1");
		
		trace("步骤2");
		await js.lib.Promise.resolve("步骤2");
		
		trace("步骤3");
		await js.lib.Promise.resolve("步骤3");
		
		return js.lib.Promise.resolve("所有步骤完成");
	}

	/**
	 * 在类方法中使用 async
	 */
	@:async
	public function instanceMethod():js.lib.Promise<Int> {
		trace("实例方法开始");
		// 使用原生 await 关键字
		var value:Int = untyped await js.lib.Promise.resolve(42);
		var result = value * 2;
		trace('计算结果: $result');
		return js.lib.Promise.resolve(result);
	}

	/**
	 * 测试 async 函数调用链
	 */
	@:async
	static function chainedAsyncCalls():js.lib.Promise<String> {
		var data1:String = untyped await fetchData("https://127.0.0.1:6333");
		trace('获取到: $data1');
		
		var data2:String = untyped await fetchData("https://127.0.0.1:6333");
		trace('获取到: $data2');
		
		return js.lib.Promise.resolve(data1 + " + " + data2);
	}

	/**
	 * 带错误处理的 async 函数
	 */
	@:async
	static function fetchWithErrorHandling(shouldFail:Bool):js.lib.Promise<String> {
		try {
			if (shouldFail) {
				// 故意触发错误
				await js.lib.Promise.reject(new js.lib.Error("模拟错误"));
			}
			var data:String = untyped await js.lib.Promise.resolve("成功的数据");
			return js.lib.Promise.resolve(data);
		} catch (e:Dynamic) {
			trace('捕获错误: $e');
			return js.lib.Promise.reject(e);
		}
	}

	/**
	 * 主函数 - 运行所有测试
	 */
	static function main() {
		trace("=== Haxe 原生 Async/Await 测试 ===");
		trace("");
		
		trace("测试 1: 简单异步函数");
		simpleAsyncFunction();
		
		trace("");
		trace("测试 2: 获取数据（无 await）");
		fetchData("https://example.com").then(function(result) {
			trace('结果: $result');
		});
		
		trace("");
		trace("测试 3: 获取数据（有 await）");
		fetchDataWithAwait("https://example2.com").then(function(result) {
			trace('结果: $result');
		});
		
		trace("");
		trace("测试 4: 顺序操作");
		sequentialOperations().then(function(result) {
			trace('最终结果: $result');
		});
		
		trace("");
		trace("测试 5: 实例方法");
		var instance = new Main();
		instance.instanceMethod().then(function(result) {
			trace('实例方法结果: $result');
		});
		
		trace("");
		trace("测试 6: 链式调用");
		chainedAsyncCalls().then(function(result) {
			trace('链式调用结果: $result');
		});
		
		trace("");
		trace("测试 7: 错误处理 - 成功情况");
		fetchWithErrorHandling(false).then(function(result) {
			trace('成功: $result');
		},function(error) {
			trace('失败: $error');
		});
		
		trace("");
		trace("测试 8: 错误处理 - 失败情况");
		fetchWithErrorHandling(true).then(function(result) {
			trace('成功: $result');
		},function(error) {
			trace('预期的失败: $error');
		});
		
		trace("");
		trace("=== 所有测试已启动 ===");
	}
}