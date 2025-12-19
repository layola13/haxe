package unit;

import utest.Runner;
import utest.ui.Report;

function main() {
    trace("START TypeScript Batch 13 Test");
    
    var classes = [
        new TestMacro(),
        new TestKeyValueIterator(),
        new TestFieldVariance(),
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
