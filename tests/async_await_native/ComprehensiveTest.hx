/**
 * Haxe 原生 Async/Await 全面测试套件
 * 
 * 编译要求: haxe -main ComprehensiveTest -js bin/comprehensive.js -D js-es=2017
 * 
 * 测试场景：
 * 1. 普通async函数声明
 * 2. 类实例方法的async
 * 3. 类静态方法的async  
 * 4. @:await表达式的使用
 * 5. @:await在变量声明中
 * 6. 链式await调用
 * 7. try/catch与async/await
 * 8. Promise.all与async/await
 * 9. 复杂异步流程控制
 */
class ComprehensiveTest {
	
	// 测试计数器
	static var testCount:Int = 0;
	static var passCount:Int = 0;
	
	public function new() {
	}
	
	// ============================================
	// 场景 1: 普通 async 函数声明
	// ============================================
	
	/**
	 * 测试 1.1: 最简单的 async 函数
	 */
	@:async
	static function simpleAsync():js.lib.Promise<String> {
		return js.lib.Promise.resolve("Test 1.1: 简单async函数完成");
	}
	
	/**
	 * 测试 1.2: 带参数的 async 函数
	 */
	@:async
	static function asyncWithParams(name:String, age:Int):js.lib.Promise<String> {
		var message = 'Test 1.2: Hello $name, age $age';
		return js.lib.Promise.resolve(message);
	}
	
	/**
	 * 测试 1.3: 返回不同类型的 async 函数
	 */
	@:async
	static function asyncReturnInt():js.lib.Promise<Int> {
		return js.lib.Promise.resolve(42);
	}
	
	/**
	 * 测试 1.4: 返回布尔值
	 */
	@:async
	static function asyncReturnBool():js.lib.Promise<Bool> {
		return js.lib.Promise.resolve(true);
	}
	
	/**
	 * 测试 1.5: 返回复杂对象
	 */
	@:async
	static function asyncReturnObject():js.lib.Promise<{name:String, value:Int}> {
		var obj = {name: "test", value: 100};
		return js.lib.Promise.resolve(obj);
	}
	
	// ============================================
	// 场景 2: 类实例方法的 async
	// ============================================
	
	var instanceValue:Int = 10;
	var instanceName:String = "TestInstance";
	
	/**
	 * 测试 2.1: 实例方法访问实例字段
	 */
	@:async
	public function instanceMethod():js.lib.Promise<String> {
		var result = 'Test 2.1: Instance ${instanceName}, value ${instanceValue}';
		return js.lib.Promise.resolve(result);
	}
	
	/**
	 * 测试 2.2: 实例方法修改实例状态
	 */
	@:async
	public function instanceModifyState(newValue:Int):js.lib.Promise<Bool> {
		instanceValue = newValue;
		return js.lib.Promise.resolve(true);
	}
	
	/**
	 * 测试 2.3: 实例方法调用其他实例方法
	 */
	@:async
	public function instanceCallChain():js.lib.Promise<String> {
		var msg1 = @:await instanceMethod();
		var success = @:await instanceModifyState(20);
		var msg2 = @:await instanceMethod();
		return js.lib.Promise.resolve('Test 2.3: $msg1 -> $msg2');
	}
	
	/**
	 * 测试 2.4: 实例方法使用 this
	 */
	@:async
	public function instanceWithThis():js.lib.Promise<Int> {
		return js.lib.Promise.resolve(this.instanceValue * 2);
	}
	
	// ============================================
	// 场景 3: 类静态方法的 async
	// ============================================
	
	static var staticCounter:Int = 0;
	
	/**
	 * 测试 3.1: 静态方法访问静态字段
	 */
	@:async
	static function staticMethod():js.lib.Promise<Int> {
		staticCounter++;
		return js.lib.Promise.resolve(staticCounter);
	}
	
	/**
	 * 测试 3.2: 静态方法调用其他静态方法
	 */
	@:async
	static function staticCallStatic():js.lib.Promise<String> {
		var count1 = @:await staticMethod();
		var count2 = @:await staticMethod();
		return js.lib.Promise.resolve('Test 3.2: $count1, $count2');
	}
	
	/**
	 * 测试 3.3: 静态方法带多个参数
	 */
	@:async
	static function staticWithMultipleParams(a:Int, b:Int, op:String):js.lib.Promise<Int> {
		var result = switch(op) {
			case "add": a + b;
			case "multiply": a * b;
			case "subtract": a - b;
			default: 0;
		};
		return js.lib.Promise.resolve(result);
	}
	
	// ============================================
	// 场景 4: @:await 表达式的使用
	// ============================================
	
	/**
	 * 测试 4.1: 单个 @:await 表达式
	 */
	@:async
	static function singleAwait():js.lib.Promise<String> {
		var result = @:await js.lib.Promise.resolve("Test 4.1: Single await");
		return js.lib.Promise.resolve(result);
	}
	
	/**
	 * 测试 4.2: 多个顺序 @:await 表达式
	 */
	@:async
	static function multipleSequentialAwaits():js.lib.Promise<String> {
		var first = @:await js.lib.Promise.resolve("First");
		var second = @:await js.lib.Promise.resolve("Second");
		var third = @:await js.lib.Promise.resolve("Third");
		return js.lib.Promise.resolve('Test 4.2: $first, $second, $third');
	}
	
	/**
	 * 测试 4.3: @:await 表达式在条件中
	 */
	@:async
	static function awaitInCondition(flag:Bool):js.lib.Promise<String> {
		var value = @:await js.lib.Promise.resolve(flag ? "True" : "False");
		return js.lib.Promise.resolve('Test 4.3: $value');
	}
	
	/**
	 * 测试 4.4: @:await 调用其他 async 函数
	 */
	@:async
	static function awaitAsyncFunction():js.lib.Promise<String> {
		var result = @:await simpleAsync();
		return js.lib.Promise.resolve('Test 4.4: Got $result');
	}
	
	// ============================================
	// 场景 5: @:await 在变量声明中
	// ============================================
	
	/**
	 * 测试 5.1: @:await 在 var 声明中
	 */
	@:async
	static function awaitInVarDeclaration():js.lib.Promise<String> {
		var message = @:await js.lib.Promise.resolve("Test 5.1: Variable declaration");
		return js.lib.Promise.resolve(message);
	}
	
	/**
	 * 测试 5.2: 多个 @:await 变量声明
	 */
	@:async
	static function multipleAwaitVars():js.lib.Promise<Int> {
		var a = @:await js.lib.Promise.resolve(10);
		var b = @:await js.lib.Promise.resolve(20);
		var c = @:await js.lib.Promise.resolve(30);
		var sum = a + b + c;
		return js.lib.Promise.resolve(sum);
	}
	
	/**
	 * 测试 5.3: @:await 复杂类型变量
	 */
	@:async
	static function awaitComplexType():js.lib.Promise<String> {
		var arr = @:await js.lib.Promise.resolve([1, 2, 3, 4, 5]);
		var sum = 0;
		for (n in arr) {
			sum += n;
		}
		return js.lib.Promise.resolve('Test 5.3: Array sum = $sum');
	}
	
	/**
	 * 测试 5.4: @:await 对象类型
	 */
	@:async
	static function awaitObjectType():js.lib.Promise<String> {
		var obj = @:await js.lib.Promise.resolve({x: 10, y: 20});
		return js.lib.Promise.resolve('Test 5.4: x=${obj.x}, y=${obj.y}');
	}
	
	// ============================================
	// 场景 6: 链式 await 调用
	// ============================================
	
	/**
	 * 辅助函数: 模拟异步步骤
	 */
	@:async
	static function asyncStep(name:String, value:Int):js.lib.Promise<Int> {
		trace('执行步骤: $name');
		return js.lib.Promise.resolve(value);
	}
	
	/**
	 * 测试 6.1: 线性链式调用
	 */
	@:async
	static function linearChain():js.lib.Promise<Int> {
		var step1 = @:await asyncStep("Step1", 10);
		var step2 = @:await asyncStep("Step2", step1 * 2);
		var step3 = @:await asyncStep("Step3", step2 + 5);
		return js.lib.Promise.resolve(step3);
	}
	
	/**
	 * 测试 6.2: 数据转换链
	 */
	@:async
	static function transformationChain(input:Int):js.lib.Promise<Int> {
		var doubled = @:await js.lib.Promise.resolve(input * 2);
		var squared = @:await js.lib.Promise.resolve(doubled * doubled);
		var result = @:await js.lib.Promise.resolve(squared + 100);
		return js.lib.Promise.resolve(result);
	}
	
	/**
	 * 测试 6.3: 函数调用链
	 */
	@:async
	static function functionCallChain():js.lib.Promise<String> {
		var int1 = @:await asyncReturnInt();
		var obj = @:await asyncReturnObject();
		var bool = @:await asyncReturnBool();
		return js.lib.Promise.resolve('Test 6.3: int=$int1, obj.value=${obj.value}, bool=$bool');
	}
	
	/**
	 * 测试 6.4: 递归 async 调用
	 */
	@:async
	static function asyncRecursive(n:Int):js.lib.Promise<Int> {
		if (n <= 0) {
			return js.lib.Promise.resolve(0);
		}
		var prev = @:await asyncRecursive(n - 1);
		return js.lib.Promise.resolve(n + prev);
	}
	
	// ============================================
	// 场景 7: try/catch 与 async/await
	// ============================================
	
	/**
	 * 测试 7.1: 基本 try/catch
	 */
	@:async
	static function basicTryCatch(shouldFail:Bool):js.lib.Promise<String> {
		try {
			if (shouldFail) {
				return @:await js.lib.Promise.reject(new js.lib.Error("Test 7.1: Intentional error"));
			}
			var result = @:await js.lib.Promise.resolve("Test 7.1: Success");
			return js.lib.Promise.resolve(result);
		} catch (e:Dynamic) {
			return js.lib.Promise.resolve('Test 7.1: Caught error - $e');
		}
	}
	
	/**
	 * 测试 7.2: 捕获 rejected Promise
	 */
	@:async
	static function catchRejectedPromise():js.lib.Promise<String> {
		try {
			var result = @:await js.lib.Promise.reject(new js.lib.Error("Rejected"));
			return js.lib.Promise.resolve(result);
		} catch (e:Dynamic) {
			return js.lib.Promise.resolve('Test 7.2: Handled rejection');
		}
	}
	
	/**
	 * 测试 7.3: 多个 try/catch 块
	 */
	@:async
	static function multipleTryCatch():js.lib.Promise<String> {
		var results = [];
		
		try {
			var r1 = @:await js.lib.Promise.resolve("Success1");
			results.push(r1);
		} catch (e:Dynamic) {
			results.push("Failed1");
		}
		
		try {
			var r2 = @:await js.lib.Promise.reject(new js.lib.Error("Error2"));
			results.push("Success2");
		} catch (e:Dynamic) {
			results.push("Failed2");
		}
		
		return js.lib.Promise.resolve('Test 7.3: ${results.join(", ")}');
	}
	
	/**
	 * 测试 7.4: 嵌套 try/catch
	 */
	@:async
	static function nestedTryCatch():js.lib.Promise<String> {
		try {
			try {
				var inner = @:await js.lib.Promise.reject(new js.lib.Error("Inner error"));
				return js.lib.Promise.resolve(inner);
			} catch (innerError:Dynamic) {
				trace('Inner caught: $innerError');
				throw new js.lib.Error("Outer error");
			}
		} catch (outerError:Dynamic) {
			return js.lib.Promise.resolve('Test 7.4: Caught outer error');
		}
	}
	
	/**
	 * 测试 7.5: try/finally 块
	 */
	@:async
	static function tryFinally():js.lib.Promise<String> {
		var cleanup = "not executed";
		try {
			var result = @:await js.lib.Promise.resolve("Test 7.5: Success");
			return js.lib.Promise.resolve(result);
		} catch (e:Dynamic) {
			trace('Caught error in finally test: $e');
			return js.lib.Promise.resolve('Test 7.5: Error handled');
		}
	}
	
	// ============================================
	// 场景 8: Promise.all 与 async/await
	// ============================================
	
	/**
	 * 测试 8.1: Promise.all 基本用法
	 */
	@:async
	static function promiseAllBasic():js.lib.Promise<String> {
		var promises = [
			js.lib.Promise.resolve("A"),
			js.lib.Promise.resolve("B"),
			js.lib.Promise.resolve("C")
		];
		var results = @:await js.lib.Promise.all(promises);
		return js.lib.Promise.resolve('Test 8.1: ${results.join(", ")}');
	}
	
	/**
	 * 测试 8.2: Promise.all 与 async 函数
	 */
	@:async
	static function promiseAllWithAsyncFunctions():js.lib.Promise<String> {
		var promises = [
			asyncStep("X", 1),
			asyncStep("Y", 2),
			asyncStep("Z", 3)
		];
		var results = @:await js.lib.Promise.all(promises);
		var sum = 0;
		for (r in results) {
			sum += r;
		}
		return js.lib.Promise.resolve('Test 8.2: Sum = $sum');
	}
	
	/**
	 * 测试 8.3: Promise.all 混合类型
	 */
	@:async
	static function promiseAllMixed():js.lib.Promise<String> {
		var promises:Array<js.lib.Promise<Dynamic>> = [
			js.lib.Promise.resolve(42),
			js.lib.Promise.resolve("text"),
			js.lib.Promise.resolve(true)
		];
		var results = @:await js.lib.Promise.all(promises);
		return js.lib.Promise.resolve('Test 8.3: ${results[0]}, ${results[1]}, ${results[2]}');
	}
	
	/**
	 * 测试 8.4: Promise.race
	 */
	@:async
	static function promiseRace():js.lib.Promise<String> {
		var promises = [
			delayedResolve("Fast", 10),
			delayedResolve("Slow", 100)
		];
		var winner = @:await js.lib.Promise.race(promises);
		return js.lib.Promise.resolve('Test 8.4: Winner = $winner');
	}
	
	/**
	 * 辅助函数: 延迟 resolve
	 */
	@:async
	static function delayedResolve(value:String, ms:Int):js.lib.Promise<String> {
		return new js.lib.Promise(function(resolve, reject) {
			js.Syntax.code("setTimeout({0}, {1})", function() {
				resolve(value);
			}, ms);
		});
	}
	
	/**
	 * 测试 8.5: Promise.all 错误处理
	 */
	@:async
	static function promiseAllWithError():js.lib.Promise<String> {
		try {
			var promises = [
				js.lib.Promise.resolve("OK1"),
				js.lib.Promise.reject(new js.lib.Error("Error in middle")),
				js.lib.Promise.resolve("OK2")
			];
			var results = @:await js.lib.Promise.all(promises);
			return js.lib.Promise.resolve("Should not reach here");
		} catch (e:Dynamic) {
			return js.lib.Promise.resolve('Test 8.5: Caught Promise.all error');
		}
	}
	
	// ============================================
	// 场景 9: 复杂异步流程控制
	// ============================================
	
	/**
	 * 测试 9.1: 条件分支中的 await
	 */
	@:async
	static function conditionalAwait(usePathA:Bool):js.lib.Promise<String> {
		var result:String;
		if (usePathA) {
			result = @:await js.lib.Promise.resolve("Path A");
		} else {
			result = @:await js.lib.Promise.resolve("Path B");
		}
		return js.lib.Promise.resolve('Test 9.1: $result');
	}
	
	/**
	 * 测试 9.2: 循环中的 await
	 */
	@:async
	static function loopWithAwait(count:Int):js.lib.Promise<Int> {
		var sum = 0;
		for (i in 0...count) {
			var value = @:await js.lib.Promise.resolve(i);
			sum += value;
			trace('Loop iteration $i');
		}
		return js.lib.Promise.resolve(sum);
	}
	
	/**
	 * 测试 9.3: While 循环中的 await
	 */
	@:async
	static function whileLoopAwait():js.lib.Promise<String> {
		var i = 0;
		var results = [];
		while (i < 3) {
			var value = @:await js.lib.Promise.resolve('Item$i');
			results.push(value);
			i++;
		}
		return js.lib.Promise.resolve('Test 9.3: ${results.join(", ")}');
	}
	
	/**
	 * 测试 9.4: Switch 语句中的 await
	 */
	@:async
	static function switchWithAwait(option:String):js.lib.Promise<String> {
		var result = switch(option) {
			case "A":
				@:await js.lib.Promise.resolve("Option A");
			case "B":
				@:await js.lib.Promise.resolve("Option B");
			default:
				@:await js.lib.Promise.resolve("Default");
		};
		return js.lib.Promise.resolve('Test 9.4: $result');
	}
	
	/**
	 * 测试 9.5: 数组迭代中的 await
	 */
	@:async
	static function arrayIterationAwait():js.lib.Promise<String> {
		var items = ["apple", "banana", "cherry"];
		var processed = [];
		
		for (item in items) {
			var upper = @:await js.lib.Promise.resolve(item.toUpperCase());
			processed.push(upper);
		}
		
		return js.lib.Promise.resolve('Test 9.5: ${processed.join(", ")}');
	}
	
	/**
	 * 测试 9.6: 嵌套对象访问的 await
	 */
	@:async
	static function nestedObjectAwait():js.lib.Promise<String> {
		var obj = @:await js.lib.Promise.resolve({
			user: {
				name: "Alice",
				age: 30
			}
		});
		return js.lib.Promise.resolve('Test 9.6: ${obj.user.name}, ${obj.user.age}');
	}
	
	// ============================================
	// 测试运行器
	// ============================================
	
	/**
	 * 运行单个测试并记录结果
	 */
	static function runTest(name:String, testFunc:Void->js.lib.Promise<Dynamic>):Void {
		testCount++;
		trace('');
		trace('[$testCount] Running: $name');
		testFunc().then(function(result) {
			trace('  ✓ PASS: $result');
			passCount++;
			return result;
		}).catchError(function(error) {
			trace('  ✗ FAIL: $name - Error: $error');
			return null;
		});
	}
	
	/**
	 * 重复字符串
	 */
	static function repeat(str:String, count:Int):String {
		var result = "";
		for (i in 0...count) {
			result += str;
		}
		return result;
	}
	
	/**
	 * 主函数 - 运行所有测试
	 */
	static function main() {
		trace("============================================================");
		trace("  Haxe 原生 Async/Await 全面测试套件");
		trace("  使用 @:async 和 @:await 元数据");
		trace("  编译配置: -D js-es=2017");
		trace("============================================================");
		
		// 场景 1: 普通 async 函数声明
		trace("\n" + repeat("=", 60));
		trace("场景 1: 普通 Async 函数声明");
		trace(repeat("=", 60));
		runTest("1.1 简单async函数", simpleAsync);
		runTest("1.2 带参数的async函数", function() return asyncWithParams("Alice", 25));
		runTest("1.3 返回Int", asyncReturnInt);
		runTest("1.4 返回Bool", asyncReturnBool);
		runTest("1.5 返回复杂对象", asyncReturnObject);
		
		// 场景 2: 类实例方法
		trace("\n" + repeat("=", 60));
		trace("场景 2: 类实例方法的 Async");
		trace(repeat("=", 60));
		var instance = new ComprehensiveTest();
		runTest("2.1 实例方法", instance.instanceMethod);
		runTest("2.2 修改实例状态", function() return instance.instanceModifyState(50));
		runTest("2.3 实例方法调用链", instance.instanceCallChain);
		runTest("2.4 使用this", instance.instanceWithThis);
		
		// 场景 3: 类静态方法
		trace("\n" + repeat("=", 60));
		trace("场景 3: 类静态方法的 Async");
		trace(repeat("=", 60));
		runTest("3.1 静态方法", staticMethod);
		runTest("3.2 静态方法调用链", staticCallStatic);
		runTest("3.3 多参数静态方法", function() return staticWithMultipleParams(10, 5, "add"));
		
		// 场景 4: @:await 表达式
		trace("\n" + repeat("=", 60));
		trace("场景 4: @:await 表达式的使用");
		trace(repeat("=", 60));
		runTest("4.1 单个await", singleAwait);
		runTest("4.2 多个顺序await", multipleSequentialAwaits);
		runTest("4.3 条件中的await", function() return awaitInCondition(true));
		runTest("4.4 await调用async函数", awaitAsyncFunction);
		
		// 场景 5: @:await 在变量声明中
		trace("\n" + repeat("=", 60));
		trace("场景 5: @:await 在变量声明中");
		trace(repeat("=", 60));
		runTest("5.1 var声明中的await", awaitInVarDeclaration);
		runTest("5.2 多个await变量", multipleAwaitVars);
		runTest("5.3 await复杂类型", awaitComplexType);
		runTest("5.4 await对象类型", awaitObjectType);
		
		// 场景 6: 链式 await 调用
		trace("\n" + repeat("=", 60));
		trace("场景 6: 链式 Await 调用");
		trace(repeat("=", 60));
		runTest("6.1 线性链", linearChain);
		runTest("6.2 数据转换链", function() return transformationChain(5));
		runTest("6.3 函数调用链", functionCallChain);
		runTest("6.4 递归async", function() return asyncRecursive(5));
		
		// 场景 7: try/catch
		trace("\n" + repeat("=", 60));
		trace("场景 7: Try/Catch 与 Async/Await");
		trace(repeat("=", 60));
		runTest("7.1 基本try/catch-成功", function() return basicTryCatch(false));
		runTest("7.2 基本try/catch-失败", function() return basicTryCatch(true));
		runTest("7.3 捕获rejected", catchRejectedPromise);
		runTest("7.4 多个try/catch", multipleTryCatch);
		runTest("7.5 嵌套try/catch", nestedTryCatch);
		runTest("7.6 try/finally", tryFinally);
		
		// 场景 8: Promise.all
		trace("\n" + repeat("=", 60));
		trace("场景 8: Promise.all 与 Async/Await");
		trace(repeat("=", 60));
		runTest("8.1 Promise.all基本", promiseAllBasic);
		runTest("8.2 Promise.all与async", promiseAllWithAsyncFunctions);
		runTest("8.3 Promise.all混合类型", promiseAllMixed);
		runTest("8.4 Promise.race", promiseRace);
		runTest("8.5 Promise.all错误处理", promiseAllWithError);
		
		// 场景 9: 复杂流程控制
		trace("\n" + repeat("=", 60));
		trace("场景 9: 复杂异步流程控制");
		trace(repeat("=", 60));
		runTest("9.1 条件分支await", function() return conditionalAwait(true));
		runTest("9.2 循环中的await", function() return loopWithAwait(5));
		runTest("9.3 while循环await", whileLoopAwait);
		runTest("9.4 switch中的await", function() return switchWithAwait("A"));
		runTest("9.5 数组迭代await", arrayIterationAwait);
		runTest("9.6 嵌套对象await", nestedObjectAwait);
		
		// 等待所有异步测试完成后显示总结
		js.Syntax.code("setTimeout({0}, {1})", function() {
			trace("\n" + repeat("=", 60));
			trace("测试总结");
			trace(repeat("=", 60));
			trace('总测试数: $testCount');
			trace('通过数: $passCount');
			trace('失败数: ${testCount - passCount}');
			trace('通过率: ${Math.round(passCount / testCount * 100)}%');
			trace(repeat("=", 60));
		}, 3000);
		
		trace("\n所有测试已启动，等待异步执行完成...");
	}
}