'use strict';
/* global monogatari */
// Original, age-appropriate, fully offline VeilLink mini visual novel.
monogatari.characters({
  'l': { name: '澪', color: '#74c9ff' },
  't': { name: '拓', color: '#ffd6a2' }
});
monogatari.script({
  'Start': [
    'show scene #101a2e with fadeIn',
    '十月末，雨刚好停在车站的最后一盏灯前。',
    'l 你看到了吗？那张没有网络的地图，居然亮起了一处信号。',
    't 这里没有基站。我们收到的，可能只是另一个人的回答。',
    {'Choice': {
       'Dialog': '你想先做什么？',
       'Explore': {'Text':'顺着信号寻找车站','Do':'jump Station'},
       'Listen': {'Text':'留下来倾听雨声','Do':'jump Shelter'}
    }}
  ],
  'Station': [
    'show scene #23375e with fadeIn',
    '他们穿过空旷的站台。远处没有列车，只有缓慢闪烁的指示灯。',
    'l 原来有人在这里留下了离线留言。',
    't 一段消息也可能成为灯塔。只要有人愿意回应。',
    '信号被收进终端。两人决定把它带回城里。',
    'end'
  ],
  'Shelter': [
    'show scene #233038 with fadeIn',
    '屋檐下，雨滴从旧玻璃窗缓慢滑落。',
    't 有时先听清楚，比急着抵达更重要。',
    'l 那我们等一分钟。等下一条消息。',
    '当指示灯再次亮起时，他们知道旅途还没有结束。',
    'end'
  ]
});
