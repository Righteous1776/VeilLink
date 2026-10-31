// ============================================================
// 五子棋引擎 Gomoku Engine v2 —— 准职业级
// 精确棋型识别 + VCF(连续冲四杀) + VCT(连续活三杀) + Zobrist换位表 + PVS迭代加深
// 浏览器 / Node 双端可用：暴露全局 GomokuEngine，Node 下挂 module.exports
// ============================================================
(function (root) {
  'use strict';

  const EMPTY = 0, BLACK = 1, WHITE = 2, SIZE = 15;
  const DIRS = [[0, 1], [1, 0], [1, 1], [1, -1]];

  // 评估分值（量级即优先级）
  const FIVE = 1e9, OPEN_FOUR = 1e7, FOUR = 1e5,
        OPEN_THREE = 1e4, CLOSED_THREE = 1e3, OPEN_TWO = 1e2, CLOSED_TWO = 1e1;
  // 组合威胁：四三(冲四+活三)≈必胜、双四、双活三。
  // 量级层级：FIVE(1e9) > OPEN_FOUR(1e7，一步必胜) > 四三/双四(8e6，数步必胜) > 冲四(1e5) > 双活三(3e5)
  // 黑棋双四/双三为禁手不可主动走，评估不给组合加成（见 comboBonus）
  const FOUR_THREE = 8e6, DOUBLE_FOUR = 8e6, DOUBLE_THREE = 3e5;

  // 棋型模式：'1'=己 '0'=空 '2'=对方/墙。覆盖中心判定在 pointShapes 内做。
  const SHAPES = {
    five:        ['11111'],
    openFour:    ['011110'],
    four:        ['11110', '01111', '11011', '10111', '11101'],
    openThree:   ['011100', '001110', '010110', '011010'],
    closedThree: ['11100', '00111', '11010', '01011', '10110', '01101', '11001', '10011'],
    openTwo:     ['001100', '011000', '000110', '010100', '001010'],
    closedTwo:   ['11000', '00011', '10100', '00101', '10010', '01001'],
  };
  const SHAPE_ORDER = ['five', 'openFour', 'four', 'openThree', 'closedThree', 'openTwo', 'closedTwo'];
  const SHAPE_SCORE = { five: FIVE, openFour: OPEN_FOUR, four: FOUR, openThree: OPEN_THREE, closedThree: CLOSED_THREE, openTwo: OPEN_TWO, closedTwo: CLOSED_TWO };

  // 预计算棋形查找表（位棋盘思想在 JS 中的等价实现）：枚举全部 3^9=19683 种 9 格线，
  // 一次性算好每种线含哪些威胁棋形，评估时 O(1) 查表，彻底省掉逐窗口扫棋形。
  // '0'=空 '1'=己 '2'=对方 —— 颜色无关，黑白评估复用同一张表。用 3 进制整数索引的扁平数组，
  // 避免字符串键字典模式退化，索引 = Σ digit*3^pos（digit∈{0,1,2}）。
  function _winIdx(s) { let v = 0; for (let i = 0; i < 9; i++) v = v * 3 + (s.charCodeAt(i) - 48); return v; }
  const LINE_TABLE = (function buildLineTable() {
    const table = new Array(19683).fill(null);
    const chars = ['0', '1', '2'];
    const rec = (i, cur) => {
      if (i === 9) {
        const keys = [];
        for (const k of SHAPE_ORDER) {
          let hit = false;
          for (const pat of SHAPES[k]) { if (cur.indexOf(pat) !== -1) { hit = true; break; } }
          if (hit) keys.push(k);
        }
        table[_winIdx(cur)] = keys;
        return;
      }
      for (const ch of chars) rec(i + 1, cur + ch);
    };
    rec(0, '');
    return table;
  })();

  // 中心覆盖表：9 格线索引 → 覆盖中心格子的最高威胁棋型（与 pointShapes 每方向"取最高"语义完全一致）。
  // 把 pointShapes / pointShapesAt 从"字符串拼接 + substr 匹配"换成 O(1) 数值查表，
  // legalMoves / moveKey / VCF / VCT / 禁手 全部提速，评估语义零变化。
  const CENTER_TABLE = (function buildCenterTable() {
    const table = new Array(19683).fill(null);
    const chars = ['0', '1', '2'];
    const rec = (i, cur) => {
      if (i === 9) {
        for (const k of SHAPE_ORDER) {
          let hit = false;
          for (const pat of SHAPES[k]) { if (matchCoverCenter(cur, pat, 4)) { hit = true; break; } }
          if (hit) { table[_winIdx(cur)] = k; return; }
        }
        return;
      }
      for (const ch of chars) rec(i + 1, cur + ch);
    };
    rec(0, '');
    return table;
  })();
  // 以 (r,c) 为中心取 9 格窗口的 3 进制索引（与 fastThreatScore 内层同构），供 CENTER_TABLE 查表
  function winIdx(board, r, c, dr, dc, player) {
    let v = 0;
    for (let j = -4; j <= 4; j++) {
      const nr = r + j * dr, nc = c + j * dc;
      let cell;
      if (!board.inBounds(nr, nc)) cell = 2;                       // 越界视为墙
      else { const bv = board.b[nr][nc]; cell = (bv === player ? 1 : (bv === EMPTY ? 0 : 2)); }
      v = v * 3 + cell;
    }
    return v;
  }

  // ---------- Zobrist ----------
  let _zob = null;
  function zobristInit() {
    _zob = [];
    for (let i = 0; i < SIZE * SIZE; i++) {
      _zob.push([0, (rand64()), (rand64())]); // EMPTY=0 不参与
    }
  }
  function rand64() {
    let h = '';
    for (let i = 0; i < 16; i++) h += (Math.floor(Math.random() * 16)).toString(16);
    // JS 位运算是 32 位有符号，这里用字符串异或不便；改用两个 32 位组合
    return { a: (Math.random() * 0xffffffff) | 0, b: (Math.random() * 0xffffffff) | 0 };
  }

  // ---------- 棋盘 ----------
  // 增量评估用线路元数据：15+15+29+29=88 条线，每条线由起点+方向唯一标识；
  // 每格固定属于 4 条线。play/undo 只重算经过该格的 4 条线，evaluate 变 O(1)。
  const LINES = (function buildLines() {
    const starts = [];       // [sr, sc, dr, dc]
    const cellLines = Array.from({ length: SIZE * SIZE }, () => []);
    const addLine = (sr, sc, dr, dc) => {
      const id = starts.length;
      starts.push([sr, sc, dr, dc]);
      let r = sr, c = sc;
      while (r >= 0 && r < SIZE && c >= 0 && c < SIZE) {
        cellLines[r * SIZE + c].push(id);
        r += dr; c += dc;
      }
    };
    for (let r = 0; r < SIZE; r++) addLine(r, 0, 0, 1);          // 水平
    for (let c = 0; c < SIZE; c++) addLine(0, c, 1, 0);          // 垂直
    for (let r = 0; r < SIZE; r++) addLine(r, 0, 1, 1);          // 主对角(含)
    for (let c = 1; c < SIZE; c++) addLine(0, c, 1, 1);
    for (let r = 0; r < SIZE; r++) addLine(r, SIZE - 1, 1, -1);  // 副对角(含)
    for (let c = SIZE - 2; c >= 0; c--) addLine(0, c, 1, -1);
    return { starts, cellLines };
  })();
  // 单条线的信息：黑白各自的{基础分, 四数(活四+冲四), 活三数}。无子/长度<5 的线返回 null（记 0）。
  // 基础分不含组合加成——组合(四三/双四/双三)按全盘聚合判定（见 comboBonus），跨线组合才会被识别
  function lineInfo(board, id) {
    const [sr, sc, dr, dc] = LINES.starts[id];
    const cells = [];
    let r = sr, c = sc, hasStone = false;
    while (board.inBounds(r, c)) { const v = board.b[r][c]; if (v !== EMPTY) hasStone = true; cells.push(v); r += dr; c += dc; }
    if (cells.length < 5 || !hasStone) return null;
    const cb = evalLine(cells, BLACK), cw = evalLine(cells, WHITE);
    return {
      b: { score: lineBaseScore(cb), f: cb.openFour + cb.four, t: cb.openThree },
      w: { score: lineBaseScore(cw), f: cw.openFour + cw.four, t: cw.openThree },
    };
  }

  class Board {
    constructor() {
      this.size = SIZE;
      this.b = Array.from({ length: SIZE }, () => new Array(SIZE).fill(EMPTY));
      this.lastMove = null; this.lastPlayer = EMPTY; this.stack = [];
      this.zkey = { a: 0, b: 0 };
      // 增量评估状态：每线分存黑白基础分与四/活三计数，组合加成按全盘聚合实时维护
      this._sb = new Float64Array(LINES.starts.length);
      this._sw = new Float64Array(LINES.starts.length);
      this._fb = new Float64Array(LINES.starts.length);
      this._fw = new Float64Array(LINES.starts.length);
      this._tb = new Float64Array(LINES.starts.length);
      this._tw = new Float64Array(LINES.starts.length);
      this._evalTotal = 0;   // Σ(_sb - _sw)
      this._totFb = 0; this._totTb = 0;  // 黑全盘四数/活三数合计（组合判定用）
      this._totFw = 0; this._totTw = 0;  // 白全盘四数/活三数合计
    }
    inBounds(r, c) { return r >= 0 && r < SIZE && c >= 0 && c < SIZE; }
    play(r, c, p) {
      this.b[r][c] = p; this.lastMove = [r, c]; this.lastPlayer = p; this.stack.push([r, c, p]);
      const z = _zob[r * SIZE + c][p];
      this.zkey.a = (this.zkey.a ^ z.a) >>> 0; this.zkey.b = (this.zkey.b ^ z.b) >>> 0;
      this._touch(r, c);
    }
    undo() {
      if (!this.stack.length) return;
      const [r, c, p] = this.stack.pop();
      this.b[r][c] = EMPTY;
      const z = _zob[r * SIZE + c][p];
      this.zkey.a = (this.zkey.a ^ z.a) >>> 0; this.zkey.b = (this.zkey.b ^ z.b) >>> 0;
      if (this.stack.length) { const [r2, c2, p2] = this.stack[this.stack.length - 1]; this.lastMove = [r2, c2]; this.lastPlayer = p2; }
      else { this.lastMove = null; this.lastPlayer = EMPTY; }
      this._touch(r, c);
    }
    // 重算经过 (r,c) 的 4 条线，增量维护基础分总和与全盘四/活三计数（组合加成在 evaluate 时 O(1) 聚合）
    _touch(r, c) {
      const ids = LINES.cellLines[r * SIZE + c];
      for (let i = 0; i < ids.length; i++) {
        const id = ids[i];
        const oB = this._sb[id], oW = this._sw[id];
        const oFb = this._fb[id], oFw = this._fw[id];
        const oTb = this._tb[id], oTw = this._tw[id];
        const n = lineInfo(this, id);
        const nb = n ? n.b : { score: 0, f: 0, t: 0 };
        const nw = n ? n.w : { score: 0, f: 0, t: 0 };
        this._sb[id] = nb.score; this._sw[id] = nw.score;
        this._fb[id] = nb.f; this._tb[id] = nb.t;
        this._fw[id] = nw.f; this._tw[id] = nw.t;
        this._evalTotal += (nb.score - nw.score) - (oB - oW);
        this._totFb += nb.f - oFb; this._totTb += nb.t - oTb;
        this._totFw += nw.f - oFw; this._totTw += nw.t - oTw;
      }
    }
    checkWin(r, c, p) {
      for (const [dr, dc] of DIRS) {
        let cnt = 1, nr = r + dr, nc = c + dc;
        while (this.inBounds(nr, nc) && this.b[nr][nc] === p) { cnt++; nr += dr; nc += dc; }
        nr = r - dr; nc = c - dc;
        while (this.inBounds(nr, nc) && this.b[nr][nc] === p) { cnt++; nr -= dr; nc -= dc; }
        if (cnt >= 5) return true;
      }
      return false;
    }
    candidates(radius = 2) {
      if (!this.stack.length) { const m = SIZE >> 1; return [[m, m]]; }
      const seen = new Set(), out = [];
      for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) {
        if (this.b[r][c] === EMPTY) continue;
        for (let dr = -radius; dr <= radius; dr++) for (let dc = -radius; dc <= radius; dc++) {
          const nr = r + dr, nc = c + dc;
          if (this.inBounds(nr, nc) && this.b[nr][nc] === EMPTY && !seen.has(nr * SIZE + nc)) {
            seen.add(nr * SIZE + nc); out.push([nr, nc]);
          }
        }
      }
      if (out.length) return out;
      // 保底：周围候选为空（致密残局）时回退扫描全部空点，避免上层漏算误判“无棋可走”
      for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) if (this.b[r][c] === EMPTY) out.push([r, c]);
      return out;
    }
    isFull() { return this.stack.length >= SIZE * SIZE; }
  }

  // ---------- 棋型识别（落子后，该点四方向形成的最高威胁） ----------
  function windowStr(board, r, c, dr, dc, player, span = 4) {
    let s = '';
    for (let i = -span; i <= span; i++) {
      const nr = r + i * dr, nc = c + i * dc;
      if (!board.inBounds(nr, nc)) s += '2';
      else { const v = board.b[nr][nc]; s += (v === EMPTY ? '0' : (v === player ? '1' : '2')); }
    }
    return s; // 长度 2*span+1，中心索引 = span
  }
  function matchCoverCenter(s, pat, center) {
    const pl = pat.length;
    for (let i = 0; i + pl <= s.length; i++) {
      if (i <= center && center < i + pl && s.substr(i, pl) === pat) return true;
    }
    return false;
  }
  // 查表版棋型识别：逐方向 O(1) 查 CENTER_TABLE，替代字符串拼接+substr 匹配
  // 返回 {five, openFour, four, openThree, closedThree, openTwo, closedTwo} 计数（四方向合计）
  function pointShapes(board, r, c, player) {
    board.b[r][c] = player;
    const res = { five: 0, openFour: 0, four: 0, openThree: 0, closedThree: 0, openTwo: 0, closedTwo: 0 };
    for (const [dr, dc] of DIRS) {
      const k = CENTER_TABLE[winIdx(board, r, c, dr, dc, player)];
      if (k) res[k]++;
    }
    board.b[r][c] = EMPTY;
    return res;
  }
  // 不复位版本：假设 (r,c) 已落 player，仅查表（供 evaluate/禁手复用）
  function pointShapesAt(board, r, c, player) {
    const res = { five: 0, openFour: 0, four: 0, openThree: 0, closedThree: 0, openTwo: 0, closedTwo: 0 };
    for (const [dr, dc] of DIRS) {
      const k = CENTER_TABLE[winIdx(board, r, c, dr, dc, player)];
      if (k) res[k]++;
    }
    return res;
  }
  // 单方向连长（含中心），用于长连禁手检测
  function lineLen(board, r, c, dr, dc, player) {
    let len = 1, nr = r + dr, nc = c + dc;
    while (board.inBounds(nr, nc) && board.b[nr][nc] === player) { len++; nr += dr; nc += dc; }
    nr = r - dr; nc = c - dc;
    while (board.inBounds(nr, nc) && board.b[nr][nc] === player) { len++; nr -= dr; nc -= dc; }
    return len;
  }
  // 黑棋禁手判定（前提：(r,c) 处已落 BLACK）。连珠规则：三三/四四/长连禁手，五连优先胜
  function forbiddenAt(board, r, c) {
    for (const [dr, dc] of DIRS) if (lineLen(board, r, c, dr, dc, BLACK) >= 6) return true; // 长连禁手优先
    const sh = pointShapesAt(board, r, c, BLACK);
    if (sh.five > 0) return false;                                  // 恰好五连 → 胜，非禁手
    const fours = sh.openFour + sh.four;
    if (fours >= 2) return true;                                     // 四四禁手
    if (sh.openThree >= 2) return true;                              // 三三禁手
    return false;
  }
  // 黑棋禁手（自动处理临时落子；若 (r,c) 已落子则直接判定不复位）
  function isForbidden(board, r, c) {
    // VeilLink freestyle: black 3-3 / 4-4 / 6+ is permitted.
    // Keep the exported API and the original search/VCF/VCT callers intact.
    return false;
  }
  // 合法着法：黑棋过滤禁手（白棋无禁手）。仅返回空点
  function legalMoves(board, player, limit = 24) {
    let cs = board.candidates();
    if (player === BLACK) cs = cs.filter(mv => !isForbidden(board, mv[0], mv[1]));
    const scored = cs.map(mv => [mv, moveKey(board, mv[0], mv[1], player)]);
    scored.sort((a, b) => b[1] - a[1]);
    return (limit && scored.length > limit ? scored.slice(0, limit) : scored).map(x => x[0]);
  }
  function makesFive(board, r, c, player) { return pointShapes(board, r, c, player).five > 0; }
  function makesOpenFour(board, r, c, player) { const s = pointShapes(board, r, c, player); return s.openFour > 0; }
  // 形成"四"（任意四威胁，含活四/冲四/跳四）
  function makesFour(board, r, c, player) { const s = pointShapes(board, r, c, player); return s.openFour + s.four > 0; }

  // (r,c) 已落 player 后，该四方向的"成五点"（填上即五连的空点），用于 VCF 找对方挡点
  function fivePointsOf(board, r, c, player) {
    const pts = [];
    const seen = new Set();
    // 沿四方向扫描可能的延伸空点
    for (const [dr, dc] of DIRS) {
      for (let i = -5; i <= 5; i++) {
        if (i === 0) continue;
        const nr = r + i * dr, nc = c + i * dc;
        if (board.inBounds(nr, nc) && board.b[nr][nc] === EMPTY) {
          const key = nr * SIZE + nc;
          if (seen.has(key)) continue; seen.add(key);
          if (makesFive(board, nr, nc, player)) pts.push([nr, nc]);
        }
      }
    }
    return pts;
  }

  // ---------- 线评估（按方向逐线打分，消除逐子累加的重复计数失真） ----------
  // 一条线（水平/垂直/两对角）只评估一次，棋型在线内出现即计，避免活三被多子重复计入
  function evalLine(cells, self) {
    // 直接按数值(0/1/2)算 3 进制索引，连字符串都不建；'1'=己 '2'=对方
    const L = cells.length, cnt = { five: 0, openFour: 0, four: 0, openThree: 0, closedThree: 0, openTwo: 0, closedTwo: 0 };
    const seen = new Set();
    for (let i = 0; i + 9 <= L; i++) {
      let v = 0;
      for (let j = 0; j < 9; j++) { const cell = cells[i + j]; v = v * 3 + (cell === self ? 1 : (cell === EMPTY ? 0 : 2)); }
      const keys = LINE_TABLE[v];
      if (!keys || !keys.length) continue;
      for (const k of keys) { if (!seen.has(k)) { seen.add(k); cnt[k]++; break; } } // 每条线每棋型只计一次
    }
    return cnt;
  }
  // 基础分：单条线棋型分值之和（不含组合加成）
  function lineBaseScore(cnt) {
    return cnt.five * FIVE + cnt.openFour * OPEN_FOUR + cnt.four * FOUR
      + cnt.openThree * OPEN_THREE + cnt.closedThree * CLOSED_THREE
      + cnt.openTwo * OPEN_TWO + cnt.closedTwo * CLOSED_TWO;
  }
  // 组合威胁加成（按全盘聚合）：四三(四≥1 且活三≥1)≈必胜；双四；双活三。
  // 跨线组合同样命中（一条线有冲四 + 另一条线有活三 = 四三），这是旧的"仅线内"评估漏掉的主战法。
  // 黑棋双四/双三为禁手（不能主动走），不给加成，避免误判"大优"误导搜索；四三非禁手，黑可走。
  function comboBonus(f, t, player) {
    if (f >= 1 && t >= 1) return FOUR_THREE;
    if (f >= 2) return DOUBLE_FOUR;
    if (t >= 2) return DOUBLE_THREE;
    return 0;
  }
  // 增量评估：基础分 O(1) 读取 + 组合加成按全盘聚合计数 O(1) 计算
  // （语义与 evaluateFull 完全一致，见下方保留的全盘扫描版本）
  function evaluate(board) {
    return board._evalTotal
      + comboBonus(board._totFb, board._totTb, BLACK)
      - comboBonus(board._totFw, board._totTw, WHITE);
  }
  // 全盘扫描版评估（黑-白）：仅用于基准/一致性校验，不参与搜索
  function evaluateFull(board) {
    let sb = 0, sw = 0, fb = 0, tb = 0, fw = 0, tw = 0;
    for (const [dr, dc] of DIRS) {
      const starts = [];
      if (dr === 0) { for (let r = 0; r < SIZE; r++) starts.push([r, 0]); }                 // 水平
      else if (dc === 0) { for (let c = 0; c < SIZE; c++) starts.push([0, c]); }             // 垂直
      else if (dr === 1 && dc === 1) { for (let r = 0; r < SIZE; r++) starts.push([r, 0]); for (let c = 1; c < SIZE; c++) starts.push([0, c]); }
      else { for (let r = 0; r < SIZE; r++) starts.push([r, SIZE - 1]); for (let c = SIZE - 2; c >= 0; c--) starts.push([0, c]); }
      for (const [sr, sc] of starts) {
        const cells = []; let r = sr, c = sc; let hasStone = false;
        while (board.inBounds(r, c)) { const v = board.b[r][c]; if (v !== EMPTY) hasStone = true; cells.push(v); r += dr; c += dc; }
        if (cells.length < 5) continue;
        if (!hasStone) continue;   // 空线无威胁，跳过整条扫描（中盘省约一半线）
        const cb = evalLine(cells, BLACK), cw = evalLine(cells, WHITE);
        sb += lineBaseScore(cb); sw += lineBaseScore(cw);
        fb += cb.openFour + cb.four; tb += cb.openThree;
        fw += cw.openFour + cw.four; tw += cw.openThree;
      }
    }
    return (sb + comboBonus(fb, tb, BLACK)) - (sw + comboBonus(fw, tw, WHITE));
  }

  // ---------- 着法排序 ----------
  // style: 'attack' 偏进攻（己方威胁加权）/ 'defense' 偏防守（对方威胁加权）/ 'balanced' 标准
  function moveKey(board, r, c, player, style) {
    const opp = player === BLACK ? WHITE : BLACK;
    const off = pointShapes(board, r, c, player); // 空点临时落子，pointShapes 内部复位，安全
    const def = pointShapes(board, r, c, opp);
    const comb = sh => {
      if (sh.five) return FIVE;
      if (sh.openFour) return OPEN_FOUR;
      const f = sh.openFour + sh.four, t = sh.openThree;
      if (f >= 1 && t >= 1) return FOUR_THREE;          // 四三≈必胜
      if (f >= 2) return DOUBLE_FOUR;                    // 双四
      if (t >= 2) return DOUBLE_THREE;                   // 双活三
      return sh.five * FIVE + sh.openFour * OPEN_FOUR + sh.four * FOUR + sh.openThree * OPEN_THREE
        + sh.closedThree * CLOSED_THREE + sh.openTwo * OPEN_TWO + sh.closedTwo * CLOSED_TWO;
    };
    const offScore = comb(off), defScore = comb(def);
    // 性格权重：进攻型更看重自己造威胁，防守型更看重化解对方威胁
    let offW = 1.0, defW = 0.9;
    if (style === 'attack') { offW = 1.18; defW = 0.82; }
    else if (style === 'defense') { offW = 0.95; defW = 1.2; }
    // 中心权重：开局/平手时倾向中心，量级小于 OPEN_TWO，不致喧宾夺主
    const center = (SIZE - 1) / 2;
    const cw = Math.max(0, 40 - (Math.abs(r - center) + Math.abs(c - center)));
    return Math.max(offScore * offW, defScore * defW) + cw;
  }
  function orderMoves(board, player, limit = 24, style) {
    const cands = board.candidates();
    const scored = cands.map(mv => [mv, moveKey(board, mv[0], mv[1], player, style)]);
    scored.sort((a, b) => b[1] - a[1]);
    return (limit && scored.length > limit ? scored.slice(0, limit) : scored).map(x => x[0]);
  }
  // 查表版威胁分：候选点四方向各取以该点为中心的 9 窗口，O(1) 查 LINE_TABLE 得威胁，
  // 替代 pointShapes 的字符串扫描，排序近乎免费（中心锚定近似，仅用于着法排序启发，评估仍以完整线扫描为准）
  function fastThreatScore(board, r, c, player) {
    let score = 0;
    for (const [dr, dc] of DIRS) {
      let v = 0;
      for (let j = -4; j <= 4; j++) {
        const nr = r + j * dr, nc = c + j * dc;
        let cell;
        if (!board.inBounds(nr, nc)) cell = 2;                       // 越界视为墙
        else { const bv = board.b[nr][nc]; cell = (bv === player ? 1 : (bv === EMPTY ? 0 : 2)); }
        v = v * 3 + cell;
      }
      const keys = LINE_TABLE[v];
      if (!keys) continue;
      for (const k of keys) {
        if (k === 'five') score += FIVE;
        else if (k === 'openFour') score += OPEN_FOUR;
        else if (k === 'four') score += FOUR;
        else if (k === 'openThree') score += OPEN_THREE;
        else if (k === 'closedThree') score += CLOSED_THREE;
        else if (k === 'openTwo') score += OPEN_TWO;
        else if (k === 'closedTwo') score += CLOSED_TWO;
      }
    }
    return score;
  }
  // 内部节点廉价排序：查表威胁分(无 pointShapes 字符串扫描)，黑棋仍过滤禁手；用于 PVS 深层提速。
  // 同时计入对方威胁（化解对方逼着与己方造威胁同权），与根节点 moveKey 语义一致，让剪枝/LMR 更有效
  function orderMovesFast(board, player, limit = 16) {
    let cs = board.candidates();
    if (player === BLACK) cs = cs.filter(mv => !isForbidden(board, mv[0], mv[1]));
    const opp = player === BLACK ? WHITE : BLACK;
    const center = (SIZE - 1) / 2;
    const scored = cs.map(mv => {
      const off = fastThreatScore(board, mv[0], mv[1], player);
      const def = fastThreatScore(board, mv[0], mv[1], opp);
      const v = Math.max(off, def) + Math.max(0, 40 - (Math.abs(mv[0] - center) + Math.abs(mv[1] - center)));
      return [mv, v];
    });
    scored.sort((a, b) => b[1] - a[1]);
    return (limit && scored.length > limit ? scored.slice(0, limit) : scored).map(x => x[0]);
  }
  // 查表版最高威胁等级（用于迫着空间窄化，近似中心锚定，仅排序/筛选用）
  const SHAPE_PRIO = { five: 7, openFour: 6, four: 5, openThree: 4, closedThree: 3, openTwo: 2, closedTwo: 1 };
  function fastThreatClass(board, r, c, player) {
    let best = 0;
    for (const [dr, dc] of DIRS) {
      let v = 0;
      for (let j = -4; j <= 4; j++) {
        const nr = r + j * dr, nc = c + j * dc;
        let cell;
        if (!board.inBounds(nr, nc)) cell = 2;
        else { const bv = board.b[nr][nc]; cell = (bv === player ? 1 : (bv === EMPTY ? 0 : 2)); }
        v = v * 3 + cell;
      }
      const keys = LINE_TABLE[v];
      if (!keys) continue;
      for (const k of keys) { if (SHAPE_PRIO[k] > best) best = SHAPE_PRIO[k]; }
    }
    return best;
  }
  // 迫着空间着法集：己方逼着(冲四/活三)+封堵对方逼着，再补齐 top-K 局面手（保持做棋能力）。
  // 用于 PVS 深层窄化分支；VCF/VCT 仍用精确 pointShapes 兜底，强杀不会漏。
  function threatMoves(board, player, posK = 6) {
    const opp = player === BLACK ? WHITE : BLACK;
    const cs = board.candidates();
    const seen = new Set(), threat = [];
    for (const mv of cs) {
      if (player === BLACK && isForbidden(board, mv[0], mv[1])) continue;
      const off = fastThreatClass(board, mv[0], mv[1], player);
      const def = fastThreatClass(board, mv[0], mv[1], opp);
      const pr = Math.max(off >= 5 ? off : 0, def >= 5 ? def - 0.5 : 0); // 冲四/活三/活四 类为逼着
      if (pr >= 5 - 1e-9) { threat.push(mv); seen.add(mv[0] * SIZE + mv[1]); }
    }
    if (posK > 0) {
      const tc = threat.length;
      const pos = orderMovesFast(board, player, posK + tc);
      for (const m of pos) { const k = m[0] * SIZE + m[1]; if (!seen.has(k)) { threat.push(m); seen.add(k); if (threat.length - tc >= posK) break; } }
    }
    return threat;
  }

  // ---------- VCF：连续冲四杀 ----------
  // 返回杀棋路径 [mv, block, mv2, block2, ...] 或 null
  function vcf(board, attacker, depth, tt, deadline) {
    if (Date.now() > deadline) return null;
    const defender = attacker === BLACK ? WHITE : BLACK;
    const key = board.zkey.a + ':' + board.zkey.b + ':v:' + attacker;
    if (tt.has(key)) { const e = tt.get(key); if (e.d >= depth) return e.r; }

    // 生成所有"形成四"的着法
    const cands = board.candidates();
    const fours = [];
    for (const mv of cands) {
      const sh = pointShapes(board, mv[0], mv[1], attacker);
      const n4 = sh.openFour + sh.four;
      if (n4 > 0) fours.push([mv, n4, sh.openFour]);
    }
    fours.sort((a, b) => (b[2] - a[2]) || (b[1] - a[1])); // 活四优先
    for (const [mv] of fours) {
      board.play(mv[0], mv[1], attacker);
      // 成五点：活四≥2 → 直接胜；冲四/跳四=1 → 对方必须挡该点
      const fives = fivePointsOf(board, mv[0], mv[1], attacker);
      if (fives.length >= 2) { board.undo(); tt.set(key, { d: depth, r: [mv] }); return [mv]; }
      if (attacker === BLACK && fives.length < 2 && isForbidden(board, mv[0], mv[1])) { board.undo(); continue; } // 四四/长连禁手，非杀
      if (fives.length === 0) { board.undo(); continue; }
      const block = fives[0];
      board.play(block[0], block[1], defender);
      let sub = null;
      if (depth - 1 > 0) sub = vcf(board, attacker, depth - 1, tt, deadline);
      board.undo();
      board.undo();
      if (sub !== null) { tt.set(key, { d: depth, r: [mv, block, ...sub] }); return [mv, block, ...sub]; }
    }
    tt.set(key, { d: depth, r: null });
    return null;
  }

  // ---------- VCT：连续活三+冲四杀（浅层，分支大） ----------
  function vct(board, attacker, depth, tt, deadline) {
    if (Date.now() > deadline) return null;
    const defender = attacker === BLACK ? WHITE : BLACK;
    // 生成形成"活三/冲四/活四"的着法
    const cands = board.candidates();
    const moves = [];
    for (const mv of cands) {
      if (attacker === BLACK && isForbidden(board, mv[0], mv[1])) continue; // 黑棋禁手不可走
      const sh = pointShapes(board, mv[0], mv[1], attacker);
      const threat = sh.openFour * 4 + sh.four * 2 + sh.openThree * 1;
      if (threat > 0) moves.push([mv, threat]);
    }
    moves.sort((a, b) => b[1] - a[1]);
    if (moves.length > 12) moves.length = 12;
    for (const [mv] of moves) {
      board.play(mv[0], mv[1], attacker);
      const fives = fivePointsOf(board, mv[0], mv[1], attacker);
      if (fives.length >= 2) { board.undo(); return [mv]; }            // 活四 → 胜
      if (fives.length === 1) {
        // 冲四：对方必须挡
        const block = fives[0];
        board.play(block[0], block[1], defender);
        let sub = depth - 1 > 0 ? vct(board, attacker, depth - 1, tt, deadline) : null;
        board.undo(); board.undo();
        if (sub !== null) return [mv, block, ...sub];
        continue;
      }
      // 活三：对方需防守（挡点 = 解掉所有活三/冲四威胁的着法，这里取对方"防守价值最高"的若干点）
      if (depth - 1 <= 0) { board.undo(); continue; }
      const defMoves = orderMoves(board, defender, 12);
      let allWin = defMoves.length > 0;
      for (const dm of defMoves) {
        board.play(dm[0], dm[1], defender);
        // 对方挡后若自己已成五(对方刚走不会成五)，检查己方是否仍有杀
        const sub = vct(board, attacker, depth - 1, tt, deadline);
        board.undo();
        if (sub === null) { allWin = false; break; }
      }
      board.undo();
      if (allWin) {
        // 简化：返回该着为杀起点（完整路径省略防守分支）
        return [mv];
      }
    }
    return null;
  }

  // ---------- PVS 常规搜索 ----------
  const TT_EXACT = 0, TT_LOWER = 1, TT_UPPER = 2;
  function pvs(board, depth, alpha, beta, color, start, timeLimit, tt, stats, pvOut, killers, style, fullOrder) {
    stats.nodes++;
    if (Date.now() - start > timeLimit) throw new _Timeout();
    const key = board.zkey.a + ':' + board.zkey.b + ':' + color;
    let ttHit = null;
    if (tt.has(key)) { ttHit = tt.get(key); if (ttHit.d >= depth) {
      if (ttHit.f === TT_EXACT) return ttHit.v;
      if (ttHit.f === TT_LOWER && ttHit.v >= beta) return ttHit.v;
      if (ttHit.f === TT_UPPER && ttHit.v <= alpha) return ttHit.v;
    }}
    if (board.lastMove !== null && board.checkWin(board.lastMove[0], board.lastMove[1], board.lastPlayer)) return -FIVE;
    if (depth === 0 || board.isFull()) return color * evaluate(board);
    const player = color > 0 ? BLACK : WHITE;
    // 着法排序：根节点用完整威胁评估(fullOrder)；内部节点用廉价 player-only 排序(fullOrder=false)，
    // 把全候选×2次 pointShapes 砍到×1，节点成本减半，使同等时间内搜得更深
    // 着法排序：根节点完整威胁评估；内部节点查表廉价排序。注：实测证明 depth>=2 全面窄化会漏看
    // 非冲四/活三级防守威胁导致被弱对手反杀，故保留全宽度搜索 + 快排序，深度靠评估/排序提速获得。
    let moves = fullOrder ? legalMoves(board, player, 20, style) : orderMovesFast(board, player, 20);
    const pref = [];
    if (ttHit && ttHit.mv && board.inBounds(ttHit.mv[0], ttHit.mv[1]) && board.b[ttHit.mv[0]][ttHit.mv[1]] === EMPTY) pref.push(ttHit.mv);
    if (killers && killers[depth] && board.inBounds(killers[depth][0], killers[depth][1]) && board.b[killers[depth][0]][killers[depth][1]] === EMPTY) pref.push(killers[depth]);
    if (pref.length) moves = pref.concat(moves.filter(m => !pref.some(p => p[0] === m[0] && p[1] === m[1])));
    // 仅保留空点：Zobrist 转置可能令 TT 记录走法指向已占点，必须过滤，否则会覆盖棋子、污染评估并回传非法着法
    moves = moves.filter(m => board.b[m[0]][m[1]] === EMPTY);
    if (!moves.length) return color * evaluate(board);
    let best = -Infinity, bestMv = moves[0], first = true;
    let flag = TT_UPPER;
    for (let mi = 0; mi < moves.length; mi++) {
      const mv = moves[mi];
      if (board.b[mv[0]][mv[1]] !== EMPTY) continue; // 双保险：绝不覆盖已落子
      board.play(mv[0], mv[1], player);
      let val;
      const childPV = [];
      if (first) { val = -pvs(board, depth - 1, -beta, -alpha, -color, start, timeLimit, tt, stats, childPV, killers, style, false); }
      else {
        // LMR：深度够、且非高优先走法（排序后第 4 位起）→ 减一层 null-window 试探，
        // fail-high 时满深度重搜，避免漏看；同等时间下搜得更深
        const rDepth = (depth >= 4 && mi >= 3) ? depth - 2 : depth - 1;
        val = -pvs(board, rDepth, -alpha - 1, -alpha, -color, start, timeLimit, tt, stats, childPV, killers, style, false);
        if (val > alpha && val < beta) {
          val = -pvs(board, depth - 1, -alpha - 1, -alpha, -color, start, timeLimit, tt, stats, childPV, killers, style, false);
          if (val > alpha && val < beta) val = -pvs(board, depth - 1, -beta, -alpha, -color, start, timeLimit, tt, stats, childPV, killers, style, false);
        }
      }
      board.undo();
      if (val > best) { best = val; bestMv = mv; if (pvOut) { pvOut.length = 0; pvOut.push(mv, ...childPV); } }
      if (best > alpha) { alpha = best; flag = TT_EXACT; }
      if (alpha >= beta) { flag = TT_LOWER; if (killers) killers[depth] = mv; break; }
      first = false;
    }
    tt.set(key, { d: depth, v: best, f: flag, mv: bestMv });
    return best;
  }
  class _Timeout {}

  // ---------- 持久化置换表：跨着/跨局复用，继承上一手搜索成果，剪枝效率倍增 ----------
  // 键含位置 Zobrist + 走子方，天然正确；仅在容量超限时整体清退，绝不按局手动清
  let _tt = new Map();
  function resetTT() { _tt = new Map(); }
  const TT_CAP = 400000;
  // ---------- 主搜索 ----------
  function chooseMove(board, player, timeLimit, opts) {
    if (!_zob) zobristInit();
    opts = opts || {};
    const style = opts.style || 'balanced';   // 性格：attack / balanced / defense
    const start = Date.now();
    const deadline = start + timeLimit * 1000;
    const stats = { nodes: 0 };
    const opp = player === BLACK ? WHITE : BLACK;
    const pvOut = [];

    // 0) 开局库：前几手走标准强点（天元 + 花月打点 + 对称应对），避免开局臭棋
    const om = openingMove(board, player);
    if (om) return { move: om, pv: [om], info: { depth: 1, nodes: 1, score: 0, time: Date.now() - start, kill: 'opening' } };

    // 1) 己方成五点 → 直接胜
    for (const mv of board.candidates()) if (makesFive(board, mv[0], mv[1], player)) {
      return { move: mv, pv: [mv], info: { depth: 1, nodes: 1, score: FIVE, time: Date.now() - start, kill: 'five' } };
    }
    // 2) 对方成五点 → 必挡
    for (const mv of board.candidates()) if (makesFive(board, mv[0], mv[1], opp)) {
      // 仍尝试在挡点中找最优，但必挡
      return { move: mv, pv: [mv], info: { depth: 1, nodes: 1, score: 0, time: Date.now() - start, kill: 'block-five' } };
    }
    // 3) VCF 探杀
    if (opts.vcf !== false) {
      const vcfTT = new Map();
      const path = vcf(board, player, opts.vcfDepth || 12, vcfTT, start + timeLimit * 1000 * 0.25);
      if (path && path.length && board.b[path[0][0]][path[0][1]] === EMPTY) {
        return { move: path[0], pv: path, info: { depth: path.length, nodes: stats.nodes, score: FIVE, time: Date.now() - start, kill: 'vcf' } };
      }
    }
    // 4) VCT 探杀（浅层，更耗时，时间充裕才开）
    if (opts.vct !== false && timeLimit >= 1.0) {
      const vctTT = new Map();
      const path = vct(board, player, opts.vctDepth || 5, vctTT, start + timeLimit * 1000 * 0.45);
      if (path && path.length && board.b[path[0][0]][path[0][1]] === EMPTY) {
        return { move: path[0], pv: path, info: { depth: path.length, nodes: stats.nodes, score: FIVE, time: Date.now() - start, kill: 'vct' } };
      }
    }
    // 5) PVS 迭代加深（复用持久化置换表 _tt，跨着继承剪枝信息）
    const tt = _tt;
    if (tt.size > TT_CAP) tt.clear();
    const maxDepth = opts.maxDepth || 10;
    const killers = new Array(maxDepth + 3).fill(null); // 杀手着法表，按层共享，提升剪枝效率
    let bestMove = null, bestScore = -Infinity, reached = 0;
    try {
      for (let depth = 1; depth <= maxDepth; depth++) {
        const color = player === BLACK ? 1 : -1;
        const curPV = [];
        const val = pvs(board, depth, -Infinity, Infinity, color, start, timeLimit * 1000, tt, stats, curPV, killers, style, true);
        if (curPV.length) { bestMove = curPV[0]; bestScore = val; pvOut.length = 0; pvOut.push(...curPV); reached = depth; }
        if (bestScore >= FIVE) break;
        if (bestScore <= -FIVE) break;
        if (Date.now() - start > timeLimit * 1000) break;
      }
    } catch (e) { if (!(e instanceof _Timeout)) throw e; }
    // 兜底：确保返回走法一定是空点（极端情况下 PVS 未产出 PV 时）
    if (!bestMove || board.b[bestMove[0]][bestMove[1]] !== EMPTY) {
      const ms = legalMoves(board, player, 1);
      bestMove = ms[0];
    }
    // 性格通过 PVS 内部着法排序偏好体现（进攻型前置进攻点 / 铁壁型前置防守点），
    // 影响搜索风格气质，但绝不覆盖搜索最优解——避免"强行有想法"反而送棋（深搜输浅搜的教训）
    return { move: bestMove, pv: pvOut, info: { depth: reached, nodes: stats.nodes, score: bestScore, time: Date.now() - start, kill: null } };
  }

  // ---------- 开局库：前几手标准强点（天元 + 花月打点 + 对称应对），黑棋规避禁手 ----------
  function openingMove(board, player) {
    const n = board.stack.length, m = 7;
    // VeilLink allows every first move: never apply center-only opening lines
    // to an unrelated first move played near the edge.
    if (n > 0 && board.b[m][m] === EMPTY) return null;
    const safe = (mv) => (mv && board.inBounds(mv[0], mv[1]) && board.b[mv[0]][mv[1]] === EMPTY) ? mv : null;
    if (n === 0) return [m, m];                                             // 黑1：天元
    if (n === 1) return safe([m, m + 1]);                                   // 白2：紧邻天元直指应对
    if (n === 2) {                                                          // 黑3：花月打点；被占则回退备选强点
      const t3 = safe([m + 1, m + 1]) || safe([m, m + 2]) || safe([m + 1, m]);
      if (t3 && player === BLACK && isForbidden(board, t3[0], t3[1])) return null; // 禁手则交搜索
      return t3;
    }
    if (n === 3) return safe([m + 1, m]);                                   // 白4：对称防守强点；被占则交搜索
    return null;                                                             // 4 手后交搜索
  }

  // ---------- 禁手陷阱：白棋主动落子逼黑棋出现多个禁手点（真算计，非查表） ----------
  function findForbiddenTrap(board, cands) {
    let best = null, bestN = 0;
    for (const mv of cands) {
      if (board.b[mv[0]][mv[1]] !== EMPTY) continue;
      board.b[mv[0]][mv[1]] = WHITE;
      let n = 0;
      for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) {
        if (board.b[r][c] === EMPTY && isForbidden(board, r, c)) n++; // 黑落此点即禁手
      }
      board.b[mv[0]][mv[1]] = EMPTY;
      if (n > bestN) { bestN = n; best = mv; }
    }
    return bestN >= 2 ? best : null; // 至少制造 2 个禁手点才算有效陷阱
  }
  // ---------- 性格化选点：势均力敌时按性格挑（破确定性 + 策略倾向） ----------
  function pickByStyle(board, cands, player, style) {
    if (style === 'attack') {                 // 进攻：选己方威胁最浓的点
      let best = cands[0], bv = -Infinity;
      for (const mv of cands) {
        const off = pointShapes(board, mv[0], mv[1], player);
        const v = off.openFour * 2 + off.four + off.openThree * 0.8;
        if (v > bv) { bv = v; best = mv; }
      }
      return best;
    }
    if (style === 'defense') {                // 防守：选把对方威胁压得最死的点
      let best = cands[0], bv = Infinity;
      for (const mv of cands) {
        const def = pointShapes(board, mv[0], mv[1], player === BLACK ? WHITE : BLACK);
        const v = def.openFour * 2 + def.four + def.openThree * 0.8;
        if (v < bv) { bv = v; best = mv; }
      }
      return best;
    }
    return cands[0];
  }

  // ---------- 导出 ----------
  zobristInit();
  root.GomokuEngine = {
    EMPTY, BLACK, WHITE, SIZE, DIRS,
    Board, evaluate, evaluateFull, pointShapes, makesFive, makesFour, makesOpenFour,
    fivePointsOf, vcf, vct, chooseMove, orderMoves, isForbidden, legalMoves, pointShapesAt,
    zobristInit, resetTT,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.GomokuEngine;
})(typeof window !== 'undefined' ? window : globalThis);
