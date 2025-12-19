import js.lib.Promise;
import haxe.Timer;

typedef UserData = {
    id: Int,
    name: String,
    email: String
}

/**
 * Haxe Async/Await 测试 Demo
 * 展示 Haxe 编译为原生 JavaScript async/await
 * 
 * 注意：此demo使用原生JS语法通过 js.Syntax 实现
 */
class AsyncAwaitTest {
    static function main() {
        trace("=== Haxe Async/Await Demo 开始 ===\n");
        
        // 运行所有测试场景
        runAllTests();
    }
    
    static function runAllTests() {
        trace("场景 1: 简单的 async/await");
        testSimpleAsync();
        
        trace("\n场景 2: 链式 await 调用");
        testChainedAwait();
        
        trace("\n场景 3: 并行异步操作");
        testParallelAsync();
        
        trace("\n场景 4: 错误处理");
        testErrorHandling();
        
        trace("\n场景 5: 实际应用 - 模拟 API 调用");
        testRealWorldExample();
    }
    
    // ========== 场景 1: 简单的 async 函数 ==========
    
    /**
     * 简单的异步延迟函数
     */
    static function delay(ms:Int):Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve('延迟 ${ms}ms 完成');
            }, ms);
        });
    }
    
    /**
     * 测试简单的 async/await
     */
    static function testSimpleAsync():Void {
        delay(1000).then(result -> {
            trace("开始延迟...");
            trace("结果: " + result);
        });
    }
    
    // ========== 场景 2: 链式 await 调用 ==========
    
    static function fetchUser(userId:Int):Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve('用户${userId}');
            }, 500);
        });
    }
    
    static function fetchUserProfile(userName:String):Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve('${userName}的个人资料');
            }, 500);
        });
    }
    
    static function fetchUserPosts(profile:String):Promise<Array<String>> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve(['${profile} - 帖子1', '${profile} - 帖子2', '${profile} - 帖子3']);
            }, 500);
        });
    }
    
    /**
     * 测试链式 await 调用
     */
    static function testChainedAwait():Void {
        trace("获取用户信息...");
        
        fetchUser(123)
            .then(user -> {
                trace("用户: " + user);
                trace("获取用户资料...");
                return fetchUserProfile(user);
            })
            .then(profile -> {
                trace("资料: " + profile);
                trace("获取用户帖子...");
                return fetchUserPosts(profile);
            })
            .then(posts -> {
                trace("帖子数量: " + posts.length);
                for (post in posts) {
                    trace("  - " + post);
                }
            });
    }
    
    // ========== 场景 3: 并行异步操作 ==========
    
    static function fetchData1():Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve("数据1");
            }, 800);
        });
    }
    
    static function fetchData2():Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve("数据2");
            }, 600);
        });
    }
    
    static function fetchData3():Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve("数据3");
            }, 400);
        });
    }
    
    /**
     * 测试并行异步操作
     */
    static function testParallelAsync():Void {
        trace("并行获取多个数据...");
        var startTime = Date.now().getTime();
        
        // 并行执行
        var promises = [
            fetchData1(),
            fetchData2(),
            fetchData3()
        ];
        
        Promise.all(promises).then(results -> {
            var endTime = Date.now().getTime();
            var elapsed = endTime - startTime;
            
            trace("所有数据已获取 (耗时: " + elapsed + "ms):");
            for (i in 0...results.length) {
                trace("  - " + results[i]);
            }
        });
    }
    
    // ========== 场景 4: 错误处理 ==========
    
    static function mayFailOperation(shouldFail:Bool):Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                if (shouldFail) {
                    reject("操作失败！");
                } else {
                    resolve("操作成功！");
                }
            }, 500);
        });
    }
    
    /**
     * 测试错误处理
     */
    static function testErrorHandling():Void {
        // 测试成功情况
        trace("测试成功情况...");
        mayFailOperation(false)
            .then(result -> {
                trace("结果: " + result);
                
                // 测试失败情况
                trace("测试失败情况...");
                return mayFailOperation(true);
            })
            .then(result -> {
                trace("结果: " + result);
            })
            .catchError(error -> {
                trace("捕获错误: " + error);
            });
    }
    
    // ========== 场景 5: 实际应用示例 ==========
    
    static function authenticateUser(username:String, password:String):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                // 模拟验证逻辑
                if (username == "admin" && password == "password") {
                    resolve(true);
                } else {
                    reject("认证失败");
                }
            }, 1000);
        });
    }
    
    static function getUserData(username:String):Promise<UserData> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve({
                    id: 1,
                    name: username,
                    email: username + "@example.com"
                });
            }, 800);
        });
    }
    
    static function loadUserDashboard(userData:UserData):Promise<String> {
        return new Promise((resolve, reject) -> {
            Timer.delay(() -> {
                resolve('欢迎, ${userData.name}! (邮箱: ${userData.email})');
            }, 600);
        });
    }
    
    /**
     * 测试实际应用场景 - 用户登录流程
     */
    static function testRealWorldExample():Void {
        trace("开始用户登录流程...");
        
        // 步骤 1: 认证用户
        trace("步骤 1: 认证用户...");
        authenticateUser("admin", "password")
            .then(authenticated -> {
                trace("认证状态: " + authenticated);
                
                // 步骤 2: 获取用户数据
                trace("步骤 2: 获取用户数据...");
                return getUserData("admin");
            })
            .then(userData -> {
                trace('用户数据: ID=${userData.id}, Name=${userData.name}');
                
                // 步骤 3: 加载用户仪表板
                trace("步骤 3: 加载仪表板...");
                return loadUserDashboard(userData);
            })
            .then(dashboard -> {
                trace("仪表板: " + dashboard);
                trace("\n✓ 登录流程完成！");
            })
            .catchError(error -> {
                trace("✗ 登录失败: " + error);
            });
    }
}