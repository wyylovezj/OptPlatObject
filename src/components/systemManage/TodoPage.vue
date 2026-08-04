<script setup>
/**
 * 待办备忘录管理页面
 * UI风格与系统通知页面一致
 */
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getTodoList, createTodo, updateTodo, toggleTodoStatus, deleteTodo } from '@/api/todoApi.js'
import { Search } from '@element-plus/icons-vue'

// 列表数据
const todoList = ref([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(15)
const loading = ref(false)

// 搜索表单
const filterForm = ref({
  status: '',
  createdTime: [],
  completedTime: []
})
const localSearch = ref('')

// 对话框
const dialogVisible = ref(false)
const editId = ref(null)
const formData = ref({ title: '', content: '', todoType: 0, reminderTime: '', recurringPattern: '', recurringDay: '', recurringTime: '09:00' })
const formRef = ref(null)

// 待办类型选项
const todoTypeOptions = [
  { value: 0, label: '一次性待办', icon: 'M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z' },
  { value: 1, label: '周期性待办', icon: 'M17.65 6.35A7.958 7.958 0 0012 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0112 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z' }
]

// 周期模式选项
const recurringPatternOptions = [
  { value: 2, label: '每天' },
  { value: 1, label: '每周' },
  { value: 0, label: '每月' }
]

// 星期选项（1=周一...7=周日）
const weekdayOptions = [
  { value: 1, label: '周一' }, { value: 2, label: '周二' }, { value: 3, label: '周三' },
  { value: 4, label: '周四' }, { value: 5, label: '周五' }, { value: 6, label: '周六' }, { value: 7, label: '周日' }
]

// 月日期选项（1-31）
const monthDayOptions = Array.from({ length: 31 }, (_, i) => ({ value: i + 1, label: `${i + 1}日` }))

// 小时选项（0-23）
const hourOptions = Array.from({ length: 24 }, (_, i) => ({ value: i, label: String(i).padStart(2, '0') }))
// 分钟选项（0-59，步长1）
const minuteOptions = Array.from({ length: 60 }, (_, i) => ({ value: i, label: String(i).padStart(2, '0') }))

// 周期时间拆分为时/分，双向绑定 recurringTime
const recurringHour = computed({
  get: () => {
    const t = formData.value.recurringTime
    if (t && t.includes(':')) return parseInt(t.split(':')[0])
    return 9
  },
  set: (val) => { syncRecurringTime(val, recurringMinute.value) }
})
const recurringMinute = computed({
  get: () => {
    const t = formData.value.recurringTime
    if (t && t.includes(':')) return parseInt(t.split(':')[1])
    return 0
  },
  set: (val) => { syncRecurringTime(recurringHour.value, val) }
})
const syncRecurringTime = (h, m) => {
  formData.value.recurringTime = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}
// 初始化时确保默认时间写入 recurringTime
syncRecurringTime(9, 0)

// 一次性待办的时/分双向绑定
const reminderHour = computed({
  get: () => {
    if (!formData.value.reminderTime || !formData.value.reminderTime.includes(' ')) return 9
    return parseInt(formData.value.reminderTime.split(' ')[1].split(':')[0] || '9')
  },
  set: (val) => {
    const hh = String(val).padStart(2, '0')
    if (formData.value.reminderTime && formData.value.reminderTime.includes(' ')) {
      const date = formData.value.reminderTime.split(' ')[0]
      const mm = formData.value.reminderTime.split(' ')[1]?.split(':')[1] || '00'
      formData.value.reminderTime = `${date} ${hh}:${mm}`
    } else if (formData.value.reminderTime) {
      formData.value.reminderTime = `${formData.value.reminderTime} ${hh}:00`
    }
  }
})
const reminderMinute = computed({
  get: () => {
    if (!formData.value.reminderTime || !formData.value.reminderTime.includes(' ')) return 0
    return parseInt(formData.value.reminderTime.split(' ')[1]?.split(':')[1] || '0')
  },
  set: (val) => {
    const mm = String(val).padStart(2, '0')
    if (formData.value.reminderTime && formData.value.reminderTime.includes(' ')) {
      const date = formData.value.reminderTime.split(' ')[0]
      const hh = formData.value.reminderTime.split(' ')[1]?.split(':')[0] || '09'
      formData.value.reminderTime = `${date} ${hh}:${mm}`
    } else if (formData.value.reminderTime) {
      formData.value.reminderTime = `${formData.value.reminderTime} 09:${mm}`
    }
  }
})

// 表单校验
const formRules = {
  title: [{ required: true, message: '请输入待办标题', trigger: 'blur' }]
}

const statusOptions = [
  { value: '', label: '全部状态' },
  { value: 0, label: '启用' },
  { value: 1, label: '停用' }
]

const getStatusTagType = (status) => {
  return status === 1 ? 'danger' : 'success'
}
const getStatusLabel = (status) => {
  return status === 1 ? '停用' : '启用'
}

// 本地搜索（客户端过滤，与系统通知页面一致）
const filteredList = computed(() => {
  const keyword = localSearch.value.trim().toLowerCase()
  if (!keyword) return todoList.value
  return todoList.value.filter(row => {
    const fields = [row.title, row.content, getStatusLabel(row.status), row.reminderTime, row.createTime, row.completedTime]
    return fields.filter(Boolean).join(' ').toLowerCase().includes(keyword)
  })
})
const highlightText = (text) => {
  if (!text && text !== 0) return '-'
  const keyword = localSearch.value.trim()
  const str = String(text)
  if (!keyword) return str
  const escapedKeyword = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return str.replace(new RegExp(`(${escapedKeyword})`, 'gi'), '<mark class="search-highlight">$1</mark>')
}

// 加载数据（保证至少200ms加载态，让用户看到加载动画）
const loadTodos = async () => {
  const start = Date.now()
  loading.value = true
  try {
    const username = sessionStorage.getItem('user') || ''
    const params = {
      username,
      page: currentPage.value,
      pageSize: pageSize.value
    }
    const f = filterForm.value
    if (f.status !== '' && f.status !== null) params.status = f.status
    if (f.createdTime && f.createdTime.length === 2) {
      params.startDate = f.createdTime[0]
      params.endDate = f.createdTime[1]
    }
    if (f.completedTime && f.completedTime.length === 2) {
      params.completedStartDate = f.completedTime[0]
      params.completedEndDate = f.completedTime[1]
    }
    const res = await getTodoList(params)
    const elapsed = Date.now() - start
    if (elapsed < 200) {
      await new Promise(r => setTimeout(r, 200 - elapsed))
    }
    if (res.code === 200) {
      todoList.value = res.data.records || []
      total.value = res.data.total || 0
    } else {
      ElMessage.error(res.message || '加载失败')
    }
  } catch (e) {
    ElMessage.error('加载待办列表失败：' + e.message)
  } finally {
    loading.value = false
  }
}

// 搜索/重置
const handleSearch = () => {
  currentPage.value = 1
  loadTodos()
}
const handleReset = () => {
  filterForm.value = { status: '', createdTime: [], completedTime: [] }
  localSearch.value = ''
  currentPage.value = 1
  loadTodos()
}

// 打开创建对话框
const openCreateDialog = () => {
  editId.value = null
  formData.value = { title: '', content: '', todoType: 0, reminderTime: '', recurringPattern: '', recurringDay: '', recurringTime: '09:00' }
  dialogVisible.value = true
}

// 打开编辑对话框
const openEditDialog = (todo) => {
  editId.value = todo.id
  formData.value = {
    title: todo.title || '',
    content: todo.content || '',
    todoType: todo.todoType || 0,
    reminderTime: todo.reminderTime || '',
    recurringPattern: todo.recurringPattern !== null && todo.recurringPattern !== undefined ? todo.recurringPattern : '',
    recurringDay: todo.recurringDay !== null && todo.recurringDay !== undefined ? todo.recurringDay : '',
    recurringTime: todo.recurringTime || ''
  }
  dialogVisible.value = true
}

// 根据 recurringDay 和 recurringTime 组合成显示用时间字符串
const buildRecurringReminderTime = () => {
  const fd = formData.value
  if (fd.todoType !== 1 || fd.recurringPattern === '' || fd.recurringPattern === null || fd.recurringPattern === undefined || !fd.recurringTime) return ''
  if (fd.recurringPattern === 2) {
    return `每天 ${fd.recurringTime}`
  } else if (fd.recurringPattern === 1) {
    const wd = weekdayOptions.find(w => String(w.value) === String(fd.recurringDay))
    return `每${wd ? wd.label : '?'} ${fd.recurringTime}`
  } else if (fd.recurringPattern === 0) {
    return `每月${fd.recurringDay || '?'}日 ${fd.recurringTime}`
  }
  return ''
}

// 获取周期模式标签（纯文字，不含时间）
const getRecurringPatternLabel = (todo) => {
  if (todo.todoType !== 1 || todo.recurringPattern === null || todo.recurringPattern === undefined) return ''
  if (todo.recurringPattern === 2) return '每天'
  if (todo.recurringPattern === 1) {
    const wd = weekdayOptions.find(w => String(w.value) === String(todo.recurringDay))
    return `每${wd ? wd.label : '?'}`
  }
  if (todo.recurringPattern === 0) return `每月${todo.recurringDay || '?'}日`
  return ''
}

// 保存
const saveTodo = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    try {
      const username = sessionStorage.getItem('user') || ''
      const payload = {
        title: formData.value.title,
        content: formData.value.content,
        todoType: formData.value.todoType,
        reminderTime: formData.value.reminderTime
          ? (formData.value.reminderTime.includes(' ') ? formData.value.reminderTime : formData.value.reminderTime + ' 09:00')
          : '',
        recurringPattern: formData.value.recurringPattern !== '' ? formData.value.recurringPattern : '',
        recurringDay: formData.value.recurringDay !== '' ? formData.value.recurringDay : '',
        recurringTime: formData.value.recurringTime || ''
      }
      if (editId.value) {
        payload.id = editId.value
        const res = await updateTodo(payload)
        if (res.code === 200) {
          ElMessage.success('更新待办成功')
          dialogVisible.value = false
          loadTodos()
        } else {
          ElMessage.error(res.message || '更新失败')
        }
      } else {
        payload.createdBy = username
        const res = await createTodo(payload)
        if (res.code === 200) {
          ElMessage.success('创建待办成功')
          dialogVisible.value = false
          // 将新待办追加到本地列表，避免全量刷新跳动
          if (res.data) {
            todoList.value.unshift(res.data)
            total.value++
          } else {
            loadTodos()
          }
        } else {
          ElMessage.error(res.message || '创建失败')
        }
      }
    } catch (e) {
      ElMessage.error((editId.value ? '更新' : '创建') + '待办失败：' + e.message)
    }
  })
}

// 切换状态
const handleToggleStatus = async (todo) => {
  const actionText = todo.status === 0 ? '停用' : '启用'
  const iconColor = todo.status === 0 ? '#e6a23c' : '#67c23a'
  try {
    await ElMessageBox.confirm(`<div style="display:flex;align-items:flex-start;gap:14px;"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="${iconColor}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:1px;">${todo.status === 0 ? '<polyline points="20 6 9 17 4 12"/>' : '<circle cx="12" cy="12" r="10"/>'}</svg><span style="font-size:14px;color:#303133;line-height:1.8;">确定要${actionText}该待办事项吗？</span></div>`, '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'todo-confirm-box', showClose: false, dangerouslyUseHTMLString: true,
    })
    const res = await toggleTodoStatus(todo.id)
    if (res.code === 200) {
      if (todo.status === 0) {
        ElMessage.warning('已停用')
      } else {
        ElMessage.success('已启用')
      }
      loadTodos()
    } else {
      ElMessage.error(res.message || '状态更新失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('状态更新失败：' + e.message)
  }
}

// 删除
const handleDelete = async (todo) => {
  try {
    await ElMessageBox.confirm('<div style="display:flex;align-items:flex-start;gap:14px;"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#f56c6c" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:1px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg><span style="font-size:14px;color:#303133;line-height:1.8;">确定要删除待办事项吗？</span></div>', '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'todo-confirm-box', showClose: false, dangerouslyUseHTMLString: true,
    })
    const res = await deleteTodo(todo.id)
    if (res.code === 200) {
      ElMessage.success('删除成功')
      loadTodos()
    } else {
      ElMessage.error(res.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('删除待办失败：' + e.message)
  }
}

const handlePageChange = (page) => {
  currentPage.value = page
  loadTodos()
}

const formatTime = (timeStr) => {
  if (!timeStr) return ''
  return timeStr.substring(0, 16)
}

const tableHeight = ref(0)
const updateTableHeight = () => {
  const el = document.querySelector('.todo-page')
  if (el) {
    const rect = el.getBoundingClientRect()
    tableHeight.value = window.innerHeight - rect.top - 310
  }
}

onMounted(() => {
  loadTodos()
  updateTableHeight()
  window.addEventListener('resize', updateTableHeight)
  window.addEventListener('todo-reminded', loadTodos)
})

onUnmounted(() => {
  window.removeEventListener('resize', updateTableHeight)
  window.removeEventListener('todo-reminded', loadTodos)
})
</script>

<template>
  <div class="todo-page">
    <!-- 统计卡片 -->
    <div class="stats-row">
      <div class="stat-card stat-total">
        <div class="stat-icon">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/></svg>
        </div>
        <div class="stat-info">
          <span class="stat-value">{{ total }}</span>
          <span class="stat-label">全部待办</span>
        </div>
      </div>
      <div class="stat-card stat-pending">
        <div class="stat-icon">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
        </div>
        <div class="stat-info">
          <span class="stat-value">{{ todoList.filter(t => t.status === 0).length }}</span>
          <span class="stat-label">启用</span>
        </div>
      </div>
      <div class="stat-card stat-done">
        <div class="stat-icon">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
        </div>
        <div class="stat-info">
          <span class="stat-value">{{ todoList.filter(t => t.status === 1).length }}</span>
          <span class="stat-label">停用</span>
        </div>
      </div>
    </div>

    <!-- 过滤栏 -->
    <div class="filter-bar" style="margin-top: 12px;">
      <el-form :model="filterForm" inline class="filter-form">
        <el-form-item class="filter-item">
          <el-select v-model="filterForm.status" placeholder="全部状态" clearable style="width: 120px">
            <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item filter-date-range">
          <el-date-picker v-model="filterForm.createdTime" type="daterange" range-separator="-" start-placeholder="创建日期(开始)" end-placeholder="创建日期(结束)" value-format="YYYY-MM-DD" style="width: 250px" clearable />
        </el-form-item>
        <el-form-item class="filter-item filter-date-range">
          <el-date-picker v-model="filterForm.completedTime" type="daterange" range-separator="-" start-placeholder="完成日期(开始)" end-placeholder="完成日期(结束)" value-format="YYYY-MM-DD" style="width: 250px" clearable />
        </el-form-item>
        <span class="filter-sep"></span>
        <div class="filter-actions">
          <el-button class="search-btn" @click="handleSearch">
            <svg class="icon-svg sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>&nbsp;搜索
          </el-button>
          <el-button class="reset-btn" @click="handleReset">
            <svg class="icon-svg sm" viewBox="0 0 24 24"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;重置
          </el-button>
        </div>
      </el-form>
    </div>

    <!-- 列表卡片 -->
    <el-card class="list-card" shadow="never">
      <div class="table-wrapper">
        <div class="table-toolbar">
          <div class="toolbar-left">
            <span class="toolbar-title">待办列表</span>
            <span class="toolbar-sep"></span>
          </div>
          <el-input
            v-model="localSearch"
            placeholder="搜索待办..."
            clearable
            :prefix-icon="Search"
            class="toolbar-search-input"
            @keyup.enter="handleSearch"
          />
          <div class="toolbar-actions">
            <el-button class="toolbar-btn-refresh" @click="loadTodos"><svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg></el-button>
            <el-button class="toolbar-btn-create" @click="openCreateDialog">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新建待办
            </el-button>
          </div>
        </div>
        <el-table :data="filteredList" v-loading="loading" style="width: 100%" stripe empty-text="暂无待办事项" :table-layout="'fixed'" :height="tableHeight" row-key="id"
          :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }">
          <el-table-column type="index" label="序号" width="50" align="center" :index="(idx) => (currentPage - 1) * pageSize + idx + 1" />
          <el-table-column label="待办标题" min-width="180" align="center" show-overflow-tooltip>
            <template #default="{ row }">
              <span class="todo-title-cell" :style="{ textDecoration: row.status === 1 ? 'line-through' : 'none', color: row.status === 1 ? '#909399' : '#303133' }" v-html="highlightText(row.title)"></span>
            </template>
          </el-table-column>
          <el-table-column label="待办内容" min-width="200" align="center" show-overflow-tooltip>
            <template #default="{ row }">
              <span v-if="row.content" style="color: #606266;">{{ row.content }}</span>
              <span v-else style="color: #c0c4cc;">-</span>
            </template>
          </el-table-column>
          <el-table-column label="状态" align="center">
            <template #default="{ row }">
              <el-tag :type="getStatusTagType(row.status)" size="small" effect="plain" style="cursor:pointer;" @click="handleToggleStatus(row)">
                {{ getStatusLabel(row.status) }}
              </el-tag>
            </template>
          </el-table-column>
          <!-- 类型 -->
          <el-table-column label="类型" width="80" align="center">
            <template #default="{ row }">
              <el-tag size="small" :type="row.todoType === 0 ? 'info' : 'primary'" effect="plain">{{ row.todoType === 0 ? '一次性' : '周期性' }}</el-tag>
            </template>
          </el-table-column>
          <!-- 周期 -->
          <el-table-column label="周期" width="120" align="center">
            <template #default="{ row }">
              <span v-if="getRecurringPatternLabel(row)" style="color: #5b7fff;">{{ getRecurringPatternLabel(row) }}</span>
              <span v-else style="color: #c0c4cc;">-</span>
            </template>
          </el-table-column>
          <el-table-column label="提醒时间" align="center">
            <template #default="{ row }">
              <template v-if="row.reminderTime">
                <span style="color: #e6a23c; display: inline-flex; align-items: center; white-space: nowrap; gap: 3px;">
                  <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: block; flex-shrink: 0;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  <span style="line-height: 1; display: inline-block; transform: translateY(1px);">{{ formatTime(row.reminderTime) }}</span>
                </span>
              </template>
              <template v-else-if="row.todoType === 1 && row.recurringTime">
                <span style="color: #5b7fff; display: inline-flex; align-items: center; white-space: nowrap; gap: 3px;">
                  <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: block; flex-shrink: 0;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  <span style="line-height: 1; display: inline-block; transform: translateY(1px);">{{ row.recurringTime }}</span>
                </span>
              </template>
              <span v-else style="color: #c0c4cc;">不提醒</span>
            </template>
          </el-table-column>
          <el-table-column label="上次修改" align="center">
            <template #default="{ row }">
              <span>{{ row.updateTime || row.createTime || '-' }}</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="260" align="center" fixed="right">
            <template #default="{ row }">
              <el-button class="table-btn-status" size="small" @click="handleToggleStatus(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <polyline v-if="row.status === 0" points="20 6 9 17 4 12"/><circle v-else cx="12" cy="12" r="10"/>
                </svg>&nbsp;{{ row.status === 0 ? '停用' : '启用' }}
              </el-button>
              <el-button class="table-btn-edit" size="small" :disabled="row.status === 1" @click="openEditDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>&nbsp;编辑
              </el-button>
              <el-button class="table-btn-delete" size="small" :disabled="row.status === 1" @click="handleDelete(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>&nbsp;删除
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="pagination-wrapper" v-if="total > 0">
        <span class="pagination-total">共 {{ total }} 条</span>
        <el-pagination v-model:current-page="currentPage" :page-size="pageSize" :total="total" layout="prev, pager, next" @current-change="handlePageChange" background />
      </div>
    </el-card>

    <!-- 新建/编辑待办对话框 -->
    <el-dialog v-model="dialogVisible" width="650px" :show-close="false" class="todo-dialog" top="20vh">
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/>
            </svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">{{ editId ? '编辑待办' : '新建待办' }}</span>
            <span class="dialog-subtitle">{{ editId ? '修改待办事项内容' : '记录一条待办事项' }}</span>
          </div>
        </div>
      </template>

      <div class="dialog-body">
        <el-scrollbar max-height="520px">
          <el-form ref="formRef" :model="formData" :rules="formRules" label-position="top" autocomplete="off">
            <div class="form-section">
              <div class="form-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>
                </svg>
                待办标题 <span style="color: #f56c6c;">*</span>
              </div>
              <el-form-item prop="title">
                <el-input v-model="formData.title" type="textarea" maxlength="100" :show-word-limit="true" placeholder="输入待办标题..." spellcheck="false" resize="none" :autosize="{ minRows: 2 }" />
              </el-form-item>
            </div>

            <div class="form-section">
              <div class="form-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
                </svg>
                待办内容 <span style="color: #f56c6c;">*</span>
              </div>
              <el-form-item :rules="{ required: true, message: '请输入待办内容', trigger: 'blur' }" prop="content">
                <el-input v-model="formData.content" type="textarea" placeholder="输入待办内容（选填）..." spellcheck="false" resize="none" :autosize="{ minRows: 3 }" />
              </el-form-item>
            </div>

            <div class="form-section">
              <div class="form-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
                </svg>
                待办类型
              </div>
              <div class="todo-type-selector">
                <div
                  v-for="opt in todoTypeOptions" :key="opt.value"
                  class="todo-type-card"
                  :class="{ active: formData.todoType === opt.value }"
                  @click="formData.todoType = opt.value"
                >
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path :d="opt.icon"/>
                  </svg>
                  <span>{{ opt.label }}</span>
                </div>
              </div>
            </div>

            <!-- 一次性待办：选择日期时间 -->
            <div v-if="formData.todoType === 0" class="form-section">
              <div class="form-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                提醒时间（可选）
              </div>
              <el-form-item prop="reminderTime">
                <div class="reminder-time-row">
                  <el-date-picker
                    v-model="formData.reminderTime"
                    type="date"
                    placeholder="选择日期"
                    value-format="YYYY-MM-DD"
                    style="width: 140px"
                    :disabled-date="(time) => time.getTime() < Date.now() - 86400000"
                    class="todo-datetime-picker"
                  />
                  <template v-if="formData.reminderTime">
                    <el-select v-model="reminderHour" placeholder="时" style="width: 72px">
                      <el-option v-for="h in hourOptions" :key="h.value" :label="h.label" :value="h.value" />
                    </el-select>
                    <span style="color: #303133; font-weight: 600;">:</span>
                    <el-select v-model="reminderMinute" placeholder="分" style="width: 72px">
                      <el-option v-for="m in minuteOptions" :key="m.value" :label="m.label" :value="m.value" />
                    </el-select>
                  </template>
                </div>
              </el-form-item>
              <div style="margin-top: 4px; font-size: 12px; color: #909399;">
                设置后将在指定时间弹出提醒
              </div>
            </div>

            <!-- 周期性待办：选择周期模式+时间 -->
            <div v-if="formData.todoType === 1">
              <div class="form-section">
                <div class="form-section-title">
                  <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 014-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 01-4 4H3"/>
                  </svg>
                  重复周期
                </div>
                <div class="recurring-pattern-row">
                  <el-select v-model="formData.recurringPattern" placeholder="选择周期" style="width: 100px">
                    <el-option v-for="p in recurringPatternOptions" :key="p.value" :label="p.label" :value="p.value" />
                  </el-select>
                  <!-- 按周：选择星期几 -->
                  <el-select v-if="formData.recurringPattern === 1" v-model="formData.recurringDay" placeholder="选择星期" style="width: 110px">
                    <el-option v-for="w in weekdayOptions" :key="w.value" :label="w.label" :value="w.value" />
                  </el-select>
                  <!-- 按月：选择几号 -->
                  <el-select v-if="formData.recurringPattern === 0" v-model="formData.recurringDay" placeholder="选择日期" style="width: 110px">
                    <el-option v-for="d in monthDayOptions" :key="d.value" :label="d.label" :value="d.value" />
                  </el-select>
                  <span v-if="formData.recurringPattern !== '' && formData.recurringPattern !== null" style="color: #909399; margin: 0 2px;">的</span>
                  <!-- 时间选择 -->
                  <template v-if="formData.recurringPattern !== '' && formData.recurringPattern !== null">
                    <el-select v-model="recurringHour" placeholder="时" style="width: 72px">
                      <el-option v-for="h in hourOptions" :key="h.value" :label="h.label" :value="h.value" />
                    </el-select>
                    <span style="color: #303133; font-weight: 600;">:</span>
                    <el-select v-model="recurringMinute" placeholder="分" style="width: 72px">
                      <el-option v-for="m in minuteOptions" :key="m.value" :label="m.label" :value="m.value" />
                    </el-select>
                  </template>
                </div>
                <div v-if="buildRecurringReminderTime()" style="margin-top: 10px; padding: 8px 14px; background: #f0f4ff; border-radius: 8px; font-size: 13px; color: #5b7fff;">
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  将在「<strong>{{ buildRecurringReminderTime() }}</strong>」自动提醒
                </div>
              </div>
            </div>
          </el-form>
        </el-scrollbar>
      </div>

      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="dialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveTodo">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>&nbsp;{{ editId ? '保存修改' : '创建待办' }}
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.todo-page {
  display: flex; flex-direction: column; height: 100%; box-sizing: border-box; user-select: none;
}

/* 统计卡片 */
.stats-row {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
.stat-card {
  flex: 1;
  min-width: 140px;
  padding: 14px 16px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 14px;
  border: 1px solid rgba(255,255,255,0.2);
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  transition: all 0.3s ease;
}
.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0,0,0,0.10);
}
.stat-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stat-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.stat-value {
  font-size: 24px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-label {
  font-size: 12px;
  font-weight: 500;
  opacity: 0.85;
}
.stat-total { background: linear-gradient(135deg, #e3f2fd, #bbdefb); border-color: #90caf9; }
.stat-total .stat-icon { background: rgba(33,150,243,0.15); color: #1565c0; }
.stat-total .stat-value { color: #0d47a1; }
.stat-total .stat-label { color: #1565c0; }

.stat-pending { background: linear-gradient(135deg, #fff3e0, #ffe0b2); border-color: #ffcc80; }
.stat-pending .stat-icon { background: rgba(255,152,0,0.15); color: #e65100; }
.stat-pending .stat-value { color: #bf360c; }
.stat-pending .stat-label { color: #e65100; }

.stat-done { background: linear-gradient(135deg, #e8f5e9, #c8e6c9); border-color: #a5d6a7; }
.stat-done .stat-icon { background: rgba(76,175,80,0.15); color: #2e7d32; }
.stat-done .stat-value { color: #1b5e20; }
.stat-done .stat-label { color: #2e7d32; }

.list-card {
  flex: 1; border-radius: 10px; overflow: hidden; display: flex; flex-direction: column;
  margin-top: 12px;
}
.list-card :deep(.el-card__body) {
  display: flex; flex-direction: column; flex: 1; padding: 16px 20px; overflow: hidden;
}

/* 过滤栏 */
.filter-bar {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
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
.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}
.filter-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}
.search-btn, .reset-btn {
  padding: 0 10px;
  min-width: auto;
  height: 32px;
  border-radius: 8px !important;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  font-size: 13px;
  font-weight: 500;
  border: none;
  color: #fff;
  transition: all 0.25s ease;
}
.search-btn {
  background: linear-gradient(135deg, #409eff, #337ecc);
}
.search-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(64, 158, 255, 0.4);
}
.reset-btn {
  background: linear-gradient(135deg, #e6a23c, #c68a2e);
}
.reset-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(230, 162, 60, 0.4);
}
.filter-bar :deep(.el-input__wrapper) {
  padding: 1px 8px !important;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  height: 32px;
}
.filter-bar :deep(.el-input__inner) {
  height: 32px;
  font-size: 13px;
}
.filter-bar :deep(.el-select__wrapper) {
  height: 32px;
  min-height: 32px;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  font-size: 13px;
}
.filter-bar :deep(.el-input__wrapper.is-focus),
.filter-bar :deep(.el-select__wrapper.is-focused) {
  box-shadow: 0 0 0 1px #2563eb inset, 0 0 0 3px rgba(37, 99, 235, 0.1) !important;
}

.icon-svg {
  width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-width: 2;
  stroke-linecap: round; stroke-linejoin: round;
}
.icon-svg.sm {
  width: 14px; height: 14px;
}

.toolbar-search-input {
  width: 200px;
}
.toolbar-search-input :deep(.el-input__wrapper) {
  border-radius: 8px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  height: 32px;
  background: #f8f9fe;
  transition: all 0.25s ease;
}
.toolbar-search-input :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
  background: #fff;
}
.toolbar-search-input :deep(.el-input__inner) {
  font-size: 13px;
}

/* 搜索高亮 */
:global(.search-highlight) {
  background: #ff6b6b;
  color: #fff;
  border-radius: 2px;
  padding: 0 2px;
}

.table-wrapper {
  flex: 1; min-height: 0; display: flex; flex-direction: column; position: relative;
}
.table-toolbar {
  display: flex; justify-content: space-between; align-items: center; padding: 2px 0 8px;
}
.toolbar-title {
  font-size: 14px; font-weight: 600; color: #303133; user-select: none;
}
.toolbar-sep {
  width: 1px; height: 24px; background: #e2e8f0; flex-shrink: 0;
}
.toolbar-left {
  display: flex; align-items: center; gap: 12px;
}
.toolbar-actions {
  display: flex; gap: 8px; flex-shrink: 0;
}
/* 工具栏刷新按钮 */
.toolbar-btn-refresh {
  width: 34px;
  height: 34px;
  padding: 0;
  border-radius: 8px !important;
  background: linear-gradient(135deg, #bcc0c8, #a3a7b0);
  border: none;
  color: #fff;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: all 0.25s ease;
}
.toolbar-btn-refresh:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(108, 117, 125, 0.4);
}

.toolbar-btn-create {
  height: 34px; padding: 0 14px; border-radius: 8px !important;
  background: linear-gradient(135deg, #667eea, #764ba2); border: none; color: #fff !important;
  font-size: 13px; font-weight: 500; transition: all 0.25s ease;
}
.toolbar-btn-create:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102,126,234,0.4);
}

.table-wrapper :deep(.el-table__body-wrapper) {
  overflow-y: auto;
}
.todo-title-cell {
  display: inline-block;
  max-width: 380px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: middle;
}
.pagination-wrapper {
  display: flex; justify-content: space-between; align-items: center;
  padding: 28px 16px 4px;
}
.pagination-total {
  font-size: 13px; color: #606266;
}

/* 操作按钮 - 仅改背景色，保留Element Plus默认布局 */
.table-btn-status, .table-btn-edit, .table-btn-delete {
  border: none;
  color: #fff !important;
  border-radius: 6px;
  white-space: nowrap;
  transition: all 0.25s ease;
}
.table-btn-status {
  background: linear-gradient(135deg, #e6a23c, #d4892b);
}
.table-btn-status:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 10px rgba(230,162,60,0.4);
}
.table-btn-edit {
  background: linear-gradient(135deg, #667eea, #764ba2);
}
.table-btn-edit:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 10px rgba(102,126,234,0.4);
}
.table-btn-edit.is-disabled {
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  opacity: 0.45;
  cursor: not-allowed;
  transform: none !important;
  box-shadow: none !important;
}
.table-btn-delete {
  background: linear-gradient(135deg, #f56c6c, #e04040);
}
.table-btn-delete:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 10px rgba(245,108,108,0.4);
}
.table-btn-delete.is-disabled {
  background: linear-gradient(135deg, #f56c6c, #e04040) !important;
  opacity: 0.45;
  cursor: not-allowed;
  transform: none !important;
  box-shadow: none !important;
}

/* 对话框样式 */
.todo-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.todo-dialog :deep(.el-dialog__header) {
  padding: 0;
  margin: 0;
}
.todo-dialog :deep(.el-dialog__body) {
  padding: 0;
}
.todo-dialog :deep(.el-dialog__footer) {
  padding: 0;
}

/* 待办类型选择卡片 */
.todo-type-selector {
  display: flex; gap: 12px;
}
.todo-type-card {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px 16px;
  border-radius: 12px;
  border: 2px solid #e4e7f0;
  background: #fff;
  cursor: pointer;
  transition: all 0.25s ease;
  font-size: 14px;
  font-weight: 500;
  color: #606266;
  user-select: none;
}
.todo-type-card:hover {
  border-color: #b4b9f2;
  background: #f8f9ff;
}
.todo-type-card.active {
  border-color: #667eea;
  background: linear-gradient(135deg, #eef0ff, #e4e7ff);
  color: #5b7fff;
  font-weight: 600;
  box-shadow: 0 2px 12px rgba(102, 126, 234, 0.15);
}
.todo-type-card svg {
  flex-shrink: 0;
}

/* 周期模式选择行 */
.recurring-pattern-row {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: nowrap;
}
.recurring-pattern-row :deep(.el-select__wrapper) {
  border-radius: 8px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  height: 36px;
  min-height: 36px;
}
.recurring-pattern-row :deep(.el-select__wrapper.is-focused) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
.recurring-pattern-row :deep(.el-select) {
  flex-shrink: 0;
}

/* 一次性待办时间选择行 - 与周期选择行风格一致 */
.reminder-time-row {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: nowrap;
}

/* 对话框头部等原有样式 */
.dialog-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 24px 28px;
  display: flex;
  align-items: center;
  gap: 16px;
}
.dialog-header-icon {
  width: 52px;
  height: 52px;
  background: rgba(255,255,255,0.2);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
}
.dialog-header-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.dialog-title {
  font-size: 20px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.5px;
}
.dialog-subtitle {
  font-size: 13px;
  color: rgba(255,255,255,0.75);
}
.dialog-body {
  padding: 24px 0;
  background: #f8f9fe;
}
.dialog-body :deep(.el-scrollbar__wrap) {
  padding: 0 28px;
}
.form-section {
  background: #fff;
  border-radius: 14px;
  padding: 16px 20px;
  margin-bottom: 14px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.08);
  border: 1px solid #eef0f8;
}
.form-section-title {
  font-size: 13px;
  font-weight: 600;
  color: #5b7fff;
  margin-bottom: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  letter-spacing: 0.3px;
}
.form-section :deep(.el-form-item) {
  margin-bottom: 0;
}
.form-section :deep(.el-input__wrapper) {
  border-radius: 10px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  padding: 4px 12px;
}
.form-section :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
/* 日期选择器独立覆盖，仅圆角和阴影，不干涉内部布局 */
.form-section :deep(.todo-datetime-picker.el-date-editor .el-input__wrapper) {
  border-radius: 10px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
}
.form-section :deep(.todo-datetime-picker.el-date-editor .el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
.form-section :deep(.el-textarea__inner) {
  border-radius: 10px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  padding: 10px 12px;
  font-size: 14px;
  line-height: 1.6;
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.form-section :deep(.el-textarea__inner)::-webkit-scrollbar {
  display: none;
}
.form-section :deep(.el-textarea__inner:focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
.form-section :deep(.el-input__count) {
  font-size: 12px;
  color: #a8abbd;
  bottom: 4px;
}

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  padding: 16px 28px;
  background: #f8f9fe;
  border-top: 1px solid #e8eaf0;
}
.dialog-btn-cancel {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 20px;
  font-size: 13px;
  border: 1px solid #e4e7f0;
  transition: all 0.25s ease;
}
.dialog-btn-save {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 24px;
  font-size: 13px;
  font-weight: 600;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  transition: all 0.25s ease;
}
.dialog-btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}

/* 分页紫色主题 */
.pagination-wrapper :deep(.el-pagination.is-background .el-pager li:not(.is-disabled).is-active) {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff;
}

/* 删除确认弹框 - 匹配新建待办模态框紫蓝渐变主题 */
.todo-confirm-box {
  border-radius: 16px !important;
  padding: 0 !important;
  overflow: hidden;
}
.todo-confirm-box .el-message-box__header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 24px;
  margin: 0;
}
.todo-confirm-box .el-message-box__title {
  color: #fff !important;
  font-size: 16px;
  font-weight: 600;
}
.todo-confirm-box .el-message-box__close {
  color: rgba(255,255,255,0.75) !important;
}
.todo-confirm-box .el-message-box__close:hover {
  color: #fff !important;
}
.todo-confirm-box .el-message-box__content {
  padding: 24px;
  background: #f8f9fe;
}
.todo-confirm-box .el-message-box__message {
  font-size: 14px;
  color: #303133;
  line-height: 1.6;
}
.todo-confirm-box .el-message-box__btns {
  padding: 16px 24px;
  background: #f8f9fe;
  border-top: 1px solid #e8eaf0;
  display: flex;
  justify-content: flex-end;
}
.todo-confirm-box .el-message-box__btns .el-button--primary {
  border-radius: 10px !important;
  height: 36px;
  padding: 0 24px;
  font-size: 13px;
  font-weight: 600;
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  border: none !important;
  color: #fff !important;
  transition: all 0.25s ease;
}
.todo-confirm-box .el-message-box__btns .el-button--primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4) !important;
}
.todo-confirm-box .el-message-box__btns .el-button--default {
  border-radius: 10px !important;
  height: 36px;
  padding: 0 20px;
  font-size: 13px;
  border: 1px solid #e4e7f0;
  transition: all 0.25s ease;
}
</style>

<style>
/* 删除确认弹框 - 无scoped，因为ElMessageBox渲染在body下 */
.todo-confirm-box {
  border-radius: 16px !important;
  padding: 0 !important;
  overflow: hidden;
}
.todo-confirm-box .el-message-box__header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 24px;
  margin: 0;
}
.todo-confirm-box .el-message-box__title {
  color: #fff !important;
  font-size: 16px;
  font-weight: 600;
}
.todo-confirm-box .el-message-box__close {
  color: rgba(255,255,255,0.75) !important;
}
.todo-confirm-box .el-message-box__close:hover {
  color: #fff !important;
}
.todo-confirm-box .el-message-box__content {
  padding: 24px;
  background: #f8f9fe;
}
.todo-confirm-box .el-message-box__message {
  font-size: 14px;
  color: #303133;
  line-height: 1.6;
}
.todo-confirm-box .el-message-box__btns {
  padding: 16px 24px;
  background: #f8f9fe;
  border-top: 1px solid #e8eaf0;
  display: flex;
  justify-content: flex-end;
}
.todo-confirm-box .el-message-box__btns .el-button--primary {
  border-radius: 10px !important;
  height: 36px;
  padding: 0 24px;
  font-size: 13px;
  font-weight: 600;
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  border: none !important;
  color: #fff !important;
  transition: all 0.25s ease;
}
.todo-confirm-box .el-message-box__btns .el-button--primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4) !important;
}
.todo-confirm-box .el-message-box__btns .el-button--default {
  border-radius: 10px !important;
  height: 36px;
  padding: 0 20px;
  font-size: 13px;
  border: 1px solid #e4e7f0;
  transition: all 0.25s ease;
}
</style>
