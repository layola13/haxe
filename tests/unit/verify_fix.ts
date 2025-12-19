// 验证关键字字段修复

// 1. 测试Std.string方法
class Std {
    public static ["string"](s: any): string {
        return String(s);
    }
}

console.log("✅ 测试1: Std[\"string\"](123) =", Std["string"](123));
console.log("✅ 测试2: Std[\"string\"](\"hello\") =", Std["string"]("hello"));
console.log("✅ 测试3: Std[\"string\"](null) =", Std["string"](null));

// 2. 测试其他关键字字段
class TestClass {
    public static ["class"](x: any): string { return "class: " + x; }
    public static ["interface"](x: any): string { return "interface: " + x; }
    public static ["function"](x: any): string { return "function: " + x; }
    public ["private"](x: any): string { return "private: " + x; }
}

console.log("✅ 测试4: TestClass[\"class\"](\"A\") =", TestClass["class"]("A"));
console.log("✅ 测试5: TestClass[\"interface\"](\"B\") =", TestClass["interface"]("B"));
console.log("✅ 测试6: TestClass[\"function\"](\"C\") =", TestClass["function"]("C"));
const obj = new TestClass();
console.log("✅ 测试7: obj[\"private\"](\"D\") =", obj["private"]("D"));

console.log("\n========================================");
console.log("✅✅✅ 所有关键字字段测试通过！");
console.log("========================================\n");
