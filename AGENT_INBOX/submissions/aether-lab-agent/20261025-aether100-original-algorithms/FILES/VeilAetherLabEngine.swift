import Foundation

// Original implementation. No copied third-party source, no network,
// DB reads/writes, background tasks, Keychain access or real radio mutation.
struct VeilAetherFeature: Identifiable, Equatable, Sendable {
    let number: Int
    let title: String
    let domain: String
    let purpose: String
    var id: Int { number }
}

enum VeilAetherError: Error, LocalizedError, Equatable {
    case invalidJSON, invalidFeature, oversizedInput, invalidShape
    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "JSON 输入不合法"
        case .invalidFeature: return "未找到功能编号"
        case .oversizedInput: return "输入超出 32 KB 上限"
        case .invalidShape: return "数据类型或数组结构不正确"
        }
    }
}

struct VeilAetherReport: Equatable, Sendable {
    let featureID: Int
    let title: String
    let output: String
    let note: String
}

struct VeilAetherInput {
    let raw: [String: Any]
    init(_ text: String) throws {
        guard text.utf8.count <= 32768 else { throw VeilAetherError.oversizedInput }
        guard let bytes = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        else { throw VeilAetherError.invalidJSON }
        raw = object
    }
    var nums: [Double] { (raw["numbers"] as? [NSNumber] ?? []).prefix(256).map(\.doubleValue).filter(\.isFinite).map { max(-1_000_000, min(1_000_000, $0)) } }
    var text: String { String((raw["text"] as? String ?? "").prefix(2048)) }
    var words: [String] { text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).prefix(256).map { $0 } }
    var ints: [Int] { nums.map { Int(max(-1e6,min(1e6,$0))) } }
    var flags: [Bool] { Array((raw["flags"] as? [Bool] ?? []).prefix(256)) }
    var edges: [[Int]] { Array((raw["edges"] as? [[Int]] ?? []).prefix(256)).filter { $0.count >= 2 && (0..<32).contains($0[0]) && (0..<32).contains($0[1]) } }
    var points: [[Double]] { Array((raw["points"] as? [[Double]] ?? []).prefix(128)).filter { $0.count >= 2 && $0[0].isFinite && $0[1].isFinite && abs($0[0]) <= 1e5 && abs($0[1]) <= 1e5 } }
    var grid: [[Int]] { Array((raw["grid"] as? [[Int]] ?? []).prefix(32)).map { Array($0.prefix(32)) } }
    var strings: [String] { Array((raw["strings"] as? [String] ?? []).prefix(256)).map { String($0.prefix(512)) } }
    var limit: Int { max(1,min(512,(raw["limit"] as? Int) ?? 10)) }
}

enum VeilAetherMath {
    static func fmt(_ x: Double) -> String { x.isFinite ? String(format: "%.4f", x) : "n/a" }
    static func mean(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.reduce(0,+)/Double(a.count) }
    static func variance(_ a: [Double]) -> Double { let m=mean(a); return a.isEmpty ? 0 : a.map { ($0-m)*($0-m) }.reduce(0,+)/Double(a.count) }
    static func median(_ a: [Double]) -> Double {
        let s=a.sorted(); guard !s.isEmpty else { return 0 }; let mid=s.count/2
        return s.count%2==0 ? (s[mid-1]+s[mid])/2 : s[mid]
    }
    static func quantile(_ a: [Double], _ q: Double) -> Double {
        let s=a.sorted(); guard !s.isEmpty else { return 0 }
        return s[max(0,min(s.count-1,Int(ceil(Double(s.count)*max(0,min(1,q))))-1))]
    }
    static func entropy(_ a: [Int]) -> Double {
        guard !a.isEmpty else { return 0 }
        let f=Dictionary(a.map { ($0,1) },uniquingKeysWith:+)
        return f.values.reduce(0) { r,c in let p=Double(c)/Double(a.count); return r - p*log2(p) }
    }
    static func checksum(_ a: [UInt8]) -> UInt32 {
        var crc:UInt32=0xFFFFFFFF
        for byte in a { crc ^= UInt32(byte); for _ in 0..<8 { let b=crc & 1; crc=(crc >> 1) ^ (b == 1 ? 0xEDB88320:0) } }
        return ~crc
    }
    static func uniquePairs(_ a: [String]) -> Int { a.count - Set(a).count }
    static func matrix(_ n: Int, edges: [[Int]], undirected: Bool = true) -> [[Bool]] {
        var g=Array(repeating:Array(repeating:false,count:n),count:n)
        for edge in edges where edge[0]<n && edge[1]<n { g[edge[0]][edge[1]]=true; if undirected {g[edge[1]][edge[0]]=true} }
        return g
    }
    static func components(_ g: [[Bool]], removing removed:Int?=nil)->Int {
        let n=g.count; var visited=Set<Int>(); var count=0
        for i in 0..<n where i != removed && !visited.contains(i) {
            count += 1; var queue=[i]; visited.insert(i)
            while let node=queue.popLast() {
                for j in 0..<n where j != removed && g[node][j] && !visited.contains(j) { visited.insert(j);queue.append(j) }
            }
        }
        return count
    }
    static func levenshtein(_ aa:String,_ bb:String)->Int {
        let a=Array(aa.prefix(256)),b=Array(bb.prefix(256));var last=Array(0...b.count)
        for (i,c) in a.enumerated(){ var now=[i+1]+Array(repeating:0,count:b.count)
            for (j,d) in b.enumerated(){ now[j+1]=min(now[j]+1,last[j+1]+1,last[j]+(c==d ? 0:1)) }; last=now
        }
        return last[b.count]
    }
    static func jaccard(_ a:Set<String>,_ b:Set<String>)->Double {
        let union=a.union(b); return union.isEmpty ? 1 : Double(a.intersection(b).count)/Double(union.count)
    }
    static func dist(_ a:[Double],_ b:[Double])->Double {hypot(a[0]-b[0],a[1]-b[1])}
    static func polygonArea(_ p:[[Double]])->Double {
        guard p.count >= 3 else { return 0 }; var s=0.0
        for i in 0..<p.count {let j=(i+1)%p.count;s+=p[i][0]*p[j][1]-p[j][0]*p[i][1]};return abs(s)/2
    }
    static func clip(_ x:Int)->Int {max(0,min(1000000,x))}
    static func numeric(_ x:Double)->String {fmt(x)}
}

enum VeilAetherEngine {
    static let domains: [(String, [String])] = [
        ("Mesh 拓扑研究", ["节点度分布","连通分量剖析","最短跳数路径","环路风险扫描","有向拓扑排序","节点失效连通率","双路无交叉容量","PageRank 中继评分","邻接闭三角率","核心层级剥离"]),
        ("无线信号科学", ["采样均值曲线","鲁棒中位估计","截尾均值降噪","信号分位数","采样方差","MAD 离群探测","EWMA 平滑追踪","CUSUM 突变侦测","局部峰值提取","信号信息熵"]),
        ("多设备协作", ["逻辑时间排序","Lamport 单调审计","向量时钟偏序","消息序号空洞","多数派门限","副本交集相似度","事件去重账簿","因果依赖缺失","依赖图关键路径","加权公平分配"]),
        ("密码学外围与隐私", ["文本香农熵","数据脱敏项计数","邮箱安全掩码","别名冲突扫描","分组时间模糊化","K 匿名组审计","CRC32 完整性校验","Nonce 重复风险","时间戳有效窗口","元数据预算审查"]),
        ("音画创作实验", ["调色板亮度","WCAG 对比评级","互补色生成","颜色调色阶","颜色相对亮度","镜头帧时长","BPM 拍点网格","动画缓动曲线","二次贝塞尔采样","音量包络压缩"]),
        ("程序化游戏生成", ["地牢路径广搜","格点 A* 规划","生命游戏演化","种子地形生成","细胞区域着色","遮挡视线计算","图块区域泛洪","事件回放验序","关卡难度估计","精灵 LOD 分级"]),
        ("离线知识图谱", ["词汇统计","独特词表提炼","文本 Jaccard","编辑距离相似","最长公共子序列","高频双字模型","离线倒排索引","关键词密度","句段分割","重复语句去重"]),
        ("几何与场景空间", ["多边形面积","点在多边形内","二维凸包生成","矩形碰撞检测","最近空间点","线段交点","折线 RDP 简化","点云旋转变换","曲线位置插值","网格占据率"]),
        ("系统可靠性试验", ["消息 P95 时延","RTT 指数平滑","退避预算模拟","重试次数预算","队列燃尽预估","平均修复时间","剩余存储估计","热阈值负载建议","电量保留预算","综合风险评分"]),
        ("触控与无障碍", ["最小可触达区域","多层颜色对比","焦点图环路","文本方向异常","布局溢出预警","动效总时长门禁","手势冲突概率","触控覆盖总量","告警文字易读性","触觉节奏一致性"])
    ]
    static let catalog: [VeilAetherFeature] = domains.enumerated().flatMap { group, pair in
        pair.1.enumerated().map { index,title in
            VeilAetherFeature(number:201+group*10+index,title:title,domain:pair.0,
              purpose:"独立离线运算模块；仅分析用户主动提供的去标识化样本")
        }
    }
    static let exampleJSON = """
    {"numbers":[1,2,3,5,8,13,21,3,2,1],"text":"VeilLink offline local science offline", "strings":["alpha","beta","alpha","gamma"],"edges":[[0,1],[1,2],[2,3],[1,3],[3,4]],"points":[[0,0],[4,0],[4,3],[0,3]],"grid":[[0,0,1,0],[0,0,0,0],[1,0,0,0],[0,0,0,0]],"flags":[true,false,true,true],"limit":5}
    """
    static func run(_ id:Int,json:String) throws -> VeilAetherReport {
        guard let feature=catalog.first(where:{$0.number==id}) else {throw VeilAetherError.invalidFeature}
        let input=try VeilAetherInput(json)
        let index=id-201
        let answer:String
        switch index/10 {
        case 0: answer=VeilAetherGraph.run(index%10,input)
        case 1: answer=VeilAetherSignal.run(index%10,input)
        case 2: answer=VeilAetherSync.run(index%10,input)
        case 3: answer=VeilAetherPrivacy.run(index%10,input)
        case 4: answer=VeilAetherMedia.run(index%10,input)
        case 5: answer=VeilAetherGames.run(index%10,input)
        case 6: answer=VeilAetherKnowledge.run(index%10,input)
        case 7: answer=VeilAetherSpatial.run(index%10,input)
        case 8: answer=VeilAetherReliability.run(index%10,input)
        case 9: answer=VeilAetherAccessibility.run(index%10,input)
        default: throw VeilAetherError.invalidFeature
        }
        return VeilAetherReport(featureID:id,title:feature.title,output:answer,
            note:"人工输入样本｜本地建议性计算｜非真实设备检测结果")
    }
}
