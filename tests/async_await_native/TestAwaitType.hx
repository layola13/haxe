@:async
class TestAwaitType {
    static function main() {
        test().then(function(x) trace("Result: " + x));
    }
    
    @:async
    static function test():js.lib.Promise<Int> {
        // 测试 await 的类型推断
        var x:Int = await js.lib.Promise.resolve(42);
        trace("x = " + x);
        return js.lib.Promise.resolve(x + 1);
    }
}