/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：
 * @date： 2026/4/24 11:02
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026/4/24 11:02
 */
// import { serverIp } from '@/utils/publicData.js'
import { ref } from 'vue'
// 告警监控中心数据区

export const alarmMonitoringData = ref({
  unprocessed: {
    // 未处理告警
    totalCount: 0, // 待处理告警条数
    critical: 0, // 未处理严重告警条数
    assigned: 0, // 已分派严重告警条数
  },
  added: {
    today: 0, // 今日新增告警
    yesterday: 0, // 昨日新增告警
    week: 0, // 本周新增告警
    month: 0, // 本月新增告警
  },
  serious: {
    // 未处理严重告警
    count: 0, // 条数
    totalCritical: 0, // 新增严重告警总数
    recently: '', // 最近发生时间
    furthest: '', // 最远发生时间
  },
  completed: {
    // 已处理告警
    count: 0, // 总数
    average: 0, // 平均处理时长
    fastest: 0, // 最快处理时长
    slowest: 0, // 最慢处理时长
  },
  alertLevel: {
    // 告警级别统计
    total: 0, // 总数
    critical: 0, // 严重条数
    important: 0, // 重要条数
    general: 0, // 一般条数
    ordinary: 0, // 普通条数
  },
  classification: {
    // 告警分类统计
    network: 0, // 网络
    system: 0, // 系统
    cloud: 0, // 云平台
    database: 0, // 数据库
    NBU: 0, // NBU备份
    middleware: 0, // 中间件
    hardware: 0, // 硬件
    K8S: 0, // K8S
    applicationLink: 0, // 应用链路
    Hadoop: 0, // 大数据
  },
  status: {
    // 告警状态统计
    total: 0, // 总数
    unprocessed: 0, // 未处理
    assigned: 0, // 已分派
    completed: 0, // 已完成
  },
  alarmTrend: {
    // 告警趋势
    week: [],
    month: [],
    lastMonth: [],
  },
  handlerTime: {
    // 处理时长
    average: 0, // 平均时长
    fastest: 0, // 最快时长
    slowest: 0, // 最慢时长
    overtime: 0, // 超时未处理
  },
})

// ITSM 待办数据区
export const itsmTodoData = ref({
  publish: [], // 发布待办
  event: [], // 事件待办
  change: [], // 变更待办
  request: [], // 请求待办
  problem: [], // 问题待办
  orderStatistics: {
    // 工单统计
    week: {
      // 本周
      total: 0, // 总数
      completed: 0, // 已完成
      uncompleted: 0, // 待处理
      completionRate: 0, // 完成率
    },
    month: {
      // 本月
      total: 0, // 总数
      completed: 0, // 已完成
      uncompleted: 0, // 待处理
      completionRate: 0, // 完成率
    },
    all: {
      // 本周
      total: 0, // 总数
      completed: 0, // 已完成
      uncompleted: 0, // 待处理
      completionRate: 0, // 完成率
    },
  },
})

// 当日值班数据
// 结构：{ eccDay, eccNight, sysOps, netOps, pm } 分别存储各类值班人员姓名
export const eccDutyData = ref(null)
