export class Std {
    public static ["string"](s: any): string {
        return String(s);
    }
}

console.log("Std[\"string\"](123) =", Std["string"](123));
console.log("Std[\"string\"](\"hello\") =", Std["string"]("hello"));
console.log("✅ 关键字字段测试通过！");
