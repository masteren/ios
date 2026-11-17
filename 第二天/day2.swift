// 第 2 天示范代码。运行:swift day2.swift
// 建议:自己一行一行敲,敲错了读一遍编译器报错。

// ---------- 1. Optional 是什么 ----------
let stocks = ["T恤": 5, "帽子": 0]
let a = stocks["T恤"]            // 类型是 Int?(可能有值,可能是 nil)
let b = stocks["鞋"]             // key 不存在 → nil
print(a as Any, b as Any)        // Optional(5) nil

var maybeStock: Int? = nil       // 显式声明一个 Optional
maybeStock = 3
print(maybeStock as Any)

// ---------- 2. ?? :nil 就用默认值 ----------
let s1 = stocks["T恤"] ?? 0      // 5
let s2 = stocks["鞋"] ?? 0       // 0
print(s1, s2)

// ---------- 3. if let :有值才执行 ----------
if let n = stocks["帽子"] {
    print("帽子库存 \(n)")        // 这里 n 是 Int,不是 Int?
} else {
    print("没有这个商品")
}

// ---------- 4. guard let :没值就提前退出 ----------
func describe(_ stock: Int?) -> String {
    guard let stock else { return "未知" }    // nil → 提前返回
    if stock == 0 { return "售罄" }
    return "剩 \(stock) 件"
}
print(describe(nil), describe(0), describe(7))

// ---------- 5. 强制解包 ! (危险) ----------
let sure = stocks["T恤"]!        // 确定有值才能用
print(sure)
// let boom = stocks["鞋"]!      // ❌ 取消注释:运行时崩溃 "unexpectedly found nil"

// ---------- 6. 可选链 ?. ----------
let name: String? = "T恤"
print(name?.count as Any)        // Optional(2)
let none: String? = nil
print(none?.count as Any)        // nil —— 不崩溃,整条链变成 nil
print(none?.count ?? 0)          // 0

// ---------- 7. 练习区:取消注释,读一遍报错 ----------
// let x: Int? = 5
// let y = x + 1                 // ❌ Int? 不能直接当 Int 用
// var z: Int = nil              // ❌ 普通 Int 不能是 nil
