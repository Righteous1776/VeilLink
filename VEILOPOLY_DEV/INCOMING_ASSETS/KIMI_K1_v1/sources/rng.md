# 确定性 RNG 规格 · SplitMix64（引擎唯一随机源）

> 联机一致性的根：所有客户端对同一 `seed` + 同一 move 序列必须逐位重放出同一状态。
> 规则：引擎内任何随机性（骰子、洗牌、AI 随机化）只能经由此 RNG；禁止 `Date()`、`UUID()`、
> `Int.random`、`arc4random`、浮点排序进入引擎。Swift/JS/Python 均可按此规格实现并对齐测试向量。

## 算法（SplitMix64）

```
常量 GOLDEN = 0x9E3779B97F4A7C15
state: UInt64（初值 = seed，每次 next 前 state += GOLDEN，溢出回绕——必须按 UInt64 运算）

next():
  state = state + GOLDEN            (mod 2^64)
  z = state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9   (mod 2^64)
  z = (z ^ (z >> 27)) * 0x94D049BB133111EB   (mod 2^64)
  return z ^ (z >> 31)              (mod 2^64)
```

## Swift 参考实现

```swift
struct SeededRNG: Codable, Equatable {
    private(set) var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func die() -> Int { Int(next() % 6) + 1 }        // 1...6
    mutating func dice() -> (Int, Int) { (die(), die()) }     // 一次双骰消耗 2 次 next
    mutating func pick(_ n: Int) -> Int { Int(next() % UInt64(n)) }  // 0..<n，用于洗牌/AI
}
```

## 测试向量（验收 Gate：实现必须全部通过才算正确）

seed = 42：

| 调用 | 预期 UInt64（十进制） | 十六进制 | 若取 die() |
|---|---|---|---|
| next()[0] | 13679457532755275413 | 0xBDD732262FEB6E95 | 2 |
| next()[1] | 2949826092126892291 | 0x28EFE333B266F103 | 2 |
| next()[2] | 5139283748462763858 | 0x47526757130F9F52 | 1 |
| next()[3] | 6349198060258255764 | 0x581CE1FF0E4AE394 | 1 |
| next()[4] | 701532786141963250 | 0x09BC585A244823F2 | 5 |
| next()[5] | 16015981125662989062 | 0xDE4431FA3C80DB06 | 1 |

洗牌向量：seed=7，对 [0..15] 做 Fisher–Yates（`for i in 15...1: j = next() % (i+1); swap(i,j)`）：

```
[14, 6, 4, 2, 5, 11, 13, 1, 3, 12, 15, 10, 8, 0, 9, 7]
```

> 本向量由 Python 参照实现生成；ChatGPT 的 Swift 实现跑通这两组向量即证明跨语言确定性对齐。

## 集成规则

1. `G.seed` 由房主在开局生成（可用系统 RNG 生成 seed 本身——seed 的熵来源不受限，进入引擎后冻结）。
2. `G.rngCounter` 记录引擎内 RNG 调用次数，重放时用于断言对齐（counter 不一致 = 实现漂移，立即 fail）。
3. 洗牌固定发生在引擎初始化（两副牌各一次 shuffle，顺序：chance 先、che st 后），之后抽牌只移动 cursor，不再消耗 RNG——避免抽卡时机影响后续骰子序列。
4. AI「思考随机性」（如随机延迟扰动、多解等概率选招）也走同一 RNG 尾部，并计入 rngCounter。
