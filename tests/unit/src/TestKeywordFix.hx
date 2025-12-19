class TestKeywordFix {
    static function main() {
        trace("测试开始...");
        
        // 测试 Std.string - 这是关键字方法
        var result1 = Std.string(123);
        trace("Std.string(123) = " + result1);
        
        var result2 = Std.string("hello");
        trace("Std.string(\"hello\") = " + result2);
        
        var result3 = Std.string(null);
        trace("Std.string(null) = " + result3);
        
        trace("✅ 所有测试通过！");
    }
}
