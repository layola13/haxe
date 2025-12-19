package unit;

import utest.Runner;
import utest.ui.Report;

function main() {
    trace("START TypeScript Batch 11 Test");
    
    var classes = [
        new TestBigInt(),
        new TestMatch(),
        new TestOverloadsForEveryone(),
    ];
    
    var runner = new Runner();
    for (c in classes) {
        runner.addCase(c);
    }
    var report = Report.create(runner);
    report.displayHeader = AlwaysShowHeader;
    report.displaySuccessResults = NeverShowSuccessResults;
    
    runner.run();
}
