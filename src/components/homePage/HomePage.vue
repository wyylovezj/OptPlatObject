<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：首页 - 告警数据统计展示（重新设计版）
 * @date： 2026-04-22
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-04-27
 */
import { alarmMonitoringData, itsmTodoData, eccDutyData } from '@/utils/homePageData.js'
import { ref, computed, onMounted, watch, nextTick, h ,onUnmounted } from 'vue'
import { Bell, Warning, CircleCheck, Clock, TrendCharts, Timer } from '@element-plus/icons-vue'
import { ElScrollbar, ElNotification, ElMessage } from 'element-plus'
import { useRouter, useRoute } from 'vue-router'
import * as echarts from 'echarts'
import {
  getAlertLevelData,
  getAlertClassData,
  getAlertStatusData,
  getAlertStatisticData,
  getAlertTrendData,
  getHandleTimeData,
} from '@/api/homePage.js'
import { getDuty,getEcc, getSys, getNet, getPM } from '@/api/dutyPageInterface.js'

// 计算环比变化
const totalChange = computed(() => {
  const yesterdayTotal = alarmMonitoringData.value.added.yesterday
  if (yesterdayTotal === 0) {
    return 0
  }
  const change = (((alarmMonitoringData.value.added.today - yesterdayTotal) / yesterdayTotal) * 100).toFixed(1)
  return parseFloat(change)
})

// 告警级别分布数据 - 4个级别
const alarmLevelData = computed(() => [
  {
    label: '严重',
    value: alarmMonitoringData.value.alertLevel.critical,
    rate:
      alarmMonitoringData.value.alertLevel.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.alertLevel.critical / alarmMonitoringData.value.alertLevel.total) * 100).toFixed(2)),
    color: '#ff4757',
    type: 'danger',
  },
  {
    label: '重要',
    value: alarmMonitoringData.value.alertLevel.important,
    rate:
      alarmMonitoringData.value.alertLevel.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.alertLevel.important / alarmMonitoringData.value.alertLevel.total) * 100).toFixed(2)),
    color: '#ffa502',
    type: 'warning',
  },
  {
    label: '一般',
    value: alarmMonitoringData.value.alertLevel.general,
    rate:
      alarmMonitoringData.value.alertLevel.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.alertLevel.general / alarmMonitoringData.value.alertLevel.total) * 100).toFixed(2)),
    color: '#2ed573',
    type: 'success',
  },
  {
    label: '普通',
    value: alarmMonitoringData.value.alertLevel.ordinary,
    rate:
      alarmMonitoringData.value.alertLevel.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.alertLevel.ordinary / alarmMonitoringData.value.alertLevel.total) * 100).toFixed(2)),
    color: '#1e90ff',
    type: 'primary',
  },
])

// 告警分类分布数据（用于ECharts饼图）
const alarmCategoryData = computed(() => [
  { name: '网络', value: alarmMonitoringData.value.classification.network },
  { name: '系统', value: alarmMonitoringData.value.classification.system },
  { name: '云平台', value: alarmMonitoringData.value.classification.cloud },
  { name: '数据库', value: alarmMonitoringData.value.classification.database },
  { name: 'NBU备份', value: alarmMonitoringData.value.classification.NBU },
  { name: '中间件', value: alarmMonitoringData.value.classification.middleware },
  { name: '硬件服务器', value: alarmMonitoringData.value.classification.hardware },
  { name: 'K8S', value: alarmMonitoringData.value.classification.K8S },
  { name: '应用链路', value: alarmMonitoringData.value.classification.applicationLink },
  { name: '大数据', value: alarmMonitoringData.value.classification.Hadoop },
])

// 告警状态分布
const alarmStatusData = computed(() => [
  {
    label: '未处理',
    value: alarmMonitoringData.value.status.unprocessed,
    rate:
      alarmMonitoringData.value.status.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.status.unprocessed / alarmMonitoringData.value.status.total) * 100).toFixed(2)),
    color: '#ff6348',
    type: 'danger',
  },
  {
    label: '已分派',
    value: alarmMonitoringData.value.status.assigned,
    rate:
      alarmMonitoringData.value.status.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.status.assigned / alarmMonitoringData.value.status.total) * 100).toFixed(2)),
    color: '#ffa502',
    type: 'warning',
  },
  {
    label: '已关闭',
    value: alarmMonitoringData.value.status.completed,
    rate:
      alarmMonitoringData.value.status.total === 0
        ? 0
        : Number(((alarmMonitoringData.value.status.completed / alarmMonitoringData.value.status.total) * 100).toFixed(2)),
    color: '#2ed573',
    type: 'success',
  },
])


// 当前激活的标签页
const activeTab = ref('request')

// 获取第一个有数据的tab页名称
const getFirstTabWithData = () => {
  const tabOrder = ['request','publish', 'event', 'change', 'problem']
  for (const tabName of tabOrder) {
    if (itsmTodoData.value[tabName] && itsmTodoData.value[tabName].length > 0) {
      return tabName
    }
  }
  // 如果所有tab都是空的，返回第一个tab（publish）
  return 'request'
}

// 在组件挂载时设置默认tab
onMounted(() => {
  // 先加载其他数据
  getLevelData()
  getStatisticData()
  getTrendData()
  loadEccDuty()

  // 设置默认tab为第一个有数据的tab
  activeTab.value = getFirstTabWithData()

  // 初始化日期显示
  const now = new Date()
  currentDateDisplay.value = now
    .toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })
    .replace(/(\d{4}年\d{1,2}月\d{1,2}日)(.+)/, '$1   $2')
  // 启动定时刷新任务，每60秒（1分钟）执行一次
  refreshTimer = setInterval(refreshAllData, 30000)

  // HomePage 挂载完成后，延迟触发待办检查（确保页面完全加载）
  setTimeout(() => {
    // 触发待办检查（通过自定义事件通知 App.vue）
    window.dispatchEvent(new CustomEvent('check-todos'))
    console.log('首页加载完成，触发待办检查')
  }, 500)

  // 延迟触发 lunar-javascript 更新提示
  setTimeout(() => {
    window.dispatchEvent(new CustomEvent('check-lunar-update'))
  }, 100)

  // 检测是否是登录成功后跳转，立刻显示成功提示
  if (route.query.loginSuccess === 'true') {
    ElMessage.success({
      message: '登录成功',
      duration: 2000,
    })
    // 使用 nextTick 确保在下一个 tick 才清除 URL 参数，避免与组件初始化冲突
    nextTick(() => {
      router.replace({ query: { ...route.query, loginSuccess: undefined } })
    })
  }

  console.log('首页数据加载完成')
})

// 获取当前标签页的工单列表
const currentTodoList = computed(() => {
  return itsmTodoData.value[activeTab.value] || []
})

// 获取各类型工单数量
const todoCounts = computed(() => ({
  publish: itsmTodoData.value.publish.length,
  event: itsmTodoData.value.event.length,
  change: itsmTodoData.value.change.length,
  request: itsmTodoData.value.request.length,
  problem: itsmTodoData.value.problem.length,
}))

// ITSM待办颜色映射
const tabColorMap = {
  publish: {
    primary: '#409eff',
    border: '#409eff',
    bg: 'linear-gradient(135deg, #e8f4ff 0%, #ffffff 100%)',
    bgLight: 'linear-gradient(135deg, #f0f7ff 0%, #ffffff 100%)',
    bgHover: 'linear-gradient(135deg, #d6ebff 0%, #ffffff 100%)',
    bgLightHover: 'linear-gradient(135deg, #e3f2ff 0%, #ffffff 100%)',
  },
  event: {
    primary: '#67c23a',
    border: '#67c23a',
    bg: 'linear-gradient(135deg, #eef7e8 0%, #ffffff 100%)',
    bgLight: 'linear-gradient(135deg, #f3faf0 0%, #ffffff 100%)',
    bgHover: 'linear-gradient(135deg, #dff0d6 0%, #ffffff 100%)',
    bgLightHover: 'linear-gradient(135deg, #e9f5e3 0%, #ffffff 100%)',
  },
  change: {
    primary: '#e6a23c',
    border: '#e6a23c',
    bg: 'linear-gradient(135deg, #fdf5e8 0%, #ffffff 100%)',
    bgLight: 'linear-gradient(135deg, #fef8f0 0%, #ffffff 100%)',
    bgHover: 'linear-gradient(135deg, #faefd6 0%, #ffffff 100%)',
    bgLightHover: 'linear-gradient(135deg, #fdf2e3 0%, #ffffff 100%)',
  },
  request: {
    primary: '#9c27b0',
    border: '#9c27b0',
    bg: 'linear-gradient(135deg, #f3e5f5 0%, #ffffff 100%)',
    bgLight: 'linear-gradient(135deg, #f8f0fa 0%, #ffffff 100%)',
    bgHover: 'linear-gradient(135deg, #e8d5f0 0%, #ffffff 100%)',
    bgLightHover: 'linear-gradient(135deg, #f0e3f5 0%, #ffffff 100%)',
  },
  problem: {
    primary: '#f56c6c',
    border: '#f56c6c',
    bg: 'linear-gradient(135deg, #fef0f0 0%, #ffffff 100%)',
    bgLight: 'linear-gradient(135deg, #fdf6f6 0%, #ffffff 100%)',
    bgHover: 'linear-gradient(135deg, #fde2e2 0%, #ffffff 100%)',
    bgLightHover: 'linear-gradient(135deg, #feeeee 0%, #ffffff 100%)',
  },
}

// 获取当前tab颜色
const getCurrentTabColor = computed(() => {
  return tabColorMap[activeTab.value] || tabColorMap.publish
})

// OA本周统计数据
// const oaWeekStats = ref({
//   total: 45,
//   completed: 38,
//   processing: 5,
//   pending: 2,
//   avgProcessTime: 1.8,
//   completionRate: 84.44,
// })

// // OA本月统计数据
// const oaMonthStats = ref({
//   total: 180,
//   completed: 152,
//   processing: 20,
//   pending: 8,
//   avgProcessTime: 2.1,
//   completionRate: 84.44,
// })
//
// // OA全部统计数据
// const oaAllStats = ref({
//   total: 1250,
//   completed: 1089,
//   processing: 120,
//   pending: 41,
//   avgProcessTime: 2.3,
//   completionRate: 87.12,
// })

// tabs激活状态
const statsActiveTab = ref('level')
const timingActiveTab = ref('trend')
// const workOrderActiveTab = ref('week')

// 当前日期显示
const currentDateDisplay = ref('')
// 定时刷新定时器
let refreshTimer = null
// 刷新所有数据
const refreshAllData =  () => {
  // 更新日期显示
  const now = new Date()
  currentDateDisplay.value = now
    .toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })
    .replace(/(\d{4}年\d{1,2}月\d{1,2}日)(.+)/, '$1   $2')

  // 调用所有接口更新数据
  getLevelData()
  getStatisticData()
  getTrendData()

  console.log('数据自动刷新完成 -', new Date().toLocaleTimeString())
}
// 格式化日期为 yyyy-mm-dd
const formatDate = (date) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

// 获取本周周一的日期
const getMondayOfThisWeek = () => {
  const today = new Date()
  const dayOfWeek = today.getDay() // 0是周日，1是周一
  const diff = dayOfWeek === 0 ? -6 : 1 - dayOfWeek // 计算到周一的差值
  const monday = new Date(today)
  monday.setDate(today.getDate() + diff)
  return monday
}
const getWeekTrendData = computed(() => {
  const monday = getMondayOfThisWeek()
  const today = new Date()
  const todayStr = `${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
  const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

  // 获取后端返回的本周趋势数据
  const weekTrendData = alarmMonitoringData.value.alarmTrend.week || []

  return weekDays.map((day, index) => {
    const currentDate = new Date(monday)
    currentDate.setDate(monday.getDate() + index)
    const month = String(currentDate.getMonth() + 1).padStart(2, '0')
    const days = String(currentDate.getDate()).padStart(2, '0')
    const dateStr = `${month}-${days}`

    // 根据索引从后端数据中获取对应的值，如果没有则为 0
    const count = weekTrendData[index] !== undefined ? weekTrendData[index] : 0

    return {
      day: dateStr === todayStr ? '今日' : dateStr,
      isToday: dateStr === todayStr,
      count: count,
    }
  })
})
// 获取本月周数据
const getMonthTrendData = computed(() => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)

  // 找到本月第一个周一（如果1号不是周一，则找到1号所在周的周一）
  const firstDayOfWeek = firstDay.getDay() // 0是周日，1是周一
  const diffToMonday = firstDayOfWeek === 0 ? -6 : 1 - firstDayOfWeek
  const firstMonday = new Date(firstDay)
  firstMonday.setDate(firstDay.getDate() + diffToMonday)

  // 从第一个周一开始，按日历周划分
  let currentWeekStart = new Date(firstMonday)
  const weeks = []
  let weekIndex = 1

  // 获取后端返回的本月趋势数据
  const monthTrendData = alarmMonitoringData.value.alarmTrend.month || []

  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(currentWeekStart.getDate() + 6)

    // 计算本周在本月的实际天数
    let actualDaysCount = 0
    let tempDate = new Date(currentWeekStart)

    // 逐天检查是否在本月范围内
    for (let i = 0; i < 7; i++) {
      if (tempDate >= firstDay && tempDate <= lastDay) {
        actualDaysCount++
      }
      tempDate.setDate(tempDate.getDate() + 1)
    }

    // 判断是否为本週（今天的日期在本周范围内）
    const isCurrentWeek = today >= currentWeekStart && today <= weekEnd

    // 只有当本周有在本月的天数时才添加
    if (actualDaysCount > 0) {
      // 根据 weekIndex 从后端数据中获取对应的值，如果没有则为 0
      const count = monthTrendData[weekIndex - 1] !== undefined ? monthTrendData[weekIndex - 1] : 0

      weeks.push({
        period: isCurrentWeek
          ? `本周(${actualDaysCount}天)`
          : `第${['一', '二', '三', '四', '五', '六'][weekIndex - 1] || weekIndex}周(${actualDaysCount}天)`,
        isCurrentWeek: isCurrentWeek,
        count: count,
      })
      weekIndex++
    }

    // 移动到下一周的起始日（下一个周一）
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }

  return weeks
})
// 获取上月周数据
const getLastMonthTrendData = computed(() => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth() - 1, 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth(), 0)

  // 找到上月第一个周一
  const firstDayOfWeek = firstDay.getDay()
  const diffToMonday = firstDayOfWeek === 0 ? -6 : 1 - firstDayOfWeek
  const firstMonday = new Date(firstDay)
  firstMonday.setDate(firstDay.getDate() + diffToMonday)

  // 从第一个周一开始，按日历周划分
  let currentWeekStart = new Date(firstMonday)
  const weeks = []
  let weekIndex = 1

  // 获取后端返回的上月趋势数据
  const lastMonthTrendData = alarmMonitoringData.value.alarmTrend.lastMonth || []

  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(currentWeekStart.getDate() + 6)

    // 计算本周在上月的实际天数
    let actualDaysCount = 0
    let tempDate = new Date(currentWeekStart)

    // 逐天检查是否在上月范围内
    for (let i = 0; i < 7; i++) {
      if (tempDate >= firstDay && tempDate <= lastDay) {
        actualDaysCount++
      }
      tempDate.setDate(tempDate.getDate() + 1)
    }

    // 只有当本周有在上月的天数时才添加
    if (actualDaysCount > 0) {
      // 根据 weekIndex 从后端数据中获取对应的值，如果没有则为 0
      const count = lastMonthTrendData[weekIndex - 1] !== undefined ? lastMonthTrendData[weekIndex - 1] : 0

      weeks.push({
        period: `第${['一', '二', '三', '四', '五', '六'][weekIndex - 1] || weekIndex}周(${actualDaysCount}天)`,
        isCurrentWeek: false,
        count: count,
      })
      weekIndex++
    }

    // 移动到下一周的起始日（下一个周一）
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }

  return weeks
})

// 计算不同时间范围的日期值
const todayValue = computed(() => getTodayRange())

// 告警统计时间范围选项配置
const alertTimeRangeOptions = {
  today: 'today',
  week: 'week',
  month: 'month',
  lastMonth: 'lastMonth',
}

// 获取今日的时间范围数组 [开始日期, 结束日期]
const getTodayRange = () => {
  const today = new Date()
  return [formatDate(today), formatDate(today)]
}

// 获取本周的时间范围数组 [周一日期, 今天日期]
const getThisWeekRange = () => {
  const monday = getMondayOfThisWeek()
  const today = new Date()
  return [formatDate(monday), formatDate(today)]
}

// 获取本月的时间范围数组 [本月第一天, 本月最后一天]
const getThisMonthRange = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)
  return [formatDate(firstDay), formatDate(lastDay)]
}

// 获取上月的时间范围数组 [上月第一天, 上月最后一天]
const getLastMonthRange = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth() - 1, 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth(), 0)
  return [formatDate(firstDay), formatDate(lastDay)]
}
// 告警统计时间范围选择器绑定的值
const alertTimeRangeSelect = ref(alertTimeRangeOptions.today)
// 监听告警统计时间范围变化，重新获取数据
const handleAlertTimeRangeChange = (value) => {
  alertTimeRange.value = getAlertTimeRangeByType(value)
  console.log('告警统计时间范围变更:', value, alertTimeRange.value)

  if (statsActiveTab.value === 'level') {
    getLevelData()
  } else if (statsActiveTab.value === 'category') {
    getClassData()
  } else if (statsActiveTab.value === 'status') {
    getStatusData()
  }
}
// 根据选择的类型获取对应的时间范围数组
const getAlertTimeRangeByType = (type) => {
  switch (type) {
    case alertTimeRangeOptions.today:
      return getTodayRange()
    case alertTimeRangeOptions.week:
      return getThisWeekRange()
    case alertTimeRangeOptions.month:
      return getThisMonthRange()
    case alertTimeRangeOptions.lastMonth:
      return getLastMonthRange()
    default:
      return getTodayRange()
  }
}
// 告警统计时间范围
const alertTimeRange = ref(todayValue.value)
// 获取本周的日期范围数组
const getWeekRange = () => {
  const monday = getMondayOfThisWeek()
  const today = new Date()
  return [formatDate(monday), formatDate(today)]
}

// 获取本月的周日期范围数组
const getMonthRanges = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)

  // 找到本月第一个周一
  const firstDayOfWeek = firstDay.getDay()
  const diffToMonday = firstDayOfWeek === 0 ? -6 : 1 - firstDayOfWeek
  const firstMonday = new Date(firstDay)
  firstMonday.setDate(firstDay.getDate() + diffToMonday)

  // 从第一个周一开始，按日历周划分
  let currentWeekStart = new Date(firstMonday)
  const ranges = []

  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(currentWeekStart.getDate() + 6)

    // 计算本周在本月的实际起始和结束日期
    let actualStart = null
    let actualEnd = null
    let tempDate = new Date(currentWeekStart)

    // 逐天检查，找到本周在本月的第一天和最后一天
    for (let i = 0; i < 7; i++) {
      if (tempDate >= firstDay && tempDate <= lastDay) {
        if (!actualStart) {
          actualStart = new Date(tempDate)
        }
        actualEnd = new Date(tempDate)
      }
      tempDate.setDate(tempDate.getDate() + 1)
    }

    // 只有当本周有在本月的天数时才添加
    if (actualStart && actualEnd) {
      ranges.push([formatDate(actualStart), formatDate(actualEnd)])
    }

    // 移动到下一周的起始日（下一个周一）
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }

  return ranges
}

// 获取上月的周日期范围数组
const getLastMonthRanges = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth() - 1, 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth(), 0)

  // 找到上月第一个周一
  const firstDayOfWeek = firstDay.getDay()
  const diffToMonday = firstDayOfWeek === 0 ? -6 : 1 - firstDayOfWeek
  const firstMonday = new Date(firstDay)
  firstMonday.setDate(firstDay.getDate() + diffToMonday)

  // 从第一个周一开始，按日历周划分
  let currentWeekStart = new Date(firstMonday)
  const ranges = []

  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(currentWeekStart.getDate() + 6)

    // 计算本周在上月的实际起始和结束日期
    let actualStart = null
    let actualEnd = null
    let tempDate = new Date(currentWeekStart)

    // 逐天检查，找到本周在上月的第一天和最后一天
    for (let i = 0; i < 7; i++) {
      if (tempDate >= firstDay && tempDate <= lastDay) {
        if (!actualStart) {
          actualStart = new Date(tempDate)
        }
        actualEnd = new Date(tempDate)
      }
      tempDate.setDate(tempDate.getDate() + 1)
    }

    // 只有当本周有在上月的天数时才添加
    if (actualStart && actualEnd) {
      ranges.push([formatDate(actualStart), formatDate(actualEnd)])
    }

    // 移动到下一周的起始日（下一个周一）
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }

  return ranges
}
// 告警分析时间范围选择器类型，0为本周，1为本月
const timeRangeSelect = ref('0')
// 告警分析时间范围
const timeRange = ref(getWeekRange())

// 获取本周的时间范围数组（用于处理时效）[周一日期, 今天日期]
const getThisWeekRangeForHandle = () => {
  const monday = getMondayOfThisWeek()
  const today = new Date()
  return [formatDate(monday), formatDate(today)]
}

// 获取本月的时间范围数组（用于处理时效）[本月1号, 今天]
const getThisMonthRangeForHandle = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  return [formatDate(firstDay), formatDate(today)]
}

// 获取上月的时间范围数组（用于处理时效）[上月1号, 上月最后一天]
const getLastMonthRangeForHandle = () => {
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth() - 1, 1)
  const lastDay = new Date(today.getFullYear(), today.getMonth(), 0)
  return [formatDate(firstDay), formatDate(lastDay)]
}
const handleTimeRange = ref(getThisWeekRangeForHandle())
// 监听时间范围选择变化
const handleTimeRangeChange = (value, tabPanel) => {
  if (value === '0') {
    timeRange.value = getWeekRange()
    handleTimeRange.value = getThisWeekRangeForHandle()
  } else if (value === '1') {
    timeRange.value = getMonthRanges()
    handleTimeRange.value = getThisMonthRangeForHandle()
  } else if (value === '2') {
    handleTimeRange.value = getLastMonthRangeForHandle()
    timeRange.value = getLastMonthRanges()
  }
  // 根据当前激活的tab页执行不同的函数
  if (tabPanel === 'trend') {
    getTrendData()
  } else if (tabPanel === 'time') {
    getHandTimeData()
  }
}

const getLevelData = async () => {
  const response = await getAlertLevelData(alertTimeRange.value)
  if (response.status === 'success') {
    alarmMonitoringData.value.alertLevel.total = response.total
    alarmMonitoringData.value.alertLevel.critical = response.critical
    alarmMonitoringData.value.alertLevel.important = response.important
    alarmMonitoringData.value.alertLevel.general = response.general
    alarmMonitoringData.value.alertLevel.ordinary = response.ordinary
  }
}
const getClassData = async () => {
  const response = await getAlertClassData(alertTimeRange.value)
  if (response.status === 'success') {
    alarmMonitoringData.value.classification.total = response.total
    alarmMonitoringData.value.classification.network = response.network
    alarmMonitoringData.value.classification.system = response.system
    alarmMonitoringData.value.classification.cloud = response.cloud
    alarmMonitoringData.value.classification.database = response.database
    alarmMonitoringData.value.classification.NBU = response.NBU
    alarmMonitoringData.value.classification.middleware = response.middleware
    alarmMonitoringData.value.classification.hardware = response.hardware
    alarmMonitoringData.value.classification.applicationLink = response.applicationLink
    alarmMonitoringData.value.classification.Hadoop = response.Hadoop
  }
}
const getStatusData = async () => {
  const response = await getAlertStatusData(alertTimeRange.value)
  if (response.status === 'success') {
    alarmMonitoringData.value.status.total = response.total
    alarmMonitoringData.value.status.unprocessed = response.unprocessed
    alarmMonitoringData.value.status.assigned = response.assigned
    alarmMonitoringData.value.status.completed = response.completed
  }
}
const getStatisticData = async () => {
  const response = await getAlertStatisticData()
  if (response.status === 'success') {
    alarmMonitoringData.value.unprocessed.totalCount = response.unprocessed.totalCount
    alarmMonitoringData.value.unprocessed.critical = response.unprocessed.critical
    alarmMonitoringData.value.unprocessed.assigned = response.unprocessed.assigned
    alarmMonitoringData.value.added.today = response.added.today
    alarmMonitoringData.value.added.yesterday = response.added.yesterday
    alarmMonitoringData.value.added.week = response.added.week
    alarmMonitoringData.value.added.month = response.added.month
    alarmMonitoringData.value.serious.count = response.serious.count
    alarmMonitoringData.value.serious.totalCritical = response.serious.totalCritical
    alarmMonitoringData.value.serious.recently = response.serious.recently
    alarmMonitoringData.value.serious.furthest = response.serious.furthest
    alarmMonitoringData.value.completed.count = response.completed.count
    alarmMonitoringData.value.completed.average = response.completed.average
    alarmMonitoringData.value.completed.fastest = response.completed.fastest
    alarmMonitoringData.value.completed.slowest = response.completed.slowest
  }
}
const getTrendData = async () => {
  console.log('当前时间范围:', timeRange.value)
  const response = await getAlertTrendData(timeRange.value, timeRangeSelect.value)
  if (response.status === 'success') {
    alarmMonitoringData.value.alarmTrend.week = response.week
    alarmMonitoringData.value.alarmTrend.month = response.month
    alarmMonitoringData.value.alarmTrend.lastMonth = response.lastMonth
    console.log('lastMonth', response.lastMonth)
  }
}

const getHandTimeData = async () => {
  const response = await getHandleTimeData(handleTimeRange.value)
  if (response.status === 'success') {
    alarmMonitoringData.value.handlerTime.average = response.average
    alarmMonitoringData.value.handlerTime.fastest = response.fastest
    alarmMonitoringData.value.handlerTime.slowest = response.slowest
    alarmMonitoringData.value.handlerTime.overtime = response.overtime
  }
}

// const getAllOrderData = async () => {
//   const username = sessionStorage.getItem('user')
//   const response = await getOrderData(username)
//   // 收集接口返回的所有待办项ID
//   if (response.status === 'success') {
//     // 收集接口返回的所有待办项ID
//     const newTodoIds = new Set()
//
//     // 遍历所有类型的待办项，收集ID
//     const allTodos = [
//       ...response.publish.map((item) => ({ ...item, type: '发布' })),
//       ...response.event.map((item) => ({ ...item, type: '事件' })),
//       ...response.change.map((item) => ({ ...item, type: '变更' })),
//       ...response.request.map((item) => ({ ...item, type: '请求' })),
//       ...response.problem.map((item) => ({ ...item, type: '问题' })),
//     ]
//
//     // 将新返回的ID添加到集合中
//     allTodos.forEach((todo) => {
//       newTodoIds.add(todo.id)
//     })
//
//     // 找出新增的待办项（在新集合中但不在旧集合中）
//     const newTodos = allTodos.filter((todo) => !todoIdSet.value.has(todo.id))
//
//     // 找出已移除的待办项（在旧集合中但不在新集合中）
//     const removedIds = [...todoIdSet.value].filter((id) => !newTodoIds.has(id))
//
//     // 如果有新增的待办项，发送通知
//     if (newTodos.length > 0) {
//       // 按类型分组统计
//       const typeGroups = {}
//       newTodos.forEach((todo) => {
//         if (!typeGroups[todo.type]) {
//           typeGroups[todo.type] = []
//         }
//         typeGroups[todo.type].push(todo.id)
//       })
//
//       const typeColors = {
//         '发布': { bg: '#ecf5ff', border: '#409eff', text: '#409eff' },
//         '事件': { bg: '#f0f9eb', border: '#67c23a', text: '#67c23a' },
//         '变更': { bg: '#fdf6ec', border: '#e6a23c', text: '#e6a23c' },
//         '请求': { bg: '#f3e5f5', border: '#9c27b0', text: '#9c27b0' },
//         '问题': { bg: '#fef0f0', border: '#f56c6c', text: '#f56c6c' }
//       }
//
//       // 使用 VNode 渲染通知内容
//       const notificationContent = h('div', { class: 'notification-content' }, [
//         // 标题部分
//         h('div', { class: 'notification-header' }, [
//           h('span', null, '🎯 共有 '),
//           h('span', {
//             style: { color: '#409eff', fontSize: '18px', fontWeight: '700' }
//           }, newTodos.length),
//           h('span', null, ' 条新待办')
//         ]),
//
//         // 滚动列表部分 - 使用 el-scrollbar
//         h(ElScrollbar, { maxHeight: '600px' }, {
//           default: () => h('div', { class: 'notification-list' },
//             Object.entries(typeGroups).map(([type, ids]) => {
//               const colors = typeColors[type] || { bg: '#f4f4f5', border: '#909399', text: '#909399' }
//               return h('div', {
//                 class: 'type-card',
//                 style: {
//                   marginBottom: '10px',
//                   padding: '10px 12px',
//                   background: colors.bg,
//                   borderLeft: `3px solid ${colors.border}`,
//                   borderRadius: '4px'
//                 }
//               }, [
//                 // 类型标题
//                 h('div', {
//                   style: {
//                     fontSize: '12px',
//                     color: colors.text,
//                     fontWeight: '600',
//                     marginBottom: '6px'
//                   }
//                 }, type),
//
//                 // ID 列表
//                 h('div', {
//                   style: {
//                     display: 'flex',
//                     flexDirection: 'column',
//                     gap: '4px'
//                   }
//                 }, ids.map(id =>
//                   h('div', {
//                     style: {
//                       fontSize: '13px',
//                       color: '#606266',
//                       paddingLeft: '8px',
//                       lineHeight: '1.6'
//                     }
//                   }, `• ${id}`)
//                 ))
//               ])
//             })
//           )
//         })
//       ])
//
//       const Notification = ElNotification({
//         title: '🔔 新待办提醒',
//         message: notificationContent,
//         type: 'primary',
//         duration: 2000,
//         position: 'top-right',
//         offset: 60,
//         customClass: 'custom-todo-notification',
//         showClose: false,
//         onClick: () => {
//           // 手动触发自定义关闭动画
//           const element = document.querySelector('.custom-todo-notification')
//           if (element) {
//             // 添加关闭动画类
//             element.classList.add('notification-closing')
//             // 等待动画完成后真正关闭
//             setTimeout(() => {
//               Notification.close()
//             }, 400)
//           } else {
//             Notification.close()
//           }
//         },
//         onClose: () => {
//           // 手动触发自定义关闭动画
//           const element = document.querySelector('.custom-todo-notification')
//           if (element) {
//             // 添加关闭动画类
//             element.classList.add('notification-closing')
//             // 等待动画完成后真正关闭
//             setTimeout(() => {
//               Notification.close()
//             }, 400)
//           }
//         }
//       })
//     }
//     // 更新Set：删除已移除的ID，添加新增的ID
//     removedIds.forEach((id) => todoIdSet.value.delete(id))
//     newTodoIds.forEach((id) => todoIdSet.value.add(id))
//     // 持久化到 localStorage
//     saveTodoIdsToStorage()
//
//     itsmTodoData.value.publish = response.publish
//     itsmTodoData.value.event = response.event
//     itsmTodoData.value.change = response.change
//     itsmTodoData.value.request = response.request
//     itsmTodoData.value.problem = response.problem
//   }
// }
// ECharts图表实例
let categoryChart = null

// 组件卸载时清理ECharts实例和定时器
onUnmounted(() => {
  // 销毁ECharts实例
  if (categoryChart) {
    categoryChart.dispose()
    categoryChart = null
  }

  // 清除定时刷新定时器
  if (refreshTimer) {
    clearInterval(refreshTimer)
    refreshTimer = null
  }

  console.log('HomePage组件已卸载，资源已清理')
})

// 格式化数字
const formatNumber = (num) => {
  return num.toLocaleString('zh-CN')
}

// 智能时间格式化函数：根据秒数自动选择合适的单位
const formatTimeDuration = (seconds) => {
  if (seconds === null || seconds === undefined || isNaN(seconds)) {
    return '0 秒'
  }

  if (seconds < 60) {
    // 小于60秒，显示秒
    const value = Number(seconds.toFixed(2))
    return `${value % 1 === 0 ? Math.round(value) : value.toFixed(2)} 秒`
  } else if (seconds < 3600) {
    // 60秒到3600秒之间，显示分钟
    const minutes = seconds / 60
    const value = Number(minutes.toFixed(2))
    return `${value % 1 === 0 ? Math.round(value) : value.toFixed(2)} 分钟`
  } else if (seconds < 86400) {
    // 3600秒到86400秒之间，显示小时
    const hours = seconds / 3600
    const value = Number(hours.toFixed(2))
    return `${value % 1 === 0 ? Math.round(value) : value.toFixed(2)} 小时`
  } else {
    // 大于等于86400秒，显示天
    const days = seconds / 86400
    const value = Number(days.toFixed(2))
    return `${value % 1 === 0 ? Math.round(value) : value.toFixed(2)} 天`
  }
}

// 待办工单点击跳转函数 - 打开外部链接
const handleTodoClick = (todo, type) => {

  // 根据工单类型构建不同的外部URL
  const urlMap = {
    request: `${todo.task_url}`,
    publish: `${todo.task_url}`,
    event: `${todo.task_url}`,
    change: `${todo.task_url}`,
    problem: `${todo.task_url}`
  }

  const targetUrl = urlMap[type]

  // 在新窗口打开外部链接
  window.open(targetUrl, '_blank')
}
// 路由实例
const router = useRouter()
const route = useRoute()
// 核心指标卡片点击跳转函数
const handleMetricCardClick = () => {
  const targetRoute = '/alarmManagement/alarmItem'
  router.push(targetRoute)
}
const categoryChartRef = ref(null)
// 初始化ECharts饼图
const initCategoryChart = () => {
  if (!categoryChartRef.value) return

  categoryChart = echarts.init(categoryChartRef.value)

  const option = {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      left: 'left',
      bottom: '0',
      itemGap: 2,
    },
    series: [
      {
        type: 'pie',
        top: '30',
        left:'80',
        radius: ['30%', '80%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: true,
          position: 'outside',
          formatter: '{b}\n{d}%',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
        },
        data: alarmCategoryData.value,
      },
    ],
  }

  categoryChart.setOption(option)
}

// 根据时间范围生成动态数据
const getDynamicTrendData = computed(() => {
  if (timeRangeSelect.value === '0') {
    return getWeekTrendData.value
  } else if (timeRangeSelect.value === '1') {
    return getMonthTrendData.value
  } else {
    return getLastMonthTrendData.value
  }
})
// 计算当前趋势数据的最大值
const currentMaxTrendValue = computed(() => {
  return Math.max(...getDynamicTrendData.value.map((item) => item.count))
})
// 监听tabs切换，重新渲染图表
watch(statsActiveTab, (newVal) => {
  if (newVal === 'category') {
    nextTick(() => {
      // 如果图表已存在，先销毁
      if (categoryChart) {
        categoryChart.dispose()
        categoryChart = null
      }
      initCategoryChart()
    })
  }
})
// 监听告警分类数据变化，更新饼图
watch(
  () => alarmCategoryData.value,
  (newData) => {
    if (categoryChart && statsActiveTab.value === 'category') {
      categoryChart.setOption({
        series: [
          {
            data: newData,
          },
        ],
      })
    }
  },
  { deep: true },
)
// 监听时间范围变化
watch(timeRange, () => {
  // 可以在这里添加其他逻辑
})

// 监听待办数据变化，自动切换到第一个有数据的tab
watch(
  () => itsmTodoData.value,
  (newData) => {
    // 只在当前tab没有数据时，才自动切换
    if (!newData[activeTab.value] || newData[activeTab.value].length === 0) {
      activeTab.value = getFirstTabWithData()
    }
  },
  { deep: true }
)

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
    refreshTimer = null
    console.log('定时刷新任务已清除')
  }
})

// 加载当日值班信息
const allDutyPersonnel = ref([])
const loadEccDuty = async () => {
  try {
    const today = new Date().toISOString().split('T')[0]
    const [result, ecc, sys, net, pm] = await Promise.all([
      getDuty([today, today]),
      getEcc(), getSys(), getNet(), getPM(),
    ])
    allDutyPersonnel.value = [
      ...(ecc || []).map(p => ({ ...p, category: 'ecc' })),
      ...(sys || []).map(p => ({ ...p, category: 'sys' })),
      ...(net || []).map(p => ({ ...p, category: 'net' })),
      ...(pm || []).map(p => ({ ...p, category: 'pm' })),
    ]
    if (result && Array.isArray(result) && result.length > 0) {
      const record = result[0]
      eccDutyData.value = {
        eccDay: record.eccDayPersonnelName || '',
        eccNight: record.eccNightPersonnelName || '',
        sysOps: record.sysOpsPersonnelName || '',
        netOps: record.netOpsPersonnelName || '',
        pm: record.pmPersonnelName || '',
      }
    }
  } catch (e) {
    console.error('加载值班信息失败:', e)
    eccDutyData.value = null
  }
}

const getDutyPhone = (name) => {
  if (!name || !allDutyPersonnel.value.length) return ''
  const p = allDutyPersonnel.value.find(item => item.name === name)
  return p ? (p.phone || p.mobile || '') : ''
}

</script>

<template>
  <div class="dashboard-container">
    <!-- 主内容区：左右3:1布局 -->
    <div class="main-content">
      <!-- 左侧面板 -->
      <div class="left-panel">
        <!-- 顶部欢迎区域 -->
        <div class="welcome-section">
          <div class="welcome-content">
            <h1 class="welcome-title">
              <el-icon :size="32"><TrendCharts /></el-icon>
              告警监控中心
            </h1>
            <p class="welcome-subtitle">实时掌握系统运行状态，快速响应异常情况</p>
          </div>
          <div class="time-badge">
            <el-icon :size="18"><Clock /></el-icon>
            <span class="time-text">{{ currentDateDisplay }}</span>
          </div>
        </div>

        <!-- 核心指标卡片 -->
        <div class="metrics-grid">
          <!-- 待处理告警（第一位） -->
          <div class="metric-card metric-warning"  @click="handleMetricCardClick">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Clock /></el-icon>
                </div>
                <div class="metric-pending-indicator">
                  <span class="pulse-dot"></span>
                  <span>进行中</span>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ alarmMonitoringData.unprocessed.totalCount }}</div>
                <div class="metric-label">待处理告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">严重</span>
                  <span class="detail-value danger-text">{{ alarmMonitoringData.unprocessed.critical }} 条</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">已分派</span>
                  <span class="detail-value">{{ alarmMonitoringData.unprocessed.assigned }} 条</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 今日新增告警（第二位） -->
          <div class="metric-card metric-primary" @click="handleMetricCardClick">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Bell /></el-icon>
                </div>
                <div class="metric-trend" :class="totalChange >= 0 ? 'trend-up' : 'trend-down'">
                  <span>较昨日</span>
                  <span class="trend-arrow"  :class="totalChange >= 0 ? 'arrow-danger' : 'arrow-success'">{{ totalChange >= 0 ? '↑' : '↓' }}</span>
                  <span :class="totalChange >= 0 ? 'trend-value-danger' : 'trend-value-success'">{{ Math.abs(totalChange) }} %</span>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ alarmMonitoringData.added.today }}</div>
                <div class="metric-label">今日新增告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">昨日新增</span>
                  <span class="detail-value">{{ alarmMonitoringData.added.yesterday }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">本周新增</span>
                  <span class="detail-value">{{ alarmMonitoringData.added.week }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">本月新增</span>
                  <span class="detail-value">{{ alarmMonitoringData.added.month }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 严重告警（第三位） -->
          <div class="metric-card metric-danger" @click="handleMetricCardClick">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Warning /></el-icon>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ alarmMonitoringData.serious.count }}</div>
                <div class="metric-label">严重告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">最近发生</span>
                  <span class="detail-value">{{ alarmMonitoringData.serious.recently }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">最远发生</span>
                  <span class="detail-value">{{ alarmMonitoringData.serious.furthest }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 已处理告警（第四位） -->
          <div class="metric-card metric-success" @click="handleMetricCardClick">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><CircleCheck /></el-icon>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ alarmMonitoringData.completed.count }}</div>
                <div class="metric-label">已处理告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">平均耗时</span>
                  <span class="detail-value">{{ formatTimeDuration(alarmMonitoringData.completed.average) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">最快处理</span>
                  <span class="detail-value">{{ formatTimeDuration(alarmMonitoringData.completed.fastest) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">最慢处理</span>
                  <span class="detail-value">{{ formatTimeDuration(alarmMonitoringData.completed.slowest) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 中间数据展示区：整合为两个卡片 -->
        <div class="data-showcase-integrated">
          <!-- 告警总数统计卡片 -->
          <div class="data-panel stats-panel">
            <div class="panel-header">
              <div class="panel-title">
                <span class="title-bar"></span>
                <h3>告警统计</h3>
              </div>
              <el-select
                v-model="alertTimeRangeSelect"
                size="small"
                style="width: 100px"
                @change="
                  () => {
                    handleAlertTimeRangeChange(alertTimeRangeSelect)
                    getStatisticData()
                    handleTimeRangeChange(timeRangeSelect, timingActiveTab)
                  }
                "
              >
                <el-option label="今日" :value="alertTimeRangeOptions.today" />
                <el-option label="本周" :value="alertTimeRangeOptions.week" />
                <el-option label="本月" :value="alertTimeRangeOptions.month" />
                <el-option label="上月" :value="alertTimeRangeOptions.lastMonth" />
              </el-select>
            </div>
            <div class="panel-body stats-body">
              <el-tabs
                v-model="statsActiveTab"
                class="stats-tabs"
                @tab-change="
                  (TabPaneName) => {
                    TabPaneName === 'level'
                      ? getLevelData()
                      : TabPaneName === 'category'
                        ? getClassData()
                        : TabPaneName === 'status'
                          ? getStatusData()
                          : null
                    getStatisticData()
                    handleTimeRangeChange(timeRangeSelect, timingActiveTab)
                  }
                "
              >
                <!-- 告警级别分布 -->
                <el-tab-pane name="level" label="按告警级别">
                  <div class="level-items">
                    <div
                      v-for="(level, index) in alarmLevelData"
                      :key="level.label"
                      class="level-item-modern"
                      :style="{ animationDelay: `${index * 0.1}s` }"
                    >
                      <div class="level-main">
                        <div class="level-info">
                          <span class="level-name">{{ level.label }}</span>
                          <el-tag :type="level.type"
                            ><span class="level-count-large">{{ formatNumber(level.value) }}</span></el-tag
                          >
                        </div>
                      </div>
                      <div class="level-progress-modern">
                        <div class="progress-track">
                          <div
                            class="progress-fill"
                            :style="{
                              width: level.rate + '%',
                              background: `linear-gradient(90deg, ${level.color}, ${level.color}dd)`,
                            }"
                          ></div>
                        </div>
                        <div style="font-size: 14px" class="progress-label">{{ level.rate }} %</div>
                      </div>
                    </div>
                  </div>
                </el-tab-pane>

                <!-- 告警分类分布 -->
                <el-tab-pane name="category" label="按告警分类">
                  <div ref="categoryChartRef" class="category-chart-container"></div>
                </el-tab-pane>

                <!-- 告警状态分布 -->
                <el-tab-pane name="status" label="按告警状态">
                  <div class="level-items">
                    <div
                      v-for="(status, index) in alarmStatusData"
                      :key="status.label"
                      class="level-item-modern"
                      :style="{ animationDelay: `${index * 0.1}s` }"
                    >
                      <div class="level-main">
                        <div class="level-info">
                          <span class="level-name">{{ status.label }}</span>
                          <el-tag :type="status.type"
                            ><span class="level-count-large">{{ formatNumber(status.value) }}</span></el-tag
                          >
                        </div>
                      </div>
                      <div class="level-progress-modern">
                        <div class="progress-track">
                          <div
                            class="progress-fill"
                            :style="{
                              width: status.rate + '%',
                              background: `linear-gradient(90deg, ${status.color}, ${status.color}dd)`,
                            }"
                          ></div>
                        </div>
                        <div class="progress-label">{{ status.rate }}%</div>
                      </div>
                    </div>
                  </div>
                </el-tab-pane>
              </el-tabs>
            </div>
          </div>

          <!-- 处理时效卡片 -->
          <div class="data-panel timing-panel">
            <div class="panel-header">
              <div class="panel-title">
                <span class="title-bar"></span>
                <h3>告警分析</h3>
              </div>
              <el-select
                v-model="timeRangeSelect"
                size="small"
                style="width: 100px"
                @change="
                  (value) => {
                    handleTimeRangeChange(value, timingActiveTab)
                    getStatisticData()
                    handleAlertTimeRangeChange(alertTimeRangeSelect)
                  }
                "
              >
                <el-option label="本周" value="0" />
                <el-option label="本月" value="1" />
                <el-option label="上月" value="2" />
              </el-select>
            </div>
            <div class="panel-body timing-body">
              <el-tabs
                v-model="timingActiveTab"
                class="timing-tabs"
                @tab-change="
                  (TabPaneName) => {
                    handleTimeRangeChange(timeRangeSelect, TabPaneName)
                    getStatisticData()
                    handleAlertTimeRangeChange(alertTimeRangeSelect)
                  }
                "
              >
                <!-- 告警趋势 -->
                <el-tab-pane name="trend" label="告警趋势">
                  <div class="trend-chart">
                    <div
                      v-for="(item, index) in getDynamicTrendData"
                      :key="`${timeRangeSelect}-${item.period || item.day}`"
                      class="trend-bar-wrapper"
                      :style="{ animationDelay: `${index * 0.08}s` }"
                    >
                      <div class="trend-bar-container">
                        <div
                          class="trend-bar"
                          :style="{
                            height: (item.count / currentMaxTrendValue) * 100 + '%',
                            background: `linear-gradient(180deg, #667eea 0%, #764ba2 100%)`,
                          }"
                        >
                          <div class="trend-bar-value">{{ item.count }}</div>
                        </div>
                      </div>
                      <div class="trend-bar-label" :class="{ 'today-highlight': item.isToday, 'current-week-highlight': item.isCurrentWeek }">
                        {{ item.period || item.day }}
                      </div>
                    </div>
                  </div>
                </el-tab-pane>

                <!-- 处理时间统计 -->
                <el-tab-pane name="time" label="处理时效">
                  <div class="time-stats-grid">
                    <div class="time-stat-card">
                      <div class="stat-icon avg">
                        <el-icon :size="24"><Timer /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">平均处理时长</div>
                        <div class="stat-value">{{ formatTimeDuration(alarmMonitoringData.handlerTime.average) }}</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon fast">
                        <el-icon :size="24"><Clock /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">最快处理</div>
                        <div class="stat-value">{{ formatTimeDuration(alarmMonitoringData.handlerTime.fastest) }}</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon slow">
                        <el-icon :size="24"><Clock /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">最慢处理</div>
                        <div class="stat-value">{{ formatTimeDuration(alarmMonitoringData.handlerTime.slowest) }}</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon overtime">
                        <el-icon :size="24"><Warning /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">超时未处理</div>
                        <div class="stat-value danger">{{ alarmMonitoringData.handlerTime.overtime }}</div>
                      </div>
                    </div>
                  </div>
                </el-tab-pane>
              </el-tabs>
            </div>
          </div>
        </div>
      </div>

      <!-- 右侧面板 -->
      <div class="right-panel">
        <!-- 值班卡片 -->
        <div class="oa-section ecc-duty-section">
          <div class="section-header">
            <div class="section-title">
              <svg class="icon" aria-hidden="true" style="width:18px;height:18px;color:#667eea">
                <use xlink:href="#icon-zhibanguanli"></use>
              </svg>
              <h2>今日值班</h2>
            </div>
          </div>
          <div class="ecc-duty-body">
            <div class="ecc-duty-row">
              <span class="ecc-shift-badge ecc-shift-day">白班</span>
              <span class="ecc-shift-label">ECC</span>
              <span class="ecc-shift-time">08:00 - 20:00</span>
              <span class="ecc-person-info">
                <span class="ecc-avatar" :class="{ 'ecc-avatar-empty': !eccDutyData?.eccDay }">{{ eccDutyData?.eccDay ? eccDutyData.eccDay.charAt(0) : '—' }}</span>
                <span class="ecc-person-name" :class="{ 'ecc-person-name-empty': !eccDutyData?.eccDay }">{{ eccDutyData?.eccDay || '未排班' }}</span>
              </span>
              <span class="ecc-person-phone">
                <svg class="ecc-phone-icon" viewBox="0 0 28 18" width="24" height="16"><text x="0" y="14" fill="currentColor" font-size="13" font-family="Arial,sans-serif" font-weight="bold">Tel</text></svg>
                {{ getDutyPhone(eccDutyData?.eccDay) || '-' }}
              </span>
            </div>
            <div class="ecc-duty-row">
              <span class="ecc-shift-badge ecc-shift-night">夜班</span>
              <span class="ecc-shift-label">ECC</span>
              <span class="ecc-shift-time">20:00 - 08:00</span>
              <span class="ecc-person-info">
                <span class="ecc-avatar" :class="{ 'ecc-avatar-empty': !eccDutyData?.eccNight }">{{ eccDutyData?.eccNight ? eccDutyData.eccNight.charAt(0) : '—' }}</span>
                <span class="ecc-person-name" :class="{ 'ecc-person-name-empty': !eccDutyData?.eccNight }">{{ eccDutyData?.eccNight || '未排班' }}</span>
              </span>
              <span class="ecc-person-phone">
                <svg class="ecc-phone-icon" viewBox="0 0 28 18" width="24" height="16"><text x="0" y="14" fill="currentColor" font-size="13" font-family="Arial,sans-serif" font-weight="bold">Tel</text></svg>
                {{ getDutyPhone(eccDutyData?.eccNight) || '-' }}
              </span>
            </div>
            <div class="ecc-duty-row">
              <span class="ecc-shift-badge ecc-shift-sys">白</span>
              <span class="ecc-shift-label">系统运维</span>
              <span class="ecc-shift-time">08:30 - 18:00</span>
              <span class="ecc-person-info">
                <span class="ecc-avatar" :class="{ 'ecc-avatar-empty': !eccDutyData?.sysOps }">{{ eccDutyData?.sysOps ? eccDutyData.sysOps.charAt(0) : '—' }}</span>
                <span class="ecc-person-name" :class="{ 'ecc-person-name-empty': !eccDutyData?.sysOps }">{{ eccDutyData?.sysOps || '未排班' }}</span>
              </span>
              <span class="ecc-person-phone">
                <svg class="ecc-phone-icon" viewBox="0 0 28 18" width="24" height="16"><text x="0" y="14" fill="currentColor" font-size="13" font-family="Arial,sans-serif" font-weight="bold">Tel</text></svg>
                {{ getDutyPhone(eccDutyData?.sysOps) || '-' }}
              </span>
            </div>
            <div class="ecc-duty-row">
              <span class="ecc-shift-badge ecc-shift-net">白</span>
              <span class="ecc-shift-label">网络运维</span>
              <span class="ecc-shift-time">08:30 - 18:00</span>
              <span class="ecc-person-info">
                <span class="ecc-avatar" :class="{ 'ecc-avatar-empty': !eccDutyData?.netOps }">{{ eccDutyData?.netOps ? eccDutyData.netOps.charAt(0) : '—' }}</span>
                <span class="ecc-person-name" :class="{ 'ecc-person-name-empty': !eccDutyData?.netOps }">{{ eccDutyData?.netOps || '未排班' }}</span>
              </span>
              <span class="ecc-person-phone">
                <svg class="ecc-phone-icon" viewBox="0 0 28 18" width="24" height="16"><text x="0" y="14" fill="currentColor" font-size="13" font-family="Arial,sans-serif" font-weight="bold">Tel</text></svg>
                {{ getDutyPhone(eccDutyData?.netOps) || '-' }}
              </span>
            </div>
            <div class="ecc-duty-row">
              <span class="ecc-shift-badge ecc-shift-pm">全</span>
              <span class="ecc-shift-label">甲方PM</span>
              <span class="ecc-shift-time">08:30 - 18:00</span>
              <span class="ecc-person-info">
                <span class="ecc-avatar" :class="{ 'ecc-avatar-empty': !eccDutyData?.pm }">{{ eccDutyData?.pm ? eccDutyData.pm.charAt(0) : '—' }}</span>
                <span class="ecc-person-name" :class="{ 'ecc-person-name-empty': !eccDutyData?.pm }">{{ eccDutyData?.pm || '未排班' }}</span>
              </span>
              <span class="ecc-person-phone">
                <svg class="ecc-phone-icon" viewBox="0 0 28 18" width="24" height="16"><text x="0" y="14" fill="currentColor" font-size="13" font-family="Arial,sans-serif" font-weight="bold">Tel</text></svg>
                {{ getDutyPhone(eccDutyData?.pm) || '-' }}
              </span>
            </div>
          </div>
        </div>

        <!-- 上半部分：实时待办工单（占2份） -->
        <div class="oa-section oa-todo-list">
          <div class="section-header">
            <div class="section-title">
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-daiban"></use>
              </svg>
              <h2>ITSM 待办</h2>
            </div>
          </div>
          <div class="section-body">
            <el-tabs v-model="activeTab" class="oa-tabs">
              <el-tab-pane name="request">
                <template #label>
                  <span class="tab-label">
                    请求
                    <el-tag size="small" class="request-tag" effect="plain">{{ todoCounts.request }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list todo-list-stacked">
                    <div
                      v-for="(todo, index) in currentTodoList"
                      :key="todo.id"
                      class="todo-item todo-item-stacked"
                      @click="handleTodoClick(todo, 'request')"
                      :style="{
                        zIndex: index + 1,
                        borderLeftColor: getCurrentTabColor.border,
                        '--card-primary-color': getCurrentTabColor.primary,
                        '--card-bg-color': getCurrentTabColor.bg,
                        '--card-bg-color-light': getCurrentTabColor.bgLight,
                        '--card-bg-color-hover': getCurrentTabColor.bgHover,
                        '--card-bg-color-light-hover': getCurrentTabColor.bgLightHover,
                      }"
                    >
                      <div class="todo-header">
                        <span class="todo-id" :style="{ color: getCurrentTabColor.primary }">{{ todo.id }}</span>
                        <el-tag type="primary" size="small">{{ '普通' }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" type="warning">
                          {{ '待处理' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无请求待办" :image-size="200" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>
              <el-tab-pane name="publish">
                <template #label>
                  <span class="tab-label">
                    发布
                    <el-tag size="small" type="primary" effect="plain">{{ todoCounts.publish }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list todo-list-stacked">
                    <div
                      v-for="(todo, index) in currentTodoList"
                      :key="todo.id"
                      class="todo-item todo-item-stacked"
                      @click="handleTodoClick(todo, 'publish')"
                      :style="{
                        zIndex: index + 1,
                        borderLeftColor: getCurrentTabColor.border,
                        '--card-primary-color': getCurrentTabColor.primary,
                        '--card-bg-color': getCurrentTabColor.bg,
                        '--card-bg-color-light': getCurrentTabColor.bgLight,
                        '--card-bg-color-hover': getCurrentTabColor.bgHover,
                        '--card-bg-color-light-hover': getCurrentTabColor.bgLightHover,
                      }"
                    >
                      <div class="todo-header">
                        <span class="todo-id" :style="{ color: getCurrentTabColor.primary }">{{ todo.id }}</span>
                        <el-tag type="primary" size="small">{{ '普通' }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" type="warning">
                          {{ '待处理' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无发布待办" :image-size="200" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>

              <el-tab-pane name="event">
                <template #label>
                  <span class="tab-label">
                    事件
                    <el-tag size="small" type="success" effect="plain">{{ todoCounts.event }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list todo-list-stacked">
                    <div
                      v-for="(todo, index) in currentTodoList"
                      :key="todo.id"
                      class="todo-item todo-item-stacked"
                      @click="handleTodoClick(todo, 'event')"
                      :style="{
                        zIndex: index + 1,
                        borderLeftColor: getCurrentTabColor.border,
                        '--card-primary-color': getCurrentTabColor.primary,
                        '--card-bg-color': getCurrentTabColor.bg,
                        '--card-bg-color-light': getCurrentTabColor.bgLight,
                        '--card-bg-color-hover': getCurrentTabColor.bgHover,
                        '--card-bg-color-light-hover': getCurrentTabColor.bgLightHover,
                      }"
                    >
                      <div class="todo-header">
                        <span class="todo-id" :style="{ color: getCurrentTabColor.primary }">{{ todo.id }}</span>
                        <el-tag type="primary" size="small">{{ '普通' }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" type="warning">
                          {{ '待处理' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无事件待办" :image-size="200" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>

              <el-tab-pane name="change">
                <template #label>
                  <span class="tab-label">
                    变更
                    <el-tag size="small" type="warning" effect="plain">{{ todoCounts.change }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list todo-list-stacked">
                    <div
                      v-for="(todo, index) in currentTodoList"
                      :key="todo.id"
                      class="todo-item todo-item-stacked"
                      @click="handleTodoClick(todo, 'change')"
                      :style="{
                        zIndex: index + 1,
                        borderLeftColor: getCurrentTabColor.border,
                        '--card-primary-color': getCurrentTabColor.primary,
                        '--card-bg-color': getCurrentTabColor.bg,
                        '--card-bg-color-light': getCurrentTabColor.bgLight,
                        '--card-bg-color-hover': getCurrentTabColor.bgHover,
                        '--card-bg-color-light-hover': getCurrentTabColor.bgLightHover,
                      }"
                    >
                      <div class="todo-header">
                        <span class="todo-id" :style="{ color: getCurrentTabColor.primary }">{{ todo.id }}</span>
                        <el-tag type="primary" size="small">{{ '普通' }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" type="warning">
                          {{ '待处理' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无变更待办" :image-size="200" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>
              <el-tab-pane name="problem">
                <template #label>
                  <span class="tab-label">
                    问题
                    <el-tag size="small" type="danger" effect="plain">{{ todoCounts.problem }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list todo-list-stacked">
                    <div
                      v-for="(todo, index) in currentTodoList"
                      :key="todo.id"
                      class="todo-item todo-item-stacked"
                      @click="handleTodoClick(todo, 'problem')"
                      :style="{
                        zIndex: index + 1,
                        borderLeftColor: getCurrentTabColor.border,
                        '--card-primary-color': getCurrentTabColor.primary,
                        '--card-bg-color': getCurrentTabColor.bg,
                        '--card-bg-color-light': getCurrentTabColor.bgLight,
                        '--card-bg-color-hover': getCurrentTabColor.bgHover,
                        '--card-bg-color-light-hover': getCurrentTabColor.bgLightHover,
                      }"
                    >
                      <div class="todo-header">
                        <span class="todo-id" :style="{ color: getCurrentTabColor.primary }">{{ todo.id }}</span>
                        <el-tag type="primary" size="small">{{ '普通' }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" type="warning">
                          {{ '待处理' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无问题待办" :image-size="200" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>
            </el-tabs>
          </div>
        </div>

        <!-- 下半部分：工单统计（占1份） -->
<!--        <div class="oa-section oa-week-stats">-->
<!--          <div class="section-header">-->
<!--            <div class="section-title">-->
<!--              <el-icon :size="18"><TrendCharts /></el-icon>-->
<!--              <h2>工单统计</h2>-->
<!--            </div>-->
<!--          </div>-->
<!--          <div class="section-body">-->
<!--            <el-tabs v-model="workOrderActiveTab" class="workorder-tabs">-->
<!--              <el-tab-pane name="week" label="本周">-->
<!--                <div class="week-stats-content">-->
<!--                  <div class="stats-overview">-->
<!--                    <div class="overview-item total">-->
<!--                      <div class="overview-value">{{ oaWeekStats.total }}</div>-->
<!--                      <div class="overview-label">工单总数</div>-->
<!--                    </div>-->
<!--                    <div class="overview-item completed">-->
<!--                      <div class="overview-value">{{ oaWeekStats.completed }}</div>-->
<!--                      <div class="overview-label">已完成</div>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                  <div class="stats-details">-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">待处理</span>-->
<!--                      <span class="detail-value warning">{{ oaWeekStats.pending }}</span>-->
<!--                    </div>-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">完成率</span>-->
<!--                      <span class="detail-value success">{{ oaWeekStats.completionRate }}%</span>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                </div>-->
<!--              </el-tab-pane>-->

<!--              <el-tab-pane name="month" label="本月">-->
<!--                <div class="week-stats-content">-->
<!--                  <div class="stats-overview">-->
<!--                    <div class="overview-item total">-->
<!--                      <div class="overview-value">{{ oaMonthStats.total }}</div>-->
<!--                      <div class="overview-label">工单总数</div>-->
<!--                    </div>-->
<!--                    <div class="overview-item completed">-->
<!--                      <div class="overview-value">{{ oaMonthStats.completed }}</div>-->
<!--                      <div class="overview-label">已完成</div>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                  <div class="stats-details">-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">待处理</span>-->
<!--                      <span class="detail-value warning">{{ oaMonthStats.pending }}</span>-->
<!--                    </div>-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">完成率</span>-->
<!--                      <span class="detail-value success">{{ oaMonthStats.completionRate }}%</span>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                  <div class="completion-progress">-->
<!--                    <div class="progress-label">-->
<!--                      <span>完成进度</span>-->
<!--                      <span>{{ oaMonthStats.completionRate }}%</span>-->
<!--                    </div>-->
<!--                    <div class="progress-bar">-->
<!--                      <div class="progress-fill" :style="{ width: oaMonthStats.completionRate + '%' }"></div>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                </div>-->
<!--              </el-tab-pane>-->

<!--              <el-tab-pane name="all" label="全部">-->
<!--                <div class="week-stats-content">-->
<!--                  <div class="stats-overview">-->
<!--                    <div class="overview-item total">-->
<!--                      <div class="overview-value">{{ oaAllStats.total }}</div>-->
<!--                      <div class="overview-label">工单总数</div>-->
<!--                    </div>-->
<!--                    <div class="overview-item completed">-->
<!--                      <div class="overview-value">{{ oaAllStats.completed }}</div>-->
<!--                      <div class="overview-label">已完成</div>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                  <div class="stats-details">-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">待处理</span>-->
<!--                      <span class="detail-value warning">{{ oaAllStats.pending }}</span>-->
<!--                    </div>-->
<!--                    <div class="detail-item">-->
<!--                      <span class="detail-label">完成率</span>-->
<!--                      <span class="detail-value success">{{ oaAllStats.completionRate }}%</span>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                  <div class="completion-progress">-->
<!--                    <div class="progress-label">-->
<!--                      <span>完成进度</span>-->
<!--                      <span>{{ oaAllStats.completionRate }}%</span>-->
<!--                    </div>-->
<!--                    <div class="progress-bar">-->
<!--                      <div class="progress-fill" :style="{ width: oaAllStats.completionRate + '%' }"></div>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                </div>-->
<!--              </el-tab-pane>-->
<!--            </el-tabs>-->
<!--          </div>-->
<!--        </div>-->
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-container {
  padding: 10px 14px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  border-radius: 10px;
  user-select: none;
}

/* 主内容区：左右3:1布局 */
.main-content {
  display: grid;
  grid-template-columns: 3fr 1fr;
  gap: 16px;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

/* 左侧面板 */
.left-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

/* 欢迎区域 */
.welcome-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 16px;
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.25);
  position: relative;
  overflow: hidden;
  flex-shrink: 0;
}

.welcome-section::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -10%;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
  border-radius: 50%;
}

.welcome-content {
  position: relative;
  z-index: 1;
}

.welcome-title {
  margin: 0 0 6px 0;
  font-size: 24px;
  font-weight: 700;
  color: #fff;
  display: flex;
  align-items: center;
  gap: 10px;
}

.title-icon {
  font-size: 28px;
}

.welcome-subtitle {
  margin: 0;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.85);
  letter-spacing: 0.5px;
}

.time-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border-radius: 24px;
  color: #fff;
  font-size: 13px;
  font-weight: 500;
  position: relative;
  z-index: 1;
}
.time-badge :deep(.el-icon) {
  display: flex;
  align-items: center;
}
.time-icon {
  font-size: 18px;
}
.time-text {
  white-space: pre;
}

/* 核心指标网格 */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  flex-shrink: 0;
}

.metric-card {
  position: relative;
  border-radius: 16px;
  overflow: hidden;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
}

.metric-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.15);
}
.metric-card:active {
  transform: translateY(-2px) scale(0.98);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
  transition: all 0.1s ease;
}
.metric-bg-pattern {
  position: absolute;
  top: 0;
  right: 0;
  width: 120px;
  height: 120px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.15) 0%, transparent 70%);
  border-radius: 50%;
  transform: translate(30%, -30%);
}

.metric-primary {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
}

.metric-danger {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.metric-success {
  background: linear-gradient(135deg, #60cd2a 0%, #8ec673 100%);
}

.metric-warning {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
}
.metric-content {
  position: relative;
  z-index: 1;
  padding: 18px 20px;
  color: #fff;
}

.metric-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.metric-icon-wrapper {
  width: 46px;
  height: 46px;
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
}

.metric-primary .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
}

.metric-danger .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(255, 71, 87, 0.3));
}

.metric-success .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(30, 144, 255, 0.3));
}

.metric-warning .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(255, 165, 2, 0.3));
}

.metric-trend {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.trend-up {
  background: transparent;
  border: none;
}

.trend-down {
  background: transparent;
  border: none;
}

.trend-arrow {
  font-size: 14px;
  line-height: 1;
  display: inline-flex;
  align-items: center;
  transform: translateY(-3px);
}

.arrow-danger {
  color: #fd0324;
  font-weight: 700;
  animation: pulse-warning 1.5s infinite;
}

.arrow-success {
  color: #ffffff;
  font-weight: 700;
}

.trend-value-danger {
  color: #fd0324;
  font-weight: 700;
}

.trend-value-success {
  color: #ffffff;
  font-weight: 700;
}

@keyframes pulse-warning {
  0%,
  100% {
    opacity: 1;
    transform: translateY(-3px) scale(1);
  }
  50% {
    opacity: 0.85;
    transform: translateY(-3px) scale(1.2);
  }
}


.metric-rate-badge {
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.metric-rate-badge.success {
  background: rgba(46, 213, 115, 0.3);
}

.metric-pending-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.pulse-dot {
  width: 8px;
  height: 8px;
  background: #fff;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%,
  100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.5;
    transform: scale(1.2);
  }
}

.metric-body {
  margin-bottom: 10px;
}

.metric-value {
  font-size: 32px;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 4px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.metric-label {
  font-size: 13px;
  opacity: 0.9;
  font-weight: 500;
}

.metric-details {
  margin-bottom: 0;
  padding: 8px 10px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  backdrop-filter: blur(5px);
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 3px 0;
  font-size: 11px;
}

.detail-row:not(:last-child) {
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.detail-row.highlight {
  background: rgba(255, 255, 255, 0.05);
  margin: 0 -10px;
  padding: 5px 10px;
  border-radius: 4px;
}

.detail-label {
  opacity: 0.85;
  font-weight: 500;
}

.detail-value {
  font-weight: 600;
}

.danger-text {
  color: #ffe0e0;
  font-weight: 700;
}

.warning-text {
  color: #fff5d6;
  font-weight: 700;
}

/* 数据展示区：整合为两个卡片 */
.data-showcase-integrated {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.data-panel {
  background: #fff;
  border-radius: 16px;
  padding: 18px 20px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
  transition: all 0.3s ease;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.data-panel:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  flex-shrink: 0;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.title-bar {
  width: 4px;
  height: 18px;
  background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
  border-radius: 2px;
}

.panel-title h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #2d3436;
}

.panel-subtitle {
  font-size: 11px;
  color: #b2bec3;
}

.panel-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.stats-body,
.timing-body {
  display: flex;
  align-items: stretch;
}

.stats-content,
.timing-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  width: 100%;
}

.stats-section,
.timing-section {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: #636e72;
  margin-bottom: 12px;
  padding-left: 8px;
  border-left: 3px solid #667eea;
}

/* Tabs样式 */
.stats-tabs,
.timing-tabs,
.workorder-tabs {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
}

.stats-tabs :deep(.el-tabs__header),
.timing-tabs :deep(.el-tabs__header),
.workorder-tabs :deep(.el-tabs__header) {
  margin: 0 0 12px 0;
  flex-shrink: 0;
}

.stats-tabs :deep(.el-tabs__content),
.timing-tabs :deep(.el-tabs__content),
.workorder-tabs :deep(.el-tabs__content) {
  flex: 1;
  overflow: hidden;
  height: 0;
}

.stats-tabs :deep(.el-tab-pane),
.timing-tabs :deep(.el-tab-pane),
.workorder-tabs :deep(.el-tab-pane) {
  height: 100%;
}

/* 告警级别分布 */
.level-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  height: 100%;
  justify-content: space-between;
  padding: 8px 4px;
}

.level-item-modern {
  animation: slideInLeft 0.5s ease-out forwards;
  opacity: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.level-main {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-bottom: 1px;
}

.level-info {
  flex: 1;
}

.level-name {
  font-size: 12px;
  color: #636e72;
  margin-bottom: 2px;
  margin-right: 20px;
}

.level-count-large {
  font-size: 14px;
  font-weight: 700;
  color: #2d3436;
}

.level-progress-modern {
  width: 95%;
  display: flex;
  align-items: center;
  gap: 3px;
}

.progress-track {
  flex: 9;
  height: 6px;
  background: #f0f2f5;
  border-radius: 3px;
  overflow: hidden;
  margin-right: 5px;
}

.progress-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
}

.progress-label {
  flex: 1;
  display: flex;
  font-size: 11px;
  font-weight: 600;
  color: #636e72;
  min-width: 36px;
  text-align: right;
  align-items: flex-end;
}

/* ECharts饼图容器 */
.category-chart-container {
  width: 100%;
  height: 90%;
}

/* 趋势图表 */
.trend-chart {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  height: 200px;
  gap: 8px;
  padding: 30px 0 20px 0;
  width: 100%;
}

.trend-bar-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  animation: fadeInUp 0.6s ease-out forwards;
  opacity: 0;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.trend-bar-container {
  width: 100%;
  height: 120px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.trend-bar {
  width: 100%;
  max-width: 32px;
  border-radius: 6px 6px 0 0;
  position: relative;
  transition: all 0.3s ease;
  cursor: pointer;
}

.trend-bar:hover {
  opacity: 0.8;
  transform: scaleY(1.05);
}

.trend-bar-value {
  position: absolute;
  top: -20px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 11px;
  font-weight: 600;
  color: #667eea;
  white-space: nowrap;
}

.trend-bar-label {
  font-size: 11px;
  color: #636e72;
  font-weight: 500;
}
.today-highlight {
  color: #ffa502;
  font-weight: 700;
  text-shadow: 0 0 8px rgba(255, 165, 2, 0.3);
}
.current-week-highlight {
  color: #ffa502;
  font-weight: 700;
  text-shadow: 0 0 8px rgba(255, 165, 2, 0.3);
}
/* 处理时间统计网格 */
.time-stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-rows: repeat(2, 1fr);
  gap: 12px;
  height: 100%;
}

.time-stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  background: #f8f9fa;
  border-radius: 12px;
  transition: all 0.3s ease;
  min-height: 0;
}

.time-stat-card:hover {
  background: #f0f2f5;
  transform: translateY(-2px);
}

.stat-icon {
  width: 50px;
  height: 50px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stat-icon.avg {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
}

.stat-icon.fast {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: #fff;
}

.stat-icon.slow {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
  color: #fff;
}

.stat-icon.overtime {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
  color: #fff;
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 13px;
  color: #636e72;
  margin-bottom: 6px;
}

.stat-value {
  font-size: 22px;
  font-weight: 700;
  color: #2d3436;
}

.stat-value.danger {
  color: #ff4757;
}

/* 右侧面板 */
.right-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

/* OA区域通用样式 */
.oa-section {
  background: #fff;
  border-radius: 16px;
  padding: 16px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: all 0.3s ease;
}

.oa-section:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
}

.oa-todo-list {
  flex: 2;
}

.oa-week-stats {
  flex: 1;
}

/* ECC 值班卡片 */
.ecc-duty-section {
  flex-shrink: 0;
}

.ecc-duty-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-top: 4px;
}

.ecc-duty-row {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 6px 10px;
  background: #f8f9fa;
  border-radius: 8px;
  font-size: 13px;
}

.ecc-shift-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 22px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 600;
  color: #fff;
  flex-shrink: 0;
}

.ecc-shift-day {
  background: linear-gradient(135deg, #667eea, #764ba2);
}

.ecc-shift-night {
  background: linear-gradient(135deg, #2d3436, #636e72);
}

.ecc-shift-sys {
  background: linear-gradient(135deg, #667eea, #764ba2);
}

.ecc-shift-net {
  background: linear-gradient(135deg, #667eea, #764ba2);
}

.ecc-shift-pm {
  background: linear-gradient(135deg, #667eea, #764ba2);
}

.ecc-shift-time {
  font-size: 12px;
  color: #909399;
  flex-shrink: 0;
  width: 72px;
}

.ecc-shift-label {
  font-size: 12px;
  color: #606266;
  flex-shrink: 0;
  width: 52px;
}

.ecc-person-info {
  display: flex;
  align-items: center;
  gap: 4px;
  flex: 1;
  min-width: 0;
}

.ecc-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: #fff;
  font-size: 11px;
  font-weight: 600;
  flex-shrink: 0;
}

.ecc-avatar-empty {
  background: #94a3b8;
  font-size: 12px;
}

.ecc-person-name {
  color: #2d3436;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.ecc-person-name-empty {
  color: #94a3b8;
  font-weight: 400;
}

.ecc-phone-icon {
  flex-shrink: 0;
  color: #e67e22;
}

.ecc-person-phone {
  display: flex;
  align-items: center;
  gap: 1px;
  min-width: 110px;
  font-size: 12px;
  color: #909399;
  font-family: 'Consolas', 'Courier New', monospace;
  flex-shrink: 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  flex-shrink: 0;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.section-title h2 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #2d3436;
}

.section-title :deep(.el-icon) {
  color: #667eea;
}

.section-badge {
  padding: 4px 10px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.section-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

/* Element Plus Tabs样式 */
.oa-tabs {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.oa-tabs :deep(.el-tabs__header) {
  margin: 0 0 12px 0;
  flex-shrink: 0;
}

.oa-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0 4px;
}

.oa-tabs :deep(.el-tabs__content) {
  flex: 1;
  overflow: hidden;
  height: 0;
}

.oa-tabs :deep(.el-tab-pane) {
  height: 100%;
}

.tab-label {
  display: flex;
  align-items: center;
  gap: 2px;
  font-size: 13px;
}
/* 请求tab的紫色tag样式 */
.request-tag {
  background-color: rgba(156, 39, 176, 0);
  border-color: rgba(156, 39, 176, 0.4);
  color: #9c27b0;
}

.tab-label :deep(.el-tag) {
  margin-left: 2px;
  transform: scale(0.9);
}
/* 调整 tabs 头部间距 */
.oa-tabs :deep(.el-tabs__item) {
  padding: 0 14px;
  font-size: 12px;
}

.oa-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0 2px;
}
/* Element Plus滚动条样式 */
.todo-scrollbar {
  height: 100%;
  width: 100%;
}

.todo-scrollbar :deep(.el-scrollbar__wrap) {
  overflow-x: hidden;
}

.todo-scrollbar :deep(.el-scrollbar__bar.is-vertical) {
  width: 8px;
  right: 4px;
}

.todo-scrollbar :deep(.el-scrollbar__thumb) {
  background-color: rgba(144, 147, 153, 0.3);
  border-radius: 4px;
  transition: all 0.3s ease;
}

.todo-scrollbar :deep(.el-scrollbar__thumb:hover) {
  background-color: rgba(144, 147, 153, 0.5);
}

/* 待办工单列表 */
.todo-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  height: 100%;
  padding-right: 8px;
}

/* 堆叠式待办列表 */
.todo-list-stacked {
  position: relative;
  padding: 8px;
}

.todo-item {
  padding: 16px 18px;
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid #e4e7ed;
  border-left: 3px solid var(--card-primary-color, #409eff);
  transition: all 0.2s ease;
  min-width: 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  position: relative;
  overflow: hidden;
}

.todo-item::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--card-primary-color, #409eff);
  opacity: 0;
  transition: opacity 0.2s ease;
}
/* 堆叠式待办卡片 */
.todo-item-stacked {
  position: relative;
  margin-bottom: -60px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.todo-item-stacked:last-child {
  margin-bottom: 0;
}

.todo-item-stacked:hover {
  margin-bottom: 0;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  border-color: #dcdfe6;
  border-left-width: 4px;
}

.todo-item-stacked:hover::before {
  opacity: 1;
}

.todo-item-stacked:hover ~ .todo-item-stacked {
  transform: translateY(8px);
}

.todo-item:hover {
  background: #f5f7fa;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  border-color: #dcdfe6;
}

.todo-item:hover::before {
  opacity: 1;
}

.todo-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  flex-wrap: wrap;
  gap: 6px;
}

.todo-id {
  font-size: 12px;
  color: #606266;
  font-weight: 600;
  word-break: break-all;
  flex-shrink: 0;
  background: #f5f7fa;
  padding: 4px 10px;
  border-radius: 4px;
  border: 1px solid #e4e7ed;
  font-family: 'Courier New', monospace;
}

.todo-title {
  font-size: 14px;
  font-weight: 500;
  color: #303133;
  margin-bottom: 10px;
  line-height: 1.6;
  word-break: break-word;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.todo-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #909399;
  margin-bottom: 10px;
  flex-wrap: wrap;
  gap: 6px;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 4px;
  word-break: break-all;
  flex-shrink: 0;
}

.todo-footer {
  display: flex;
  justify-content: flex-end;
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  width: 100%;
  min-height: 150px;
}

/* 本周工单统计 */
.week-stats-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
  height: 100%;
}

.stats-overview {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
}

.overview-item {
  padding: 10px;
  border-radius: 10px;
  text-align: center;
  transition: all 0.3s ease;
}

.overview-item:hover {
  transform: translateY(-2px);
}

.overview-item.total {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
}

.overview-item.completed {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: #fff;
}

.overview-value {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 4px;
}

.overview-label {
  font-size: 11px;
  opacity: 0.9;
}

.stats-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.detail-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 10px;
  background: #f8f9fa;
  border-radius: 8px;
}

.detail-label {
  font-size: 12px;
  color: #636e72;
}

.detail-value {
  font-size: 14px;
  font-weight: 700;
  color: #2d3436;
}

.detail-value.primary {
  color: #1e90ff;
}

.detail-value.warning {
  color: #ffa502;
}

.detail-value.success {
  color: #2ed573;
}

.completion-progress {
  margin-top: auto;
}

.progress-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #636e72;
  margin-bottom: 6px;
  font-weight: 600;
}

.progress-bar {
  height: 8px;
  background: #f0f2f5;
  border-radius: 4px;
  overflow: hidden;
}

.progress-bar .progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
  border-radius: 4px;
  transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
}

/* Tabs标签页自定义样式 */
.stats-tabs :deep(.el-tabs__header) {
  margin: 0 0 16px 0;
}

.stats-tabs :deep(.el-tabs__nav-wrap::after) {
  height: 1px;
}

.timing-tabs :deep(.el-tabs__header) {
  margin: 0 0 16px 0;
}

.timing-tabs :deep(.el-tabs__nav-wrap::after) {
  height: 1px;
}

.workorder-tabs :deep(.el-tabs__header) {
  margin: 0 0 12px 0;
}

.workorder-tabs :deep(.el-tabs__nav-wrap::after) {
  height: 1px;
}

/* 图表容器 */
.chart-container {
  width: 100%;
  height: 280px;
}

/* 响应式调整 */
@media (max-width: 1400px) {
  .main-content {
    grid-template-columns: 1fr;
  }

  .right-panel {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
  }

  .oa-todo-list {
    flex: none;
  }

  .oa-week-stats {
    flex: none;
  }
}

@media (max-width: 1200px) {
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .data-showcase-integrated {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .dashboard-container {
    padding: 12px;
  }

  .welcome-section {
    flex-direction: column;
    gap: 12px;
    text-align: center;
    padding: 14px 18px;
  }

  .welcome-title {
    font-size: 20px;
  }

  .metrics-grid {
    grid-template-columns: 1fr;
  }

  .metric-value {
    font-size: 28px;
  }

  .data-showcase-integrated {
    grid-template-columns: 1fr;
  }

  .right-panel {
    grid-template-columns: 1fr;
  }

  .time-stats-grid {
    grid-template-columns: 1fr;
  }
}
.icon {
  width: 1.5em;
  height: 1.5em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}

</style>
