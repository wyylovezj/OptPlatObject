<script setup>
import { ref, reactive, nextTick, onBeforeUnmount, onMounted } from 'vue'
import { Plus, User, UserFilled, Monitor, Document, Grid, Notebook, Check, Edit, Delete, CircleCheck, Upload } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, ElInput, ElTooltip } from 'element-plus'
import { getDuty, getEcc, getSys, getNet, getPM, deleteHandover, saveHandover, getHandovers, confirmHandovers } from '@/api/dutyPageInterface.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { RBAC_IP } from '@/utils/dutyPageData.js'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

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

// 日期范围：默认近一周
const getWeekRangeStr = () => {
  const end = new Date()
  const start = new Date()
  start.setDate(start.getDate() - 6)
  const fmt = d => d.toISOString().split('T')[0]
  return [fmt(start), fmt(end)]
}
const filterDate = ref(getWeekRangeStr())

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
      ? { fromColor: rcData.primary, toColor: rcData.secondary, fromDesc: 'ECC 白班 · 08:00-20:00', toDesc: 'ECC 夜班 · 20:00-08:00' }
      : { fromColor: rcData.secondary, toColor: rcData.primary, fromDesc: 'ECC 夜班 · 20:00-08:00', toDesc: 'ECC 白班 · 08:00-20:00' }
  } else {
    rc = { fromColor: rcData.both, toColor: rcData.both, fromDesc: role.label + ' · 08:30-18:00', toDesc: role.label + ' · 08:30-18:00' }
  }


  return {
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
    fromName: item.fromPersonnelName || '',
    fromUserCode: item.fromPersonnelId || '',
    fromSurname: (item.fromPersonnelName || '').charAt(0) || '—',
    fromColor: rc.fromColor,
    fromRoleDesc: rc.fromDesc,
    toName: item.toPersonnelName || '',
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
    editingRole: false,
    editingFrom: false,
    editingTo: false,
  }
}

// 重置筛选条件
const resetFilters = () => {
  filterRole.value = ''
  filterStatus.value = ''
  filterShiftType.value = ''
  filterDate.value = getWeekRangeStr()
  searchHandover()
}

// 搜索函数
const searchHandover = async () => {
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
const prevSchedules = ref([])
const allPersonnel = ref([])

// 获取排班信息和人员列表
const loadHandoverInitData = async () => {
  const today = new Date().toISOString().split('T')[0]

  // 计算昨天日期
  const yesterdayDate = new Date()
  yesterdayDate.setDate(yesterdayDate.getDate() - 1)
  const yesterdayStr = yesterdayDate.toISOString().split('T')[0]

  // 计算过去30天的开始日期（用于查找非ECC人员的前一个排班记录）
  const pastDate = new Date()
  pastDate.setDate(pastDate.getDate() - 30)
  const pastStr = pastDate.toISOString().split('T')[0]

  try {
    const [scheduleArr, yesterdayArr, pastArr] = await Promise.all([
      getDuty([today, today]),
      getDuty([yesterdayStr, yesterdayStr]),
      getDuty([pastStr, yesterdayStr]),
    ])
    todaySchedule.value = Array.isArray(scheduleArr) && scheduleArr.length > 0 ? scheduleArr[0] : null
    yesterdaySchedule.value = Array.isArray(yesterdayArr) && yesterdayArr.length > 0 ? yesterdayArr[0] : null
    prevSchedules.value = Array.isArray(pastArr) ? pastArr : []
  } catch (e) {
    console.error('获取排班数据失败:', e)
  }

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
  } catch (e) {
    console.error('获取人员列表失败:', e)
  }
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
      // 白班→夜班 (20:00-8:00)：交班人=今天白班，接班人=今天夜班
      card.fromRoleDesc = 'ECC 白班 · 08:00-20:00'
      card.toRoleDesc = 'ECC 夜班 · 20:00-08:00'

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
      // 夜班→白班 (8:00-20:00)：交班人=前一天夜班，接班人=今天白班
      card.fromRoleDesc = 'ECC 夜班 · 20:00-08:00'
      card.toRoleDesc = 'ECC 白班 · 08:00-20:00'

      // 交班人：前一天的夜班人员
      if (yesterdayScheduleData) {
        const fromName = yesterdayScheduleData.eccNightPersonnelName || yesterdayScheduleData.ecc_night_personnel_id || ''
        card.fromName = getPersonName(fromName) || fromName || '未排班'
        card.fromSurname = getSurname(card.fromName) || '—'
        const fromPerson = allPersonnel.value.find(p => p.userCode === fromName || p.name === card.fromName)
        card.fromUserCode = fromPerson ? fromPerson.userCode : ''
      } else {
        card.fromName = '未排班'
        card.fromSurname = '—'
        card.fromUserCode = ''
      }

      // 接班人：今天的白班人员
      if (schedule) {
        const toName = schedule.eccDayPersonnelName || schedule.ecc_day_personnel_id || ''
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
    const today = new Date().toISOString().split('T')[0]
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
}

// 根据卡片角色筛选可用人员
const getPersonnelByCard = (card) => {
  const categoryMap = { ecc: 'ecc', sys: 'sys', net: 'net', pm: 'pm' }
  const cat = categoryMap[card.roleValue]
  return cat ? allPersonnel.value.filter(p => p.category === cat) : allPersonnel.value
}

// 交班人选择
const onFromSelect = (card, userCode) => {
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
  const person = allPersonnel.value.find(p => p.userCode === userCode)
  if (person) {
    card.toName = person.name
    card.toUserCode = person.userCode
    card.toSurname = getSurname(person.name)
  }
  card.editingTo = false
}

// 点击编辑交班人/接班人：显示下拉框并自动聚焦展开
const handleEditPerson = (card, type) => {
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
  const shiftType = (hour >= 8 && hour < 20) ? 2 : 1

  const pad = n => String(n).padStart(2, '0')
  const today = now.toISOString().split('T')[0]
  const handoverTime = `${today} ${pad(hour)}:${pad(now.getMinutes())}`

  const draftCard = reactive({
    isDraft: true,
    handoverId: crypto.randomUUID(),
    _cardId: 'card-draft-' + Date.now(),
    date: today,
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
    card.shiftType = 3
    card.shiftLabel = '同组交接'
    card.shiftClass = 'shift-day'
  } else {
    const now = new Date()
    const hour = now.getHours()
    card.shiftType = (hour >= 8 && hour < 20) ? 2 : 1
    card.shiftLabel = card.shiftType === 1 ? '白班 → 夜班' : '夜班 → 白班'
    card.shiftClass = card.shiftType === 1 ? 'shift-day' : 'shift-night'
  }
  // 清空交班人和接班人
  card.fromName = ''
  card.fromUserCode = ''
  card.fromSurname = ''
  card.toName = ''
  card.toUserCode = ''
  card.toSurname = ''
  fillPersonnel(card)
  card.editingRole = false
}

// 切换 ECC 交班方向（白班↔夜班）
const toggleShift = (card) => {
  if (card.roleValue !== 'ecc' || !card.isDraft) return
  card.shiftType = card.shiftType === 1 ? 2 : 1
  card.shiftLabel = card.shiftType === 1 ? '白班 → 夜班' : '夜班 → 白班'
  card.shiftClass = card.shiftType === 1 ? 'shift-day' : 'shift-night'
  // 仅交换交班人和接班人，保留用户已选人员，不覆盖
  ;[card.fromName, card.toName] = [card.toName, card.fromName]
  ;[card.fromUserCode, card.toUserCode] = [card.toUserCode, card.fromUserCode]
  ;[card.fromSurname, card.toSurname] = [card.toSurname, card.fromSurname]
  ;[card.fromColor, card.toColor] = [card.toColor, card.fromColor]
  ;[card.fromRoleDesc, card.toRoleDesc] = [card.toRoleDesc, card.fromRoleDesc]
}

// 系统运行状态：添加新行
const addStatusItem = (card, index) => {
  const newUid = ++lineUidCounter.value
  card.systemStatus.splice(index + 1, 0, { text: '', level: 0, _uid: newUid })
  nextTick(() => {
    const el = document.querySelector(`[data-status-uid="${newUid}"] input`)
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
    const el = document.querySelector(`[data-todo-uid="${newUid}"] input`)
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
    card.systemStatus.push({ text: '—', level: 0, _uid: ++lineUidCounter.value })
  }
  if (card.todoItems.length === 0) {
    card.todoItems.push({ text: '—', level: 0, _uid: ++lineUidCounter.value, attachments: [] })
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

// 重新编辑已保存的卡片
const editDraftCard = (card) => {
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

// ============ 导出 PDF ============
const exportToPdf = async () => {
  ElMessage.closeAll()
  if (handoverList.value.length === 0) {
    ElMessage.warning('当前没有可导出的记录')
    return
  }

  ElMessage.info('正在生成 PDF，请稍候...')

  try {
    const pdf = new jsPDF('l', 'mm', 'a4') // 横向 A4
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    const margin = 5
    const gap = 6 // 卡片间距 mm
    const maxWidth = pageWidth - margin * 2
    const usableHeight = pageHeight - margin * 2

    const cards = document.querySelectorAll('.handover-card')
    if (cards.length === 0) {
      ElMessage.warning('未找到可导出的卡片')
      return
    }

    let yOffset = margin

    for (let i = 0; i < cards.length; i++) {
      const canvas = await html2canvas(cards[i], {
        useCORS: true,
        scale: 3,
        backgroundColor: '#ffffff',
        logging: false,
      })

      const imgData = canvas.toDataURL('image/png')
      const imgWidth = maxWidth
      const imgHeight = (canvas.height * imgWidth) / canvas.width

      // 如果当前页剩余空间不够放这张卡片，另起一页
      if (yOffset + imgHeight > margin + usableHeight) {
        pdf.addPage()
        yOffset = margin
      }

      // 水平居中
      const xOffset = margin + (maxWidth - imgWidth) / 2
      pdf.addImage(imgData, 'PNG', xOffset, yOffset, imgWidth, imgHeight)
      yOffset += imgHeight + gap
    }

    const now = new Date()
    const pad = n => String(n).padStart(2, '0')
    const dateStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`
    pdf.save(`\u4ea4\u63a5\u73ed\u8bb0\u5f55_${dateStr}.pdf`)

    ElMessage.closeAll()
    ElMessage.success(`导出成功，共 ${cards.length} 条记录`)
  } catch (e) {
    console.error('导出 PDF 失败:', e)
    ElMessage.closeAll()
    ElMessage.error('导出 PDF 失败：' + (e.message || '未知错误'))
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
        <el-button v-if="permissionStore.hasPermission('duty:handoverExport')" class="btn-outline" @click="exportToPdf">导出记录</el-button>
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
                    @change="onRoleChange(item)"
                    @visible-change="(v) => { if (!v) item.editingRole = false }"
                  >
                    <el-option v-for="opt in roleOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
                  </el-select>
                </span>
              </template>
              <template v-else>{{ item.role }}</template>
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
                <el-tooltip v-if="item.statusClass !== 'completed' && permissionStore.hasPermission('duty:handoverDelete') && isCardCreator(item)" content="删除" placement="top">
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

            <div class="handover-divider"></div>

            <!-- 系统运行状态 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Monitor /></el-icon> 系统运行状态
              </div>
              <template v-if="item.isDraft">
                <div v-for="(line, li) in item.systemStatus" :key="'s-' + line._uid" class="handover-input-row-with-dot" :data-status-uid="line._uid">
                  <span
                    class="severity-dot"
                    :style="{ background: getLevelColor(line.level) }"
                    :title="severityLevels.find(s => s.value === line.level)?.label"
                    @click="cycleLevel(line)"
                  ></span>
                  <el-input
                    v-model="line.text"
                    size="small"
                    spellcheck="false"
                    placeholder="输入系统运行状态，回车添加下一条..."
                    @keydown.enter.prevent="addStatusItem(item, li)"
                  />
                  <span class="row-delete-btn" @click="removeLineItem(item.systemStatus, li)" v-if="item.systemStatus.length > 1">
                    <el-icon><Delete /></el-icon>
                  </span>
                </div>
              </template>
              <ul v-else class="handover-list">
                <li v-for="(line, li) in item.systemStatus" :key="'s-' + li" :class="getLevelClass(line.level) || { 'warn-item': line.warn, 'danger-item': line.danger }">
                  {{ line.text }}
                </li>
              </ul>
            </div>

            <!-- 待跟进事项 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Document /></el-icon> 待跟进事项
              </div>
              <template v-if="item.isDraft">
                <template v-for="(line, li) in item.todoItems" :key="'t-' + line._uid">
                  <div class="handover-input-row-with-dot" :data-todo-uid="line._uid">
                    <span
                      class="severity-dot"
                      :style="{ background: getLevelColor(line.level) }"
                      :title="severityLevels.find(s => s.value === line.level)?.label"
                      @click="cycleLevel(line)"
                    ></span>
                    <el-input
                      v-model="line.text"
                      size="small"
                      spellcheck="false"
                      placeholder="输入待跟进事项，回车添加下一条..."
                      @keydown.enter.prevent="addTodoItem(item, li)"
                    />
                    <span class="row-delete-btn" @click="removeLineItem(item.todoItems, li)" v-if="item.todoItems.length > 1">
                      <el-icon><Delete /></el-icon>
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
                  <li v-for="(line, li) in item.todoItems" :key="'t-' + li" :class="getLevelClass(line.level) || { 'warn-item': line.warn, 'danger-item': line.danger }">
                    {{ line.text }}
                  </li>
                </ul>
                <!-- 查看模式附件 -->
                <div class="handover-content-title" style="margin-top: 12px;">
                  <el-icon><Upload /></el-icon> 附件
                </div>
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
                <span>创建人：{{ item.createUserNickname || '' }} &nbsp;|&nbsp; 交接时间：{{ item.handoverTime }}</span>
              </template>
              <template v-else>
                <span>创建人：{{ item.createUserNickname || '' }} &nbsp;|&nbsp; 交接时间：{{ item.handoverTime }} &nbsp;|&nbsp; 接班人确认：<strong :style="{ color: item.confirmColor }">{{ item.confirmText }}</strong>
                <template v-if="item.confirmTime">&nbsp;|&nbsp; 确认时间：{{ item.confirmTime }}</template></span>
              </template>
            </div>
            </div>
          </div>
        </div>
      </div>
    </el-scrollbar>

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
        <el-form-item label="待跟进事项">
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
  gap: 8px;
  padding: 6px 10px;
  background: var(--bg-page);
  border-radius: 6px;
  margin-bottom: 6px;
  font-size: 13px;
}
.handover-input-row-with-dot:last-child {
  margin-bottom: 0;
}
.handover-input-row-with-dot :deep(.el-input) {
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
.handover-input-row-with-dot :deep(.el-input__inner) {
  font-size: 13px;
  color: var(--text-2);
  height: 19.5px;
  line-height: 19.5px;
  padding: 0;
  background: transparent !important;
}

/* 颜色点 */
.severity-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-top: 6px;
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
  margin-top: 1px;
  transition: color 0.15s;
}
.row-delete-btn:hover {
  color: var(--danger);
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
