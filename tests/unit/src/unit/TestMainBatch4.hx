package unit;

import utest.Runner;
import utest.ui.Report;

function main() {
    trace("START TypeScript Batch 4 Test");
    
    var classes = [
        new TestEReg(),
        new TestXML(),
        new TestMisc(),
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
