<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { Plus, ArrowLeft, ArrowRight, Calendar, Monitor, Connection, User, List, UploadFilled, Download, InfoFilled } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { HolidayUtil } from 'lunar-javascript'
import * as XLSX from 'xlsx'
import { getEcc, getSys, getNet, getPM, saveDuty, getDuty, updateDuty } from '@/api/dutyPageInterface.js'
import {
  eccDayPersonnel,
  eccNightPersonnel,
  sysOpsPersonnel,
  netOpsPersonnel,
  pmPersonnel,
  resetDutyScheduleData,
} from '@/utils/dutyPageData.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
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
    label: formatDt(monday) + ' ~ ' + formatDt(sunday) + '  第' + weekNum + '周',
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
    // 从后端获取本周排班数据，同时更新表格和今日值班
    fetchScheduleData()
  }
}

const shiftCustomWeek = (dir) => {
  // 日期被清空时，回退到本周的起止日期
  if (!customStart.value || !customEnd.value) {
    const weekRange = getWeekRange()
    customStart.value = weekRange.startFull
    customEnd.value = weekRange.endFull
  }
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
  ElMessage.closeAll()
  tableTitle.value = '排班明细 (' + customStart.value + ' 至 ' + customEnd.value + ')'
  fetchScheduleData(customStart.value, customEnd.value)
  ElMessage.success('已切换至自定义日期范围')
}

// ============ 今日值班 ============
const todayStr = computed(() => {
  const d = new Date()
  const weekNames = ['日', '一', '二', '三', '四', '五', '六']
  return d.getMonth() + 1 + '月' + d.getDate() + '日 星期' + weekNames[d.getDay()]
})

const todayDateStr = computed(() => new Date().toISOString().split('T')[0])

const todayDayType = computed(() => getDayType(todayDateStr.value))

const todayIsRestDay = computed(() => todayDayType.value === 'rest' || todayDayType.value === 'holiday')

// 今日值班数据（从 API 动态获取）
const todayEccPersons = ref([])
const todaySysPersons = ref([])
const todayNetPersons = ref([])
const todayPmPersons = ref([])

// 从后端获取指定范围排班数据，同时更新排班表格和今日值班展示
const fetchScheduleData = async (startDate, endDate) => {
  try {
    // 支持传入自定义日期范围，未传入则使用本周范围（并更新今日值班）
    const isWeekMode = !startDate && !endDate
    const range = isWeekMode
      ? getWeekRange()
      : { startFull: startDate, endFull: endDate }
    const result = await getDuty([range.startFull, range.endFull])

    if (result && Array.isArray(result)) {
      const todayStr = new Date().toISOString().split('T')[0]

      // 仅本周模式清空并更新今日值班
      if (isWeekMode) {
        todayEccPersons.value = []
        todaySysPersons.value = []
        todayNetPersons.value = []
        todayPmPersons.value = []
      }

      const tableRows = []

      result.forEach((record) => {
        const dateStr = record.scheduleDate || record.schedule_date
        if (!dateStr) return

        const d = new Date(dateStr)
        const dow = d.getDay()
        const dayOfWeek = dow === 0 ? 6 : dow - 1
        const dateDisplay = `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} (周${weekDaysNames[dayOfWeek]})`
        const isToday = dateStr === todayStr
        const dayType = getDayType(dateStr)
        const holidayName = getDayHolidayNameByDateStr(dateStr)

        const dayBadgeClass =
          dayType === 'rest' ? 'badge-rest' : dayType === 'holiday' ? 'badge-holiday' : 'badge-workday'
        const dayBadgeText =
          dayType === 'rest' ? '休息日' : dayType === 'holiday' ? holidayName || '法定假日' : '工作日'

        const eccDayName = record.eccDayPersonnelName || ''
        const eccDayId = record.eccDayPersonnelId || record.ecc_day_personnel_id || ''
        const eccNightName = record.eccNightPersonnelName || ''
        const eccNightId = record.eccNightPersonnelId || record.ecc_night_personnel_id || ''
        const sysName = record.sysOpsPersonnelName || ''
        const sysId = record.sysOpsPersonnelId || record.sys_ops_personnel_id || ''
        const netName = record.netOpsPersonnelName || ''
        const netId = record.netOpsPersonnelId || record.net_ops_personnel_id || ''
        const pmName = record.pmPersonnelName || ''
        const pmId = record.pmPersonnelId || record.pm_personnel_id || ''

        // 白班行
        tableRows.push({
          id: dateStr + '-D',
          date: dateStr,
          dateDisplay: dateDisplay,
          isToday: isToday,
          dayType: dayType,
          shift: 'day',
          shiftText: '白班 08:00-20:00',
          shiftClass: 'shift-day',
          dayBadgeClass: dayBadgeClass,
          dayBadgeText: dayBadgeText,
          ecc: eccDayName,
          eccSurname: eccDayName ? getSurname(eccDayName) : '',
          eccColor: eccDayName ? 'var(--primary)' : '',
          eccId: eccDayId,
          sysOps: sysName,
          sysSurname: sysName ? getSurname(sysName) : '',
          sysColor: sysName ? 'var(--purple)' : '',
          sysId: sysId,
          isSysOpsMaster: !!sysName,
          netOps: netName,
          netSurname: netName ? getSurname(netName) : '',
          netColor: netName ? 'var(--cyan)' : '',
          netId: netId,
          isNetOpsMaster: !!netName,
          pm: pmName,
          pmSurname: pmName ? getSurname(pmName) : '',
          pmColor: pmName ? 'var(--warning)' : '',
          pmId: pmId,
          isPmMaster: !!pmName,
        })

        // 夜班行
        tableRows.push({
          id: dateStr + '-N',
          date: dateStr,
          dateDisplay: '',
          isToday: isToday,
          dayType: dayType,
          shift: 'night',
          shiftText: '夜班 20:00-08:00',
          shiftClass: 'shift-night',
          dayBadgeClass: dayBadgeClass,
          dayBadgeText: dayBadgeText,
          ecc: eccNightName,
          eccSurname: eccNightName ? getSurname(eccNightName) : '',
          eccColor: eccNightName ? 'var(--text-3)' : '',
          eccId: eccNightId,
          sysOps: sysName,
          sysSurname: sysName ? getSurname(sysName) : '',
          sysColor: sysName ? 'var(--purple)' : '',
          isSysOpsMaster: false,
          netOps: netName,
          netSurname: netName ? getSurname(netName) : '',
          netColor: netName ? 'var(--cyan)' : '',
          isNetOpsMaster: false,
          pm: pmName,
          pmSurname: pmName ? getSurname(pmName) : '',
          pmColor: pmName ? 'var(--warning)' : '',
          isPmMaster: false,
        })

        // 仅本周模式更新今日值班
        if (isWeekMode && isToday) {
          if (eccDayName) {
            todayEccPersons.value.push({
              name: eccDayName,
              surname: getSurname(eccDayName),
              avatarColor: 'var(--primary)',
              shiftClass: 'shift-day',
              shiftLabel: '白',
              time: '08:00 - 20:00',
            })
          }
          if (eccNightName) {
            todayEccPersons.value.push({
              name: eccNightName,
              surname: getSurname(eccNightName),
              avatarColor: 'var(--text-3)',
              shiftClass: 'shift-night',
              shiftLabel: '夜',
              time: '20:00 - 08:00',
            })
          }
          todaySysPersons.value = sysName
            ? [
                {
                  name: sysName,
                  surname: getSurname(sysName),
                  avatarColor: 'var(--purple)',
                  shiftClass: 'shift-day',
                  shiftLabel: '白',
                  time: '08:30 - 18:00',
                },
              ]
            : []
          todayNetPersons.value = netName
            ? [
                {
                  name: netName,
                  surname: getSurname(netName),
                  avatarColor: 'var(--cyan)',
                  shiftClass: 'shift-day',
                  shiftLabel: '白',
                  time: '08:30 - 18:00',
                },
              ]
            : []
          todayPmPersons.value = pmName
            ? [
                {
                  name: pmName,
                  surname: getSurname(pmName),
                  avatarColor: 'var(--warning)',
                  shiftClass: 'shift-day',
                  shiftLabel: '全',
                  time: '08:30 - 18:00',
                },
              ]
            : []
        }
      })

      // 填充查询范围内缺失的日期（无排班数据的天数也显示在表格中）
      const existingDates = new Set(tableRows.map(r => r.date))
      const startDate = new Date(range.startFull)
      const endDate = new Date(range.endFull)
      const cursor = new Date(startDate)
      while (cursor <= endDate) {
        const dateStr = formatDateStr(cursor)
        if (!existingDates.has(dateStr)) {
          const d = new Date(dateStr)
          const dow = d.getDay()
          const dayOfWeek = dow === 0 ? 6 : dow - 1
          const dateDisplay = `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} (周${weekDaysNames[dayOfWeek]})`
          const isToday = dateStr === todayStr
          const dayType = getDayType(dateStr)
          const holidayName = getDayHolidayNameByDateStr(dateStr)
          const dayBadgeClass = dayType === 'rest' ? 'badge-rest' : dayType === 'holiday' ? 'badge-holiday' : 'badge-workday'
          const dayBadgeText = dayType === 'rest' ? '休息日' : dayType === 'holiday' ? holidayName || '法定假日' : '工作日'

          const emptyRow = {
            eccSurname: '',
            eccColor: '',
            eccId: '',
            sysSurname: '',
            sysColor: '',
            sysId: '',
            isSysOpsMaster: false,
            netOps: '',
            netSurname: '',
            netColor: '',
            netId: '',
            isNetOpsMaster: false,
            pm: '',
            pmSurname: '',
            pmColor: '',
            pmId: '',
            isPmMaster: false,
          }

          // 白班行
          tableRows.push({
            ...emptyRow,
            id: dateStr + '-D',
            date: dateStr,
            dateDisplay: dateDisplay,
            isToday: isToday,
            dayType: dayType,
            shift: 'day',
            shiftText: '白班 08:00-20:00',
            shiftClass: 'shift-day',
            dayBadgeClass: dayBadgeClass,
            dayBadgeText: dayBadgeText,
            ecc: '',
          })

          // 夜班行
          tableRows.push({
            ...emptyRow,
            id: dateStr + '-N',
            date: dateStr,
            dateDisplay: '',
            isToday: isToday,
            dayType: dayType,
            shift: 'night',
            shiftText: '夜班 20:00-08:00',
            shiftClass: 'shift-night',
            dayBadgeClass: dayBadgeClass,
            dayBadgeText: dayBadgeText,
            ecc: '',
          })
        }
        cursor.setDate(cursor.getDate() + 1)
      }

      // 按日期排序
      tableRows.sort((a, b) => a.date.localeCompare(b.date) || (a.shift === 'day' ? -1 : 1))
      scheduleTableData.value = tableRows
    }
  } catch (error) {
    console.error('获取排班数据失败:', error.message)
  }
}

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



// 示例排班表格数据（实际应从 API 获取）
const weekDaysNames = ['一', '二', '三', '四', '五', '六', '日']


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



const scheduleTableData = ref([])

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

// 月度排班数据(用于日历标记)
const monthDutyData = ref([])

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
  // 调用接口获取月度排班数据
  fetchMonthDutyData()
}

// 获取指定月份的排班数据
const fetchMonthDutyData = async () => {
  try {
    const year = workdayYear.value
    const month = workdayMonth.value + 1 // 转换为1-12

    // 计算月份第一天和最后一天
    const firstDay = `${year}-${String(month).padStart(2, '0')}-01`
    const lastDate = new Date(year, month, 0).getDate() // 获取该月最后一天
    const lastDay = `${year}-${String(month).padStart(2, '0')}-${String(lastDate).padStart(2, '0')}`

    const dateRange = [firstDay, lastDay]
    const result = await getDuty(dateRange)
    console.log('月度排班数据:', result,Array.isArray(result))

    // 存储排班数据
    if (result && Array.isArray(result)) {
      monthDutyData.value = result
      console.log("monthDutyData",monthDutyData)
    } else {
      console.log("monthDutyData",monthDutyData)
      monthDutyData.value = []
    }
  } catch (error) {
    console.error('获取月度排班数据失败:', error.message)
    monthDutyData.value = []
  }
}

// 判断某天是否有排班数据
const hasDutyOnDay = (day) => {
  const year = workdayYear.value
  const month = workdayMonth.value + 1
  const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`

  return monthDutyData.value.some(item => item.scheduleDate === dateStr)
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
  // 打开时重置为当前月份
  const now = new Date()
  workdayYear.value = now.getFullYear()
  workdayMonth.value = now.getMonth() // 0-indexed
  workdayMonthSelect.value = now.getMonth() + 1 // 1-indexed for select
  workdayModalVisible.value = true
  // 打开模态框时获取当前月份的排班数据
  fetchMonthDutyData()
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
  // 月份切换后获取新月份的排班数据
  fetchMonthDutyData()
}

// 权限状态管理
const permissionStore = usePermissionStore()

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
  }

  // 工作日时,系统运维和网络运维为必填
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

// 最新排班日期（用于控制手动排班日期可选范围）
const latestScheduleDate = ref('')

// 已排班的日期集合（用于禁用已排班日期，防止重复选择）
const scheduledDateSet = ref(new Set())

// 从值班表中获取最新排班日期
const fetchLatestScheduleDate = async () => {
  try {
    const result = await getDuty(['2000-01-01', '2099-12-31'])
    if (result && Array.isArray(result) && result.length > 0) {
      const dates = result.map(r => r.scheduleDate || r.schedule_date).filter(Boolean)
      if (dates.length > 0) {
        dates.sort()
        return dates[dates.length - 1]
      }
    }
  } catch (error) {
    console.error('获取最新排班日期失败:', error)
  }
  return null
}

// 排班日期禁用规则：仅禁止选择今天之前的日期
const disabledScheduleDate = (time) => {
  const today = new Date()
  const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
  const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  return timeDate.getTime() < todayDate.getTime()
}

// Excel导入区域的日期提示文本
const excelDateRangeText = computed(() => {
  const base = latestScheduleDate.value
  if (!base) {
    const today = new Date().toISOString().split('T')[0]
    return `当前暂无排班数据，新增排班日期可从 ${today} 开始`
  }
  const nextDate = new Date(base)
  nextDate.setDate(nextDate.getDate() + 1)
  const nextStr = formatDateStr(nextDate)
  return `当前值班已排班至 ${base}，新增排班日期从 ${nextStr} 开始，可覆盖已有排班！`
})

const openAddDutyModal = async () => {
  addDutyModalVisible.value = true

  // 获取值班表中所有排班数据
  try {
    const result = await getDuty(['2000-01-01', '2099-12-31'])
    if (result && Array.isArray(result)) {
      const allDates = result.map(r => r.scheduleDate || r.schedule_date).filter(Boolean)
      // 存储已排班日期集合
      scheduledDateSet.value = new Set(allDates)

      // 获取最新排班日期
      if (allDates.length > 0) {
        allDates.sort()
        const latestDate = allDates[allDates.length - 1]
        const today = new Date().toISOString().split('T')[0]

        latestScheduleDate.value = latestDate

        if (latestDate >= today) {
          // 排班日期默认值为最新排班日期的后一天
          const nextDate = new Date(latestDate)
          nextDate.setDate(nextDate.getDate() + 1)
          manualForm.date = formatDateStr(nextDate)
        } else {
          manualForm.date = today
        }
      } else {
        // 没有排班数据
        latestScheduleDate.value = ''
        scheduledDateSet.value = new Set()
        manualForm.date = new Date().toISOString().split('T')[0]
      }
    }
  } catch (error) {
    console.error('获取排班数据失败:', error)
    latestScheduleDate.value = ''
    scheduledDateSet.value = new Set()
    manualForm.date = new Date().toISOString().split('T')[0]
  }
}

// 下拉框聚焦时加载数据
// 排班日期变化时，自动获取当天的排班数据并填充到表单
watch(() => manualForm.date, async (newDate) => {
  if (!newDate || !addDutyModalVisible.value) return

  // 先确保所有人员选项数据已加载，el-select 才能正确显示中文名称
  await Promise.all([
    loadEccPersonnel(),
    loadSysPersonnel(),
    loadNetPersonnel(),
    loadPmPersonnel(),
  ])

  try {
    const result = await getDuty([newDate, newDate])
    if (result && Array.isArray(result) && result.length > 0) {
      const record = result[0]
      manualForm.eccDay = record.eccDayPersonnelId || record.ecc_day_personnel_id || ''
      manualForm.eccNight = record.eccNightPersonnelId || record.ecc_night_personnel_id || ''
      manualForm.sysOps = record.sysOpsPersonnelId || record.sys_ops_personnel_id || ''
      manualForm.netOps = record.netOpsPersonnelId || record.net_ops_personnel_id || ''
      manualForm.pm = record.pmPersonnelId || record.pm_personnel_id || ''
    } else {
      // 当天没有排班数据，清空表单
      manualForm.eccDay = ''
      manualForm.eccNight = ''
      manualForm.sysOps = ''
      manualForm.netOps = ''
      manualForm.pm = ''
    }
  } catch (error) {
    console.error('获取当日排班数据失败:', error)
  }
})

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

  // 将表单数据转换为数组格式,每条对象是一天的排班数据
  const dutyScheduleArray = [
    {
      schedule_date: manualForm.date || '',
      ecc_day_personnel_id: manualForm.eccDay || '',
      ecc_night_personnel_id: manualForm.eccNight || '',
      sys_ops_personnel_id: manualForm.sysOps || '',
      net_ops_personnel_id: manualForm.netOps || '',
      pm_personnel_id: manualForm.pm || '',
      created_by: currentUser,
      updated_by: currentUser,
    },
  ]

  try {
    await saveDuty(dutyScheduleArray)
    ElMessage.success('排班已保存')
    addDutyModalVisible.value = false
    // 重置数据模型
    resetDutyScheduleData()
    // 立即刷新排班表格和今日值班
    fetchScheduleData()
  } catch (error) {
    ElMessage.error('保存排班失败: ' + error.message)
  }
}

// 关闭弹窗时重置数据
const closeAddDutyModal = () => {
  addDutyModalVisible.value = false
  // 清空表单中的已选值
  const baseStr = latestScheduleDate.value
  if (baseStr) {
    const nextDate = new Date(baseStr)
    nextDate.setDate(nextDate.getDate() + 1)
    manualForm.date = formatDateStr(nextDate)
  } else {
    manualForm.date = new Date().toISOString().split('T')[0]
  }
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
  // 清空已排班日期集合
  scheduledDateSet.value = new Set()
  // 清空Excel导入的数据
  excelImportData.value = []
}

// ============ 编辑模式（表格内联编辑与调班保存）============
const editingDate = ref(null)
const editForm = reactive({
  schedule_date: '',
  ecc_day_personnel_id: '',
  ecc_night_personnel_id: '',
  sys_ops_personnel_id: '',
  net_ops_personnel_id: '',
  pm_personnel_id: '',
})

// 根据选中选项文本动态计算下拉框宽度
const getEditSelectWidth = (value, options, placeholder) => {
  const option = options.find(o => o.userCode === value)
  const text = option ? option.name : placeholder
  // 12px 字体下：中文字符约12px宽，ASCII约7.2px宽
  let textWidth = 0
  for (const ch of text) {
    textWidth += ch.charCodeAt(0) > 127 ? 12 : 7.2
  }
  // padding(16px) + caret(~14px) + border(2px) + buffer(4px) = 36px
  const total = Math.ceil(textWidth + 36)
  return { width: total + 'px', minWidth: total + 'px' }
}

// 判断该日期是否有排班数据（用于控制调班按钮是否可点击）
const hasDutyData = (row) => {
  if (!row) return false
  const nightRow = scheduleTableData.value.find(r => r.date === row.date && r.shift === 'night')
  return !!(row.ecc || row.sysOps || row.netOps || row.pm || nightRow?.ecc)
}

// 开始编辑指定日期的排班
const startEdit = async (row) => {
  // 预加载所有人员选项数据，确保 el-select 渲染时 options 已就绪
  await Promise.all([
    loadEccPersonnel(),
    loadSysPersonnel(),
    loadNetPersonnel(),
    loadPmPersonnel(),
  ])

  const dayRow = scheduleTableData.value.find(r => r.date === row.date && r.shift === 'day')
  const nightRow = scheduleTableData.value.find(r => r.date === row.date && r.shift === 'night')
  if (!dayRow) return

  editingDate.value = row.date
  editForm.schedule_date = row.date
  editForm.ecc_day_personnel_id = dayRow.eccId || dayRow.ecc || ''
  editForm.ecc_night_personnel_id = nightRow?.eccId || nightRow?.ecc || ''
  editForm.sys_ops_personnel_id = dayRow.sysId || dayRow.sysOps || ''
  editForm.net_ops_personnel_id = dayRow.netId || dayRow.netOps || ''
  editForm.pm_personnel_id = dayRow.pmId || dayRow.pm || ''
}

// 取消编辑
const cancelEdit = () => {
  editingDate.value = null
}

// 保存调班
const saveEdit = async () => {
  try {
    const currentUser = authStore.user || ''
    const updateData = {
      schedule_date: editForm.schedule_date,
      ecc_day_personnel_id: editForm.ecc_day_personnel_id,
      ecc_night_personnel_id: editForm.ecc_night_personnel_id,
      sys_ops_personnel_id: editForm.sys_ops_personnel_id,
      net_ops_personnel_id: editForm.net_ops_personnel_id,
      pm_personnel_id: editForm.pm_personnel_id,
      updated_by: currentUser,
    }

    await updateDuty(updateData)
    ElMessage.success('调班保存成功')
    editingDate.value = null
    // 刷新排班数据
    fetchScheduleData()
  } catch (error) {
    ElMessage.error('调班保存失败: ' + error.message)
  }
}

// ============ Excel 批量导入 ============
const excelImportData = ref([])
const excelFileInput = ref(null)

// 导出排班明细到Excel
const exportDutyTable = () => {
  // 按日期分组，合并白班和夜班
  const dateMap = {}
  scheduleTableData.value.forEach(row => {
    if (!dateMap[row.date]) {
      dateMap[row.date] = { day: null, night: null }
    }
    if (row.shift === 'day') {
      dateMap[row.date].day = row
    } else {
      dateMap[row.date].night = row
    }
  })

  // 构建导出数据，格式与导入模板一致
  const exportData = Object.keys(dateMap).sort().map(date => {
    const { day, night } = dateMap[date]
    return {
      '日期': day?.date || date,
      'ecc白班人员': day?.eccId || day?.ecc || '',
      'ecc夜班人员': night?.eccId || night?.ecc || '',
      '系统运维人员': day?.sysId || day?.sysOps || '',
      '网络运维人员': day?.netId || day?.netOps || '',
      '甲方PM': day?.pmId || day?.pm || '',
    }
  })

  // 创建工作簿
  const wb = XLSX.utils.book_new()
  const ws = XLSX.utils.json_to_sheet(exportData)

  // 设置列宽
  ws['!cols'] = [
    { wch: 16 }, // 日期
    { wch: 20 }, // ecc白班人员
    { wch: 20 }, // ecc夜班人员
    { wch: 20 }, // 系统运维人员
    { wch: 20 }, // 网络运维人员
    { wch: 20 }, // 甲方PM
  ]

  XLSX.utils.book_append_sheet(wb, ws, '排班明细')
  XLSX.writeFile(wb, '排班明细.xlsx')
  ElMessage.success('排班导出成功')
}

// 下载Excel模板
const downloadExcelTemplate = () => {
  // 创建工作簿
  const wb = XLSX.utils.book_new()

  // 创建模板数据(示例行)
  const templateData = [
    {
      日期: '格式:yyyy-mm-dd,例如:2026-01-01',
      ecc白班人员: '域账号,如:wuyanzu',
      ecc夜班人员: '域账号,如:wuyanzu',
      系统运维人员: '域账号,如:wuyanzu',
      网络运维人员: '域账号,如:wuyanzu',
      甲方PM: '域账号,如:wuyanzu',
    },
  ]

  // 创建工作表
  const ws = XLSX.utils.json_to_sheet(templateData)

  // 设置列宽
  ws['!cols'] = [
    { wch: 35 }, // 日期
    { wch: 25 }, // ecc白班人员
    { wch: 25 }, // ecc夜班人员
    { wch: 25 }, // 系统运维人员
    { wch: 25 }, // 网络运维人员
    { wch: 25 }, // 甲方PM
  ]

  // 设置标题行(第一行)的背景色为灰色,标识为说明行
  const range = XLSX.utils.decode_range(ws['!ref'] || 'A1')
  for (let col = range.s.c; col <= range.e.c; col++) {
    const cellAddress = XLSX.utils.encode_cell({ r: 0, c: col })
    if (ws[cellAddress]) {
      ws[cellAddress].s = {
        fill: { fgColor: { rgb: 'E8E8E8' } },
        font: { color: { rgb: '666666' }, bold: false },
      }
    }
  }

  // 将工作表添加到工作簿
  XLSX.utils.book_append_sheet(wb, ws, '排班模板')

  // 下载文件
  XLSX.writeFile(wb, '排班导入模板.xlsx')
  ElMessage.success('模板下载成功')
}

// 触发文件选择
const triggerFileSelect = () => {
  if (excelFileInput.value) {
    excelFileInput.value.click()
  }
}

// 处理Excel文件导入
const handleExcelFile = async (event) => {
  const file = event.target.files[0]
  if (!file) return

  // 验证文件类型
  const validExtensions = ['.xlsx', '.xls']
  const fileExtension = file.name.substring(file.name.lastIndexOf('.')).toLowerCase()

  if (!validExtensions.includes(fileExtension)) {
    ElMessage.error('请上传 .xlsx 或 .xls 格式的Excel文件')
    return
  }

  // 验证文件大小(5MB)
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.error('文件大小不能超过5MB')
    return
  }

  try {
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data, { type: 'array', cellDates: false })

    // 获取第一个工作表
    const firstSheetName = workbook.SheetNames[0]
    const worksheet = workbook.Sheets[firstSheetName]

    // 转换为JSON数据,使用原始值
    const jsonData = XLSX.utils.sheet_to_json(worksheet, { raw: true })

    if (jsonData.length === 0) {
      ElMessage.warning('Excel文件中没有数据')
      return
    }

    // 验证必需的列（ECC为必填，系统运维、网络运维、甲方PM为非必填）
    const requiredColumns = [
      '日期',
      'ecc白班人员',
      'ecc夜班人员',
    ]

    const firstRow = jsonData[0]
    const missingColumns = requiredColumns.filter((col) => !(col in firstRow))

    if (missingColumns.length > 0) {
      ElMessage.error(`Excel文件缺少必需的列: ${missingColumns.join(', ')}`)
      return
    }

    // 获取当前登录用户名
    const currentUser = authStore.user || ''

    // 转换数据格式,添加created_by和updated_by
    excelImportData.value = jsonData.map((row) => {
      // 处理日期格式
      let scheduleDate = row.日期 || ''
      if (typeof scheduleDate === 'number') {
        // Excel日期序列号转换为日期字符串(按天计算,忽略时间)
        // 使用标准公式: Unix时间戳 = (Excel序列号 - 25569) * 86400000
        // 25569 是 1970-01-01 对应的Excel序列号(已修正1900年闰年bug)
        const days = Math.floor(scheduleDate)
        const jsDate = new Date((days - 25569) * 86400000)
        // 使用UTC方法获取日期,避免时区问题
        scheduleDate = `${jsDate.getUTCFullYear()}-${String(jsDate.getUTCMonth() + 1).padStart(2, '0')}-${String(jsDate.getUTCDate()).padStart(2, '0')}`
      } else if (scheduleDate instanceof Date) {
        // 如果是Date对象,使用UTC转换为字符串
        scheduleDate = `${scheduleDate.getUTCFullYear()}-${String(scheduleDate.getUTCMonth() + 1).padStart(2, '0')}-${String(scheduleDate.getUTCDate()).padStart(2, '0')}`
      } else if (typeof scheduleDate === 'string') {
        // 如果是字符串,提取日期部分
        const dateMatch = scheduleDate.match(/(\d{4})[-/](\d{1,2})[-/](\d{1,2})/)
        if (dateMatch) {
          scheduleDate = `${dateMatch[1]}-${dateMatch[2].padStart(2, '0')}-${dateMatch[3].padStart(2, '0')}`
        }
      }

      return {
        schedule_date: scheduleDate,
        ecc_day_personnel_id: row.ecc白班人员 || '',
        ecc_night_personnel_id: row.ecc夜班人员 || '',
        sys_ops_personnel_id: row.系统运维人员 || '',
        net_ops_personnel_id: row.网络运维人员 || '',
        pm_personnel_id: row.甲方PM || '',
        created_by: currentUser,
        updated_by: currentUser,
      }
    })

    ElMessage.success(`成功导入 ${excelImportData.value.length} 条排班数据`)
  } catch (error) {
    ElMessage.error('读取Excel文件失败: ' + error.message)
  }

  // 清空文件输入,允许重复选择同一文件
  event.target.value = ''
}

// 保存Excel导入的数据
const saveExcelImport = async () => {
  if (excelImportData.value.length === 0) {
    ElMessage.closeAll()
    ElMessage.warning('请先导入Excel文件')
    return
  }

  try {
    await saveDuty(excelImportData.value)
    ElMessage.closeAll()
    ElMessage.success(`成功保存 ${excelImportData.value.length} 条排班数据`)
    addDutyModalVisible.value = false
    // 重置数据模型
    resetDutyScheduleData()
    excelImportData.value = []
    // 立即刷新排班表格和今日值班
    fetchScheduleData()
  } catch (error) {
    ElMessage.closeAll()
    ElMessage.error('保存排班失败: ' + error.message)
  }
}

// 统一保存入口,根据当前tab执行不同逻辑
const handleSave = () => {
  if (addDutyTab.value === 'manual') {
    saveManualDuty()
  } else {
    saveExcelImport()
  }
}

// ============ 初始化 ============
onMounted(async () => {
  // 页面加载时从后端获取本周排班数据
  fetchScheduleData()
})
</script>

<template>
  <div class="duty-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">排班与值班管理</h2>
      <div class="toolbar-actions">
        <el-button v-if="permissionStore.hasPermission('duty:export')" class="btn-outline" @click="exportDutyTable">导出排班</el-button>
        <el-button v-if="permissionStore.hasPermission('duty:create')" type="primary" class="btn-primary-custom" @click="openAddDutyModal">
          <el-icon><Plus /></el-icon>
          &nbsp;新增排班
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
        <el-date-picker v-model="customStart" type="date" placeholder="开始" value-format="YYYY-MM-DD" class="filter-date-picker" size="small" style="width: 100px" />
        <span class="range-sep">至</span>
        <el-date-picker v-model="customEnd" type="date" placeholder="结束" value-format="YYYY-MM-DD" class="filter-date-picker" size="small" style="width: 100px" />
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
          <template v-if="todayEccPersons.length > 0">
            <div class="person-item" v-for="p in todayEccPersons" :key="p.name">
              <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
              <div class="p-info">
                <div class="p-name">
                  {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
                </div>
                <div class="p-time">{{ p.time }}</div>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="person-item">
              <div class="p-avatar" style="background: var(--text-4);">—</div>
              <div class="p-info">
                <div class="p-name">
                  <span style="color: var(--text-4);">未排班</span>
                  <span class="badge-shift shift-day">白</span>
                </div>
                <div class="p-time" style="color: var(--text-4);">08:00 - 20:00</div>
              </div>
            </div>
            <div class="person-item">
              <div class="p-avatar" style="background: var(--text-4);">—</div>
              <div class="p-info">
                <div class="p-name">
                  <span style="color: var(--text-4);">未排班</span>
                  <span class="badge-shift shift-night">夜</span>
                </div>
                <div class="p-time" style="color: var(--text-4);">20:00 - 08:00</div>
              </div>
            </div>
          </template>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-sys">
            <span class="role-name"
              ><el-icon><Monitor /></el-icon> 系统运维</span
            >
          </div>
          <template v-if="todaySysPersons.length > 0">
            <div class="person-item" v-for="p in todaySysPersons" :key="p.name">
              <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
              <div class="p-info">
                <div class="p-name">
                  {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
                </div>
                <div class="p-time">{{ p.time }}</div>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="person-item">
              <div class="p-avatar" style="background: var(--text-4);">—</div>
              <div class="p-info">
                <div class="p-name">
                  <span style="color: var(--text-4);">未排班</span>
                  <span class="badge-shift shift-day">白</span>
                </div>
                <div class="p-time" style="color: var(--text-4);">08:30 - 18:00</div>
              </div>
            </div>
          </template>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-net">
            <span class="role-name"
              ><el-icon><Connection /></el-icon> 网络运维</span
            >
          </div>
          <template v-if="todayNetPersons.length > 0">
            <div class="person-item" v-for="p in todayNetPersons" :key="p.name">
              <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
              <div class="p-info">
                <div class="p-name">
                  {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
                </div>
                <div class="p-time">{{ p.time }}</div>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="person-item">
              <div class="p-avatar" style="background: var(--text-4);">—</div>
              <div class="p-info">
                <div class="p-name">
                  <span style="color: var(--text-4);">未排班</span>
                  <span class="badge-shift shift-day">白</span>
                </div>
                <div class="p-time" style="color: var(--text-4);">08:30 - 18:00</div>
              </div>
            </div>
          </template>
        </div>

        <div class="duty-role-card">
          <div class="role-header r-pm">
            <span class="role-name"
              ><el-icon><User /></el-icon> 甲方项目经理</span
            >
          </div>
          <template v-if="todayPmPersons.length > 0">
            <div class="person-item" v-for="p in todayPmPersons" :key="p.name">
              <div class="p-avatar" :style="{ background: p.avatarColor }">{{ p.surname }}</div>
              <div class="p-info">
                <div class="p-name">
                  {{ p.name }} <span :class="['badge-shift', p.shiftClass]">{{ p.shiftLabel }}</span>
                </div>
                <div class="p-time">{{ p.time }}</div>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="person-item">
              <div class="p-avatar" style="background: var(--text-4);">—</div>
              <div class="p-info">
                <div class="p-name">
                  <span style="color: var(--text-4);">未排班</span>
                  <span class="badge-shift shift-day">全</span>
                </div>
                <div class="p-time" style="color: var(--text-4);">08:30 - 18:00</div>
              </div>
            </div>
          </template>
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
              <template v-if="editingDate === row.date && row.shift === 'day'">
                <el-select class="edit-mode-select" v-model="editForm.ecc_day_personnel_id" :style="getEditSelectWidth(editForm.ecc_day_personnel_id, eccUserOptions, '选择白班')" placeholder="选择白班" size="small" @visible-change="loadEccPersonnel">
                  <el-option v-for="u in eccUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" />
                </el-select>
              </template>
              <template v-else-if="editingDate === row.date && row.shift === 'night'">
                <el-select class="edit-mode-select" v-model="editForm.ecc_night_personnel_id" :style="getEditSelectWidth(editForm.ecc_night_personnel_id, eccUserOptions, '选择夜班')" placeholder="选择夜班" size="small" @visible-change="loadEccPersonnel">
                  <el-option v-for="u in eccUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" />
                </el-select>
              </template>
              <div class="user-tag" v-else-if="row.ecc">
                <div class="user-tag-avatar" :style="{ background: row.eccColor }">{{ row.eccSurname }}</div>
                {{ row.ecc }}
              </div>
              <div class="user-tag" v-else>
                <div class="user-tag-avatar" style="background: var(--text-4);">—</div>
                <span class="rest-text">未排班</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="系统运维 (白班)" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <template v-if="editingDate === row.date && row.shift === 'day'">
                <el-select class="edit-mode-select" v-model="editForm.sys_ops_personnel_id" :style="getEditSelectWidth(editForm.sys_ops_personnel_id, sysUserOptions, '选择人员')" placeholder="选择人员" size="small" @visible-change="loadSysPersonnel">
                  <el-option v-for="u in sysUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" />
                </el-select>
              </template>
              <div class="user-tag" v-else-if="row.sysOps && row.isSysOpsMaster">
                <div class="user-tag-avatar" :style="{ background: row.sysColor }">{{ row.sysSurname }}</div>
                {{ row.sysOps }}
              </div>
              <div class="user-tag" v-else>
                <div class="user-tag-avatar" style="background: var(--text-4);">—</div>
                <span class="rest-text">{{ row.shift === 'night' || row.dayType === 'rest' || row.dayType === 'holiday' ? '休息 (按需支持)' : '未排班' }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="网络运维 (白班)" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <template v-if="editingDate === row.date && row.shift === 'day'">
                <el-select class="edit-mode-select" v-model="editForm.net_ops_personnel_id" :style="getEditSelectWidth(editForm.net_ops_personnel_id, netUserOptions, '选择人员')" placeholder="选择人员" size="small" @visible-change="loadNetPersonnel">
                  <el-option v-for="u in netUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" />
                </el-select>
              </template>
              <div class="user-tag" v-else-if="row.netOps && row.isNetOpsMaster">
                <div class="user-tag-avatar" :style="{ background: row.netColor }">{{ row.netSurname }}</div>
                {{ row.netOps }}
              </div>
              <div class="user-tag" v-else>
                <div class="user-tag-avatar" style="background: var(--text-4);">—</div>
                <span class="rest-text">{{ row.shift === 'night' || row.dayType === 'rest' || row.dayType === 'holiday' ? '休息 (按需支持)' : '未排班' }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="甲方 PM" :resizable="false" align="center" min-width="15%">
            <template #default="{ row }">
              <template v-if="editingDate === row.date && row.shift === 'day'">
                <el-select class="edit-mode-select" v-model="editForm.pm_personnel_id" :style="getEditSelectWidth(editForm.pm_personnel_id, pmUserOptions, '选择人员')" placeholder="选择人员" size="small" @visible-change="loadPmPersonnel">
                  <el-option v-for="u in pmUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" />
                </el-select>
              </template>
              <div class="user-tag" v-else-if="row.pm && row.isPmMaster">
                <div class="user-tag-avatar" :style="{ background: row.pmColor }">{{ row.pmSurname }}</div>
                {{ row.pm }}
              </div>
              <div class="user-tag" v-else>
                <div class="user-tag-avatar" style="background: var(--text-4);">—</div>
                <span class="rest-text">{{ row.shift === 'night' || row.dayType === 'rest' || row.dayType === 'holiday' ? '休息 (按需支持)' : '未排班' }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="操作" :resizable="false" align="center" min-width="13%">
            <template #default="{ row }">
              <template v-if="editingDate === row.date">
                <el-button type="info" size="small" round plain @click="cancelEdit">取消</el-button>
                <el-button type="success" size="small" round plain @click="saveEdit">保存调班</el-button>
              </template>
              <template v-else>
                <el-tooltip content="账号无调班权限" :disabled="permissionStore.hasPermission('duty:edit')" placement="top">
                  <el-button type="warning" size="small" round plain :disabled="!permissionStore.hasPermission('duty:edit') || !hasDutyData(row)" @click="startEdit(row)">
                    调班
                  </el-button>
                </el-tooltip>
              </template>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </div>

    <!-- 日历弹窗 -->
    <el-dialog v-model="workdayModalVisible" title="日历" width="500px" center :close-on-click-modal="false">
      <p class="workday-tip">
        系统自动识别工作日、休息日和法定节假日（含调休）。节假日数据基于 lunar-javascript 库内置的国务院放假安排，当前版本数据截止至2026年12月，2027年及之后年份需等国务院公布安排后更新库版本方可支持。颜色标记说明：
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
          <span v-if="hasDutyOnDay(d)" class="duty-badge">排</span>
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
      <div v-show="addDutyTab === 'excel'">
        <div class="excel-date-hint">
          <el-icon><InfoFilled /></el-icon>
          <span>{{ excelDateRangeText }}</span>
        </div>
        <div class="upload-area-box" @click="triggerFileSelect">
        <input ref="excelFileInput" type="file" accept=".xlsx,.xls" style="display: none" @change="handleExcelFile" />
        <el-icon class="upload-icon" :size="48"><UploadFilled /></el-icon>
        <div class="upload-title-text">点击或将 Excel 文件拖拽到此处</div>
        <div class="upload-desc-text">支持 .xlsx, .xls 格式,最大 5MB</div>
        <a href="#" class="download-tmpl-link" @click.stop="downloadExcelTemplate">
          <el-icon><Download /></el-icon>
          下载排班标准导入模板.xlsx
        </a>
        <div v-if="excelImportData.length > 0" class="import-info" @click.stop>
          <el-icon><List /></el-icon>
          已导入 {{ excelImportData.length }} 条数据
        </div>
        </div>
      </div>
      <div v-show="addDutyTab === 'manual'" class="manual-form">
        <div class="excel-date-hint">
          <el-icon><InfoFilled /></el-icon>
          <span>{{ excelDateRangeText }}</span>
        </div>
        <el-form ref="manualFormRef" :model="manualForm" :rules="manualFormRules" label-width="140px" size="small">
          <el-form-item label="排班日期" prop="date"
            ><el-date-picker v-model="manualForm.date" type="date" value-format="YYYY-MM-DD" style="width: 100%" :disabled-date="disabledScheduleDate"
          /></el-form-item>
          <el-row :gutter="12">
            <el-col :span="12">
              <el-form-item label="ECC (白班)" prop="eccDay"
                ><el-select v-model="manualForm.eccDay" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadEccPersonnel"
                  ><el-option v-for="u in eccUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" /></el-select
              ></el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="ECC (夜班)" prop="eccNight"
                ><el-select v-model="manualForm.eccNight" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadEccPersonnel"
                  ><el-option v-for="u in eccUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" /></el-select
              ></el-form-item>
            </el-col>
          </el-row>
          <el-form-item label="系统运维 (白班)" prop="sysOps"
            ><el-select v-model="manualForm.sysOps" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadSysPersonnel"
              ><el-option v-for="u in sysUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" /></el-select
          ></el-form-item>
          <el-form-item label="网络运维 (白班)" prop="netOps"
            ><el-select v-model="manualForm.netOps" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadNetPersonnel"
              ><el-option v-for="u in netUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" /></el-select
          ></el-form-item>
          <el-form-item label="甲方 PM" prop="pm"
            ><el-select v-model="manualForm.pm" clearable placeholder="请选择人员" style="width: 100%" @visible-change="loadPmPersonnel"
              ><el-option v-for="u in pmUserOptions" :key="u.userCode" :label="u.name" :value="u.userCode" /></el-select
          ></el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="closeAddDutyModal">取消</el-button>
        <el-button type="primary" @click="handleSave">确认保存</el-button>
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
  width: 100px !important;
  max-width: 100px !important;
}
.filter-date-picker :deep(.el-input__wrapper) {
  min-width: 100px !important;
  max-width: 100px !important;
  padding: 0 8px !important;
}
.filter-date-picker :deep(.el-input__inner) {
  font-size: 12px !important;
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
  line-height: 1;
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
.duty-table :deep(.el-table__row) {
  height: 48px;
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

/* 编辑模式下拉框样式 - 与非编辑模式 user-tag 视觉一致 */
.edit-mode-select {
  width: fit-content;
}
.edit-mode-select :deep(.el-input) {
  width: 100%;
}
.edit-mode-select :deep(.el-input__wrapper) {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 3px 8px;
  box-shadow: none !important;
}
.edit-mode-select :deep(.el-input__wrapper.is-focus),
.edit-mode-select :deep(.el-input__wrapper:hover) {
  box-shadow: none !important;
}
.edit-mode-select :deep(.el-input__inner) {
  font-size: 12px;
  line-height: 1;
  height: auto;
  min-height: auto;
  color: var(--text-1);
  padding: 0;
}
.edit-mode-select :deep(.el-select__caret) {
  font-size: 12px;
  color: var(--text-4);
}
.edit-mode-select :deep(.el-input__suffix-inner) {
  align-items: center;
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
.duty-badge {
  position: absolute;
  top: 2px;
  right: 2px;
  background: var(--primary);
  color: #fff;
  font-size: 9px;
  font-weight: 600;
  padding: 1px 4px;
  border-radius: 3px;
  line-height: 1;
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
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 16px;
  font-size: 12px;
  color: var(--primary);
  text-decoration: none;
}
.download-tmpl-link:hover {
  text-decoration: underline;
}
.excel-date-hint {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 12px;
  padding: 8px 12px;
  background: var(--warning-bg);
  border: 1px solid var(--warning-border);
  border-radius: 6px;
  font-size: 13px;
  color: #92400e;
}

.import-info {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 16px;
  padding: 12px;
  background: var(--primary-bg);
  border: 1px solid var(--primary-border);
  border-radius: 6px;
  font-size: 13px;
  color: var(--primary);
  font-weight: 500;
}
.manual-form {
  padding: 0;
}
</style>
