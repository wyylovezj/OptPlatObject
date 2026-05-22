<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, ArrowLeft, ArrowRight, Calendar, Monitor, Connection, User, List, UploadFilled } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { HolidayUtil } from 'lunar-javascript'
import { fetchDutyUsers, getEcc, getSys, getNet, getPM, saveDuty } from '@/api/dutyPageInterface.js'
import {
  dutyUsers,
  dutyScheduleData,
  eccDayPersonnel,
  eccNightPersonnel,
  sysOpsPersonnel,
  netOpsPersonnel,
  pmPersonnel,
  resetDutyScheduleData,
} from '@/utils/dutyPageData.js'
import { useAuthStore } from '@/stores/authInfoStore.js'

// ============ 周期切换 ============
const periodMode = ref('week')
const customStart = ref('')
const customEnd = ref('')
const tableTitle = ref('')

const getWeekRange = () => {
  const now = new Date()
  const dayOfWeek = now.getDay()
  const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek
  const monday = new Date(now)
  monday.setDate(now.getDate() + mondayOffset)
  const sunday = new Date(monday)
  sunday.setDate(monday.getDate() + 6)

  const formatDt = (d) => {
    return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日'
  }
  const fmtShort = (d) => {
    return String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
  }

  const weekNum =
    Math.ceil(
      (monday.getDate() +
        (new Date(monday.getFullYear(), monday.getMonth(), 1).getDay() === 0 ? 7 : new Date(monday.getFullYear(), monday.getMonth(), 1).getDay()) -
        1) /
      7,
    ) || 1
  return {
    label: formatDt(monday) + ' — ' + formatDt(sunday) + ' · 第' + weekNum + '周',
    startShort: fmtShort(monday),
    endShort: fmtShort(sunday),
    startFull: monday.toISOString().split('T')[0],
    endFull: sunday.toISOString().split('T')[0],
  }
}

const weekLabel = ref('')
const updateWeekLabel = () => {
  const range = getWeekRange()
  weekLabel.value = range.label
  tableTitle.value = '本周排班明细 (' + range.startShort + ' 至 ' + range.endShort + ')'
  customStart.value = range.startFull
  customEnd.value = range.endFull
}
updateWeekLabel()

const switchPeriod = (mode) => {
  periodMode.value = mode
  if (mode === 'week') {
    updateWeekLabel()
    // 重新生成本周数据
    const range = getWeekRange()
    scheduleTableData.value = generateScheduleData(range.startFull, range.endFull)
  }
}

const shiftCustomWeek = (dir) => {
  const start = new Date(customStart.value)
  const end = new Date(customEnd.value)
  start.setDate(start.getDate() + dir * 7)
  end.setDate(end.getDate() + dir * 7)
  customStart.value = formatDateStr(start)
  customEnd.value = formatDateStr(end)
}

const formatDateStr = (d) => {
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
}

const applyCustomRange = () => {
  tableTitle.value = '排班明细 (' + customStart.value + ' 至 ' + customEnd.value + ')'
  scheduleTableData.value = generateScheduleData(customStart.value, customEnd.value)
  ElMessage.success('已切换至自定义日期范围')
}

// ============ 今日值班 ============
const todayStr = computed(() => {
  const d = new Date()
  const weekNames = ['日', '一', '二', '三', '四', '五', '六']
  return d.getMonth() + 1 + '月' + d.getDate() + '日 星期' + weekNames[d.getDay()]
})

// 示例今日值班数据（实际应从 API 获取）
const todayEccPersons = ref([
  { name: '李四光', surname: '李', avatarColor: 'var(--primary)', shiftClass: 'shift-day', shiftLabel: '白', time: '09:00 - 18:00' },
  { name: '张三丰', surname: '张', avatarColor: 'var(--text-3)', shiftClass: 'shift-night', shiftLabel: '夜', time: '18:00 - 09:00' },
])
const todaySysPersons = ref([
  { name: '赵六六', surname: '赵', avatarColor: 'var(--purple)', shiftClass: 'shift-day', shiftLabel: '白', time: '09:00 - 18:00' },
])
const todayNetPersons = ref([
  { name: '孙八一', surname: '孙', avatarColor: 'var(--cyan)', shiftClass: 'shift-day', shiftLabel: '白', time: '09:00 - 18:00' },
])
const todayPmPersons = ref([
  { name: '吴经理', surname: '吴', avatarColor: 'var(--warning)', shiftClass: 'shift-day', shiftLabel: '全', time: '09:00 - 18:00 在线' },
])

// ============ 排班表格 ============
// 使用 lunar-javascript 库自动识别日期类型（统一供表格和日历使用）
const getDayType = (dateStr) => {
  const d = new Date(dateStr)
  const year = d.getFullYear()
  const month = d.getMonth() + 1
  const day = d.getDate()
  const holiday = HolidayUtil.getHoliday(year, month, day)

  if (holiday) {
    // 有节假日信息
    if (holiday.isWork()) {
      // 调休补班日 - 视为工作日
      return 'workday'
    }
    // 法定节假日 - 视为休息日
    return 'holiday'
  }

  // 没有节假日信息，按周末判断
  const dow = d.getDay()
  return dow === 0 || dow === 6 ? 'rest' : 'workday'
}

const isRestDay = (dateStr) => {
  const type = getDayType(dateStr)
  return type === 'rest' || type === 'holiday'
}

// 示例排班表格数据（实际应从 API 获取）
const weekDaysNames = ['一', '二', '三', '四', '五', '六', '日']

// 人员池数据
const personPool = {
  ecc: ['张三丰', '李四光'],
  sys: ['王五一', '赵六六'],
  net: ['钱七七', '孙八一'],
  pm: ['周总', '吴经理'],
}

// 人员颜色映射
const personColors = {
  张三丰: 'var(--primary)',
  李四光: 'var(--text-3)',
  王五一: 'var(--purple)',
  赵六六: 'var(--purple)',
  钱七七: 'var(--cyan)',
  孙八一: 'var(--cyan)',
  周总: 'var(--warning)',
  吴经理: 'var(--warning)',
}

// 获取姓氏
const getSurname = (name) => name.charAt(0)

// 获取日期对应的节假日名称（供表格使用）
const getDayHolidayNameByDateStr = (dateStr) => {
  const d = new Date(dateStr)
  const year = d.getFullYear()
  const month = d.getMonth() + 1
  const day = d.getDate()
  const holiday = HolidayUtil.getHoliday(year, month, day)

  if (holiday) {
    const name = holiday.getName()
    if (holiday.isWork()) {
      return name + '(补)'
    }
    return name
  }

  return ''
}

// 生成指定日期范围的排班数据
const generateScheduleData = (startDate, endDate) => {
  const data = []
  const start = new Date(startDate)
  const end = new Date(endDate)
  const today = new Date()
  const todayStr = today.toISOString().split('T')[0]

  let currentDate = new Date(start)
  let dayIndex = 0

  while (currentDate <= end) {
    const dateStr = currentDate.toISOString().split('T')[0]
    const dow = currentDate.getDay()
    const dayOfWeek = dow === 0 ? 6 : dow - 1 // 转换为周一=0
    const dateDisplay =
      String(currentDate.getMonth() + 1).padStart(2, '0') +
      '-' +
      String(currentDate.getDate()).padStart(2, '0') +
      ' (周' +
      weekDaysNames[dayOfWeek] +
      ')'
    const isToday = dateStr === todayStr
    const dayType = getDayType(dateStr)
    const isRest = dayType === 'rest' || dayType === 'holiday'

    // 根据日期选择人员（简单的轮转逻辑）
    const eccPerson = personPool.ecc[dayIndex % personPool.ecc.length]
    const sysPerson = isRest ? '' : personPool.sys[dayIndex % personPool.sys.length]
    const netPerson = isRest ? '' : personPool.net[dayIndex % personPool.net.length]
    const pmPerson = isRest ? '' : personPool.pm[dayIndex % personPool.pm.length]

    // 获取节假日名称（如果有）
    const holidayName = getDayHolidayNameByDateStr(dateStr)

    // 白班行
    data.push({
      id: dateStr + '-D',
      date: dateStr,
      dateDisplay: dateDisplay,
      isToday: isToday,
      dayType: dayType,
      shift: 'day',
      shiftText: '白班 09:00-18:00',
      shiftClass: 'shift-day',
      ecc: eccPerson,
      eccSurname: getSurname(eccPerson),
      eccColor: personColors[eccPerson] || 'var(--primary)',
      sysOps: sysPerson,
      sysSurname: sysPerson ? getSurname(sysPerson) : '',
      sysColor: sysPerson ? personColors[sysPerson] || 'var(--purple)' : '',
      isSysOpsMaster: !isRest,
      netOps: netPerson,
      netSurname: netPerson ? getSurname(netPerson) : '',
      netColor: netPerson ? personColors[netPerson] || 'var(--cyan)' : '',
      isNetOpsMaster: !isRest,
      pm: pmPerson,
      pmSurname: pmPerson ? getSurname(pmPerson) : '',
      pmColor: pmPerson ? personColors[pmPerson] || 'var(--warning)' : '',
      isPmMaster: !isRest,
    })

    // 夜班行
    const eccNightPerson = personPool.ecc[(dayIndex + 1) % personPool.ecc.length]
    data.push({
      id: dateStr + '-N',
      date: dateStr,
      dateDisplay: '',
      isToday: isToday,
      dayType: dayType,
      shift: 'night',
      shiftText: '夜班 18:00-09:00',
      shiftClass: 'shift-night',
      ecc: eccNightPerson,
      eccSurname: getSurname(eccNightPerson),
      eccColor: personColors[eccNightPerson] || 'var(--text-3)',
      sysOps: sysPerson,
      sysSurname: sysPerson ? getSurname(sysPerson) : '',
      sysColor: sysPerson ? personColors[sysPerson] || 'var(--purple)' : '',
      isSysOpsMaster: false,
      netOps: netPerson,
      netSurname: netPerson ? getSurname(netPerson) : '',
      netColor: netPerson ? personColors[netPerson] || 'var(--cyan)' : '',
      isNetOpsMaster: false,
      pm: pmPerson,
      pmSurname: pmPerson ? getSurname(pmPerson) : '',
      pmColor: pmPerson ? personColors[pmPerson] || 'var(--warning)' : '',
      isPmMaster: false,
    })

    currentDate.setDate(currentDate.getDate() + 1)
    dayIndex++
  }

  return data.map((row) => ({
    ...row,
    dayBadgeClass: row.dayType === 'rest' ? 'badge-rest' : row.dayType === 'holiday' ? 'badge-holiday' : 'badge-workday',
    dayBadgeText: row.dayType === 'rest' ? '休息日' : row.dayType === 'holiday' ? row.holidayName || '法定假日' : '工作日',
  }))
}

const scheduleTableData = ref(generateScheduleData(getWeekRange().startFull, getWeekRange().endFull))

const scheduleSpanMethod = ({ row, columnIndex }) => {
  // 列顺序：日期(0), 班次(1), ECC(2), 系统运维(3), 网络运维(4), PM(5), 操作(6)
  if (columnIndex === 0) {
    // 日期列：白班和夜班合并
    const pairRows = scheduleTableData.value.filter((r) => r.date === row.date)
    if (pairRows.length === 2 && pairRows[0].id === row.id) return { rowspan: 2, colspan: 1 }
    if (pairRows.length === 2 && pairRows[1].id === row.id) return { rowspan: 0, colspan: 0 }
    return { rowspan: 1, colspan: 1 }
  }
  if (columnIndex === 3 || columnIndex === 4 || columnIndex === 5) {
    // 系统运维、网络运维、PM列：白班和夜班合并，只在白班行显示
    const pairRows = scheduleTableData.value.filter((r) => r.date === row.date)
    if (pairRows.length === 2) {
      // 白班行（第一行）合并2行
      if (pairRows[0].id === row.id) return { rowspan: 2, colspan: 1 }
      // 夜班行（第二行）隐藏
      if (pairRows[1].id === row.id) return { rowspan: 0, colspan: 0 }
    }
    return { rowspan: 1, colspan: 1 }
  }
  if (columnIndex === 6) {
    // 操作列：白班和夜班合并
    const pairRows = scheduleTableData.value.filter((r) => r.date === row.date)
    if (pairRows.length === 2) {
      if (pairRows[0].id === row.id) return { rowspan: 2, colspan: 1 }
      if (pairRows[1].id === row.id) return { rowspan: 0, colspan: 0 }
    }
    return { rowspan: 1, colspan: 1 }
  }
  return { rowspan: 1, colspan: 1 }
}

const tableRowClassName = ({ row }) => {
  if (row.isToday) return 'today-row'
  if (row.dayType === 'rest' || row.dayType === 'holiday') return 'rest-day-row'
  return ''
}

// ============ 工作日维护弹窗 ============
const workdayModalVisible = ref(false)
const workdayYear = ref(2026)
const workdayMonth = ref(4) // 0-indexed, 4 = May
const workdayMonthSelect = ref(5) // 1-indexed for select, 5 = May
const weekDays = ['一', '二', '三', '四', '五', '六', '日']

// 年份选项（当前年份前后各2年）
const yearOptions = computed(() => {
  const currentYear = new Date().getFullYear()
  const years = []
  for (let y = currentYear - 2; y <= currentYear + 2; y++) {
    years.push(y)
  }
  return years
})

// 月份选项
const monthOptions = [
  { value: 1, label: '1月' },
  { value: 2, label: '2月' },
  { value: 3, label: '3月' },
  { value: 4, label: '4月' },
  { value: 5, label: '5月' },
  { value: 6, label: '6月' },
  { value: 7, label: '7月' },
  { value: 8, label: '8月' },
  { value: 9, label: '9月' },
  { value: 10, label: '10月' },
  { value: 11, label: '11月' },
  { value: 12, label: '12月' },
]

const workdayStartDow = computed(() => {
  const first = new Date(workdayYear.value, workdayMonth.value, 1)
  return first.getDay() === 0 ? 6 : first.getDay() - 1
})

const workdayDaysInMonth = computed(() => {
  const last = new Date(workdayYear.value, workdayMonth.value + 1, 0)
  return last.getDate()
})

// 年月选择变化时的处理
const onYearMonthChange = () => {
  workdayMonth.value = workdayMonthSelect.value - 1
}

// 使用 lunar-javascript 库自动识别日期类型
const getDayTypeFromLunar = (day) => {
  const year = workdayYear.value
  const month = workdayMonth.value + 1
  const holiday = HolidayUtil.getHoliday(year, month, day)

  if (holiday) {
    // 有节假日信息
    if (holiday.isWork()) {
      // 调休补班日 - 视为工作日
      return 'workday'
    }
    // 法定节假日 - 视为休息日
    return 'holiday'
  }

  // 没有节假日信息，按周末判断
  const d = new Date(year, month - 1, day)
  const dow = d.getDay()
  return dow === 0 || dow === 6 ? 'rest' : 'workday'
}

// 获取节假日名称（供日历弹窗使用）
const getDayHolidayName = (day) => {
  const year = workdayYear.value
  const month = workdayMonth.value + 1
  const holiday = HolidayUtil.getHoliday(year, month, day)

  if (holiday) {
    const name = holiday.getName()
    if (holiday.isWork()) {
      return name + '(补)'
    }
    return name
  }

  return ''
}

const getCalDayStyle = (day) => {
  const type = getDayTypeFromLunar(day)
  if (type === 'holiday') return { background: '#fce7f3', color: '#9d174d', borderColor: '#fbcfe8' }
  if (type === 'rest') return { background: '#fef3c7', color: '#92400e', borderColor: '#fde68a' }
  return { background: '#dbeafe', color: '#1e40af', borderColor: '#bfdbfe' }
}

const openWorkdayModal = () => {
  workdayModalVisible.value = true
}
const workdayMonthNav = (dir) => {
  workdayMonth.value += dir
  if (workdayMonth.value > 11) {
    workdayMonth.value = 0
    workdayYear.value++
  }
  if (workdayMonth.value < 0) {
    workdayMonth.value = 11
    workdayYear.value--
  }
  // 同步更新下拉框的值
  workdayMonthSelect.value = workdayMonth.value + 1
}
const saveWorkdays = () => {
  // TODO: POST workdayOverrides to backend
  ElMessage.success('工作日配置已保存')
  workdayModalVisible.value = false
}

// 获取authStore实例
const authStore = useAuthStore()

// ============ 新增排班弹窗 ============
const addDutyModalVisible = ref(false)
const addDutyTab = ref('excel')
const manualFormRef = ref(null)
const manualForm = reactive({
  date: new Date().toISOString().split('T')[0], // 默认当天日期
  eccDay: '',
  eccNight: '',
  sysOps: '',
  netOps: '',
  pm: '',
})

// 判断当前选择的日期是否为非工作日（休息日或法定节假日）
const isNonWorkDay = computed(() => {
  if (!manualForm.date) return false
  const dayType = getDayType(manualForm.date)
  return dayType === 'rest' || dayType === 'holiday'
})

// 动态验证规则
const manualFormRules = computed(() => {
  const rules = {
    date: [{ required: true, message: '请选择排班日期', trigger: 'change' }],
    eccDay: [{ required: true, message: '请选择ECC白班人员', trigger: 'change' }],
    eccNight: [{ required: true, message: '请选择ECC夜班人员', trigger: 'change' }],
    pm: [{ required: true, message: '请选择甲方PM人员', trigger: 'change' }],
  }

  // 工作日时，系统运维和网络运维为必填
  if (!isNonWorkDay.value) {
    rules.sysOps = [{ required: true, message: '请选择系统运维人员', trigger: 'change' }]
    rules.netOps = [{ required: true, message: '请选择网络运维人员', trigger: 'change' }]
  }

  return rules
})

// 下拉框选项数据（从数据模型中获取）
const eccUserOptions = computed(() => eccDayPersonnel.value)
const sysUserOptions = computed(() => sysOpsPersonnel.value)
const netUserOptions = computed(() => netOpsPersonnel.value)
const pmUserOptions = computed(() => pmPersonnel.value)

const openAddDutyModal = () => {
  addDutyModalVisible.value = true
}

// 下拉框聚焦时加载数据
const loadEccPersonnel = async () => {
  if (eccDayPersonnel.value.length === 0) {
    try {
      const data = await getEcc()
      eccDayPersonnel.value = data || []
      console.log('ECC白班人员数据：', data)
      // ECC夜班使用相同的数据
      eccNightPersonnel.value = data || []
    } catch {
      ElMessage.error('获取ECC值班人员失败')
    }
  }
}

const loadSysPersonnel = async () => {
  if (sysOpsPersonnel.value.length === 0) {
    try {
      const data = await getSys()
      sysOpsPersonnel.value = data || []
    } catch {
      ElMessage.error('获取系统运维值班人员失败')
    }
  }
}

const loadNetPersonnel = async () => {
  if (netOpsPersonnel.value.length === 0) {
    try {
      const data = await getNet()
      netOpsPersonnel.value = data || []
    } catch {
      ElMessage.error('获取网络运维值班人员失败')
    }
  }
}

const loadPmPersonnel = async () => {
  if (pmPersonnel.value.length === 0) {
    try {
      const data = await getPM()
      pmPersonnel.value = data || []
    } catch {
      ElMessage.error('获取甲方PM值班人员失败')
    }
  }
}

// 保存排班
const saveManualDuty = async () => {
  if (addDutyTab.value !== 'manual') return

  // 表单验证
  if (!manualFormRef.value) return

  try {
    await manualFormRef.value.validate()
  } catch {
    ElMessage.warning('请填写必填项')
    return
  }

  // 获取当前登录用户名
  const currentUser = authStore.user || ''

  // 将表单数据转换为数组格式，每条对象是一天的排班数据
  const dutyScheduleArray = [{
    schedule_date: manualForm.date || '',
    ecc_day_personnel_id: manualForm.eccDay?.id || '',
    ecc_night_personnel_id: manualForm.eccNight?.id || '',
    sys_ops_personnel_id: manualForm.sysOps?.id || '',
    net_ops_personnel_id: manualForm.netOps?.id || '',
    pm_personnel_id: manualForm.pm?.id || '',
    created_by: currentUser,
    updated_by: currentUser,
  }]

  try {
    await saveDuty(dutyScheduleArray)
    ElMessage.success('排班已保存')
    addDutyModalVisible.value = false
    // 重置数据模型
    resetDutyScheduleData()
  } catch (error) {
    ElMessage.error('保存排班失败: ' + error.message)
  }
}

// 关闭弹窗时重置数据
const closeAddDutyModal = () => {
  addDutyModalVisible.value = false
  // 清空表单中的已选值
  manualForm.date = new Date().toISOString().split('T')[0] // 重置为当天日期
  manualForm.eccDay = ''
  manualForm.eccNight = ''
  manualForm.sysOps = ''
  manualForm.netOps = ''
  manualForm.pm = ''
  // 清除表单验证状态
  if (manualFormRef.value) {
    manualFormRef.value.clearValidate()
  }
  // 重置所有数据模型为初始值
  resetDutyScheduleData()
}

// ============ 初始化 ============
onMounted(async () => {
  try {
    const users = await fetchDutyUsers()
    if (users && users.length) dutyUsers.value = users
  } catch (e) {
    /* ignore */
  }
})
</script>

<template>
  <div class="duty-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">排班与值班管理</h2>
      <div class="toolbar-actions">
        <el-button class="btn-outline">导出表格</el-button>
        <el-button type="primary" class="btn-primary-custom" @click="openAddDutyModal">
          <el-icon><Plus /></el-icon>
          新增排班
        </el-button>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="period-switch">
        <button :class="['period-btn', { active: periodMode === 'week' }]" @click="switchPeriod('week')">本周值班</button>
        <button :class="['period-btn', { active: periodMode === 'custom' }]" @click="switchPeriod('custom')">自定义周期</button>
      </div>

      <div v-show="periodMode === 'week'" class="week-indicator">{{ weekLabel }}</div>

      <div :class="['custom-range', { enabled: periodMode === 'custom' }]">
        <button class="nav-week-btn" @click="shiftCustomWeek(-1)">
          <el-icon><ArrowLeft /></el-icon>
        </button>
        <el-date-picker v-model="customStart" type="date" placeholder="开始" value-format="YYYY-MM-DD" class="filter-date-picker" size="small" />
        <span class="range-sep">至</span>
        <el-date-picker v-model="customEnd" type="date" placeholder="结束" value-format="YYYY-MM-DD" class="filter-date-picker" size="small" />
        <button class="nav-week-btn" @click="shiftCustomWeek(1)">
          <el-icon><ArrowRight /></el-icon>
        </button>
        <el-button type="primary" size="small" @click="applyCustomRange">查询</el-button>
      </div>

      <el-button class="btn-outline ml-auto" size="small" @click="openWorkdayModal">
        <el-icon><Calendar /></el-icon>
        &nbsp;日历
      </el-button>
    </div>

    <!-- 今日值班卡片 -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <el-icon><Calendar /></el-icon>
          今日值班 ({{ todayStr }})
        </div>
      </div>
      <div class="today-grid">
        <div class="duty-role-card">
          <div class="role-header r-ecc">
            <span class="role-name"
              ><el-icon><Monitor /></el-icon> ECC 指挥中心</span
            >
          </div>
          <div class="person-item" v-for="p in todayEccPersons" :key="p.name">
            <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
            <div class="p-info">
              <div class="p-name">
                {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
              </div>
              <div class="p-time">{{ p.time }}</div>
            </div>
          </div>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-sys">
            <span class="role-name"
              ><el-icon><Monitor /></el-icon> 系统运维</span
            >
          </div>
          <div class="person-item" v-for="p in todaySysPersons" :key="p.name">
            <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
            <div class="p-info">
              <div class="p-name">
                {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
              </div>
              <div class="p-time">{{ p.time }}</div>
            </div>
          </div>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-net">
            <span class="role-name"
              ><el-icon><Connection /></el-icon> 网络运维</span
            >
          </div>
          <div class="person-item" v-for="p in todayNetPersons" :key="p.name">
            <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
            <div class="p-info">
              <div class="p-name">
                {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
              </div>
              <div class="p-time">{{ p.time }}</div>
            </div>
          </div>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-pm">
            <span class="role-name"
              ><el-icon><User /></el-icon> 甲方项目经理</span
            >
          </div>
          <div class="person-item" v-for="p in todayPmPersons" :key="p.name">
            <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
            <div class="p-info">
              <div class="p-name">
                {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
              </div>
              <div class="p-time">{{ p.time }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 排班明细表格 -->
    <div class="card table-card">
      <div class="card-header">
        <div class="card-title">
          <el-icon><List /></el-icon>
          <span>{{ tableTitle }}</span>
        </div>
      </div>
      <div class="table-container">
        <el-table
          :data="scheduleTableData"
          height="100%"
          :span-method="scheduleSpanMethod"
          border
          class="duty-table"
          :row-class-name="tableRowClassName"
        >
          <el-table-column label="日期" :resizable="false" min-width="12%" align="center">
            <template #default="{ row }">
              <div class="date-cell-content">
                <span class="date-text">{{ row.dateDisplay }}</span>
                <span :class="['workday-badge', row.dayBadgeClass]">{{ row.dayBadgeText }}</span>
                <span v-if="row.isToday" class="date-today">今日</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="班次 (仅ECC分白/夜)" :resizable="false" min-width="15%" align="center">
            <template #default="{ row }">
              <span :class="['badge-shift', row.shiftClass]">{{ row.shiftText }}</span>
            </template>
          </el-table-column>
          <el-table-column label="ECC 指挥中心" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <div class="user-tag" v-if="row.ecc">
                <div class="user-tag-avatar" :style="{ background: row.eccColor }">{{ row.eccSurname }}</div>
                {{ row.ecc }}
              </div>
            </template>
          </el-table-column>
          <el-table-column label="系统运维 (白班)" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <div class="user-tag" v-if="row.sysOps && row.isSysOpsMaster">
                <div class="user-tag-avatar" :style="{ background: row.sysColor }">{{ row.sysSurname }}</div>
                {{ row.sysOps }}
              </div>
              <span v-else-if="!row.isSysOpsMaster" class="rest-text">休息 (按需支持)</span>
            </template>
          </el-table-column>
          <el-table-column label="网络运维 (白班)" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <div class="user-tag" v-if="row.netOps && row.isNetOpsMaster">
                <div class="user-tag-avatar" :style="{ background: row.netColor }">{{ row.netSurname }}</div>
                {{ row.netOps }}
              </div>
              <span v-else-if="!row.isNetOpsMaster" class="rest-text">休息 (按需支持)</span>
            </template>
          </el-table-column>
          <el-table-column label="甲方 PM" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <div class="user-tag" v-if="row.pm && row.isPmMaster">
                <div class="user-tag-avatar" :style="{ background: row.pmColor }">{{ row.pmSurname }}</div>
                {{ row.pm }}
              </div>
              <span v-else-if="!row.isPmMaster">-</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" :resizable="false" align="center" min-width="13%">
            <template #default> <a class="action-link">编辑</a><a class="action-link">调班</a> </template>
          </el-table-column>
        </el-table>
      </div>
    </div>

    <!-- 日历弹窗 -->
    <el-dialog v-model="workdayModalVisible" title="日历" width="500px" center :close-on-click-modal="false">
      <p class="workday-tip">
        系统自动识别工作日、休息日和法定节假日（含调休），截止到2026年12月，颜色标记说明：
        <span class="workday-badge badge-workday">工作日</span>
        <span class="workday-badge badge-rest">休息日</span>
        <span class="workday-badge badge-holiday">法定假日</span>
      </p>
      <div class="month-nav">
        <button class="nav-week-btn" @click="workdayMonthNav(-1)">
          <el-icon><ArrowLeft /></el-icon>
        </button>
        <div class="month-selects">
          <el-select v-model="workdayYear" @change="onYearMonthChange" style="width: 90px" size="small">
            <el-option v-for="y in yearOptions" :key="y" :label="y + '年'" :value="y" />
          </el-select>
          <el-select v-model="workdayMonthSelect" @change="onYearMonthChange" style="width: 80px" size="small">
            <el-option v-for="m in monthOptions" :key="m.value" :label="m.label" :value="m.value" />
          </el-select>
        </div>
        <button class="nav-week-btn" @click="workdayMonthNav(1)">
          <el-icon><ArrowRight /></el-icon>
        </button>
      </div>
      <div class="weekday-header">
        <span v-for="(w, idx) in weekDays" :key="idx" :class="{ weekend: idx >= 5 }">{{ w }}</span>
      </div>
      <div class="workday-calendar-grid">
        <div v-for="i in workdayStartDow" :key="'empty-' + i" class="cal-empty-cell"></div>
        <div v-for="d in workdayDaysInMonth" :key="'day-' + d" class="cal-day-cell" :style="getCalDayStyle(d)">
          {{ d }}
          <span v-if="getDayHolidayName(d)" class="holiday-name">{{ getDayHolidayName(d) }}</span>
        </div>
      </div>
      <div class="workday-legend">
        <div><span class="legend-block" style="background: #dbeafe; border: 1px solid #bfdbfe"></span> 工作日（默认周一至五）</div>
        <div><span class="legend-block" style="background: #fef3c7; border: 1px solid #fde68a"></span> 休息日（默认周六日）</div>
        <div><span class="legend-block" style="background: #fce7f3; border: 1px solid #fbcfe8"></span> 法定假日</div>
      </div>
    </el-dialog>

    <!-- 新增排班弹窗 -->
    <el-dialog v-model="addDutyModalVisible" center title="新增排班" width="580px" :close-on-click-modal="false" @close="closeAddDutyModal">
      <div class="modal-tabs">
        <div :class="['modal-tab', { active: addDutyTab === 'excel' }]" @click="addDutyTab = 'excel'">Excel 批量导入</div>
        <div :class="['modal-tab', { active: addDutyTab === 'manual' }]" @click="addDutyTab = 'manual'">手动配置排班</div>
      </div>
      <div v-show="addDutyTab === 'excel'" class="upload-area-box">
        <el-icon class="upload-icon" :size="48"><UploadFilled /></el-icon>
        <div class="upload-title-text">点击或将 Excel 文件拖拽到此处</div>
        <div class="upload-desc-text">支持 .xlsx, .xls 格式，最大 5MB</div>
        <a href="#" class="download-tmpl-link">↓ 下载排班标准导入模板.xlsx</a>
      </div>
      <div v-show="addDutyTab === 'manual'" class="manual-form">
        <el-form ref="manualFormRef" :model="manualForm" :rules="manualFormRules" label-width="140px" size="small">
          <el-form-item label="排班日期" prop="date"
            ><el-date-picker v-model="manualForm.date" type="date" value-format="YYYY-MM-DD" style="width: 100%"
          /></el-form-item>
          <el-row :gutter="12">
            <el-col :span="12">
              <el-form-item label="ECC (白班)" prop="eccDay"
                ><el-select v-model="manualForm.eccDay" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadEccPersonnel"
                  ><el-option v-for="u in eccUserOptions" :key="u.id" :label="u.name" :value="u" /></el-select
              ></el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="ECC (夜班)" prop="eccNight"
                ><el-select v-model="manualForm.eccNight" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadEccPersonnel"
                  ><el-option v-for="u in eccUserOptions" :key="u.id" :label="u.name" :value="u" /></el-select
              ></el-form-item>
            </el-col>
          </el-row>
          <el-form-item label="系统运维 (白班)" prop="sysOps"
            ><el-select v-model="manualForm.sysOps" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadSysPersonnel"
              ><el-option v-for="u in sysUserOptions" :key="u.id" :label="u.name" :value="u" /></el-select
          ></el-form-item>
          <el-form-item label="网络运维 (白班)" prop="netOps"
            ><el-select v-model="manualForm.netOps" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadNetPersonnel"
              ><el-option v-for="u in netUserOptions" :key="u.id" :label="u.name" :value="u" /></el-select
          ></el-form-item>
          <el-form-item label="甲方 PM" prop="pm"
            ><el-select v-model="manualForm.pm" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadPmPersonnel"
              ><el-option v-for="u in pmUserOptions" :key="u.id" :label="u.name" :value="u" /></el-select
          ></el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="closeAddDutyModal">取消</el-button>
        <el-button type="primary" @click="saveManualDuty">确认保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.duty-page {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 16px 24px;
  height: 100%;
  box-sizing: border-box;
  overflow-y: auto;
  user-select: none;
  --primary: #2563eb;
  --primary-light: #3b82f6;
  --primary-bg: #eff6ff;
  --primary-border: #bfdbfe;
  --purple: #7c3aed;
  --cyan: #0891b2;
  --warning: #f59e0b;
  --danger: #dc2626;
  --success: #16a34a;
  --text-1: #0f172a;
  --text-2: #334155;
  --text-3: #64748b;
  --text-4: #94a3b8;
  --bg-page: #f1f5f9;
  --bg-card: #ffffff;
  --border: #e2e8f0;
  --border-light: #f1f5f9;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.04);
  --radius: 10px;
  --radius-sm: 6px;
  --warning-bg: #fffbeb;
  --warning-border: #fde68a;
  --danger-bg: #fef2f2;
  --danger-border: #fecaca;
  --success-bg: #f0fdf4;
  --success-border: #bbf7d0;
  --bg-sidebar: #0f172a;
}

/* 工具栏 */
.page-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
  flex-shrink: 0;
}
.page-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-1);
  margin: 0;
}
.toolbar-actions {
  display: flex;
  gap: 10px;
}

/* 按钮 */
.btn-outline {
  border: 1px solid var(--border) !important;
  color: var(--text-2) !important;
  background: var(--bg-card) !important;
}
.btn-outline:hover {
  border-color: var(--primary) !important;
  color: var(--primary) !important;
}
.btn-primary-custom {
  background: var(--primary) !important;
  border-color: var(--primary) !important;
}
.btn-primary-custom:hover {
  background: var(--primary-light) !important;
}
.ml-auto {
  margin-left: auto;
}

/* 筛选栏 */
.filter-bar {
  background: var(--bg-card);
  padding: 10px 16px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  display: flex;
  gap: 16px;
  align-items: center;
  flex-shrink: 0;
}
.period-switch {
  display: flex;
  background: var(--bg-page);
  padding: 3px;
  border-radius: 8px;
  border: 1px solid var(--border);
}
.period-btn {
  padding: 5px 18px;
  font-size: 13px;
  color: var(--text-3);
  cursor: pointer;
  border-radius: 5px;
  font-weight: 500;
  border: none;
  background: none;
  white-space: nowrap;
  transition: all 0.25s;
}
.period-btn:hover {
  color: var(--text-2);
}
.period-btn.active {
  background: var(--bg-card);
  color: var(--primary);
  box-shadow: var(--shadow-sm);
}
.week-indicator {
  font-size: 13px;
  color: var(--primary);
  font-weight: 600;
  background: var(--primary-bg);
  padding: 5px 14px;
  border-radius: 6px;
  border: 1px solid var(--primary-border);
  white-space: nowrap;
}
.custom-range {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0.4;
  pointer-events: none;
  transition: all 0.3s;
  overflow: hidden;
  height: 0;
}
.custom-range.enabled {
  opacity: 1;
  pointer-events: auto;
  height: auto;
  overflow: visible;
}
.nav-week-btn {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-3);
  flex-shrink: 0;
  padding: 0;
}
.nav-week-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.filter-date-picker {
  width: 130px;
}
.range-sep {
  color: var(--text-4);
  font-size: 13px;
}

/* 卡片 */
.card {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  flex-shrink: 0;
}
.card-header {
  padding: 10px 16px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fafafa;
}
.card-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 今日值班卡片 */
.today-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  padding: 12px 16px;
}
.duty-role-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  box-shadow: var(--shadow-sm);
}
.role-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px dashed var(--border);
  padding-bottom: 6px;
  margin-bottom: 2px;
}
.role-name {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-2);
  display: flex;
  align-items: center;
  gap: 6px;
}
.r-ecc {
  color: var(--primary);
}
.r-sys {
  color: var(--purple);
}
.r-net {
  color: var(--cyan);
}
.r-pm {
  color: var(--warning);
}
.person-item {
  display: flex;
  align-items: center;
  gap: 8px;
}
.p-avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 12px;
  flex-shrink: 0;
  color: #fff;
}
.p-info {
  flex: 1;
}
.p-name {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-1);
  display: flex;
  align-items: center;
  gap: 6px;
}
.p-time {
  font-size: 11px;
  color: var(--text-3);
  font-family: monospace;
  margin-top: 2px;
}

/* 班次标签 */
.badge-shift {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
}
.shift-day {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}
.shift-night {
  background: var(--bg-sidebar);
  color: var(--text-4);
  border: 1px solid var(--text-2);
}

/* 工作日标签 */
.workday-badge {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
  margin-left: 6px;
  display: inline-block;
}
.badge-rest {
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fde68a;
}
.badge-workday {
  background: #dbeafe;
  color: #1e40af;
  border: 1px solid #bfdbfe;
}
.badge-holiday {
  background: #fce7f3;
  color: #9d174d;
  border: 1px solid #fbcfe8;
}
.date-today {
  display: inline-block;
  background: var(--primary);
  color: #fff;
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  margin-top: 4px;
  font-weight: normal;
}

/* 排班表格 */
.table-card {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.table-container {
  flex: 1;
  overflow: auto;
}
.duty-table :deep(.el-table__header th) {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-3);
  background: #fafafa;
  white-space: nowrap;
  padding: 10px 16px;
}
.duty-table :deep(.el-table__body td) {
  font-size: 13px;
  padding: 10px 16px;
}
.duty-table :deep(.rest-day-row td) {
  background: #fef9f0;
}
.duty-table :deep(.today-row td) {
  background: rgb(165 179 237 / 0.6);
}
.duty-table :deep(.rest-day-row .date-cell-content) {
  color: var(--text-3);
}
.date-cell-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}
.date-text {
  font-weight: 600;
  color: var(--text-1);
  font-size: 13px;
}
.user-tag {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  padding: 3px 8px;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1;
  vertical-align: middle;
}
.user-tag-avatar {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: bold;
  color: #fff;
}
.rest-text {
  color: var(--text-4);
  font-size: 12px;
}
.action-link {
  color: var(--primary);
  cursor: pointer;
  font-size: 12px;
  margin-right: 10px;
}
.action-link:hover {
  text-decoration: underline;
}

/* 模态框 - 工作日维护 */
.workday-tip {
  font-size: 13px;
  color: var(--text-3);
  margin-bottom: 16px;
  line-height: 1.6;
}
.month-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  gap: 12px;
}
.month-selects {
  display: flex;
  gap: 6px;
  flex: 1;
  justify-content: center;
}
.month-label {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-1);
}
.weekday-header {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
  margin-bottom: 4px;
}
.weekday-header span {
  text-align: center;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-4);
  padding: 4px;
}
.weekday-header span.weekend {
  color: var(--danger);
}
.workday-calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}
.cal-empty-cell {
  height: 36px;
}
.cal-day-cell {
  height: 48px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  transition: all 0.15s;
  position: relative;
  gap: 2px;
}
.workday-legend {
  display: flex;
  gap: 16px;
  margin-top: 16px;
  padding-top: 12px;
  border-top: 1px solid var(--border-light);
}
.workday-legend div {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--text-3);
}
.legend-block {
  width: 12px;
  height: 12px;
  border-radius: 3px;
  display: inline-block;
}
.holiday-name {
  font-size: 9px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

/* 新增排班弹窗 */
.modal-tabs {
  display: flex;
  border-bottom: 1px solid var(--border);
  margin-bottom: 20px;
}
.modal-tab {
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-3);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}
.modal-tab.active {
  color: var(--primary);
  border-bottom-color: var(--primary);
}
.upload-area-box {
  border: 2px dashed var(--border);
  border-radius: 8px;
  padding: 40px 20px;
  text-align: center;
  background: var(--bg-page);
  cursor: pointer;
  transition: all 0.2s;
}
.upload-area-box:hover {
  border-color: var(--primary);
  background: var(--primary-bg);
}
.upload-icon {
  color: var(--primary-light);
  margin-bottom: 10px;
}
.upload-title-text {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-1);
  margin-bottom: 4px;
}
.upload-desc-text {
  font-size: 12px;
  color: var(--text-4);
}
.download-tmpl-link {
  display: inline-block;
  margin-top: 16px;
  font-size: 12px;
  color: var(--primary);
  text-decoration: none;
}
.download-tmpl-link:hover {
  text-decoration: underline;
}
.manual-form {
  padding: 10px 0;
}
</style>
