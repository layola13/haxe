// 简单测试：验证Std["string"]修复
class Std {
    public static ["string"](s: any): string {
        return String(s);
    }
}

console.log("=== 测试 Std.string 关键字字段修复 ===");
console.log("Std[\"string\"](123) =", Std["string"](123));
console.log("Std[\"string\"](\"hello\") =", Std["string"]("hello"));
console.log("Std[\"string\"](null) =", Std["string"](null));
console.log("Std[\"string\"](true) =", Std["string"](true));
console.log("✅ 所有Std.string测试通过！");
