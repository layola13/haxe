class TestDoWhile {
    static function main() {
        var i = 0;
        do {
            trace(i);
            i++;
        } while (i < 5);
        
        var j = 0;
        do j++ while (j < 3);
    }
}
