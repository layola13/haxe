# Haxe 编译器重新编译指南

本指南说明如何重新编译 Haxe 编译器以启用原生 async/await 支持。

## 前提条件

在开始之前，确保你已安装以下工具：

### 必需工具

1. **OCaml** (版本 4.08 或更高)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install ocaml ocaml-native-compilers opam
   
   # macOS (使用 Homebrew)
   brew install ocaml opam
   
   # 初始化 opam
   opam init
   eval $(opam env)
   ```

2. **OCaml 依赖包**
   ```bash
   opam install dune sedlex xml-light extlib luv
   ```

3. **Neko VM** (可选，用于运行某些工具)
   ```bash
   # 从 https://nekovm.org/ 下载并安装
   ```

4. **构建工具**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install make pkg-config libpcre3-dev zlib1g-dev
   
   # macOS
   brew install pkg-config pcre
   ```

## 编译步骤

### 1. 克隆或导航到 Haxe 源码目录

```bash
cd /home/sonygod/projects/haxe
```

### 2. 清理之前的编译产物（如果有）

```bash
make clean
```

### 3. 编译编译器

有两种编译方法：

#### 方法 A：使用 Makefile（推荐）

```bash
# 编译 Haxe 编译器
make

# 或者使用并行编译加速
make -j4
```

#### 方法 B：使用 Dune 直接构建

```bash
# 编译
dune build

# 编译器位于 _build/default/main.exe
```

### 4. 验证编译结果

```bash
# 检查编译器版本
./haxe --version

# 或者如果使用 dune
./_build/default/main.exe --version
```

### 5. 安装编译器（可选）

```bash
# 安装到系统目录
sudo make install

# 或者创建符号链接
sudo ln -sf $(pwd)/haxe /usr/local/bin/haxe
```

## 编译输出

成功编译后，你会得到：

- `haxe` - Haxe 编译器可执行文件（或在 Windows 上为 `haxe.exe`）
- `haxelib` - Haxe 库管理器

## 验证 async/await 支持

### 1. 创建测试文件

```haxe
// Test.hx
class Test {
    @:async
    static function asyncFunction():js.lib.Promise<String> {
        var result = @:await js.lib.Promise.resolve("Hello");
        return js.lib.Promise.resolve(result + " World");
    }
    
    static function main() {
        asyncFunction().then(function(s) trace(s));
    }
}
```

### 2. 编译测试

```bash
./haxe -main Test -js test.js -D js-es=2017
```

### 3. 检查生成的 JavaScript

```bash
cat test.js | grep -A 5 "async function"
```

你应该看到类似这样的输出：
```javascript
async function asyncFunction() {
    var result = await Promise.resolve("Hello");
    return Promise.resolve(result + " World");
}
```

## 故障排除

### 问题 1：OCaml 版本不兼容

**错误信息**: `Error: The compiler doesn't support OCaml X.XX`

**解决方案**:
```bash
# 安装正确版本的 OCaml
opam switch create 4.14.0
eval $(opam env)
```

### 问题 2：缺少依赖

**错误信息**: `Error: Library 'sedlex' not found`

**解决方案**:
```bash
opam install sedlex xml-light extlib luv
```

### 问题 3：编译失败

**错误信息**: 各种编译错误

**解决方案**:
```bash
# 清理并重新编译
make clean
opam update
opam upgrade
make
```

### 问题 4：找不到 genjs.ml 的修改

**解决方案**:
确保你在正确的分支并且修改已保存：
```bash
git status
git diff src/generators/genjs.ml
```

## 性能优化编译选项

如果需要优化版本的编译器：

```bash
# 使用发布模式编译
dune build --release

# 或使用 Make
make OCAMLOPT=ocamlopt.opt
```

## 开发模式编译

如果你正在开发编译器并需要频繁重新编译：

```bash
# 启用快速编译（使用字节码）
dune build --profile dev

# 监听文件变化并自动重新编译
dune build --watch
```

## 交叉编译

### 编译 Windows 版本（在 Linux 上）

```bash
# 安装 MinGW
sudo apt-get install mingw-w64

# 配置交叉编译
opam install ocaml-windows

# 编译
make PLATFORM=windows
```

## 测试编译器

运行测试套件以确保编译器正常工作：

```bash
# 运行所有测试
cd tests
haxe RunCi.hxml

# 或只运行 JavaScript 目标测试
haxe RunCi.hxml -D js-only
```

## 额外资源

- [Haxe 编译器开发文档](https://github.com/HaxeFoundation/haxe/wiki)
- [OCaml 文档](https://ocaml.org/docs)
- [Dune 构建系统](https://dune.build/)

## 下一步

成功编译编译器后，请参阅：

1. `ASYNC_AWAIT_USAGE_GUIDE.md` - 如何使用 async/await 功能
2. `tests/async_await_native/` - 测试用例和示例
3. `TROUBLESHOOTING.md` - 常见问题和解决方案