// 第 3 天:struct 和值语义
// 运行:cd ~/Projects/ios/第三天 && swift day3.swift
// 说明在 第三天.md。TODO 从上往下按编号做,每做完一个运行一次。

// ------------------------
// 商品 struct
// ------------------------
struct Product {
    let id: Int
    let name: String
    let price: Int
    var stock: Int

    // TODO: (2-a) 计算属性 isSoldOut
    // var isSoldOut: Bool {
    //     stock == 0
    // }

    // TODO: (2-b) 计算属性 priceWithTax
    // 含税价格 = price * 110 / 100

    // TODO: (2-c) 方法 label()
    // func label() -> String {
    //     if isSoldOut {
    //         return "\(name)(售罄)"
    //     }
    //     return "\(name) 剩 \(stock) 件"
    // }

    // TODO: (4-a) mutating 方法 sell()
    // mutating func sell(_ count: Int) {
    //     // TODO: (4-c) 库存检查:不够时 print("库存不足") 然后 return(guard)
    //     stock -= count
    // }

    // TODO: (4-d) mutating 方法 restock()
    // 补货:stock 加上 count
}

// ------------------------
// 1. 创建实例
// ------------------------
// TODO: (1-a) 创建实例 shirt
// let shirt = Product(id: 1, name: "T恤", price: 3000, stock: 5)
// print(shirt.name, shirt.price, shirt.stock)

// TODO: (1-b) 创建实例 cap
// id: 2 / name: "帽子" / price: 1500 / stock: 0 → 打印 name 和 stock

// TODO: (1-c) 参数顺序写反 → 确认报错 → 注释回去
// let wrong = Product(name: "包", id: 3, price: 5000, stock: 1)

// ------------------------
// 2. 计算属性和方法
// ------------------------
// TODO: (2-a) 读取 isSoldOut
// print(shirt.isSoldOut)
// print(cap.isSoldOut)

// TODO: (2-b) 读取 priceWithTax
// shirt → 3300

// TODO: (2-c) 调用 label()
// print(shirt.label())
// print(cap.label())

// ------------------------
// 3. let / var
// ------------------------
// TODO: (3-a) var 实例的修改
// var bag = Product(id: 3, name: "包", price: 5000, stock: 3)
// bag.stock = 2
// print(bag.stock)

// TODO: (3-b) 修改 let 属性 → 确认报错 → 注释回去
// bag.name = "钱包"

// TODO: (3-c) 修改 let 实例 → 确认报错 → 注释回去
// shirt.stock = 0

// ------------------------
// 4. mutating
// ------------------------
// TODO: (4-b) 调用 sell()
// bag.sell(1)
// print(bag.label())

// TODO: (4-c) 确认库存不足
// bag.sell(10)
// print(bag.stock)

// TODO: (4-d) 调用 restock()
// bag 补货 5 件 → 打印 stock

// TODO: (4-e) let 实例调用 mutating 方法 → 确认报错 → 注释回去
// shirt.sell(1)

// ------------------------
// 5. 值语义
// ------------------------
// TODO: (5-a) 赋值 = 复制
// var copy = bag
// copy.stock = 0
// print(bag.stock, copy.stock)

// TODO: (5-b) 修改原来的 bag
// bag.stock = 99 → 打印 bag.stock 和 copy.stock

// ------------------------
// 6. 数组里的 struct
// ------------------------
// TODO: (6-a) 商品数组
// var products = [
//     Product(id: 1, name: "T恤", price: 3000, stock: 5),
//     Product(id: 2, name: "帽子", price: 1500, stock: 3),
// ]

// TODO: (6-b) 用 for-in 修改 → 确认报错 → 注释回去
// for p in products { p.stock = 0 }

// TODO: (6-c) 用 for var 修改 → 确认没有变化
// for var p in products { p.stock = 0 }
// print(products[0].stock, products[1].stock)

// TODO: (6-d) 用下标修改
// for i in products.indices { products[i].stock = 0 }
// print(products[0].stock, products[1].stock)

// TODO: (6-e) 更新服务器发来的库存(参考 AppState.swift)
// let stocks = ["1": 4] → T恤: 4 / 帽子: 0

// ------------------------
// 7. 函数参数
// ------------------------
// TODO: (7-a) 在函数里修改参数 → 确认报错 → 注释回去
// func clearStockWrong(_ p: Product) {
//     p.stock = 0
// }

// TODO: (7-b) 返回一个新值
// func clearStock(_ p: Product) -> Product {
//     var copy = p
//     copy.stock = 0
//     return copy
// }
// let cleared = clearStock(bag)
// print(bag.stock, cleared.stock)

// TODO: (7-c) 函数 discounted()
// 返回八折(price * 8 / 10)的新 Product

// ------------------------
// 8. class
// ------------------------
// TODO: (8-a) 定义 class ProductRef
// class ProductRef {
//     let name: String
//     var stock: Int
//
//     init(name: String, stock: Int) {
//         self.name = name
//         self.stock = stock
//     }
// }

// TODO: (8-b) 赋值 = 共享
// let r1 = ProductRef(name: "T恤", stock: 5)
// let r2 = r1
// r2.stock = 0
// print(r1.stock, r1 === r2)

// TODO: (8-c) 删掉 init → 确认报错 → 恢复

// TODO: (8-d) 给 let 的 r2 赋另一个对象 → 确认报错 → 注释回去
// r2 = ProductRef(name: "帽子", stock: 1)

print("✅ day3.swift 运行结束")
