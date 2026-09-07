<script setup>
/**
 * @author： 监控大屏
 * @desc： 运维监控大屏 - 实时监控数据展示
 * @date： 2026-06-16
 */
import { ref, watch, onMounted, onUnmounted, nextTick, computed } from 'vue'
import { ElMessage, ElScrollbar } from 'element-plus'
import axios from 'axios'
import * as echarts from 'echarts'

// 修改 src/utils/publicData.js 中的 serverIp 定义
const RBAC_IP = ref(window.APP_CONFIG?.RBAC_IP || '127.0.0.1');
// ==================== 告警/ITSM 接口直连(与首页同源,组件内自持不经 api/homePage.js 转发) ====================
// 告警级别统计(严重/重要/一般): 入参日期 YYYY-MM-DD,返回 { critical/important/general/total, status }
const getAlertLevelData = async (date) => {
  try {
    const res = await axios.post(`${RBAC_IP.value}/getMonitoAlertLevelData`, { date })
    return res.data
  } catch (error) {
    console.error('获取告警级别数据失败:', error)
    throw error
  }
}

// 告警状态统计(闭环收敛: 今日已处理/待处理): 入参日期
const getAlertStatusData = async (date) => {
  try {
    const res = await axios.post(`${RBAC_IP.value}/getMonitoAlertStatusData`, { date })
    return res.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}

// 告警统计(今日新增告警数): 无入参,返回 { added: { today } }
const getAlertStatisticData = async () => {
  try {
    const res = await axios.get(`${RBAC_IP.value}/getMonitoAlertStatisticData`)
    return res.data
  } catch (error) {
    console.error('获取告警统计数据失败:', error)
    throw error
  }
}

// ITSM 工单待办 + SLA 达成率(首页 ITSM 待办卡片同源): 入参当前登录用户名
const getOrderData = async (username) => {
  try {
    const res = await axios.post(`${RBAC_IP.value}/getMonitoOrderData`, { username })
    return res.data
  } catch (error) {
    console.error('获取 ITSM 工单数据失败:', error)
    throw error
  }
}

// ==================== 告警真实数据(与首页/告警数据页面同源接口) ====================

// 告警中心统计(四大级别 + 闭环收敛): value/closed/processing 由接口填充,趋势文案为静态占位
const alertCenterData = ref({
  critical: { value: 0, trend: '环比 +8%', note: '未恢复 / 100% 响应', bar: 78 },
  major: { value: 0, trend: '环比 -3%', note: '处理中 9', bar: 52 },
  minor: { value: 0, trend: '持平', note: '轻度负载波动', bar: 40 },
  info: { value: 0, trend: '今日', note: '今日新增告警', bar: 95 },
  closed: 0,
  processing: 0,
})

// 闭环率 = 今日已处理 / (今日已处理 + 待处理)
const closureRate = computed(() => {
  const total = alertCenterData.value.closed + alertCenterData.value.processing
  return total > 0 ? ((alertCenterData.value.closed / total) * 100).toFixed(1) : '0.0'
})

// 频次推移快照序列: 每 5 分钟采样一次"今日新增"各级别告警总数(不论是否已处理),
// 横轴固定 24 个 5 分钟网格槽位(覆盖最近 2 小时);尚未采样的空槽以默认值占位填满窗口,
// 真实采样到达该槽位时原位覆盖默认值
const trendSeriesData = ref({ xData: [], crit: [], major: [], minor: [] })
// 采样周期: 每 5 分钟采样一次(数据拉取仅此周期进行)
const TREND_SAMPLE_INTERVAL = 5 * 60 * 1000
// 图形重绘周期: 每 3 秒完整重绘一次频次推移折线(仅重绘渲染,不触发数据拉取)
const TREND_REPAINT_INTERVAL = 10 * 1000
// 窗口容量: 24 个槽位 = 最近 2 小时(24 × 5 分钟)
const TREND_MAX_POINTS = 24
// 槽宽(分钟): 槽位时间轴锚定 5 分钟网格(如 14:00 / 14:05 / 14:10)
const TREND_SLOT_MINUTES = 5
// 空槽占位默认值: 尚无采样的槽位以 0 占位,采样到位后被真实值覆盖
const TREND_DEFAULT_VALUE = 0

// ==================== 实时未结告警列表: JS 流式无缝滚动 ====================
// 数据源: searchData 明细按发生时间倒序取前 12 条。
// 实现: 行对象持久化 + 轨道双份渲染 + 50ms 定时器步进位移(替代 CSS 动画)。
// 刷新不做整批替换: 最新集合中的新行进入补位队列,只在"某行完全滚出视口顶部"
// 的位置从队尾接入继续滚动;已不在最新未结集合的行滚出后移除——画面全程无跳变
const alertRows = ref([])
const pendingAlerts = ref([])
const rollOffset = ref(0)
const rollTrackEl = ref(null)
// 行单元高 = 单行高 + 行距(gap 6px),首帧实测;后续行高恒定(单行文本+固定 padding)
let rollUnit = 0
let rollTimer = null
let rollPaused = false
const ROLL_SPEED = 26
const ROLL_STEP_MS = 50
const ROLL_TRACK_GAP = 6

// 滚动主循环: 每 50ms 推进一次位移;队首行滚出视口后轮转/移除并补新,
// 同时位移回退一个行单元高做补偿,保证画面连续不跳
const rollTick = () => {
  const rows = alertRows.value
  if (rollPaused || !rows.length) return
  // 行单元高首帧实测(内容不换行,高度固定,实测一次即可)
  if (!rollUnit && rollTrackEl.value?.firstElementChild) {
    rollUnit = rollTrackEl.value.firstElementChild.offsetHeight + ROLL_TRACK_GAP
  }
  if (!rollUnit) return
  rollOffset.value += (ROLL_SPEED * ROLL_STEP_MS) / 1000
  // 队首行完全滚出视口顶部时: 未过时行轮转到队尾继续循环;
  // 过时行(已不在最新未结集合)移除,并取出补位队列中的新告警从队尾接入继续滚动
  while (rollOffset.value >= rollUnit && rows.length) {
    const head = rows.shift()
    if (head.stale) {
      const next = pendingAlerts.value.shift()
      if (next) rows.push(next)
    } else {
      rows.push(head)
    }
    rollOffset.value -= rollUnit
  }
  // 越过整份内容高度即回绕(轨道双份内容相同,回绕点视觉无缝)
  const half = rows.length * rollUnit
  if (half && rollOffset.value >= half) rollOffset.value -= half
}

// 按行原始发生时间重算相对时间文案(仅文本刷新,不影响滚动位置)
const refreshRowTimes = () => {
  alertRows.value.forEach(o => { o.time = relativeTime(o.raw) })
}

// 全栈基础设施与应用监控矩阵
const infraData = ref({
  host: { total: 248, health: '99.1%', offline: 2, cpu: 68, ram: 82, disk: 58, net: 73 },
  db: { total: 36, health: '100% 在线', pool: '76.4%', slow: '14 ops', replica: '< 0.05s', sessions: '1,285 个', qpsPeak: '9.8K' },
  middleware: { total: 52, kafkaLag: 1842, redisHit: '99.4%', rocket: '8,420/s', zk: '128 会话', es: 'Green 正常', retry: '0 个' },
  k8s: { pods: 1260, restarts: 8, clusters: '4 Clusters', nodes: '62/64 Ready', pending: '2 Pending', hpa: '12次 / 1h', cpuPct: '62%', memPct: '71%' },
  docker: { total: 3420, health: '99.8%', stopped: 14, oom: '0 触发', scan: '全合规', healthChk: '0 失败', logRate: '1.8 GB/h' },
  jvm: { threads: 8640, heap: '73.2%', youngGc: '28ms / 次', fullGc: '1次 / 1h', classes: '21.4K', deadlock: '0 个' },
  api: { total: 432, health: '99.98%', rtt: 38, err4xx: '0.31%', err5xx: '0.008%', p99: '86 ms', breaker: '0 激活' },
})

// 阿里云专有云企业套件监控
const cloudData = ref({
  ecs: { count: 512, health: '99.9% 稳定', cpu: '54.2%', mem: '61.8%', iops: '18.4K / 320MB/s', disk: '47%', ess: '就绪' },
  vpc: { routes: 42, zones: '42 个隔离区', vbr: '10G 双活', nat: '42.5 万 pps', eip: '128/150 已分配', vsw: '86 个', flowlog: '已开启' },
  slb: { count: 28, health: '100% 正常', qps: 24500, newConn: '12.6K /s', unhealthy: '0 台', ssl: '已开启', healthChk: '全通过' },
  security: { rules: 864, health: '防御中', audit: '全合规', blocks: 3182, ddos: 'Clean 5.2G', brute: '126 次', vuln: '0 高危' },
  rds: { instances: 24, health: '高可用 HA', replica: '< 0.08s', storage: '12.4 TB (61%)', backup: '已完成', cpu: '22%', conns: '1,842 个' },
  oss: { size: 184, health: '16 Buckets', bandwidth: '840 Mbps', reqQps: '42.6K', apiRate: '99.999%', objects: '2.86 亿', dr: '已同步' },
})

// ==================== 大屏轮播控制 ====================
// 两块大屏定义: 运维监控 / ITSM流程(标题在顶部正中间随轮播切换)
const screens = [
  { key: 'ops', title: '全栈智能运维告警监控中心' },
  { key: 'itsm', title: 'ITSM流程监控中心' },
]
const currentIndex = ref(0)
const currentScreen = computed(() => screens[currentIndex.value])

// 自动轮播配置(毫秒)，15秒自动轮播
const AUTO_PLAY_INTERVAL = 15000
// 轮播倒计时秒数: 由顶部倒计时环实时展示,归零时切换下一屏
const COUNTDOWN_TOTAL = AUTO_PLAY_INTERVAL / 1000
const countdown = ref(COUNTDOWN_TOTAL)
const autoPlayEnabled = ref(true)
const isHovering = ref(false)
let autoPlayTimer = null

// 倒计时环描边参数: 半径 12.5(适配按钮内边),剩余秒数越多环越满
const ringPerimeter = 2 * Math.PI * 12.5
const ringOffset = computed(() => ringPerimeter - (countdown.value / COUNTDOWN_TOTAL) * ringPerimeter)

const startAutoPlay = () => {
  if (autoPlayTimer) clearInterval(autoPlayTimer)
  autoPlayTimer = null
  if (!autoPlayEnabled.value) return
  autoPlayTimer = setInterval(() => {
    countdown.value--
    if (countdown.value <= 0) {
      countdown.value = COUNTDOWN_TOTAL
      currentIndex.value = (currentIndex.value + 1) % screens.length
    }
  }, 1000)
}

const stopAutoPlay = () => {
  if (autoPlayTimer) {
    clearInterval(autoPlayTimer)
    autoPlayTimer = null
  }
}

// 重新计时: 重置倒计时秒数并重启自动轮播定时器(仅手动切换大屏时使用)
const restartAutoPlay = () => {
  countdown.value = COUNTDOWN_TOTAL
  startAutoPlay()
}

const toggleAutoPlay = () => {
  autoPlayEnabled.value = !autoPlayEnabled.value
  // 恢复时从中断处继续倒计时,不重置进度环
  if (autoPlayEnabled.value) startAutoPlay()
  else stopAutoPlay()
}

// 切换到指定大屏(手动切换时重置自动轮播计时)
const switchScreen = (index) => {
  if (index === currentIndex.value) return
  currentIndex.value = index
  if (autoPlayEnabled.value) restartAutoPlay()
}

const prevScreen = () => switchScreen((currentIndex.value + screens.length - 1) % screens.length)
const nextScreen = () => switchScreen((currentIndex.value + 1) % screens.length)

// 鼠标悬停时暂停自动轮播,移出后恢复
const onMouseEnter = () => {
  isHovering.value = true
  stopAutoPlay()
}
const onMouseLeave = () => {
  isHovering.value = false
  // 移出后从中断处继续倒计时
  if (autoPlayEnabled.value) startAutoPlay()
}

// ==================== 全屏模式控制 ====================
// 快捷键 F11 进入/退出全屏; ESC 由浏览器原生退出全屏并自动同步状态
const isFullscreenMode = ref(false)

// 同步全屏状态: 通过 body 类驱动全局布局变化(隐藏侧边栏/顶栏并去除留白)
const syncFullscreenState = () => {
  const fullscreen = !!document.fullscreenElement
  isFullscreenMode.value = fullscreen
  document.body.classList.toggle('-fullscreen', fullscreen)
  // 全屏切换导致布局突变,mouseenter/leave 可能丢失而使悬停暂停状态卡死
  // 这里重置悬停状态并恢复轮播,倒计时从中断处继续
  isHovering.value = false
  if (autoPlayEnabled.value) startAutoPlay()
  // 全屏切换后重建告警图表,确保按新尺寸重新渲染
  rebuildCharts()
}

const toggleFullscreen = async () => {
  try {
    if (document.fullscreenElement) {
      await document.exitFullscreen()
    } else {
      await document.documentElement.requestFullscreen()
    }
  } catch {
    ElMessage.warning('当前浏览器不允许切换全屏模式')
  }
}

const handleKeydown = (e) => {
  if (e.key === 'F11') {
    // 拦截浏览器默认全屏,统一由组件管理全屏状态与布局隐藏
    e.preventDefault()
    toggleFullscreen()
  }
}

// ==================== 当前时间 ====================
const currentTime = ref('')
const updateTime = () => {
  const now = new Date()
  const pad = n => n.toString().padStart(2, '0')
  currentTime.value = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
}

// ==================== ECharts 图表 ====================
let charts = {}

const initCharts = () => {
  nextTick(() => {
    initClosureChart()
    initAlertStreamChart()
    initItmsCharts()
  })
}

// 告警闭环收敛环形图配置(供初始化与 3 秒周期重绘复用,每次重绘读取最新快照数据)
const buildClosureOption = () => ({
  tooltip: { trigger: 'item', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#00d4ff', textStyle: { color: '#e0e6ed' }, formatter: '{b}: {c} ({d}%)' },
  series: [{
    type: 'pie',
    radius: ['52%', '74%'],
    center: ['50%', '50%'],
    label: { show: true, position: 'center', formatter: `${closureRate.value}%
闭环率`, fontSize: 11, color: '#00d4ff', lineHeight: 14 },
    itemStyle: { borderRadius: 4, borderColor: '#0a142d', borderWidth: 2 },
    data: [
      { value: alertCenterData.value.closed, name: '已闭环', itemStyle: { color: '#00d4ff' } },
      { value: alertCenterData.value.processing, name: '处置中', itemStyle: { color: '#ffa502' } },
    ],
  }],
})

const initClosureChart = () => {
  const el = document.getElementById('chart-closure')
  if (!el) return
  const chart = echarts.init(el)
  charts.closure = chart
  chart.setOption(buildClosureOption())
}

// 频次推移折线完整配置(供初始化与周期重绘复用,每次重绘读取最新快照)
const buildTrendOption = (d) => ({
  tooltip: { trigger: 'axis', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#00d4ff', textStyle: { color: '#e0e6ed' } },
  legend: { data: ['严重', '重要', '一般'], textStyle: { color: '#a8b8d0', fontSize: 10 }, top: 0, left: 'center' },
  grid: { top: 26, right: 14, bottom: 22, left: 34 },
  // 横轴刻度只显示在偶数槽位(索引 1/3/5…,即第 2/4/6 个槽),每两个槽一个标签等效 10 分钟一刻度避免拥挤
  xAxis: { type: 'category', boundaryGap: false, data: d.xData, axisLabel: { color: '#7b8ca8', fontSize: 9, interval: index => index % 2 === 1 }, axisLine: { lineStyle: { color: '#1a2a4a' } }, axisTick: { show: false } },
  yAxis: { type: 'value', minInterval: 1, splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 9 } },
  series: [
    { name: '严重', type: 'line', smooth: true, symbol: 'none', data: d.crit, itemStyle: { color: '#ff4757' }, lineStyle: { width: 2 }, areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(255,71,87,0.45)' }, { offset: 1, color: 'rgba(255,71,87,0)' }]) } },
    { name: '重要', type: 'line', smooth: true, symbol: 'none', data: d.major, itemStyle: { color: '#ffa502' }, lineStyle: { width: 2 }, areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(255,165,2,0.35)' }, { offset: 1, color: 'rgba(255,165,2,0)' }]) } },
    { name: '一般', type: 'line', smooth: true, symbol: 'none', data: d.minor, itemStyle: { color: '#ffd93d' }, lineStyle: { width: 2 } },
  ],
})

// 告警动态频次推移折线图(今日各级别告警总数快照序列,每 5 分钟一个槽点,24 个槽点覆盖最近 2 小时)
const initAlertStreamChart = () => {
  const el = document.getElementById('chart-trend')
  if (!el) return
  const chart = echarts.init(el)
  charts.alertStream = chart
  chart.setOption(buildTrendOption(trendSeriesData.value))
}

// 3 秒周期完整重绘频次推移图: 清空画布后全量重放配置,保证每次定时触发都真实发生一次渲染
const repaintTrendChart = () => {
  const chart = charts.alertStream
  if (!chart) return
  chart.clear()
  chart.setOption(buildTrendOption(trendSeriesData.value))
}

// ==================== 真实告警数据接入 ====================
// 日期参数(YYYY-MM-DD,与首页告警分析一致)
const todayStr = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// 告警级别中文 → 列表样式类(严重红/重要橙/一般黄/普通青)
const LEVEL_MAP = { '严重': 'critical', '重要': 'major', '一般': 'minor', '普通': 'info' }

// 发生时间解析(兼容 "2026-3-25 09:25:00" 无前导零格式)与相对时间文案
const parseTime = (str) => new Date(String(str || '').replace(/-/g, '/')).getTime()
const relativeTime = (str) => {
  const t = parseTime(str)
  if (Number.isNaN(t)) return '-'
  const diffMin = Math.max(0, Math.floor((Date.now() - t) / 60000))
  if (diffMin < 60) return `${diffMin}m 前`
  if (diffMin < 60 * 24) return `${Math.floor(diffMin / 60)}h 前`
  return `${Math.floor(diffMin / (60 * 24))}d 前`
}

// 快照序列持久化(localStorage): 刷新或重开页面后恢复今日已积累的快照,跨天自动清空(今日累计语义下旧数据无意义)
// key 升级为 v2: 旧版为 15 秒粒度(6 分钟窗口),新版为 5 分钟粒度(2 小时窗口),时间格式不兼容旧缓存直接作废
const TREND_STORAGE_KEY = '-trend-series-v2'
// 快照序列所属日期: 用于跨天检测(页面不关跨越零点时清空序列,新一天从零开始积累)
let trendSeriesDate = todayStr()

// ==================== 5 分钟网格槽位工具 ====================
// 槽位标签 HH:mm ↔ 当日分钟数互转(用于按 5 分钟等差推算历史/未来槽位)
const labelToMinutes = label => {
  const [h, m] = label.split(':').map(Number)
  return h * 60 + m
}
const minutesToLabel = total => {
  // 模 1440 归一: 前推越过零点时自动回绕到前一日对应时刻
  total = ((total % 1440) + 1440) % 1440
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`
}
// 当前时刻所属的 5 分钟网格槽位(向下取整,如 14:07:23 → '14:05'),即本次采样写入的槽位
const currentSlotLabel = () => {
  const n = new Date()
  return minutesToLabel(Math.floor((n.getHours() * 60 + n.getMinutes()) / TREND_SLOT_MINUTES) * TREND_SLOT_MINUTES)
}
const saveTrendSeries = () => {
  try {
    localStorage.setItem(TREND_STORAGE_KEY, JSON.stringify({ date: todayStr(), ...trendSeriesData.value }))
  } catch {
    // localStorage 不可用(隐私模式等)时静默跳过
  }
}
const restoreTrendSeries = () => {
  try {
    const saved = JSON.parse(localStorage.getItem(TREND_STORAGE_KEY) || 'null')
    if (saved && saved.date === todayStr() && Array.isArray(saved.xData)) {
      trendSeriesData.value = { xData: saved.xData, crit: saved.crit || [], major: saved.major || [], minor: saved.minor || [] }
      trendSeriesDate = saved.date
    }
  } catch {
    // 存储数据损坏时静默忽略
  }
}

// 将推移窗口重建为"以 current 槽位为右端、连续 24 个 5 分钟槽位"的完整窗口:
// 仍落在窗口内的旧值按槽位原样迁移,新滑入/从未采样的空槽以默认值占位,
// 窗口始终铺满,曲线不用等 2 小时才填满横轴;每次采样前重建也顺带剔除非网格残留标签
const ensureTrendWindow = (current) => {
  const t = trendSeriesData.value
  const xData = [], crit = [], major = [], minor = []
  for (let i = TREND_MAX_POINTS - 1; i >= 0; i--) {
    const label = minutesToLabel(labelToMinutes(current) - i * TREND_SLOT_MINUTES)
    const idx = t.xData.indexOf(label)
    xData.push(label)
    crit.push(idx >= 0 ? t.crit[idx] : TREND_DEFAULT_VALUE)
    major.push(idx >= 0 ? t.major[idx] : TREND_DEFAULT_VALUE)
    minor.push(idx >= 0 ? t.minor[idx] : TREND_DEFAULT_VALUE)
  }
  t.xData = xData
  t.crit = crit
  t.major = major
  t.minor = minor
}

// 快照记录: 拉取今日各级别告警总数(发生时间是今日,不论是否已处理),
// 写入当前 5 分钟槽位,该槽位若为空槽(默认值占位)即被真实数据原位覆盖
const recordTrendSnapshot = async () => {
  try {
    // 跨天检测: 页面不关跨越零点时清空序列,今日累计从零重新开始
    const today = todayStr()
    if (today !== trendSeriesDate) {
      trendSeriesDate = today
      trendSeriesData.value = { xData: [], crit: [], major: [], minor: [] }
    }
    const d = await getAlertLevelData(today)
    if (d?.status !== 'success') return
    const t = trendSeriesData.value
    // 采样槽位 = 此刻所在的 5 分钟网格(横轴标签 HH:mm),窗口右端随采样推进
    const bucket = currentSlotLabel()
    ensureTrendWindow(bucket)
    const idx = t.xData.indexOf(bucket)
    t.crit[idx] = d.critical
    t.major[idx] = d.important
    t.minor[idx] = d.general
    // 数据落槽后走全量重绘路径(与 3 秒重绘同入口,避免增量 setOption 与 clear 重绘互相丢失配置)
    repaintTrendChart()
    saveTrendSeries()
  } catch (e) {
    console.error('频次推移快照失败:', e)
  }
}

// 数据到达后刷新闭环收敛图(图表实例未初始化时跳过,initCharts 会读取最新数据渲染);
// 整图重绘与 3 秒周期共用同入口,避免增量 setOption 与 clear 重绘互相丢失配置
const updateClosureChart = () => {
  if (charts.closure) {
    charts.closure.clear()
    charts.closure.setOption(buildClosureOption())
  }
}

// 拉取告警明细(按发生时间倒序取前 12 条),与滚动轨道做增量合并而非整批替换:
// 直连原始接口而非 api/interface.js 的 searchData 封装,避免触发其中耦合的语音播报副作用
const fetchAlertDetail = async () => {
  try {
    const rows = await axios.post(`${RBAC_IP.value}/searchMonitorData`, {}).then(r => (r.data && r.data.data) || [])
    const list = [...rows]
      .sort((a, b) => (parseTime(b.occurrenceTime) || 0) - (parseTime(a.occurrenceTime) || 0))
      .slice(0, 12)
      .map(r => ({
        // id 稳定标识同一条告警,作为双份轨道 DOM 复用的 key(刷新时行不被重建)
        id: `${r.system_name || '-'}|${r.occurrenceTime}|${r.alarm_details || '-'}`,
        level: r.severity || '普通',
        levelClass: LEVEL_MAP[r.severity] || 'info',
        src: r.system_name || '-',
        desc: r.alarm_details || '-',
        raw: r.occurrenceTime,
        time: relativeTime(r.occurrenceTime),
      }))
    if (!alertRows.value.length) {
      // 首次拉取(或轨道滚空): 直接铺满轨道并回到起点,等待滚动推进
      alertRows.value = list
      rollOffset.value = 0
      rollUnit = 0
    } else {
      // 增量合并: 仍在最新集合的行照常轮转;不在的标记过时(滚出后移除);
      // 最新集合中的新行(含上次未消费的补位)按序进入补位队列
      const newIds = new Set(list.map(n => n.id))
      alertRows.value.forEach(o => { o.stale = !newIds.has(o.id) })
      const exists = id =>
        alertRows.value.some(o => o.id === id) || pendingAlerts.value.some(p => p.id === id)
      pendingAlerts.value = [...pendingAlerts.value, ...list.filter(n => !exists(n.id))]
    }
    refreshRowTimes()
  } catch (e) {
    console.error('告警明细查询失败:', e)
  }
}

// 拉取真实告警数据: 统计卡/闭环收敛 30 秒周期刷新;频次推移数据采样由 5 分钟定时器负责、图形重绘由 3 秒定时器负责;未结列表由 15 秒定时器负责
const fetchRealtimeData = async () => {
  const [levelRes, statRes, statusRes] = await Promise.allSettled([
    getAlertLevelData(todayStr()),
    getAlertStatisticData(),
    getAlertStatusData(todayStr()),
  ])
  // 告警级别统计 → 严重/重要/一般统计卡(数值与占比进度条同步)
  if (levelRes.status === 'fulfilled' && levelRes.value?.status === 'success') {
    const d = levelRes.value
    const pct = v => (d.total > 0 ? Math.round((v / d.total) * 100) : 0)
    alertCenterData.value.critical.value = d.critical
    alertCenterData.value.critical.bar = pct(d.critical)
    alertCenterData.value.major.value = d.important
    alertCenterData.value.major.bar = pct(d.important)
    alertCenterData.value.minor.value = d.general
    alertCenterData.value.minor.bar = pct(d.general)
  }
  // 告警统计 → 新增告警卡(今日新增)
  if (statRes.status === 'fulfilled' && statRes.value?.status === 'success') {
    alertCenterData.value.info.value = statRes.value.added.today
  }
  // 告警状态 → 闭环收敛: 已闭环=今日已处理,处置中=待处理
  if (statusRes.status === 'fulfilled' && statusRes.value?.status === 'success') {
    alertCenterData.value.closed = statusRes.value.completed
    alertCenterData.value.processing = statusRes.value.unprocessed
  }
  updateClosureChart()
}

// ==================== 第2屏 ITSM 工单真实数据(与首页 ITSM 待办同源接口) ====================
// 数据源: getOrderData(username) —— 首页 ITSM 工单卡片(App.vue 待办检查)同一接口,
// 返回五类待办工单列表 + sla 达成率统计 + 近 7 日趋势(week_trend/sla_trend,后端模拟)
const ITSM_ORDER_TYPES = ['request', 'publish', 'event', 'change', 'problem']
// 工单类型展示元信息: 中文名 + 图表配色(语义对应首页 ITSM tab: 请求紫/发布青/事件绿/变更橙/问题红)
const ITSM_CATEGORY_META = {
  request: { label: '请求', color: '#a78bfa' },
  publish: { label: '发布', color: '#00d4ff' },
  event: { label: '事件', color: '#00ff88' },
  change: { label: '变更', color: '#ffa502' },
  problem: { label: '问题', color: '#ff4757' },
}
// 工单处理状态 → 状态文字颜色(走马灯卡片显示)
const ITSM_STATUS_COLOR = {
  '处理中': '#00d4ff', '审批中': '#00d4ff', '发布中': '#00d4ff', '实施中': '#00d4ff',
  '已受理': '#00ff88', '待处理': '#ffa502', '待审批': '#ffa502',
}
// 走马灯: 悬停暂停水平滚动(与第一屏未结告警列表交互一致)
const tickerPaused = ref(false)
// 创建时间短显(MM-dd HH:mm)
const shortOrderTime = (str) => (str || '').slice(5, 16)
const itsmData = ref({
  request: [],
  publish: [],
  event: [],
  change: [],
  problem: [],
  // SLA 达成率: rate 达成率 / total 周期总工单 / achieved 达标 / overtime 超时 / baseline 目标基线
  sla: { rate: 99.98, total: 0, achieved: 0, overtime: 0, baseline: 99.5 },
  // 近 7 日趋势(第三排图表): 每日五类新建数 / 每日达成率
  week_trend: [],
  sla_trend: [],
})

// 工单总览合计: 五类待办工单总数
const itsmTodoTotal = computed(() =>
  ITSM_ORDER_TYPES.reduce((sum, type) => sum + (itsmData.value[type]?.length || 0), 0)
)

// 工单总览五类占比行(卡片内嵌微条数据): 类别名/色板/数量/占待办总量百分比,实时跟随接口数据
const itsmOverviewRows = computed(() => {
  const total = itsmTodoTotal.value
  return ITSM_ORDER_TYPES.map(type => {
    const count = itsmData.value[type]?.length || 0
    return {
      label: ITSM_CATEGORY_META[type].label,
      color: ITSM_CATEGORY_META[type].color,
      count,
      pct: total > 0 ? Math.round((count / total) * 1000) / 10 : 0,
    }
  })
})

// SLA 卡三行占比条数据: 周期工单为满量基线(100%),达标绿/超时红 = 各自数量 / 周期工单总数
const slaOverviewRows = computed(() => {
  const s = itsmData.value.sla || {}
  const total = Number(s.total) || 0
  const pctOf = v => (total > 0 ? Math.round((v / total) * 1000) / 10 : 0)
  const achieved = Number(s.achieved) || 0
  const overtime = Number(s.overtime) || 0
  return [
    { label: '周期工单', count: total, pct: total > 0 ? 100 : 0, tip: '周期工单总量', color: '#00d4ff', valClass: 'c-info' },
    { label: '达标工单', count: achieved, pct: pctOf(achieved), tip: total > 0 ? `占周期工单 ${pctOf(achieved)}%` : '暂无数据', color: '#00ff88', valClass: 'c-good' },
    { label: '超时工单', count: overtime, pct: pctOf(overtime), tip: total > 0 ? `占周期工单 ${pctOf(overtime)}%` : '暂无数据', color: '#ff4757', valClass: 'c-bad' },
  ]
})

// 工单分类占比: 近 7 日五类工单合计(week_trend 派生,与工单趋势图同口径),供饼图直接消费
const itsmCategoryStat = computed(() =>
  ITSM_ORDER_TYPES.map(type => ({
    name: ITSM_CATEGORY_META[type].label,
    value: (itsmData.value.week_trend || []).reduce((sum, d) => sum + (Number(d[type]) || 0), 0),
    color: ITSM_CATEGORY_META[type].color,
  })).filter(item => item.value > 0)
)

// 走马灯明细流: 五类工单合流,按提交时间倒序(最新在前),每条携带类别标签/配色/状态色
const itsmTickerRows = computed(() =>
  ITSM_ORDER_TYPES
    .flatMap(type =>
      (itsmData.value[type] || []).map(o => ({
        ...o,
        typeLabel: ITSM_CATEGORY_META[type].label,
        typeColor: ITSM_CATEGORY_META[type].color,
        statusColor: ITSM_STATUS_COLOR[o.status] || '#7b8ca8',
      }))
    )
    .sort((a, b) => (parseTime(b.createTime) || 0) - (parseTime(a.createTime) || 0))
)

// 走马灯滚动周期随明细数量自适应: 每卡约 394px 折算约 40px/s,保底 80s
const tickerDuration = computed(() =>
  itsmTickerRows.value.length
    ? Math.max(80, Math.ceil((itsmTickerRows.value.length * 394) / 40))
    : 80
)

// 拉取 ITSM 工单待办与 SLA 达成率(30 秒周期与告警统计同频)
const fetchItmsData = async () => {
  const username = sessionStorage.getItem('user')
  if (!username) return
  try {
    const res = await getOrderData(username)
    if (res?.status !== 'success') return
    ITSM_ORDER_TYPES.forEach(type => { itsmData.value[type] = res[type] || [] })
    if (res.sla) itsmData.value.sla = { ...itsmData.value.sla, ...res.sla }
    if (Array.isArray(res.week_trend)) itsmData.value.week_trend = res.week_trend
    if (Array.isArray(res.sla_trend)) itsmData.value.sla_trend = res.sla_trend
    // 趋势/占比图表数据刷新(图表未初始化时跳过,initItmsCharts 会读取最新数据)
    updateItmsCharts()
  } catch (e) {
    console.error('ITSM 工单数据拉取失败:', e)
  }
}

// ==================== 第2屏 ITSM 图表(第三排: 工单趋势/分类占比/SLA达成趋势) ====================
// 深色大屏统一 tooltip 皮肤(与第1屏图表一致)
const itmsTooltip = { backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#00d4ff', textStyle: { color: '#e0e6ed' } }

// 工单趋势(近 7 日): 五类工单每日新建数折线,颜色与分类色板一致(请求紫/发布青/事件绿/变更橙/问题红)
const buildOrderTrendOption = (rows) => {
  const list = rows || []
  return {
    tooltip: { ...itmsTooltip, trigger: 'axis' },
    legend: {
      data: ITSM_ORDER_TYPES.map(t => ITSM_CATEGORY_META[t].label),
      textStyle: { color: '#a8b8d0', fontSize: 10 },
      top: 0,
      left: 'center',
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      itemGap: 14,
    },
    grid: { top: 30, right: 14, bottom: 24, left: 36 },
    xAxis: { type: 'category', boundaryGap: false, data: list.map(r => r.date), axisLabel: { color: '#7b8ca8', fontSize: 10 }, axisLine: { lineStyle: { color: '#1a2a4a' } }, axisTick: { show: false } },
    yAxis: { type: 'value', minInterval: 1, splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10 } },
    series: ITSM_ORDER_TYPES.map(t => ({
      name: ITSM_CATEGORY_META[t].label,
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 4.5,
      data: list.map(r => Number(r[t]) || 0),
      itemStyle: { color: ITSM_CATEGORY_META[t].color },
      lineStyle: { width: 2 },
      emphasis: { focus: 'series' },
    })),
  }
}

// 工单分类占比(近 7 日): 横向条形图 —— 宽扁卡片内条形比环形图更饱满,条长=数量;
// 类目自顶向下按五类色板顺序,尾标显示 单数 + 占比;值轴留 1.3 倍余量防长条尾标越界
const buildCategoryOption = (list) => {
  const total = list.reduce((sum, it) => sum + (Number(it.value) || 0), 0)
  const pctOf = v => (total > 0 ? Math.round((v / total) * 1000) / 10 : 0)
  return {
    tooltip: {
      ...itmsTooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: ps => {
        const p = ps && ps[0]
        return p ? `${p.name}: <b>${p.value} 单</b> · 占近 7 日 ${pctOf(p.value)}%` : ''
      },
    },
    grid: { top: 6, right: 4, bottom: 2, left: 40 },
    xAxis: {
      type: 'value',
      axisLabel: { show: false },
      splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } },
      max: v => Math.ceil(v.max * 1.3),
    },
    yAxis: {
      type: 'category',
      inverse: true,
      data: list.map(i => i.name),
      axisLine: { lineStyle: { color: '#1a2a4a' } },
      axisTick: { show: false },
      axisLabel: { color: '#a8b8d0', fontSize: 12 },
    },
    series: [{
      type: 'bar',
      barWidth: 15,
      label: {
        show: true,
        position: 'right',
        color: '#e0e6ed',
        fontFamily: "'Courier New', monospace",
        fontSize: 12,
        formatter: p => `${p.value} 单 · ${pctOf(p.value)}%`,
      },
      itemStyle: { borderRadius: [0, 5, 5, 0] },
      data: list.map(i => ({ value: i.value, itemStyle: { color: i.color } })),
    }],
  }
}

// SLA 达成率趋势(近 7 日): 平滑折线 + 目标基线参考线
const buildSlaTrendOption = (rows) => {
  const list = rows || []
  return {
    tooltip: {
      ...itmsTooltip,
      trigger: 'axis',
      formatter: params => `${params[0]?.axisValue} 达成率: <b>${params[0]?.data}%</b>`,
    },
    grid: { top: 28, right: 16, bottom: 24, left: 42 },
    xAxis: { type: 'category', boundaryGap: false, data: list.map(r => r.date), axisLabel: { color: '#7b8ca8', fontSize: 10 }, axisLine: { lineStyle: { color: '#1a2a4a' } }, axisTick: { show: false } },
    yAxis: { type: 'value', min: 98, max: 101, splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10, formatter: '{value}%' } },
    series: [{
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 5,
      data: list.map(r => r.rate),
      itemStyle: { color: '#00ff88' },
      lineStyle: { width: 2 },
      areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(0,255,136,0.35)' }, { offset: 1, color: 'rgba(0,255,136,0)' }]) },
      markLine: {
        silent: true,
        symbol: 'none',
        data: [{ yAxis: itsmData.value.sla.baseline }],
        lineStyle: { color: '#ffa502', type: 'dashed', width: 1 },
        label: { formatter: `基线 ${itsmData.value.sla.baseline}%`, color: '#ffa502', fontSize: 9, position: 'insideEndTop' },
      },
    }],
  }
}

// 第三排三图表初始化(挂载时统一调用,未拉回数据前以默认空态渲染)
const initItmsCharts = () => {
  const orderTrendEl = document.getElementById('chart-order-trend')
  if (orderTrendEl) {
    const chart = echarts.init(orderTrendEl)
    charts.orderTrend = chart
    chart.setOption(buildOrderTrendOption(itsmData.value.week_trend))
  }
  const categoryEl = document.getElementById('chart-order-category')
  if (categoryEl) {
    const chart = echarts.init(categoryEl)
    charts.orderCategory = chart
    chart.setOption(buildCategoryOption(itsmCategoryStat.value))
  }
  const slaTrendEl = document.getElementById('chart-sla-trend')
  if (slaTrendEl) {
    const chart = echarts.init(slaTrendEl)
    charts.slaTrend = chart
    chart.setOption(buildSlaTrendOption(itsmData.value.sla_trend))
  }
}

// 数据到达后整图重绘(clear + setOption 全量重放,与第1屏重绘风格一致)
const updateItmsCharts = () => {
  if (charts.orderTrend) {
    charts.orderTrend.clear()
    charts.orderTrend.setOption(buildOrderTrendOption(itsmData.value.week_trend))
  }
  if (charts.orderCategory) {
    charts.orderCategory.clear()
    charts.orderCategory.setOption(buildCategoryOption(itsmCategoryStat.value))
  }
  if (charts.slaTrend) {
    charts.slaTrend.clear()
    charts.slaTrend.setOption(buildSlaTrendOption(itsmData.value.sla_trend))
  }
}

// 第1屏闭环环形图 + 第2屏三图 3 秒周期整组重绘: 清空画布后全量重放配置,
// 与频次推移折线图同节奏(数据 30 秒才刷新,重绘仅保持画面实时渲染动感)
const repaintSnapshotCharts = () => {
  updateClosureChart()
  updateItmsCharts()
}

// 数值千分位格式化(等宽字体大数展示)
const numFmt = (v, dec = 0) => Number(v).toFixed(dec).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
const clampN = (v, min, max) => (v < min ? min : v > max ? max : v)

// ==================== 生命周期 ====================
let timeTimer = null
// 真实数据定时刷新(30s)/频次推移采样(5min)/频次推移重绘(3s)/未结列表滚动刷新(15s)/数据微抖动定时器
let refreshTimer = null
let trendRefreshTimer = null
let trendRepaintTimer = null
let detailRefreshTimer = null
let itsmRefreshTimer = null
let snapshotRepaintTimer = null
let jitterTimer = null

// 窗口尺寸变化时重新校准图表
const handleWindowResize = () => {
  Object.values(charts).forEach(c => c && c.resize())
}

// 全屏切换后彻底重建图表: dispose 旧实例并清空流式定时器,
// 待全屏布局(顶栏隐藏/容器高度切换)稳定后按新尺寸重新初始化
const rebuildCharts = () => {
  Object.values(charts).forEach(c => c && c.dispose())
  charts = {}
  setTimeout(initCharts, 300)
}

// 切换大屏后重新校准图表尺寸,避免布局偏移导致图表渲染异常
watch(currentIndex, () => {
  nextTick(() => {
    Object.values(charts).forEach(c => c && c.resize())
  })
})

onMounted(() => {
  updateTime()
  timeTimer = setInterval(updateTime, 1000)
  setTimeout(initCharts, 100)
  startAutoPlay()
  // 恢复今日已积累的频次推移快照(刷新页面不丢失)
  restoreTrendSeries()
  // 立即铺满 24 槽窗口: 尚未采样的空槽以默认值占位,曲线起步即占满最近 2 小时横轴,采样后原位覆盖
  ensureTrendWindow(currentSlotLabel())
  // 拉取真实告警数据(与首页同源): 统计/闭环 30 秒;频次推移 5 分钟采样 + 3 秒重绘;未结列表 15 秒滚动
  fetchRealtimeData()
  recordTrendSnapshot()
  fetchAlertDetail()
  // 拉取 ITSM 工单待办与 SLA 达成率(与首页 ITSM 待办卡片同源)
  fetchItmsData()
  refreshTimer = setInterval(fetchRealtimeData, 30 * 1000)
  itsmRefreshTimer = setInterval(fetchItmsData, 30 * 1000)
  // 频次推移数据采样: 每 5 分钟拉取一次数据写入当前槽(数据更新与图形重绘解耦)
  trendRefreshTimer = setInterval(recordTrendSnapshot, TREND_SAMPLE_INTERVAL)
  // 频次推移图形重绘: 每 3 秒完整重绘一次折线图,保持画面实时渲染感
  trendRepaintTimer = setInterval(repaintTrendChart, TREND_REPAINT_INTERVAL)
  // 闭环环形图 + ITSM 三图: 每 3 秒整组重绘一次,与频次推移折线同节奏
  snapshotRepaintTimer = setInterval(repaintSnapshotCharts, TREND_REPAINT_INTERVAL)
  // 实时未结告警列表: 保持 30 秒高频刷新,不受频次推移重绘周期影响
  detailRefreshTimer = setInterval(fetchAlertDetail, 30 * 1000)
  // 未结告警列表滚动推进: 50ms 步进一位移,刷新数据的增量接入由 rollTick 在滚出位置完成
  rollTimer = setInterval(rollTick, ROLL_STEP_MS)
  // 30秒周期数据微抖动,模拟核心指标的实时波动
  jitterTimer = setInterval(() => {
    // 主机资源水位 ±2~3% 轻微波动,模拟负载实时变化
    infraData.value.host.cpu = 68 + Math.floor(Math.random() * 7 - 3)
    infraData.value.host.ram = 82 + Math.floor(Math.random() * 5 - 2)
    infraData.value.host.disk = 58 + Math.floor(Math.random() * 5 - 2)
    infraData.value.host.net = 73 + Math.floor(Math.random() * 5 - 2)
    infraData.value.middleware.kafkaLag = 1842 + Math.floor(Math.random() * 260 - 130)
    infraData.value.api.rtt = 38 + Math.floor(Math.random() * 4 - 2)
    cloudData.value.slb.qps = 24500 + Math.floor(Math.random() * 260 - 130)
    // 卡面属性行数值抖动: 解析当前字符串格式原位改写,模拟各指标实时波动
    const jit = (cur, amp, min, max, dec) => {
      const v = clampN(cur + (Math.random() * 2 - 1) * amp, min, max)
      return Number(v.toFixed(dec))
    }
    infraData.value.db.pool = `${jit(parseFloat(infraData.value.db.pool) || 76.4, 2, 55, 96, 1)}%`
    infraData.value.middleware.redisHit = `${jit(parseFloat(infraData.value.middleware.redisHit) || 99.4, 0.3, 98.4, 100, 1)}%`
    infraData.value.middleware.rocket = `${numFmt(jit(parseInt(infraData.value.middleware.rocket.replace(/\D/g, '')) || 8420, 180, 3000, 20000, 0), 0)}/s`
    infraData.value.k8s.cpuPct = `${jit(parseFloat(infraData.value.k8s.cpuPct) || 62, 1.6, 40, 88, 0)}%`
    infraData.value.k8s.memPct = `${jit(parseFloat(infraData.value.k8s.memPct) || 71, 1.8, 40, 92, 0)}%`
    infraData.value.docker.logRate = `${jit(parseFloat(infraData.value.docker.logRate) || 1.8, 0.2, 0.6, 4.2, 1)} GB/h`
    infraData.value.jvm.heap = `${jit(parseFloat(infraData.value.jvm.heap) || 73.2, 1.6, 55, 90, 1)}%`
    infraData.value.api.p99 = `${jit(parseFloat(infraData.value.api.p99) || 86, 4, 40, 180, 0)} ms`
    cloudData.value.ecs.cpu = `${jit(parseFloat(cloudData.value.ecs.cpu) || 54.2, 2, 30, 86, 1)}%`
    cloudData.value.ecs.mem = `${jit(parseFloat(cloudData.value.ecs.mem) || 61.8, 2.2, 30, 86, 1)}%`
    cloudData.value.rds.cpu = `${jit(parseFloat(cloudData.value.rds.cpu) || 22, 1.6, 8, 70, 0)}%`
    cloudData.value.rds.conns = `${numFmt(jit(parseInt(String(cloudData.value.rds.conns).replace(/\D/g, '')) || 1842, 40, 800, 3200, 0), 0)} 个`
    cloudData.value.security.ddos = `Clean ${jit(parseFloat(String(cloudData.value.security.ddos).replace(/[^0-9.]/g, '')) || 5.2, 0.35, 2.5, 9.5, 1)}G`
    cloudData.value.oss.bandwidth = `${jit(parseFloat(cloudData.value.oss.bandwidth) || 840, 28, 300, 2200, 0)} Mbps`
  }, 30000)
  window.addEventListener('resize', handleWindowResize)
  document.addEventListener('fullscreenchange', syncFullscreenState)
  window.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  if (timeTimer) clearInterval(timeTimer)
  if (refreshTimer) clearInterval(refreshTimer)
  if (trendRefreshTimer) clearInterval(trendRefreshTimer)
  if (trendRepaintTimer) clearInterval(trendRepaintTimer)
  if (detailRefreshTimer) clearInterval(detailRefreshTimer)
  if (itsmRefreshTimer) clearInterval(itsmRefreshTimer)
  if (snapshotRepaintTimer) clearInterval(snapshotRepaintTimer)
  if (rollTimer) clearInterval(rollTimer)
  if (jitterTimer) clearInterval(jitterTimer)
  stopAutoPlay()
  window.removeEventListener('resize', handleWindowResize)
  document.removeEventListener('fullscreenchange', syncFullscreenState)
  window.removeEventListener('keydown', handleKeydown)
  // 离开页面时确保恢复布局,避免侧边栏/顶栏停留在隐藏状态
  document.body.classList.remove('-fullscreen')
  Object.values(charts).forEach(c => c && c.dispose())
  charts = {}
})
</script>

<template>
  <div class="-carousel-wrapper">
    <!-- 顶部标题栏(参考大屏标准样式: 左侧品牌 / 中间轮播标题 / 右侧倒计时与状态) -->
    <div class="dashboard-header">
      <!-- 左侧品牌区 -->
      <div class="header-left">
        <svg class="brand-icon" viewBox="0 0 24 24" width="28" height="28"><path fill="currentColor" d="M6,16A5,5 0 0,1 6,6A7,7 0 0,1 20,9A5,5 0 0,1 18,19H7.27L8.5,21.5L7,22.5L4.5,17.5H6M18,9H6A3,3 0 0,0 6,15H18A3,3 0 0,0 18,9M12.46,11.07L10.8,13.5H12.62L11.38,15.43L14.25,12.32H12.32L13.46,10.57L12.46,11.07Z"/></svg>
        <div class="brand-text">
          <div class="brand-title">OPS-INTELLIGENCE CENTER</div>
          <div class="brand-subtitle">1080P / 2K / 4K AUTO-SCALE ADAPTIVE</div>
        </div>
      </div>

      <!-- 中间轮播标题(随大屏切换) -->
      <div class="header-center">
        <h1>{{ currentScreen.title }}</h1>
      </div>

      <!-- 右侧状态区 -->
      <div class="header-right">
        <!-- 自动轮播开关(边框为倒计时进度环) -->
        <button
          class="autoplay-toggle"
          :title="autoPlayEnabled ? '暂停自动轮播' : '开启自动轮播'"
          @click.stop="toggleAutoPlay"
        >
          <svg class="toggle-ring" viewBox="0 0 28 28">
            <circle cx="14" cy="14" r="12.5" stroke="rgba(255,255,255,0.1)" stroke-width="2" fill="none"/>
            <circle class="toggle-ring-progress" cx="14" cy="14" r="12.5" stroke="#00f0ff" stroke-width="2" fill="none" :stroke-dasharray="ringPerimeter" :stroke-dashoffset="ringOffset"/>
          </svg>
          <svg v-if="autoPlayEnabled" class="toggle-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>
          <svg v-else class="toggle-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M8 5v14l11-7z"/></svg>
        </button>

        <!-- LIVE 徽标 -->
        <div class="live-badge">
          <span class="ripple-dot"><span class="ripple-core"></span></span>
          <span class="live-text">LIVE</span>
        </div>

        <!-- SLA 综合健康率 -->
        <div class="sla-info">
          <div class="sla-label">SLA 综合健康率</div>
          <div class="sla-value">99.99%</div>
        </div>

        <!-- 时钟 -->
        <div class="header-clock">{{ currentTime }}</div>

        <!-- 全屏切换 -->
        <button
          class="fullscreen-toggle"
          :title="isFullscreenMode ? '退出全屏 (F11)' : '进入全屏 (F11)'"
          @click="toggleFullscreen"
        >
          <svg v-if="!isFullscreenMode" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>
          <svg v-else viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z"/></svg>
        </button>
      </div>
    </div>

    <!-- 大屏轮播区 -->
    <div class="carousel-viewport" @mouseenter="onMouseEnter" @mouseleave="onMouseLeave">
      <div class="carousel-track" :style="{ transform: `translateX(-${currentIndex * 100}%)` }">

      <!-- 第1屏: 运维监控大屏 -->
      <div class="carousel-slide">
        <el-scrollbar class="-scrollbar" view-class="-viewport">
          <div class="-dashboard dashboard-fill">

    <!-- 第一层: 告警中心 -->
    <div class="alert-layer">
      <!-- 4大告警统计 -->
      <div class="alert-stats-grid">
        <div class="metric-card alert-stat level-critical breathing-critical">
          <div class="alert-stat-head">
            <span class="alert-stat-title c-critical"><svg class="card-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M13 14H11V9H13M13 18H11V16H13M1 21H23L12 2L1 21Z"/></svg> 严重 (Critical)</span>
            <span class="alert-stat-trend">{{ alertCenterData.critical.trend }}</span>
          </div>
          <div class="alert-stat-main">
            <span class="alert-stat-value c-critical">{{ alertCenterData.critical.value }}</span>
            <span class="alert-stat-note">{{ alertCenterData.critical.note }}</span>
          </div>
          <div class="alert-stat-bar"><div class="alert-stat-fill"></div></div>
        </div>
        <div class="metric-card alert-stat level-major">
          <div class="alert-stat-head">
            <span class="alert-stat-title c-major"><svg class="card-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M13,13H11V7H13V13M13,17H11V15H13V17M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"/></svg> 重要 (Major)</span>
            <span class="alert-stat-trend c-major">{{ alertCenterData.major.trend }}</span>
          </div>
          <div class="alert-stat-main">
            <span class="alert-stat-value c-major">{{ alertCenterData.major.value }}</span>
            <span class="alert-stat-note">{{ alertCenterData.major.note }}</span>
          </div>
          <div class="alert-stat-bar"><div class="alert-stat-fill"></div></div>
        </div>
        <div class="metric-card alert-stat level-minor">
          <div class="alert-stat-head">
            <span class="alert-stat-title c-minor"><svg class="card-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M21,19V20H3V19L5,17V11C5,7.9 7.03,5.17 10,4.29C10,4.19 10,4.1 10,4A2,2 0 0,1 12,2A2,2 0 0,1 14,4C14,4.1 14,4.19 14,4.29C16.97,5.17 19,7.9 19,11V17L21,19M12,23A2,2 0 0,0 14,21H10A2,2 0 0,0 12,23Z"/></svg> 一般 (Minor)</span>
            <span class="alert-stat-trend">{{ alertCenterData.minor.trend }}</span>
          </div>
          <div class="alert-stat-main">
            <span class="alert-stat-value c-minor">{{ alertCenterData.minor.value }}</span>
            <span class="alert-stat-note">{{ alertCenterData.minor.note }}</span>
          </div>
          <div class="alert-stat-bar"><div class="alert-stat-fill"></div></div>
        </div>
        <div class="metric-card alert-stat level-info">
          <div class="alert-stat-head">
            <span class="alert-stat-title c-info"><svg class="card-icon" viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M13,9H11V7H13V9M13,17H11V11H13V17M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"/></svg> 新增 (Info)</span>
            <span class="alert-stat-trend c-info">{{ alertCenterData.info.trend }}</span>
          </div>
          <div class="alert-stat-main">
            <span class="alert-stat-value c-info">{{ alertCenterData.info.value }}</span>
            <span class="alert-stat-note">{{ alertCenterData.info.note }}</span>
          </div>
          <div class="alert-stat-bar"><div class="alert-stat-fill"></div></div>
        </div>
      </div>

      <!-- 告警闭环收敛环形图 -->
      <div class="metric-card tile-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M7,5H21V7H7V5M7,13V11H21V13H7M4,4.5A1.5,1.5 0 0,1 5.5,6A1.5,1.5 0 0,1 4,7.5A1.5,1.5 0 0,1 2.5,6A1.5,1.5 0 0,1 4,4.5M4,10.5A1.5,1.5 0 0,1 5.5,12A1.5,1.5 0 0,1 4,13.5A1.5,1.5 0 0,1 2.5,12A1.5,1.5 0 0,1 4,10.5M7,19V17H21V19H7M4,16.5A1.5,1.5 0 0,1 5.5,18A1.5,1.5 0 0,1 4,19.5A1.5,1.5 0 0,1 2.5,18A1.5,1.5 0 0,1 4,16.5Z"/></svg>
          <span>告警闭环收敛</span>
          <span class="header-tag c-good">SLA 89.2%</span>
        </div>
        <div class="chart-slot">
          <div class="chart-container chart-sm" id="chart-closure"></div>
          <!-- 无告警数据(已闭环与处置中均为 0)时整槽显示炫酷空态 -->
          <div v-if="!alertCenterData.closed && !alertCenterData.processing" class="data-empty">
            <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
            <span class="de-text">暂无告警数据</span>
          </div>
        </div>
        <div class="closure-footer">
          <span>已闭环: <b class="c-good">{{ alertCenterData.closed }}</b></span>
          <span>处置中: <b class="c-warn">{{ alertCenterData.processing }}</b></span>
        </div>
      </div>

      <!-- 告警动态频次推移(3 秒重绘 · 5 分钟采样 · 24 槽点 · 最近 2 小时窗口) -->
      <div class="metric-card tile-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>
          <span>告警动态频次推移</span>
          <span class="header-tag streaming-tag">● STREAMING</span>
        </div>
        <div class="chart-slot">
          <div class="chart-container chart-sm" id="chart-trend"></div>
          <!-- 采样窗口未建立(首屏加载前)时整槽显示炫酷空态 -->
          <div v-if="!trendSeriesData.xData.length" class="data-empty">
            <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
            <span class="de-text">暂无采样数据</span>
          </div>
        </div>
      </div>

      <!-- 实时未结告警列表 -->
      <div class="metric-card tile-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M12 20a8 8 0 0 0 8-8 8 8 0 0 0-8-8 8 8 0 0 0-8 8 8 8 0 0 0 8 8m0-18a10 10 0 0 1 10 10 10 10 0 0 1-10 10A10 10 0 0 1 2 12 10 10 0 0 1 12 2m.5 5v5.25l4.5 2.67-.75 1.23L11 13V7h1.5z"/></svg>
          <span>实时未结告警列表</span>
          <span class="header-tag">SEAMLESS POOL</span>
        </div>
        <div class="alert-roll-list" @mouseenter="rollPaused = true" @mouseleave="rollPaused = false">
          <div class="alert-roll-track" ref="rollTrackEl" :style="{ transform: `translateY(-${rollOffset}px)` }">
            <div v-for="item in alertRows" :key="`a-${item.id}`" class="alert-row" :class="item.levelClass">
              <span class="alert-level">{{ item.level }}</span>
              <span class="alert-src">{{ item.src }}</span>
              <span class="alert-desc" :title="item.desc">{{ item.desc }}</span>
              <span class="alert-time">{{ item.time }}</span>
            </div>
            <div v-for="item in alertRows" :key="`b-${item.id}`" class="alert-row" :class="item.levelClass">
              <span class="alert-level">{{ item.level }}</span>
              <span class="alert-src">{{ item.src }}</span>
              <span class="alert-desc" :title="item.desc">{{ item.desc }}</span>
              <span class="alert-time">{{ item.time }}</span>
            </div>
          </div>
          <!-- 列表为空时整槽显示炫酷空态(轨道保持空渲染,不干扰滚动逻辑) -->
          <div v-if="!alertRows.length" class="data-empty">
            <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
            <span class="de-text">暂无未结告警</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 第二层: 全栈基础设施与应用监控矩阵 -->
    <div class="section-bar">
      <span class="section-title"><svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M13,3V9H21V3M13,21H21V11H13M3,21H11V15H3M3,13H11V3H3V13Z"/></svg> 应用系统与基础设施监控矩阵</span>
      <span class="section-meta">SLA BASELINE 99.95% · 5min SCRAPE</span>
    </div>
    <div class="infra-grid">
      <!-- 业务系统 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M20 10c-.5 0-1 .2-1.4.5l-.5-.5C17.7 9.6 17 9 16 9c-.5 0-1 .2-1.4.5l-.5-.5C13.7 8.6 13 8 12 8c-.5 0-1 .2-1.4.5L10 8c-.7-.7-1.6-1-2.5-1C5 7 3 9 3 11.5V13h16c1.1 0 2-.9 2-2s-.9-1-1-1M3 16h2v3H3m3 0h2v-3H6m3 0h2v3H9m3 0h2v-3h-2m3 0h2v3h-2m3 0h2v-3h-2z"/></svg>
          <span>应用系统</span>
          <span class="header-tag c-good">99.99%</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">165</span>
          <span class="mini-flag">系统数</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>核心业务系统可用率:</span><span class="mm-val c-good">100%</span></div>
          <div class="mini-metric"><span>开发类系统:</span><span class="mm-val c-info">111 个</span></div>
          <div class="mini-metric"><span>运维类系统:</span><span class="mm-val c-info">23 个</span></div>
          <div class="mini-metric"><span>分/子公司系统:</span><span class="mm-val c-info">31 个</span></div>
          <div class="mini-metric"><span>日志增速:</span><span class="mm-val c-info">495 K/时</span></div>
        </div>

      </div>


      <!-- 核心API链路 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2m-5.15 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 0 1-4.33 3.56M14.34 14H9.66c-.1-.66-.16-1.32-.16-2 0-.68.06-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2M12 19.96c-.83-1.2-1.5-2.53-1.91-3.96h3.82c-.41 1.43-1.08 2.76-1.91 3.96M8 8H5.08A7.923 7.923 0 0 1 9.4 4.44C8.8 5.55 8.35 6.75 8 8m-2.92 8H8c.35 1.25.8 2.45 1.4 3.56A8.008 8.008 0 0 1 5.08 16m-.82-2C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2M12 4.04c.83 1.2 1.5 2.54 1.91 3.96h-3.82c.41-1.42 1.08-2.76 1.91-3.96M18.92 8h-2.95a15.65 15.65 0 0 0-1.38-3.56c1.84.63 3.37 1.9 4.33 3.56M12 2C6.47 2 2 6.5 2 12s4.47 10 10 10 10-4.5 10-10S17.53 2 12 2z"/></svg>
          <span>服务状态监控</span>
          <span class="header-tag c-good">{{ infraData.api.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.api.total }}</span>
          <span class="mini-flag c-info">HTTP/ICMP</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>往返耗时:</span><span class="mm-val c-good">{{ infraData.api.rtt }} ms</span></div>
          <div class="mini-metric"><span>4xx 错误率:</span><span class="mm-val c-warn">{{ infraData.api.err4xx }}</span></div>
          <div class="mini-metric"><span>5xx 错误率:</span><span class="mm-val c-bad">{{ infraData.api.err5xx }}</span></div>
          <div class="mini-metric"><span>P99 耗时:</span><span class="mm-val c-info">{{ infraData.api.p99 }}</span></div>
          <div class="mini-metric"><span>ICMP 响应率:</span><span class="mm-val c-good">99.5%</span></div>
        </div>

      </div>
      <!-- 主机监控 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M4 3h16a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1m1 2v14h14V5H5m2 2h10v2H7V7m0 4h10v2H7v-2m0 4h6v2H7v-2"/></svg>
          <span>主机监控</span>
          <span class="header-tag c-good">100%</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.host.total }}</span>
          <span class="mini-flag c-bad"><span class="blink-fast"></span> 生产+预发</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>CPU Avg:</span><span class="mm-val c-info">{{ infraData.host.cpu }}%</span></div>
          <div class="mini-metric"><span>RAM Avg:</span><span class="mm-val c-warn">{{ infraData.host.ram }}%</span></div>
          <div class="mini-metric"><span>磁盘 I/O:</span><span class="mm-val c-good">{{ infraData.host.disk }}%</span></div>
          <div class="mini-metric"><span>网络 IO:</span><span class="mm-val c-warn">{{ infraData.host.net }}%</span></div>
        </div>

      </div>

      <!-- 原生数据库 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 3C7.58 3 4 4.79 4 7v10c0 2.21 3.58 4 8 4s8-1.79 8-4V7c0-2.21-3.58-4-8-4m0 2c3.87 0 6 1.5 6 2s-2.13 2-6 2-6-1.5-6-2 2.13-2 6-2M6 7.51c.88.49 2.51.99 4.5 1.19L12 9c1.33 0 4.5-.5 6-1.5V11c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 13c1.33 0 4.5-.5 6-1.5v3c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 17c1.33 0 4.5-.5 6-1.5v2c0 .5-2.13 2-6 2s-6-1.5-6-2z"/></svg>
          <span>原生数据库</span>
          <span class="header-tag c-good">{{ infraData.db.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.db.total }}</span>
          <span class="mini-flag c-info">Oracle/Mysql/PG/DM</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>连接池占用:</span><span class="mm-val c-warn">{{ infraData.db.pool }}</span></div>
          <div class="mini-metric"><span>慢查询 QPS:</span><span class="mm-val c-good">{{ infraData.db.slow }}</span></div>
          <div class="mini-metric"><span>主从延时:</span><span class="mm-val c-good">{{ infraData.db.replica }}</span></div>
          <div class="mini-metric"><span>活跃会话:</span><span class="mm-val c-info">{{ infraData.db.sessions }}</span></div>
          <div class="mini-metric"><span>QPS 峰值:</span><span class="mm-val c-info">{{ infraData.db.qpsPeak }}</span></div>
        </div>

      </div>

      <!-- 中间件节点 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M22 7v6H9V7h13M2 14v2h6v-2H2m0-7v2h6V7H2m10 7v2h10v-2H12m-10 7v2h6v-2H2m10 0v2h10v-2H12z"/></svg>
          <span>中间件节点</span>
          <span class="header-tag">{{ infraData.middleware.total }} Nodes</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.middleware.kafkaLag }}</span>
          <span class="mini-flag">缓存、消息、ES</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>Redis 命中率:</span><span class="mm-val c-good">{{ infraData.middleware.redisHit }}</span></div>
          <div class="mini-metric"><span>RocketMQ TPS:</span><span class="mm-val c-info">{{ infraData.middleware.rocket }}</span></div>
          <div class="mini-metric"><span>ZooKeeper 连接:</span><span class="mm-val c-info">{{ infraData.middleware.zk }}</span></div>
          <div class="mini-metric"><span>ES 集群状态:</span><span class="mm-val c-good">{{ infraData.middleware.es }}</span></div>
          <div class="mini-metric"><span>消息重试队列:</span><span class="mm-val c-good">{{ infraData.middleware.retry }}</span></div>
        </div>

      </div>

      <!-- K8s集群 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2m0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3m0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/></svg>
          <span>K8s集群</span>
          <span class="header-tag">{{ infraData.k8s.clusters }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.k8s.pods }}</span>
          <span class="mini-flag c-warn">POD 数</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>Node 节点:</span><span class="mm-val c-good">{{ infraData.k8s.nodes }}</span></div>
          <div class="mini-metric"><span>异常 Pod:</span><span class="mm-val c-warn">{{ infraData.k8s.pending }}</span></div>
          <div class="mini-metric"><span>ECTD 状态:</span><span class="mm-val c-info">Green 正常</span></div>
          <div class="mini-metric"><span>CPU 水位:</span><span class="mm-val c-info">{{ infraData.k8s.cpuPct }}</span></div>
          <div class="mini-metric"><span>内存水位:</span><span class="mm-val c-warn">{{ infraData.k8s.memPct }}</span></div>
        </div>

      </div>

      <!-- JVM运行时 -->
      <div class="metric-card mini-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2m-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93m6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
          <span>JVM运行时</span>
          <span class="header-tag">JDK 17</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ infraData.jvm.threads }}</span>
          <span class="mini-flag">活跃线程</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>堆内存分配:</span><span class="mm-val c-warn">{{ infraData.jvm.heap }}</span></div>
          <div class="mini-metric"><span>Young GC:</span><span class="mm-val c-info">{{ infraData.jvm.youngGc }}</span></div>
          <div class="mini-metric"><span>Full GC 频次:</span><span class="mm-val c-bad">{{ infraData.jvm.fullGc }}</span></div>
          <div class="mini-metric"><span>类加载总数:</span><span class="mm-val c-info">{{ infraData.jvm.classes }}</span></div>
          <div class="mini-metric"><span>死锁线程:</span><span class="mm-val c-good">{{ infraData.jvm.deadlock }}</span></div>
        </div>

      </div>
    </div>

    <!-- 第三层: 阿里云专有云企业套件监控 -->
    <div class="section-bar cloud">
      <span class="section-title"><svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M19.35 10.04A7.49 7.49 0 0 0 12 4C9.11 4 6.6 5.64 5.35 8.04A5.994 5.994 0 0 0 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96M19 18H6a4 4 0 0 1-4-4c0-2.05 1.53-3.76 3.56-3.97l1.07-.11.5-.95A5.469 5.469 0 0 1 12 6c2.62 0 4.88 1.86 5.39 4.43l.3 1.5 1.53.11A2.98 2.98 0 0 1 22 15c0 1.65-1.35 3-3 3z"/></svg> 云资源与安全防护监控</span>
      <span class="section-meta"><span>ZONE: 合肥-北京 REGION</span><span class="c-good">● 异地容灾</span></span>
    </div>
    <div class="cloud-grid">
      <!-- ECS云服务器 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M4 3h16a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1m1 2v14h14V5H5m2 2h10v2H7V7m0 4h10v2H7v-2m0 4h6v2H7v-2"/></svg>
          <span>ECS云服务器</span>
          <span class="header-tag c-good">{{ cloudData.ecs.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.ecs.count }}</span>
          <span class="mini-flag">台实例</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>平均 CPU:</span><span class="mm-val c-info">{{ cloudData.ecs.cpu }}</span></div>
          <div class="mini-metric"><span>平均内存:</span><span class="mm-val c-info">{{ cloudData.ecs.mem }}</span></div>
          <div class="mini-metric"><span>IOPS / 吞吐:</span><span class="mm-val">{{ cloudData.ecs.iops }}</span></div>
          <div class="mini-metric"><span>云盘使用率:</span><span class="mm-val c-good">{{ cloudData.ecs.disk }}</span></div>
          <div class="mini-metric"><span>ESS 伸缩组:</span><span class="mm-val c-good">{{ cloudData.ecs.ess }}</span></div>
        </div>

      </div>

      <!-- VPC虚拟专网 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M22 7v6H9V7h13M2 14v2h6v-2H2m0-7v2h6V7H2m10 7v2h10v-2H12m-10 7v2h6v-2H2m10 0v2h10v-2H12z"/></svg>
          <span>VPC虚拟专网</span>
          <span class="header-tag">{{ cloudData.vpc.zones }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.vpc.routes }}</span>
          <span class="mini-flag">条路由表</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>高速通道 VBR:</span><span class="mm-val c-good">{{ cloudData.vpc.vbr }}</span></div>
          <div class="mini-metric"><span>NAT 网关:</span><span class="mm-val c-info">{{ cloudData.vpc.nat }}</span></div>
          <div class="mini-metric"><span>EIP 弹性IP:</span><span class="mm-val">25/25</span></div>
          <div class="mini-metric"><span>子网 vSwitch:</span><span class="mm-val c-info">{{ cloudData.vpc.vsw }}</span></div>
          <div class="mini-metric"><span>流日志:</span><span class="mm-val c-good">{{ cloudData.vpc.flowlog }}</span></div>
        </div>

      </div>

      <!-- SLB负载均衡 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M3.5 18.5L9 13l4 4 7.5-7.5L22 11V3h-8l2.5 2.5L13 11l-4-4L2 17l1.5 1.5z"/></svg>
          <span>SLB负载均衡</span>
          <span class="header-tag c-good">{{ cloudData.slb.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.slb.count }}</span>
          <span class="mini-flag">ALB / CLB</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>入口总 QPS:</span><span class="mm-val c-info">{{ cloudData.slb.qps.toLocaleString() }}</span></div>
          <div class="mini-metric"><span>新建连接:</span><span class="mm-val c-info">{{ cloudData.slb.newConn }}</span></div>
          <div class="mini-metric"><span>异常后端 ECS:</span><span class="mm-val c-good">{{ cloudData.slb.unhealthy }}</span></div>
          <div class="mini-metric"><span>SSL 卸载:</span><span class="mm-val c-good">{{ cloudData.slb.ssl }}</span></div>
          <div class="mini-metric"><span>健康检查:</span><span class="mm-val c-good">{{ cloudData.slb.healthChk }}</span></div>
        </div>

      </div>

      <!-- 安全组与威胁防护 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12,1L3,5V11C3,16.55 6.84,21.74 12,23C17.16,21.74 21,16.55 21,11V5L12,1Z"/></svg>
          <span>安全组与威胁防护</span>
          <span class="header-tag c-warn">{{ cloudData.security.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.security.blocks }}</span>
          <span class="mini-flag c-bad">今日恶意拦截</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>今日告警:</span><span class="mm-val c-info">{{ cloudData.security.rules }} 条</span></div>
          <div class="mini-metric"><span>威胁检测策略:</span><span class="mm-val c-good">1271 条</span></div>
          <div class="mini-metric"><span>威胁分诊率:</span><span class="mm-val">98.61 %</span></div>
          <div class="mini-metric"><span>暴力破解拦截:</span><span class="mm-val c-warn">{{ cloudData.security.brute }}</span></div>
          <div class="mini-metric"><span>高危漏洞未修复:</span><span class="mm-val c-bad">272 个</span></div>
        </div>

      </div>

      <!-- RDS专有实例 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 3C7.58 3 4 4.79 4 7v10c0 2.21 3.58 4 8 4s8-1.79 8-4V7c0-2.21-3.58-4-8-4m0 2c3.87 0 6 1.5 6 2s-2.13 2-6 2-6-1.5-6-2 2.13-2 6-2M6 7.51c.88.49 2.51.99 4.5 1.19L12 9c1.33 0 4.5-.5 6-1.5V11c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 13c1.33 0 4.5-.5 6-1.5v3c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 17c1.33 0 4.5-.5 6-1.5v2c0 .5-2.13 2-6 2s-6-1.5-6-2z"/></svg>
          <span>RDS专有实例</span>
          <span class="header-tag c-good">{{ cloudData.rds.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.rds.instances }}</span>
          <span class="mini-flag">热备集群</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>只读延时:</span><span class="mm-val c-good">{{ cloudData.rds.replica }}</span></div>
          <div class="mini-metric"><span>存储空间:</span><span class="mm-val c-warn">{{ cloudData.rds.storage }}</span></div>
          <div class="mini-metric"><span>自动冷备:</span><span class="mm-val c-good">{{ cloudData.rds.backup }}</span></div>
          <div class="mini-metric"><span>平均 CPU:</span><span class="mm-val c-info">{{ cloudData.rds.cpu }}</span></div>
          <div class="mini-metric"><span>活跃连接:</span><span class="mm-val c-info">{{ cloudData.rds.conns }}</span></div>
        </div>

      </div>

      <!-- OSS对象存储 -->
      <div class="metric-card mini-card ali-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M19.35 10.04A7.49 7.49 0 0 0 12 4C9.11 4 6.6 5.64 5.35 8.04A5.994 5.994 0 0 0 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96M19 18H6a4 4 0 0 1-4-4c0-2.05 1.53-3.76 3.56-3.97l1.07-.11.5-.95A5.469 5.469 0 0 1 12 6c2.62 0 4.88 1.86 5.39 4.43l.3 1.5 1.53.11A2.98 2.98 0 0 1 22 15c0 1.65-1.35 3-3 3z"/></svg>
          <span>OSS对象存储</span>
          <span class="header-tag c-good">{{ cloudData.oss.health }}</span>
        </div>
        <div class="mini-main">
          <span class="mini-value">{{ cloudData.oss.size }}</span>
          <span class="mini-flag">TB 存储</span>
        </div>
        <!-- 属性明细: 贴卡底自底部向上排布,数值随 30s 状态抖动实时刷新 -->
        <div class="mini-metrics">
          <div class="mini-metric"><span>流出带宽:</span><span class="mm-val c-info">{{ cloudData.oss.bandwidth }}</span></div>
          <div class="mini-metric"><span>请求 QPS:</span><span class="mm-val c-info">{{ cloudData.oss.reqQps }}</span></div>
          <div class="mini-metric"><span>API 响应率:</span><span class="mm-val c-good">{{ cloudData.oss.apiRate }}</span></div>
          <div class="mini-metric"><span>对象总数:</span><span class="mm-val">{{ cloudData.oss.objects }}</span></div>
          <div class="mini-metric"><span>跨域容灾:</span><span class="mm-val c-good">{{ cloudData.oss.dr }}</span></div>
        </div>

      </div>
    </div>
    </div>
        </el-scrollbar>
      </div>

      <!-- 第2屏: ITSM流程大屏(工单/SLA 数据与首页 ITSM 待办同源接口,知识库/图表区待接入) -->
      <div class="carousel-slide">
        <el-scrollbar class="-scrollbar" view-class="-viewport">
          <div class="-dashboard dashboard-itsm">
            <div class="metrics-grid">
              <!-- SLA达成率(首位,数据来自 getOrderData 返回的 sla 统计) -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>
                  <span>工单SLA达成率</span>
                  <span class="header-tag c-info">基线 {{ itsmData.sla.baseline }}%</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value c-good">{{ itsmData.sla.total > 0 ? Number(itsmData.sla.rate).toFixed(2) : '--' }}</span>
                  <span class="mini-flag c-good">{{ itsmData.sla.total > 0 ? '% 整体达成率' : '整体达成率' }}</span>
                </div>
                <!-- 周期工单/达标/超时 → 内嵌占比条(周期行满量作基线,达标绿/超时红随占比伸缩) -->
                <div class="mini-list">
                  <div
                    v-for="row in slaOverviewRows"
                    :key="row.label"
                    class="itsm-bar-row"
                    :title="row.tip"
                  >
                    <i class="itsm-bar-dot" :style="{ background: row.color }"></i>
                    <span class="itsm-bar-label">{{ row.label }}</span>
                    <div class="itsm-bar-track">
                      <i class="itsm-bar-fill" :style="{ width: row.pct + '%', background: row.color }"></i>
                    </div>
                    <span class="mini-list-value" :class="row.valClass">{{ row.count }}</span>
                  </div>
                </div>
              </div>

              <!-- 工单总览(右侧第一张): 五类待办工单合计与分项 -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M19 3h-4.18C14.4 1.84 13.3 1 12 1c-1.3 0-2.4.84-2.82 2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2m-7 0a1 1 0 0 1 1 1 1 1 0 0 1-1 1 1 1 0 0 1-1-1 1 1 0 0 1 1-1m-2 14l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>
                  <span>工单总览</span>
                  <span class="header-tag c-info">ITSM 待办</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmTodoTotal }}</span>
                  <span class="mini-flag">条待办工单</span>
                </div>
                <!-- 五类待办数量 → 内嵌占比条(条宽 = 该类数量 / 待办总量,色板与五类一致),悬停显占比 -->
                <div class="mini-list">
                  <div
                    v-for="row in itsmOverviewRows"
                    :key="row.label"
                    class="itsm-bar-row"
                    :title="row.pct > 0 ? ('占待办总量 ' + row.pct + '%') : '暂无该类待办'"
                  >
                    <i class="itsm-bar-dot" :style="{ background: row.color }"></i>
                    <span class="itsm-bar-label">{{ row.label }}</span>
                    <div class="itsm-bar-track">
                      <i class="itsm-bar-fill" :style="{ width: row.pct + '%', background: row.color }"></i>
                    </div>
                    <span class="mini-list-value c-info">{{ row.count }}</span>
                  </div>
                </div>
              </div>

              <!-- 事件管理 -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2L1 21h22M12 6l7.53 13H4.47M11 10v4h2v-4m-2 6v2h2v-2"/></svg>
                  <span>事件管理</span>
                  <span class="header-tag c-info">INCIDENT</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmData.event.length }}</span>
                  <span class="mini-flag c-warn">待处理事件</span>
                </div>
                <div class="mini-list">
                  <div class="mini-list-item"><span>最新编号</span><span class="itsm-row-value"><span class="c-info">{{ itsmData.event[0]?.id || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>工单标题</span><span class="itsm-row-value"><span>{{ itsmData.event[0]?.title || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>申请人</span><span class="itsm-row-value"><span>{{ itsmData.event[0]?.applicant || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>提交时间</span><span class="itsm-row-value"><span>{{ itsmData.event[0]?.createTime || '-' }}</span></span></div>
                </div>
              </div>

              <!-- 问题管理 -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M20 8h-2.81c-.45-.78-1.07-1.45-1.82-1.96L17 4.41 15.59 3l-2.17 2.17a6.002 6.002 0 0 0-2.83 0L8.41 3 7 4.41l1.62 1.63C7.88 6.55 7.26 7.22 6.81 8H4v2h2.09c-.05.33-.09.66-.09 1v1H4v2h2v1c0 .34.04.67.09 1H4v2h2.81c1.04 1.79 2.97 3 5.19 3s4.15-1.21 5.19-3H20v-2h-2.09c.05-.33.09-.66.09-1v-1h2v-2h-2v-1c0-.34-.04-.67-.09-1H20V8m-6 8h-4v-2h4v2m0-4h-4v-2h4v2z"/></svg>
                  <span>问题管理</span>
                  <span class="header-tag c-info">PROBLEM</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmData.problem.length }}</span>
                  <span class="mini-flag c-warn">待处理问题</span>
                </div>
                <div class="mini-list">
                  <div class="mini-list-item"><span>最新编号</span><span class="itsm-row-value"><span class="c-info">{{ itsmData.problem[0]?.id || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>工单标题</span><span class="itsm-row-value"><span>{{ itsmData.problem[0]?.title || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>申请人</span><span class="itsm-row-value"><span>{{ itsmData.problem[0]?.applicant || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>提交时间</span><span class="itsm-row-value"><span>{{ itsmData.problem[0]?.createTime || '-' }}</span></span></div>
                </div>
              </div>

              <!-- 变更管理 -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 6v3l4-4-4-4v3c-4.42 0-8 3.58-8 8 0 1.57.46 3.03 1.24 4.26L6.7 14.8A5.87 5.87 0 0 1 6 12c0-3.31 2.69-6 6-6m6.76 1.74L17.3 9.2c.44.84.7 1.79.7 2.8 0 3.31-2.69 6-6 6v-3l-4 4 4 4v-3c4.42 0 8-3.58 8-8 0-1.57-.46-3.03-1.24-4.26z"/></svg>
                  <span>变更管理</span>
                  <span class="header-tag c-info">CHANGE</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmData.change.length }}</span>
                  <span class="mini-flag c-warn">待审批变更</span>
                </div>
                <div class="mini-list">
                  <div class="mini-list-item"><span>最新编号</span><span class="itsm-row-value"><span class="c-info">{{ itsmData.change[0]?.id || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>工单标题</span><span class="itsm-row-value"><span>{{ itsmData.change[0]?.title || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>申请人</span><span class="itsm-row-value"><span>{{ itsmData.change[0]?.applicant || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>提交时间</span><span class="itsm-row-value"><span>{{ itsmData.change[0]?.createTime || '-' }}</span></span></div>
                </div>
              </div>

              <!-- 请求管理(原服务满意度改造) -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M20 2H4a2 2 0 0 0-2 2v18l4-4h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z"/><path fill="currentColor" d="M7 9h10v1.6H7z"/><path fill="currentColor" d="M7 13h6v1.6H7z"/></svg>
                  <span>请求管理</span>
                  <span class="header-tag c-info">REQUEST</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmData.request.length }}</span>
                  <span class="mini-flag c-warn">待处理请求</span>
                </div>
                <div class="mini-list">
                  <div class="mini-list-item"><span>最新编号</span><span class="itsm-row-value"><span class="c-info">{{ itsmData.request[0]?.id || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>工单标题</span><span class="itsm-row-value"><span>{{ itsmData.request[0]?.title || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>申请人</span><span class="itsm-row-value"><span>{{ itsmData.request[0]?.applicant || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>提交时间</span><span class="itsm-row-value"><span>{{ itsmData.request[0]?.createTime || '-' }}</span></span></div>
                </div>
              </div>

              <!-- 发布管理(原服务台工作量改造) -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M9 16V10H5l7-7 7 7h-4v6H9M5 20v-2h14v2H5z"/></svg>
                  <span>发布管理</span>
                  <span class="header-tag c-info">RELEASE</span>
                </div>
                <div class="mini-main">
                  <span class="mini-value">{{ itsmData.publish.length }}</span>
                  <span class="mini-flag c-warn">待处理发布</span>
                </div>
                <div class="mini-list">
                  <div class="mini-list-item"><span>最新编号</span><span class="itsm-row-value"><span class="c-info">{{ itsmData.publish[0]?.id || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>工单标题</span><span class="itsm-row-value"><span>{{ itsmData.publish[0]?.title || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>申请人</span><span class="itsm-row-value"><span>{{ itsmData.publish[0]?.applicant || '-' }}</span></span></div>
                  <div class="mini-list-item"><span>提交时间</span><span class="itsm-row-value"><span>{{ itsmData.publish[0]?.createTime || '-' }}</span></span></div>
                </div>
              </div>

              <!-- 知识库(占位,数据源待接入) -->
              <div class="metric-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M18 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2M6 4h5v8l-2.5-1.5L6 12V4z"/></svg>
                  <span>知识库</span>
                  <span class="header-tag">KNOWLEDGE</span>
                </div>
                <div class="card-body">
                  <!-- 数据源未接入: 整槽显示紫色雷达空态动画 -->
                  <div class="placeholder-area de-violet">
                    <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
                    <span class="de-text">暂无知识数据 · 数据源待接入</span>
                  </div>
                </div>
              </div>
            </div>
            <div class="charts-section">
              <div class="chart-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>
                  <span>工单趋势 (7日)</span>
                  <span class="header-tag c-info">REQUEST FLOW</span>
                </div>
                <div class="chart-slot">
                  <div class="chart-container" id="chart-order-trend"></div>
                  <!-- 7 日趋势数据未拉回时整槽显示炫酷空态 -->
                  <div v-if="!(itsmData.week_trend || []).length" class="data-empty violet">
                    <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
                    <span class="de-text">暂无趋势数据</span>
                  </div>
                </div>
              </div>
              <div class="chart-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M11 2v20c-5.07-.5-9-4.79-9-10s3.93-9.5 9-10m2 0v9h9c-.47-4.74-4.24-8.52-9-9m0 11v9c4.74-.47 8.53-4.25 9-9h-9z"/></svg>
                  <span>工单分类占比</span>
                  <span class="header-tag c-info">近 7 日</span>
                </div>
                <div class="chart-slot">
                  <div class="chart-container" id="chart-order-category"></div>
                  <!-- 分类合计为 0(无任何工单)时整槽显示炫酷空态 -->
                  <div v-if="!itsmCategoryStat.length" class="data-empty violet">
                    <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
                    <span class="de-text">暂无分类数据</span>
                  </div>
                </div>
              </div>
              <div class="chart-card">
                <div class="card-header">
                  <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>
                  <span>工单SLA达成趋势</span>
                  <span class="header-tag c-good">基线 {{ itsmData.sla.baseline }}%</span>
                </div>
                <div class="chart-slot">
                  <div class="chart-container" id="chart-sla-trend"></div>
                  <!-- SLA 趋势数据未拉回时整槽显示炫酷空态 -->
                  <div v-if="!(itsmData.sla_trend || []).length" class="data-empty violet">
                    <div class="de-scene"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
                    <span class="de-text">暂无趋势数据</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- 第四排: 五类工单处理明细流 · 水平走马灯(卡片自左向右循环滚动,悬停暂停,高度占满剩余空间) -->
            <div class="itsm-event-ticker">
              <div class="itsm-ticker-bar">
                <span class="itsm-ticker-title">
                  <svg class="card-icon" viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M12 20a8 8 0 0 0 8-8 8 8 0 0 0-8-8 8 8 0 0 0-8 8 8 8 0 0 0 8 8m0-18a10 10 0 0 1 10 10 10 10 0 0 1-10 10A10 10 0 0 1 2 12 10 10 0 0 1 12 2m.5 5v5.25l4.5 2.67-.75 1.23L11 13V7h1.5z"/></svg>
                  工单处理明细流
                  <span class="itsm-ticker-sub">ORDER FLOW · REQ/REL/INC/CHG/PRB</span>
                </span>
                <span class="itsm-ticker-meta"><span class="ticker-live-dot"></span>LIVE · {{ itsmTickerRows.length }} 条 · 自左向右循环</span>
              </div>
              <div class="ticker-viewport" @mouseenter="tickerPaused = true" @mouseleave="tickerPaused = false">
                <div v-if="itsmTickerRows.length" class="ticker-track" :class="{ 'ticker-paused': tickerPaused }" :style="{ animationDuration: tickerDuration + 's' }">
                  <div v-for="n in 4" :key="`seq-${n}`" class="ticker-seq">
                    <div v-for="(row, idx) in itsmTickerRows" :key="`${row.id}-${idx}`" class="ticker-card">
                      <div class="ticker-card-head">
                        <span class="ticker-type" :style="{ color: row.typeColor, borderColor: row.typeColor, background: row.typeColor + '1a' }">{{ row.typeLabel }}</span>
                        <span class="ticker-card-status" :style="{ color: row.statusColor }">{{ row.status || '待处理' }}</span>
                      </div>
                      <div class="ticker-title" :title="row.title">{{ row.title || '-' }}</div>
                      <div class="ticker-card-attrs">
                        <div class="ticker-attr"><span class="ticker-attr-label"><svg class="ticker-attr-icon ta-apl" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>申请人</span><span class="ticker-attr-value"><span class="ticker-chip">{{ row.applicant || '-' }}</span></span></div>
                        <div class="ticker-attr"><span class="ticker-attr-label"><svg class="ticker-attr-icon ta-cur" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>当前处理人</span><span class="ticker-attr-value"><span class="ticker-chip handler">{{ row.currentHandler || '-' }}</span></span></div>
                        <div class="ticker-attr"><span class="ticker-attr-label"><svg class="ticker-attr-icon ta-prev" viewBox="0 0 24 24" width="13" height="13"><path fill="currentColor" d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/></svg>上一步处理人</span><span class="ticker-attr-value"><span class="ticker-chip prev">{{ row.previousHandler || '-' }}</span></span></div>
                      </div>
                      <div class="ticker-card-foot">
                        <span class="ticker-id">{{ row.id || '-' }}</span>
                        <span class="ticker-time">{{ shortOrderTime(row.createTime) }}</span>
                      </div>
                    </div>
                  </div>
                </div>
                <div v-else class="ticker-empty">
                  <div class="de-scene sm"><i class="de-wave"></i><i class="de-wave w2"></i><i class="de-ring"></i><i class="de-core"></i></div>
                  <span class="de-text">暂无工单明细 · 等待数据接入</span>
                </div>
              </div>
            </div>
          </div>
        </el-scrollbar>
      </div>

      </div>

      <!-- 轮播切换箭头 -->
      <button class="carousel-arrow prev" title="上一屏" @click="prevScreen">‹</button>
      <button class="carousel-arrow next" title="下一屏" @click="nextScreen">›</button>
    </div>
  </div>
</template>

<style scoped>
/* ==================== 全局 ==================== */
.-carousel-wrapper {
  /* 视口锚定: 不依赖祖先链高度(100%逐级传递易断裂),非全屏 = 100vh - 顶栏40px - 主区上下padding32px */
  height: calc(100vh - 72px);
  display: flex;
  flex-direction: column;
  background: radial-gradient(ellipse at 20% 50%, rgba(10, 30, 60, 0.8) 0%, #050a1a 100%);
  color: #e0e6ed;
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
}

.-scrollbar {
  height: 100%;
}

/* 滚动视图撑满容器并纵向排布,配合 dashboard-fill 精确适配可视区 */
.-scrollbar :deep(.el-scrollbar__view) {
  min-height: 100%;
  display: flex;
  flex-direction: column;
}

.-scrollbar :deep(.el-scrollbar__bar) {
  z-index: 100;
}

.-scrollbar :deep(.el-scrollbar__thumb) {
  background: rgba(0, 212, 255, 0.3);
  border-radius: 4px;
}

.-scrollbar :deep(.el-scrollbar__thumb:hover) {
  background: rgba(0, 212, 255, 0.5);
}

.-dashboard {
  padding: 16px 20px;
  color: #e0e6ed;
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
  box-sizing: border-box;
}

/* 统一盒模型: flex 百分比/calc 宽度计算包含内边距,避免溢出换行 */
.-dashboard *,
.-dashboard *::before,
.-dashboard *::after {
  box-sizing: border-box;
}

/* 第1屏专用: 三层区域按视口高度弹性铺满,行间距拉开避免卡片过高显压抑 */
.dashboard-fill {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* ==================== 大屏轮播 ==================== */
.carousel-viewport {
  flex: 1;
  min-height: 0;
  position: relative;
  overflow: hidden;
}

.carousel-track {
  display: flex;
  height: 100%;
  transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  will-change: transform;
}

.carousel-slide {
  flex: 0 0 100%;
  min-width: 0;
  height: 100%;
  overflow: hidden;
}

/* 切换箭头 */
.carousel-arrow {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 34px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(0, 212, 255, 0.25);
  border-radius: 8px;
  background: rgba(10, 25, 50, 0.65);
  color: #00d4ff;
  font-size: 22px;
  line-height: 1;
  cursor: pointer;
  opacity: 0.35;
  transition: all 0.3s ease;
  z-index: 20;
}

.carousel-arrow:hover {
  opacity: 1;
  background: rgba(0, 212, 255, 0.15);
  box-shadow: 0 0 14px rgba(0, 212, 255, 0.25);
}

.carousel-arrow.prev { left: 8px; }
.carousel-arrow.next { right: 8px; }

/* 自动轮播开关(边框由倒计时进度环替代) */
.autoplay-toggle {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  border-radius: 50%;
  background: rgba(10, 25, 50, 0.6);
  color: #7b8ca8;
  cursor: pointer;
  transition: all 0.3s ease;
  padding: 0;
}

.autoplay-toggle:hover {
  color: #00d4ff;
  box-shadow: 0 0 10px rgba(0, 212, 255, 0.25);
}

.toggle-ring {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.toggle-ring-progress {
  transition: stroke-dashoffset 1s linear;
}

.toggle-icon {
  position: relative;
  z-index: 1;
}

/* 全屏切换按钮 */
.fullscreen-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: 1px solid rgba(0, 212, 255, 0.2);
  border-radius: 50%;
  background: rgba(10, 25, 50, 0.6);
  color: #7b8ca8;
  cursor: pointer;
  transition: all 0.3s ease;
}

.fullscreen-toggle:hover {
  color: #00d4ff;
  border-color: rgba(0, 212, 255, 0.5);
}

/* ==================== 占位页(待接入内容) ==================== */
/* 知识库等占位槽: 紫色虚框与空态雷达动画同色(--de 由父 .de-violet 提供,含紫默认值兜底) */
.placeholder-area {
  min-height: 130px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: 1px dashed rgba(var(--de, 167, 139, 250), 0.3);
  border-radius: 8px;
  background: rgba(var(--de, 167, 139, 250), 0.04);
}

.placeholder-icon {
  font-size: 26px;
  color: rgba(0, 212, 255, 0.45);
}

.placeholder-text {
  font-size: 13px;
  color: #7b8ca8;
  letter-spacing: 2px;
}

.placeholder-sub {
  font-size: 11px;
  color: #4a6a8a;
}

.chart-placeholder {
  min-height: 200px;
}

/* ==================== 顶部标题栏 ==================== */
.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: linear-gradient(135deg, rgba(15, 30, 60, 0.9), rgba(5, 15, 35, 0.9));
  border: 1px solid rgba(0, 212, 255, 0.15);
  border-radius: 12px;
  margin: 16px 20px 16px;
  flex-shrink: 0;
  box-shadow: 0 4px 30px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(0, 212, 255, 0.1);
}

/* 左侧品牌区 */
.header-left {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 25%;
  min-width: 250px;
}

.brand-icon {
  color: #22d3ee;
  filter: drop-shadow(0 0 8px rgba(0, 240, 255, 0.6));
  flex-shrink: 0;
}

.brand-title {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 3px;
  color: #22d3ee;
  font-weight: 900;
  white-space: nowrap;
}

.brand-subtitle {
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  letter-spacing: 1px;
  white-space: nowrap;
  margin-top: 2px;
}

/* 中间轮播标题: 居中渐变发光 */
.header-center {
  flex: 1;
  text-align: center;
  min-width: 0;
}

.header-center h1 {
  margin: 0;
  font-size: 28px;
  font-weight: 900;
  letter-spacing: 4px;
  text-transform: uppercase;
  white-space: nowrap;
  background: linear-gradient(90deg, #22d3ee, #bae6fd, #a5b4fc);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  filter: drop-shadow(0 2px 8px rgba(0, 240, 255, 0.4));
}

/* 右侧状态区 */
.header-right {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 18px;
  width: 25%;
  min-width: 330px;
}

/* LIVE 徽标 */
.live-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(6, 78, 59, 0.5);
  border: 1px solid rgba(16, 185, 129, 0.4);
  padding: 2px 8px;
  border-radius: 9999px;
}

.ripple-dot {
  position: relative;
  display: flex;
  height: 8px;
  width: 8px;
}

.ripple-dot::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: #34d399;
  animation: ripple-spread 1.6s infinite ease-out;
}

.ripple-core {
  height: 8px;
  width: 8px;
  border-radius: 50%;
  background: #34d399;
}

@keyframes ripple-spread {
  0% { transform: scale(1); opacity: 0.8; }
  100% { transform: scale(2.4); opacity: 0; }
}

.live-text {
  font-size: 10px;
  font-weight: 700;
  color: #34d399;
  letter-spacing: 1px;
}

/* SLA 综合健康率 */
.sla-info {
  text-align: right;
  white-space: nowrap;
}

.sla-label {
  font-size: 9px;
  color: #7b8ca8;
}

.sla-value {
  font-size: 12px;
  font-weight: 700;
  color: #34d399;
  font-family: 'Courier New', monospace;
}

/* 时钟 */
.header-clock {
  font-family: 'Courier New', monospace;
  color: #67e8f9;
  font-weight: 700;
  font-size: 14px;
  letter-spacing: 1px;
  white-space: nowrap;
  text-shadow: 0 0 8px rgba(0, 240, 255, 0.35);
}

/* ==================== 告警中心层 ==================== */
/* 告警中心层(grow+零基准: 剩余空间被三层均分,无底部空白,与内容零耦合) */
.alert-layer {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  gap: 18px;
}

/* 宽度配比: 统计区3 : 闭环环形图2 : 频次推移4 : 未结列表3 */
.alert-layer > :nth-child(1) { flex: 3; min-width: 0; min-height: 0; }
.alert-layer > :nth-child(2) { flex: 2; min-width: 0; min-height: 0; }
.alert-layer > :nth-child(3) { flex: 4; min-width: 0; min-height: 0; }
.alert-layer > :nth-child(4) { flex: 3; min-width: 0; min-height: 0; }

/* 2×2 统计卡: flex 换行 + 显式宽高(严格填满容器,不被内容撑高) */
.alert-stats-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 18px;
}

.alert-stats-grid .alert-stat {
  width: calc(50% - 9px);
  height: calc(50% - 9px);
  min-height: 0;
}

/* 统计卡紧凑化: 降低告警层高度下限,让二三排矩阵层分到更多高度 */
.alert-stat {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 6px;
  padding: 10px 14px;
}

.alert-stat-head,
.alert-stat-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
}

.alert-stat-title {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 14px;
  font-weight: 700;
  white-space: nowrap;
}

.alert-stat-trend {
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

.alert-stat-value {
  font-size: 28px;
  font-weight: 900;
  font-family: 'Courier New', monospace;
  line-height: 1;
}

.alert-stat-note {
  font-size: 11px;
  color: #6a7a94;
  white-space: nowrap;
}

.alert-stat-bar {
  height: 4px;
  border-radius: 1px;
  background: rgba(255, 255, 255, 0.08);
  overflow: hidden;
}

.alert-stat-fill {
  height: 100%;
  border-radius: 1px;
}

/* 级别配色(沿用大屏主题色) */
.c-critical { color: #ff4757; }
.c-major { color: #ffa502; }
.c-minor { color: #ffd93d; }
.c-info { color: #00d4ff; }
.c-good { color: #00ff88; }
.c-warn { color: #ffa502; }
.c-bad { color: #ff4757; }

/* 告警级别统计卡: 整框边框色与各级字体颜色一致(双类选择器覆盖 .metric-card 默认青色边框) */
.metric-card.level-critical { border-left: 1px solid #ff4757; }
/* 重要卡: 整框橙色 + 左侧2px同色强调(严重卡保持呼吸灯红色边框,由动画驱动) */
.metric-card.level-major { border: 1px solid rgba(255, 165, 2, 0.6); border-left: 1px solid #ffa502; }
.metric-card.level-minor { border: 1px solid rgba(255, 217, 61, 0.55); border-left: 1px solid #ffd93d; }
.metric-card.level-info { border: 1px solid rgba(0, 212, 255, 0.55); border-left: 1px solid #00d4ff; }
/* hover 保持各级主题色(特异性高于 .metric-card:hover 的默认青色) */
.metric-card.level-critical:hover { border-color: #ff4757; }
.metric-card.level-major:hover { border-color: #ffa502; }
.metric-card.level-minor:hover { border-color: #ffd93d; }
.metric-card.level-info:hover { border-color: #00d4ff; }
/* 重要卡文本: 趋势/说明同字色 */
.level-major .alert-stat-trend,
.level-major .alert-stat-note { color: #ffa502; }

.level-critical .alert-stat-fill { background: #ff4757; }
.level-major .alert-stat-fill { background: #ffa502; }
.level-minor .alert-stat-fill { background: #ffd93d; }
.level-info .alert-stat-fill { background: #00d4ff; }

/* 严重告警呼吸灯 */
.breathing-critical { animation: pulse-critical 2s infinite ease-in-out; }
@keyframes pulse-critical {
  0%, 100% { box-shadow: 0 0 6px rgba(255, 71, 87, 0.2), inset 0 0 4px rgba(255, 71, 87, 0.1); border-color: rgba(255, 71, 87, 0.4); }
  50% { box-shadow: 0 0 18px rgba(255, 71, 87, 0.6), inset 0 0 10px rgba(255, 71, 87, 0.25); border-color: rgba(255, 71, 87, 0.9); }
}

/* 高频微闪 */
.blink-fast { animation: blink-fast 0.8s infinite; }
@keyframes blink-fast {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.2; }
}

/* 告警层图表/列表卡片 */
.tile-card {
  display: flex;
  flex-direction: column;
}

.tile-card .card-header { margin-bottom: 6px; }

.header-tag {
  margin-left: auto;
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  background: rgba(10, 25, 50, 0.6);
  border: 1px solid rgba(0, 212, 255, 0.15);
  border-radius: 8px;
  padding: 1px 6px;
  white-space: nowrap;
}

.header-tag.c-good { color: #00ff88; border-color: rgba(0, 255, 136, 0.3); }
.header-tag.c-warn { color: #ffa502; border-color: rgba(255, 165, 2, 0.3); }

.streaming-tag {
  color: #00d4ff;
  animation: stream-pulse 1.5s ease-in-out infinite;
}
@keyframes stream-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.35; }
}

/* 图表高度随卡片弹性伸缩(不设最小高度,三层高度比例纯由 flex 决定) */
.chart-sm { flex: 1; min-height: 0; }

.closure-footer {
  flex-shrink: 0;
  display: flex;
  justify-content: space-around;
  font-size: 13px;
  color: #8a9bb5;
  border-top: 1px solid rgba(0, 212, 255, 0.1);
  padding-top: 6px;
}

/* 实时未结告警列表: 轨道双份渲染,位移由 JS(rollTick)按 50ms 步进驱动,无缝循环 */
.alert-roll-list {
  position: relative;
  flex: 1;
  overflow: hidden;
  /* 上下边缘渐隐,提示内容为滚动流 */
  -webkit-mask-image: linear-gradient(180deg, transparent 0, #000 14px, #000 calc(100% - 14px), transparent 100%);
  mask-image: linear-gradient(180deg, transparent 0, #000 14px, #000 calc(100% - 14px), transparent 100%);
}

.alert-roll-track {
  display: flex;
  flex-direction: column;
  gap: 6px;
  /* transform 由 JS 逐帧赋值(不经 CSS 动画),数据增量接入时位置不重置,不产生跳变 */
  will-change: transform;
}

.alert-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: 6px;
  border: 1px solid;
  flex-shrink: 0;
}

.alert-row.critical { color: #ff6b81; border-color: rgba(255, 71, 87, 0.4); background: rgba(255, 71, 87, 0.08); }
.alert-row.major { color: #ffb84d; border-color: rgba(255, 165, 2, 0.4); background: rgba(255, 165, 2, 0.08); }
.alert-row.minor { color: #ffd93d; border-color: rgba(255, 217, 61, 0.35); background: rgba(255, 217, 61, 0.06); }
.alert-row.info { color: #4dd8ff; border-color: rgba(0, 212, 255, 0.35); background: rgba(0, 212, 255, 0.06); }

.alert-level {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  padding: 1px 4px;
  border: 1px solid currentColor;
  border-radius: 3px;
  background: rgba(0, 0, 0, 0.35);
}

.alert-src {
  font-family: 'Courier New', monospace;
  font-size: 13px;
  color: #e0e6ed;
  white-space: nowrap;
}

.alert-desc {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 12px;
  color: #a8b8d0;
}

.alert-time {
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

/* ==================== 分层区域标题 ==================== */
.section-bar {
  flex: 0 0 22px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 16px;
  font-weight: 700;
  letter-spacing: 1px;
  color: #00d4ff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.section-bar.cloud .section-title { color: #ff9900; }

.section-meta {
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

/* ==================== 基础设施/专有云矩阵 ==================== */
/* 基础设施矩阵(grow+零基准: 与告警层严格等高) */
.infra-grid {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  gap: 18px;
}

.infra-grid > .mini-card { flex: 1; min-width: 0; min-height: 0; }

/* 阿里云矩阵(grow+零基准: 与前两层严格等高) */
.cloud-grid {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  gap: 18px;
}

.cloud-grid > .mini-card { flex: 1; min-width: 0; min-height: 0; }

.mini-card {
  display: flex;
  flex-direction: column;
  /* 溢出隐藏: 非全屏等低高度场景下,超高部分直接在卡片内裁切,不允许属性行跑出卡片外框 */
  overflow: hidden;
  /* 上下内边距 12px: 为 5 行明细(15px 行距)预留垂直预算,1080P 全屏等高模式下不溢出 */
  padding: 12px 16px;
}

.mini-card .card-header {
  font-size: 16px;
  margin-bottom: 10px;
  padding-bottom: 6px;
}

/* 卡片头右侧标签略放大,与卡片内放大后的文字层级协调 */
.mini-card .header-tag { font-size: 12px; padding: 1px 8px; }

.mini-main {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 6px;
  margin-bottom: 10px;
}

.mini-value {
  font-size: 28px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}

.mini-flag {
  font-size: 14px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

/* 主题色 flag: c-* 类双类后置,覆盖上方默认灰色(同 .header-tag.c-good 的处理方式) */
.mini-flag.c-good { color: #00ff88; }
.mini-flag.c-info { color: #00d4ff; }
.mini-flag.c-warn { color: #ffa502; }
.mini-flag.c-bad { color: #ff4757; }

/* 明细行: 属性整块贴卡片底部向上排布,行内固定间距;卡片内容不足时余白留在上方,不随卡片高度拉伸 */
.mini-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
  font-size: 13px;
  color: #8a9bb5;
  margin-top: auto;
}

.mini-list-item {
  display: flex;
  justify-content: space-between;
  gap: 6px;
  white-space: nowrap;
  /* 行高固定 18px: 13px 字体的稳定垂直栅格,保证行距预算可预期,卡片内不溢出 */
  line-height: 18px;
}

/* 属性名图标化: 前导菱形光点,纯文本行有图形锚点(青辉与大屏配色一致) */
.mini-list-item > span:first-child {
  position: relative;
  padding-left: 11px;
  color: #96a7c2;
}
.mini-list-item > span:first-child::before {
  content: '';
  position: absolute;
  left: 1px;
  top: 50%;
  width: 4px;
  height: 4px;
  margin-top: -2px;
  transform: rotate(45deg);
  border: 1px solid rgba(0, 212, 255, 0.55);
  background: rgba(0, 212, 255, 0.15);
  box-shadow: 0 0 4px rgba(0, 212, 255, 0.35);
}

/* 属性值 → 数据标签(capsule): 圆角细边浅底,line-height 16+border 2 = 18,与行栅格吻合不溢出 */
.mini-list-value {
  display: inline-block;
  min-width: 0;
  max-width: 62%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 0 8px;
  border-radius: 999px;
  line-height: 16px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  font-family: 'Courier New', monospace;
  text-align: right;
}

/* 数据标签语义色: 双类后置覆盖灰底,边框/底色/文字跟随健康度语义 */
.mini-list-value.c-good { border-color: rgba(0, 255, 136, 0.4); background: rgba(0, 255, 136, 0.09); }
.mini-list-value.c-info { border-color: rgba(0, 212, 255, 0.4); background: rgba(0, 212, 255, 0.09); }
.mini-list-value.c-warn { border-color: rgba(255, 165, 2, 0.4); background: rgba(255, 165, 2, 0.09); }
.mini-list-value.c-bad  { border-color: rgba(255, 71, 87, 0.42); background: rgba(255, 71, 87, 0.09); }

/* 进度条区域: 与属性明细一致贴卡片底部向上排布,行距固定 */
.mini-progress {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: auto;
}

/* 属性明细列表: 大数值之下,属性+值锚定卡底、自底部向上排布(上方余量自动留白),
   行距 14px 固定不随卡高拉伸;值语义色由 c-* 类提供,随 30s 状态抖动实时刷新 */
.mini-metrics {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-top: auto;
}

.mini-metric {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  font-size: 12px;
  line-height: 17px;
  color: #8a9bb5;
  white-space: nowrap;
}

/* 属性名: 前导菱形光点(与明细列表一致),超长省略防挤压值 */
.mini-metric > span:first-child {
  position: relative;
  flex: 1;
  min-width: 0;
  padding-left: 10px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.mini-metric > span:first-child::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  width: 4px;
  height: 4px;
  margin-top: -2px;
  transform: rotate(45deg);
  border: 1px solid rgba(0, 212, 255, 0.55);
  background: rgba(0, 212, 255, 0.15);
  box-shadow: 0 0 4px rgba(0, 212, 255, 0.35);
}

/* 属性值标签: 圆角胶囊(与 ITSM 卡明细值同款),等宽加粗超长省略;
   语义色规则双类后置覆盖灰底,普通行(无 c-* 类)保持浅灰标签 */
.mini-metric .mm-val {
  flex-shrink: 0;
  max-width: 58%;
  overflow: hidden;
  text-overflow: ellipsis;
  padding: 0 8px;
  border-radius: 999px;
  line-height: 14px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  font-family: 'Courier New', monospace;
  font-weight: 600;
}
/* 值标签语义色: 边框/底色/文字跟随健康度(与 .mini-list-value.c-* 同配色) */
.mini-metric .mm-val.c-good {
  color: #00ff88;
  border-color: rgba(0, 255, 136, 0.4);
  background: rgba(0, 255, 136, 0.09);
}
.mini-metric .mm-val.c-info {
  color: #00d4ff;
  border-color: rgba(0, 212, 255, 0.4);
  background: rgba(0, 212, 255, 0.09);
}
.mini-metric .mm-val.c-warn {
  color: #ffa502;
  border-color: rgba(255, 165, 2, 0.4);
  background: rgba(255, 165, 2, 0.09);
}
.mini-metric .mm-val.c-bad {
  color: #ff4757;
  border-color: rgba(255, 71, 87, 0.42);
  background: rgba(255, 71, 87, 0.09);
}

/* 单个指标组: 文本行与进度条贴合(组内 3px),组间距离由 .mini-progress 的 gap 控制 */
.mini-progress-item {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.mini-progress-row {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: #8a9bb5;
}
.mini-progress-row .c-info,
.mini-progress-row .c-warn { font-family: 'Courier New', monospace; }

/* 覆盖 .progress-bar 的 flex:1(在纵向 flex 中 basis 0 会导致高度归零),固定进度条高度 */
.progress-bar.sm { flex: 0 0 auto; height: 5px; }

/* 阿里云专有云卡片橙色点缀 */
.ali-card { border-left: 2px solid rgba(255, 153, 0, 0.55); }
.ali-card .card-header { border-bottom-color: rgba(255, 153, 0, 0.18); }
.ali-card .card-icon { color: #ff9900; }

/* ==================== 二三层卡片边框呼吸高亮 ==================== */
/* 基础设施矩阵: 青色柔光呼吸,错峰闪动营造流动感;hover 暂停动画改用静态高亮 */
/* 发光加粗: 1px 轮廓光带贴边扩散等效加宽亮边 + 双层辉光增强亮度与范围 */
.mini-card { animation: glow-border 3.2s infinite ease-in-out; }
.mini-card:nth-child(2n) { animation-delay: 0.8s; }
.mini-card:nth-child(3n) { animation-delay: 1.6s; }
.mini-card:hover { animation: none; }
@keyframes glow-border {
  0%, 100% {
    border-color: rgba(0, 212, 255, 0.32);
    box-shadow: 0 0 0 1px rgba(0, 212, 255, 0.3), 0 0 16px rgba(0, 212, 255, 0.15), 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(0, 212, 255, 0.1);
  }
  50% {
    border-color: rgba(0, 212, 255, 0.85);
    box-shadow: 0 0 0 1px rgba(0, 212, 255, 0.6), 0 0 22px rgba(0, 212, 255, 0.45), 0 0 44px rgba(0, 212, 255, 0.18), 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(0, 212, 255, 0.16);
  }
}

/* 阿里云矩阵: 橙色柔光呼吸,左侧橙条保持静态实色不参与动画 */
.ali-card { animation: glow-border-ali 3.2s infinite ease-in-out; }
.ali-card:nth-child(2n) { animation-delay: 0.8s; }
.ali-card:nth-child(3n) { animation-delay: 1.6s; }
.ali-card:hover { animation: none; border-color: rgba(255, 153, 0, 0.6); }
@keyframes glow-border-ali {
  0%, 100% {
    border-top-color: rgba(255, 153, 0, 0.42);
    border-right-color: rgba(255, 153, 0, 0.42);
    border-bottom-color: rgba(255, 153, 0, 0.42);
    box-shadow: 0 0 0 1px rgba(255, 153, 0, 0.32), 0 0 16px rgba(255, 153, 0, 0.15), 0 2px 20px rgba(0, 0, 0, 0.2);
  }
  50% {
    border-top-color: rgba(255, 153, 0, 0.88);
    border-right-color: rgba(255, 153, 0, 0.88);
    border-bottom-color: rgba(255, 153, 0, 0.88);
    box-shadow: 0 0 0 1px rgba(255, 153, 0, 0.62), 0 0 22px rgba(255, 153, 0, 0.45), 0 0 44px rgba(255, 153, 0, 0.18), 0 2px 20px rgba(0, 0, 0, 0.2);
  }
}

/* ==================== 核心指标卡片网格 ==================== */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
  margin-bottom: 16px;
}

.metric-card {
  background: linear-gradient(135deg, rgba(12, 28, 58, 0.85), rgba(6, 16, 35, 0.9));
  border: 1px solid rgba(0, 212, 255, 0.12);
  border-radius: 10px;
  padding: 14px 16px;
  box-shadow: 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(0, 212, 255, 0.06);
  transition: all 0.3s ease;
}

.metric-card:hover {
  border-color: rgba(0, 212, 255, 0.35);
  transform: translateY(-2px);
  box-shadow: 0 6px 30px rgba(0, 0, 0, 0.3), 0 0 20px rgba(0, 212, 255, 0.05);
}

.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 600;
  color: #a8b8d0;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(0, 212, 255, 0.08);
}

.card-icon {
  color: #00d4ff;
  flex-shrink: 0;
  /* 图标随所在标题字号缩放,与标题文本同大(覆盖模板内联的固定宽高属性) */
  width: 1em;
  height: 1em;
}

.card-body { position: relative; }

/* ==================== 第2屏 ITSM 指标卡(内部纵向弹性,与第一屏 mini 卡同风格) ==================== */
/* 卡体纵向排布: 明细列表贴卡底部,同排卡片被行高拉齐时视觉统一 */
.metrics-grid .metric-card {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: relative;
}

.metrics-grid .card-body {
  flex: 1;
  display: flex;
  flex-direction: column;
}

/* 知识库占位区弹性撑满剩余高度,与同排真数据卡等高 */
.metrics-grid .placeholder-area {
  flex: 1;
  min-height: 120px;
}

/* 明细行: 左侧标签防压缩;右侧数值为工单标题等长文本时省略截断 */
.metrics-grid .mini-list-item > span:first-child { flex-shrink: 0; }

/* 第二屏属性行: 属性名与值标签最小间距 10px(五张管理卡及 SLA/总览卡统一) */
.metrics-grid .mini-list-item { gap: 10px; }

/* 第二屏指标卡行距: 全局明细 gap 15 收紧至 12,压缩两行指标卡高度预算
   (行高取行内最高卡,行距越紧行高越低,给图表区/走马灯留出可视区余量) */
.metrics-grid .mini-list { gap: 12px; }

/* ==================== ITSM 指标卡: 属性内嵌占比条 ==================== */
/* 属性行内嵌占比条: 色点 + 属性名 + 轨道(条宽 = 属性值/分母总量,色随语义) + 数值胶囊 */
.itsm-bar-row {
  display: flex;
  align-items: center;
  gap: 10px;
  line-height: 18px;
  white-space: nowrap;
}

.itsm-bar-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.itsm-bar-label {
  flex-shrink: 0;
  font-size: 13px;
  color: #96a7c2;
}

.itsm-bar-track {
  flex: 1;
  min-width: 0;
  height: 6px;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.06);
  overflow: hidden;
}

.itsm-bar-fill {
  display: block;
  height: 100%;
  border-radius: 3px;
  transition: width 0.6s ease;
}

/* 属性值(管理卡): 外层仅做右对齐弹性容器,内层标签宽度随文本自适应;
   短值标签靠右,超长时内层标签收缩省略,左缘与属性名保持 10px 间距 */
.itsm-row-value {
  flex: 1;
  min-width: 0;
  display: flex;
  justify-content: flex-end;
}
.itsm-row-value > span {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 0 8px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  font-family: 'Courier New', monospace;
  line-height: 16px;
  /* 青色文字: 管理卡属性值统一有色字体(编号强调由 c-info 后置,同青系加边框色) */
  color: #00d4ff;
}

/* 编号等强调值: 青系标签(双类压过上方 chip 灰字,与底色边框一起着色) */
.itsm-row-value > span.c-info {
  color: #00d4ff;
  border-color: rgba(0, 212, 255, 0.4);
  background: rgba(0, 212, 255, 0.09);
}
.header-tag.c-info { color: #00d4ff; border-color: rgba(0, 212, 255, 0.3); }
.metrics-grid .mini-value.c-good { color: #00ff88; }

/* ==================== 第二屏指标卡光影动态特效 ==================== */
/* 呼吸辉光: 青色边框柔光呼吸(与第一屏 mini 卡同节奏,错峰闪动) */
.metrics-grid .metric-card { animation: itsm-glow 3.2s infinite ease-in-out; }
.metrics-grid .metric-card:nth-child(2n) { animation-delay: 0.8s; }
.metrics-grid .metric-card:nth-child(3n) { animation-delay: 1.6s; }
.metrics-grid .metric-card:hover { animation: none; }
@keyframes itsm-glow {
  0%, 100% {
    border-color: rgba(0, 212, 255, 0.3);
    box-shadow: 0 0 0 1px rgba(0, 212, 255, 0.24), 0 0 14px rgba(0, 212, 255, 0.12), 0 2px 20px rgba(0, 0, 0, 0.2);
  }
  50% {
    border-color: rgba(0, 212, 255, 0.8);
    box-shadow: 0 0 0 1px rgba(0, 212, 255, 0.55), 0 0 20px rgba(0, 212, 255, 0.4), 0 0 44px rgba(0, 212, 255, 0.15), 0 2px 20px rgba(0, 0, 0, 0.2);
  }
}

/* 扫光: 光带周期扫过卡面(卡 overflow hidden 裁切,text 不受影响) */
.metrics-grid .metric-card::after {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: 0;
  width: 46%;
  transform: translateX(-140%);
  background: linear-gradient(100deg, transparent 0%, rgba(0, 212, 255, 0.16) 50%, transparent 100%);
  animation: itsm-sweep 5.4s ease-in-out infinite;
  pointer-events: none;
}
.metrics-grid .metric-card:nth-child(2n)::after { animation-delay: 1.35s; }
.metrics-grid .metric-card:nth-child(3n)::after { animation-delay: 2.7s; }
.metrics-grid .metric-card:hover::after { animation: none; opacity: 0; }
@keyframes itsm-sweep {
  0% { transform: translateX(-140%); }
  55% { transform: translateX(330%); }
  100% { transform: translateX(330%); }
}

/* ==================== 第二屏整屏弹性布局 ==================== */
/* 第二屏占满滚动视口: 父 view 高度经 min-height 确定后,flex-grow 吸收全部剩余空间
   (不能依赖 min-height:100% —— 父高度 auto 的滚动链下子元素百分比高度不生效,内容不足时无法撑满) */
.dashboard-itsm {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
}
.dashboard-itsm .metrics-grid { flex-shrink: 0; }
.dashboard-itsm .charts-section { flex-shrink: 0; }

/* ==================== 第二屏第四排: 五类工单处理明细流 · 水平走马灯 ==================== */
/* 弹性吸收前三排剩余高度(卡片随视口高度拉伸);min-height 仅保空态可视下限,
   避免非全屏/缩放视口不足时整屏出现滚动条 */
.itsm-event-ticker {
  flex: 1 1 auto;
  min-height: 135px;
  margin-top: 16px;
  display: flex;
  flex-direction: column;
}

.itsm-ticker-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.itsm-ticker-title {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 1px;
  color: #00d4ff;
  white-space: nowrap;
}

.itsm-ticker-sub {
  font-size: 11px;
  font-weight: 400;
  letter-spacing: 2px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
}

.itsm-ticker-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: #7b8ca8;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

.ticker-live-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #00ff88;
  box-shadow: 0 0 6px #00ff88;
  animation: ticker-dot 1.6s ease-in-out infinite;
}
@keyframes ticker-dot {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

/* 视口: 左右边缘渐隐,提示内容横向滚动 */
.ticker-viewport {
  overflow: hidden;
  border: 1px solid rgba(0, 212, 255, 0.14);
  border-radius: 10px;
  background: linear-gradient(135deg, rgba(10, 24, 50, 0.55), rgba(5, 12, 28, 0.65));
  padding: 10px 0;
  display: flex;
  align-items: stretch;
  flex: 1;
  min-height: 0;
  -webkit-mask-image: linear-gradient(90deg, transparent 0, #000 48px, #000 calc(100% - 48px), transparent 100%);
  mask-image: linear-gradient(90deg, transparent 0, #000 48px, #000 calc(100% - 48px), transparent 100%);
  position: relative;
}

/* 走马灯轨道扫光: 单条金色光束周期性掠过(单实例动画,开销低) */
.ticker-viewport::after {
  content: '';
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: -26%;
  width: 22%;
  pointer-events: none;
  background: linear-gradient(100deg, transparent, rgba(255, 184, 40, 0.09), transparent);
  animation: ticker-gold-beam 7s ease-in-out infinite;
}
@keyframes ticker-gold-beam {
  0% { transform: translateX(0); }
  60%, 100% { transform: translateX(700%); }
}

/* 轨道: 4 份等宽序列首尾相连,自左向右平移(25% 即一个序列周期,回绕点画面一致实现无缝) */
.ticker-track {
  display: flex;
  width: max-content;
  animation: ticker-scroll-right 80s linear infinite;
  will-change: transform;
}
.ticker-track.ticker-paused { animation-play-state: paused; }
.ticker-seq {
  display: flex;
  flex-shrink: 0;
}
@keyframes ticker-scroll-right {
  from { transform: translateX(-25%); }
  to { transform: translateX(0); }
}

/* 明细卡: 纵向弹性铺满剩余高度,行间隙随卡高均匀分布;
   第四排与前三排区分 —— 金色呼吸边框(错峰,离屏卡被视口 overflow 裁剪不参与绘制) */
.ticker-card {
  flex-shrink: 0;
  width: 380px;
  margin-right: 14px;
  padding: 16px 18px;
  border-radius: 12px;
  background: linear-gradient(135deg, rgba(14, 24, 50, 0.92), rgba(8, 15, 34, 0.95));
  border: 1px solid rgba(255, 176, 32, 0.3);
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.25), inset 0 1px 0 rgba(255, 176, 32, 0.07);
  transition: border-color 0.25s ease;
  display: flex;
  flex-direction: column;
  justify-content: space-evenly;
  animation: ticker-gold-glow 3.6s infinite ease-in-out;
}
.ticker-card:nth-child(2n) { animation-delay: 1.4s; }
.ticker-card:nth-child(3n) { animation-delay: 0.7s; }
.ticker-card:hover {
  animation: none;
  border-color: rgba(255, 200, 92, 0.95);
  box-shadow: 0 0 18px rgba(255, 176, 32, 0.25), 0 2px 12px rgba(0, 0, 0, 0.25);
}
@keyframes ticker-gold-glow {
  0%, 100% {
    border-color: rgba(255, 176, 32, 0.3);
    box-shadow: 0 0 0 1px rgba(255, 176, 32, 0.14), 0 0 12px rgba(255, 176, 32, 0.07), 0 2px 12px rgba(0, 0, 0, 0.25), inset 0 1px 0 rgba(255, 176, 32, 0.06);
  }
  50% {
    border-color: rgba(255, 200, 92, 0.85);
    box-shadow: 0 0 0 1px rgba(255, 176, 32, 0.42), 0 0 20px rgba(255, 176, 32, 0.28), 0 2px 12px rgba(0, 0, 0, 0.25), inset 0 1px 0 rgba(255, 200, 92, 0.13);
  }
}

/* 头行: 左侧类别徽标 + 右侧状态 */
.ticker-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

/* 类别徽标: 颜色内联绑定(请求紫/发布青/事件绿/变更橙/问题红) */
.ticker-type {
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 1px;
  padding: 2px 10px;
  border-radius: 4px;
  border: 1px solid;
  white-space: nowrap;
}

.ticker-card-status {
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 1px;
  white-space: nowrap;
}

/* 标题行: 大号加粗,最多两行省略 */
.ticker-title {
  font-size: 17px;
  font-weight: 600;
  line-height: 1.55;
  color: #f0f4fa;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  overflow-wrap: break-word;
}

/* 属性区: 每个属性独立一行 */
.ticker-card-attrs {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.ticker-attr {
  display: flex;
  align-items: center;
  /* 属性名与值标签最小间距 10px */
  gap: 10px;
}
.ticker-attr-label {
  flex-shrink: 0;
  min-width: 6.5em;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #5f7290;
  letter-spacing: 1px;
}

/* 属性名前语义小图标: 随标签字号等大(1em),不参与 min-width 对齐;
   颜色由 ta-* 彩类提供(链路语义: 发起青 / 处理中金 / 上一步蓝) */
.ticker-attr-label svg {
  width: 1em;
  height: 1em;
  flex-shrink: 0;
}
.ticker-attr-label .ta-apl { color: #00d4ff; }
.ticker-attr-label .ta-cur { color: #ffb020; }
.ticker-attr-label .ta-prev { color: #7fb3ff; }

/* 属性值: 右对齐弹性容器,标签宽度随文本自适应;超长截断后左缘与属性名保持 10px */
.ticker-attr-value {
  flex: 1;
  min-width: 0;
  display: flex;
  justify-content: flex-end;
}
.ticker-chip {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 1px 9px;
  border-radius: 999px;
  border: 1px solid rgba(0, 212, 255, 0.35);
  background: rgba(0, 212, 255, 0.07);
  /* 与属性名同级字号(13px),加粗胶囊作值强调;三行语义色与行首图标同色
     (发起青/处理中金/上一步蓝),属性值不使用白/近白文本 */
  font-size: 13px;
  font-weight: 600;
  line-height: 18px;
  color: #00d4ff;
}
/* 当前处理人: 处理中金(与行首图标 ta-cur 同色) */
.ticker-chip.handler {
  color: #ffb020;
  border-color: rgba(255, 176, 32, 0.45);
  background: rgba(255, 176, 32, 0.1);
}
/* 上一步处理人: 流转蓝(与行首图标 ta-prev 同色) */
.ticker-chip.prev {
  color: #7fb3ff;
  border-color: rgba(127, 179, 255, 0.4);
  background: rgba(127, 179, 255, 0.09);
}

/* 底行: 编号 + 时间(等宽字体) */
.ticker-card-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}
.ticker-id {
  font-size: 14px;
  color: #00d4ff;
  letter-spacing: 0.5px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.ticker-time {
  flex-shrink: 0;
  font-size: 14px;
  color: #7b8ca8;
  letter-spacing: 1px;
}

/* 走马灯空态: 金色雷达动画(文案由 .de-text 承担) */
.ticker-empty {
  --de: 255, 184, 40;
  flex: 1;
  min-height: 58px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

/* ==================== 颜色变量 ==================== */
.text-danger { color: #ff4757 !important; }
.text-warning { color: #ffa502 !important; }
.text-success { color: #00ff88 !important; }

.critical { color: #ff4757; }
.warning { color: #ffa502; }
.success { color: #00ff88; }
.danger { color: #ff4757; }
.processing { color: #6b7dff; }
.info { color: #00d4ff; }

.dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-right: 4px;
}
.critical-dot { background: #ff4757; box-shadow: 0 0 4px #ff4757; }
.warning-dot { background: #ffa502; box-shadow: 0 0 4px #ffa502; }
.info-dot { background: #00d4ff; box-shadow: 0 0 4px #00d4ff; }
.success-dot { background: #00ff88; box-shadow: 0 0 4px #00ff88; }
.error-dot { background: #ff4757; box-shadow: 0 0 4px #ff4757; }

/* ==================== 指标公共 ==================== */
.metric-main {
  text-align: center;
  margin-bottom: 10px;
}
.metric-number {
  font-size: 32px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
  text-shadow: 0 0 10px rgba(0, 212, 255, 0.2);
}
.metric-label {
  font-size: 12px;
  color: #6a7a94;
  margin-top: 2px;
}

.metric-details {
  display: flex;
  justify-content: center;
  gap: 16px;
  margin-bottom: 10px;
}
.detail-item {
  display: flex;
  align-items: center;
  font-size: 12px;
  color: #8a9bb5;
}

.metric-sub-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-bottom: 8px;
}
.sub-metric {
  text-align: center;
}
.sub-number {
  font-size: 20px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}
.sub-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 2px;
}

.metric-trend {
  font-size: 12px;
  color: #6a7a94;
  text-align: center;
}
.trend-up { color: #ff4757; }

/* ==================== 进度条 ==================== */
.progress-bar-group { margin-top: 8px; }
.progress-item {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}
.progress-label {
  font-size: 11px;
  color: #8a9bb5;
  width: 28px;
  flex-shrink: 0;
}
.progress-bar {
  flex: 1;
  height: 6px;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 3px;
  overflow: hidden;
}
.progress-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 1s ease;
}
.cpu-fill { background: linear-gradient(90deg, #00d4ff, #6b7dff); }
.mem-fill { background: linear-gradient(90deg, #ffd93d, #ff6b6b); }
.disk-fill { background: linear-gradient(90deg, #00ff88, #00d4ff); }
.net-fill { background: linear-gradient(90deg, #a78bfa, #00d4ff); }
.progress-value {
  font-size: 11px;
  color: #8a9bb5;
  width: 35px;
  text-align: right;
  flex-shrink: 0;
  font-family: 'Courier New', monospace;
}

/* ==================== 数据库 ==================== */
.db-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  margin-top: 8px;
}
.db-stat-item { text-align: center; }
.db-stat-value {
  font-size: 16px;
  font-weight: 600;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}
.db-stat-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 2px;
}

/* ==================== 中间件 ==================== */
.mw-list {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 4px 12px;
  margin-top: 8px;
}
.mw-item {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  padding: 3px 0;
}
.mw-name { color: #8a9bb5; }
.mw-count {
  font-family: 'Courier New', monospace;
  color: #6a7a94;
  font-weight: 600;
}

/* ==================== 缓存 ==================== */
.cache-stats {
  display: flex;
  align-items: center;
  gap: 16px;
}
.cache-stat-item { text-align: center; }
.cache-stat-circle {
  position: relative;
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.circle-text {
  position: absolute;
  font-size: 14px;
  font-weight: 700;
  color: #00d4ff;
  font-family: 'Courier New', monospace;
}
.cache-stat-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 4px;
}
.cache-info {
  flex: 1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px 12px;
}
.cache-info-item {
  display: flex;
  flex-direction: column;
}
.cache-info-label { font-size: 11px; color: #6a7a94; }
.cache-info-value {
  font-size: 14px;
  font-weight: 600;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}

/* ==================== K8s ==================== */
.k8s-summary {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-bottom: 8px;
}
.k8s-summary-item { text-align: center; }
.k8s-summary-num {
  font-size: 18px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}
.k8s-summary-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 2px;
}

.k8s-usage { margin-bottom: 8px; }
.k8s-usage .progress-item { margin-bottom: 4px; }

.k8s-ns-list {
  display: grid;
  gap: 3px;
}
.ns-item {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  padding: 2px 6px;
  background: rgba(0, 212, 255, 0.05);
  border-radius: 3px;
}
.ns-name {
  color: #00d4ff;
  font-weight: 500;
}
.ns-stats { color: #6a7a94; }

/* ==================== 网络流量 ==================== */
.net-summary { margin-bottom: 8px; }
.net-summary-item { text-align: center; margin-bottom: 6px; }
.net-value {
  font-size: 28px;
  font-weight: 700;
  color: #00d4ff;
  font-family: 'Courier New', monospace;
}
.net-unit { font-size: 14px; color: #6a7a94; }
.net-label { font-size: 11px; color: #6a7a94; }

.net-peak {
  display: flex;
  justify-content: center;
  gap: 24px;
}
.net-peak-item {
  text-align: center;
}
.peak-label { font-size: 11px; color: #6a7a94; display: block; }
.peak-value {
  font-size: 16px;
  font-weight: 600;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}

/* ==================== 网络设备 ==================== */
.port-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-top: 8px;
}
.port-stat { text-align: center; }
.port-label {
  font-size: 11px;
  color: #6a7a94;
  display: block;
}
.port-value {
  font-size: 14px;
  font-weight: 600;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}

/* ==================== 链路追踪 ==================== */
.trace-summary {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-bottom: 8px;
}
.trace-stat { text-align: center; }
.trace-value {
  font-size: 16px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}
.trace-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 2px;
}

.apdex-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.apdex-label {
  font-size: 11px;
  color: #8a9bb5;
  width: 72px;
  flex-shrink: 0;
}
.apdex-value {
  font-size: 14px;
  font-weight: 600;
  color: #00d4ff;
  font-family: 'Courier New', monospace;
  width: 40px;
  text-align: right;
}

.trace-services {
  display: grid;
  gap: 3px;
}
.trace-svc-item {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  padding: 2px 6px;
  background: rgba(107, 125, 255, 0.05);
  border-radius: 3px;
}
.svc-name { color: #8a9bb5; }
.svc-latency {
  color: #ffa502;
  font-family: 'Courier New', monospace;
  font-weight: 600;
}

/* ==================== URL监控 ==================== */
.url-avg {
  text-align: center;
  font-size: 12px;
  color: #6a7a94;
  margin-bottom: 8px;
}
.avg-value {
  font-size: 20px;
  font-weight: 700;
  color: #00d4ff;
  margin-left: 8px;
  font-family: 'Courier New', monospace;
}
.avg-value small { font-size: 12px; color: #6a7a94; }

.url-list {
  display: grid;
  gap: 3px;
}
.url-item {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  padding: 2px 6px;
  border-radius: 3px;
  background: rgba(0, 212, 255, 0.05);
}
.url-item.slow { background: rgba(255, 165, 2, 0.1); }
.url-item.error { background: rgba(255, 71, 87, 0.1); }
.url-name {
  color: #8a9bb5;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 140px;
}
.url-response {
  font-family: 'Courier New', monospace;
  font-weight: 600;
  flex-shrink: 0;
}
.url-item.slow .url-response { color: #ffa502; }
.url-item.error .url-response { color: #ff4757; }
.url-item.normal .url-response { color: #00ff88; }

/* ==================== JVM监控 ==================== */
.jvm-heap { margin-bottom: 8px; }
.jvm-heap-info {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  margin-bottom: 4px;
}
.heap-label { color: #8a9bb5; }
.heap-value {
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
  font-weight: 600;
}

.jvm-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  margin-bottom: 8px;
}
.jvm-stat { text-align: center; }
.jvm-stat-label {
  font-size: 11px;
  color: #6a7a94;
  display: block;
}
.jvm-stat-value {
  font-size: 14px;
  font-weight: 600;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}

.jvm-instances {
  display: grid;
  gap: 4px;
}
.jvm-instance-item {
  display: flex;
  align-items: center;
  gap: 8px;
}
.jvm-inst-name {
  font-size: 11px;
  color: #8a9bb5;
  width: 90px;
  flex-shrink: 0;
}
.jvm-inst-bar {
  flex: 1;
  height: 5px;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 3px;
  overflow: hidden;
}
.jvm-inst-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 0.8s ease;
}
.jvm-inst-value {
  font-size: 11px;
  color: #8a9bb5;
  width: 32px;
  text-align: right;
  font-family: 'Courier New', monospace;
}

/* ==================== 应用日志 ==================== */
.log-summary {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-bottom: 8px;
}
.log-stat { text-align: center; }
.log-stat-value {
  font-size: 16px;
  font-weight: 700;
  color: #e0e6ed;
  font-family: 'Courier New', monospace;
}
.log-stat-label {
  font-size: 11px;
  color: #6a7a94;
  margin-top: 2px;
}

.log-list {
  max-height: 180px;
  overflow-y: auto;
  display: grid;
  gap: 2px;
}
.log-list::-webkit-scrollbar { width: 3px; }
.log-list::-webkit-scrollbar-track { background: rgba(255,255,255,0.03); }
.log-list::-webkit-scrollbar-thumb { background: rgba(0,212,255,0.3); border-radius: 2px; }

.log-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  padding: 3px 6px;
  border-radius: 3px;
  font-family: 'Courier New', monospace;
}
.log-item.error { background: rgba(255, 71, 87, 0.08); }
.log-item.warn { background: rgba(255, 165, 2, 0.08); }

.log-time { color: #4a6a8a; }
.log-level { font-weight: 700; }
.log-level.error { color: #ff4757; }
.log-level.warn { color: #ffa502; }
.log-app {
  color: #6b7dff;
  padding: 0 4px;
}
.log-msg {
  color: #8a9bb5;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ==================== 小图表 ==================== */
.chart-mini-container {
  width: 100%;
  height: 80px;
  margin-top: 8px;
}

/* ==================== 底部图表区 ==================== */
.charts-section {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 14px;
}

/* 图表卡: 第三排与前两排指标卡区分 —— 紫罗兰色呼吸边框(错峰) + 斜向扫光带 */
.chart-card {
  position: relative;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(14, 24, 52, 0.88), rgba(7, 14, 32, 0.92));
  border: 1px solid rgba(167, 139, 250, 0.28);
  border-radius: 10px;
  padding: 14px 16px;
  box-shadow: 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(167, 139, 250, 0.07);
  transition: all 0.3s ease;
  animation: chart-glow-violet 3.4s infinite ease-in-out;
}
.chart-card:nth-child(2n) { animation-delay: 0.8s; }
.chart-card:nth-child(3n) { animation-delay: 1.6s; }

.chart-card:hover {
  animation: none;
  border-color: rgba(196, 148, 255, 0.9);
  box-shadow: 0 6px 30px rgba(0, 0, 0, 0.32), 0 0 22px rgba(167, 139, 250, 0.22);
}

/* 紫光扫光带: 自左向右斜穿整卡,周期长于呼吸营造纵深 */
.chart-card::after {
  content: '';
  position: absolute;
  top: -18%;
  bottom: -18%;
  left: -32%;
  width: 26%;
  pointer-events: none;
  background: linear-gradient(100deg, transparent, rgba(167, 139, 250, 0.1), transparent);
  animation: chart-violet-sweep 7.5s ease-in-out infinite;
}
.chart-card:hover::after { animation: none; }
@keyframes chart-glow-violet {
  0%, 100% {
    border-color: rgba(167, 139, 250, 0.3);
    box-shadow: 0 0 0 1px rgba(167, 139, 250, 0.18), 0 0 14px rgba(167, 139, 250, 0.08), 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(167, 139, 250, 0.06);
  }
  50% {
    border-color: rgba(196, 148, 255, 0.8);
    box-shadow: 0 0 0 1px rgba(167, 139, 250, 0.45), 0 0 22px rgba(167, 139, 250, 0.3), 0 2px 20px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(196, 148, 255, 0.12);
  }
}
@keyframes chart-violet-sweep {
  0% { transform: translateX(0); }
  55%, 100% { transform: translateX(640%); }
}

.chart-container {
  width: 100%;
  height: 188px;
}

/* ==================== 炫酷空态: 全息雷达扫描动画 ==================== */
/* 槽内数据为空时的占位: 扩散波纹 + 旋转虚线环 + 脉冲核心 + 流光全息文字;
   默认青色, .data-empty.violet/.de-violet 紫色, 金色由父级自定义 --de 提供 */
.chart-slot {
  position: relative;
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
}

.data-empty {
  --de: 0, 212, 255;
  position: absolute;
  inset: 0;
  z-index: 6;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at 50% 46%, rgba(var(--de), 0.07), transparent 64%);
}
.data-empty.violet,
.de-violet { --de: 167, 139, 250; }

.de-scene {
  position: relative;
  width: 64px;
  height: 64px;
  flex-shrink: 0;
}
.de-scene.sm { width: 46px; height: 46px; }

/* 旋转虚线外环: 雷达搜索意象 */
.de-ring {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 1px dashed rgba(var(--de), 0.6);
  animation: de-spin 7s linear infinite;
}

/* 脉冲核心: 发光圆点 */
.de-core {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 8px;
  height: 8px;
  margin: -4px 0 0 -4px;
  border-radius: 50%;
  background: rgba(var(--de), 0.95);
  animation: de-core-pulse 2s ease-in-out infinite;
}

/* 双层扩散波纹: 从核心向外荡开 */
.de-wave {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 22px;
  height: 22px;
  margin: -11px 0 0 -11px;
  border-radius: 50%;
  border: 1px solid rgba(var(--de), 0.7);
  opacity: 0;
  animation: de-wave 2.2s ease-out infinite;
}
.de-wave.w2 { animation-delay: 1.1s; }

/* 流光全息文字: 渐变沿文字往返滑动(字距拉开呼吸感) */
.de-text {
  margin-top: 10px;
  padding-left: 6px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 6px;
  white-space: nowrap;
  color: transparent;
  background: linear-gradient(90deg, rgba(var(--de), 0.35), rgba(var(--de), 1), rgba(var(--de), 0.35));
  background-size: 220% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  animation: de-shimmer 2.8s linear infinite;
}

@keyframes de-spin { to { transform: rotate(360deg); } }
@keyframes de-core-pulse {
  0%, 100% { box-shadow: 0 0 6px 2px rgba(var(--de), 0.6), 0 0 16px 6px rgba(var(--de), 0.3); }
  50% { box-shadow: 0 0 10px 4px rgba(var(--de), 0.95), 0 0 26px 10px rgba(var(--de), 0.45); }
}
@keyframes de-wave {
  0% { transform: scale(0.4); opacity: 0.9; }
  75%, 100% { transform: scale(1.9); opacity: 0; }
}
@keyframes de-shimmer {
  from { background-position: 220% 0; }
  to { background-position: -220% 0; }
}

/* ==================== 闪烁动画 ==================== */
.blink {
  animation: blink-text 1s ease-in-out infinite;
}
@keyframes blink-text {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

/* ==================== 响应式 ==================== */
@media (max-width: 1600px) {
  .metrics-grid { grid-template-columns: repeat(3, 1fr); }
  /* 窄屏卡片换行,高度交由内容撑开并恢复滚动 */
  .dashboard-fill { flex: none; }
  .alert-layer, .infra-grid, .cloud-grid { flex: 0 0 auto; }
  .section-bar { flex: 0 0 auto; }
  .chart-sm { flex: none; height: 150px; }
  /* 告警层: 统计区整行四卡一行,三张图表卡一行等分 */
  .alert-layer { flex-wrap: wrap; }
  .alert-layer > :nth-child(1) { flex: none; width: 100%; }
  .alert-layer > :nth-child(2),
  .alert-layer > :nth-child(3),
  .alert-layer > :nth-child(4) { flex: 1 1 0; }
  .alert-stats-grid .alert-stat { width: calc(25% - 13.5px); height: auto; }
  /* 基础设施 4 列 / 阿里云 3 列 */
  .infra-grid { flex-wrap: wrap; }
  .infra-grid > .mini-card { flex: none; width: calc((100% - 54px) / 4); }
  .cloud-grid { flex-wrap: wrap; }
  .cloud-grid > .mini-card { flex: none; width: calc((100% - 36px) / 3); }
}

@media (max-width: 1200px) {
  .metrics-grid { grid-template-columns: repeat(2, 1fr); }
  .charts-section { grid-template-columns: repeat(2, 1fr); }
  .infra-grid > .mini-card { width: calc((100% - 18px) / 2); }
  .cloud-grid > .mini-card { width: calc((100% - 18px) / 2); }
  .alert-stats-grid .alert-stat { width: calc(50% - 9px); }
  .header-center h1 { font-size: 18px; }
  .brand-subtitle { display: none; }
  .sla-info { display: none; }
}

@media (max-width: 768px) {
  .metrics-grid { grid-template-columns: 1fr; }
  .charts-section { grid-template-columns: 1fr; }
  .alert-layer > * { width: 100%; }
  .alert-stats-grid .alert-stat { width: 100%; }
  .infra-grid > .mini-card, .cloud-grid > .mini-card { width: 100%; }
  .header-right { flex-direction: column; gap: 8px; align-items: flex-end; }
  .header-clock { font-size: 12px; }
  .dashboard-header { flex-direction: column; gap: 12px; }
  .header-left { flex-direction: column; text-align: center; }
  .carousel-arrow { display: none; }
}
</style>

<style>
/* 全局：禁止浏览器及父容器滚动条，由内部 el-scrollbar 接管滚动 */
html, body {
  overflow: hidden;
  height: 100%;
  margin: 0;
  padding: 0;
}
.el-main {
  overflow: hidden !important;
}

/* 监控大屏全屏模式(F11): 隐藏侧边栏/顶栏,去除主区域留白,完全铺满屏幕 */
body.-fullscreen {
  background: #050a1a;
}
body.-fullscreen .el-aside {
  display: none !important;
}
body.-fullscreen .el-header {
  display: none !important;
}
body.-fullscreen .el-main {
  padding: 0 !important;
  background: #050a1a !important;
}
body.-fullscreen .-carousel-wrapper .dashboard-header {
  margin: 0;
  border-radius: 0;
}
/* 全屏模式下顶栏/主区留白已移除,容器高度直接取满视口 */
body.-fullscreen .-carousel-wrapper {
  height: 100vh;
}
</style>

