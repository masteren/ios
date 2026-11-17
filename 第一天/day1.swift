// 第 1 天示范代码。运行:swift day1.swift
// 建议:不要复制粘贴,自己一行一行敲,敲错了读一遍编译器报错。

// ---------- 1. 打印 ----------
print("Hello, Swift!")            // 相当于 Python 的 print("Hello, Swift!")

// ---------- 2. let 和 var ----------
let name = "T恤"                  // let:常量,赋值后不能再改
var stock = 5                     // var:变量,可以改
stock = 4                         // ✅ OK
stock = stock - 1                 // ✅ OK,现在是 3
print(name, stock)

// ---------- 3. 类型推断 与 显式类型 ----------
let price = 3000                  // 编译器看到整数 → 推断为 Int
let rate = 0.1                    // 小数 → 推断为 Double
let isActive = true               // → Bool
let title = "夏季新品"             // → String

let price2: Int = 3000            // 显式写类型,效果一样
let discount: Double = 0.8
// 注意:Int 和 Double 不能直接混着算,要手动转换
let finalPrice = Double(price) * discount
print("折后价:", finalPrice)       // 2400.0

// ---------- 4. 字符串插值 ----------
print("商品 \(name),价格 \(price) 日元,库存 \(stock) 件")
print("折后 \(Int(finalPrice)) 日元")   // Int(...) 把 Double 转成 Int(去掉小数)

// ---------- 5. 数组 与 字典 ----------
var names = ["T恤", "帽子", "包"]      // 推断为 [String]
names.append("鞋")
print(names[0], names.count)           // T恤 4

var stocks = ["T恤": 5, "帽子": 0]     // 推断为 [String: Int]
stocks["包"] = 8
print(stocks["T恤"] as Any)            // Optional(5) —— 注意!字典取值可能没有,所以返回 Int?(明天细讲)

// ---------- 6. 循环 ----------
for n in names {
    print("商品:", n)
}
for i in 1...3 {                       // 1...3 表示 1、2、3(含 3)
    print("第 \(i) 次")
}

// ---------- 7. 练习区:取消注释,读一遍报错 ----------
name = "帽子"          // ❌ let 不能重新赋值
stock = "五"           // ❌ Int 不能赋字符串
let total = price * rate   // ❌ Int 和 Double 不能直接相乘
