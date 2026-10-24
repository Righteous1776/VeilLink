import Foundation

// VeilLink RareLab: pure, offline, manual-input analysis. No I/O, storage,
// key access, transport mutation, location collection, or network connection.
// This is deliberately independent of Mission Control R1 (20 features).

enum VeilRareLabError: Error, LocalizedError {
    case badInput(String)
    var errorDescription: String? {
        switch self { case .badInput(let message): return message }
    }
}

struct VeilRareTool: Identifiable, Equatable {
    let id: Int
    let symbol: String
    let title: String
    let category: String
    let detail: String
}

enum VeilRareLab {
    static let maxInputBytes = 64_000
    static let catalog: [VeilRareTool] = [
        .init(id: 1, symbol: "scanGaps", title: "扫描空窗探测", category: "无线与 Mesh", detail: "观察邻居扫描间隙超过中位数的情况"),
        .init(id: 2, symbol: "robustRSSI", title: "鲁棒 RSSI 离群判别", category: "无线与 Mesh", detail: "以中位数及 MAD 识别信号离群值"),
        .init(id: 3, symbol: "shadowStreak", title: "射频阴影连续段", category: "无线与 Mesh", detail: "测量弱信号持续最长的采样段"),
        .init(id: 4, symbol: "peerChurn", title: "邻居发现抖动", category: "无线与 Mesh", detail: "统计扫描样本中的新增和消失趋势"),
        .init(id: 5, symbol: "advertCollision", title: "广告周期碰撞窗口", category: "无线与 Mesh", detail: "估算两广告周期发生相位重合的间隔"),
        .init(id: 6, symbol: "channelEntropy", title: "广告信道多样性", category: "无线与 Mesh", detail: "计算 37/38/39 信道分布熵"),
        .init(id: 7, symbol: "hysteresis", title: "链路防抖切换模拟", category: "无线与 Mesh", detail: "通过进入与退出门槛抑制切换震荡"),
        .init(id: 8, symbol: "articulation", title: "Mesh 网络割点", category: "无线与 Mesh", detail: "识别失效可能拆散拓扑的关键中继"),
        .init(id: 9, symbol: "bridgeEdges", title: "Mesh 关键桥接边", category: "无线与 Mesh", detail: "识别删去后会分裂连通性的关键链路"),
        .init(id: 10, symbol: "hopReach", title: "跳数内可达率", category: "无线与 Mesh", detail: "在指定跳数预算内计算可达节点"),
        .init(id: 11, symbol: "lossBursts", title: "分片连续丢失簇", category: "传输与恢复", detail: "识别分片空缺的最长连续区间"),
        .init(id: 12, symbol: "ackHoles", title: "确认序列空洞", category: "传输与恢复", detail: "计算 ACK 序列中不存在的编号"),
        .init(id: 13, symbol: "reorder", title: "乱序倒置密度", category: "传输与恢复", detail: "测量到达顺序中的逆序对"),
        .init(id: 14, symbol: "retryAmplification", title: "重传放大因子", category: "传输与恢复", detail: "比较实际发送与唯一逻辑分片数量"),
        .init(id: 15, symbol: "windowPressure", title: "接收窗口超订阅", category: "传输与恢复", detail: "判断等待队列是否超过接收窗口"),
        .init(id: 16, symbol: "checkpointOrder", title: "检查点单调性", category: "传输与恢复", detail: "识别进度回退或重复"),
        .init(id: 17, symbol: "throughputCollapse", title: "吞吐坍塌比", category: "传输与恢复", detail: "比较头尾吞吐窗口的下降程度"),
        .init(id: 18, symbol: "idleWatchdog", title: "链路静默预算", category: "传输与恢复", detail: "根据最后消息时间判断是否超过静默门槛"),
        .init(id: 19, symbol: "fairQuota", title: "优先级配额公平性", category: "传输与恢复", detail: "分析各业务槽位比例与最小保障"),
        .init(id: 20, symbol: "parityRepair", title: "奇偶分片修复门槛", category: "传输与恢复", detail: "判断每一组 XOR 校验能否覆盖单分片缺失"),
        .init(id: 21, symbol: "trustReciprocity", title: "非对称信任关系", category: "身份与隐私", detail: "发现单向声明而没有回执的信任边"),
        .init(id: 22, symbol: "trustFanout", title: "超常信任扩散", category: "身份与隐私", detail: "检测单节点信任关联爆发"),
        .init(id: 23, symbol: "signerContinuity", title: "签名访问组连续性", category: "身份与隐私", detail: "对比旧版与新版非秘密签名命名空间"),
        .init(id: 24, symbol: "fingerprintDrift", title: "身份公钥指纹变更", category: "身份与隐私", detail: "识别同一设备公开指纹历史漂移"),
        .init(id: 25, symbol: "qrReuse", title: "一次性二维码复用", category: "身份与隐私", detail: "检测已消费能力摘要被重复使用"),
        .init(id: 26, symbol: "clockSkew", title: "多端时钟偏移", category: "身份与隐私", detail: "估算两端事件时间戳的偏差"),
        .init(id: 27, symbol: "nonceDuplicates", title: "随机数摘要重复", category: "身份与隐私", detail: "发现样本摘要重复，提示进一步认证检查"),
        .init(id: 28, symbol: "capabilityDowngrade", title: "能力宣告降级", category: "身份与隐私", detail: "比较认证前后的特性位集合"),
        .init(id: 29, symbol: "metadataInventory", title: "诊断元数据清单", category: "身份与隐私", detail: "按字段名检查不宜导出的敏感项"),
        .init(id: 30, symbol: "consentContinuity", title: "签署版本连续性", category: "身份与隐私", detail: "检查当前协议版本与本地签署版本一致性"),
        .init(id: 31, symbol: "touchBalance", title: "触摸按下抬起失衡", category: "触控与取证", detail: "核对按下、结束、取消事件完整性"),
        .init(id: 32, symbol: "cancelRate", title: "手势中断率", category: "触控与取证", detail: "计算已开始触摸被系统取消的比例"),
        .init(id: 33, symbol: "deadzoneGrid", title: "触控死区网格", category: "触控与取证", detail: "按用户提供的网格命中情况定位弱响应区"),
        .init(id: 34, symbol: "occlusion", title: "残留透明遮挡", category: "触控与取证", detail: "识别仍然接受触摸的可见装饰层"),
        .init(id: 35, symbol: "edgeGesture", title: "边缘滑动冲突", category: "触控与取证", detail: "测量边缘启动手势的失败比例"),
        .init(id: 36, symbol: "themeLag", title: "主题切换响应延迟", category: "触控与取证", detail: "比较主题切换前后点击响应中位数"),
        .init(id: 37, symbol: "focusLoops", title: "输入框焦点循环", category: "触控与取证", detail: "统计焦点反复获得与失去的次数"),
        .init(id: 38, symbol: "frameHitches", title: "主线程卡顿簇", category: "触控与取证", detail: "计算超帧预算的最长连续卡顿"),
        .init(id: 39, symbol: "thermalCoupling", title: "热状态与卡顿共变", category: "触控与取证", detail: "对齐温度级别和帧耗时，检查共同变化"),
        .init(id: 40, symbol: "faultCoincidence", title: "故障窗口共现", category: "触控与取证", detail: "以事件时间窗口检测故障的相邻出现"),
    ]

    /// Only anonymous, bounded numeric and technical examples are included.
    /// Do not paste identity keys, message plaintext, credentials or personal metadata.
    static func sample(for id: Int) -> String {
        switch id {
        case 1...10:
            return #"{"timeMs":[0,140,280,900,1050,1200],"rssi":[-58,-62,-97,-95,-64,-60],"peers":["A","A","B","A","C","B"],"intervals":[120,180],"channels":[37,37,38,39,38,37],"edges":[[0,1],[1,2],[2,3],[0,4],[4,2]],"thresholdIn":-65,"thresholdOut":-82,"hopBudget":2}"#
        case 11...20:
            return #"{"expected":[0,1,2,3,4,5,6,7,8,9],"received":[0,1,4,5,8,9],"acks":[10,12,15],"arrival":[1,3,2,5,4],"sent":[0,1,1,2,3,3,3],"window":3,"pending":7,"checkpoints":[0,1024,2048,2048,3072],"rates":[90,88,82,36,29,20],"nowMs":9000,"lastSeenMs":2500,"idleLimitMs":3000,"quotas":[4,1,1,0],"missingPerGroup":[0,1,2,1]}"#
        case 21...30:
            return #"{"trustEdges":[[0,1],[1,0],[0,2],[0,3],[0,4]],"oldGroup":"TEAM_A.shared","newGroup":"TEAM_B.shared","fingerprints":["p1","p1","p2"],"tokens":["q1","q2","q1"],"clockA":[1000,2000,3000],"clockB":[1140,2140,3140],"nonces":["x1","x2","x1"],"previousBits":7,"currentBits":3,"metadataFields":["event","screen","message_plaintext","rssi"],"consentedVersion":4,"requiredVersion":5}"#
        default:
            return #"{"phases":["down","move","cancel","down","up"],"touchGrid":[[10,8,7],[9,0,2],[9,8,8]],"overlays":[{"name":"glow","decorative":true,"visible":true,"hittable":true}],"edgeAttempts":12,"edgeFailed":5,"beforeMs":[22,24,28,30],"afterMs":[44,90,87,45],"focusEvents":["begin","end","begin","end","begin"],"frameMs":[16,33,88,100,18,70],"thermalLevels":[0,1,2,3,1,2],"events":[[100,"touch.cancel"],[400,"ui.missed"],[1200,"ble.timeout"],[1400,"touch.cancel"]],"faultWindowMs":450}"#
        }
    }

    static func run(id: Int, json: String) throws -> String {
        guard (1...40).contains(id) else { throw VeilRareLabError.badInput("未知运算器编号") }
        guard json.utf8.count <= maxInputBytes else { throw VeilRareLabError.badInput("样本大于 64 KB") }
        guard let decoded = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let x = decoded as? [String: Any] else {
            throw VeilRareLabError.badInput("请输入 JSON 对象，不读取真实设备数据")
        }
        return try execute(id: id, x: x)
    }

    // Bounded, data-only extraction helpers. Invalid sample types fail closed.
    private static func nums(_ x: [String: Any], _ key: String, max: Int = 4096) throws -> [Double] {
        guard let values = x[key] as? [NSNumber], values.count <= max,
              values.allSatisfy({ $0.doubleValue.isFinite && abs($0.doubleValue) <= 1e12 }) else {
            throw VeilRareLabError.badInput("字段 \(key) 必须是有限数值数组（最多 \(max) 项）")
        }
        return values.map(\.doubleValue)
    }
    private static func ints(_ x: [String: Any], _ key: String, max: Int = 4096) throws -> [Int] {
        let n = try nums(x, key, max: max)
        guard n.allSatisfy({ $0.rounded() == $0 && $0 >= -1e9 && $0 <= 1e9 }) else {
            throw VeilRareLabError.badInput("字段 \(key) 必须是安全范围内的整数数组")
        }
        return n.map(Int.init)
    }
    private static func words(_ x: [String: Any], _ key: String, max: Int = 4096) throws -> [String] {
        guard let a = x[key] as? [String], a.count <= max, a.allSatisfy({ $0.utf8.count <= 128 }) else {
            throw VeilRareLabError.badInput("字段 \(key) 必须是短字符串数组")
        }
        return a
    }
    private static func number(_ x: [String: Any], _ key: String, fallback: Double = 0) -> Double {
        guard let n = x[key] as? NSNumber, n.doubleValue.isFinite, abs(n.doubleValue) < 1e12 else { return fallback }
        return n.doubleValue
    }
    private static func string(_ x: [String: Any], _ key: String) -> String {
        let value = x[key] as? String ?? ""
        return String(value.prefix(128))
    }
    private static func pairs(_ x: [String: Any], _ key: String) throws -> [(Int, Int)] {
        guard let a = x[key] as? [[NSNumber]], a.count <= 512, a.allSatisfy({ $0.count == 2 && abs($0[0].doubleValue) < 1e6 && abs($0[1].doubleValue) < 1e6 && $0[0].doubleValue.isFinite && $0[1].doubleValue.isFinite && $0[0].doubleValue.rounded() == $0[0].doubleValue && $0[1].doubleValue.rounded() == $0[1].doubleValue }) else { throw VeilRareLabError.badInput("字段 \(key) 需要 [[整数,整数],...]，最多512条") }
        return a.map { ($0[0].intValue, $0[1].intValue) }
    }
    private static func median(_ a: [Double]) -> Double {
        guard !a.isEmpty else { return 0 }
        let s = a.sorted(), i = s.count / 2
        return s.count % 2 == 0 ? (s[i - 1] + s[i]) / 2 : s[i]
    }
    private static func longest(_ a: [Bool]) -> Int {
        var current = 0, longest = 0
        for ok in a { current = ok ? current + 1 : 0; longest = Swift.max(longest, current) }
        return longest
    }
    private static func output(_ label: String, _ value: String, _ note: String) -> String {
        "\(label)：\(value)\n\(note)"
    }
    private static func pct(_ ratio: Double) -> String {
        String(format: "%.1f%%", max(0, min(1, ratio.isFinite ? ratio : 0)) * 100)
    }
    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }
    private static func graph(_ x: [String: Any]) throws -> [Int: Set<Int>] {
        let edges = try pairs(x, "edges")
        var g: [Int: Set<Int>] = [:]
        for (a,b) in edges where a != b { g[a, default: []].insert(b); g[b, default: []].insert(a) }
        return g
    }
    private static func components(_ graph: [Int:Set<Int>], excluding vertex: Int? = nil, excludingEdge: (Int,Int)? = nil) -> Int {
        let nodes = Set(graph.keys).subtracting(vertex.map { [$0] } ?? [])
        var unseen = nodes, count = 0
        while let seed = unseen.first {
            count += 1
            var queue = [seed]
            unseen.remove(seed)
            while let top = queue.popLast() {
                for next in graph[top] ?? [] where next != vertex && !(excludingEdge.map { ($0.0 == top && $0.1 == next) || ($0.1 == top && $0.0 == next) } ?? false) {
                    if unseen.remove(next) != nil { queue.append(next) }
                }
            }
        }
        return count
    }

    private static func execute(id: Int, x: [String: Any]) throws -> String {
        switch id {
        case 1:
            let a = try nums(x, "timeMs"); guard a.count > 2 else { return output("扫描空窗", "样本不足", "需要至少三个时间戳。") }
            let gaps = zip(a,a.dropFirst()).map { max(0,$1-$0) }; let m = median(gaps)
            return output("异常扫描间隙", "\(gaps.filter { $0 > max(100, m * 2.5) }.count) 次", "参考中位间隔 \(Int(m)) ms；不证明无线干扰来源。")
        case 2:
            let a = try nums(x,"rssi"); guard a.count > 2 else { return output("鲁棒 RSSI", "样本不足", "需要至少三次观测。") }
            let m = median(a), mad = median(a.map { abs($0-m) }); let count = a.filter { abs($0-m) > max(8, mad*3) }.count
            return output("MAD 离群点", "\(count)/\(a.count)", "RSSI 中位数 \(Int(m)) dBm，MAD \(String(format:"%.1f",mad))；仅为异常线索。")
        case 3:
            let a = try nums(x,"rssi"); let n = longest(a.map { $0 < -85 }); return output("射频阴影", "最长 \(n) 个采样", "连续弱 RSSI 样本，仅反映给定输入。")
        case 4:
            let a = try words(x,"peers"); guard a.count > 1 else { return output("邻居抖动", "样本不足", "至少两个样本。") }; let changes = zip(a,a.dropFirst()).filter { $0 != $1 }.count
            return output("可见邻居切换", "\(changes) 次", "相邻样本切换率 \(pct(ratio(changes,a.count-1)))；非真实断线次数。")
        case 5:
            let a = try ints(x,"intervals"); guard a.count==2 && a.allSatisfy({$0 > 0 && $0 <= 60000}) else {throw VeilRareLabError.badInput("intervals 必须为两个正整数毫秒")}; var aa=a[0], bb=a[1]; while bb != 0 { (aa,bb) = (bb,aa%bb) }; let lcm = a[0]/aa*a[1]
            return output("理论相位重复周期", "\(lcm) ms", "假设固定周期和同相起点；实际 BLE 广播包含随机延迟。")
        case 6:
            let a = try ints(x,"channels"); guard !a.isEmpty else { return output("信道熵", "样本不足", "需要广告信道记录。") }; let counts = [37,38,39].map { c in a.filter{$0==c}.count }; guard counts.reduce(0,+)==a.count else {throw VeilRareLabError.badInput("仅允许信道 37、38、39")}; let entropy = counts.reduce(0.0) { value,c in let p=Double(c)/Double(a.count); return value+(p>0 ? -p*log2(p) : 0) }
            return output("广告信道 Shannon 熵", String(format:"%.3f / 1.585 bit",entropy), "只说明样本分散程度，不是链路带宽。")
        case 7:
            let a = try nums(x,"rssi"); let thresholdIn=number(x,"thresholdIn",fallback:-65), thresholdOut=number(x,"thresholdOut",fallback:-82); guard thresholdIn > thresholdOut else {throw VeilRareLabError.badInput("进入阈值须高于退出阈值")}; var active=false,switches=0; for value in a {let next=active ? value>=thresholdOut : value>=thresholdIn; if next != active {switches+=1}; active=next}
            return output("双门槛状态变更", "\(switches) 次", "减少门槛附近的抖动；不自动更换实际连接。")
        case 8:
            let g=try graph(x),baseline=components(g); let cut = g.keys.sorted().filter { components(g,excluding:$0)>baseline }; return output("拓扑割点",cut.isEmpty ? "无" : cut.map(String.init).joined(separator:","), "任何割点断开可能导致网络分区；仅处理无向候选图。")
        case 9:
            let g=try graph(x),baseline=components(g); let edges=g.flatMap { u,neighbors in neighbors.filter{$0>u}.map{(u,$0)} }; let bridges=edges.filter{components(g,excludingEdge:$0)>baseline}; return output("关键桥接边",bridges.isEmpty ? "无" : bridges.map { "\($0.0)-\($0.1)" }.joined(separator:", "),"仅拓扑层结果，不保证物理链路独立。")
        case 10:
            let g=try graph(x),hops=max(0,min(64,Int(number(x,"hopBudget",fallback:2)))); let root=g.keys.sorted().first ?? 0; var reached:Set<Int>=[root],frontier=[root]; for _ in 0..<hops {let next=Set(frontier.flatMap{Array(g[$0] ?? [])}).subtracting(reached); reached.formUnion(next);frontier=Array(next)}; return output("\(hops) 跳内可达节点", "\(reached.count)/\(g.count)","图中包括源节点，不代表已有密钥授权。")
        case 11:
            let expected=try ints(x,"expected"),received=Set(try ints(x,"received")); let missing=expected.filter{!received.contains($0)};let runs = longest(expected.map{!received.contains($0)});return output("最长连续丢片", "\(runs) 块，缺失总计 \(missing.count)","分片标识按 expected 顺序审计，不重传任何真实数据。")
        case 12:
            let a=Array(Set(try ints(x,"acks"))).sorted();guard let first=a.first,let last=a.last,last-first<=100000 else{return output("ACK 空洞","样本不足或跨度过大","必须提供有界 ACK 序列。")};let missed=last-first+1-a.count;return output("ACK 中间空洞", "\(max(0,missed)) 个", "不包含首尾之外尚未确认的序号。")
        case 13:
            let a=try ints(x,"arrival",max:512);var inversions=0;for i in a.indices {for j in a.indices where j>i && a[i]>a[j] {inversions+=1}};let denom=a.count*(a.count-1)/2;return output("乱序倒置比例",pct(ratio(inversions,denom)),"使用有界样本的两两逆序，不推断协议重放攻击。")
        case 14:
            let a=try ints(x,"sent");let unique=Set(a).count;let amp=unique==0 ? 0 : Double(a.count)/Double(unique);return output("发送放大因子",String(format:"%.2f×",amp),"只按逻辑分片标识计数；可能包含正常重试。")
        case 15:
            let pending=max(0,Int(number(x,"pending"))),window=max(1,Int(number(x,"window",fallback:1)));let over=max(0,pending-window);return output("接收窗口压测", "超额 \(over) 块", "仅提示缓冲压力，不改变 CoreBluetooth 窗口。")
        case 16:
            let a=try nums(x,"checkpoints");let rollback=zip(a,a.dropFirst()).filter{$1<$0}.count;let duplicate=zip(a,a.dropFirst()).filter{$1==$0}.count;return output("检查点异常", "回退 \(rollback) / 重复 \(duplicate)","恢复必须先验证认证标记；重复位置未必是错误。")
        case 17:
            let a=try nums(x,"rates").filter{$0>=0};guard a.count>=4 else{return output("吞吐坍塌","样本不足","至少四个速率窗口。")};let mid=a.count/2,head=median(Array(a.prefix(mid))),tail=median(Array(a.suffix(mid)));return output("近期吞吐变化",pct(head>0 ? max(0,(head-tail)/head) : 0),"头半中位数 \(Int(head))，尾半 \(Int(tail))；单位取决于输入采样。")
        case 18:
            let now=number(x,"nowMs"),last=number(x,"lastSeenMs"),limit=number(x,"idleLimitMs",fallback:3000);guard limit>0 else{throw VeilRareLabError.badInput("静默门槛必须大于零")};let age=max(0,now-last);return output("静默监测",age>limit ? "已超时" : "窗口内", "静默 \(Int(age)) ms / 门槛 \(Int(limit)) ms，不会发送心跳。")
        case 19:
            let q=try ints(x,"quotas");guard !q.isEmpty&&q.allSatisfy({$0>=0}) else {throw VeilRareLabError.badInput("quotas 必须非负且非空")};let total=q.reduce(0,+);let starved=q.filter{$0==0}.count;return output("业务配额饥饿", "\(starved) 类零槽位", "总预算 \(total) 槽，静态诊断并非实际调度器。")
        case 20:
            let a=try ints(x,"missingPerGroup");guard a.allSatisfy({$0>=0}) else{throw VeilRareLabError.badInput("缺失数不得为负")};let repairable=a.filter{$0==1}.count;let failed=a.filter{$0>1}.count;return output("单 XOR 校验可修复组", "\(repairable) 组，无法覆盖 \(failed) 组", "只有假定每组存在且已验证单独 XOR 校验分片时才成立。")
        case 21:
            let edges=try pairs(x,"trustEdges"),set=Set(edges.map{"\($0.0)>\($0.1)"});let asymmetric=edges.filter{!set.contains("\($0.1)>\($0.0)")};return output("单向信任声明", "\(asymmetric.count) 条", "双向边不等于已完成身份验证，不自动提升任何信任。")
        case 22:
            let edges=try pairs(x,"trustEdges"),groups=Dictionary(grouping:edges,by:{$0.0});let out=groups.mapValues{Set($0.map{$0.1}).count};let maxFan=out.values.max() ?? 0;return output("最大信任出度", "\(maxFan) 条", "超常扩散仅提示人工核对，不构成恶意节点判定。")
        case 23:
            let a=string(x,"oldGroup"),b=string(x,"newGroup");guard !a.isEmpty && !b.isEmpty else{throw VeilRareLabError.badInput("需要旧版与新版的非秘密访问组标签")};return output("签名命名空间连续性",a==b ? "一致" : "发生变更", "变更可能影响旧 Keychain 可读性；不能据此重建数据库密钥。")
        case 24:
            let a=try words(x,"fingerprints");let unique=Set(a);return output("公开指纹版本", "\(unique.count) 种", "只接受已脱敏的公开指纹别名，不能自动判为密钥被替换。")
        case 25:
            let a=try words(x,"tokens");let repeats=a.count-Set(a).count;return output("一次性能力复用", "\(repeats) 次重复", "输入须为不可反推的测试摘要，禁止上传真实二维码密钥。")
        case 26:
            let a=try nums(x,"clockA"),b=try nums(x,"clockB");guard a.count==b.count else{throw VeilRareLabError.badInput("两端必须有等量对齐时间戳")};let offsets=zip(a,b).map{$1-$0};return output("中位时钟偏移", "\(Int(median(offsets))) ms", "只估计对齐样本偏移，网络时延及抖动尚未消除。")
        case 27:
            let a=try words(x,"nonces");return output("样本摘要重复", "\(a.count-Set(a).count) 次", "只分析脱敏摘要，不是协议层完整随机数安全证明。")
        case 28:
            let old=Int(number(x,"previousBits")),new=Int(number(x,"currentBits"));guard old>=0&&new>=0 else{throw VeilRareLabError.badInput("特性位必须非负")};let lost=old & ~new;return output("能力位回退", "0x\(String(lost,radix:16))", "可能由版本协商产生，不能自动当成攻击。")
        case 29:
            let a=try words(x,"metadataFields");let keys=["password","token","secret","plaintext","private","raw_body"];let bad=a.filter{f in keys.contains{f.lowercased().contains($0)}};return output("敏感元数据字段名", "\(bad.count) 项疑似", "只按字段名检查；不会访问或展示字段值。")
        case 30:
            let signed=Int(number(x,"consentedVersion",fallback:-1)),required=Int(number(x,"requiredVersion",fallback:-1));guard required>=0 else{throw VeilRareLabError.badInput("requiredVersion 缺失")};return output("协议版本签署门禁",signed==required ? "版本一致" : "必须重新确认", "仅分析版本号；真实签署与有效性由现有 Legal Gate 验证。")
        case 31:
            let a=try words(x,"phases");let started=a.filter{$0=="down"}.count,ended=a.filter{$0=="up"}.count,cancelled=a.filter{$0=="cancel"}.count;return output("触控序列平衡", "开始 \(started) / 结束 \(ended) / 取消 \(cancelled)","未归还事件估计 \(max(0,started-ended-cancelled))，未追踪触控ID时只能作为线索。")
        case 32:
            let a=try words(x,"phases");let started=a.filter{$0=="down"}.count,cancelled=a.filter{$0=="cancel"}.count;return output("触摸取消率",pct(ratio(cancelled,started)),"取消可能来自系统导航或通知，不证明控件 Bug。")
        case 33:
            guard let rows=x["touchGrid"] as? [[NSNumber]],rows.count<=32,rows.allSatisfy({$0.count<=32 && $0.allSatisfy{$0.intValue>=0}}) else{throw VeilRareLabError.badInput("touchGrid 必须为非负网格")};let minHits=rows.flatMap{$0.map(\.intValue)}.min() ?? 0;let zones=rows.enumerated().flatMap{r,row in row.enumerated().compactMap{c,n in n.intValue<=minHits ? "\(r),\(c)" : nil}};return output("最低响应热区",zones.prefix(12).joined(separator:"; "),"最低采样数 \(minHits)，0可能表示无人点击而非真实死区。")
        case 34:
            guard let overlays=x["overlays"] as? [[String:Any]],overlays.count<=128 else{throw VeilRareLabError.badInput("overlays 必须为对象数组")};let risky=overlays.filter{($0["decorative"] as? Bool ?? false)&&($0["visible"] as? Bool ?? false)&&($0["hittable"] as? Bool ?? false)};return output("可疑装饰覆盖", "\(risky.count) 层", "需以真机 hitTest 路径确认，不直接更改 SwiftUI 层级。")
        case 35:
            let tries=max(0,Int(number(x,"edgeAttempts"))),failed=max(0,Int(number(x,"edgeFailed")));return output("边缘交互失败比",pct(ratio(min(tries,failed),tries)),"仅适用于已人工标记成功/失败的手势样本。")
        case 36:
            let a=try nums(x,"beforeMs"),b=try nums(x,"afterMs");let shift=median(b)-median(a);return output("主题变更后触摸延迟", "\(Int(shift)) ms", "正值为变慢；样本不能证明主题切换是因果因素。")
        case 37:
            let a=try words(x,"focusEvents");let loops=zip(a,a.dropFirst()).filter{$0=="end" && $1=="begin"}.count;return output("焦点重入循环", "\(loops) 次", "可提示系统键盘/输入框复建；不记录真实文本。")
        case 38:
            let a=try nums(x,"frameMs");let stalls=a.filter{$0>33.3};return output("连续明显卡顿", "最长 \(longest(a.map{$0>33.3})) 帧", "超过 33.3 ms 共 \(stalls.count)/\(a.count)；近似 UI 帧耗时。")
        case 39:
            let a=try nums(x,"frameMs"),b=try nums(x,"thermalLevels");guard a.count==b.count else{throw VeilRareLabError.badInput("热状态与帧耗时样本需等长")};let normal=zip(a,b).filter{$1<2}.map{$0.0},hot=zip(a,b).filter{$1>=2}.map{$0.0};return output("热负荷卡顿差", "\(Int(median(hot)-median(normal))) ms", "热样本与非热样本中位数差；共同变化不表示热状态造成卡顿。")
        case 40:
            guard let events=x["events"] as? [[Any]],events.count<=2000,events.allSatisfy({$0.count==2 && $0[0] is NSNumber && $0[1] is String}) else{throw VeilRareLabError.badInput("events 需要 [[时间戳,事件名],...]")};let window=max(0,min(10000,number(x,"faultWindowMs",fallback:300)));let a=events.compactMap { row -> (Double,String)? in guard let t=row[0] as? NSNumber,let name=row[1] as? String,t.doubleValue.isFinite,name.utf8.count<=128 else{return nil};return (t.doubleValue,name)}.sorted{$0.0<$1.0};var pairs=0;for i in a.indices {var j=i+1;while j<a.count && a[j].0-a[i].0<=window {if a[i].1 != a[j].1 {pairs+=1};j+=1}};return output("异名故障共现", "\(pairs) 对", "时间窗 \(Int(window)) ms，仅提示时间邻近，不证明因果。")
        default:
            throw VeilRareLabError.badInput("未知运算器")
        }
    }
}