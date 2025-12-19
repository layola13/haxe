// 预期生成的 JavaScript 代码示例
// 这展示了 @:async 和 @:await 元数据如何转换为原生 JavaScript async/await

// 简单的 async 函数
async function simpleAsyncFunction() {
	console.log("执行异步函数");
	await Promise.resolve("完成");
	console.log("异步操作完成");
}

// 返回 Promise 的 async 函数
async function fetchData(url) {
	console.log("正在获取: " + url);
	var result = await Promise.resolve("来自 " + url + " 的数据");
	return Promise.resolve(result);
}

// 带错误处理的 async 函数
async function fetchWithErrorHandling(shouldFail) {
	try {
		if(shouldFail) {
			await Promise.reject(new Error("模拟错误"));
		}
		var data = await Promise.resolve("成功的数据");
		return Promise.resolve(data);
	} catch( e ) {
		console.log("捕获错误: " + e);
		return Promise.reject(e);
	}
}

// 顺序执行多个异步操作
async function sequentialOperations() {
	var result1 = await Promise.resolve("步骤1");
	console.log(result1);
	var result2 = await Promise.resolve("步骤2");
	console.log(result2);
	var result3 = await Promise.resolve("步骤3");
	console.log(result3);
	return Promise.resolve("所有步骤完成");
}

// 类中的 async 方法
class Main {
	async instanceMethod() {
		var value = await Promise.resolve(42);
		return Promise.resolve(value * 2);
	}
}

// 链式 async 调用
async function chainedAsyncCalls() {
	var data1 = await fetchData("https://api.example.com/data1");
	console.log("获取到: " + data1);
	var data2 = await fetchData("https://api.example.com/data2");
	console.log("获取到: " + data2);
	return Promise.resolve(data1 + " + " + data2);
}