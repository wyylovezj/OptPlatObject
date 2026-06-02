0
<script setup>
import { ref, reactive, computed, watch, onMounted, nextTick } from 'vue'
import { Plus, ArrowLeft, ArrowRight, Document, Edit, Paperclip, Check, Delete, CircleCheck, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, ElTooltip, ElPopover, ElDialog, ElEmpty } from 'element-plus'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'
import { saveDutyLog, getDutyLogs, deleteDutyLog, confirmDutyLog, saveNotes, getNotes } from '@/api/dutyPageInterface.js'
import { RBAC_IP } from '@/utils/dutyPageData.js'
import { usePermissionStore } from '@/stores/permissionStore.js'

// ============ 日期导航 ============
// 权限状态管理
const permissionStore = usePermissionStore()

const logDate = ref(new Date())

const logDateStr = computed(() => {
  const d = logDate.value
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
})

const logDateLabel = computed(() => {
  const days = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  const d = logDate.value
  return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日 · ' + days[d.getDay()]
})

const logDateFormatted = computed(() => {
  const d = logDate.value
  return d.getMonth() + 1 + '月' + d.getDate() + '日'
})

const isToday = computed(() => {
  const now = new Date()
  const d = logDate.value
  return d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
})

const shiftLogDate = (dir) => {
  logDate.value.setDate(logDate.value.getDate() + dir)
  logDate.value = new Date(logDate.value)
}

const goLogToday = () => {
  logDate.value = new Date()
}

// ============ 日志条目 ============

// 圆点颜色弹窗显隐状态
const dotColorVisible = reactive({})

// 标签输入状态（参考 Element Plus 动态标签模式）
const tagInputEntry = ref(-1)
const tagInputColor = ref('')
const tagInputValue = ref('')




const loadLogEntries = async () => {
  try {
    const data = await getDutyLogs(logDateStr.value)
    const dotClassReverse = { 0: '', 1: 'success', 2: 'warn', 3: 'danger' }
    const tagClassReverse = { 5: 'danger', 4: 'warn', 3: 'resolve', 2: 'info', 1: 'default' }

    logEntries.value = (data || []).map(item => ({
      logDate: item.log_date,
      time: item.log_time || '',
      dotClass: dotClassReverse[item.dot_class] || '',
      isDraft: item.status === 0,
      confirmed: item.status === 2,
      editingTitle: false,
      editingDesc: false,
      title: item.title || '',
      desc: item.description || '',
      createUser: item.create_user || '',
      createUserNickname: item.create_user_nickname || '',
      tags: (item.tags || []).map(t => ({
        text: t.tag_text,
        class: tagClassReverse[t.tag_class] || 'default'
      })),
      attachments: (item.attachments || []).map(a => ({
        name: a.file_name,
        file_path: a.file_path || null,
        file_size: a.file_size || null,
        content_type: a.content_type || null
      }))
    }))
  } catch (e) {
    console.error('加载值班日志失败:', e)
    logEntries.value = []
  }
  await loadDutyNotes()
}

const loadDutyNotes = async () => {
  try {
    const data = await getNotes(logDateStr.value)
    const notes = Array.isArray(data) ? data : (data && data.data && Array.isArray(data.data) ? data.data : [])
    dutyNoteUidCounter.value = notes.length
    dutyNoteItems.value = notes.map((item, idx) => ({
      text: item.description || '',
      level: item.level ?? 0,
      _uid: idx + 1,
      _noteId: item.note_id || '',
      _originalText: item.description || '',
      _originalCreateUser: item.create_user || '',
      _originalCreateUserNickname: item.create_user_nickname || '',
    }))
  } catch (e) {
    console.error('加载值班备注失败:', e)
  }
}

// 日期变化时重新加载日志
watch(logDate, () => {
  loadLogEntries()
})

onMounted(() => {
  loadLogEntries()
})

// 刷新日志（点击刷新按钮）
const refreshLogEntries = () => {
  ElMessage.closeAll()
  loadLogEntries()
  ElMessage.success('已刷新')
}

// 格式化卡片日期显示（预留）
// const formatCardDate = (dateStr) => {
//   if (!dateStr) return ''
//   const parts = dateStr.split('-')
//   if (parts.length < 3) return dateStr
//   return parseInt(parts[1]) + '月' + parseInt(parts[2]) + '日'
// }

// ============ 日志条目操作 ============
const isLogCreator = (item) => {
  return permissionStore.userInfo?.username && item.createUser &&
    permissionStore.userInfo.username === item.createUser
}

const editLogEntry = (idx) => {
  logEntries.value[idx].isDraft = true
}

const handleEditTitle = (idx) => {
  logEntries.value[idx].editingTitle = true
  nextTick(() => {
    const input = document.querySelector(`[data-log-title-input="${idx}"]`)
    if (input) input.focus()
  })
}

const handleEditDesc = (idx) => {
  logEntries.value[idx].editingDesc = true
  nextTick(() => {
    const input = document.querySelector(`[data-log-desc-input="${idx}"]`)
    if (input) input.focus()
  })
}

const saveLogEntry = async (idx) => {
  ElMessage.closeAll()
  const entry = logEntries.value[idx]
  // 校验必填项
  if (!entry.title || !entry.title.trim()) {
    ElMessage.warning('请填写事件标题')
    return
  }
  const date = logDate.value
  // 如果条目自带 logDate 则用它，否则用导航日期
  const logDateStr = entry.logDate || `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
  const parts = logDateStr.split('-')
  const y = parts[0]
  const m = parts[1]
  const d = parts[2]
  const t = entry.time.replace(/:/g, '')
  const logId = `${y}${m}${d}${t}`

  const dotClassMap = { '': 0, 'success': 1, 'warn': 2, 'danger': 3 }
  const tagClassMap = { 'danger': 5, 'warn': 4, 'resolve': 3, 'info': 2, 'default': 1 }

  const files = (entry.attachments || []).filter(att => att.file).map(att => att.file)

  const logData = {
    log_id: logId,
    log_date: `${y}-${m}-${d}`,
    log_time: entry.time,
    dot_class: dotClassMap[entry.dotClass] || 0,
    title: entry.title || '',
    description: entry.desc || '',
    create_user: entry.createUser || '',
    create_user_nickname: entry.createUserNickname || '',
    status: entry.confirmed ? 2 : 1,
    sort_order: idx,
    tags: (entry.tags || []).map(tag => ({
      tag_text: tag.text,
      tag_class: tagClassMap[tag.class] || 1,
      sort_order: 0
    })),
    attachments: (entry.attachments || []).map((att, attIdx) => ({
      file_name: att.name,
      file_size: att.file ? att.file.size : null,
      content_type: att.file ? att.file.type : null,
      sort_order: attIdx
    }))
  }

  try {
    await saveDutyLog(logData, files)
    entry.isDraft = false
    entry._localOnly = false
    entry.editingTitle = false
    entry.editingDesc = false
    ElMessage.success('日志已保存')
    await loadLogEntries()
  } catch (e) {
    ElMessage.error('保存失败: ' + e.message)
    await loadLogEntries()
  }
}

const confirmLogEntry = (idx) => {
  const entry = logEntries.value[idx]
  if (entry.confirmed) return
  ElMessage.closeAll()
  ElMessageBox.confirm('确认后该日志将不可修改，确定执行？', '确认记录', {
    confirmButtonText: '确认',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(async () => {
      try {
        const date = logDate.value
        const logDateStr = entry.logDate || `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
        const parts = logDateStr.split('-')
        const t = entry.time.replace(/:/g, '')
        const logId = `${parts[0]}${parts[1]}${parts[2]}${t}`
        await confirmDutyLog(logId)
      } catch (e) {
        ElMessage.error('确认失败: ' + e.message)
        await loadLogEntries()
        return
      }
      entry.confirmed = true
      entry.isDraft = false
      entry.editingTitle = false
      entry.editingDesc = false
      ElMessage.closeAll()
      ElMessage.success('日志已确认')
      await loadLogEntries()
    })
    .catch(() => {})
}

const deleteLogEntry = (idx) => {
  const entry = logEntries.value[idx]
  ElMessage.closeAll()
  ElMessageBox.confirm('确定删除此日志记录吗？', '确认删除', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(async () => {
      if (!entry._localOnly) {
        // 已保存的记录需调用后端接口删除
        try {
          const date = logDate.value
          const logDateStr = entry.logDate || `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
          const parts = logDateStr.split('-')
          const t = entry.time.replace(/:/g, '')
          const logId = `${parts[0]}${parts[1]}${parts[2]}${t}`
          await deleteDutyLog(logId)
        } catch (e) {
          ElMessage.error('删除失败: ' + e.message)
          await loadLogEntries()
          return
        }
      }
      logEntries.value.splice(idx, 1)
      ElMessage.closeAll()
      ElMessage.success('日志已删除')
      await loadLogEntries()
    })
    .catch(() => {})
}

const logEntries = ref([])

// ============ 值班备注 ============
const dutyNoteUidCounter = ref(0)
const dutyNoteItems = ref([])
const dutyNoteEditing = ref(false)

// 生成全局唯一 ID（用于新建值班备注的 note_id）
const genNoteId = () => {
  try {
    return crypto.randomUUID()
  } catch {
    // 兼容不支持 crypto.randomUUID 的环境
    return 'note-' + Date.now() + '-' + Math.random().toString(36).substring(2, 10)
  }
}

const addDutyNoteItem = (index) => {
  const newUid = ++dutyNoteUidCounter.value
  dutyNoteItems.value.splice(index + 1, 0, { text: '', level: 0, _uid: newUid, _noteId: '', _originalText: '', _originalCreateUser: '', _originalCreateUserNickname: '' })
  nextTick(() => {
    const el = document.querySelector(`[data-duty-note-uid="${newUid}"] input`)
    if (el) el.focus()
  })
}

const removeDutyNoteItem = (list, index) => {
  list.splice(index, 1)
}

const editDutyNote = async () => {
  await loadDutyNotes()
  dutyNoteEditing.value = true
  if (dutyNoteItems.value.length === 0) {
    dutyNoteItems.value = [{ text: '', level: 0, _uid: ++dutyNoteUidCounter.value, _noteId: '', _originalText: '', _originalCreateUser: '', _originalCreateUserNickname: '' }]
  }
}

const saveDutyNote = async () => {
  ElMessage.closeAll()
  // 清理空行
  for (let i = dutyNoteItems.value.length - 1; i >= 0; i--) {
    if (!dutyNoteItems.value[i].text.trim()) {
      dutyNoteItems.value.splice(i, 1)
    }
  }
  if (dutyNoteItems.value.length === 0) {
    dutyNoteItems.value.push({ text: '', level: 0, _uid: ++dutyNoteUidCounter.value, _noteId: '' })
  }
  // 构建备注数据
  const notesData = dutyNoteItems.value.map((item, idx) => {
    const isModified = item.text !== item._originalText
    return {
      note_id: item._noteId || genNoteId(),
      note_date: logDateStr.value,
      description: item.text,
      level: item.level ?? 0,
      create_user: isModified ? (permissionStore.userInfo?.username || '') : (item._originalCreateUser || ''),
      create_user_nickname: isModified ? (permissionStore.userInfo?.nickname || '') : (item._originalCreateUserNickname || ''),
      sort_order: idx,
    }
  })
  try {
    await saveNotes(notesData)
    // 更新原始文本记录
    dutyNoteItems.value.forEach(item => {
      const isModified = item.text !== item._originalText
      item._originalText = item.text
      if (isModified) {
        item._originalCreateUser = permissionStore.userInfo?.username || ''
        item._originalCreateUserNickname = permissionStore.userInfo?.nickname || ''
      }
    })
    dutyNoteEditing.value = false
    ElMessage.success('备注已保存')
    await loadLogEntries()
  } catch (e) {
    ElMessage.error('保存备注失败: ' + e.message)
    await loadLogEntries()
  }
}

// ============ 新增日志弹窗 ============
const logModalVisible = ref(false)
const newLog = reactive({
  time: '16:30:00',
  type: 'alert',
  title: '',
  desc: '',
  tags: [],
})
const availableTags = [
  { value: 'danger', label: '危急', class: 'danger' },
  { value: 'resolve', label: '恢复正常', class: 'resolve' },
  { value: 'info', label: '日常记录', class: 'info' },
  { value: 'warn', label: '严重', class: 'warn' },
]

// 标签颜色选项（日志条目内联添加，5种颜色）
const tagColors = [
  { class: 'danger', label: '危急' },
  { class: 'warn', label: '严重' },
  { class: 'resolve', label: '恢复正常' },
  { class: 'info', label: '日常记录' },
  { class: 'default', label: '普通信息' },
]

const toggleTag = (value) => {
  const idx = newLog.tags.indexOf(value)
  if (idx >= 0) {
    newLog.tags.splice(idx, 1)
  } else {
    newLog.tags.push(value)
  }
}

const addTag = (idx, colorClass) => {
  tagInputEntry.value = idx
  tagInputColor.value = colorClass
  tagInputValue.value = ''
  nextTick(() => {
    const input = document.querySelector(`[data-log-tag-input="${idx}"]`)
    if (input) input.focus()
  })
}

const confirmTagInput = () => {
  const idx = tagInputEntry.value
  if (idx < 0) return
  const entry = logEntries.value[idx]
  if (tagInputValue.value) {
    if (!entry.tags) entry.tags = []
    entry.tags.push({ text: tagInputValue.value, class: tagInputColor.value })
  }
  tagInputEntry.value = -1
  tagInputColor.value = ''
  tagInputValue.value = ''
}

const removeTag = (idx, tag) => {
  const entry = logEntries.value[idx]
  const i = entry.tags.indexOf(tag)
  if (i >= 0) entry.tags.splice(i, 1)
}

const openLogModal = async () => {
  await loadLogEntries()
  const now = new Date()
  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const ss = String(now.getSeconds()).padStart(2, '0')
  const currentTime = hh + ':' + mm + ':' + ss
  logEntries.value.push({
    logDate: logDateStr.value,
    time: currentTime,
    dotClass: '',
    isDraft: true,
    confirmed: false,
    _localOnly: true,
    editingTitle: true,
    editingDesc: false,
    title: '',
    desc: '',
    createUser: permissionStore.userInfo?.username || '',
    createUserNickname: permissionStore.userInfo?.nickname || '',
    tags: [],
    attachments: [],
  })
  nextTick(() => {
    const input = document.querySelector(`[data-log-title-input="${logEntries.value.length - 1}"]`)
    if (input) input.focus()
  })
}
const submitLog = () => {
  ElMessage.success('日志已保存')
  logModalVisible.value = false
}

const handleAttachmentClick = (idx) => {
  const input = document.querySelector(`[data-attachment-input="${idx}"]`)
  if (input) input.click()
}

const onAttachmentSelect = (event, idx) => {
  const files = Array.from(event.target.files)
  if (files.length > 0) {
    const entry = logEntries.value[idx]
    if (!entry.attachments) entry.attachments = []
    files.forEach(file => {
      const url = URL.createObjectURL(file)
      entry.attachments.push({ name: file.name, file, url })
    })
  }
  event.target.value = ''
}

const previewAttachment = (attachment) => {
  if (!attachment) return
  const name = typeof attachment === 'string' ? attachment : attachment.name
  // 有 file_path 则构造后端下载地址，否则用 blob url（草稿附件）
  const url = attachment.file_path
    ? `${RBAC_IP.value}${attachment.file_path}`
    : (attachment.url || null)
  if (!url) return
  const isImage = /\.(png|jpg|jpeg|gif|webp|bmp|svg)$/i.test(name)
  const isPdf = /\.pdf$/i.test(name)
  if (isImage) {
    previewImageUrl.value = url
    previewVisible.value = true
  } else if (isPdf) {
    previewPdfUrl.value = url
    previewPdfVisible.value = true
  } else {
    // 非图片/PDF文件触发下载
    const a = document.createElement('a')
    a.href = url
    a.download = name
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
  }
}

const removeAttachment = (idx, attIdx) => {
  const entry = logEntries.value[idx]
  const att = entry.attachments[attIdx]
  if (att && att.url) URL.revokeObjectURL(att.url)
  entry.attachments.splice(attIdx, 1)
}

const previewImageUrl = ref('')
const previewVisible = ref(false)
const previewPdfVisible = ref(false)
const previewPdfUrl = ref('')

const closePreview = () => {
  previewVisible.value = false
  previewImageUrl.value = ''
}

// 选择圆点颜色并关闭弹窗
const selectDotColor = (idx, colorClass) => {
  logEntries.value[idx].dotClass = colorClass
  dotColorVisible[idx] = false
}

// ============ 导出 PDF ============
const exportToPdf = async () => {
  ElMessage.closeAll()
  if (logEntries.value.length === 0 && dutyNoteItems.value.every(item => !item.text.trim() || item.text.trim() === '—')) {
    ElMessage.warning('当前没有可导出的内容')
    return
  }

  ElMessage.info('正在生成 PDF，请稍候...')

  try {
    const pdf = new jsPDF('l', 'mm', 'a4') // 横向 A4
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    const margin = 5
    const gap = 6
    const maxWidth = pageWidth - margin * 2
    const usableHeight = pageHeight - margin * 2

    let yOffset = margin

    // --- 值班日志时间线条目（逐条截取，标题栏 + 每项日志） ---
    const entries = document.querySelectorAll('.log-entry')
    if (entries.length > 0) {
      // 记录内容区起始位置，用于后续画边框
      const contentStartX = margin
      let contentStartY = yOffset

      // 先截取卡片标题栏
      const headerEl = document.querySelector('.log-timeline-card .card-header')
      if (headerEl) {
        const headerCanvas = await html2canvas(headerEl, {
          useCORS: true,
          scale: 3,
          backgroundColor: '#ffffff',
          logging: false,
        })
        const headerImgData = headerCanvas.toDataURL('image/png')
        const headerImgWidth = maxWidth
        const headerImgHeight = (headerCanvas.height * headerImgWidth) / headerCanvas.width
        pdf.addImage(headerImgData, 'PNG', contentStartX, yOffset, headerImgWidth, headerImgHeight)
        yOffset += headerImgHeight
        contentStartY = yOffset // 边框从标题栏下方开始
      }

      for (let i = 0; i < entries.length; i++) {
        const canvas = await html2canvas(entries[i], {
          useCORS: true,
          scale: 3,
          backgroundColor: '#ffffff',
          logging: false,
        })

        const imgData = canvas.toDataURL('image/png')
        const imgWidth = maxWidth
        const imgHeight = (canvas.height * imgWidth) / canvas.width

        if (yOffset + imgHeight > margin + usableHeight) {
          pdf.addPage()
          yOffset = margin
          contentStartY = yOffset
        }

        pdf.addImage(imgData, 'PNG', contentStartX, yOffset, imgWidth, imgHeight)
        yOffset += imgHeight + gap
      }

      // 画圆角边框（顶部被标题栏图片覆盖，只露出左右下三边圆角）
      const contentEndY = yOffset - gap
      pdf.setDrawColor(226, 232, 240) // #e2e8f0
      pdf.setLineWidth(0.5)
      pdf.roundedRect(contentStartX, contentStartY, maxWidth, contentEndY - contentStartY, 3, 3, 'S')
      yOffset += 3 // 边框后留点间距
    }

    // --- 值班备注 ---
    const hasRealNotes = dutyNoteItems.value.some(item => item.text.trim() && item.text.trim() !== '—')
    if (hasRealNotes) {
      const noteCard = document.querySelector('.log-note-card')
      if (noteCard) {
        const canvas = await html2canvas(noteCard, {
          useCORS: true,
          scale: 3,
          backgroundColor: '#ffffff',
          logging: false,
        })

        const imgData = canvas.toDataURL('image/png')
        const imgWidth = maxWidth
        const imgHeight = (canvas.height * imgWidth) / canvas.width

        if (yOffset + imgHeight > margin + usableHeight) {
          pdf.addPage()
          yOffset = margin
        }

        const xOffset = margin + (maxWidth - imgWidth) / 2
        pdf.addImage(imgData, 'PNG', xOffset, yOffset, imgWidth, imgHeight)
        yOffset += imgHeight + gap
      }
    }

    const now = new Date()
    const pad = n => String(n).padStart(2, '0')
    const dateStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`
    const entryCount = entries.length + (hasRealNotes ? 1 : 0)
    pdf.save(`值班日志_${logDateStr.value}_${dateStr}.pdf`)

    ElMessage.closeAll()
    ElMessage.success(`导出成功，共 ${entryCount} 项`)
  } catch (e) {
    console.error('导出 PDF 失败:', e)
    ElMessage.closeAll()
    ElMessage.error('导出 PDF 失败：' + (e.message || '未知错误'))
  }
}
</script>

<template>
  <div class="log-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">值班日志</h2>
    </div>

    <!-- 日期导航 -->
    <div class="log-header-bar">
      <div class="log-date-nav">
        <button class="log-nav-btn" @click="shiftLogDate(-1)">
          <el-icon><ArrowLeft /></el-icon>
        </button>
        <div class="log-current-date">{{ logDateLabel }}</div>
        <button class="log-nav-btn" @click="shiftLogDate(1)">
          <el-icon><ArrowRight /></el-icon>
        </button>
        <el-button size="small" @click="goLogToday">今天</el-button>
      </div>
      <div class="toolbar-actions">
        <el-button v-if="permissionStore.hasPermission('duty:logExport')" class="btn-outline" @click="exportToPdf">导出日志</el-button>
        <el-button v-if="permissionStore.hasPermission('duty:logCreate')" type="primary" class="btn-primary-custom" :disabled="!isToday" @click="openLogModal">
          <el-icon><Plus /></el-icon>
          新增日志
        </el-button>
      </div>
    </div>

    <!-- 日志主体 -->
    <div class="log-body-wrapper">
      <!-- 日志时间线 -->
      <div class="card log-timeline-card">
        <div class="card-header">
          <div class="card-title">
            <el-icon><Document /></el-icon>
            值班日志时间线
          </div>
          <el-tooltip content="刷新" placement="top">
            <el-button type="info" plain class="search-btn" @click="refreshLogEntries">
              <svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>
            </el-button>
          </el-tooltip>
        </div>
        <div v-if="logEntries.length === 0" class="log-empty-state">
          <el-empty description="暂无值班日志" :image-size="200" />
        </div>
        <el-scrollbar v-else class="log-timeline-scroll">
          <div class="log-timeline">
            <div v-for="(entry, idx) in logEntries" :key="idx" class="log-entry">
              <!-- 时间列 -->
              <div class="log-time-col">
                <div class="log-date">{{ entry.logDate }}</div>
                <div class="log-time">{{ entry.time }}</div>
              </div>
              <!-- 圆点列 -->
              <div class="log-dot-col">
                <el-popover
                  v-if="entry.isDraft"
                  :visible="dotColorVisible[idx]"
                  placement="right"
                  trigger="click"
                  :width="130"
                  popper-class="dot-color-popover"
                >
                  <template #reference>
                    <span :class="['log-dot', entry.dotClass]" @click.stop="dotColorVisible[idx] = !dotColorVisible[idx]"></span>
                  </template>
                  <div class="dot-color-options">
                    <div class="dot-color-item" @click="selectDotColor(idx, '')">
                      <span class="dot-color-dot"></span>
                      <span class="dot-color-label">普通</span>
                    </div>
                    <div class="dot-color-item" @click="selectDotColor(idx, 'success')">
                      <span class="dot-color-dot success"></span>
                      <span class="dot-color-label">正常</span>
                    </div>
                    <div class="dot-color-item" @click="selectDotColor(idx, 'warn')">
                      <span class="dot-color-dot warn"></span>
                      <span class="dot-color-label">警告</span>
                    </div>
                    <div class="dot-color-item" @click="selectDotColor(idx, 'danger')">
                      <span class="dot-color-dot danger"></span>
                      <span class="dot-color-label">危险</span>
                    </div>
                  </div>
                </el-popover>
                <span v-else :class="['log-dot', entry.dotClass]"></span>
                <div class="log-line"></div>
              </div>
              <!-- 内容列 -->
              <div class="log-content">
                <div class="log-content-title-row">
                  <template v-if="entry.isDraft && entry.editingTitle">
                    <el-input
                      v-model="entry.title"
                      size="small"
                      class="log-title-input"
                      :data-log-title-input="idx"
                      placeholder="事件标题"
                      maxlength="30"
                      show-word-limit
                      spellcheck="false"
                      :style="{ width: Math.max((entry.title.length || 0) * 2 + 2, 9) + 'ch' }"
                      @blur="entry.editingTitle = false"
                    />
                  </template>
                  <template v-else-if="entry.isDraft && !entry.editingTitle">
                    <span class="title-clickable" @click="handleEditTitle(idx)">{{ entry.title || '点击输入标题' }}</span>
                  </template>
                  <template v-else>
                    <div :class="['log-content-title', { 'log-content-title-empty': !entry.title }]">{{ entry.title || '请录入标题' }}</div>
                  </template>
                  <!-- 确认状态 -->
                  <span :class="['log-entry-status', entry._localOnly ? 'status-pending-save' : (entry.confirmed ? 'status-completed' : 'status-pending')]">{{ entry._localOnly ? '⏳ 待保存' : (entry.confirmed ? '✓ 已确认' : '⏳ 待确认') }}</span>
                  <span class="person-wrap">
                    <span class="person-tag">创建人：{{ entry.createUserNickname || entry.createUser || '' }}</span>
                  </span>
                  <!-- 操作按钮 -->
                  <span class="log-entry-actions">
                    <template v-if="entry.isDraft">
                      <el-tooltip v-if="permissionStore.hasPermission('duty:logSave') && isLogCreator(entry)" content="保存" placement="top">
                        <span class="header-icon-btn save" @click="saveLogEntry(idx)">
                          <el-icon><Check /></el-icon>
                        </span>
                      </el-tooltip>
                    </template>
                    <template v-else-if="!entry.confirmed">
                      <el-tooltip v-if="permissionStore.hasPermission('duty:logEdit') && isLogCreator(entry)" content="编辑" placement="top">
                        <span class="header-icon-btn edit" @click="editLogEntry(idx)">
                          <el-icon><Edit /></el-icon>
                        </span>
                      </el-tooltip>
                      <el-tooltip v-if="permissionStore.hasPermission('duty:logConfirm') && isLogCreator(entry)" content="确认" placement="top">
                        <span class="header-icon-btn confirm" @click="confirmLogEntry(idx)">
                          <el-icon><CircleCheck /></el-icon>
                        </span>
                      </el-tooltip>
                    </template>
                    <el-tooltip v-if="!entry.confirmed && permissionStore.hasPermission('duty:logDelete') && isLogCreator(entry)" content="删除" placement="top">
                      <span class="header-icon-btn delete" @click="deleteLogEntry(idx)">
                        <el-icon><Delete /></el-icon>
                      </span>
                    </el-tooltip>
                  </span>
                </div>
                <template v-if="entry.isDraft && entry.editingDesc">
                  <el-input
                    v-model="entry.desc"
                    type="textarea"
                    class="log-desc-input"
                    :data-log-desc-input="idx"
                    placeholder="详细描述"
                    maxlength="500"
                    show-word-limit
                    spellcheck="false"
                    :autosize="{ minRows: 1, maxRows: 10 }"
                    @blur="entry.editingDesc = false"
                  />
                </template>
                <template v-else-if="entry.isDraft && !entry.editingDesc">
                  <span class="desc-clickable" @click="handleEditDesc(idx)">{{ entry.desc || '点击输入详细描述' }}</span>
                </template>
                <template v-else>
                  <div :class="['log-content-desc', { 'log-content-desc-empty': !entry.desc }]">{{ entry.desc || '请录入日志明细' }}</div>
                </template>
                <div class="log-content-tags">
                  <span class="tags-label">标签</span>
                  <span v-for="(tag, tagIdx) in entry.tags" :key="tagIdx" :class="['log-tag', 'log-tag-' + tag.class, { 'tag-removable': entry.isDraft }]" @click="entry.isDraft && removeTag(idx, tag)">{{ tag.text }}</span>
                  <el-input
                    v-if="entry.isDraft && tagInputEntry === idx"
                    v-model="tagInputValue"
                    size="small"
                    class="tag-edit-input"
                    :class="'tag-edit-' + tagInputColor"
                    :data-log-tag-input="idx"
                    placeholder="输入标签"
                    maxlength="10"
                    spellcheck="false"
                    @keyup.enter="confirmTagInput"
                    @blur="confirmTagInput"
                  />
                  <span v-if="!entry.isDraft && (!entry.tags || entry.tags.length === 0)" class="tags-empty">无</span>
                  <el-popover v-if="entry.isDraft && tagInputEntry !== idx" placement="right" trigger="click" :width="110" popper-class="tag-add-popover">
                    <template #reference>
                      <span class="tag-add-btn">+</span>
                    </template>
                    <div class="tag-add-options">
                      <div v-for="tc in tagColors" :key="tc.class" class="tag-add-option" @click="addTag(idx, tc.class)">
                        <span :class="['tag-color-dot', tc.class]"></span>
                        <span>{{ tc.label }}</span>
                      </div>
                    </div>
                  </el-popover>
                </div>
                <div class="log-content-attachments">
                  <span class="attachments-label">附件</span>
                  <template v-if="entry.attachments && entry.attachments.length > 0">
                    <span v-for="(att, attIdx) in entry.attachments" :key="attIdx" class="log-attachment-item" @click="previewAttachment(att)">
                      <el-icon><Paperclip /></el-icon> {{ att.name }}
                      <span v-if="entry.isDraft" class="attachment-remove-btn" @click.stop="removeAttachment(idx, attIdx)">×</span>
                    </span>
                  </template>
                  <span v-if="!entry.isDraft && (!entry.attachments || entry.attachments.length === 0)" class="attachment-empty">无</span>
                  <template v-if="entry.isDraft">
                    <span class="tag-add-btn" @click="handleAttachmentClick(idx)">+</span>
                    <input type="file" :data-attachment-input="idx" accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar" style="display:none" multiple @change="onAttachmentSelect($event, idx)" />
                  </template>
                </div>
              </div>
            </div>
          </div>
        </el-scrollbar>
      </div>

      <!-- 图片预览弹窗 -->
      <Teleport to="body">
        <div v-if="previewVisible" class="image-preview-overlay" @click.self="closePreview">
          <span class="image-preview-close" @click="closePreview">&times;</span>
          <img :src="previewImageUrl" class="image-preview-img" alt="预览图片" />
        </div>
      </Teleport>

      <!-- PDF预览弹窗 -->
      <el-dialog v-model="previewPdfVisible" title="PDF预览" width="auto" :close-on-click-modal="true" destroy-on-close>
        <div class="preview-pdf-wrap">
          <embed :src="previewPdfUrl" class="preview-pdf-embed" />
        </div>
      </el-dialog>

      <!-- 值班备注 -->
      <div class="card log-note-card">
        <div class="card-header">
          <div class="card-title">
            <el-icon><Edit /></el-icon> 当日值班备注 · {{ logDateFormatted }}
          </div>
          <div class="log-entry-actions">
            <el-tooltip content="刷新" placement="top">
              <span class="header-icon-btn refresh" @click="loadDutyNotes()">
                <el-icon><Refresh /></el-icon>
              </span>
            </el-tooltip>
            <template v-if="dutyNoteEditing">
              <el-tooltip v-if="permissionStore.hasPermission('duty:noteSave')" content="新增一行" placement="top">
                <span class="header-icon-btn add" @click="addDutyNoteItem(dutyNoteItems.length - 1)">
                  <el-icon><Plus /></el-icon>
                </span>
              </el-tooltip>
              <el-tooltip v-if="permissionStore.hasPermission('duty:noteSave')" content="保存" placement="top">
                <span class="header-icon-btn save" @click="saveDutyNote">
                  <el-icon><Check /></el-icon>
                </span>
              </el-tooltip>
            </template>
            <template v-else>
              <el-tooltip v-if="permissionStore.hasPermission('duty:noteEdit')" content="编辑" placement="top">
                <span class="header-icon-btn edit" :class="{ 'is-disabled': !isToday }" :style="!isToday ? 'cursor: not-allowed; opacity: 0.5;' : ''" @click="isToday && editDutyNote()">
                  <el-icon><Edit /></el-icon>
                </span>
              </el-tooltip>
            </template>
          </div>
        </div>
        <div class="log-note-body">
          <div v-if="dutyNoteItems.length === 0" class="note-empty-wrapper">
            <el-empty description="暂无值班备注" :image-size="80" />
          </div>
          <el-scrollbar v-else class="duty-note-scrollbar">
          <div v-for="(line, li) in dutyNoteItems" :key="'dn-' + line._uid" class="handover-input-row-with-dot" :data-duty-note-uid="line._uid">
            <span class="row-number-badge">{{ li + 1 }}</span>
            <el-input
              v-model="line.text"
              size="small"
              spellcheck="false"
              :readonly="!dutyNoteEditing"
              :class="{ 'readonly-input': !dutyNoteEditing }"
              :placeholder="dutyNoteEditing ? '输入值班备注，回车添加下一条...' : ''"
              @keydown.enter.prevent="dutyNoteEditing && addDutyNoteItem(li)"
            />
            <span v-show="dutyNoteEditing" class="row-clear-btn" @click="line.text = ''; line._originalText = ''">&times;</span>
            <span v-show="dutyNoteEditing" class="row-delete-btn" @click="removeDutyNoteItem(dutyNoteItems, li)">
              <el-icon :size="13"><Delete /></el-icon>
            </span>
          </div>
          </el-scrollbar>
        </div>
      </div>
    </div>

    <!-- 新增日志弹窗 -->
    <el-dialog v-model="logModalVisible" title="新增值班日志" width="580px" :close-on-click-modal="false">
      <el-form label-width="80px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="时间">
              <el-time-picker v-model="newLog.time" value-format="HH:mm" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="事件类型">
              <el-select v-model="newLog.type" style="width: 100%">
                <el-option label="告警处理" value="alert" />
                <el-option label="巡检记录" value="inspect" />
                <el-option label="工单处理" value="ticket" />
                <el-option label="设备维护" value="maintain" />
                <el-option label="其他" value="other" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="事件标题">
          <el-input v-model="newLog.title" spellcheck="false" placeholder="简要描述事件" />
        </el-form-item>
        <el-form-item label="详细描述">
          <el-input v-model="newLog.desc" spellcheck="false" type="textarea" :rows="4" placeholder="详细记录事件经过、处理措施和结果..." />
        </el-form-item>
        <el-form-item label="标签">
          <div class="tag-selector">
            <span
              v-for="tag in availableTags"
              :key="tag.value"
              :class="['log-tag', 'log-tag-' + tag.class, { selected: newLog.tags.includes(tag.value) }]"
              @click="toggleTag(tag.value)"
              >{{ tag.label }}</span
            >
          </div>
        </el-form-item>
        <el-form-item label="附件">
          <div class="upload-area-box">
            <div class="upload-desc-text">点击或拖拽上传附件</div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="logModalVisible = false">取消</el-button>
        <el-button type="primary" @click="submitLog">保存日志</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.log-page {
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
.btn-primary-custom.is-disabled {
  background: #94a3b8 !important;
  border-color: #94a3b8 !important;
  opacity: 0.6;
}

/* 日期导航 */
.log-header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}
.log-date-nav {
  display: flex;
  align-items: center;
  gap: 12px;
}
.log-current-date {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-1);
  min-width: 300px;
  text-align: center;
}
.log-nav-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-3);
  padding: 0;
}
.log-nav-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}

/* 卡片 */
.card {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.log-mini-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  background: var(--primary);
}
.log-mini-dot.success { background: var(--success); }
.log-mini-dot.warn { background: var(--warning); }
.log-mini-dot.danger { background: var(--danger); }

.card-header {
  padding: 10px 16px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fafafa;
}

/* 时间线空状态 */
.log-empty-state {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
}

.card-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 日志主体布局 */
.log-body-wrapper {
  display: flex;
  flex-direction: column;
  gap: 14px;
  flex: 1;
  min-height: 0;
}
.log-timeline-card {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

/* 标签行 */
.log-tag-row {
  display: flex;
  gap: 6px;
}
.log-tag {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
}
.log-tag-danger {
  background: #fef2f2;
  color: #dc2626;
  border: 1px solid #fecaca;
}
.log-tag-resolve {
  background: var(--success-bg);
  color: var(--success);
  border: 1px solid var(--success-border);
}
.log-tag-info {
  background: var(--primary-bg);
  color: var(--primary);
  border: 1px solid var(--primary-border);
}
.log-tag-warn {
  background: #fff7ed;
  color: #ea580c;
  border: 1px solid #fed7aa;
}
.log-tag-default {
  background: #f9fafb;
  color: #6b7280;
  border: 1px solid #e5e7eb;
}

/* 标签编辑输入框 */
.tag-edit-input {
  display: inline-flex;
  width: 80px;
  vertical-align: middle;
}
.tag-edit-input :deep(.el-input__wrapper) {
  background: transparent !important;
  box-shadow: none !important;
  padding: 0 !important;
  border-radius: 4px !important;
  height: 20px !important;
}
.tag-edit-input :deep(.el-input__inner) {
  font-size: 10px;
  height: 20px;
  line-height: 20px;
  padding: 0 6px;
  border-radius: 4px;
  background: transparent;
}

/* 各颜色编辑输入框 - 显示带颜色的框 */
.tag-edit-danger :deep(.el-input__inner) {
  border: 1px solid #fecaca;
  background: #fef2f2;
  color: #dc2626;
}
.tag-edit-resolve :deep(.el-input__inner) {
  border: 1px solid var(--success-border);
  background: var(--success-bg);
  color: var(--success);
}
.tag-edit-info :deep(.el-input__inner) {
  border: 1px solid var(--primary-border);
  background: var(--primary-bg);
  color: var(--primary);
}
.tag-edit-warn :deep(.el-input__inner) {
  border: 1px solid #fed7aa;
  background: #fff7ed;
  color: #ea580c;
}
.tag-edit-default :deep(.el-input__inner) {
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  color: #6b7280;
}
.tag-edit-danger :deep(.el-input__inner:focus),
.tag-edit-resolve :deep(.el-input__inner:focus),
.tag-edit-info :deep(.el-input__inner:focus),
.tag-edit-warn :deep(.el-input__inner:focus),
.tag-edit-default :deep(.el-input__inner:focus) {
  border-style: solid;
  outline: none;
}

/* 日志时间线 */
.log-timeline-scroll {
  padding: 16px;
  flex: 1;
  height: 0;
  min-height: 0;
}
.log-timeline {
  display: flex;
  flex-direction: column;
  gap: 0;
}
.log-entry {
  display: flex;
  gap: 14px;
  padding: 14px 0;
  border-bottom: 1px solid var(--border-light);
  position: relative;
}
.log-entry:last-child {
  border-bottom: none;
}
.log-time-col {
  width: 80px;
  flex-shrink: 0;
  text-align: right;
  padding-top: 2px;
}
.log-date {
  font-size: 11px;
  color: var(--text-3);
  line-height: 1.2;
}
.log-time {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-1);
  font-family: monospace;
}
.log-dot-col {
  width: 20px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.log-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--primary);
  flex-shrink: 0;
  margin-top: 5px;
}
.log-dot.warn {
  background: var(--warning);
}
.log-dot.danger {
  background: var(--danger);
}
.log-dot.success {
  background: var(--success);
}
.log-line {
  width: 2px;
  flex: 1;
  background: var(--border);
  margin-top: 4px;
}
.log-content {
  flex: 1;
  min-width: 0;
}
.log-content-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 22px;
}
.log-content-title-empty {
  color: var(--text-4);
  font-weight: 400;
}
.title-clickable {
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  line-height: 22px;
  border-bottom: 1px dashed var(--border);
  transition:
    color 0.2s,
    border-color 0.2s;
}
.title-clickable:hover {
  color: var(--primary);
  border-bottom-color: var(--primary);
}

.log-title-input {
  position: relative;
  min-width: 9ch;
  max-width: 68ch;
}
.log-title-input :deep(.el-input__wrapper) {
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
  padding: 0 !important;
}
.log-title-input :deep(.el-input__inner) {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  height: 22px;
  line-height: 22px;
  padding: 0;
  border-bottom: 1px dashed var(--border);
}
.log-title-input :deep(.el-input__inner:focus) {
  border-bottom-color: var(--primary);
}
.log-title-input :deep(.el-input__count) {
  position: absolute;
  right: 0;
  bottom: -18px;
  background: transparent;
  padding: 0;
  font-size: 10px;
  color: var(--text-4);
  line-height: 1;
  white-space: nowrap;
  z-index: 1;
}

.log-content-title-row {
  display: flex;
  align-items: center;
  gap: 24px;
  margin-bottom: 12px;
}
.person-wrap {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.person-tag {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
  background: var(--bg-page);
  color: var(--text-3);
  border: 1px solid var(--border);
  line-height: 20px;
  height: 20px;
  display: inline-block;
  white-space: nowrap;
}
.log-content-desc {
  font-size: 13px;
  color: var(--text-2);
  line-height: 1.6;
  max-width: 50%;
  border-bottom: 1px solid transparent;
}
.log-content-desc-empty {
  color: var(--text-4);
}
.desc-clickable {
  cursor: pointer;
  font-size: 13px;
  color: var(--text-2);
  line-height: 1.6;
  display: inline-block;
  max-width: 50%;
  border-bottom: 1px dashed var(--border);
  transition:
    color 0.2s,
    border-color 0.2s;
}
.desc-clickable:hover {
  color: var(--primary);
  border-bottom-color: var(--primary);
}
.log-desc-input {
  max-width: 50%;
}
.log-desc-input :deep(.el-textarea__inner) {
  font-size: 13px;
  color: var(--text-2);
  line-height: 1.6;
  background: transparent;
  border: none;
  outline: none;
  box-shadow: none;
  padding: 0;
  resize: none;
  border-bottom: 1px dashed var(--border);
  border-radius: 0;
}
.log-desc-input :deep(.el-textarea__inner:focus) {
  border-bottom-color: var(--primary);
}
.log-desc-input :deep(.el-input__count) {
  position: absolute;
  right: 0;
  bottom: -16px;
  background: transparent;
  padding: 0;
  font-size: 10px;
  color: var(--text-4);
  line-height: 1;
  z-index: 1;
}
.tag-add-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 4px;
  border: 1px dashed var(--border);
  color: var(--text-3);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  line-height: 1;
  transition: all 0.15s;
  user-select: none;
}
.tag-add-btn:hover {
  color: var(--primary);
  border-color: var(--primary);
  background: var(--primary-bg);
}
.tag-removable {
  cursor: pointer;
}
.tag-removable:hover {
  opacity: 0.6;
}

.tags-empty {
  font-size: 12px;
  color: var(--text-4);
  display: inline-flex;
  align-items: center;
  line-height: 1;
}
.tags-label {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 500;
  background: var(--bg-page);
  color: var(--text-4);
  border: 1px solid var(--border);
  line-height: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;
}
.log-content-tags {
  display: flex;
  gap: 6px;
  margin-top: 12px;
  flex-wrap: wrap;
  align-items: center;
  min-height: 20px;
}
.log-content-attachments {
  display: flex;
  gap: 6px;
  margin-top: 6px;
  align-items: center;
  min-height: 18px;
}
.attachments-label {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 500;
  background: var(--bg-page);
  color: var(--text-4);
  border: 1px solid var(--border);
  line-height: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;
}
.log-attachment-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--primary);
  cursor: pointer;
}
.attachment-empty {
  font-size: 12px;
  color: var(--text-4);
  display: inline-flex;
  align-items: center;
  line-height: 1;
}
.attachment-remove-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  font-size: 11px;
  line-height: 1;
  color: var(--text-4);
  cursor: pointer;
  transition: all 0.15s;
  margin-left: 2px;
}
.attachment-remove-btn:hover {
  color: var(--danger);
  background: var(--danger-bg);
}

/* 值班备注 */
.log-note-card {
  flex-shrink: 0;
}
.log-note-body {
  padding: 12px 16px;
  height: 206px;
  display: flex;
  flex-direction: column;
}
.duty-note-scrollbar {
  height: 100%;
}

.note-empty-wrapper {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}
.log-note-area {
  width: 100%;
  min-height: 80px;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 13px;
  outline: none;
  resize: vertical;
  font-family: inherit;
  line-height: 1.6;
  box-sizing: border-box;
}
.log-note-area:focus {
  border-color: var(--primary);
}

/* 值班备注逐行输入 */
.handover-input-row-with-dot {
  display: flex;
  align-items: center;
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
  height: 19.5px !important;
  min-height: 0 !important;
  line-height: 19.5px !important;
  --el-input-border-color: transparent !important;
  --el-input-bg-color: transparent !important;
  --el-input-hover-border-color: transparent !important;
}
.handover-input-row-with-dot :deep(.el-input__wrapper) {
  height: 19.5px !important;
  min-height: 0 !important;
  padding: 0 !important;
  background: transparent !important;
  background-color: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
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

/* 只读输入框 - 像纯文本一样 */
.readonly-input :deep(.el-input__inner) {
  cursor: default;
  user-select: text;
}
.row-delete-btn {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  font-size: 14px;
  line-height: 1;
  transition: color 0.15s;
  border-radius: 4px;
}
.row-delete-btn:hover {
  color: var(--danger);
}

.row-clear-btn {
  flex-shrink: 0;
  cursor: pointer;
  color: var(--text-4);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  font-size: 14px;
  line-height: 1;
  transition: color 0.15s;
  border-radius: 4px;
  margin-right: 2px;
}
.row-clear-btn:hover {
  color: var(--warning);
}


.row-number-badge {
  flex-shrink: 0;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #f97316;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  color: #fff;
  font-weight: 700;
  line-height: 1;
  user-select: none;
  position: relative;
  top: 1px;
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
.tag-selector {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.tag-selector .log-tag {
  cursor: pointer;
  opacity: 0.5;
  transition: all 0.2s;
}
.tag-selector .log-tag:hover {
  opacity: 0.8;
}
.tag-selector .log-tag.selected {
  opacity: 1;
}

/* 图片预览遮罩层 - 参考交接班记录 */
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
}

/* PDF预览弹窗 */
.preview-pdf-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
}
.preview-pdf-embed {
  width: 700px;
  height: 70vh;
  border: none;
  border-radius: 4px;
}

/* 日志条目操作按钮 - 参考交接班记录卡片 */
.log-entry-actions {
  display: flex;
  align-items: center;
  gap: 2px;
  margin-left: auto;
  flex-shrink: 0;
}

/* 日志确认状态标签 - 与交接班记录卡片一致 */
.log-entry-status {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 20px;
  font-weight: 600;
  white-space: nowrap;
}
.log-entry-status.status-completed {
  background: var(--success-bg);
  color: var(--success);
  border: 1px solid var(--success-border);
}
.log-entry-status.status-pending {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}
.log-entry-status.status-pending-save {
  background: var(--primary-bg);
  color: var(--primary);
  border: 1px solid var(--primary-border);
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
.header-icon-btn.delete {
  color: var(--text-4);
}
.header-icon-btn.delete:hover {
  background: #fef2f2;
  color: var(--danger);
}
.header-icon-btn.refresh {
  color: var(--text-3);
}
.header-icon-btn.refresh:hover {
  background: var(--bg-page);
  color: var(--primary);
}
.header-icon-btn.add {
  color: var(--success);
}
.header-icon-btn.add:hover {
  background: var(--success-bg);
  color: #15803d;
}

/* 圆点颜色选择弹窗 */
.log-dot-clickable {
  cursor: pointer;
}

/* 刷新按钮 - 与交接班记录重置按钮一致 */
.card-header .search-btn {
  height: 32px;
  padding: 0 8px;
  min-width: auto;
  font-size: 13px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
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
</style>

<style>
/* 弹窗样式 - 非 scoped 以覆盖 Element Plus Teleport */
.dot-color-popover {
  padding: 4px !important;
  min-width: auto !important;
}
.dot-color-options {
  display: flex !important;
  flex-direction: column !important;
  gap: 2px !important;
}
.dot-color-item {
  display: flex !important;
  align-items: center !important;
  gap: 8px !important;
  padding: 6px 8px !important;
  border-radius: 4px !important;
  cursor: pointer !important;
  font-size: 12px !important;
  color: #334155 !important;
  transition: background 0.15s !important;
}
.dot-color-item:hover {
  background: #f1f5f9 !important;
}
.dot-color-dot {
  display: inline-block !important;
  width: 12px !important;
  height: 12px !important;
  flex-shrink: 0 !important;
  background: #2563eb !important;
}
.dot-color-dot.success {
  background: #16a34a !important;
}
.dot-color-dot.warn {
  background: #f59e0b !important;
}
.dot-color-dot.danger {
  background: #dc2626 !important;
}
.dot-color-label {
  font-size: 12px !important;
  color: #334155 !important;
}

.tag-add-popover {
  padding: 4px !important;
  min-width: auto !important;
}
.tag-add-options {
  display: flex !important;
  flex-direction: column !important;
  gap: 2px !important;
}
.tag-add-option {
  display: flex !important;
  align-items: center !important;
  gap: 8px !important;
  padding: 6px 8px !important;
  border-radius: 4px !important;
  cursor: pointer !important;
  font-size: 12px !important;
  color: #334155 !important;
  transition: background 0.15s !important;
}
.tag-add-option:hover {
  background: #f1f5f9 !important;
}
.tag-color-dot {
  display: inline-block !important;
  width: 12px !important;
  height: 12px !important;
  flex-shrink: 0 !important;
}
.tag-color-dot.danger {
  background: #dc2626 !important;
}
.tag-color-dot.warn {
  background: #ea580c !important;
}
.tag-color-dot.resolve {
  background: #16a34a !important;
}
.tag-color-dot.info {
  background: #2563eb !important;
}
.tag-color-dot.default {
  background: #6b7280 !important;
}

/* 日期选择器下拉面板 - 缩小单元格间距 */
.log-date-popper {
  min-width: unset !important;
  width: auto !important;
}
.log-date-popper .el-picker-panel__body {
  width: auto !important;
}
.log-date-popper .el-date-table td .el-date-table-cell {
  padding: 1px !important;
  width: 26px !important;
  height: 26px !important;
}
.log-date-popper .el-date-table td .el-date-table-cell .el-date-table-cell__inner {
  width: 24px !important;
  height: 24px !important;
  line-height: 24px !important;
}
.log-date-popper .el-date-table th {
  padding: 2px 0 !important;
}
.log-date-popper .el-date-table th .el-date-table-cell {
  width: 26px !important;
  height: 26px !important;
}
</style>
