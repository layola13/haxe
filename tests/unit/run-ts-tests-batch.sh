#!/bin/bash

# 设置环境
export PATH=/tmp/neko-2.4.1-linux64:$PATH
cd "$(dirname "$0")"

HAXE="../../haxe"
FAILED=0
TOTAL=0

echo "========================================="
echo "TypeScript 单元测试 - 分批运行"
echo "========================================="

# 定义测试批次
declare -a BATCHES=(
    "TestOps,TestBasetypes,TestNumericSuffixes"
    "TestNumericSeparator,TestExceptions,TestBytes"
    "TestIO,TestLocals,TestLocalStatic"
    "TestEReg,TestXML,TestMisc"
    "TestJson,TestResource,TestInt64"
    "TestReflect,TestSerialize,TestMeta"
    "TestType,TestOrder,TestGADT"
    "TestGeneric,TestArrowFunctions,TestCasts"
    "TestSyntaxModule,TestNull,TestNullCoalescing"
    "TestNumericCasts,TestHashMap,TestRest"
    "TestBigInt,TestMatch,TestOverloadsForEveryone"
    "TestInterface,TestNaN,TestMapComprehension"
    "TestMacro,TestKeyValueIterator,TestFieldVariance"
    "TestConstrainedMonomorphs,TestDefaultTypeParameters"
)

for i in "${!BATCHES[@]}"; do
    BATCH_NUM=$((i + 1))
    TESTS="${BATCHES[$i]}"
    echo ""
    echo "批次 $BATCH_NUM/${#BATCHES[@]}: $TESTS"
    echo "-----------------------------------------"
    
    # 创建临时测试文件
    cat > src/unit/TestMainBatch.hx << EOF
package unit;

import utest.Runner;
import utest.ui.Report;

function main() {
    trace("START TypeScript Batch $BATCH_NUM Test");
    
    var classes = [
EOF
    
    # 添加测试类
    IFS=',' read -ra TEST_CLASSES <<< "$TESTS"
    for TEST_CLASS in "${TEST_CLASSES[@]}"; do
        echo "        new $TEST_CLASS()," >> src/unit/TestMainBatch.hx
    done
    
    cat >> src/unit/TestMainBatch.hx << EOF
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
EOF
    
    # 创建编译配置
    cat > compile-ts-batch.hxml << EOF
-D source-header=
--debug
-p src
--resource res1.txt@re/s?!%[]))("'1.txt
--resource res2.bin@re/s?!%[]))("'1.bin
--resource serializedValues.txt
--dce full
-lib utest
-D analyzer-optimize
-D analyzer-user-var-fusion
-D message.reporting=pretty
-D haxe-next
unit.TestMainBatch
--ts bin/unit-batch$BATCH_NUM.ts
EOF
    
    # 编译（30秒超时）
    TOTAL=$((TOTAL + 1))
    if timeout 30 $HAXE compile-ts-batch.hxml 2>&1 | grep -v "WDeprecatedEnumAbstract"; then
        echo "✓ 批次 $BATCH_NUM 编译成功"
        
        # 运行测试（5秒超时）
        if timeout 5 bun run bin/unit-batch$BATCH_NUM.ts 2>&1 > /dev/null; then
            echo "✓ 批次 $BATCH_NUM 运行成功"
        else
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 124 ]; then
                echo "✗ 批次 $BATCH_NUM 运行超时（5秒）"
            else
                echo "✗ 批次 $BATCH_NUM 运行失败"
            fi
            FAILED=$((FAILED + 1))
        fi
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "✗ 批次 $BATCH_NUM 编译超时（30秒）"
        else
            echo "✗ 批次 $BATCH_NUM 编译失败"
        fi
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "========================================="
echo "测试总结"
echo "========================================="
echo "总批次: $TOTAL"
echo "成功: $((TOTAL - FAILED))"
echo "失败: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo "✓ 所有测试批次编译成功！"
    exit 0
else
    echo "✗ 有 $FAILED 个批次编译失败"
    exit 1
fi