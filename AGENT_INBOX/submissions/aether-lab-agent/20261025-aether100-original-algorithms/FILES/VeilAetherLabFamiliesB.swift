import Foundation

private typealias BM = VeilAetherMath

enum VeilAetherGames {
    private static func grid(_ i:VeilAetherInput)->[[Int]] {
        let raw=i.grid;guard raw.count>=2,raw.count<=32,raw.allSatisfy({$0.count==raw[0].count}),raw[0].count>=2 else {
            return [[0,0,1,0],[0,0,0,0],[1,0,0,0],[0,0,0,0]]
        };return raw
    }
    private static func search(_ board:[[Int]], aStar:Bool)->Int {
        let h=board.count,w=board[0].count;guard board[0][0]==0,board[h-1][w-1]==0 else{return -1}
        var d=Array(repeating:Array(repeating:Int.max,count:w),count:h);d[0][0]=0
        var open=[(0,0)],found=0
        while !open.isEmpty && found<2048 {
            found+=1
            if aStar {open.sort{d[$0.0][$0.1]+abs(h-1-$0.0)+abs(w-1-$0.1)<d[$1.0][$1.1]+abs(h-1-$1.0)+abs(w-1-$1.1)}}
            let (r,c)=open.removeFirst();let cost=d[r][c]
            if r==h-1 && c==w-1 {return cost}
            for (dr,dc) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let nr=r+dr,nc=c+dc
                if nr>=0 && nr<h && nc>=0 && nc<w && board[nr][nc]==0 && cost+1<d[nr][nc]{d[nr][nc]=cost+1;open.append((nr,nc))}
            }
        }
        return -1
    }
    static func run(_ k:Int,_ i:VeilAetherInput)->String{
        let b=grid(i),h=b.count,w=b[0].count,ints=i.ints
        switch k {
        case 0: return "地牢 BFS 路径步数 \(search(b,aStar:false))"
        case 1: return "A* 格点路径步数 \(search(b,aStar:true))"
        case 2:
            var alive=0
            for r in 0..<h{for c in 0..<w{
                var count=0;for dr in -1...1{for dc in -1...1 where !(dr==0 && dc==0) {
                    let nr=r+dr,nc=c+dc;if nr>=0 && nr<h && nc>=0 && nc<w && b[nr][nc] != 0{count+=1}
                }}
                if count==3 || (count==2 && b[r][c] != 0){alive+=1}
            }}
            return "生命游戏下一代存活格 \(alive)"
        case 3:
            let seed=UInt64(bitPattern:Int64(ints.first ?? 1776));var s=seed &+ 0x9e3779b97f4a7c15
            var values=[Int]();for _ in 0..<16{s ^= s<<13;s ^= s>>7;s ^= s<<17;values.append(Int(s%10))}
            return "种子地形: "+values.map(String.init).joined(separator:",")
        case 4:
            let palette=Set(b.flatMap{$0});return "地图图块种类 \(palette.count)"
        case 5:
            var blocked=0;let row=0,col=0
            for index in 1..<min(h,w){if b[row+index][col+index] != 0 {blocked+=1}}
            return "主对角线遮挡 \(blocked) 处（格点近似）"
        case 6:
            var seen=Set<Int>(),regions=0
            for r in 0..<h{for c in 0..<w where b[r][c]==0{
                let start=r*w+c;if seen.contains(start){continue}
                regions+=1;seen.insert(start);var q=[start]
                while let v=q.popLast(){let rr=v/w,cc=v%w
                    for (dr,dc) in [(1,0),(-1,0),(0,1),(0,-1)]{
                        let nr=rr+dr,nc=cc+dc,id=nr*w+nc
                        if nr>=0 && nr<h && nc>=0 && nc<w && b[nr][nc]==0 && !seen.contains(id){seen.insert(id);q.append(id)}
                    }
                }
            }}
            return "可走区域数 \(regions)"
        case 7:
            let regressions=zip(ints,ints.dropFirst()).filter{$0.0>=$0.1}.count
            return "回放非单调事件 \(regressions)"
        case 8:
            let walls=b.flatMap{$0}.filter{$0 != 0}.count
            return "关卡阻塞率 \(BM.fmt(100*Double(walls)/Double(h*w)))%"
        default:
            let density=Double(h*w),cells=min(4096,h*w*max(1,i.limit));return "LOD 采样预算 \(cells) / \(Int(density))"
        }
    }
}

enum VeilAetherKnowledge {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let w=i.words,t=i.text,strings=i.strings
        switch k {
        case 0: return "词数 \(w.count)，字符 \(t.count)"
        case 1: return "独立词 \(Set(w).count) 个"
        case 2:
            let mid=w.count/2;let a=Set(w.prefix(mid)),b=Set(w.dropFirst(mid))
            return "上下文 Jaccard \(BM.fmt(BM.jaccard(a,b)))"
        case 3:
            let a=strings.first ?? "",b=strings.dropFirst().first ?? ""
            return "编辑距离 \(BM.levenshtein(a,b))"
        case 4:
            let a=Array((strings.first ?? "").prefix(100)),b=Array((strings.dropFirst().first ?? "").prefix(100))
            var dp=Array(repeating:Array(repeating:0,count:b.count+1),count:a.count+1)
            if !a.isEmpty && !b.isEmpty{for x in 1...a.count{for y in 1...b.count{dp[x][y]=a[x-1]==b[y-1] ? dp[x-1][y-1]+1 : max(dp[x-1][y],dp[x][y-1])}}}
            return "最长公共子序列 \(dp[a.count][b.count])"
        case 5:
            let letters=Array(t.lowercased());var f=[String:Int]()
            if letters.count>=2 {for index in 0..<(letters.count-1){f[String(letters[index...index+1]),default:0]+=1}}
            let top=f.sorted{$0.value==$1.value ? $0.key<$1.key : $0.value>$1.value}.first
            return "最高频 bigram: \(top?.key ?? "—") (\(top?.value ?? 0))"
        case 6:
            let dict=Dictionary(grouping:w.enumerated(),by:{$0.element})
            return "倒排索引 \(dict.count) 词项 / \(dict.values.reduce(0){$0+$1.count}) 出现位置"
        case 7:
            let needle=(strings.first ?? "veil").lowercased();return "关键词密度 \(BM.fmt(w.isEmpty ? 0 : 100*Double(w.filter{$0==needle}.count)/Double(w.count)))%"
        case 8:
            return "句段 \(t.split(whereSeparator:{"。！？.!?\n".contains($0)}).filter{!$0.trimmingCharacters(in:.whitespaces).isEmpty}.count)"
        default: return "去重后语句 \(Set(strings.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}).count)/\(strings.count)"
        }
    }
}

enum VeilAetherSpatial {
    static func run(_ k:Int,_ i:VeilAetherInput)->String{
        let p=i.points,n=p.count,values=i.nums
        switch k {
        case 0: return "面积 \(BM.fmt(BM.polygonArea(p))) 平方单位"
        case 1:
            guard n>=3 else{return "点数不足"}
            let point:[Double]=[values.first ?? 1.0,values.dropFirst().first ?? 1.0];var inside=false,j=n-1
            for k in 0..<n{let yi=p[k][1],yj=p[j][1]
                if (yi>point[1]) != (yj>point[1]) && point[0] < (p[j][0]-p[k][0])*(point[1]-yi)/(yj-yi)+p[k][0] {inside = !inside}
                j=k
            }
            return "目标点 \(inside ? "在多边形内":"在多边形外")"
        case 2:
            guard n>1 else{return "凸包节点 \(n)"}
            let points=p.sorted{$0[0]==$1[0] ? $0[1]<$1[1] : $0[0]<$1[0]}
            func cross(_ a:[Double],_ b:[Double],_ c:[Double])->Double{(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])}
            var lower=[[Double]]();for x in points{while lower.count>=2 && cross(lower[lower.count-2],lower[lower.count-1],x)<=0{lower.removeLast()};lower.append(x)}
            var upper=[[Double]]();for x in points.reversed(){while upper.count>=2 && cross(upper[upper.count-2],upper[upper.count-1],x)<=0{upper.removeLast()};upper.append(x)}
            return "凸包节点 \(lower.count+upper.count-2)"
        case 3:
            guard n>=2 else{return "需要两组矩形控制点"}
            let a=p[0],b=p[1],width=abs(values.first ?? 2),height=abs(values.dropFirst().first ?? 2)
            return "矩形碰撞: \(abs(a[0]-b[0])<width && abs(a[1]-b[1])<height ? "可能相交":"未相交")"
        case 4:
            guard n>0 else{return "没有坐标"}
            let target:[Double]=[values.first ?? 0.0,values.dropFirst().first ?? 0.0]
            let hit=p.enumerated().min{BM.dist($0.element,target)<BM.dist($1.element,target)}
            return "最近点 #\(hit?.offset ?? -1)，距离 \(BM.fmt(hit.map{BM.dist($0.element,target)} ?? 0))"
        case 5:
            guard n>=4 else{return "至少四个端点"}
            func cross(_ a:[Double],_ b:[Double],_ c:[Double])->Double{(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])}
            let a=cross(p[0],p[1],p[2]),b=cross(p[0],p[1],p[3]),c=cross(p[2],p[3],p[0]),d=cross(p[2],p[3],p[1])
            return "两线段严格交叉: \(a*b<0 && c*d<0 ? "是":"否（含边界未判定）")"
        case 6:
            guard n>=2 else{return "简化后点数 \(n)"}
            let tolerance=max(0.001,min(1e3,abs(values.first ?? 0.5)))
            func simplify(_ nodes:[[Double]])->[[Double]]{
                if nodes.count<3{return nodes};let a=nodes[0],b=nodes[nodes.count-1],ab=BM.dist(a,b)
                var maxDistance = -1.0,index=0
                for j in 1..<(nodes.count-1){let q=nodes[j],distance=ab<1e-12 ? BM.dist(a,q) : abs((b[1]-a[1])*q[0]-(b[0]-a[0])*q[1]+b[0]*a[1]-b[1]*a[0])/ab
                    if distance>maxDistance{maxDistance=distance;index=j}
                }
                if maxDistance<=tolerance{return [a,b]}
                let left=simplify(Array(nodes[0...index]));let right=simplify(Array(nodes[index...]));return Array(left.dropLast())+right
            }
            return "RDP 简化 \(n) → \(simplify(p).count) 点"
        case 7:
            guard let point=p.first else{return "坐标缺失"};let angle=(values.first ?? 45)*Double.pi/180
            return "旋转后的首点 \(BM.fmt(point[0]*cos(angle)-point[1]*sin(angle))),\(BM.fmt(point[0]*sin(angle)+point[1]*cos(angle)))"
        case 8:
            guard n>=2 else{return "至少两个控制点"};let t=0.35
            return "线性插值 \(BM.fmt(p[0][0]*(1-t)+p[1][0]*t)),\(BM.fmt(p[0][1]*(1-t)+p[1][1]*t))"
        default:
            let cells=i.grid.flatMap{$0};return "网格占据率 \(BM.fmt(cells.isEmpty ? 0 : 100*Double(cells.filter{$0 != 0}.count)/Double(cells.count)))%"
        }
    }
}

enum VeilAetherReliability {
    static func run(_ k:Int,_ i:VeilAetherInput)->String {
        let a=i.nums
        switch k {
        case 0: return "消息 P95 \(BM.fmt(BM.quantile(a,0.95))) ms"
        case 1:
            var smooth=a.first ?? 0;for x in a.dropFirst(){smooth=0.2*x+0.8*smooth}
            return "平滑 RTT \(BM.fmt(smooth)) ms"
        case 2:
            let retries=max(0,min(8,abs(i.ints.first ?? 3)))
            let delays=(0..<retries).map{min(60,1 << $0)}
            return "退避节奏: "+delays.map(String.init).joined(separator:",")+" s"
        case 3:
            let used=max(0,i.ints.first ?? 0),budget=i.limit
            return "剩余重试 \(max(0,budget-used)) / \(budget)"
        case 4:
            let arrivals=max(0,a.first ?? 0),processed=max(0,a.dropFirst().first ?? 0)
            return "队列净增速 \(BM.fmt(arrivals-processed)) /秒"
        case 5:
            let incidents=a.filter{$0>0};return "平均修复时间 \(BM.fmt(BM.mean(incidents))) 分钟"
        case 6:
            let free=max(0,a.first ?? 0),daily=max(0,a.dropFirst().first ?? 0)
            return "存储剩余 \(daily>0 ? BM.fmt(free/daily) : "未知") 天（不自动清理）"
        case 7:
            let thermal=max(0,min(3,i.ints.first ?? 0));return "热等级 \(thermal)，建议特效预算 \([100,60,25,0][thermal])%"
        case 8:
            let charge=max(0,min(100,Int(a.first ?? 100)));return "电量 \(charge)% / 非关键特效 \(charge<15 ? 20:charge<30 ? 55:100)%"
        default:
            let danger=min(100,max(0,Int(BM.mean(a.map{abs($0)}))));return "综合样本风险 \(danger)/100（非安全认证）"
        }
    }
}

enum VeilAetherAccessibility {
    static func run(_ k:Int,_ i:VeilAetherInput)->String{
        let a=i.nums,strings=i.strings,ints=i.ints
        switch k {
        case 0:
            let widths=a.enumerated().compactMap{$0.offset%2==0 ? $0.element:nil};let heights=a.enumerated().compactMap{$0.offset%2==1 ? $0.element:nil}
            let n=min(widths.count,heights.count),small=(0..<n).filter{widths[$0]<44 || heights[$0]<44}.count
            return "低于建议 44pt 的触控目标 \(small)/\(n)"
        case 1:
            let values=Array(ints.prefix(6)).map{Double(max(0,min(255,$0)))/255}
            guard values.count==6 else{return "需要两组 RGB 六个分量"}
            func lum(_ c:[Double])->Double{let v=c.map{x in x<=0.04045 ? x/12.92 : pow((x+0.055)/1.055,2.4)};return v[0]*0.2126+v[1]*0.7152+v[2]*0.0722}
            let x=lum(Array(values[0..<3])),y=lum(Array(values[3..<6]))
            return "图层文字对比度 \(BM.fmt((max(x,y)+0.05)/(min(x,y)+0.05)))"
        case 2:
            let graph=BM.matrix(16,edges:i.edges,undirected:false);var state=Array(repeating:0,count:16),cycle=false
            func visit(_ u:Int){state[u]=1;for v in 0..<16 where graph[u][v]{if state[v]==1{cycle=true}else if state[v]==0{visit(v)}};state[u]=2}
            for u in 0..<16 where state[u]==0{visit(u)}
            return "焦点序列环路 \(cycle ? "存在":"未发现")"
        case 3:
            let bidi=i.text.unicodeScalars.filter{(0x202A...0x202E).contains($0.value)||(0x2066...0x2069).contains($0.value)}.count
            return "双向控制字符 \(bidi) 个（需人工检查）"
        case 4:
            let maxLen=strings.map{$0.count}.max() ?? 0;return "最大文案 \(maxLen) 字符，\(maxLen>45 ? "建议检查小屏换行":"低风险")"
        case 5:
            let total=a.map{max(0,$0)}.reduce(0,+);return "动效时间 \(BM.fmt(total)) ms，\(total>2500 ? "建议缩减":"可接受")"
        case 6:
            let duplicate=i.strings.count-Set(i.strings).count
            return "共享手势标签重复 \(duplicate) 项（不代表真实冲突）"
        case 7:
            let count=i.flags.filter{$0}.count;return "叠加层拦截状态 \(count)/\(i.flags.count) 层"
        case 8:
            let tooLong=strings.filter{$0.count>100}.count
            return "冗长错误提示 \(tooLong) 条"
        default:
            let times=zip(a,a.dropFirst()).map{abs($0.0-$0.1)}
            return "触觉间隔方差 \(BM.fmt(BM.variance(times)))"
        }
    }
}
