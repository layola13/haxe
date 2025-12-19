class TestNativeAsync {
    static function main() {
        testAsync().then(function(result) {
            trace("最终结果: " + result);
        });
    }
    
    // 使用原生 async 关键字（不使用 @:async 元数据）
    static async function testAsync():js.lib.Promise<Int> {
        trace("开始异步测试...");
        
        var x:Int = await js.lib.Promise.resolve(42);
        trace("x = " + x);
        
        var y:Int = await js.lib.Promise.resolve(10);
        trace("y = " + y);
        
        return js.lib.Promise.resolve(x + y);
    }
    
    // 测试类方法中的 async
    static async function add(a:Int, b:Int):js.lib.Promise<Int> {
        var result:Int = await js.lib.Promise.resolve(a + b);
        return js.lib.Promise.resolve(result);
    }
}