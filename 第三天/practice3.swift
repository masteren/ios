// 第 3 天练习:购物车(カート / cart)
// 运行:cd ~/Projects/ios/第三天 && swift practice3.swift
// 说明在 第三天.md「9. 今日练习」。TODO 从上往下按编号做,每做完一个运行一次。

// ------------------------
// 商品(已写好,不用改)
// ------------------------
struct Product {
    let id: Int
    let name: String
    let price: Int
    var stock: Int
}

// ------------------------
// 1. 购物车的一行 CartItem
// ------------------------
struct CartItem {
    // TODO: (1-a) 属性 product, quantity
    // product: Product(let) / quantity: Int(var)

    // TODO: (1-b) 计算属性 subtotal
    // 单价 × 数量
}

// ------------------------
// 2. 购物车 Cart
// ------------------------
struct Cart {
    // TODO: (2-a) 属性 items
    // [CartItem] 类型 / var / 默认值 []

    // TODO: (2-b) 计算属性 total
    // 所有 subtotal 的合计

    // TODO: (2-c) mutating 方法 add(_ product: Product, quantity: Int)
    // 已有同 id 的商品 → 用下标增加数量 / 没有 → append

    // TODO: (2-d) mutating 方法 remove(id: Int)
    // 删掉对应 id 的那一行
}

// ------------------------
// 3. 测试
// ------------------------
// TODO: (3-a) 添加商品
// let shirt = Product(id: 1, name: "T恤", price: 3000, stock: 5)
// let hat = Product(id: 2, name: "帽子", price: 1500, stock: 3)
//
// var cart = Cart()
// cart.add(shirt, quantity: 1)
// cart.add(hat, quantity: 2)
// cart.add(shirt, quantity: 1)
//
// for item in cart.items {
//     print("\(item.product.name) × \(item.quantity) = \(item.subtotal) 日元")
// }
// print("合计:", cart.total)
// print("行数:", cart.items.count)

// TODO: (3-b) 删除商品
// cart.remove(id: 2)
// print("删掉帽子后合计:", cart.total)

// ------------------------
// 4. 值语义
// ------------------------
// TODO: (4-a) 保存一份旧购物车
// saved ← cart → 往 cart 里加 hat 5 件 → 打印 saved.total 和 cart.total

// ------------------------
// 5. 读报错
// ------------------------
// TODO: (5-a) 删掉 add 的 mutating → 确认报错 → 恢复

// TODO: (5-b) var cart 改成 let cart → 确认报错 → 恢复

// TODO: (5-c) 在 add 里用 for item in items 改数量 → 确认报错 → 恢复

// ------------------------
// 6. 加分
// ------------------------
// TODO: (6-a) 把 Cart 改成 class → 再跑 (4-a)
// 复制成 practice3_class.swift / 写 init() {} / 删掉所有 mutating

print("✅ practice3.swift 运行结束")
