import Foundation

private typealias AM = VeilAetherMath

enum VeilAetherGraph {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let g=AM.matrix(16,edges:i.edges);let n=g.count
        switch k {
        case 0:
            return "各节点度数: " + (0..<n).map { String(g[$0].filter{$0}.count) }.joined(separator:",")
        case 1:
            return "连通分量: \(AM.components(g))"
        case 2:
            var dist=Array(repeating:-1,count:n);dist[0]=0;var q=[0];var head=0
            while head<q.count {let u=q[head];head+=1;for v in 0..<n where g[u][v] && dist[v]<0 {dist[v]=dist[u]+1;q.append(v)}}
            return "0 到 4 最少跳数: \(dist[4])"
        case 3:
            var visited=Set<Int>();var found=false
            func dfs(_ u:Int,_ parent:Int){visited.insert(u);for v in 0..<n where g[u][v] {if !visited.contains(v){dfs(v,u)}else if v != parent{found=true}}}
            for u in 0..<n where !visited.contains(u){dfs(u,-1)}
            return found ? "检测到回路" : "无回路"
        case 4:
            let dg=AM.matrix(16,edges:i.edges,undirected:false)
            var indeg=Array(repeating:0,count:n)
            for u in 0..<n {for v in 0..<n where dg[u][v]{indeg[v]+=1}}
            var q=(0..<n).filter {indeg[$0]==0};var idx=0;var order=[Int]()
            while idx<q.count{let u=q[idx];idx+=1;order.append(u);for v in 0..<n where dg[u][v] {indeg[v]-=1;if indeg[v]==0{q.append(v)}}}
            return order.count == n ? "拓扑: "+order.map(String.init).joined(separator:",") : "有向图存在环"
        case 5:
            // Fraction of reachable node pairs after the worst one-node failure.
            var worst = 1.0
            for removed in 0..<n {
                var seen=Set([removed]),sumPairs=0
                for start in 0..<n where !seen.contains(start) {
                    var queue=[start],size=0;seen.insert(start)
                    while let u=queue.popLast() {size+=1;for v in 0..<n where g[u][v] && !seen.contains(v) {
                        seen.insert(v);queue.append(v)
                    }}
                    sumPairs+=size*(size-1)/2
                }
                let possible=max(1,(n-1)*(n-2)/2)
                worst=min(worst,Double(sumPairs)/Double(possible))
            }
            return "最坏节点故障后节点对可达率: \(AM.fmt(worst*100))%"
        case 6:
            // Unit capacity max flow = number of edge-disjoint paths from 0 to 4.
            var capacity=Array(repeating:Array(repeating:0,count:n),count:n)
            for u in 0..<n {for v in 0..<n where g[u][v]{capacity[u][v]=1}}
            var flow=0
            while flow<16 {
                var parent=Array(repeating:-1,count:n),q=[0],head=0;parent[0]=0
                while head<q.count && parent[4]<0 {let u=q[head];head+=1
                    for v in 0..<n where capacity[u][v]>0 && parent[v]<0 {parent[v]=u;q.append(v)}
                }
                guard parent[4]>=0 else{break}
                var v=4
                while v != 0 {let u=parent[v];capacity[u][v]-=1;capacity[v][u]+=1;v=u}
                flow+=1
            }
            return "0→4 无公共边冗余路径: \(flow) 条"
        case 7:
            let d=AM.matrix(16,edges:i.edges,undirected:false)
            var rank=Array(repeating:1.0/Double(n),count:n)
            for _ in 0..<20 {
                var next=Array(repeating:0.15/Double(n),count:n)
                for u in 0..<n{let out=d[u].filter{$0}.count
                    if out==0{for v in 0..<n{next[v]+=0.85*rank[u]/Double(n)}}
                    else{for v in 0..<n where d[u][v]{next[v]+=0.85*rank[u]/Double(out)}}
                };rank=next
            }
            return "PageRank 高权重节点: \(rank.enumerated().max(by:{$0.element<$1.element})?.offset ?? 0)"
        case 8:
            var triangles=0,wedges=0
            for u in 0..<n {let neighbors=(0..<n).filter{g[u][$0]}
                if neighbors.count>1 {wedges+=neighbors.count*(neighbors.count-1)/2
                    for a in 0..<neighbors.count{for b in (a+1)..<neighbors.count where g[neighbors[a]][neighbors[b]]{triangles+=1}}
                }
            }
            return "闭三角率: \(AM.fmt(wedges==0 ? 0 : Double(triangles)/Double(wedges)))"
        default:
            var active=Set(0..<n),depth=0;let threshold=max(1,min(8,i.limit))
            while !active.isEmpty {let dropped=active.filter{u in active.filter{g[u][$0]}.count<threshold}
                if dropped.isEmpty {break};active.subtract(dropped);depth+=1;if depth>16{break}}
            return "\(threshold)-core 节点数: \(active.count) (轮次\(depth))"
        }
    }
}

enum VeilAetherSignal {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let a=i.nums;let m=AM.mean(a)
        switch k {
        case 0: return "均值 \(AM.fmt(m))"
        case 1: return "中位数 \(AM.fmt(AM.median(a)))"
        case 2:
            let v=a.sorted();let d=v.count/10;let trimmed=Array(v.dropFirst(d).dropLast(d))
            return "10% 截尾均值 \(AM.fmt(AM.mean(trimmed)))"
        case 3: return "P90 \(AM.fmt(AM.quantile(a,0.90)))"
        case 4: return "方差 \(AM.fmt(AM.variance(a)))"
        case 5:
            let med=AM.median(a),mad=AM.median(a.map{abs($0-med)})
            let outliers=a.filter{mad>0 ? abs($0-med)>3*1.4826*mad : abs($0-med)>0}
            return "MAD 异常点数 \(outliers.count)"
        case 6:
            var ema=a.first ?? 0;for x in a.dropFirst(){ema=0.25*x+0.75*ema}
            return "EWMA \(AM.fmt(ema))"
        case 7:
            var pos=0.0,negative=0.0,maxDeviation=0.0
            let sigma=sqrt(AM.variance(a));let slack=max(0.001,sigma/2)
            for x in a {pos=max(0,pos+x-m-slack);negative=min(0,negative+x-m+slack);maxDeviation=max(maxDeviation,pos,abs(negative))}
            return "CUSUM 偏移幅度 \(AM.fmt(maxDeviation))"
        case 8:
            let count=a.count<3 ? 0 : (1..<(a.count-1)).filter{a[$0]>a[$0-1] && a[$0]>=a[$0+1]}.count
            return "局部峰值 \(count) 个"
        default:
            let bins=a.map{Int(($0*10).rounded())};return "离散 Shannon 熵 \(AM.fmt(AM.entropy(bins))) bit"
        }
    }
}

enum VeilAetherSync {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let a=i.ints,labels=i.strings,e=i.edges
        switch k {
        case 0:
            let sorted=a.enumerated().sorted{ $0.element==$1.element ? $0.offset<$1.offset : $0.element<$1.element }
            return "稳定逻辑顺序: "+sorted.prefix(15).map{String($0.offset)}.joined(separator:",")
        case 1: return "Lamport 回退 \(zip(a,a.dropFirst()).filter{$0.1<=$0.0}.count) 次"
        case 2:
            let first=Array(a.prefix(3)),second=Array(a.dropFirst(3).prefix(3))
            guard first.count==3 && second.count==3 else{return "需至少6个数构成两个向量时钟"}
            let f=zip(first,second).allSatisfy{$0<=$1},b=zip(first,second).allSatisfy{$0>=$1}
            return f && b ? "同一时钟" : f ? "A 先于 B" : b ? "B 先于 A" : "并发无序"
        case 3:
            let unique=Array(Set(a)).sorted();let gaps=zip(unique,unique.dropFirst()).reduce(0){$0+max(0,min(1000,$1.1-$1.0-1))}
            return "消息序列缺口 \(gaps)"
        case 4:
            let approved=i.flags.filter{$0}.count;let threshold=i.flags.count/2+1
            return "多数派门限 \(approved)/\(threshold) \(approved>=threshold ? "满足":"不足")"
        case 5:
            let l=Set(labels.enumerated().compactMap{$0.offset%2==0 ? $0.element:nil})
            let r=Set(labels.enumerated().compactMap{$0.offset%2==1 ? $0.element:nil})
            return "副本交并比 \(AM.fmt(AM.jaccard(l,r)))"
        case 6: return "重复操作 ID \(AM.uniquePairs(labels)) 个"
        case 7:
            let seen=Set(e.map{$0[0]});let unknown=Set(e.map{$0[1]}).subtracting(seen)
            return "缺失父事件 \(unknown.count) 个"
        case 8:
            let n=16,g=AM.matrix(n,edges:e,undirected:false)
            var indeg=Array(repeating:0,count:n);for u in 0..<n{for v in 0..<n where g[u][v]{indeg[v]+=1}}
            var q=(0..<n).filter{indeg[$0]==0},idx=0,dist=Array(repeating:0,count:n)
            while idx<q.count{let u=q[idx];idx+=1;for v in 0..<n where g[u][v] {dist[v]=max(dist[v],dist[u]+1);indeg[v]-=1;if indeg[v]==0{q.append(v)}}}
            return q.count==n ? "关键路径长度 \(dist.max() ?? 0)" : "依赖图有环"
        default:
            let weights=a.prefix(16).map{max(0,$0)};let total=weights.reduce(0,+)
            return "公平队列份额 "+weights.prefix(6).map{String(format:"%.1f%%",total==0 ? 0 : 100*Double($0)/Double(total))}.joined(separator:",")
        }
    }
}

enum VeilAetherPrivacy {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let text=i.text, strings=i.strings,a=i.ints
        switch k {
        case 0: return "文本字节熵 \(AM.fmt(AM.entropy(Array(text.utf8).map(Int.init)))) bit"
        case 1:
            let patterns=["password","token","apikey","secret","手机号","密钥"]
            return "待人工审核的敏感字段标记 \(patterns.filter{text.lowercased().contains($0)}.count)"
        case 2:
            let parts=text.split(separator:"@",maxSplits:1).map(String.init)
            guard parts.count==2,parts[0].count>=2 else{return "非有效邮箱格式"}
            return "邮箱掩码: \(parts[0].prefix(1))***@\(parts[1])"
        case 3: return "别名重复 \(AM.uniquePairs(strings.map{$0.lowercased()})) 条"
        case 4:
            let buckets=a.map{Int(floor(Double($0)/300))*300};return "5分钟时间桶: "+buckets.prefix(10).map(String.init).joined(separator:",")
        case 5:
            let frequency=Dictionary(strings.map{($0,1)},uniquingKeysWith:+)
            let bad=frequency.values.filter{$0<max(2,min(10,i.limit))}.count
            return "K 匿名不足的组 \(bad) 个"
        case 6: return "CRC32 (非加密摘要): "+String(AM.checksum(Array(text.utf8)),radix:16)
        case 7: return "重复 Nonce 标识 \(AM.uniquePairs(strings)) 项（仅样本 ID 检查）"
        case 8:
            let now=a.first ?? 0,expiry=a.dropFirst().first ?? 0
            return "凭据新鲜性: \(expiry>=now && expiry-now<=3600 ? "窗口内" : "超时或异常")"
        default:
            let bytes=strings.reduce(0){$0+$1.utf8.count}
            return "元数据 \(bytes) B / 4096 B \(bytes<=4096 ? "可审阅":"超出预算")"
        }
    }
}

enum VeilAetherMedia {
    private static func srgb(_ x:Double)->Double{let x=max(0,min(1,x));return x<=0.04045 ? x/12.92 : pow((x+0.055)/1.055,2.4)}
    private static func col(_ a:[Int],_ offset:Int)->[Double]{let p=Array(a.dropFirst(offset).prefix(3));return p.count==3 ? p.map{Double(max(0,min(255,$0)))/255} : [0,0,0]}
    private static func luminance(_ rgb:[Double])->Double{0.2126*srgb(rgb[0])+0.7152*srgb(rgb[1])+0.0722*srgb(rgb[2])}
    static func run(_ k:Int,_ i:VeilAetherInput)->String{
        let a=i.nums,ints=i.ints,c=col(ints,0),d=col(ints,3),lum=luminance(c)
        switch k {
        case 0: return "颜色平均明度 \(AM.fmt(AM.mean(c)))"
        case 1:
            let l2=luminance(d);return "WCAG 对比度 \(AM.fmt((max(lum,l2)+0.05)/(min(lum,l2)+0.05))):1"
        case 2: return "互补色 RGB: "+c.map{String(Int((1-$0)*255))}.joined(separator:",")
        case 3:
            let levels=c.map{Int(($0*5).rounded())};return "五级调色阶: "+levels.map(String.init).joined(separator:",")
        case 4: return "相对亮度 \(AM.fmt(lum))"
        case 5:
            let frames=Double(abs(ints.first ?? 0)),fps=Double(max(1,min(120,abs(ints.dropFirst().first ?? 30))))
            return "镜头时长 \(AM.fmt(frames/fps)) s"
        case 6:
            let bpm=max(20,min(320,abs(a.first ?? 120)));return "节拍间隔 \(AM.fmt(60/bpm)) s"
        case 7:
            let t=max(0,min(1,abs(a.first ?? 0).truncatingRemainder(dividingBy:1)))
            return "Smoothstep 缓动 \(AM.fmt(t*t*(3-2*t)))"
        case 8:
            let p=i.points;guard p.count>=3 else{return "需要三个控制点"}
            let t=0.5,x=pow(1-t,2)*p[0][0]+2*t*(1-t)*p[1][0]+t*t*p[2][0]
            let y=pow(1-t,2)*p[0][1]+2*t*(1-t)*p[1][1]+t*t*p[2][1]
            return "Bezier 50%: (\(AM.fmt(x)),\(AM.fmt(y)))"
        default:
            let peak=a.map{abs($0)}.max() ?? 0;let compressed=peak<=1 ? peak : 1+log2(peak)
            return "音量包络压缩峰值 \(AM.fmt(compressed))"
        }
    }
}
