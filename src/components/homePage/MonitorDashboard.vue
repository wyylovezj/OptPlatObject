<script setup>
/**
 * @author： 监控大屏
 * @desc： 运维监控大屏 - 实时监控数据展示
 * @date： 2026-06-16
 */
import { ref, onMounted, onUnmounted, nextTick, computed } from 'vue'
import { ElScrollbar } from 'element-plus'
import * as echarts from 'echarts'

// ==================== 静态模拟数据 ====================

// 告警监控数据
const alertData = ref({
  totalAlerts: 187,
  criticalAlerts: 23,
  warningAlerts: 56,
  infoAlerts: 108,
  todayNewAlerts: 12,
  trend: [45, 52, 38, 64, 58, 72, 65, 48, 55, 62, 70, 82, 76, 90, 85, 78, 92, 88, 95, 102, 98, 87, 93, 78],
})

// OA工单数据
const oaWorkOrderData = ref({
  pendingOrders: 45,
  processingOrders: 28,
  completedOrders: 156,
  todayNewOrders: 8,
  overtimeOrders: 3,
  weeklyStats: [32, 28, 35, 41, 38, 45, 42],
  categoryStats: [
    { name: '服务请求', value: 42 },
    { name: '事件处理', value: 28 },
    { name: '变更申请', value: 18 },
    { name: '问题管理', value: 12 },
  ],
})

// 主机监控数据
const hostData = ref({
  total: 156,
  online: 142,
  offline: 8,
  warning: 6,
  cpuUsage: 62.5,
  memoryUsage: 71.3,
  diskUsage: 55.8,
  cpuTop5: [
    { name: 'app-svr-01', cpu: 95.2, mem: 88.5 },
    { name: 'db-svr-03', cpu: 91.7, mem: 92.1 },
    { name: 'web-svr-05', cpu: 88.3, mem: 75.6 },
    { name: 'app-svr-07', cpu: 86.9, mem: 79.4 },
    { name: 'log-svr-02', cpu: 84.5, mem: 82.3 },
  ],
})

// 中间件监控
const middlewareData = ref({
  total: 68,
  normal: 62,
  abnormal: 6,
  types: [
    { name: 'Nginx', total: 18, abnormal: 2 },
    { name: 'Tomcat', total: 22, abnormal: 1 },
    { name: 'RabbitMQ', total: 8, abnormal: 0 },
    { name: 'Kafka', total: 6, abnormal: 1 },
    { name: 'ZooKeeper', total: 5, abnormal: 0 },
    { name: 'ElasticSearch', total: 9, abnormal: 2 },
  ],
})

// 数据库监控
const databaseData = ref({
  total: 42,
  normal: 38,
  abnormal: 4,
  connections: 356,
  slowQueries: 12,
  avgResponseTime: 23.5,
  types: [
    { name: 'MySQL', total: 18, abnormal: 2 },
    { name: 'Oracle', total: 12, abnormal: 1 },
    { name: 'Redis', total: 8, abnormal: 0 },
    { name: 'MongoDB', total: 4, abnormal: 1 },
  ],
})

// 缓存监控
const cacheData = ref({
  totalMemoryUsed: 68.5,
  hitRate: 95.2,
  missRate: 4.8,
  keysCount: 125680,
  avgTtl: 3600,
  throughput: [2300, 2450, 2180, 2560, 2780, 2650, 2890, 3020, 2950, 3100, 2850, 2680, 3200, 2980, 2750, 3100],
})

// 链路监控
const traceData = ref({
  totalTraces: 8560,
  errorTraces: 126,
  avgLatency: 156,
  p99Latency: 892,
  apdexScore: 0.94,
  services: 36,
  topSlowTraces: [
    { name: '订单服务', latency: 1250, calls: 3250 },
    { name: '支付服务', latency: 980, calls: 2180 },
    { name: '用户服务', latency: 720, calls: 4560 },
    { name: '库存服务', latency: 680, calls: 1890 },
  ],
})

// 网络流量监控
const networkTrafficData = ref({
  totalBandwidth: 20,
  usedBandwidth: 12.5,
  inbound: 5.8,
  outbound: 6.7,
  peakInbound: 8.2,
  peakOutbound: 9.5,
  trafficTrend: [3.2, 4.5, 5.8, 7.2, 8.5, 9.8, 10.2, 11.5, 12.8, 11.2, 10.5, 9.8, 8.5, 7.2, 6.8, 5.5, 6.2, 7.8, 8.5, 9.2, 10.5, 11.2, 10.8, 9.5],
  protocols: [
    { name: 'HTTP/HTTPS', value: 45 },
    { name: '数据库', value: 20 },
    { name: 'DNS', value: 12 },
    { name: 'SSH', value: 8 },
    { name: '其他', value: 15 },
  ],
})

// 网络设备监控
const networkDeviceData = ref({
  total: 85,
  online: 78,
  offline: 3,
  warning: 4,
  types: [
    { name: '交换机', total: 45, abnormal: 2 },
    { name: '路由器', total: 18, abnormal: 1 },
    { name: '防火墙', total: 12, abnormal: 0 },
    { name: '负载均衡', total: 10, abnormal: 1 },
  ],
  portStats: { total: 2560, used: 1830, free: 730, error: 8 },
})

// Docker容器监控
const dockerData = ref({
  total: 128,
  running: 115,
  stopped: 8,
  paused: 3,
  abnormal: 2,
  stats: [
    { name: '容器A-01', cpu: 35.2, mem: 42.5, status: 'running' },
    { name: '容器B-03', cpu: 68.7, mem: 55.3, status: 'running' },
    { name: '容器C-05', cpu: 92.1, mem: 88.6, status: 'warning' },
    { name: '容器D-02', cpu: 12.5, mem: 28.9, status: 'running' },
    { name: '容器E-04', cpu: 45.8, mem: 62.1, status: 'running' },
  ],
})

// K8s Pod监控
const k8sData = ref({
  totalPods: 256,
  runningPods: 238,
  pendingPods: 6,
  failedPods: 4,
  crashedPods: 8,
  nodes: 12,
  cpuUsage: 58.3,
  memoryUsage: 65.7,
  namespaces: [
    { name: 'production', pods: 120, cpu: 65.2, mem: 72.8 },
    { name: 'staging', pods: 48, cpu: 42.5, mem: 48.3 },
    { name: 'testing', pods: 56, cpu: 35.8, mem: 40.2 },
    { name: 'monitoring', pods: 32, cpu: 28.6, mem: 35.5 },
  ],
})

// URL监控
const urlData = ref({
  totalUrls: 86,
  available: 78,
  unavailable: 5,
  slow: 3,
  avgResponse: 325,
  uptime: 99.65,
  topSlow: [
    { name: 'https://api.example.com/order', response: 2850, status: 'slow' },
    { name: 'https://app.example.com/report', response: 1920, status: 'slow' },
    { name: 'https://web.example.com/search', response: 1560, status: 'slow' },
    { name: 'https://api.example.com/payment', response: 890, status: 'normal' },
    { name: 'https://app.example.com/login', response: 450, status: 'normal' },
  ],
})

// JVM监控
const jvmData = ref({
  heapUsed: 4.2,
  heapMax: 8,
  heapUsage: 52.5,
  nonHeapUsed: 256,
  gcCount: 1856,
  gcTime: 12.5,
  threadsCount: 256,
  daemonThreads: 38,
  classesLoaded: 5680,
  instances: [
    { name: 'gateway-service', heap: 68.5, gc: 2.5, threads: 48 },
    { name: 'user-service', heap: 52.3, gc: 1.8, threads: 36 },
    { name: 'order-service', heap: 75.6, gc: 3.2, threads: 52 },
    { name: 'payment-service', heap: 45.2, gc: 1.5, threads: 28 },
    { name: 'notification-service', heap: 38.9, gc: 1.2, threads: 22 },
  ],
})

// 应用日志监控
const logData = ref({
  totalLogs: 158600,
  errorLogs: 326,
  warnLogs: 1850,
  infoLogs: 156424,
  logsPerSec: 256,
  recentErrors: [
    { time: '09:45:23', level: 'ERROR', app: 'order-service', message: '数据库连接超时' },
    { time: '09:42:15', level: 'ERROR', app: 'payment-service', message: '支付接口调用失败' },
    { time: '09:38:56', level: 'WARN', app: 'user-service', message: '接口响应时间超过阈值' },
    { time: '09:35:12', level: 'ERROR', app: 'gateway-service', message: '路由转发失败' },
    { time: '09:32:44', level: 'WARN', app: 'order-service', message: '库存扣减重试' },
    { time: '09:28:30', level: 'ERROR', app: 'notification-service', message: '邮件发送失败' },
    { time: '09:25:18', level: 'WARN', app: 'app-svr-01', message: '磁盘使用率超过80%' },
  ],
})

// ==================== 模拟健康状态 ====================
const systemHealthItems = computed(() => [
  { label: '告警系统', status: alertData.value.criticalAlerts > 10 ? 'warning' : 'normal', value: alertData.value.criticalAlerts > 10 ? '告警较多' : '运行正常' },
  { label: 'OA工单', status: oaWorkOrderData.value.overtimeOrders > 0 ? 'warning' : 'normal', value: oaWorkOrderData.value.overtimeOrders > 0 ? `${oaWorkOrderData.value.overtimeOrders}个超时` : '运行正常' },
  { label: '主机系统', status: hostData.value.warning > 0 ? 'warning' : 'normal', value: hostData.value.warning > 0 ? `${hostData.value.warning}台异常` : '运行正常' },
  { label: '中间件', status: middlewareData.value.abnormal > 0 ? 'warning' : 'normal', value: middlewareData.value.abnormal > 0 ? `${middlewareData.value.abnormal}个异常` : '运行正常' },
  { label: '数据库', status: databaseData.value.abnormal > 0 ? 'warning' : 'normal', value: databaseData.value.abnormal > 0 ? `${databaseData.value.abnormal}个异常` : '运行正常' },
  { label: '缓存系统', status: cacheData.value.hitRate > 90 ? 'normal' : 'warning', value: `命中率${cacheData.value.hitRate}%` },
  { label: '链路追踪', status: traceData.value.apdexScore > 0.9 ? 'normal' : 'warning', value: `Apdex ${traceData.value.apdexScore}` },
  { label: '网络流量', status: networkTrafficData.value.usedBandwidth / networkTrafficData.value.totalBandwidth > 0.8 ? 'warning' : 'normal', value: `${networkTrafficData.value.usedBandwidth}Gbps` },
  { label: '网络设备', status: networkDeviceData.value.warning > 0 ? 'warning' : 'normal', value: networkDeviceData.value.warning > 0 ? `${networkDeviceData.value.warning}台异常` : '运行正常' },
  { label: 'Docker', status: dockerData.value.abnormal > 0 ? 'warning' : 'normal', value: dockerData.value.abnormal > 0 ? `${dockerData.value.abnormal}个异常` : '运行正常' },
  { label: 'K8s', status: k8sData.value.failedPods > 0 ? 'warning' : 'normal', value: k8sData.value.failedPods > 0 ? `${k8sData.value.failedPods + k8sData.value.crashedPods}个异常` : '运行正常' },
  { label: 'URL监控', status: urlData.value.unavailable > 0 ? 'error' : 'normal', value: urlData.value.unavailable > 0 ? `${urlData.value.unavailable}个不可达` : `可用率${urlData.value.uptime}%` },
  { label: 'JVM', status: jvmData.value.heapUsage > 80 ? 'warning' : 'normal', value: `堆使用${jvmData.value.heapUsage}%` },
  { label: '应用日志', status: logData.value.errorLogs > 100 ? 'warning' : 'normal', value: `${logData.value.errorLogs}个错误` },
])

// ==================== 当前时间 ====================
const currentTime = ref('')
const currentDate = ref('')
const updateTime = () => {
  const now = new Date()
  currentTime.value = now.toLocaleTimeString('zh-CN', { hour12: false })
  currentDate.value = now.toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })
}

// ==================== ECharts 图表 ====================
let charts = {}

const initCharts = () => {
  nextTick(() => {
    initAlertTrendChart()
    initOaCategoryChart()
    initCacheThroughputChart()
    initNetworkTrafficChart()
    initDockerCpuChart()
  })
}

const initAlertTrendChart = () => {
  const el = document.getElementById('chart-alert-trend')
  if (!el) return
  const chart = echarts.init(el)
  charts.alertTrend = chart
  chart.setOption({
    tooltip: { trigger: 'axis', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#1a6bff', textStyle: { color: '#e0e6ed' } },
    grid: { top: 20, right: 20, bottom: 25, left: 45 },
    xAxis: { type: 'category', data: Array.from({ length: 24 }, (_, i) => `${i}:00`), axisLabel: { color: '#7b8ca8', fontSize: 10 }, axisLine: { lineStyle: { color: '#1a2a4a' } }, axisTick: { show: false } },
    yAxis: { type: 'value', splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10 } },
    series: [{
      name: '告警数', type: 'line', smooth: true, symbol: 'none', lineStyle: { color: '#ff4757', width: 2, shadowBlur: 8, shadowColor: 'rgba(255,71,87,0.4)' },
      areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(255,71,87,0.3)' }, { offset: 1, color: 'rgba(255,71,87,0.02)' }]) },
      data: alertData.value.trend,
    }],
  })
}

const initOaCategoryChart = () => {
  const el = document.getElementById('chart-oa-category')
  if (!el) return
  const chart = echarts.init(el)
  charts.oaCategory = chart
  chart.setOption({
    tooltip: { trigger: 'item', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#00d4ff', textStyle: { color: '#e0e6ed' } },
    series: [{
      type: 'pie', radius: ['40%', '70%'], center: ['50%', '50%'],
      label: { color: '#a8b8d0', fontSize: 11, formatter: '{b}\n{d}%' },
      labelLine: { lineStyle: { color: '#2a3a5a' } },
      itemStyle: { borderRadius: 4, borderColor: '#0a142d', borderWidth: 2 },
      data: oaWorkOrderData.value.categoryStats.map((item, index) => ({
        ...item,
        itemStyle: { color: ['#00d4ff', '#6b7dff', '#ff6b6b', '#ffd93d'][index] },
      })),
    }],
  })
}

const initCacheThroughputChart = () => {
  const el = document.getElementById('chart-cache-throughput')
  if (!el) return
  const chart = echarts.init(el)
  charts.cacheThroughput = chart
  chart.setOption({
    tooltip: { trigger: 'axis', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#00d4ff', textStyle: { color: '#e0e6ed' } },
    grid: { top: 20, right: 20, bottom: 25, left: 45 },
    xAxis: { type: 'category', data: Array.from({ length: 16 }, (_, i) => `${i * 90}s`), axisLabel: { color: '#7b8ca8', fontSize: 10 }, axisLine: { lineStyle: { color: '#1a2a4a' } } },
    yAxis: { type: 'value', splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10 } },
    series: [{
      type: 'bar', barWidth: '60%', itemStyle: {
        borderRadius: [4, 4, 0, 0],
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: '#00d4ff' }, { offset: 1, color: '#0066cc' }]),
      },
      data: cacheData.value.throughput,
    }],
  })
}

const initNetworkTrafficChart = () => {
  const el = document.getElementById('chart-network-traffic')
  if (!el) return
  const chart = echarts.init(el)
  charts.networkTraffic = chart
  const inboundData = networkTrafficData.value.trafficTrend.map(v => (v * 0.45).toFixed(1))
  const outboundData = networkTrafficData.value.trafficTrend.map(v => (v * 0.55).toFixed(1))
  chart.setOption({
    tooltip: { trigger: 'axis', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#6b7dff', textStyle: { color: '#e0e6ed' } },
    legend: { data: ['入站流量', '出站流量'], textStyle: { color: '#a8b8d0', fontSize: 11 }, top: 0, right: 0 },
    grid: { top: 35, right: 20, bottom: 25, left: 45 },
    xAxis: { type: 'category', data: Array.from({ length: 24 }, (_, i) => `${i}:00`), axisLabel: { color: '#7b8ca8', fontSize: 10 }, axisLine: { lineStyle: { color: '#1a2a4a' } } },
    yAxis: { type: 'value', name: 'Gbps', nameTextStyle: { color: '#7b8ca8', fontSize: 10 }, splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10 } },
    series: [
      { name: '入站流量', type: 'line', smooth: true, symbol: 'none', lineStyle: { color: '#00d4ff', width: 2 }, data: inboundData.map(Number) },
      { name: '出站流量', type: 'line', smooth: true, symbol: 'none', lineStyle: { color: '#6b7dff', width: 2 }, data: outboundData.map(Number) },
    ],
  })
}

const initDockerCpuChart = () => {
  const el = document.getElementById('chart-docker-cpu')
  if (!el) return
  const chart = echarts.init(el)
  charts.dockerCpu = chart
  chart.setOption({
    tooltip: { trigger: 'axis', backgroundColor: 'rgba(10,20,45,0.9)', borderColor: '#ffd93d', textStyle: { color: '#e0e6ed' } },
    grid: { top: 20, right: 20, bottom: 65, left: 45 },
    xAxis: { type: 'category', data: dockerData.value.stats.map(s => s.name), axisLabel: { color: '#a8b8d0', fontSize: 10, rotate: 20 }, axisLine: { lineStyle: { color: '#1a2a4a' } } },
    yAxis: { type: 'value', max: 100, splitLine: { lineStyle: { color: '#1a2a4a', type: 'dashed' } }, axisLabel: { color: '#7b8ca8', fontSize: 10, formatter: '{value}%' } },
    series: [
      { name: 'CPU', type: 'bar', barWidth: '30%', itemStyle: { borderRadius: [4, 4, 0, 0], color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: '#ffd93d' }, { offset: 1, color: '#ff6b6b' }]) }, data: dockerData.value.stats.map(s => s.cpu) },
      { name: '内存', type: 'bar', barWidth: '30%', itemStyle: { borderRadius: [4, 4, 0, 0], color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: '#6b7dff' }, { offset: 1, color: '#00d4ff' }]) }, data: dockerData.value.stats.map(s => s.mem) },
    ],
  })
}

// ==================== 生命周期 ====================
let timeTimer = null

onMounted(() => {
  updateTime()
  timeTimer = setInterval(updateTime, 1000)
  setTimeout(initCharts, 100)
})

onUnmounted(() => {
  if (timeTimer) clearInterval(timeTimer)
  Object.values(charts).forEach(c => c && c.dispose())
  charts = {}
})

// ==================== 状态辅助 ====================
const statusIcon = (status) => {
  if (status === 'normal') return '●'
  if (status === 'warning') return '◆'
  return '▲'
}
const statusClass = (status) => {
  if (status === 'normal') return 'status-normal'
  if (status === 'warning') return 'status-warning'
  return 'status-error'
}
</script>

<template>
  <el-scrollbar class="monitor-scrollbar" view-class="monitor-viewport">
    <div class="monitor-dashboard">
    <!-- 顶部标题栏 -->
    <div class="dashboard-header">
      <div class="header-left">
        <div class="logo-icon">
          <svg viewBox="0 0 48 48" width="32" height="32">
            <circle cx="24" cy="24" r="20" fill="none" stroke="#00d4ff" stroke-width="2" stroke-dasharray="4 3"/>
            <circle cx="24" cy="24" r="10" fill="none" stroke="#00d4ff" stroke-width="2"/>
            <circle cx="24" cy="24" r="3" fill="#00d4ff"/>
            <line x1="24" y1="4" x2="24" y2="14" stroke="#00d4ff" stroke-width="1.5"/>
            <line x1="24" y1="34" x2="24" y2="44" stroke="#00d4ff" stroke-width="1.5"/>
            <line x1="4" y1="24" x2="14" y2="24" stroke="#00d4ff" stroke-width="1.5"/>
            <line x1="34" y1="24" x2="44" y2="24" stroke="#00d4ff" stroke-width="1.5"/>
          </svg>
        </div>
        <div class="header-title">
          <h1>运维监控大屏 · Real-Time Monitoring</h1>
          <span class="header-subtitle">智慧运维 · 全栈可观测</span>
        </div>
      </div>
      <div class="header-right">
        <div class="header-time">
          <div class="time-display">{{ currentTime }}</div>
          <div class="date-display">{{ currentDate }}</div>
        </div>
        <div class="header-status">
          <span class="live-dot"></span>
          <span>系统运行中</span>
        </div>
      </div>
    </div>

    <!-- 健康状态栏 -->
    <div class="health-bar">
      <div
        v-for="item in systemHealthItems"
        :key="item.label"
        class="health-item"
        :class="statusClass(item.status)"
      >
        <span class="health-icon">{{ statusIcon(item.status) }}</span>
        <span class="health-label">{{ item.label }}</span>
        <span class="health-value">{{ item.value }}</span>
      </div>
    </div>

    <!-- 核心指标卡片 -->
    <div class="metrics-grid">
      <!-- 告警监控 -->
      <div class="metric-card card-alert">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2L1 21h22M12 6l7.53 13H4.47M11 10v4h2v-4m-2 6v2h2v-2"/></svg>
          <span>告警监控</span>
        </div>
        <div class="card-body">
          <div class="metric-main">
            <div class="metric-number critical">{{ alertData.totalAlerts }}</div>
            <div class="metric-label">总告警数</div>
          </div>
          <div class="metric-details">
            <div class="detail-item">
              <span class="dot critical-dot"></span>
              <span>严重 {{ alertData.criticalAlerts }}</span>
            </div>
            <div class="detail-item">
              <span class="dot warning-dot"></span>
              <span>警告 {{ alertData.warningAlerts }}</span>
            </div>
            <div class="detail-item">
              <span class="dot info-dot"></span>
              <span>提示 {{ alertData.infoAlerts }}</span>
            </div>
          </div>
          <div class="metric-trend">
            <span class="trend-up">↑</span>
            <span>今日新增 {{ alertData.todayNewAlerts }}</span>
          </div>
        </div>
      </div>

      <!-- OA工单 -->
      <div class="metric-card card-oa">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2m-7 14l-5-5 1.41-1.41L12 14.17l4.59-4.58L18 11"/></svg>
          <span>OA工单</span>
        </div>
        <div class="card-body">
          <div class="metric-sub-grid">
            <div class="sub-metric">
              <div class="sub-number">{{ oaWorkOrderData.pendingOrders }}</div>
              <div class="sub-label">待处理</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number processing">{{ oaWorkOrderData.processingOrders }}</div>
              <div class="sub-label">处理中</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number success">{{ oaWorkOrderData.completedOrders }}</div>
              <div class="sub-label">已完成</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number danger" :class="{ blink: oaWorkOrderData.overtimeOrders > 0 }">{{ oaWorkOrderData.overtimeOrders }}</div>
              <div class="sub-label">超时</div>
            </div>
          </div>
          <div class="metric-trend">
            <span class="trend-up">↑</span>
            <span>今日新增 {{ oaWorkOrderData.todayNewOrders }}</span>
          </div>
        </div>
      </div>

      <!-- 主机监控 -->
      <div class="metric-card card-host">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M4 3h16a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1m1 2v14h14V5H5m2 2h10v2H7V7m0 4h10v2H7v-2m0 4h6v2H7v-2"/></svg>
          <span>主机监控</span>
        </div>
        <div class="card-body">
          <div class="metric-main">
            <div class="metric-number">{{ hostData.total }}</div>
            <div class="metric-label">总主机数</div>
          </div>
          <div class="metric-details">
            <div class="detail-item">
              <span class="dot success-dot"></span>
              <span>在线 {{ hostData.online }}</span>
            </div>
            <div class="detail-item">
              <span class="dot error-dot"></span>
              <span>离线 {{ hostData.offline }}</span>
            </div>
            <div class="detail-item">
              <span class="dot critical-dot"></span>
              <span>异常 {{ hostData.warning }}</span>
            </div>
          </div>
          <div class="progress-bar-group">
            <div class="progress-item">
              <span class="progress-label">CPU</span>
              <div class="progress-bar">
                <div class="progress-fill cpu-fill" :style="{ width: hostData.cpuUsage + '%' }"></div>
              </div>
              <span class="progress-value">{{ hostData.cpuUsage }}%</span>
            </div>
            <div class="progress-item">
              <span class="progress-label">内存</span>
              <div class="progress-bar">
                <div class="progress-fill mem-fill" :style="{ width: hostData.memoryUsage + '%' }"></div>
              </div>
              <span class="progress-value">{{ hostData.memoryUsage }}%</span>
            </div>
            <div class="progress-item">
              <span class="progress-label">磁盘</span>
              <div class="progress-bar">
                <div class="progress-fill disk-fill" :style="{ width: hostData.diskUsage + '%' }"></div>
              </div>
              <span class="progress-value">{{ hostData.diskUsage }}%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 数据库监控 -->
      <div class="metric-card card-db">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 3C7.58 3 4 4.79 4 7v10c0 2.21 3.58 4 8 4s8-1.79 8-4V7c0-2.21-3.58-4-8-4m0 2c3.87 0 6 1.5 6 2s-2.13 2-6 2-6-1.5-6-2 2.13-2 6-2M6 7.51c.88.49 2.51.99 4.5 1.19L12 9c1.33 0 4.5-.5 6-1.5V11c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 13c1.33 0 4.5-.5 6-1.5v3c0 .5-2.13 2-6 2s-6-1.5-6-2m0 4c.88.49 2.51 1 4.5 1.19L12 17c1.33 0 4.5-.5 6-1.5v2c0 .5-2.13 2-6 2s-6-1.5-6-2z"/></svg>
          <span>数据库</span>
        </div>
        <div class="card-body">
          <div class="metric-main">
            <div class="metric-number">{{ databaseData.total }}</div>
            <div class="metric-label">数据库实例</div>
          </div>
          <div class="metric-details">
            <div class="detail-item">
              <span class="dot success-dot"></span>
              <span>正常 {{ databaseData.normal }}</span>
            </div>
            <div class="detail-item">
              <span class="dot error-dot"></span>
              <span>异常 {{ databaseData.abnormal }}</span>
            </div>
          </div>
          <div class="db-stats">
            <div class="db-stat-item">
              <div class="db-stat-value">{{ databaseData.connections }}</div>
              <div class="db-stat-label">连接数</div>
            </div>
            <div class="db-stat-item">
              <div class="db-stat-value warning">{{ databaseData.slowQueries }}</div>
              <div class="db-stat-label">慢查询</div>
            </div>
            <div class="db-stat-item">
              <div class="db-stat-value">{{ databaseData.avgResponseTime }}ms</div>
              <div class="db-stat-label">平均响应</div>
            </div>
          </div>
        </div>
      </div>

      <!-- 中间件 -->
      <div class="metric-card card-mw">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M22 7v6H9V7h13M2 14v2h6v-2H2m0-7v2h6V7H2m10 7v2h10v-2H12m-10 7v2h6v-2H2m10 0v2h10v-2H12z"/></svg>
          <span>中间件</span>
        </div>
        <div class="card-body">
          <div class="metric-main">
            <div class="metric-number">{{ middlewareData.total }}</div>
            <div class="metric-label">中间件总数</div>
          </div>
          <div class="metric-details">
            <div class="detail-item">
              <span class="dot success-dot"></span>
              <span>正常 {{ middlewareData.normal }}</span>
            </div>
            <div class="detail-item">
              <span class="dot error-dot"></span>
              <span>异常 {{ middlewareData.abnormal }}</span>
            </div>
          </div>
          <div class="mw-list">
            <div v-for="mw in middlewareData.types" :key="mw.name" class="mw-item">
              <span class="mw-name">{{ mw.name }}</span>
              <span class="mw-count" :class="{ 'text-warning': mw.abnormal > 0 }">{{ mw.abnormal }}/{{ mw.total }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 缓存监控 -->
      <div class="metric-card card-cache">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M2 5.27L3.28 4 20 20.72 18.73 22l-1.46-1.46c-.34.29-.77.46-1.27.46H8a2 2 0 0 1-2-2V9.73L2 5.27M19 4v11.18l-2-2V6h-1.5v5.18L12.5 9.18V6h-1v4.68L8 7.18V4h11m-4 14c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2z"/></svg>
          <span>缓存监控</span>
        </div>
        <div class="card-body">
          <div class="cache-stats">
            <div class="cache-stat-item">
              <div class="cache-stat-circle hit-circle">
                <svg viewBox="0 0 36 36" width="60" height="60">
                  <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="#1a2a4a" stroke-width="3"/>
                  <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="#00d4ff" stroke-width="3" stroke-dasharray="95.2, 100" stroke-linecap="round"/>
                </svg>
                <div class="circle-text">{{ cacheData.hitRate }}%</div>
              </div>
              <div class="cache-stat-label">缓存命中率</div>
            </div>
            <div class="cache-info">
              <div class="cache-info-item">
                <span class="cache-info-label">内存使用</span>
                <span class="cache-info-value">{{ cacheData.totalMemoryUsed }}%</span>
              </div>
              <div class="cache-info-item">
                <span class="cache-info-label">Key数量</span>
                <span class="cache-info-value">{{ (cacheData.keysCount / 1000).toFixed(1) }}K</span>
              </div>
              <div class="cache-info-item">
                <span class="cache-info-label">平均TTL</span>
                <span class="cache-info-value">{{ cacheData.avgTtl }}s</span>
              </div>
              <div class="cache-info-item">
                <span class="cache-info-label">丢失率</span>
                <span class="cache-info-value warning">{{ cacheData.missRate }}%</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- K8s -->
      <div class="metric-card card-k8s">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2m0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3m0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/></svg>
          <span>K8s集群</span>
        </div>
        <div class="card-body">
          <div class="k8s-summary">
            <div class="k8s-summary-item">
              <div class="k8s-summary-num">{{ k8sData.totalPods }}</div>
              <div class="k8s-summary-label">Pods</div>
            </div>
            <div class="k8s-summary-item">
              <div class="k8s-summary-num">{{ k8sData.nodes }}</div>
              <div class="k8s-summary-label">Node</div>
            </div>
            <div class="k8s-summary-item">
              <div class="k8s-summary-num">
                <span class="text-success">{{ k8sData.runningPods }}</span>
                /{{ k8sData.totalPods }}
              </div>
              <div class="k8s-summary-label">运行中</div>
            </div>
            <div class="k8s-summary-item">
              <div class="k8s-summary-num text-danger">{{ k8sData.failedPods + k8sData.crashedPods }}</div>
              <div class="k8s-summary-label">异常</div>
            </div>
          </div>
          <div class="k8s-usage">
            <div class="progress-item">
              <span class="progress-label">CPU</span>
              <div class="progress-bar">
                <div class="progress-fill cpu-fill" :style="{ width: k8sData.cpuUsage + '%' }"></div>
              </div>
              <span class="progress-value">{{ k8sData.cpuUsage }}%</span>
            </div>
            <div class="progress-item">
              <span class="progress-label">内存</span>
              <div class="progress-bar">
                <div class="progress-fill mem-fill" :style="{ width: k8sData.memoryUsage + '%' }"></div>
              </div>
              <span class="progress-value">{{ k8sData.memoryUsage }}%</span>
            </div>
          </div>
          <div class="k8s-ns-list">
            <div v-for="ns in k8sData.namespaces" :key="ns.name" class="ns-item">
              <span class="ns-name">{{ ns.name }}</span>
              <span class="ns-stats">{{ ns.pods }}P · CPU {{ ns.cpu }}% · MEM {{ ns.mem }}%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Docker -->
      <div class="metric-card card-docker">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M20 10c-.5 0-1 .2-1.4.5l-.5-.5C17.7 9.6 17 9 16 9c-.5 0-1 .2-1.4.5l-.5-.5C13.7 8.6 13 8 12 8c-.5 0-1 .2-1.4.5L10 8c-.7-.7-1.6-1-2.5-1C5 7 3 9 3 11.5V13h16c1.1 0 2-.9 2-2s-.9-1-1-1M3 16h2v3H3m3 0h2v-3H6m3 0h2v3H9m3 0h2v-3h-2m3 0h2v3h-2m3 0h2v-3h-2z"/></svg>
          <span>Docker</span>
        </div>
        <div class="card-body">
          <div class="metric-sub-grid">
            <div class="sub-metric">
              <div class="sub-number success">{{ dockerData.running }}</div>
              <div class="sub-label">运行中</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number">{{ dockerData.stopped }}</div>
              <div class="sub-label">已停止</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number">{{ dockerData.paused }}</div>
              <div class="sub-label">已暂停</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number danger">{{ dockerData.abnormal }}</div>
              <div class="sub-label">异常</div>
            </div>
          </div>
          <div class="chart-mini-container" id="chart-docker-cpu"></div>
        </div>
      </div>

      <!-- 网络流量 -->
      <div class="metric-card card-network">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M15 9h-5v6h5V9m-4 .5h3v5h-3v-5m0-7.5c-5 0-9 4-9 9s4 9 9 9 9-4 9-9-4-9-9-9m0 16c-3.9 0-7-3.1-7-7s3.1-7 7-7 7 3.1 7 7-3.1 7-7 7z"/></svg>
          <span>网络流量</span>
        </div>
        <div class="card-body">
          <div class="net-summary">
            <div class="net-summary-item">
              <div class="net-value">{{ networkTrafficData.usedBandwidth }}<span class="net-unit">Gbps</span></div>
              <div class="net-label">当前流量 / {{ networkTrafficData.totalBandwidth }}Gbps</div>
            </div>
            <div class="net-peak">
              <div class="net-peak-item">
                <span class="peak-label">入站峰值</span>
                <span class="peak-value">{{ networkTrafficData.peakInbound }}G</span>
              </div>
              <div class="net-peak-item">
                <span class="peak-label">出站峰值</span>
                <span class="peak-value">{{ networkTrafficData.peakOutbound }}G</span>
              </div>
            </div>
          </div>
          <div class="chart-mini-container" id="chart-network-traffic"></div>
        </div>
      </div>

      <!-- 网络设备 -->
      <div class="metric-card card-netdev">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2M4 12c0-4.42 3.58-8 8-8 1.42 0 2.78.37 3.95 1.03L5.03 15.95C4.37 14.78 4 13.42 4 12m8 8c-1.42 0-2.78-.37-3.95-1.03L18.97 8.05C19.63 9.22 20 10.58 20 12c0 4.42-3.58 8-8 8z"/></svg>
          <span>网络设备</span>
        </div>
        <div class="card-body">
          <div class="metric-main">
            <div class="metric-number">{{ networkDeviceData.total }}</div>
            <div class="metric-label">设备总数</div>
          </div>
          <div class="metric-details">
            <div class="detail-item">
              <span class="dot success-dot"></span>
              <span>在线 {{ networkDeviceData.online }}</span>
            </div>
            <div class="detail-item">
              <span class="dot error-dot"></span>
              <span>离线 {{ networkDeviceData.offline }}</span>
            </div>
            <div class="detail-item">
              <span class="dot critical-dot"></span>
              <span>异常 {{ networkDeviceData.warning }}</span>
            </div>
          </div>
          <div class="port-stats">
            <div class="port-stat">
              <span class="port-label">端口总数</span>
              <span class="port-value">{{ networkDeviceData.portStats.total }}</span>
            </div>
            <div class="port-stat">
              <span class="port-label">已使用</span>
              <span class="port-value text-success">{{ networkDeviceData.portStats.used }}</span>
            </div>
            <div class="port-stat">
              <span class="port-label">空闲</span>
              <span class="port-value">{{ networkDeviceData.portStats.free }}</span>
            </div>
            <div class="port-stat">
              <span class="port-label">错误</span>
              <span class="port-value text-danger">{{ networkDeviceData.portStats.error }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 链路追踪 -->
      <div class="metric-card card-trace">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M3.5 18.5L9 13l4 4 7.5-7.5L22 11V3h-8l2.5 2.5L13 11l-4-4L2 17l1.5 1.5z"/></svg>
          <span>链路追踪</span>
        </div>
        <div class="card-body">
          <div class="trace-summary">
            <div class="trace-stat">
              <div class="trace-value">{{ (traceData.totalTraces / 1000).toFixed(1) }}K</div>
              <div class="trace-label">调用总量</div>
            </div>
            <div class="trace-stat">
              <div class="trace-value danger">{{ traceData.errorTraces }}</div>
              <div class="trace-label">错误链路</div>
            </div>
            <div class="trace-stat">
              <div class="trace-value">{{ traceData.avgLatency }}ms</div>
              <div class="trace-label">平均延迟</div>
            </div>
            <div class="trace-stat">
              <div class="trace-value warning">{{ traceData.p99Latency }}ms</div>
              <div class="trace-label">P99延迟</div>
            </div>
          </div>
          <div class="apdex-bar">
            <div class="apdex-label">Apdex满意度</div>
            <div class="progress-bar">
              <div class="progress-fill mem-fill" :style="{ width: traceData.apdexScore * 100 + '%' }"></div>
            </div>
            <div class="apdex-value">{{ traceData.apdexScore }}</div>
          </div>
          <div class="trace-services">
            <div v-for="svc in traceData.topSlowTraces" :key="svc.name" class="trace-svc-item">
              <span class="svc-name">{{ svc.name }}</span>
              <span class="svc-latency">{{ svc.latency }}ms</span>
            </div>
          </div>
        </div>
      </div>

      <!-- URL监控 -->
      <div class="metric-card card-url">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2m-5.15 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 0 1-4.33 3.56M14.34 14H9.66c-.1-.66-.16-1.32-.16-2 0-.68.06-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2M12 19.96c-.83-1.2-1.5-2.53-1.91-3.96h3.82c-.41 1.43-1.08 2.76-1.91 3.96M8 8H5.08A7.923 7.923 0 0 1 9.4 4.44C8.8 5.55 8.35 6.75 8 8m-2.92 8H8c.35 1.25.8 2.45 1.4 3.56A8.008 8.008 0 0 1 5.08 16m-.82-2C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2M12 4.04c.83 1.2 1.5 2.54 1.91 3.96h-3.82c.41-1.42 1.08-2.76 1.91-3.96M18.92 8h-2.95a15.65 15.65 0 0 0-1.38-3.56c1.84.63 3.37 1.9 4.33 3.56M12 2C6.47 2 2 6.5 2 12s4.47 10 10 10 10-4.5 10-10S17.53 2 12 2z"/></svg>
          <span>URL监控</span>
        </div>
        <div class="card-body">
          <div class="metric-sub-grid">
            <div class="sub-metric">
              <div class="sub-number success">{{ urlData.available }}</div>
              <div class="sub-label">可用</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number danger">{{ urlData.unavailable }}</div>
              <div class="sub-label">不可达</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number warning">{{ urlData.slow }}</div>
              <div class="sub-label">慢响应</div>
            </div>
            <div class="sub-metric">
              <div class="sub-number">{{ urlData.uptime }}%</div>
              <div class="sub-label">可用率</div>
            </div>
          </div>
          <div class="url-avg">
            <span>平均响应时间</span>
            <span class="avg-value">{{ urlData.avgResponse }}<small>ms</small></span>
          </div>
          <div class="url-list">
            <div v-for="url in urlData.topSlow.slice(0, 4)" :key="url.name" class="url-item" :class="url.status">
              <div class="url-name" :title="url.name">{{ url.name }}</div>
              <div class="url-response">{{ url.response }}ms</div>
            </div>
          </div>
        </div>
      </div>

      <!-- JVM监控 -->
      <div class="metric-card card-jvm">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2m-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93m6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
          <span>JVM监控</span>
        </div>
        <div class="card-body">
          <div class="jvm-heap">
            <div class="jvm-heap-info">
              <span class="heap-label">堆内存使用</span>
              <span class="heap-value">{{ jvmData.heapUsed }}GB / {{ jvmData.heapMax }}GB</span>
            </div>
            <div class="progress-bar">
              <div class="progress-fill cpu-fill" :style="{ width: jvmData.heapUsage + '%' }"></div>
            </div>
          </div>
          <div class="jvm-stats">
            <div class="jvm-stat">
              <span class="jvm-stat-label">GC次数</span>
              <span class="jvm-stat-value">{{ jvmData.gcCount }}</span>
            </div>
            <div class="jvm-stat">
              <span class="jvm-stat-label">GC耗时</span>
              <span class="jvm-stat-value">{{ jvmData.gcTime }}s</span>
            </div>
            <div class="jvm-stat">
              <span class="jvm-stat-label">线程数</span>
              <span class="jvm-stat-value">{{ jvmData.threadsCount }}</span>
            </div>
            <div class="jvm-stat">
              <span class="jvm-stat-label">类加载</span>
              <span class="jvm-stat-value">{{ jvmData.classesLoaded }}</span>
            </div>
          </div>
          <div class="jvm-instances">
            <div v-for="inst in jvmData.instances" :key="inst.name" class="jvm-instance-item">
              <span class="jvm-inst-name">{{ inst.name }}</span>
              <div class="jvm-inst-bar">
                <div class="jvm-inst-fill" :style="{ width: inst.heap + '%', background: inst.heap > 70 ? '#ff6b6b' : inst.heap > 50 ? '#ffd93d' : '#00d4ff' }"></div>
              </div>
              <span class="jvm-inst-value">{{ inst.heap }}%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 应用日志监控 -->
      <div class="metric-card card-log">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6m-1 7V3.5L18.5 9H13M6 20V4h5v7h7v9H6m2-2h8v-2H8v2m0-4h8v-2H8v2m0-4h5V8H8v2z"/></svg>
          <span>应用日志</span>
        </div>
        <div class="card-body">
          <div class="log-summary">
            <div class="log-stat">
              <div class="log-stat-value">{{ (logData.totalLogs / 1000).toFixed(1) }}K</div>
              <div class="log-stat-label">总量</div>
            </div>
            <div class="log-stat">
              <div class="log-stat-value danger">{{ logData.errorLogs }}</div>
              <div class="log-stat-label">错误</div>
            </div>
            <div class="log-stat">
              <div class="log-stat-value warning">{{ logData.warnLogs }}</div>
              <div class="log-stat-label">警告</div>
            </div>
            <div class="log-stat">
              <div class="log-stat-value">{{ logData.logsPerSec }}/s</div>
              <div class="log-stat-label">速率</div>
            </div>
          </div>
          <div class="log-list">
            <div v-for="(log, idx) in logData.recentErrors" :key="idx" class="log-item" :class="log.level.toLowerCase()">
              <span class="log-time">{{ log.time }}</span>
              <span class="log-level" :class="log.level.toLowerCase()">[{{ log.level }}]</span>
              <span class="log-app">{{ log.app }}</span>
              <span class="log-msg">{{ log.message }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 底部图表区域 -->
    <div class="charts-section">
      <div class="chart-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/></svg>
          <span>告警趋势 (24h)</span>
        </div>
        <div class="chart-container" id="chart-alert-trend"></div>
      </div>
      <div class="chart-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M21 8v12H3V8h18m0-2H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2m-10 9H8v2h3v2h2v-2h3v-2h-3v-2h-2v2m9-5H4v4h16V8z"/></svg>
          <span>工单分类统计</span>
        </div>
        <div class="chart-container" id="chart-oa-category"></div>
      </div>
      <div class="chart-card">
        <div class="card-header">
          <svg class="card-icon" viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M22 12l-4-4v3H3v2h15v3z"/></svg>
          <span>缓存吞吐量</span>
        </div>
        <div class="chart-container" id="chart-cache-throughput"></div>
      </div>
    </div>
    </div>
  </el-scrollbar>
</template>

<style scoped>
/* ==================== 全局 ==================== */
.monitor-scrollbar {
  height: 100%;
  background: radial-gradient(ellipse at 20% 50%, rgba(10, 30, 60, 0.8) 0%, #050a1a 100%);
}

.monitor-scrollbar :deep(.el-scrollbar__bar) {
  z-index: 100;
}

.monitor-scrollbar :deep(.el-scrollbar__thumb) {
  background: rgba(0, 212, 255, 0.3);
  border-radius: 4px;
}

.monitor-scrollbar :deep(.el-scrollbar__thumb:hover) {
  background: rgba(0, 212, 255, 0.5);
}

.monitor-dashboard {
  padding: 16px 20px;
  color: #e0e6ed;
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
}

/* ==================== 顶部标题栏 ==================== */
.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 24px;
  background: linear-gradient(135deg, rgba(15, 30, 60, 0.9), rgba(5, 15, 35, 0.9));
  border: 1px solid rgba(0, 212, 255, 0.15);
  border-radius: 12px;
  margin-bottom: 16px;
  box-shadow: 0 4px 30px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(0, 212, 255, 0.1);
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.logo-icon {
  animation: pulse-rotate 3s ease-in-out infinite;
}

@keyframes pulse-rotate {
  0%, 100% { transform: rotate(0deg) scale(1); opacity: 1; }
  50% { transform: rotate(180deg) scale(1.1); opacity: 0.8; }
}

.header-title h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 600;
  background: linear-gradient(90deg, #00d4ff, #6b7dff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: 2px;
}

.header-subtitle {
  font-size: 12px;
  color: #4a6a8a;
  letter-spacing: 4px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 24px;
}

.time-display {
  font-size: 28px;
  font-weight: 700;
  color: #00d4ff;
  font-family: 'Courier New', monospace;
  text-shadow: 0 0 10px rgba(0, 212, 255, 0.5);
}

.date-display {
  font-size: 13px;
  color: #7b8ca8;
  text-align: right;
  margin-top: 2px;
}

.header-status {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #7b8ca8;
}

.live-dot {
  width: 8px;
  height: 8px;
  background: #00ff88;
  border-radius: 50%;
  animation: blink 1.5s ease-in-out infinite;
  box-shadow: 0 0 6px rgba(0, 255, 136, 0.6);
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

/* ==================== 健康状态栏 ==================== */
.health-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 16px;
  padding: 10px 16px;
  background: rgba(10, 25, 50, 0.7);
  border: 1px solid rgba(0, 212, 255, 0.1);
  border-radius: 10px;
}

.health-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  border-radius: 6px;
  font-size: 12px;
  white-space: nowrap;
}

.health-icon { font-size: 10px; }
.health-label { color: #8a9bb5; }
.health-value { font-weight: 500; }

.health-item.status-normal {
  background: rgba(0, 255, 136, 0.08);
}
.health-item.status-normal .health-icon { color: #00ff88; }
.health-item.status-normal .health-value { color: #00ff88; }

.health-item.status-warning {
  background: rgba(255, 165, 2, 0.1);
}
.health-item.status-warning .health-icon { color: #ffa502; }
.health-item.status-warning .health-value { color: #ffa502; }

.health-item.status-error {
  background: rgba(255, 71, 87, 0.1);
}
.health-item.status-error .health-icon { color: #ff4757; }
.health-item.status-error .health-value { color: #ff4757; }

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
  font-size: 14px;
  font-weight: 600;
  color: #a8b8d0;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(0, 212, 255, 0.08);
}

.card-icon {
  color: #00d4ff;
  flex-shrink: 0;
}

.card-body { position: relative; }

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

.chart-card {
  background: linear-gradient(135deg, rgba(12, 28, 58, 0.85), rgba(6, 16, 35, 0.9));
  border: 1px solid rgba(0, 212, 255, 0.12);
  border-radius: 10px;
  padding: 14px 16px;
  box-shadow: 0 2px 20px rgba(0, 0, 0, 0.2);
  transition: all 0.3s ease;
}

.chart-card:hover {
  border-color: rgba(0, 212, 255, 0.35);
  box-shadow: 0 6px 30px rgba(0, 0, 0, 0.3);
}

.chart-container {
  width: 100%;
  height: 200px;
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
}

@media (max-width: 1200px) {
  .metrics-grid { grid-template-columns: repeat(2, 1fr); }
  .charts-section { grid-template-columns: repeat(2, 1fr); }
  .header-title h1 { font-size: 18px; }
}

@media (max-width: 768px) {
  .metrics-grid { grid-template-columns: 1fr; }
  .charts-section { grid-template-columns: 1fr; }
  .header-right { flex-direction: column; gap: 8px; align-items: flex-end; }
  .time-display { font-size: 22px; }
  .dashboard-header { flex-direction: column; gap: 12px; }
  .header-left { flex-direction: column; text-align: center; }
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
</style>
