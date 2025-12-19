@:async
class TestMinimal {
    static function main() {
        test();
    }
    
    @:async
    static function test():js.lib.Promise<Int> {
        var x:Int = await js.lib.Promise.resolve(42);
        trace(x);
        return js.lib.Promise.resolve(x);
    }
}