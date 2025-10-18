# Running Unit Tests for TypeScript Target

## Prerequisites

1. Build the Haxe compiler with TypeScript support
2. Set the standard library path: `export HAXE_STD_PATH=/root/Projects/haxe/std`
3. Install a TypeScript/JavaScript runtime (Bun, Node.js, or Deno)

## Simple Test

A standalone test without external dependencies:

```bash
cd tests/unit

# Compile
HAXE_STD_PATH=/root/Projects/haxe/std ../../haxe -main SimpleTypeScriptTest --ts bin/simple-test.ts

# Run with Bun
bun run bin/simple-test.ts

# Or run with Node.js
node bin/simple-test.ts

# Or run with Deno
deno run bin/simple-test.ts
```

## Full Unit Test Suite (requires utest)

The full unit test suite requires the `utest` library:

```bash
cd tests/unit

# Install utest (if haxelib is available)
haxelib install utest

# Compile
HAXE_STD_PATH=/root/Projects/haxe/std ../../haxe compile-ts.hxml

# Run
bun run bin/unit.ts
```

## Test Configuration Files

- **`compile-ts.hxml`** - Full unit test suite configuration (requires utest)
- **`SimpleTypeScriptTest.hx`** - Standalone test file without external dependencies

## What Tests Cover

The simple test covers:
- ✅ Basic types (Int, Float, String, Bool)
- ✅ Array operations (push, pop, access)
- ✅ String operations (length, toUpperCase, toLowerCase, substr)
- ✅ Math operations (PI, sqrt, floor, ceil, round)
- ✅ String interpolation

The full test suite (when utest is installed) covers:
- All basic types and operations
- Collections (Array, Map, IntMap, StringMap)
- Reflection and RTTI
- Exception handling
- Serialization
- And much more...

## Example Output

```
SimpleTypeScriptTest.hx:3: === TypeScript Simple Test ===
SimpleTypeScriptTest.hx:21: Testing basic types...
SimpleTypeScriptTest.hx:27:   Int: 42
SimpleTypeScriptTest.hx:28:   Float: 3.14
SimpleTypeScriptTest.hx:29:   String: hello
SimpleTypeScriptTest.hx:30:   Bool: true
SimpleTypeScriptTest.hx:34: Testing arrays...
SimpleTypeScriptTest.hx:36:   Length: 5
SimpleTypeScriptTest.hx:37:   First: 1
SimpleTypeScriptTest.hx:38:   Last: 5
...
SimpleTypeScriptTest.hx:17: === All Tests Passed ===
```

## Notes

- TypeScript target uses the same standard library as JavaScript (`std/ts/`)
- String interpolation (`$var` and `${expr}`) may have known issues in some contexts
- Resource embedding is partially supported
- The TypeScript target generates `.ts` files that can be run directly by modern runtimes