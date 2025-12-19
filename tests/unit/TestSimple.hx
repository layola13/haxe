class TestSimple {
    public function new() {
        trace("Created");
    }
    public static function main() {
        var t = new TestSimple();
        trace(Type.getClass(t));
    }
}
