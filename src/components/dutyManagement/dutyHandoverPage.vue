<script setup>
import { ref, reactive, nextTick, onBeforeUnmount, onMounted } from 'vue'
import { Plus, User, UserFilled, Monitor, Document, Grid, Notebook, Check, Edit, Delete, CircleCheck, Upload, RefreshLeft, Message, Download, CopyDocument, Close, Tickets } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, ElInput, ElTooltip, ElTag } from 'element-plus'
import { getDuty, getEcc, getSys, getNet, getPM, getBatch, getService, getOtherDuty, deleteHandover, saveHandover, getHandovers, confirmHandovers, exportHandoverExcel } from '@/api/dutyPageInterface.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { RBAC_IP } from '@/utils/dutyPageData.js'

// 权限状态管理
const permissionStore = usePermissionStore()

// 按钮权限辅助函数：判断当前用户是否为卡片创建者
const isCardCreator = (item) => {
  return permissionStore.userInfo?.username && item.createUser &&
    permissionStore.userInfo.username === item.createUser
}

// 按钮权限辅助函数：判断当前用户是否为卡片接班人
const isCardReceiver = (item) => {
  return permissionStore.userInfo?.username && item.toUserCode &&
    permissionStore.userInfo.username === item.toUserCode
}

// ============ 筛选 ============
const filterRole = ref('')
const filterStatus = ref('')
const filterShiftType = ref('')

// 本地日期字符串：避免 toISOString 的 UTC 时区偏移问题（UTC+8 时区 0:00~7:00 会得到前一天日期）
const getLocalDateStr = (date = new Date()) => {
  const pad = n => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

// 默认日期范围：0:00~8:00 时为 [前天, 昨天]，其他时间为 [昨天, 今天]
const getDefaultDateRange = () => {
  const now = new Date()
  const today = getLocalDateStr(now)
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  const yesterdayStr = getLocalDateStr(yesterday)
  if (now.getHours() < 8) {
    const dayBeforeYesterday = new Date(now)
    dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2)
    return [getLocalDateStr(dayBeforeYesterday), today]
  }
  return [yesterdayStr, today]
}
const filterDate = ref(getDefaultDateRange())

// 后端数据映射为前端卡片结构
const mapBackendToCard = (item) => {
  const roleMap = { 1: { label: 'ECC 指挥中心', value: 'ecc' }, 2: { label: '系统运维', value: 'sys' }, 3: { label: '网络运维', value: 'net' }, 4: { label: '甲方PM', value: 'pm' } }
  const role = roleMap[item.personnelType] || roleMap[1]
  const status = item.status === 1 ? 'completed' : 'pending'
  const statusBadge = status === 'completed' ? 'status-completed' : 'status-pending'
  const statusIcon = status === 'completed' ? '✓' : '⏳'
  const statusText = status === 'completed' ? '已完成' : '待确认'

  let shiftType = item.shiftType || 1
  let shiftLabel = '', shiftClass = ''
  if (role.value === 'ecc') {
    shiftLabel = shiftType === 1 ? '白班 → 夜班' : '夜班 → 白班'
    shiftClass = shiftType === 1 ? 'shift-day' : 'shift-night'
  } else {
    shiftType = 3
    shiftLabel = '同组交接'
    shiftClass = 'shift-day'
  }

  // 按 sort_order 排序
  const sortByOrder = arr => (arr || []).slice().sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0))

  const systemStatus = sortByOrder(item.systemStatus).map(s => ({
    text: s.text || '',
    level: Number(s.level ?? 0),
    _uid: ++lineUidCounter.value,
  }))

  const todoItems = sortByOrder(item.todoItems).map(t => ({
    text: t.text || '',
    level: Number(t.level ?? 0),
    _uid: ++lineUidCounter.value,
    attachments: [],
  }))

  // 附件按 sort_order 排序并分配到待跟进事项
  const sortedAttachments = sortByOrder(item.attachments).map(a => ({
    name: a.name || '',
    url: RBAC_IP.value + (a.url || ''),
    file_size: Number(a.file_size || 0),
  }))
  if (sortedAttachments.length > 0) {
    // 若无待跟进事项则创建一个占位事项
    if (todoItems.length === 0) {
      todoItems.push({ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] })
    }
    const target = todoItems.find(t => t.text.trim()) || todoItems[todoItems.length - 1]
    target.attachments = sortedAttachments
  }

  // 兼容 to_personnel_id 字段名
  const toPersonnelId = item.toPersonnelId || item.to_personnel_id || ''

  // 头像颜色和角色描述
  const roleColors = {
    ecc: { primary: 'var(--primary)', secondary: 'var(--text-3)' },
    sys: { both: 'var(--purple)' },
    net: { both: 'var(--cyan)' },
    pm: { both: 'var(--warning)' },
  }
  const rcData = roleColors[role.value]
  let rc
  if (role.value === 'ecc') {
    rc = shiftType === 1
      ? { fromColor: rcData.primary, toColor: rcData.secondary, fromDesc: 'ECC 白班 · 07:00-19:00', toDesc: 'ECC 夜班 · 19:00-07:00' }
      : { fromColor: rcData.secondary, toColor: rcData.primary, fromDesc: 'ECC 夜班 · 19:00-07:00', toDesc: 'ECC 白班 · 07:00-19:00' }
  } else {
    rc = { fromColor: rcData.both, toColor: rcData.both, fromDesc: role.label + ' · 08:30-18:00', toDesc: role.label + ' · 08:30-18:00' }
  }


  const card = {
    isDraft: false,
    handoverId: item.handover_id || item.id || '',
    _cardId: 'card-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
    date: item.scheduleDate || item.date || '',
    role: role.label,
    roleValue: role.value,
    personnelType: item.personnelType,
    shiftType,
    shiftLabel,
    shiftClass,
    statusClass: status,
    statusBadgeClass: statusBadge,
    statusIcon,
    statusText,
    fromName: item.fromPersonnelName || '未排班',
    fromUserCode: item.fromPersonnelId || '',
    fromSurname: (item.fromPersonnelName || '').charAt(0) || '—',
    fromColor: rc.fromColor,
    fromRoleDesc: rc.fromDesc,
    toName: item.toPersonnelName || '未排班',
    toUserCode: toPersonnelId,
    toSurname: (item.toPersonnelName || '').charAt(0) || '—',
    toColor: rc.toColor,
    toRoleDesc: rc.toDesc,
    systemStatus,
    todoItems,
    handoverTime: item.handoverTime || '',
    confirmText: status === 'completed' ? '已确认' : '待确认',
    confirmColor: status === 'completed' ? 'var(--success)' : 'var(--warning)',
    confirmTime: item.confirmTime || '',
    createUserNickname: item.create_user_nickname || '',
    createUser: item.create_user || '',
    batchPersonA: item.batchPersonA || '未排班',
    batchPersonACode: item.batchPersonACode || '',
    batchPersonASurname: item.batchPersonASurname || (item.batchPersonA ? item.batchPersonA.charAt(0) : '—'),
    batchPersonAEditing: false,
    batchPersonB: item.batchPersonB || '未排班',
    batchPersonBCode: item.batchPersonBCode || '',
    batchPersonBSurname: item.batchPersonBSurname || (item.batchPersonB ? item.batchPersonB.charAt(0) : '—'),
    batchPersonBEditing: false,
    servicePerson1: item.servicePerson1 || '未排班',
    servicePerson1Code: item.servicePerson1Code || '',
    servicePerson1Surname: item.servicePerson1Surname || (item.servicePerson1 ? item.servicePerson1.charAt(0) : '—'),
    servicePerson1Editing: false,
    servicePerson2: item.servicePerson2 || '未排班',
    servicePerson2Code: item.servicePerson2Code || '',
    servicePerson2Surname: item.servicePerson2Surname || (item.servicePerson2 ? item.servicePerson2.charAt(0) : '—'),
    servicePerson2Editing: false,
    servicePerson3: item.servicePerson3 || '未排班',
    servicePerson3Code: item.servicePerson3Code || '',
    servicePerson3Surname: item.servicePerson3Surname || (item.servicePerson3 ? item.servicePerson3.charAt(0) : '—'),
    servicePerson3Editing: false,
    editingRole: false,
    editingFrom: false,
    editingTo: false,
  }

  // 对于ECC夜班(personnelType=1, shiftType=2)的记录，从otherDuty中提取跑批和服务台人员数据
  if (item.personnelType === 1 && shiftType === 2 && item.otherDuty) {
    const od = item.otherDuty
    if (od.batch_A) {
      card.batchPersonA = od.batch_A
      card.batchPersonASurname = od.batch_A.charAt(0) || '—'
    }
    if (od.batch_A_id) {
      card.batchPersonACode = od.batch_A_id
    }
    if (od.batch_B) {
      card.batchPersonB = od.batch_B
      card.batchPersonBSurname = od.batch_B.charAt(0) || '—'
    }
    if (od.batch_B_id) {
      card.batchPersonBCode = od.batch_B_id
    }
    if (od.service_A) {
      card.servicePerson1 = od.service_A
      card.servicePerson1Surname = od.service_A.charAt(0) || '—'
    }
    if (od.service_A_id) {
      card.servicePerson1Code = od.service_A_id
    }
    if (od.service_B) {
      card.servicePerson2 = od.service_B
      card.servicePerson2Surname = od.service_B.charAt(0) || '—'
    }
    if (od.service_B_id) {
      card.servicePerson2Code = od.service_B_id
    }
    if (od.service_C) {
      card.servicePerson3 = od.service_C
      card.servicePerson3Surname = od.service_C.charAt(0) || '—'
    }
    if (od.service_C_id) {
      card.servicePerson3Code = od.service_C_id
    }
  }

  return card
}

// 重置筛选条件
const resetFilters = () => {
  filterRole.value = ''
  filterStatus.value = ''
  filterShiftType.value = ''
  filterDate.value = getDefaultDateRange()
  searchHandover()
}

// 搜索函数
const searchHandover = async () => {
  const _now = Date.now()
  if (_now - _lastSearchTime < 500) return
  _lastSearchTime = _now
  isLoading.value = true
  // 模拟3秒延迟，测试loading遮罩
  // await new Promise(resolve => setTimeout(resolve, 1000))
  try {
    const params = {}
    if (filterDate.value && filterDate.value.length === 2) {
      params.scheduleDateRange = [filterDate.value[0], filterDate.value[1]]
    }
    if (filterRole.value) {
      const roleMap = { ecc: 1, sys: 2, net: 3, pm: 4 }
      params.personnelType = roleMap[filterRole.value]
    }
    if (filterStatus.value) {
      params.status = filterStatus.value === 'completed' ? 1 : 0
    }
    if (filterShiftType.value) {
      params.shiftType = Number(filterShiftType.value)
    }
    const data = await getHandovers(params)
    handoverList.value = (data || []).map(mapBackendToCard)
  } catch (e) {
    console.error('查询交接班记录失败:', e)
    ElMessage.error('查询交接班记录失败')
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  searchHandover()
})

const dateShortcuts = [
  {
    text: '今天',
    value: () => {
      const end = new Date()
      const start = new Date()
      return [start, end]
    },
  },
  {
    text: '近一周',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setDate(start.getDate() - 6)
      return [start, end]
    },
  },
  {
    text: '近30天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setDate(start.getDate() - 29)
      return [start, end]
    },
  },
]

// ============ 交接班数据 ============
const lineUidCounter = { value: 0 }
const nextLineUid = () => ++lineUidCounter.value

const handoverList = ref([])

// 加载状态
const isLoading = ref(false)
let _lastSearchTime = 0

// ============ 值班选项常量 ============
const roleOptions = [
  { label: 'ECC 指挥中心', value: 'ecc', type: 1 },
  { label: '系统运维', value: 'sys', type: 2 },
  { label: '网络运维', value: 'net', type: 3 },
  { label: '甲方PM', value: 'pm', type: 4 },
]

// ============ 严重级别常量 ============
const severityLevels = [
  { value: 0, label: '普通', color: '#16a34a' },
  { value: 1, label: '重要', color: '#f59e0b' },
  { value: 2, label: '严重', color: '#dc2626' },
]

const getLevelColor = (level) => {
  const found = severityLevels.find(s => s.value === level)
  return found ? found.color : '#eab308'
}

const cycleLevel = (item) => {
  const idx = severityLevels.findIndex(s => s.value === item.level)
  item.level = severityLevels[(idx + 1) % severityLevels.length].value
}

// 根据 level 返回对应的 CSS class
const getLevelClass = (level) => {
  if (level === undefined || level === null) return ''
  return 'level-' + level
}

// 判断当前是否为白班时间
const isDayShift = () => {
  const hour = new Date().getHours()
  return hour >= 7 && hour < 19
}

// 根据卡片获取当前班次标签
const getCardShiftLabel = (card) => {
  if (card.roleValue === 'ecc') {
    return card.shiftType === 1 ? '☀️ 白班' : '🌙 夜班'
  }
  return '☀️ 白班'
}

const getCardShiftTagType = (card) => {
  if (card.roleValue === 'ecc') {
    return card.shiftType === 1 ? 'warning' : 'info'
  }
  return 'warning'
}

// 判断文件名是否为图片
const isImage = (name) => /(\.(jpg|jpeg|png|gif|webp|bmp|svg))$/i.test(name)

// 根据文件名返回对应图标
const getFileIcon = (name) => {
  if (/\.(doc|docx)$/i.test(name)) return Document
  if (/\.(xls|xlsx)$/i.test(name)) return Grid
  if (/\.txt$/i.test(name)) return Notebook
  return Document
}

// 获取文件扩展名（大写）
const getFileExt = (name) => {
  const m = name.match(/\.(\w+)$/)
  return m ? m[1].toUpperCase() : 'FILE'
}

// 图片预览弹窗状态
const previewImageUrl = ref('')
const previewVisible = ref(false)

// 点击图片放大预览
const previewImage = (att) => {
  previewImageUrl.value = att.url
  previewVisible.value = true
}

// 关闭图片预览
const closePreview = () => {
  previewVisible.value = false
  previewImageUrl.value = ''
}

// 点击文件下载到本地
const downloadFile = (att) => {
  const a = document.createElement('a')
  a.href = att.url
  a.download = att.name
  a.style.display = 'none'
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
}

// ============ 内联新建交接班 ============
const todaySchedule = ref(null)
const yesterdaySchedule = ref(null)
const tomorrowSchedule = ref(null)
const prevSchedules = ref([])
const allPersonnel = ref([])

// 跑批人员（单独从 getBatch 接口获取）
const batchPersonnel = ref([])

// 运维服务台人员（单独从 getService 接口获取）
const servicePersonnel = ref([])

// 今日跑批+服务台排班数据（from other_duty 表）
const todayOtherDuty = ref(null)

// 获取排班信息和人员列表
const loadHandoverInitData = async () => {
  const today = getLocalDateStr()

  // 计算昨天日期
  const yesterdayDate = new Date()
  yesterdayDate.setDate(yesterdayDate.getDate() - 1)
  const yesterdayStr = getLocalDateStr(yesterdayDate)

  // 计算明天日期
  const tomorrowDate = new Date()
  tomorrowDate.setDate(tomorrowDate.getDate() + 1)
  const tomorrowStr = getLocalDateStr(tomorrowDate)

  // 计算过去30天的开始日期（用于查找非ECC人员的前一个排班记录）
  const pastDate = new Date()
  pastDate.setDate(pastDate.getDate() - 30)
  const pastStr = getLocalDateStr(pastDate)

  try {
    const [scheduleArr, yesterdayArr, tomorrowArr, pastArr] = await Promise.all([
      getDuty([today, today]),
      getDuty([yesterdayStr, yesterdayStr]),
      getDuty([tomorrowStr, tomorrowStr]),
      getDuty([pastStr, yesterdayStr]),
    ])
    todaySchedule.value = Array.isArray(scheduleArr) && scheduleArr.length > 0 ? scheduleArr[0] : null
    yesterdaySchedule.value = Array.isArray(yesterdayArr) && yesterdayArr.length > 0 ? yesterdayArr[0] : null
    tomorrowSchedule.value = Array.isArray(tomorrowArr) && tomorrowArr.length > 0 ? tomorrowArr[0] : null
    prevSchedules.value = Array.isArray(pastArr) ? pastArr : []

    // 获取今日跑批+服务台排班数据
    try {
      todayOtherDuty.value = await getOtherDuty(today)
    } catch (e) {
      console.error('获取今日跑批/服务台排班失败:', e)
      todayOtherDuty.value = null
    }
  } catch (e) {
    console.error('获取排班数据失败:', e)
  }

    await loadPersonnelData()
}

// 根据 userCode 获取人员姓名
const getPersonName = (userCode) => {
  if (!userCode) return ''
  const person = allPersonnel.value.find(p => p.userCode === userCode)
  return person ? person.name : userCode
}

// 获取人员姓名首字
const getSurname = (name) => name ? name.charAt(0) : ''

// 填充交班人和接班人
const fillPersonnel = (card) => {
  const schedule = todaySchedule.value
  const yesterdayScheduleData = yesterdaySchedule.value

  // 设置头像颜色
  if (card.roleValue === 'ecc') {
    card.fromColor = card.shiftType === 1 ? 'var(--primary)' : 'var(--text-3)'
    card.toColor = card.shiftType === 1 ? 'var(--text-3)' : 'var(--primary)'
  } else {
    const colorMap = { sys: 'var(--purple)', net: 'var(--cyan)', pm: 'var(--warning)' }
    card.fromColor = colorMap[card.roleValue] || 'var(--purple)'
    card.toColor = colorMap[card.roleValue] || 'var(--purple)'
  }

  if (card.roleValue === 'ecc') {
    if (card.shiftType === 1) {
      // 白班→夜班 (19:00-7:00)：交班人=今天白班，接班人=今天夜班
      card.fromRoleDesc = 'ECC 白班 · 07:00-19:00'
      card.toRoleDesc = 'ECC 夜班 · 19:00-07:00'

      if (schedule) {
        const fromName = schedule.eccDayPersonnelName || schedule.ecc_day_personnel_id || ''
        const toName = schedule.eccNightPersonnelName || schedule.ecc_night_personnel_id || ''
        card.fromName = getPersonName(fromName) || fromName || '未排班'
        card.fromSurname = getSurname(card.fromName) || '—'
        const fromPerson = allPersonnel.value.find(p => p.userCode === fromName || p.name === card.fromName)
        card.fromUserCode = fromPerson ? fromPerson.userCode : ''
        card.toName = getPersonName(toName) || toName || '未排班'
        card.toSurname = getSurname(card.toName) || '—'
        const toPerson = allPersonnel.value.find(p => p.userCode === toName || p.name === card.toName)
        card.toUserCode = toPerson ? toPerson.userCode : ''
      } else {
        card.fromName = '未排班'
        card.fromSurname = '—'
        card.fromUserCode = ''
        card.toName = '未排班'
        card.toSurname = '—'
        card.toUserCode = ''
      }
    } else {
      // 夜班→白班：根据当前小时区分时间段
      // 19:00~24:00：交班人=今天夜班人员，接班人=明天白班人员
      // 0:00~7:00：交班人=昨天夜班人员，接班人=今天白班人员
      const currentHour = new Date().getHours()
      const isEveningCreation = currentHour >= 19

      card.fromRoleDesc = 'ECC 夜班 · 19:00-07:00'
      card.toRoleDesc = 'ECC 白班 · 07:00-19:00'

      // 交班人
      const fromSchedule = isEveningCreation ? schedule : yesterdayScheduleData
      if (fromSchedule) {
        const fromName = fromSchedule.eccNightPersonnelName || fromSchedule.ecc_night_personnel_id || ''
        card.fromName = getPersonName(fromName) || fromName || '未排班'
        card.fromSurname = getSurname(card.fromName) || '—'
        const fromPerson = allPersonnel.value.find(p => p.userCode === fromName || p.name === card.fromName)
        card.fromUserCode = fromPerson ? fromPerson.userCode : ''
      } else {
        card.fromName = '未排班'
        card.fromSurname = '—'
        card.fromUserCode = ''
      }

      // 接班人
      const toSchedule = isEveningCreation ? tomorrowSchedule.value : schedule
      if (toSchedule) {
        const toName = toSchedule.eccDayPersonnelName || toSchedule.ecc_day_personnel_id || ''
        card.toName = getPersonName(toName) || toName || '未排班'
        card.toSurname = getSurname(card.toName) || '—'
        const toPerson = allPersonnel.value.find(p => p.userCode === toName || p.name === card.toName)
        card.toUserCode = toPerson ? toPerson.userCode : ''
      } else {
        card.toName = '未排班'
        card.toSurname = '—'
        card.toUserCode = ''
      }
    }
  } else {
    // 非ECC（系统运维/网络运维/甲方PM）
    const roleFieldMap = {
      sys: { name: 'sysOpsPersonnelName', id2: 'sys_ops_personnel_id', label: '系统运维 · 08:30-18:00' },
      net: { name: 'netOpsPersonnelName', id2: 'net_ops_personnel_id', label: '网络运维 · 08:30-18:00' },
      pm:  { name: 'pmPersonnelName', id2: 'pm_personnel_id', label: '甲方PM · 08:30-18:00' },
    }
    const field = roleFieldMap[card.roleValue]
    card.fromRoleDesc = field.label
    card.toRoleDesc = field.label

    // 接班人：今天的排班人员
    if (schedule) {
      const toName = schedule[field.name] || schedule[field.id2] || ''
      card.toName = getPersonName(toName) || toName || '未排班'
      card.toSurname = getSurname(card.toName) || '—'
      const toPerson = allPersonnel.value.find(p => p.userCode === toName || p.name === card.toName)
      card.toUserCode = toPerson ? toPerson.userCode : ''
    } else {
      card.toName = '未排班'
      card.toSurname = '—'
      card.toUserCode = ''
    }

    // 交班人：前一个有该类型人员排班记录的人员（从历史排班中从后往前找）
    const today = getLocalDateStr()
    const reversed = [...prevSchedules.value].reverse()
    let foundFrom = false
    for (const record of reversed) {
      const dateStr = record.scheduleDate || record.schedule_date
      if (!dateStr || dateStr === today) continue

      const personName = record[field.name] || record[field.id2] || ''
      if (personName) {
        card.fromName = getPersonName(personName) || personName
        card.fromSurname = getSurname(card.fromName) || '—'
        const fromPerson = allPersonnel.value.find(p => p.userCode === personName || p.name === card.fromName)
        card.fromUserCode = fromPerson ? fromPerson.userCode : ''
        foundFrom = true
        break
      }
    }
    if (!foundFrom) {
      card.fromName = '未排班'
      card.fromSurname = '—'
      card.fromUserCode = ''
    }
  }

  // 填充跑批和服务台人员：优先从今日 other_duty 排班中获取
  const od = todayOtherDuty.value
  if (od) {
    if (od.batchA) {
      card.batchPersonA = od.batchA
      card.batchPersonACode = od.batchAId || ''
      card.batchPersonASurname = od.batchA.charAt(0) || '—'
    }
    if (od.batchB) {
      card.batchPersonB = od.batchB
      card.batchPersonBCode = od.batchBId || ''
      card.batchPersonBSurname = od.batchB.charAt(0) || '—'
    }
    if (od.serviceA) {
      card.servicePerson1 = od.serviceA
      card.servicePerson1Code = od.serviceAId || ''
      card.servicePerson1Surname = od.serviceA.charAt(0) || '—'
    }
    if (od.serviceB) {
      card.servicePerson2 = od.serviceB
      card.servicePerson2Code = od.serviceBId || ''
      card.servicePerson2Surname = od.serviceB.charAt(0) || '—'
    }
    if (od.serviceC) {
      card.servicePerson3 = od.serviceC
      card.servicePerson3Code = od.serviceCId || ''
      card.servicePerson3Surname = od.serviceC.charAt(0) || '—'
    }
  }
}

// 获取所有人员数据（含跑批人员）
const loadPersonnelData = async () => {
  try {
    const [ecc, sys, net, pm] = await Promise.all([
      getEcc(), getSys(), getNet(), getPM()
    ])
    allPersonnel.value = [
      ...(ecc || []).map(p => ({ ...p, category: 'ecc' })),
      ...(sys || []).map(p => ({ ...p, category: 'sys' })),
      ...(net || []).map(p => ({ ...p, category: 'net' })),
      ...(pm || []).map(p => ({ ...p, category: 'pm' })),
    ]

    // 获取跑批人员
    await loadBatchPersonnel()
    // 获取运维服务台人员
    await loadServicePersonnel()
  } catch (e) {
    console.error('获取人员列表失败:', e)
  }
}

// 获取运维服务台人员：调用 getService 接口获取
const loadServicePersonnel = async () => {
  try {
    const data = await getService()
    servicePersonnel.value = data || []
  } catch (e) {
    console.error('获取运维服务台人员失败:', e)
    servicePersonnel.value = []
  }
}

// 获取跑批人员：调用 getBatch 接口获取
const loadBatchPersonnel = async () => {
  try {
    const data = await getBatch()
    batchPersonnel.value = data || []
  } catch (e) {
    console.error('获取跑批人员失败:', e)
    batchPersonnel.value = []
  }
}

// 根据卡片角色筛选可用人员
const getPersonnelByCard = (card) => {
  const categoryMap = { ecc: 'ecc', sys: 'sys', net: 'net', pm: 'pm' }
  const cat = categoryMap[card.roleValue]
  return cat ? allPersonnel.value.filter(p => p.category === cat) : allPersonnel.value
}

// 获取跑批人员：从 batchPersonnel ref 中获取
const getBatchPersonnel = () => {
  return batchPersonnel.value
}

// 获取运维服务台人员：从 servicePersonnel ref 中获取
const getServicePersonnel = () => {
  return servicePersonnel.value
}

// 按服务台分组获取人员
const getServicePersonnelByGroup = (group) => {
  return servicePersonnel.value.filter(p => p.serviceGroup === group)
}

// 交班人选择
const onFromSelect = (card, userCode) => {
  if (!userCode) {
    card.fromName = ''
    card.fromUserCode = ''
    card.fromSurname = ''
    card.editingFrom = false
    return
  }
  const person = allPersonnel.value.find(p => p.userCode === userCode)
  if (person) {
    card.fromName = person.name
    card.fromUserCode = person.userCode
    card.fromSurname = getSurname(person.name)
  }
  card.editingFrom = false
}

// 接班人选择
const onToSelect = (card, userCode) => {
  if (!userCode) {
    card.toName = ''
    card.toUserCode = ''
    card.toSurname = ''
    card.editingTo = false
    return
  }
  const person = allPersonnel.value.find(p => p.userCode === userCode)
  if (person) {
    card.toName = person.name
    card.toUserCode = person.userCode
    card.toSurname = getSurname(person.name)
  }
  card.editingTo = false
}

// 跑批A角选择
const onBatchASelect = (card, userCode) => {
  if (!userCode) {
    card.batchPersonA = ''
    card.batchPersonACode = ''
    card.batchPersonASurname = ''
    card.batchPersonAEditing = false
    return
  }
  const person = batchPersonnel.value.find(p => p.userCode === userCode)
  if (person) {
    card.batchPersonA = person.name
    card.batchPersonACode = person.userCode
    card.batchPersonASurname = getSurname(person.name)
  }
  card.batchPersonAEditing = false
}

// 跑批B角选择
const onBatchBSelect = (card, userCode) => {
  if (!userCode) {
    card.batchPersonB = ''
    card.batchPersonBCode = ''
    card.batchPersonBSurname = ''
    card.batchPersonBEditing = false
    return
  }
  const person = batchPersonnel.value.find(p => p.userCode === userCode)
  if (person) {
    card.batchPersonB = person.name
    card.batchPersonBCode = person.userCode
    card.batchPersonBSurname = getSurname(person.name)
  }
  card.batchPersonBEditing = false
}

// 点击编辑跑批A角
const handleEditBatchA = async (card) => {
  await loadPersonnelData()
  card.batchPersonAEditing = true
  nextTick(() => {
    const sel = document.querySelector(`[data-edit-select="batchA-${card._cardId}"]`)
    if (sel) {
      const wrapper = sel.querySelector('.el-input__wrapper') || sel.querySelector('.el-select__wrapper')
      if (wrapper) wrapper.click()
    }
  })
}

// 点击编辑跑批B角
const handleEditBatchB = async (card) => {
  await loadPersonnelData()
  card.batchPersonBEditing = true
  nextTick(() => {
    const sel = document.querySelector(`[data-edit-select="batchB-${card._cardId}"]`)
    if (sel) {
      const wrapper = sel.querySelector('.el-input__wrapper') || sel.querySelector('.el-select__wrapper')
      if (wrapper) wrapper.click()
    }
  })
}

// ===== 运维服务台人员选择 =====
const makeServiceHandler = (idx) => {
  const nameKey = `servicePerson${idx}`
  const codeKey = `servicePerson${idx}Code`
  const surnameKey = `servicePerson${idx}Surname`
  const editingKey = `servicePerson${idx}Editing`

  const onSelect = (card, userCode) => {
    if (!userCode) {
      card[nameKey] = ''
      card[codeKey] = ''
      card[surnameKey] = ''
      card[editingKey] = false
      return
    }
    const person = servicePersonnel.value.find(p => p.userCode === userCode)
    if (person) {
      card[nameKey] = person.name
      card[codeKey] = person.userCode
      card[surnameKey] = getSurname(person.name)
    }
    card[editingKey] = false
  }

  const handleEdit = async (card) => {
    await loadPersonnelData()
    card[editingKey] = true
    nextTick(() => {
      const sel = document.querySelector(`[data-edit-select="service${idx}-${card._cardId}"]`)
      if (sel) {
        const wrapper = sel.querySelector('.el-input__wrapper') || sel.querySelector('.el-select__wrapper')
        if (wrapper) wrapper.click()
      }
    })
  }

  return { onSelect, handleEdit }
}

const serviceHandlers1 = makeServiceHandler(1)
const serviceHandlers2 = makeServiceHandler(2)
const serviceHandlers3 = makeServiceHandler(3)

// 点击编辑交班人/接班人：加载人员后显示下拉框并自动聚焦展开
const handleEditPerson = async (card, type) => {
  await loadPersonnelData()
  if (type === 'from') {
    card.editingFrom = true
  } else {
    card.editingTo = true
  }
  nextTick(() => {
    const sel = document.querySelector(`[data-edit-select="${type}-${card._cardId}"]`)
    if (sel) {
      const wrapper = sel.querySelector('.el-input__wrapper') || sel.querySelector('.el-select__wrapper')
      if (wrapper) wrapper.click()
    }
  })
}

// 点击编辑角色：显示下拉框并自动聚焦展开
const handleEditRole = (card) => {
  card.editingRole = true
  nextTick(() => {
    const sel = document.querySelector(`[data-edit-role="${card._cardId}"]`)
    if (sel) {
      const wrapper = sel.querySelector('.el-input__wrapper') || sel.querySelector('.el-select__wrapper')
      if (wrapper) wrapper.click()
    }
  })
}

// 创建草稿卡片
const createDraftCard = async () => {
  await loadHandoverInitData()
  await searchHandover()

  const now = new Date()
  const hour = now.getHours()
  const shiftType = (hour >= 7 && hour < 19) ? 1 : 2

  const pad = n => String(n).padStart(2, '0')
  const today = getLocalDateStr(now)
  const handoverTime = `${today} ${pad(hour)}:${pad(now.getMinutes())}`

  // 0:00~7:00 创建的夜班卡片业务上属于前一天的夜班，卡片日期显示为前一天
  let cardDate = today
  if (shiftType === 2 && hour < 7) {
    const yesterdayDate = new Date(now)
    yesterdayDate.setDate(yesterdayDate.getDate() - 1)
    cardDate = getLocalDateStr(yesterdayDate)
  }
  console.log(`[createDraftCard] hour=${hour}, shiftType=${shiftType}, today=${today}, cardDate=${cardDate}`)

  const draftCard = reactive({
    isDraft: true,
    handoverId: crypto.randomUUID(),
    _cardId: 'card-draft-' + Date.now(),
    date: cardDate,
    role: 'ECC 指挥中心',
    roleValue: 'ecc',
    personnelType: 1,
    shiftType: shiftType,
    shiftLabel: shiftType === 1 ? '白班 → 夜班' : '夜班 → 白班',
    shiftClass: shiftType === 1 ? 'shift-day' : 'shift-night',
    statusClass: 'pending',
    statusBadgeClass: 'status-pending',
    statusIcon: '⏳',
    statusText: '待确认',
    fromName: '',
    fromUserCode: '',
    fromSurname: '',
    fromColor: '',
    fromRoleDesc: '',
    toName: '',
    toUserCode: '',
    toSurname: '',
    toColor: '',
    toRoleDesc: '',
    systemStatus: [{ text: '', level: 0, _uid: ++lineUidCounter.value }],
    todoItems: [{ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] }],
    handoverTime: handoverTime,
    batchPersonA: '未排班',
    batchPersonACode: '',
    batchPersonASurname: '—',
    batchPersonAEditing: false,
    batchPersonB: '未排班',
    batchPersonBCode: '',
    batchPersonBSurname: '—',
    batchPersonBEditing: false,
    servicePerson1: '未排班',
    servicePerson1Code: '',
    servicePerson1Surname: '—',
    servicePerson1Editing: false,
    servicePerson2: '未排班',
    servicePerson2Code: '',
    servicePerson2Surname: '—',
    servicePerson2Editing: false,
    servicePerson3: '未排班',
    servicePerson3Code: '',
    servicePerson3Surname: '—',
    servicePerson3Editing: false,
    confirmText: '待确认',
    confirmColor: 'var(--warning)',
    confirmTime: '',
    createUserNickname: permissionStore.userInfo?.nickname || '',
    createUser: permissionStore.userInfo?.username || '',
    editingRole: false,
    editingFrom: false,
    editingTo: false,
  })

  fillPersonnel(draftCard)
  handoverList.value.unshift(draftCard)
}

// 值班角色切换
const onRoleChange = (card) => {
  const opt = roleOptions.find(r => r.value === card.roleValue)
  if (opt) {
    card.role = opt.label
    card.personnelType = opt.type
  }
  if (card.roleValue !== 'ecc') {
    // 离开 ECC：备份所有 ECC 专用字段，切回来时完整恢复
    if (card.shiftType !== 3) {
      card._eccBackup = {
        shiftType: card.shiftType,
        shiftLabel: card.shiftLabel,
        shiftClass: card.shiftClass,
        fromName: card.fromName,
        fromUserCode: card.fromUserCode,
        fromSurname: card.fromSurname,
        fromColor: card.fromColor,
        fromRoleDesc: card.fromRoleDesc,
        toName: card.toName,
        toUserCode: card.toUserCode,
        toSurname: card.toSurname,
        toColor: card.toColor,
        toRoleDesc: card.toRoleDesc,
        batchPersonA: card.batchPersonA,
        batchPersonACode: card.batchPersonACode,
        batchPersonASurname: card.batchPersonASurname,
        batchPersonB: card.batchPersonB,
        batchPersonBCode: card.batchPersonBCode,
        batchPersonBSurname: card.batchPersonBSurname,
        servicePerson1: card.servicePerson1,
        servicePerson1Code: card.servicePerson1Code,
        servicePerson1Surname: card.servicePerson1Surname,
        servicePerson2: card.servicePerson2,
        servicePerson2Code: card.servicePerson2Code,
        servicePerson2Surname: card.servicePerson2Surname,
        servicePerson3: card.servicePerson3,
        servicePerson3Code: card.servicePerson3Code,
        servicePerson3Surname: card.servicePerson3Surname,
      }
    }
    card.shiftType = 3
    card.shiftLabel = '同组交接'
    card.shiftClass = 'shift-day'
    // 清空交班人和接班人
    card.fromName = ''
    card.fromUserCode = ''
    card.fromSurname = ''
    card.toName = ''
    card.toUserCode = ''
    card.toSurname = ''
    fillPersonnel(card)
  } else {
    // 切回 ECC：恢复备份数据（类型不变 + 数据不丢失）
    if (card._eccBackup) {
      Object.assign(card, card._eccBackup)
      delete card._eccBackup
    }
  }
  card.editingRole = false
}

// 切换 ECC 交班方向（白班↔夜班）
const toggleShift = (card) => {
  if (card.roleValue !== 'ecc' || !card.isDraft) return
  card.shiftType = card.shiftType === 1 ? 2 : 1
  card.shiftLabel = card.shiftType === 1 ? '白班 → 夜班' : '夜班 → 白班'
  card.shiftClass = card.shiftType === 1 ? 'shift-day' : 'shift-night'

  if (card.shiftType === 2) {
    // 切换到夜班(夜班→白班)：交班人=今天夜班，接班人取第二天白班
    card.fromRoleDesc = 'ECC 夜班 · 19:00-07:00'
    card.toRoleDesc = 'ECC 白班 · 07:00-19:00'
    // 交班人 = 今天的夜班人员（从今天排班取）
    const schedule = todaySchedule.value
    if (schedule) {
      const fromName = schedule.eccNightPersonnelName || schedule.ecc_night_personnel_id || ''
      const fromPerson = allPersonnel.value.find(p => p.userCode === fromName || p.name === getPersonName(fromName))
      card.fromName = getPersonName(fromName) || fromName || ''
      card.fromUserCode = fromPerson ? fromPerson.userCode : fromName
      card.fromSurname = getSurname(card.fromName) || '—'
    } else {
      card.fromName = ''
      card.fromUserCode = ''
      card.fromSurname = '—'
    }
    // 接班人 = 第二天的白班人员
    const tomorrowScheduleData = tomorrowSchedule.value
    if (tomorrowScheduleData) {
      const toName = tomorrowScheduleData.eccDayPersonnelName || tomorrowScheduleData.ecc_day_personnel_id || ''
      const toPerson = allPersonnel.value.find(p => p.userCode === toName || p.name === getPersonName(toName))
      card.toName = getPersonName(toName) || toName || ''
      card.toUserCode = toPerson ? toPerson.userCode : toName
      card.toSurname = getSurname(card.toName) || '—'
    } else {
      card.toName = ''
      card.toUserCode = ''
      card.toSurname = '—'
    }
    card.fromColor = 'var(--text-3)'
    card.toColor = 'var(--primary)'
  } else {
    // 切换到白班(白班→夜班)：交班人=今天白班，接班人=今天夜班
    card.fromRoleDesc = 'ECC 白班 · 07:00-19:00'
    card.toRoleDesc = 'ECC 夜班 · 19:00-07:00'
    // 交班人 = 今天的白班人员
    const schedule = todaySchedule.value
    if (schedule) {
      const fromName = schedule.eccDayPersonnelName || schedule.ecc_day_personnel_id || ''
      const fromPerson = allPersonnel.value.find(p => p.userCode === fromName || p.name === getPersonName(fromName))
      card.fromName = getPersonName(fromName) || fromName || ''
      card.fromUserCode = fromPerson ? fromPerson.userCode : fromName
      card.fromSurname = getSurname(card.fromName) || '—'
    } else {
      card.fromName = ''
      card.fromUserCode = ''
      card.fromSurname = '—'
    }
    // 接班人 = 今天的夜班人员
    if (schedule) {
      const toName = schedule.eccNightPersonnelName || schedule.ecc_night_personnel_id || ''
      const toPerson = allPersonnel.value.find(p => p.userCode === toName || p.name === getPersonName(toName))
      card.toName = getPersonName(toName) || toName || ''
      card.toUserCode = toPerson ? toPerson.userCode : toName
      card.toSurname = getSurname(card.toName) || '—'
    } else {
      card.toName = ''
      card.toUserCode = ''
      card.toSurname = '—'
    }
    card.fromColor = 'var(--primary)'
    card.toColor = 'var(--text-3)'
  }
  // 同步更新备份
  if (card._eccBackup) {
    card._eccBackup.shiftType = card.shiftType
    card._eccBackup.shiftLabel = card.shiftLabel
    card._eccBackup.shiftClass = card.shiftClass
    card._eccBackup.fromName = card.fromName
    card._eccBackup.fromUserCode = card.fromUserCode
    card._eccBackup.fromSurname = card.fromSurname
    card._eccBackup.fromColor = card.fromColor
    card._eccBackup.fromRoleDesc = card.fromRoleDesc
    card._eccBackup.toName = card.toName
    card._eccBackup.toUserCode = card.toUserCode
    card._eccBackup.toSurname = card.toSurname
    card._eccBackup.toColor = card.toColor
    card._eccBackup.toRoleDesc = card.toRoleDesc
  }
}

// 系统运行状态：添加新行
const addStatusItem = (card, index) => {
  const newUid = ++lineUidCounter.value
  card.systemStatus.splice(index + 1, 0, { text: '', level: 0, _uid: newUid })
  nextTick(() => {
    const el = document.querySelector(`[data-status-uid="${newUid}"] textarea`)
    if (el) el.focus()
  })
}

// 删除指定行
const removeLineItem = (list, index) => {
  if (list.length <= 1) return
  list.splice(index, 1)
}

// 待跟进事项：添加新行
const addTodoItem = (card, index) => {
  const newUid = ++lineUidCounter.value
  card.todoItems.splice(index + 1, 0, { text: '', level: 0, _uid: newUid, attachments: [] })
  nextTick(() => {
    const el = document.querySelector(`[data-todo-uid="${newUid}"] textarea`)
    if (el) el.focus()
  })
}

// 触发上传文件
const triggerUpload = (line) => {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*,.doc,.docx,.xls,.xlsx,.txt'
  input.multiple = true
  input.onchange = (e) => {
    const files = Array.from(e.target.files)
    files.forEach(file => {
      if (!line.attachments) line.attachments = []
      line.attachments.push({
        name: file.name,
        url: URL.createObjectURL(file),
        _file: file,
      })
    })
    input.value = ''
  }
  input.click()
}

// 待跟进事项板块上传（上传到最后一个事项，若无事项则自动新增一行）
const triggerTodoUpload = (card) => {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*,.doc,.docx,.xls,.xlsx,.txt'
  input.multiple = true
  input.onchange = (e) => {
    const files = Array.from(e.target.files)
    // 确保至少有一个事项行来挂载附件
    if (card.todoItems.length === 0 || (card.todoItems.length === 1 && !card.todoItems[0].text.trim() && !card.todoItems[0].attachments?.length)) {
      card.todoItems.push({ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] })
    }
    const last = card.todoItems[card.todoItems.length - 1]
    files.forEach(file => {
      if (!last.attachments) last.attachments = []
      last.attachments.push({
        name: file.name,
        url: URL.createObjectURL(file),
        _file: file,
      })
    })
    input.value = ''
  }
  input.click()
}

// 移除附件
const removeAttachment = (line, index) => {
  if (line.attachments[index]?.url) {
    URL.revokeObjectURL(line.attachments[index].url)
  }
  line.attachments.splice(index, 1)
}

// 保存草稿
const saveDraftCard = async (card) => {
  // 校验交班人和接班人
  ElMessage.closeAll()
  if (!card.fromName || !card.fromName.trim()) {
    ElMessage.warning('请选择交班人后再保存')
    return
  }
  if (!card.toName || !card.toName.trim()) {
    ElMessage.warning('请选择接班人后再保存')
    return
  }

  // 检查当天是否已有同班次的交接班记录
  const todayStr = card.date
  try {
    const existingData = await getHandovers({
      scheduleDateRange: [todayStr, todayStr],
      personnelType: card.personnelType,
      shiftType: card.shiftType,
    })
    if (existingData && existingData.length > 0) {
      const duplicate = existingData.find(r => {
        const existingId = r.handover_id || r.id
        return existingId && existingId !== card.handoverId
      })
      if (duplicate) {
        const shiftPeriod = card.roleValue === 'ecc'
          ? (card.shiftType === 1 ? '白班' : '夜班')
          : card.role
        ElMessage.warning(`今日已有${shiftPeriod}交班记录，不允许重复，请确认是否是对应班次`)
        return
      }
    }
  } catch (e) {
    console.error('查询交接班记录失败:', e)
  }

  // 弹出确认框
  try {
    await ElMessageBox.confirm(
      '确定保存此交接班记录吗？',
      '保存确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
  } catch (e) {
    if (e !== 'cancel') {
      console.error('保存确认失败:', e)
    }
    return
  }

  // 原地删除空行，保留响应式引用
  for (let i = card.systemStatus.length - 1; i >= 0; i--) {
    if (!card.systemStatus[i].text.trim()) {
      card.systemStatus.splice(i, 1)
    }
  }
  for (let i = card.todoItems.length - 1; i >= 0; i--) {
    if (!card.todoItems[i].text.trim() && !card.todoItems[i].attachments?.length) {
      card.todoItems.splice(i, 1)
    }
  }
  if (card.systemStatus.length === 0) {
    card.systemStatus.push({ text: '', level: 0, _uid: ++lineUidCounter.value })
  }
  if (card.todoItems.length === 0) {
    card.todoItems.push({ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] })
  }

  // ============ 构建交接班数据模型 ============
  const statusMap = { pending: 0, completed: 1 }
  const handoverDataModel = {
    handover_id: card.handoverId,
    scheduleDate: card.date,
    personnelType: card.personnelType,
    shiftType: card.shiftType,
    create_user: permissionStore.userInfo?.username || '',
    create_user_nickname: permissionStore.userInfo?.nickname || '',
    fromPersonnelId: card.fromUserCode || '',
    fromPersonnelName: card.fromName || '',
    toPersonnelId: card.toUserCode || '',
    toPersonnelName: card.toName || '',
    handoverTime: card.handoverTime,
    status: statusMap[card.statusClass] ?? 0,
    confirmTime: card.confirmTime || '',
    systemStatus: card.systemStatus.map((s, si) => ({
      sort_order: String(si + 1),
      text: s.text,
      level: String(s.level ?? 0),
    })),
    todoItems: card.todoItems.map((t, ti) => ({
      sort_order: String(ti + 1),
      text: t.text,
      level: String(t.level ?? 0),
    })),
    attachments: card.todoItems.flatMap((t) =>
      (t.attachments || []).map((a) => ({
        name: a.name,
        url: a.url || '',
        file_size: a._file ? a._file.size : (a.file_size || 0),
      }))
    ).map((a, ai) => ({
      ...a,
      sort_order: String(ai + 1),
    })),
  }

  // 仅ECC夜班保存时上传跑批和运维服务台人员
  if (card.roleValue === 'ecc' && card.shiftType === 2) {
    handoverDataModel.otherDuty = {
      batch_A_id: card.batchPersonACode || '',
      batch_A: card.batchPersonA || '',
      batch_B_id: card.batchPersonBCode || '',
      batch_B: card.batchPersonB || '',
      service_A_id: card.servicePerson1Code || '',
      service_A: card.servicePerson1 || '',
      service_B_id: card.servicePerson2Code || '',
      service_B: card.servicePerson2 || '',
      service_C_id: card.servicePerson3Code || '',
      service_C: card.servicePerson3 || '',
    }
  }

  console.log('========== 交接班数据模型（传递给后端）==========')
  console.log(JSON.stringify(handoverDataModel, null, 2))

  // 收集原始 File 对象用于上传
  const files = card.todoItems.flatMap(t =>
    (t.attachments || []).map(a => a._file).filter(Boolean)
  )
  console.log('上传文件数量:', files.length)
  files.forEach((f, i) => console.log(`文件[${i}]:`, f.name, f.size))

  try {
    await saveHandover(handoverDataModel, files)
    ElMessage.success('交接班记录已保存')
    await searchHandover()
  } catch (e) {
    console.error('保存交接班记录失败:', e)
    ElMessage.error(e.message || '保存交接班记录失败')
    await searchHandover()
  }
}

// 保存编辑前快照，用于撤销
const cardSnapshots = new Map()

// 克隆卡片可编辑字段
const cloneEditableFields = (card) => {
  return {
    role: card.role,
    roleValue: card.roleValue,
    personnelType: card.personnelType,
    shiftType: card.shiftType,
    shiftLabel: card.shiftLabel,
    shiftClass: card.shiftClass,
    fromName: card.fromName,
    fromUserCode: card.fromUserCode,
    fromSurname: card.fromSurname,
    fromColor: card.fromColor,
    fromRoleDesc: card.fromRoleDesc,
    toName: card.toName,
    toUserCode: card.toUserCode,
    toSurname: card.toSurname,
    toColor: card.toColor,
    toRoleDesc: card.toRoleDesc,
    batchPersonA: card.batchPersonA,
    batchPersonACode: card.batchPersonACode,
    batchPersonASurname: card.batchPersonASurname,
    batchPersonB: card.batchPersonB,
    batchPersonBCode: card.batchPersonBCode,
    batchPersonBSurname: card.batchPersonBSurname,
    servicePerson1: card.servicePerson1,
    servicePerson1Code: card.servicePerson1Code,
    servicePerson1Surname: card.servicePerson1Surname,
    servicePerson2: card.servicePerson2,
    servicePerson2Code: card.servicePerson2Code,
    servicePerson2Surname: card.servicePerson2Surname,
    servicePerson3: card.servicePerson3,
    servicePerson3Code: card.servicePerson3Code,
    servicePerson3Surname: card.servicePerson3Surname,
    systemStatus: JSON.parse(JSON.stringify(card.systemStatus)),
    todoItems: JSON.parse(JSON.stringify(card.todoItems)),
    handoverTime: card.handoverTime,
    confirmText: card.confirmText,
    confirmColor: card.confirmColor,
    _eccBackup: card._eccBackup ? JSON.parse(JSON.stringify(card._eccBackup)) : undefined,
  }
}

// 撤销编辑，恢复到编辑前状态
const undoEditCard = async (card) => {
  try {
    await ElMessageBox.confirm(
      '确定撤销当前修改吗？已编辑的内容将丢失。',
      '撤销修改',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    const snapshot = cardSnapshots.get(card._cardId)
    if (!snapshot) {
      // 新建但未保存的草稿，仅重置表单内容，保持草稿状态
      card.systemStatus = [{ text: '', level: 0, _uid: ++lineUidCounter.value }]
      card.todoItems = [{ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] }]
      return
    }
    Object.assign(card, snapshot)
    card.isDraft = false
    cardSnapshots.delete(card._cardId)
    await searchHandover()
  } catch (e) {
    if (e !== 'cancel') {
      console.error('撤销修改失败:', e)
    }
  }
}

// 重新编辑已保存的卡片
const editDraftCard = async (card) => {
  // 加载排班数据，确保切换班次时能获取到正确的默认人员
  await loadHandoverInitData()
  cardSnapshots.set(card._cardId, cloneEditableFields(card))
  card.isDraft = true
  // 如果列表为空则补一个空行方便编辑
  if (card.systemStatus.length === 0 || card.systemStatus.every(s => !s.text || s.text === '—')) {
    card.systemStatus = [{ text: '', level: card.systemStatus[0]?.level ?? 0, _uid: ++lineUidCounter.value }]
  }
  if (card.todoItems.length === 0 || card.todoItems.every(t => (!t.text || t.text === '—') && (!t.attachments || t.attachments.length === 0))) {
    card.todoItems = [{ text: '', level: card.todoItems[0]?.level ?? 0, _uid: ++lineUidCounter.value, attachments: [] }]
  }
}

// 确认交接
const confirmHandover = async (item) => {
  if (item.statusClass === 'completed' || !item.handoverId) return
  try {
    await ElMessageBox.confirm(
      '确认交接后该记录将不可修改，确定执行？',
      '确认交接',
      {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    await confirmHandovers(item.handoverId)
    const now = new Date()
    const pad = n => String(n).padStart(2, '0')
    item.confirmTime = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`
    item.statusClass = 'completed'
    item.statusBadgeClass = 'status-completed'
    item.statusIcon = '✓'
    item.statusText = '已完成'
    item.confirmText = '已确认'
    item.confirmColor = 'var(--success)'
    ElMessage.success('交接已确认')
    await searchHandover()
  } catch (e) {
    if (e !== 'cancel') {
      console.error('确认交接失败:', e)
      ElMessage.error(e.message || '确认交接失败')
      await searchHandover()
    }
  }
}

// 根据 level 返回对应的中文标签（用于复制粘贴保留颜色）
const getLevelLabel = (level) => {
  const found = severityLevels.find(s => s.value === level)
  return found ? found.label : '普通'
}

// 根据中文标签解析 level 值
const parseLevelLabel = (text) => {
  const match = text.match(/^\[(普通|重要|严重)\]/)
  if (match) {
    const found = severityLevels.find(s => s.label === match[1])
    return { level: found ? found.value : 0, text: text.slice(match[0].length).trim() }
  }
  return { level: 0, text }
}

// 复制文本到剪贴板（可选携带级别信息）
const copyText = (text, level) => {
  const prefix = level !== undefined ? `[${getLevelLabel(level)}]` : ''
  const fullText = prefix + text
  navigator.clipboard.writeText(fullText).then(() => {
    ElMessage.closeAll()
    ElMessage.success('已复制到剪贴板')
  }).catch(() => {
    // 降级方案
    const textarea = document.createElement('textarea')
    textarea.value = fullText
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    document.body.removeChild(textarea)
    ElMessage.closeAll()
    ElMessage.success('已复制到剪贴板')
  })
}

// 一键复制全部条目（交接事件明细 / 备注），保留颜色级别
const copyAllItems = (items, label) => {
  const lines = items
    .filter(s => s.text && s.text.trim() && s.text.trim() !== '-' && s.text.trim() !== '—')
    .map((s, i) => `${i + 1}. [${getLevelLabel(s.level)}]${s.text}`)
  if (lines.length === 0) {
    ElMessage.closeAll()
    ElMessage.warning(`${label}无内容可复制`)
    return
  }
  copyText(lines.join('\n'))
}

// 处理编辑模式下 textarea 的粘贴事件：自动解析 [普通]/[重要]/[严重] 前缀并设置级别
const handlePaste = (e, line) => {
  const text = e.clipboardData.getData('text')
  if (!text) return

  // 只处理单行粘贴（不含换行符），避免影响多行一键粘贴逻辑
  if (text.includes('\n') || text.includes('\r')) return

  const result = parseLevelLabel(text.trim())
  if (result.level !== 0) {
    e.preventDefault()
    line.level = result.level
    // 在光标位置插入纯文本
    const target = e.target
    // el-input 内部 textarea 可能嵌套，处理原生 textarea 或 el-input 元素
    const textarea = target.tagName === 'TEXTAREA' ? target : target.querySelector('textarea')
    if (!textarea) {
      // 降级：直接赋值
      line.text = result.text
      return
    }
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const currentText = line.text || ''
    line.text = currentText.substring(0, start) + result.text + currentText.substring(end)
    // 移动光标到插入文本末尾
    nextTick(() => {
      textarea.selectionStart = textarea.selectionEnd = start + result.text.length
      textarea.focus()
    })
  }
}

// 处理编辑模式下 textarea 的复制事件（Ctrl+C）：选中文本时自动附加 [级别] 前缀
const handleCopy = (e, line) => {
  // 只处理有选中文本的复制，且自身级别非普通
  if (line.level === 0) return

  const target = e.target
  const textarea = target.tagName === 'TEXTAREA' ? target : target.querySelector('textarea')
  if (!textarea) return

  const selectedText = textarea.value.substring(textarea.selectionStart, textarea.selectionEnd)
  if (!selectedText || selectedText.includes('\n')) return

  // 如果选中文本已包含 [级别] 前缀则不重复添加
  const levelLabel = getLevelLabel(line.level)
  if (selectedText.startsWith(`[${levelLabel}]`)) return

  e.preventDefault()
  const formattedText = `[${levelLabel}]${selectedText}`
  e.clipboardData.setData('text/plain', formattedText)
}

// 一键粘贴全部条目（交接事件明细 / 备注）
const pasteAllItems = async (card, field, label) => {
  try {
    const text = await navigator.clipboard.readText()
    if (!text || !text.trim()) {
      ElMessage.closeAll()
      ElMessage.warning('剪贴板为空，无法粘贴')
      return
    }
    const lines = text.split(/\r?\n/).map(l => {
      const cleaned = l.replace(/^\d+[\.\)、]\s*/, '').trim()
      if (!cleaned) return null
      const parsed = parseLevelLabel(cleaned)
      return parsed
    }).filter(Boolean)
    if (lines.length === 0) {
      ElMessage.closeAll()
      ElMessage.warning('剪贴板无有效内容')
      return
    }
    const list = card[field]
    // 若当前仅有一行空行则替换，否则追加
    const isEmpty = list.length === 0 || (list.length === 1 && !list[0].text?.trim())
    const newItems = lines.map(parsed => ({
      text: parsed.text,
      level: parsed.level,
      _uid: ++lineUidCounter.value,
      ...(field === 'todoItems' ? { attachments: [] } : {}),
    }))
    if (isEmpty) {
      list.splice(0, list.length, ...newItems)
    } else {
      list.push(...newItems)
    }
    ElMessage.closeAll()
    ElMessage.success(`已粘贴 ${lines.length} 条${label}`)
  } catch (e) {
    ElMessage.closeAll()
    ElMessage.error('粘贴失败，请检查浏览器剪贴板权限')
  }
}

// 一键清除所有条目（交接事件明细 / 备注）
const clearAllItems = (card, field) => {
  const list = card[field]
  list.splice(0, list.length)
  if (field === 'todoItems') {
    list.push({ text: '', level: 0, _uid: ++lineUidCounter.value, attachments: [] })
  } else {
    list.push({ text: '', level: 0, _uid: ++lineUidCounter.value })
  }
}

// 删除卡片
const deleteCard = async (card) => {
  try {
    await ElMessageBox.confirm('确定删除此交接班记录吗？', '确认删除', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })
    // 已保存到数据库的记录才调用删除接口，未存库的草稿直接删除卡片
    if (!card.isDraft && card.handoverId) {
      await deleteHandover(card.handoverId)
    }
    const idx = handoverList.value.findIndex(c => c === card || c._cardId === card._cardId)
    if (idx !== -1) {
      handoverList.value.splice(idx, 1)
    }
    ElMessage.success('交接班记录已删除')
    await searchHandover()
  } catch (e) {
    // 用户取消不处理，其他错误报错
    if (e !== 'cancel') {
      console.error('删除失败:', e)
      ElMessage.error(e.message || '删除失败')
      await searchHandover()
    }
  }
}

// ============ 导出 Excel ============
const exportToExcel = async () => {
  ElMessage.closeAll()
  if (!filterDate.value || filterDate.value.length !== 2) {
    ElMessage.warning('请先选择日期范围再导出')
    return
  }

  ElMessage.info('正在生成 Excel，请稍候...')

  try {
    const dateRange = [filterDate.value[0], filterDate.value[1]]
    const response = await exportHandoverExcel(dateRange)

    // 触发浏览器下载
    const blob = new Blob([response.data], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    const dateStr = `${dateRange[0]}-${dateRange[1]}`
    link.download = `ECC值班交接记录_${dateStr}.xlsx`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)

    ElMessage.closeAll()
    ElMessage.success('导出成功')
  } catch (e) {
    console.error('导出 Excel 失败:', e)
    ElMessage.closeAll()
    ElMessage.error('导出失败：' + (e.message || '未知错误'))
  }
}

// 组件销毁时释放所有 object URLs
onBeforeUnmount(() => {
  handoverList.value.forEach(card => {
    card.todoItems?.forEach(item => {
      item.attachments?.forEach(att => {
        if (att.url?.startsWith('blob:')) URL.revokeObjectURL(att.url)
      })
    })
  })
})
</script>

<template>
  <div class="handover-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">交接班记录</h2>
      <div class="toolbar-actions">
        <el-button v-if="permissionStore.hasPermission('duty:handoverExport')" type="warning" plain @click="exportToExcel">
          <el-icon><Download /></el-icon>&nbsp;导出
        </el-button>
        <el-button v-if="permissionStore.hasPermission('duty:handoverCreate')" type="primary" class="btn-primary-custom" @click="createDraftCard">
          <el-icon><Plus /></el-icon>
          新建交接班
        </el-button>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <el-form :inline="true" class="filter-form">
        <el-form-item class="filter-item">
          <el-select v-model="filterRole" clearable placeholder="值班角色" style="width: 130px" @clear="filterRole = ''">
            <el-option label="全部角色" value="" />
            <el-option label="ECC 指挥中心" value="ecc" />
            <el-option label="系统运维" value="sys" />
            <el-option label="网络运维" value="net" />
            <el-option label="甲方PM" value="pm" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="filterStatus" clearable placeholder="交接状态" style="width: 130px" @clear="filterStatus = ''">
            <el-option label="全部" value="" />
            <el-option label="已完成" value="completed" />
            <el-option label="待确认" value="pending" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="filterShiftType" clearable placeholder="交班类型" style="width: 130px" @clear="filterShiftType = ''">
            <el-option label="全部类型" value="" />
            <el-option label="白班→夜班" value="1" />
            <el-option label="夜班→白班" value="2" />
            <el-option label="同组交接" value="3" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item filter-date-range">
          <el-date-picker
            v-model="filterDate"
            type="daterange"
            start-placeholder="交接日期(开始)"
            end-placeholder="交接日期(结束)"
            value-format="YYYY-MM-DD"
            :shortcuts="dateShortcuts"
            unlink-panels
            style="width: 260px"
            @clear="filterDate = getDefaultDateRange(); searchHandover()"
          />
        </el-form-item>
        <span class="filter-sep"></span>
        <div class="filter-actions">
          <el-button v-if="permissionStore.hasPermission('duty:handoverReset')" type="info" plain @click="resetFilters" class="search-btn">
            <svg class="icon-svg sm" viewBox="0 0 24 24">
              <polyline points="1 4 1 10 7 10" />
              <path d="M3.51 15a9 9 0 102.13-9.36L1 10" />
            </svg>
            &nbsp;重置
          </el-button>
          <el-button v-if="permissionStore.hasPermission('duty:handoverSearch')" type="info" plain @click="searchHandover" class="search-btn">
            <svg class="icon-svg sm" viewBox="0 0 24 24">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            &nbsp;查询
          </el-button>
        </div>
      </el-form>
    </div>

   <!-- 交接班时间线 -->
    <div v-loading="isLoading" class="handover-timeline-wrapper">
      <!-- 内容始终渲染 -->
      <div v-if="handoverList.length === 0" class="handover-empty-wrapper">
        <el-empty description="暂无交接班记录" :image-size="200" />
      </div>
      <el-scrollbar v-else class="handover-timeline">
      <div v-for="(item, index) in handoverList" :key="index" class="handover-item">
        <span :class="['handover-dot', item.statusClass]"></span>
        <div class="handover-card">
          <div class="handover-card-header">
            <div class="handover-date">{{ item.date }} ·
              <template v-if="item.isDraft">
                <span class="role-name-wrap">
                  <span v-show="!item.editingRole" class="role-clickable" @click="handleEditRole(item)">{{ item.role }}</span>
                  <el-select
                    v-show="item.editingRole"
                    v-model="item.roleValue"
                    size="small"
                    class="role-inline-select"
                    :data-edit-role="item._cardId"
                    :teleported="false"
                    clearable
                    @change="onRoleChange(item)"
                    @visible-change="(v) => { if (!v) item.editingRole = false }"
                  >
                    <el-option v-for="opt in roleOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
                  </el-select>
                </span>
              </template>
              <template v-else>{{ item.role }}</template>
            </div>
            <!-- 当前班次醒目提示 -->
            <div class="handover-header-center">
              <el-tag :type="getCardShiftTagType(item)" size="small" effect="dark">
                {{ getCardShiftLabel(item) }}
              </el-tag>
            </div>
            <div class="handover-header-right">
              <div class="handover-header-actions">
                <!-- 保存按钮：仅创建者（isCardCreator）可用 -->
                <template v-if="item.isDraft && permissionStore.hasPermission('duty:handoverSave') && isCardCreator(item)">
                  <el-tooltip content="保存草稿" placement="top">
                    <span class="header-icon-btn save" @click="saveDraftCard(item)">
                      <el-icon><Check /></el-icon>
                    </span>
                  </el-tooltip>
                  <el-tooltip content="撤销修改" placement="top">
                    <span class="header-icon-btn undo" @click="undoEditCard(item)">
                      <el-icon><RefreshLeft /></el-icon>
                    </span>
                  </el-tooltip>
                  <!-- 未保存的草稿允许直接删除 -->
                  <el-tooltip v-if="!cardSnapshots.has(item._cardId) && permissionStore.hasPermission('duty:handoverDelete') && isCardCreator(item)" content="删除" placement="top">
                    <span class="header-icon-btn delete" @click="deleteCard(item)">
                      <el-icon><Delete /></el-icon>
                    </span>
                  </el-tooltip>
                </template>
                <!-- 编辑和确认：编辑仅创建者可用，确认仅接班人可用 -->
                <template v-else-if="item.statusClass === 'pending'">
                  <el-tooltip v-if="permissionStore.hasPermission('duty:handoverEdit') && isCardCreator(item)" content="编辑" placement="top">
                    <span class="header-icon-btn edit" @click="editDraftCard(item)">
                      <el-icon><Edit /></el-icon>
                    </span>
                  </el-tooltip>
                  <el-tooltip v-if="permissionStore.hasPermission('duty:handoverConfirm') && isCardReceiver(item)" content="确认交接" placement="top">
                    <span class="header-icon-btn confirm" @click="confirmHandover(item)">
                      <el-icon><CircleCheck /></el-icon>
                    </span>
                  </el-tooltip>
                </template>
                <!-- 删除：仅创建者可用，非已完成卡片可见 -->
                <el-tooltip v-if="item.statusClass !== 'completed' && !item.isDraft && permissionStore.hasPermission('duty:handoverDelete') && isCardCreator(item)" content="删除" placement="top">
                  <span class="header-icon-btn delete" @click="deleteCard(item)">
                    <el-icon><Delete /></el-icon>
                  </span>
                </el-tooltip>
              </div>
              <div class="handover-shift-info">
                <span
                  :class="['badge-shift', item.shiftClass]"
                  :style="item.roleValue === 'ecc' && item.isDraft ? { cursor: 'pointer' } : {}"
                  @click="item.roleValue === 'ecc' && item.isDraft && toggleShift(item)"
                >{{ item.shiftLabel }}</span>
                <span v-if="item.isDraft" class="handover-status status-draft">⏳ 待保存</span>
                <span v-else :class="['handover-status', item.statusBadgeClass]">{{ item.statusIcon }} {{ item.statusText }}</span>
              </div>
            </div>
          </div>
          <div class="handover-body">
            <!-- 交班人 -->
            <div class="handover-col">
              <div class="handover-section-title">
                <el-icon><User /></el-icon> 交班人
              </div>
              <div class="handover-person-row">
                <div class="handover-person-avatar" :style="{ background: item.fromColor }">{{ item.fromSurname }}</div>
                <div class="handover-person-info">
                  <template v-if="item.isDraft">
                    <div class="person-name-wrap">
                      <span v-show="!item.editingFrom" class="person-clickable" @click="handleEditPerson(item, 'from')">{{ item.fromName || '(点击选择)' }}</span>
                      <el-select
                        v-show="item.editingFrom"
                        v-model="item.fromName"
                        size="small"
                        class="person-inline-select"
                        :data-edit-select="'from-' + item._cardId"
                        :teleported="false"
                        clearable
                        placeholder="选择交班人"
                        @change="onFromSelect(item, item.fromName)"
                        @visible-change="(v) => { if (!v) item.editingFrom = false }"
                        autofocus
                      >
                        <el-option v-for="p in getPersonnelByCard(item)" :key="p.userCode" :label="p.name" :value="p.userCode" />
                      </el-select>
                    </div>
                    <div class="handover-person-role">{{ item.fromRoleDesc }}</div>
                  </template>
                  <template v-else>
                    <div class="handover-person-name">{{ item.fromName }}</div>
                    <div class="handover-person-role">{{ item.fromRoleDesc }}</div>
                  </template>
                </div>
              </div>
            </div>
            <!-- 接班人 -->
            <div class="handover-col">
              <div class="handover-section-title">
                <el-icon><UserFilled /></el-icon> 接班人
              </div>
              <div class="handover-person-row">
                <div class="handover-person-avatar" :style="{ background: item.toColor }">{{ item.toSurname }}</div>
                <div class="handover-person-info">
                  <template v-if="item.isDraft">
                    <div class="person-name-wrap">
                      <span v-show="!item.editingTo" class="person-clickable" @click="handleEditPerson(item, 'to')">{{ item.toName || '(点击选择)' }}</span>
                      <el-select
                        v-show="item.editingTo"
                        v-model="item.toName"
                        size="small"
                        class="person-inline-select"
                        :data-edit-select="'to-' + item._cardId"
                        :teleported="false"
                        clearable
                        placeholder="选择接班人"
                        @change="onToSelect(item, item.toName)"
                        @visible-change="(v) => { if (!v) item.editingTo = false }"
                        autofocus
                      >
                        <el-option v-for="p in getPersonnelByCard(item)" :key="p.userCode" :label="p.name" :value="p.userCode" />
                      </el-select>
                    </div>
                    <div class="handover-person-role">{{ item.toRoleDesc }}</div>
                  </template>
                  <template v-else>
                    <div class="handover-person-name">{{ item.toName }}</div>
                    <div class="handover-person-role">{{ item.toRoleDesc }}</div>
                  </template>
                </div>
              </div>
            </div>
            <!-- 跑批人员（仅ECC夜班显示） -->
            <!-- 跑批人员标题 - 全宽 -->
            <div v-if="item.roleValue === 'ecc' && item.shiftType === 2" class="handover-content-block" style="margin-top: 0; margin-bottom: 0; padding-bottom: 0;">
              <div class="handover-section-title">
                <el-icon><UserFilled /></el-icon> 跑批人员
              </div>
            </div>
            <!-- 跑批A角 -->
            <div v-if="item.roleValue === 'ecc' && item.shiftType === 2" class="handover-col">
              <div class="handover-person-row">
                <div class="handover-person-avatar" style="background: var(--purple);">{{ item.batchPersonASurname || '—' }}</div>
                <div class="handover-person-info">
                  <template v-if="item.isDraft">
                    <div class="person-name-wrap">
                      <span v-show="!item.batchPersonAEditing" class="person-clickable" @click="handleEditBatchA(item)">{{ item.batchPersonA || '(点击选择)' }}</span>
                      <el-select
                        v-show="item.batchPersonAEditing"
                        v-model="item.batchPersonACode"
                        size="small"
                        class="person-inline-select"
                        :data-edit-select="'batchA-' + item._cardId"
                        :teleported="false"
                        clearable
                        placeholder="选择A角"
                        @change="onBatchASelect(item, item.batchPersonACode)"
                        @visible-change="(v) => { if (!v) item.batchPersonAEditing = false }"
                        autofocus
                      >
                        <el-option v-for="p in getBatchPersonnel()" :key="p.userCode" :label="p.name" :value="p.userCode" />
                      </el-select>
                    </div>
                    <div class="handover-person-role">跑批A角 · 08:30-18:00</div>
                  </template>
                  <template v-else>
                    <div class="handover-person-name">{{ item.batchPersonA || '—' }}</div>
                    <div class="handover-person-role">跑批A角 · 08:30-18:00</div>
                  </template>
                </div>
              </div>
            </div>
            <!-- 跑批B角 -->
            <div v-if="item.roleValue === 'ecc' && item.shiftType === 2" class="handover-col">
              <div class="handover-person-row">
                <div class="handover-person-avatar" style="background: var(--purple);">{{ item.batchPersonBSurname || '—' }}</div>
                <div class="handover-person-info">
                  <template v-if="item.isDraft">
                    <div class="person-name-wrap">
                      <span v-show="!item.batchPersonBEditing" class="person-clickable" @click="handleEditBatchB(item)">{{ item.batchPersonB || '(点击选择)' }}</span>
                      <el-select
                        v-show="item.batchPersonBEditing"
                        v-model="item.batchPersonBCode"
                        size="small"
                        class="person-inline-select"
                        :data-edit-select="'batchB-' + item._cardId"
                        :teleported="false"
                        clearable
                        placeholder="选择B角"
                        @change="onBatchBSelect(item, item.batchPersonBCode)"
                        @visible-change="(v) => { if (!v) item.batchPersonBEditing = false }"
                        autofocus
                      >
                        <el-option v-for="p in getBatchPersonnel()" :key="p.userCode" :label="p.name" :value="p.userCode" />
                      </el-select>
                    </div>
                    <div class="handover-person-role">跑批B角 · 08:30-18:00</div>
                  </template>
                  <template v-else>
                    <div class="handover-person-name">{{ item.batchPersonB || '—' }}</div>
                    <div class="handover-person-role">跑批B角 · 08:30-18:00</div>
                  </template>
                </div>
              </div>
            </div>
            <!-- 运维服务台（仅ECC夜班显示） -->
            <div v-if="item.roleValue === 'ecc' && item.shiftType === 2" class="handover-content-block" style="margin-top: 0; margin-bottom: 0; padding-bottom: 0;">
              <div class="handover-section-title">
                <el-icon><UserFilled /></el-icon> 运维服务台
              </div>
            </div>
            <!-- 服务台1/2/3 - flex行三列 -->
            <div v-if="item.roleValue === 'ecc' && item.shiftType === 2" class="service-row">
              <!-- 服务台1 -->
              <div class="service-col">
                <div class="handover-person-row">
                  <div class="handover-person-avatar" style="background: var(--primary);">{{ item.servicePerson1Surname || '—' }}</div>
                  <div class="handover-person-info">
                    <template v-if="item.isDraft">
                      <div class="person-name-wrap">
                        <span v-show="!item.servicePerson1Editing" class="person-clickable" @click="serviceHandlers1.handleEdit(item)">{{ item.servicePerson1 || '(点击选择)' }}</span>
                        <el-select
                          v-show="item.servicePerson1Editing"
                          v-model="item.servicePerson1Code"
                          size="small"
                          class="person-inline-select"
                          :data-edit-select="'service1-' + item._cardId"
                          :teleported="false"
                          clearable
                          placeholder="选择人员"
                          @change="serviceHandlers1.onSelect(item, item.servicePerson1Code)"
                          @visible-change="(v) => { if (!v) item.servicePerson1Editing = false }"
                          autofocus
                        >
                          <el-option v-for="p in getServicePersonnelByGroup(1)" :key="p.userCode" :label="p.name" :value="p.userCode" />
                        </el-select>
                      </div>
                      <div class="handover-person-role">业务组 · 08:30-18:00</div>
                    </template>
                    <template v-else>
                      <div class="handover-person-name">{{ item.servicePerson1 || '—' }}</div>
                      <div class="handover-person-role">业务组 · 08:30-18:00</div>
                    </template>
                  </div>
                </div>
              </div>
              <!-- 服务台2 -->
              <div class="service-col">
                <div class="handover-person-row">
                  <div class="handover-person-avatar" style="background: var(--primary);">{{ item.servicePerson2Surname || '—' }}</div>
                  <div class="handover-person-info">
                    <template v-if="item.isDraft">
                      <div class="person-name-wrap">
                        <span v-show="!item.servicePerson2Editing" class="person-clickable" @click="serviceHandlers2.handleEdit(item)">{{ item.servicePerson2 || '(点击选择)' }}</span>
                        <el-select
                          v-show="item.servicePerson2Editing"
                          v-model="item.servicePerson2Code"
                          size="small"
                          class="person-inline-select"
                          :data-edit-select="'service2-' + item._cardId"
                          :teleported="false"
                          clearable
                          placeholder="选择人员"
                          @change="serviceHandlers2.onSelect(item, item.servicePerson2Code)"
                          @visible-change="(v) => { if (!v) item.servicePerson2Editing = false }"
                          autofocus
                        >
                          <el-option v-for="p in getServicePersonnelByGroup(2)" :key="p.userCode" :label="p.name" :value="p.userCode" />
                        </el-select>
                      </div>
                      <div class="handover-person-role">财务组 · 08:30-18:00</div>
                    </template>
                    <template v-else>
                      <div class="handover-person-name">{{ item.servicePerson2 || '—' }}</div>
                      <div class="handover-person-role">财务组 · 08:30-18:00</div>
                    </template>
                  </div>
                </div>
              </div>
              <!-- 服务台3 -->
              <div class="service-col">
                <div class="handover-person-row">
                  <div class="handover-person-avatar" style="background: var(--primary);">{{ item.servicePerson3Surname || '—' }}</div>
                  <div class="handover-person-info">
                    <template v-if="item.isDraft">
                      <div class="person-name-wrap">
                        <span v-show="!item.servicePerson3Editing" class="person-clickable" @click="serviceHandlers3.handleEdit(item)">{{ item.servicePerson3 || '(点击选择)' }}</span>
                        <el-select
                          v-show="item.servicePerson3Editing"
                          v-model="item.servicePerson3Code"
                          size="small"
                          class="person-inline-select"
                          :data-edit-select="'service3-' + item._cardId"
                          :teleported="false"
                          clearable
                          placeholder="选择人员"
                          @change="serviceHandlers3.onSelect(item, item.servicePerson3Code)"
                          @visible-change="(v) => { if (!v) item.servicePerson3Editing = false }"
                          autofocus
                        >
                          <el-option v-for="p in getServicePersonnelByGroup(3)" :key="p.userCode" :label="p.name" :value="p.userCode" />
                        </el-select>
                      </div>
                      <div class="handover-person-role">办公组 · 08:30-18:00</div>
                    </template>
                    <template v-else>
                      <div class="handover-person-name">{{ item.servicePerson3 || '—' }}</div>
                      <div class="handover-person-role">办公组 · 08:30-18:00</div>
                    </template>
                  </div>
                </div>
              </div>
            </div>

            <div class="handover-divider"></div>

            <!-- 系统运行状态 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Message /></el-icon> 交接事件明细
                <template v-if="!item.isDraft">
                  <el-tooltip :content="`复制全部(${item.systemStatus.filter(s => s.text && s.text.trim() && s.text.trim() !== '-' && s.text.trim() !== '—').length}条)`" placement="top">
                    <span class="title-action-btn" @click="copyAllItems(item.systemStatus, '交接事件明细')">
                      <el-icon><CopyDocument /></el-icon>
                    </span>
                  </el-tooltip>
                </template>
                <template v-else>
                  <div class="title-action-group">
                    <el-tooltip content="一键粘贴全部" placement="top">
                      <span class="title-action-btn paste" @click="pasteAllItems(item, 'systemStatus', '交接事件明细')">
                        <el-icon><Tickets /></el-icon>
                      </span>
                    </el-tooltip>
                    <el-tooltip content="一键清除全部" placement="top">
                      <span class="title-action-btn clear" @click="clearAllItems(item, 'systemStatus')">
                        <el-icon><Delete /></el-icon>
                      </span>
                    </el-tooltip>
                  </div>
                </template>
              </div>
              <template v-if="item.isDraft">
                <div v-for="(line, li) in item.systemStatus" :key="'s-' + line._uid" class="handover-input-row-with-dot" :class="'input-level-' + line.level" :data-status-uid="line._uid">
                  <span
                    class="severity-dot"
                    :style="{ background: getLevelColor(line.level) }"
                    :title="severityLevels.find(s => s.value === line.level)?.label"
                    @click="cycleLevel(line)"
                  ></span>
                  <span class="row-index">{{ li + 1 }}.</span>
                  <el-input
                    v-model="line.text"
                    type="textarea"
                    :autosize="{ minRows: 1, maxRows: 10 }"
                    size="small"
                    spellcheck="false"
                    placeholder="输入系统运行状态，回车添加下一条..."
                    @keydown.enter.prevent="addStatusItem(item, li)"
                    @paste="handlePaste($event, line)"
                    @copy="handleCopy($event, line)"
                  />
                  <span v-if="item.systemStatus.length > 1" class="row-delete-btn" @click="removeLineItem(item.systemStatus, li)">
                    <el-icon><Delete /></el-icon>
                  </span>
                  <span v-else class="row-clear-btn" @click="line.text = ''; line.level = 0" title="清空">
                    <el-icon><Close /></el-icon>
                  </span>
                </div>
              </template>
              <ul v-else class="handover-list">
                <template v-for="(line, li) in item.systemStatus" :key="'s-' + li">
                  <li v-if="line.text && line.text.trim() && line.text.trim() !== '-' && line.text.trim() !== '—'" :class="getLevelClass(line.level) || { 'warn-item': line.warn, 'danger-item': line.danger }">
                    <span class="handover-list-text">{{ li + 1 }}. {{ line.text }}</span>
                    <span class="handover-list-copy" @click="copyText(line.text, line.level)" title="复制">
                      <el-icon><CopyDocument /></el-icon>
                    </span>
                  </li>
                  <li v-else class="handover-list-empty"></li>
                </template>
              </ul>
            </div>

            <!-- 待跟进事项 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Document /></el-icon> 备注
                <template v-if="!item.isDraft">
                  <el-tooltip :content="`复制全部(${item.todoItems.filter(s => s.text && s.text.trim() && s.text.trim() !== '-' && s.text.trim() !== '—').length}条)`" placement="top">
                    <span class="title-action-btn" @click="copyAllItems(item.todoItems, '备注')">
                      <el-icon><CopyDocument /></el-icon>
                    </span>
                  </el-tooltip>
                </template>
                <template v-else>
                  <div class="title-action-group">
                    <el-tooltip content="一键粘贴全部" placement="top">
                      <span class="title-action-btn paste" @click="pasteAllItems(item, 'todoItems', '备注')">
                        <el-icon><Tickets /></el-icon>
                      </span>
                    </el-tooltip>
                    <el-tooltip content="一键清除全部" placement="top">
                      <span class="title-action-btn clear" @click="clearAllItems(item, 'todoItems')">
                        <el-icon><Delete /></el-icon>
                      </span>
                    </el-tooltip>
                  </div>
                </template>
              </div>
              <template v-if="item.isDraft">
                <template v-for="(line, li) in item.todoItems" :key="'t-' + line._uid">
                  <div class="handover-input-row-with-dot" :class="'input-level-' + line.level" :data-todo-uid="line._uid">
                    <span
                      class="severity-dot"
                      :style="{ background: getLevelColor(line.level) }"
                      :title="severityLevels.find(s => s.value === line.level)?.label"
                      @click="cycleLevel(line)"
                    ></span>
                    <span class="row-index">{{ li + 1 }}.</span>
                    <el-input
                      v-model="line.text"
                      type="textarea"
                      :autosize="{ minRows: 1, maxRows: 10 }"
                      size="small"
                      spellcheck="false"
                      placeholder="输入备注，回车添加下一条..."
                      @keydown.enter.prevent="addTodoItem(item, li)"
                      @paste="handlePaste($event, line)"
                      @copy="handleCopy($event, line)"
                    />
                    <span v-if="item.todoItems.length > 1" class="row-delete-btn" @click="removeLineItem(item.todoItems, li)">
                      <el-icon><Delete /></el-icon>
                    </span>
                    <span v-else class="row-clear-btn" @click="line.text = ''; line.level = 0" title="清空">
                      <el-icon><Close /></el-icon>
                    </span>
                  </div>
                </template>
                <!-- 附件标题 -->
                <div class="handover-content-title" style="margin-top: 12px;">
                  <el-icon><Upload /></el-icon> 附件
                </div>
                <!-- 上传附件入口 -->
                <div class="upload-row">
                  <div class="todo-upload-trigger" @click="triggerTodoUpload(item)">
                    <el-icon><Upload /></el-icon>
                    <span>上传附件</span>
                  </div>
                  <span class="upload-hint">支持图片、Word、Excel、文本文件</span>
                </div>
                <!-- 图片附件缩略图 -->
                <template v-for="(line, li) in item.todoItems" :key="'att-img-' + line._uid">
                  <div v-if="line.attachments?.some(a => isImage(a.name))" class="attachment-previews">
                    <template v-for="(att, ai) in line.attachments" :key="'img-' + ai">
                      <div v-if="isImage(att.name)" class="attachment-item">
                        <img :src="att.url" :alt="att.name" class="preview-img" @click.stop="previewImage(att)" />
                        <span class="attachment-remove" @click="removeAttachment(line, ai)">&times;</span>
                      </div>
                    </template>
                  </div>
                </template>
                <!-- 文档附件列表（同行排列） -->
                <template v-for="(line, li) in item.todoItems" :key="'att-file-' + line._uid">
                  <div v-if="line.attachments?.some(a => !isImage(a.name))" class="attachment-file-row-wrap">
                    <template v-for="(att, ai) in line.attachments" :key="'file-' + ai">
                      <div v-if="!isImage(att.name)" class="attachment-file-row">
                        <span class="file-ext-icon" :class="'ext-' + getFileExt(att.name).toLowerCase()" @click.stop="downloadFile(att)" style="cursor: pointer;">{{ getFileExt(att.name) }}</span>
                        <span class="attachment-file-name" @click.stop="downloadFile(att)" style="cursor: pointer;">{{ att.name }}</span>
                        <span class="attachment-file-remove" @click="removeAttachment(line, ai)">&times;</span>
                      </div>
                    </template>
                  </div>
                </template>
              </template>
              <template v-else>
                <ul class="handover-list">
                  <template v-for="(line, li) in item.todoItems" :key="'t-' + li">
                    <li v-if="line.text && line.text.trim() && line.text.trim() !== '-' && line.text.trim() !== '—'" :class="getLevelClass(line.level) || { 'warn-item': line.warn, 'danger-item': line.danger }">
                      <span class="handover-list-text">{{ li + 1 }}. {{ line.text }}</span>
                      <span class="handover-list-copy" @click="copyText(line.text, line.level)" title="复制">
                        <el-icon><CopyDocument /></el-icon>
                      </span>
                    </li>
                    <li v-else class="handover-list-empty"></li>
                  </template>
                </ul>
                <!-- 查看模式附件 -->
                <div class="handover-content-title" style="margin-top: 12px;">
                  <el-icon><Upload /></el-icon> 附件
                </div>
                <div v-if="!item.todoItems.some(t => t.attachments?.length)" class="no-attachment-hint">无附件</div>
                <template v-for="(line, li) in item.todoItems" :key="'att-img-' + line._uid">
                  <div v-if="line.attachments?.some(a => isImage(a.name))" class="attachment-previews" style="margin-top: 6px;">
                    <template v-for="(att, ai) in line.attachments" :key="'img-' + ai">
                      <div v-if="isImage(att.name)" class="attachment-item">
                        <img :src="att.url" :alt="att.name" class="preview-img" @click="previewImage(att)" />
                      </div>
                    </template>
                  </div>
                </template>
                <!-- 查看模式附件（同行排列） -->
                <template v-for="(line, li) in item.todoItems" :key="'att-file-' + line._uid">
                  <div v-if="line.attachments?.some(a => !isImage(a.name))" class="attachment-file-row-wrap" style="margin-top: 6px;">
                    <template v-for="(att, ai) in line.attachments" :key="'file-' + ai">
                      <div v-if="!isImage(att.name)" class="attachment-file-row" style="cursor: pointer;" @click="downloadFile(att)">
                        <span class="file-ext-icon" :class="'ext-' + getFileExt(att.name).toLowerCase()">{{ getFileExt(att.name) }}</span>
                        <span class="attachment-file-name">{{ att.name }}</span>
                      </div>
                    </template>
                  </div>
                </template>
              </template>
            </div>

            <!-- 交接确认 -->
            <div class="handover-content-block">
              <div class="handover-sign">
              <template v-if="item.isDraft">
                <span>创建人：{{ item.createUserNickname || '' }} &nbsp;|&nbsp; 创建时间：{{ item.handoverTime }}</span>
              </template>
              <template v-else>
                <span>创建人：{{ item.createUserNickname || '' }} &nbsp;|&nbsp; 创建时间：{{ item.handoverTime }} &nbsp;|&nbsp; 接班人确认：<strong :style="{ color: item.confirmColor }">{{ item.confirmText }}</strong>
                <template v-if="item.confirmTime">&nbsp;|&nbsp; 确认时间：{{ item.confirmTime }}</template></span>
              </template>
            </div>
            </div>
          </div>
        </div>
      </div>
    </el-scrollbar>
    </div>

    <!-- 新建交接班弹窗 -->
    <el-dialog v-model="handoverModalVisible" title="新建交接班记录" width="620px" :close-on-click-modal="false">
      <el-form label-width="100px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="值班角色">
              <el-select v-model="newHandover.role" style="width: 100%">
                <el-option label="ECC 指挥中心" value="ecc" />
                <el-option label="系统运维" value="sys" />
                <el-option label="网络运维" value="net" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="交接日期">
              <el-date-picker v-model="newHandover.date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="交班人">
              <el-select v-model="newHandover.from" style="width: 100%">
                <el-option label="李四光" value="李四光" />
                <el-option label="张三丰" value="张三丰" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="接班人">
              <el-select v-model="newHandover.to" style="width: 100%">
                <el-option label="张三丰" value="张三丰" />
                <el-option label="李四光" value="李四光" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="系统运行状态">
          <el-input v-model="newHandover.systemStatus" spellcheck="false" type="textarea" :rows="3" placeholder="描述当前各系统运行状况..." />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="newHandover.todo" spellcheck="false" type="textarea" :rows="3" placeholder="需要接班人关注的事项..." />
        </el-form-item>
        <el-form-item label="附件">
          <div class="upload-area-box">
            <div class="upload-desc-text">点击或拖拽上传附件（截图、文档等）</div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="handoverModalVisible = false">取消</el-button>
        <el-button type="primary" @click="submitHandover">提交交接</el-button>
      </template>
    </el-dialog>

    <!-- 图片预览弹窗 -->
    <Teleport to="body">
      <div v-if="previewVisible" class="image-preview-overlay" @click.self="closePreview">
        <span class="image-preview-close" @click="closePreview">&times;</span>
        <img :src="previewImageUrl" class="image-preview-img" alt="预览图片" />
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.handover-page {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 16px 24px;
  height: 100%;
  box-sizing: border-box;
  overflow: hidden;
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

/* 筛选栏 - 匹配告警管理页面样式 */
.filter-bar {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  flex-shrink: 0;
}

.filter-form {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  width: 100%;
}

.filter-form :deep(.el-form-item) {
  margin-right: 0;
  margin-bottom: 0;
}

.filter-item {
  flex: 0 0 auto;
}

.filter-date-range {
  display: flex;
  align-items: center;
}

/* 标签 */
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

/* 交接班时间线 */
.handover-timeline-wrapper {
  flex: 1;
  position: relative;
  min-height: 300px;
  overflow: hidden;
}

.handover-empty-wrapper {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}
.handover-timeline {
  position: relative;
  flex: 1;
  height: 100%;
}
.handover-timeline::before {
  content: '';
  position: absolute;
  left: 14px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: var(--border);
}
.handover-item {
  display: flex;
  align-items: flex-start;
  margin-bottom: 16px;
}
.handover-dot {
  flex-shrink: 0;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 2px solid var(--primary);
  background: var(--bg-card);
  margin-top: 18px;
  margin-left: 8px;
  margin-right: 8px;
  z-index: 1;
  position: relative;
}
.handover-dot.completed {
  background: var(--success);
  border-color: var(--success);
}
.handover-dot.pending {
  background: var(--warning-bg);
  border-color: var(--warning);
}
.handover-card {
  flex: 1;
  min-width: 0;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  transition: box-shadow 0.2s;
}
.handover-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
}
.handover-card-header {
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border-light);
  position: relative;
}

/* 当前班次提示居中 */
.handover-header-center {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
}
.handover-date {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-1);
}
.handover-shift-info {
  display: flex;
  align-items: center;
  gap: 8px;
}
.handover-status {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 20px;
  font-weight: 600;
}
.status-completed {
  background: var(--success-bg);
  color: var(--success);
  border: 1px solid var(--success-border);
}
.status-pending {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}

/* 待保存状态样式 */
.status-draft {
  background: #eff6ff;
  color: #2563eb;
  border: 1px solid #bfdbfe;
}

.handover-body {
  padding: 14px 16px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.handover-col {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.handover-section-title {
  font-size: 11px;
  font-weight: 600;
  color: var(--text-4);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 2px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.handover-person-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.handover-person-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  color: #fff;
  flex-shrink: 0;
}
.handover-person-info {
  flex: 1;
}
.handover-person-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  height: 22px;
  line-height: 22px;
}
.handover-person-role {
  font-size: 11px;
  color: var(--text-3);
}

.handover-divider {
  grid-column: 1 / -1;
  height: 1px;
  background: var(--border-light);
  margin: 2px 0;
}
.handover-content-block {
  grid-column: 1 / -1;
}
.handover-content-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-2);
  margin-bottom: 6px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.handover-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 0;
  margin: 0;
}
.handover-list li {
  font-size: 13px;
  color: var(--text-2);
  padding: 6px 10px;
  background: var(--bg-page);
  border-radius: 6px;
  display: flex;
  align-items: flex-start;
  gap: 8px;
  line-height: 19.5px;
}
.handover-list li::before {
  content: '';
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--primary);
  flex-shrink: 0;
  margin-top: 6px;
}
.handover-list li.warn-item::before {
  background: var(--warning);
}
.handover-list li.danger-item::before {
  background: var(--danger);
}
.handover-sign {
  font-size: 12px;
  color: var(--text-3);
  text-align: left;
  padding-top: 8px;
  border-top: 1px dashed var(--border-light);
  margin-top: 6px;
}

/* 头部右侧 */
.handover-header-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 头部图标按钮 */
.handover-header-actions {
  display: flex;
  align-items: center;
  gap: 2px;
  min-height: 24px;
}
.header-icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.15s;
  font-size: 14px;
}
.header-icon-btn.save {
  color: var(--primary);
}
.header-icon-btn.save:hover {
  background: var(--primary-bg);
  color: #1d4ed8;
}
.header-icon-btn.edit {
  color: var(--warning);
}
.header-icon-btn.edit:hover {
  background: var(--warning-bg);
  color: #d97706;
}
.header-icon-btn.confirm {
  color: var(--success);
}
.header-icon-btn.confirm:hover {
  background: var(--success-bg);
  color: #15803d;
}
.header-icon-btn.undo {
  color: var(--text-3);
}
.header-icon-btn.undo:hover {
  background: var(--bg-page);
  color: var(--text-1);
}

/* 弹窗 */
.upload-area-box {
  border: 2px dashed var(--border);
  border-radius: 8px;
  padding: 20px;
  text-align: center;
  background: var(--bg-page);
  cursor: pointer;
}
.upload-area-box:hover {
  border-color: var(--primary);
  background: var(--primary-bg);
}
.upload-desc-text {
  font-size: 12px;
  color: var(--text-4);
}

/* 草稿卡片编辑样式 */
.role-clickable {
  cursor: pointer;
  border-bottom: 1px dashed var(--text-4);
  transition: color 0.2s;
}
.role-clickable:hover {
  color: var(--primary);
  border-bottom-color: var(--primary);
}
.role-inline-select {
  width: 150px;
  display: inline-block;
  vertical-align: middle;
  height: 22px;
}
.role-inline-select :deep(.el-input) {
  height: 22px !important;
}
.role-inline-select :deep(.el-input__wrapper) {
  height: 22px !important;
  min-height: 22px !important;
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
  padding: 0 !important;
}
.role-inline-select :deep(.el-input__wrapper:hover),
.role-inline-select :deep(.el-input__wrapper.is-focus) {
  box-shadow: none !important;
  border: none !important;
}
.role-inline-select :deep(.el-input__inner) {
  font-size: 13px;
  height: 22px !important;
  line-height: 22px !important;
  background: transparent !important;
  border: none !important;
  padding: 0 !important;
}
.role-inline-select :deep(.el-select__caret) {
  display: none;
}
.role-name-wrap {
  display: inline-block;
  height: 22px;
  vertical-align: middle;
}
.person-clickable {
  cursor: pointer;
  border-bottom: 1px dashed var(--text-4);
  transition: color 0.2s;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 22px;
  height: 22px;
  display: inline-block;
}
.person-clickable:hover {
  color: var(--primary);
  border-bottom-color: var(--primary);
}
.person-name-wrap {
  height: 22px;
  display: flex;
  align-items: center;
}
.person-inline-select {
  width: 72px;
  height: 22px;
  display: block;
}
.person-inline-select :deep(.el-input) {
  height: 22px !important;
}
.person-inline-select :deep(.el-input__wrapper) {
  height: 22px !important;
  min-height: 22px !important;
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
  padding: 0 !important;
}
.person-inline-select :deep(.el-input__wrapper:hover),
.person-inline-select :deep(.el-input__wrapper.is-focus) {
  box-shadow: none !important;
  border: none !important;
}
.person-inline-select :deep(.el-input__inner) {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  height: 22px !important;
  line-height: 22px !important;
  background: transparent !important;
  border: none !important;
  padding: 0 !important;
}
.person-inline-select :deep(.el-select__caret) {
  display: none;
}
.person-inline-select :deep(.el-select__clear) {
  display: inline-flex !important;
  color: var(--text-4);
  font-size: 14px;
}

/* 运维服务台行：三列等宽 flex 布局 */
.service-row {
  grid-column: 1 / -1;
  display: flex;
  gap: 24px;
}
.service-col {
  flex: 1;
  min-width: 0;
}

.handover-input-row {
  margin-bottom: 6px;
}
.handover-input-row:last-child {
  margin-bottom: 0;
}
.handover-input-row .el-input__inner {
  font-size: 13px;
}

/* 带颜色点的编辑行 */
.handover-input-row-with-dot {
  display: flex;
  align-items: flex-start;
  padding: 6px 10px;
  background: var(--bg-page);
  border-radius: 6px;
  margin-bottom: 4px;
  font-size: 13px;
}
.handover-input-row-with-dot:last-child {
  margin-bottom: 0;
}
.handover-input-row-with-dot :deep(.el-input),
.handover-input-row-with-dot :deep(.el-textarea) {
  flex: 1;
  --el-input-border-color: transparent !important;
  --el-input-bg-color: transparent !important;
  --el-input-hover-border-color: transparent !important;
}
.handover-input-row-with-dot :deep(.el-input__wrapper) {
  background: transparent !important;
  background-color: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
  padding: 0 !important;
}
.handover-input-row-with-dot :deep(.el-input__wrapper:hover),
.handover-input-row-with-dot :deep(.el-input__wrapper.is-focus) {
  box-shadow: none !important;
  border: none !important;
}
.handover-input-row-with-dot :deep(.el-input__inner),
.handover-input-row-with-dot :deep(.el-textarea__inner) {
  font-size: 13px;
  color: var(--text-2);
  line-height: 19.5px;
  padding: 0;
  background: transparent !important;
  resize: none !important;
}
.handover-input-row-with-dot :deep(.el-textarea__inner) {
  min-height: 19.5px;
}

/* 行序号 */
.row-index {
  flex-shrink: 0;
  font-size: 13px;
  line-height: 19.5px;
  color: var(--text-2);
  margin-right: 4px;
  user-select: none;
}

/* 颜色点 */
.severity-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-top: 6px;
  margin-right: 8px;
  cursor: pointer;
  transition: transform 0.15s;
  border: none;
}
.severity-dot:hover {
  transform: scale(1.4);
}

/* 行删除按钮 */
.row-delete-btn {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: flex;
  align-items: center;
  align-self: center;
  transition: color 0.15s;
}
.row-delete-btn:hover {
  color: var(--danger);
}

/* 行清空按钮 */
.row-clear-btn {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: flex;
  align-items: center;
  align-self: center;
  transition: color 0.15s;
}
.row-clear-btn:hover {
  color: var(--warning);
}

/* 行上传按钮 */
.row-upload-btn {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: flex;
  align-items: center;
  margin-top: 1px;
  transition: color 0.15s;
}
.row-upload-btn:hover {
  color: var(--primary);
}

/* 附件缩略图 */
.attachment-previews {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 6px;
}
.attachment-item {
  position: relative;
  width: 60px;
  height: 60px;
  border-radius: 6px;
  overflow: hidden;
  border: 1px solid var(--border);
  flex-shrink: 0;
}
.attachment-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.preview-img {
  cursor: pointer;
}

/* 无附件提示 */
.no-attachment-hint {
  font-size: 13px;
  color: var(--text-4);
  padding: 6px 0;
}

/* 文档附件列表行（同行排列） */
.attachment-file-row-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 6px;
}
.attachment-file-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  background: var(--bg-page);
  border-radius: 6px;
  border: 1px solid var(--border);
  font-size: 12px;
  color: var(--text-2);
  width: fit-content;
}
.attachment-file-row:last-child {
  margin-bottom: 0;
}
.attachment-file-row .el-icon {
  font-size: 16px;
  flex-shrink: 0;
  color: var(--primary);
}

/* 文件扩展名标签 */
.file-ext-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 4px;
  font-size: 8px;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
  line-height: 1;
}
.ext-doc,
.ext-docx { background: #2b5797; }
.ext-xls,
.ext-xlsx { background: #217346; }
.ext-txt { background: #555; }
.attachment-file-name {
  flex: 0 1 auto;
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.attachment-file-remove {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: flex;
  align-items: center;
  font-size: 16px;
  line-height: 1;
  transition: color 0.15s;
}
.attachment-file-remove:hover {
  color: var(--danger);
}
.attachment-remove {
  position: absolute;
  top: 2px;
  right: 2px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: rgba(0,0,0,0.5);
  color: #fff;
  font-size: 12px;
  line-height: 16px;
  text-align: center;
  cursor: pointer;
  transition: background 0.15s;
}
.attachment-remove:hover {
  background: rgba(220,38,38,0.8);
}

/* 展示模式颜色点 */
.handover-list li.level-2::before {
  background: #dc2626;
}
.handover-list li.level-1::before {
  background: #f59e0b;
}
.handover-list li.level-0::before {
  background: #16a34a;
}

/* 查看模式文本颜色跟随圆点 */
.handover-list li.level-2 {
  color: #dc2626;
}
.handover-list li.level-1 {
  color: #f59e0b;
}

/* 列表文本 - 自动撑满 */
/* 编辑模式文本颜色跟随圆点 */
.handover-input-row-with-dot.input-level-2 :deep(.el-input__inner),
.handover-input-row-with-dot.input-level-2 :deep(.el-textarea__inner) {
  color: #dc2626 !important;
}
.handover-input-row-with-dot.input-level-2 .row-index {
  color: #dc2626;
}
.handover-input-row-with-dot.input-level-1 :deep(.el-input__inner),
.handover-input-row-with-dot.input-level-1 :deep(.el-textarea__inner) {
  color: #f59e0b !important;
}
.handover-input-row-with-dot.input-level-1 .row-index {
  color: #f59e0b;
}

.handover-list-text {
  flex: 1;
  min-width: 0;
}

/* 标题右侧操作按钮组（编辑模式多按钮容器） */
.title-action-group {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 2px;
}
.title-action-group .title-action-btn {
  margin-left: 0;
}

/* 标题右侧操作按钮 */
.title-action-btn {
  margin-left: auto;
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: inline-flex;
  align-items: center;
  font-size: 14px;
  padding: 2px 4px;
  border-radius: 4px;
  transition: all 0.15s;
}
.title-action-btn:hover {
  color: var(--primary);
  background: var(--primary-bg);
}
.title-action-btn.paste {
  color: var(--warning);
}
.title-action-btn.paste:hover {
  color: #d97706;
  background: var(--warning-bg);
}
.title-action-btn.clear {
  color: var(--text-4);
}
.title-action-btn.clear:hover {
  color: var(--danger);
  background: var(--danger-bg);
}

/* 复制按钮 */
.handover-list-copy {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: flex;
  align-items: center;
  opacity: 0;
  transition: opacity 0.15s, color 0.15s;
  margin-left: 4px;
}
.handover-list li:hover .handover-list-copy {
  opacity: 1;
}
.handover-list-copy:hover {
  color: var(--primary);
}

/* 空行占位 */
.handover-list-empty {
  font-size: 13px;
  padding: 6px 10px;
  background: var(--bg-page);
  border-radius: 6px;
  min-height: 19.5px;
  line-height: 19.5px;
  list-style: none;
}

/* 待跟进事项 - 上传附件入口 */
.upload-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 6px;
}
.todo-upload-trigger {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border: 1px dashed var(--border);
  border-radius: 6px;
  font-size: 12px;
  color: var(--text-4);
  cursor: pointer;
  width: fit-content;
  transition: all 0.15s;
}
.todo-upload-trigger:hover {
  border-color: var(--primary);
  color: var(--primary);
  background: var(--primary-bg);
}
.upload-hint {
  font-size: 11px;
  color: var(--text-4);
}

/* 分隔线 */
.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}

/* 搜索按钮 */
.filter-actions {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
}

.filter-actions .search-btn {
  height: 32px;
  padding: 0 16px;
  font-size: 13px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.icon-svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.icon-svg.sm {
  width: 14px;
  height: 14px;
}

/* 图片预览遮罩层 */
.image-preview-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.85);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  cursor: zoom-out;
  overflow: hidden;
}
.image-preview-img {
  max-width: 90vw;
  max-height: 90vh;
  object-fit: contain;
  border-radius: 4px;
  display: block;
}
.image-preview-close {
  position: absolute;
  top: 20px;
  right: 30px;
  color: #fff;
  font-size: 36px;
  font-weight: 300;
  cursor: pointer;
  line-height: 1;
  z-index: 10000;
}
.image-preview-close:hover {
  color: #f00;
}</style>
