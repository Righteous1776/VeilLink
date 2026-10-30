/* Monogatari v2.8.0 content overlay for VeilLink — full engine is upstream. */
monogatari.characters({
  h: { name: '鹭遥', color: '#c5d6ff' },
  q: { name: '齐夜', color: '#eec79d' },
  b: { name: '站内广播', color: '#80b6be' }
});
monogatari.assets('scenes', {});
monogatari.assets('music', {});
monogatari.assets('voices', {});
monogatari.assets('sounds', {});
monogatari.assets('images', {});
monogatari.assets('gallery', {});
monogatari.storage({ trust: 0, clues: 0 });

monogatari.script({
  Start: ["jump s00"],
  s00: [
    "show scene #07172b with fadeIn",
    "凌晨零点，东京湾的雨像一道没有尽头的玻璃幕墙。",
    "jump s01"
  ],
  s01: [
    "show scene #112339 with fadeIn",
    "b 末班列车已停止运行。请尚未离站的旅客前往第三站台。",
    "jump s02"
  ],
  s02: [
    "show scene #112339 with fadeIn",
    "h 你也收到了那条短信吗？发信人明明是……十年前关闭的车站。",
    "jump s03"
  ],
  s03: [
    "show scene #112339 with fadeIn",
    "扶梯下方传来短促的电流声。她伸出手，广播室的门却自行打开了。",
    { Choice: {
      follow: {
        Text: "先跟着鹭遥", Do: "jump s04a",
        onChosen: function () { this.storage({ trust: this.storage('trust') + 1 }); },
        onRevert: function () { this.storage({ trust: this.storage('trust') - 1 }); }
      },
      inspect: {
        Text: "检查旧广播设备", Do: "jump s04b",
        onChosen: function () { this.storage({ clues: this.storage('clues') + 1 }); },
        onRevert: function () { this.storage({ clues: this.storage('clues') - 1 }); }
      }
    } }
  ],
  s04a: [
    "show scene #111d31 with fadeIn",
    "h 谢谢你相信我。我曾经在这里等一个人，但我已经记不清那个人的声音。",
    "jump s05a"
  ],
  s05a: [
    "show scene #111d31 with fadeIn",
    "车窗外的街灯逐渐褪色，仿佛有人将城市的饱和度调低。",
    "jump s06"
  ],
  s04b: [
    "show scene #181927 with fadeIn",
    "控制台的纸带只打印出同一个时间：00:17。它似乎不是故障，而是有人刻意留下的坐标。",
    "jump s05b"
  ],
  s05b: [
    "show scene #181927 with fadeIn",
    "q 你找到了记录。记住，屏幕可以伪造，但机械纸带不会主动改写过去。",
    "jump s06"
  ],
  s06: [
    "show scene #111d31 with fadeIn",
    "q 这辆没有司机的列车，是一座被封存的通信中继站。",
    "jump s07"
  ],
  s07: [
    "show scene #111d31 with fadeIn",
    "h 如果消息能够穿过时间，那些没来得及说的话，是不是也可以送达？",
    "jump s08"
  ],
  s08: [
    "show scene #07172b with fadeIn",
    "雨线与高楼之间，最后一盏红色航标灯依然亮着。",
    "jump s09"
  ],
  s09: [
    "show scene #181927 with fadeIn",
    "q 主档案只够修复一次。你要相信一个人的记忆，还是这套冷冰冰的证据？",
    { Choice: {
      person: {
        Text: "相信鹭遥的记忆", Do: "jump s10a",
        onChosen: function () { this.storage({ trust: this.storage('trust') + 1 }); },
        onRevert: function () { this.storage({ trust: this.storage('trust') - 1 }); }
      },
      record: {
        Text: "追查档案里的真相", Do: "jump s10b",
        onChosen: function () { this.storage({ clues: this.storage('clues') + 1 }); },
        onRevert: function () { this.storage({ clues: this.storage('clues') - 1 }); }
      }
    } }
  ],
  s10a: [
    "show scene #112339 with fadeIn",
    "h 那我也试着相信自己。那条短信不是求救，而是约定。",
    "jump s11"
  ],
  s10b: [
    "show scene #181927 with fadeIn",
    "q 记录显示，每年今晚，这座车站都会替陌生人转送一条未寄出的消息。",
    "jump s11"
  ],
  s11: [
    "show scene #07172b with fadeIn",
    "屏幕倒计时只剩十秒。城市与车站之间，出现了最后一次选择。",
    { Choice: {
      publish: { Text: "将档案向全城公开", Do: "jump resolve_public" },
      guard: { Text: "保留车站，亲手送出消息", Do: "jump resolve_guard" }
    } }
  ],
  end_public: [
    "show scene #07172b with fadeIn",
    "真相变成全城都能读到的灯火。人们开始给失联的朋友写信，而你知道，今晚的雨终于有了回声。",
    "end"
  ],
  end_static: [
    "show scene #181927 with fadeIn",
    "消息被公开，却缺失关键的那一分钟。屏幕上的雪花噪点慢慢归于平静，留下等待下一位调查者的线索。",
    "end"
  ],
  end_dawn: [
    "show scene #112339 with fadeIn",
    "列车穿过海湾，清晨第一束光落在第三站台。鹭遥记起了那句约定，而你们终于将它送到了正确的地方。",
    "end"
  ],
  end_alone: [
    "show scene #111d31 with fadeIn",
    "广播响起，车门缓缓关闭。那封信被安全送达，至于发信人是谁，留给了下一场雨。",
    "end"
  ],
  resolve_public: [
    { Conditional: {
      Condition: function () { return this.storage('clues') >= 1; },
      True: "jump end_public", False: "jump end_static"
    } }
  ],
  resolve_guard: [
    { Conditional: {
      Condition: function () { return this.storage('trust') >= 1; },
      True: "jump end_dawn", False: "jump end_alone"
    } }
  ]
});
