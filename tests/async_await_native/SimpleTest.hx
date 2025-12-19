/**
 * 简单的 await 测试
 */
class SimpleTest {
	@:async
	static function testAwait():js.lib.Promise<String> {
		trace("开始");
		
		// 直接使用 @:await 元数据
		var result = @:await js.lib.Promise.resolve("测试数据");
		
		trace('结果: $result');
		return js.lib.Promise.resolve(result);
	}
	
	static function main() {
		trace("=== 简单 Await 测试 ===");
		testAwait().then(function(r) {
			trace('完成: $r');
		});
	}
}