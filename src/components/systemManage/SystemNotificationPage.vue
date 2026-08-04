<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { ElMessage, ElMessageBox, ElScrollbar } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import { getSystemNotifications, createSystemNotification, deleteSystemNotification, publishSystemNotification, updateSystemNotification, getNotificationStats, getAllGroups, getGroupUsers } from '@/api/systemNotificationApi.js'
import { marked } from 'marked'

// Markdown 渲染（表格内使用，去掉 <p> 包裹避免撑大行高）
const renderMarkdown = (text) => {
  if (!text) return ''
  return marked.parse(text, { async: false }).replace(/^<p>([\s\S]*)<\/p>\n?$/, '$1')
}

const notificationList = ref([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const loading = ref(false)
const dialogVisible = ref(false)
const formData = ref({ title: '', content: '', notificationType: 'success' })
const formRef = ref(null)
const editId = ref(null)

// 用户组多选数据
const selectedGroupIds = ref([])
const allGroups = ref([])
const loadingGroups = ref(false)
// 用户组-用户映射 {groupId: [userName,...]}
const groupUsersMap = ref({})
// 查看模式
const isViewMode = ref(false)
// 是否为预览
const isPreviewing = ref(false)
// 预览弹框
const previewDialogVisible = ref(false)
const previewTitle = ref('')
const previewHtmlContent = ref('')
const previewType = ref('success')
const previewTypeLabel = ref('普通通知')
const previewPublishTime = ref('')

const notifTypeStyles = {
  success: { c: '#67c23a', label: '普通通知' },
  warning: { c: '#e6a23c', label: '重要通知' },
  error: { c: '#f56c6c', label: '紧急通知' },
}

const handlePreview = () => {
  if (!formData.value.title && !formData.value.content) {
    ElMessage.warning('请先填写通知标题和内容')
    return
  }
  previewTitle.value = formData.value.title || '系统通知'
  previewType.value = formData.value.notificationType || 'success'
  previewTypeLabel.value = (notifTypeStyles[previewType.value] || notifTypeStyles.success).label
  previewPublishTime.value = previewPublishTime.value || new Date().toLocaleString('zh-CN', { hour12: false })
  // 渲染 Markdown
  try {
    const parsed = marked.parse(formData.value.content || '', { async: false })
    if (parsed instanceof Promise) {
      parsed.then(html => { previewHtmlContent.value = html })
    } else {
      previewHtmlContent.value = parsed
    }
  } catch (e) {
    previewHtmlContent.value = formData.value.content || ''
  }
  previewDialogVisible.value = true
}

const backToEdit = () => {
  isPreviewing.value = false
  isViewMode.value = false
}

// 查看已发布通知的完整内容
const handleViewNotification = async (notification) => {
  isViewMode.value = true
  isPreviewing.value = false
  editId.value = notification.id
  previewPublishTime.value = notification.publishTime || ''
  formData.value = {
    title: notification.title || '',
    content: notification.content || '',
    notificationType: notification.notificationType || 'success',
  }
  // 加载已选用户组
  if (allGroups.value.length === 0) {
    await loadGroups()
  }
  if (notification.targetGroupIds && notification.targetGroupIds.length > 0) {
    selectedGroupIds.value = notification.targetGroupIds.map(id => String(id))
  } else {
    selectedGroupIds.value = []
  }
  dialogVisible.value = true
}

const loadGroups = async () => {
  try {
    loadingGroups.value = true
    const res = await getAllGroups()
    if (res.code === 200) {
      allGroups.value = res.data || []
      // 并行加载每个用户组的用户
      const map = {}
      const promises = (res.data || []).map(async (g) => {
        try {
          const uRes = await getGroupUsers(g.groupCode)
          if (uRes.code === 200) {
            map[g.id] = (uRes.data || []).map(u => u.nickname || u.username)
          }
        } catch (e) {
          console.warn(`加载用户组 ${g.groupName} 用户失败：`, e.message)
        }
      })
      await Promise.all(promises)
      groupUsersMap.value = map
    }
  } catch (e) {
    console.error('加载用户组失败：', e.message)
  } finally {
    loadingGroups.value = false
  }
}

// 统计数据
const statsData = ref({
  todayPublished: 0,
  unpublished: 0,
  totalPublished: 0,
  urgent: 0,
  important: 0,
  normal: 0
})

const loadStats = async () => {
  try {
    const res = await getNotificationStats()
    if (res.code === 200) {
      statsData.value = res.data
    }
  } catch (e) {
    console.error('加载通知统计失败：', e.message)
  }
}

// 搜索条件
const filterForm = ref({ createdBy: '', status: '', notificationType: '', createdTime: [], publishTime: [] })

const statusOptions = [
  { value: '0', label: '草稿' },
  { value: '1', label: '已发布' }
]

const typeFilterOptions = [
  { value: 'success', label: '普通通知' },
  { value: 'warning', label: '重要通知' },
  { value: 'error', label: '紧急通知' }
]

const typeOptions = [
  { value: 'success', label: '普通通知', color: '#67c23a' },
  { value: 'warning', label: '重要通知', color: '#e6a23c' },
  { value: 'error', label: '紧急通知', color: '#f56c6c' }
]

const getTypeInfo = (type) => typeOptions.find(t => t.value === type) || typeOptions[0]

// 预览按钮可用条件：标题和内容均不为空
const canPreview = computed(() => formData.value.title.trim() && formData.value.content.trim())

const formRules = {
  title: [{ required: true, message: '请输入通知标题', trigger: 'blur' }],
  content: [{ required: true, message: '请输入通知内容', trigger: 'blur' }]
}

// 搜索文本高亮（表格中显示纯文本，避免块级标签撑高行）
const highlightText = (text) => {
  if (!text && text !== 0) return '-'
  const keyword = localSearch.value.trim()
  // 渲染Markdown后去除所有HTML标签，得到纯文本
  const plainText = renderMarkdown(String(text)).replace(/<[^>]*>/g, '')
  if (!keyword) return plainText
  const escapedKeyword = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return plainText.replace(new RegExp(`(${escapedKeyword})`, 'gi'), '<mark class="search-highlight">$1</mark>')
}

// 本地搜索
const localSearch = ref('')
const filteredList = computed(() => {
  const keyword = localSearch.value.trim().toLowerCase()
  if (!keyword) return notificationList.value
  return notificationList.value.filter(row => {
    const fields = [row.title, row.content, row.notificationType, row.createdBy, row.createdTime, row.publishTime]
    const typeLabel = getTypeInfo(row.notificationType).label
    const statusLabel = row.status === 1 ? '已发布' : '草稿'
    const searchText = [...fields, typeLabel, statusLabel].filter(Boolean).join(' ').toLowerCase()
    return searchText.includes(keyword)
  })
})

const loadWithMinDuration = async (extraParams = {}) => {
  const start = Date.now()
  loading.value = true
  try {
    const params = { page: currentPage.value, pageSize: pageSize.value, ...extraParams }
    const f = filterForm.value
    if (f.createdBy) params.createdBy = f.createdBy
    if (f.status !== '' && f.status !== null) params.status = f.status
    if (f.notificationType) params.notificationType = f.notificationType
    if (f.createdTime && f.createdTime.length === 2) {
      params.createdTimeStart = f.createdTime[0]
      params.createdTimeEnd = f.createdTime[1]
    }
    if (f.publishTime && f.publishTime.length === 2) {
      params.publishTimeStart = f.publishTime[0]
      params.publishTimeEnd = f.publishTime[1]
    }
    const res = await getSystemNotifications(params)
    const elapsed = Date.now() - start
    if (elapsed < 200) {
      await new Promise(r => setTimeout(r, 200 - elapsed))
    }
    if (res.code === 200) {
      notificationList.value = res.data.records || []
      total.value = res.data.total || 0
    } else {
      ElMessage.error(res.message || '加载失败')
    }
  } catch (e) {
    ElMessage.error('加载通知列表失败：' + e.message)
  } finally {
    loading.value = false
  }
}

const loadNotifications = async () => {
  loading.value = true
  try {
    const params = {
      page: currentPage.value,
      pageSize: pageSize.value,
    }
    const f = filterForm.value
    if (f.createdBy) params.createdBy = f.createdBy
    if (f.status !== '' && f.status !== null) params.status = f.status
    if (f.notificationType) params.notificationType = f.notificationType
    if (f.createdTime && f.createdTime.length === 2) {
      params.createdTimeStart = f.createdTime[0]
      params.createdTimeEnd = f.createdTime[1]
    }
    if (f.publishTime && f.publishTime.length === 2) {
      params.publishTimeStart = f.publishTime[0]
      params.publishTimeEnd = f.publishTime[1]
    }
    const res = await getSystemNotifications(params)
    if (res.code === 200) {
      notificationList.value = res.data.records || []
      total.value = res.data.total || 0
    } else {
      ElMessage.error(res.message || '加载失败')
    }
  } catch (e) {
    ElMessage.error('加载通知列表失败：' + e.message)
  } finally {
    loading.value = false
  }
}

const openCreateDialog = async () => {
  editId.value = null
  isViewMode.value = false
  isPreviewing.value = false
  selectedGroupIds.value = []
  previewPublishTime.value = ''
  formData.value = { title: '', content: '', notificationType: 'success' }
  if (allGroups.value.length === 0) {
    await loadGroups()
  }
  dialogVisible.value = true
}

const openEditDialog = async (notification) => {
  editId.value = notification.id
  isViewMode.value = false
  isPreviewing.value = false
  selectedGroupIds.value = notification.targetGroupIds ? notification.targetGroupIds.map(id => String(id)) : []
  previewPublishTime.value = ''
  formData.value = {
    title: notification.title || '',
    content: notification.content || '',
    notificationType: notification.notificationType || 'success',
  }
  if (allGroups.value.length === 0) {
    await loadGroups()
  }
  dialogVisible.value = true
}

const saveNotification = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    try {
      const username = sessionStorage.getItem('user') || ''
      if (editId.value) {
        // 编辑已有通知
        const res = await updateSystemNotification({
          id: editId.value,
          title: formData.value.title,
          content: formData.value.content,
          notificationType: formData.value.notificationType,
          targetGroupIds: selectedGroupIds.value,
        })
        if (res.code === 200) {
          ElMessage.success('更新通知成功')
          dialogVisible.value = false
          loadNotifications()
          loadStats()
        } else {
          ElMessage.error(res.message || '更新失败')
        }
      } else {
        // 新建通知
        const res = await createSystemNotification({
          title: formData.value.title,
          content: formData.value.content,
          notificationType: formData.value.notificationType,
          createdBy: username,
          targetGroupIds: selectedGroupIds.value,
        })
        if (res.code === 200) {
          ElMessage.success('创建通知成功')
          dialogVisible.value = false
          loadNotifications()
          loadStats()
        } else {
          ElMessage.error(res.message || '创建失败')
        }
      }
    } catch (e) {
      ElMessage.error((editId.value ? '更新' : '创建') + '通知失败：' + e.message)
    }
  })
}

// HTML转义
const escapeHtml = (str) => {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

const handlePublish = async (notification) => {
  try {
    await ElMessageBox.confirm('确定要发布通知\u300C' + escapeHtml(notification.title) + '\u300D吗？', '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'publish-confirm-box', showClose: false,
    })
    const res = await publishSystemNotification(notification.id, notification.targetGroupIds || [])
    if (res.code === 200) {
      ElMessage.success(res.message || '发布成功')
      loadNotifications()
      loadStats()
    } else {
      ElMessage.error(res.message || '发布失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('发布通知失败：' + e.message)
  }
}

// 获取用户组名称（按ID查找）
const getGroupName = (groupId) => {
  const group = allGroups.value.find(g => String(g.id) === String(groupId))
  return group ? group.groupName : groupId
}

const handleDelete = async (notification) => {
  try {
    await ElMessageBox.confirm('确定要删除通知\u300C' + escapeHtml(notification.title) + '\u300D吗？', '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'publish-confirm-box', showClose: false,
    })
    const res = await deleteSystemNotification(notification.id)
    if (res.code === 200) {
      ElMessage.success('删除成功')
      loadNotifications()
      loadStats()
    } else {
      ElMessage.error(res.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('删除通知失败：' + e.message)
  }
}

const handlePageChange = (page) => {
  currentPage.value = page
  loadNotifications()
}

const handleSearch = () => {
  currentPage.value = 1
  loadWithMinDuration()
}

const handleReset = () => {
  filterForm.value = { createdBy: '', status: '', notificationType: '', createdTime: [], publishTime: [] }
  currentPage.value = 1
  loadNotifications()
}

const handleRefresh = () => {
  loadWithMinDuration()
  loadStats()
}

const tableHeight = ref(0)
const updateTableHeight = () => {
  const el = document.querySelector('.notification-page')
  if (el) {
    const rect = el.getBoundingClientRect()
    tableHeight.value = window.innerHeight - rect.top - 380
  }
}

onMounted(() => {
  loadNotifications()
  loadStats()
  updateTableHeight()
  window.addEventListener('resize', updateTableHeight)
})

onUnmounted(() => {
  window.removeEventListener('resize', updateTableHeight)
})
</script>

<template>
  <div class="notification-page">
    <!-- 统计卡片 -->
    <div class="stats-row">
      <div class="stat-card stat-today-published">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.todayPublished }}</span>
          <span class="stat-label">今日发布</span>
        </div>
      </div>
      <div class="stat-card stat-unpublished">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><path d="M12 18l-4 1 1-4 9.5-9.5a2.121 2.121 0 013 3z"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.unpublished }}</span>
          <span class="stat-label">未发布</span>
        </div>
      </div>
      <div class="stat-card stat-total-published">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.totalPublished }}</span>
          <span class="stat-label">总发布</span>
        </div>
      </div>
      <div class="stat-card stat-urgent">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.urgent }}</span>
          <span class="stat-label">紧急</span>
        </div>
      </div>
      <div class="stat-card stat-important">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.important }}</span>
          <span class="stat-label">重要</span>
        </div>
      </div>
      <div class="stat-card stat-normal">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ statsData.normal }}</span>
          <span class="stat-label">普通</span>
        </div>
      </div>
    </div>

    <div class="filter-bar" style="margin-top: 12px;">
      <el-form :model="filterForm" inline class="filter-form">
        <el-form-item class="filter-item">
          <el-input v-model="filterForm.createdBy" placeholder="创建人" clearable style="width: 130px" @keyup.enter="handleSearch" />
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="filterForm.status" placeholder="全部状态" clearable style="width: 110px">
            <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="filterForm.notificationType" placeholder="全部类型" clearable style="width: 120px">
            <el-option v-for="item in typeFilterOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item class="filter-item filter-date-range">
          <el-date-picker v-model="filterForm.createdTime" type="daterange" range-separator="-" start-placeholder="创建日期(开始)" end-placeholder="创建日期(结束)" value-format="YYYY-MM-DD" style="width: 250px" clearable />
        </el-form-item>
        <el-form-item class="filter-item filter-date-range">
          <el-date-picker v-model="filterForm.publishTime" type="daterange" range-separator="-" start-placeholder="发布日期(开始)" end-placeholder="发布日期(结束)" value-format="YYYY-MM-DD" style="width: 250px" clearable />
        </el-form-item>
        <span class="filter-sep"></span>
        <div class="filter-actions">
          <el-button class="search-btn" @click="handleSearch"><svg class="icon-svg sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>&nbsp;搜索</el-button>
          <el-button class="reset-btn" @click="handleReset"><svg class="icon-svg sm" viewBox="0 0 24 24"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;重置</el-button>
        </div>
      </el-form>
    </div>

    <el-card class="list-card" shadow="never">
      <div class="table-wrapper">
        <div class="table-toolbar">
          <div class="toolbar-left">
            <span class="toolbar-title">通知列表</span>
            <span class="toolbar-sep"></span>
          </div>
          <el-input
            v-model="localSearch"
            placeholder="搜索通知..."
            clearable
            :prefix-icon="Search"
            class="toolbar-search-input"
          />
          <div class="toolbar-actions">
            <el-button class="toolbar-btn-refresh" @click="handleRefresh"><svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg></el-button>
            <el-button class="toolbar-btn-create" @click="openCreateDialog"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新建通知</el-button>
          </div>
        </div>
        <el-table :data="filteredList" v-loading="loading" style="width: 100%" stripe empty-text="暂无系统通知" :table-layout="'auto'" :height="tableHeight" :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }">
        <el-table-column type="index" label="序号" width="60" align="center" :index="(idx) => (currentPage - 1) * pageSize + idx + 1" />
        <el-table-column label="通知标题" min-width="200" align="center" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="notification-content" v-html="highlightText(row.title)"></span>
          </template>
        </el-table-column>
        <el-table-column label="通知内容" min-width="280" align="center" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="notification-content" v-html="highlightText(row.content)"></span>
          </template>
        </el-table-column>
        <el-table-column label="通知类型" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.notificationType" size="small">{{ getTypeInfo(row.notificationType).label }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="通知组" min-width="150" align="center" show-overflow-tooltip>
          <template #default="{ row }">
            <template v-if="row.targetGroupNames && row.targetGroupNames.length > 0">
              <el-tag
                v-for="(name, idx) in row.targetGroupNames"
                :key="idx"
                size="small"
                style="margin: 1px 2px"
              >{{ name }}</el-tag>
            </template>
            <span v-else style="color: #909399;">全部用户</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">{{ row.status === 1 ? '已发布' : '草稿' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="创建人" width="120" align="center">
          <template #default="{ row }">
            <span v-html="highlightText(row.createdBy)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="createdTime" label="创建时间" width="170" align="center" />
        <el-table-column label="发布时间" width="170" align="center">
          <template #default="{ row }">{{ row.publishTime || '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="180" align="center" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 0" class="table-btn-publish" size="small" @click="handlePublish(row)"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>&nbsp;发布</el-button>
            <el-button v-if="row.status === 0" class="table-btn-edit" size="small" @click="openEditDialog(row)"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>&nbsp;编辑</el-button>
            <el-button v-if="row.status === 1" class="table-btn-view" size="small" @click="handleViewNotification(row)"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>&nbsp;查看</el-button>
          </template>
        </el-table-column>
      </el-table>
      </div>
      <div class="pagination-wrapper" v-if="total > 0">
        <span class="pagination-total">共 {{ total }} 条</span>
        <el-pagination v-model:current-page="currentPage" :page-size="pageSize" :total="total" layout="prev, pager, next" @current-change="handlePageChange" background />
      </div>
    </el-card>

    <!-- 新建/查看通知模态框 -->
    <el-dialog v-model="dialogVisible" width="680px" :show-close="false" class="notification-dialog" top="5vh">
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/>
              <path d="M13.73 21a2 2 0 01-3.46 0"/>
            </svg>
          </div>
          <div class="dialog-header-text">
            <template v-if="isViewMode">
              <span class="dialog-title">查看通知</span>
              <span class="dialog-subtitle">通知详情及目标用户组设置</span>
            </template>
            <template v-else>
              <span class="dialog-title">{{ editId ? '编辑通知' : '发布新通知' }}</span>
              <span class="dialog-subtitle">撰写一条系统通知</span>
            </template>
          </div>
        </div>
      </template>

      <div class="dialog-body">
        <el-scrollbar max-height="520px">
        <el-form ref="formRef" :model="formData" :rules="isViewMode ? {} : formRules" label-position="top" autocomplete="off">
          <div class="form-section">
            <div class="form-section-title">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>
              </svg>
              通知标题 <span style="color: #f56c6c;">*</span>
            </div>
            <el-form-item prop="title">
              <el-input v-model="formData.title" type="textarea" maxlength="100" :show-word-limit="!isViewMode" placeholder="输入通知标题..." spellcheck="false" resize="none" :autosize="{ minRows: 2, maxRows: 10 }" :disabled="isViewMode" />
            </el-form-item>
          </div>

          <div class="form-section">
            <div class="form-section-title">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
              </svg>
              通知类型
            </div>
            <el-radio-group v-model="formData.notificationType" class="type-radio-group" :disabled="isViewMode">
              <el-radio-button v-for="item in typeOptions" :key="item.value" :value="item.value" class="type-radio-btn">
                <span class="type-radio-label">
                  <span class="type-dot" :style="{ background: item.color }"></span>
                  {{ item.label }}
                </span>
              </el-radio-button>
            </el-radio-group>
          </div>

          <div class="form-section">
            <div class="form-section-title">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
              </svg>
              通知内容
            </div>
            <el-form-item prop="content">
              <el-input v-model="formData.content" type="textarea" placeholder="详细描述通知内容..." spellcheck="false" resize="none" :autosize="{ minRows: 6, maxRows: 20 }" :disabled="isViewMode" />
            </el-form-item>
          </div>

          <!-- 目标用户组（创建/编辑时可选择，查看时只读） -->
          <div class="form-section">
            <div class="form-section-title">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/>
              </svg>
              目标用户组
            </div>
            <el-select
              v-model="selectedGroupIds"
              multiple
              filterable
              clearable
              placeholder="搜索或选择用户组，不选则推送给全部用户"
              style="width: 100%"
              :loading="loadingGroups"
              :disabled="isViewMode"
              collapse-tags
              collapse-tags-tooltip
            >
              <el-option
                v-for="group in allGroups"
                :key="group.id"
                :label="`${group.groupName} (${group.groupCode})`"
                :value="String(group.id)"
              >
                <div style="display: flex; align-items: center; justify-content: space-between; width: 100%;">
                  <span>{{ group.groupName }} ({{ group.groupCode }})</span>
                  <el-popover
                    placement="right-start"
                    trigger="hover"
                    :width="220"
                    :teleported="true"
                    :disabled="isViewMode"
                  >
                    <template #reference>
                      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#909399" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="cursor: pointer; flex-shrink: 0; margin-left: 6px;">
                        <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/>
                      </svg>
                    </template>
                    <div style="font-size: 13px; max-height: 220px; overflow-y: auto;">
                      <div style="font-weight: 600; color: #5b7fff; margin-bottom: 6px; padding-bottom: 4px; border-bottom: 1px solid #eee;">
                        {{ group.groupName }} 成员
                      </div>
                      <div v-if="(groupUsersMap[group.id] || []).length === 0" style="color: #999;">暂无用户</div>
                      <div
                        v-for="(user, idx) in (groupUsersMap[group.id] || [])"
                        :key="idx"
                        style="padding: 3px 0; color: #303133;"
                      >{{ user }}</div>
                    </div>
                  </el-popover>
                </div>
              </el-option>
            </el-select>
            <div style="margin-top: 6px; font-size: 12px; color: #909399;">
              <template v-if="selectedGroupIds.length === 0">不选则推送给<strong>全部用户</strong></template>
              <template v-else>已选择 {{ selectedGroupIds.length }} 个用户组</template>
            </div>
          </div>
        </el-form>
        </el-scrollbar>
      </div>

      <template #footer>
        <div class="dialog-footer">
          <el-button v-if="isViewMode && isPreviewing" class="dialog-btn-edit" @click="backToEdit">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>&nbsp;返回编辑
          </el-button>
          <el-button v-if="isViewMode && !isPreviewing" class="dialog-btn-preview" :disabled="!canPreview" @click="handlePreview">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>&nbsp;预览
          </el-button>
          <el-button class="dialog-btn-cancel" @click="dialogVisible = false; isViewMode = false; isPreviewing = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;{{ isViewMode ? '关闭' : '取消' }}
          </el-button>
          <el-button v-if="!isViewMode" class="dialog-btn-preview" :disabled="!canPreview" @click="handlePreview">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>&nbsp;预览
          </el-button>
          <el-button v-if="!isViewMode" class="dialog-btn-save" type="primary" @click="saveNotification">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>&nbsp;保存草稿
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 系统通知预览模态框（与用户端一致） -->
    <el-dialog v-model="previewDialogVisible" width="560px" :show-close="false" class="system-notif-dialog" top="8vh" :close-on-click-modal="false">
      <template #header>
        <div class="notif-dialog-header">
          <div class="notif-dialog-header-icon">
            <svg v-if="previewType === 'success'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
            <svg v-else-if="previewType === 'warning'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
            <svg v-else-if="previewType === 'error'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 14s3 2 3 5V5s-3 2-3 5"/><path d="M3 10v4a2 2 0 002 2h3l3 4V4L8 8H5a2 2 0 00-2 2z"/></svg>
            <svg v-else viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
          </div>
          <div class="notif-dialog-header-text">
            <span class="notif-dialog-title-text">{{ previewTitle }}</span>
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <el-tag :type="previewType" size="small" effect="dark">{{ previewTypeLabel }}</el-tag>
              <span v-if="previewPublishTime" style="font-size: 12px; color: rgba(255,255,255,0.7);">{{ previewPublishTime }}</span>
            </div>
          </div>
        </div>
      </template>
      <div class="notif-dialog-body">
        <el-scrollbar max-height="400px">
          <div class="notif-dialog-content" v-html="previewHtmlContent"></div>
        </el-scrollbar>
      </div>
      <template #footer>
        <div class="notif-dialog-footer">
          <el-button class="notif-dialog-btn" @click="previewDialogVisible = false">我知道了</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.notification-page {
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
/* 各卡片配色 */
.stat-today-published { background: linear-gradient(135deg, #e8f5e9, #c8e6c9); border-color: #a5d6a7; }
.stat-today-published .stat-icon { background: rgba(76,175,80,0.15); color: #2e7d32; }
.stat-today-published .stat-value { color: #1b5e20; }
.stat-today-published .stat-label { color: #2e7d32; }

.stat-unpublished { background: linear-gradient(135deg, #fff3e0, #ffe0b2); border-color: #ffcc80; }
.stat-unpublished .stat-icon { background: rgba(255,152,0,0.15); color: #e65100; }
.stat-unpublished .stat-value { color: #bf360c; }
.stat-unpublished .stat-label { color: #e65100; }

.stat-total-published { background: linear-gradient(135deg, #e3f2fd, #bbdefb); border-color: #90caf9; }
.stat-total-published .stat-icon { background: rgba(33,150,243,0.15); color: #1565c0; }
.stat-total-published .stat-value { color: #0d47a1; }
.stat-total-published .stat-label { color: #1565c0; }

.stat-urgent { background: linear-gradient(135deg, #fce4ec, #f8bbd0); border-color: #f48fb1; }
.stat-urgent .stat-icon { background: rgba(244,67,54,0.15); color: #c62828; }
.stat-urgent .stat-value { color: #b71c1c; }
.stat-urgent .stat-label { color: #c62828; }

.stat-important { background: linear-gradient(135deg, #f3e5f5, #e1bee7); border-color: #ce93d8; }
.stat-important .stat-icon { background: rgba(156,39,176,0.15); color: #7b1fa2; }
.stat-important .stat-value { color: #4a148c; }
.stat-important .stat-label { color: #7b1fa2; }

.stat-normal { background: linear-gradient(135deg, #e8f5e9, #c8e6c9); border-color: #a5d6a7; }
.stat-normal .stat-icon { background: rgba(76,175,80,0.15); color: #2e7d32; }
.stat-normal .stat-value { color: #1b5e20; }
.stat-normal .stat-label { color: #2e7d32; }

.list-card {
  flex: 1; border-radius: 10px; overflow: hidden; display: flex; flex-direction: column;
}
.list-card :deep(.el-card__body) {
  display: flex; flex-direction: column; flex: 1; padding: 16px 20px; overflow: hidden;
}

/* 过滤栏样式（参考告警页面） */
.filter-bar {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  margin-bottom: 16px;
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

/* 输入框和选择器统一样式（参考告警页面） */
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
.filter-bar :deep(.el-button),
:deep(.el-button) {
  height: 32px;
  padding: 0 14px;
  font-size: 13px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
}
.table-wrapper {
  flex: 1; min-height: 0; display: flex; flex-direction: column;
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

/* 工具栏搜索框 */
.toolbar-search-input {
  width: 320px;
}
.toolbar-search-input :deep(.el-input__wrapper) {
  border-radius: 8px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  height: 34px;
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
}

/* Markdown 渲染内容在表格中的样式 */
.notification-content {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: inline-block;
  max-width: 100%;
  vertical-align: middle;
}
.notification-content :deep(strong) {
  font-weight: 600;
}
.notification-content :deep(code) {
  background: #f0f0f0;
  padding: 1px 4px;
  border-radius: 3px;
  font-size: 12px;
}
.notification-content :deep(a) {
  color: #409eff;
  text-decoration: none;
}
.notification-content :deep(a:hover) {
  text-decoration: underline;
}
.notification-content :deep(p) {
  margin: 0;
}

/* 告警公共图标样式 */
.icon-svg {
  width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-width: 2;
  stroke-linecap: round; stroke-linejoin: round;
}
.icon-svg.sm {
  width: 14px; height: 14px;
}
.table-wrapper :deep(.el-table__body-wrapper) {
  overflow-y: auto;
}
/* 通知标题和内容列超出省略 */
.table-wrapper :deep(.el-table__body-wrapper) .el-table__body .cell {
  overflow: hidden !important;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pagination-wrapper {
  display: flex; justify-content: space-between; align-items: center;
  padding: 28px 16px 4px;
}
.pagination-total {
  font-size: 13px; color: #606266;
}

/* 对话框样式 - 现代化卡通风格 */
.notification-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.notification-dialog :deep(.el-dialog__header) {
  padding: 0;
  margin: 0;
}
.notification-dialog :deep(.el-dialog__body) {
  padding: 0;
}
.notification-dialog :deep(.el-dialog__footer) {
  padding: 0;
}

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
  height: 42px;
}
.form-section :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
.form-section :deep(.el-textarea__inner) {
  border-radius: 10px;
  box-shadow: 0 0 0 1px #e4e7f0 inset !important;
  padding: 10px 12px;
  font-size: 14px;
  line-height: 1.6;
  min-height: 120px;
}
.form-section :deep(.el-textarea__inner:focus) {
  box-shadow: 0 0 0 2px #667eea inset !important;
}
.form-section :deep(.el-input__count) {
  font-size: 12px;
  color: #a8abbd;
  bottom: 4px;
}

/* 通知内容文本域滚动条 el-scrollbar 风格 */
.form-section :deep(.el-textarea__inner)::-webkit-scrollbar {
  width: 6px;
}
.form-section :deep(.el-textarea__inner)::-webkit-scrollbar-thumb {
  background: #c0c4cc;
  border-radius: 3px;
}
.form-section :deep(.el-textarea__inner)::-webkit-scrollbar-thumb:hover {
  background: #909399;
}
.form-section :deep(.el-textarea__inner)::-webkit-scrollbar-track {
  background: transparent;
}

.type-radio-group {
  display: flex;
  gap: 10px;
}
.type-radio-btn {
  flex: 1;
}
.type-radio-btn :deep(.el-radio-button__inner) {
  border-radius: 10px !important;
  padding: 10px 16px;
  height: auto;
  font-size: 13px;
  border: 1px solid #e4e7f0;
  box-shadow: 0 1px 3px rgba(0,0,0,0.04);
  transition: all 0.25s ease;
}
.type-radio-btn :deep(.el-radio-button__inner:hover) {
  border-color: #667eea;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
}
.type-radio-btn :deep(.el-radio-button__orig-radio:checked + .el-radio-button__inner) {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border-color: transparent;
  color: #fff;
  box-shadow: 0 4px 14px rgba(102, 126, 234, 0.35);
}
.type-radio-label {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}
.type-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}
.type-radio-btn :deep(.el-radio-button__orig-radio:checked + .el-radio-button__inner) .type-dot {
  box-shadow: 0 0 0 2px rgba(255,255,255,0.6);
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 16px 28px 24px;
  background: #f8f9fe;
}
.dialog-btn-cancel {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 20px;
  border: 1px solid #e4e7f0;
  background: #fff;
  color: #666;
  font-size: 13px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all 0.25s ease;
}
.dialog-btn-cancel:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(255,107,107,0.12);
}

/* 对话框预览按钮 */
.dialog-btn-preview {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 20px;
  background: linear-gradient(135deg, #409eff, #337ecc);
  border: none;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all 0.25s ease;
}
.dialog-btn-preview:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(64, 158, 255, 0.4);
}
.dialog-btn-preview.is-disabled,
.dialog-btn-preview:disabled {
  background: #c8c9cc !important;
  cursor: not-allowed !important;
  transform: none !important;
  box-shadow: none !important;
}

/* 对话框返回编辑按钮 */
.dialog-btn-edit {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 20px;
  background: linear-gradient(135deg, #e6a23c, #c68a2e);
  border: none;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all 0.25s ease;
}
.dialog-btn-edit:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(230, 162, 60, 0.4);
}

.dialog-btn-save {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 22px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  font-size: 13px;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all 0.25s ease;
}
.dialog-btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
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

/* 工具栏新建按钮 - 匹配对话框按钮风格 */
.toolbar-btn-create {
  border-radius: 10px !important;
  height: 34px;
  padding: 0 18px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  transition: all 0.25s ease;
}
.toolbar-btn-create:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}

/* 表格发布按钮 - 匹配对话框按钮风格 */
.table-btn-publish {
  border-radius: 8px !important;
  height: 28px;
  padding: 0 12px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  font-size: 12px;
  font-weight: 500;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: all 0.25s ease;
}
.table-btn-publish:hover {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.35);
}

/* 表格编辑按钮 */
.table-btn-edit {
  border-radius: 8px !important;
  height: 28px;
  padding: 0 12px;
  background: linear-gradient(135deg, #909399, #6b6f76);
  border: none;
  font-size: 12px;
  font-weight: 500;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: all 0.25s ease;
}
.table-btn-edit:hover {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(108, 117, 125, 0.35);
}

/* 表格查看按钮 */
.table-btn-view {
  border-radius: 8px !important;
  height: 28px;
  padding: 0 12px;
  background: linear-gradient(135deg, #409eff, #337ecc);
  border: none;
  font-size: 12px;
  font-weight: 500;
  color: #fff;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: all 0.25s ease;
}
.table-btn-view:hover {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.35);
}

/* 按钮圆角统一 */
:deep(.el-button) {
  transition: all 0.25s ease;
}
:deep(.el-button--primary):hover {
  filter: brightness(1.1);
}
:deep(.el-button--danger):hover {
  filter: brightness(1.1);
}

/* 发布/删除确认框 - 匹配新建通知模态框风格 */
:global(.publish-confirm-box) {
  border-radius: 16px !important;
  padding: 0 !important;
  width: 400px !important;
}
:global(.publish-confirm-box .el-message-box__header) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 16px 24px;
  margin: 0;
  border-radius: 16px 16px 0 0;
}
:global(.publish-confirm-box .el-message-box__headerbtn) {
  display: none;
}
:global(.publish-confirm-box .el-message-box__title) {
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  text-align: center;
}
:global(.publish-confirm-box .el-message-box__content) {
  padding: 24px 24px 8px;
  text-align: center;
  font-size: 14px;
  color: #303133;
  line-height: 1.7;
}
:global(.publish-confirm-box .el-message-box__message p) {
  margin: 0;
}
:global(.publish-confirm-box .el-message-box__btns) {
  padding: 12px 24px 20px;
  display: flex;
  justify-content: center;
  gap: 12px;
}
:global(.publish-confirm-box .el-message-box__btns .el-button) {
  border-radius: 8px !important;
  height: 36px;
  padding: 0 20px;
  font-size: 13px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: all 0.25s ease;
}
:global(.publish-confirm-box .el-message-box__btns .el-button--primary) {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff;
  font-weight: 500;
}
:global(.publish-confirm-box .el-message-box__btns .el-button--primary:hover) {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102, 126, 234, 0.35);
}
:global(.publish-confirm-box .el-message-box__btns .el-button--default) {
  border: 1px solid #dcdfe6;
  background: #fff;
  color: #606266;
}
:global(.publish-confirm-box .el-message-box__btns .el-button--default:hover) {
  color: #f56c6c;
  border-color: #f56c6c;
}

/* 分页紫色主题（与备忘录一致） */
.pagination-wrapper :deep(.el-pagination.is-background .el-pager li:not(.is-disabled).is-active) {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff;
}
</style>
