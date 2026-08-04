<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：顶部导航栏组件
 * @date： 2026-01-28 09:28:01
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:28:01
 */

import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowRight } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { getSystemNotifications, getUserNotificationHistory, markUserNotificationsRead, getUserUnreadCount } from '@/api/systemNotificationApi.js'
import { getTodoList, createTodo, updateTodo, deleteTodo, toggleTodoStatus } from '@/api/todoApi.js'
import {
  messageInstance,
  stopSpeak,
  isSpeaking,
  stopSpeaking,
  user, isSsoLogin
} from '@/utils/publicData.js'


// 获取store实例
const authStore = useAuthStore()
const permissionStore = usePermissionStore()

// 控制喇叭提示框的隐藏与显示
const visible = ref(false)
// 控制告警图标提示框的隐藏与显示
const alarmVisible = ref(false)
const content = ref(stopSpeaking.value ? '点击开启语音播报' : '点击关闭语音播报')
// 顶部个人信息菜单后面的上下箭头翻转标志
const direction = ref(false)
// 面包屑过滤
const route = useRoute()
const router = useRouter()

// 跳转到待办备忘录页面
const goToTodoPage = () => {
  router.push('/systemManagement/todo')
}

// ======== 备忘录待办模态框 ========
const todoDialogVisible = ref(false)
const todoList = ref([])
const selectedTodo = ref(null)
const todoLoading = ref(false)

// 新建待办独立模态框
const todoCreateDialogVisible = ref(false)
const createFormData = ref({ title: '', content: '', todoType: 0, reminderTime: '', recurringPattern: '', recurringDay: '', recurringTime: '09:00' })
const createSaving = ref(false)
const createFormRef = ref(null)

// 编辑模式
const editId = ref(null)
const isEditMode = computed(() => editId.value !== null)

// 右键菜单
const contextMenuVisible = ref(false)
const contextMenuX = ref(0)
const contextMenuY = ref(0)
const contextMenuTodo = ref(null)

const closeContextMenu = () => {
  contextMenuVisible.value = false
}

const handleContextMenu = (e, todo) => {
  e.preventDefault()
  contextMenuX.value = e.clientX
  contextMenuY.value = e.clientY
  contextMenuTodo.value = todo
  contextMenuVisible.value = true
}

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

// 周期性待办时/分双向绑定
const recurringHour = computed({
  get: () => {
    const t = createFormData.value.recurringTime
    if (t && t.includes(':')) return parseInt(t.split(':')[0])
    return 9
  },
  set: (val) => { syncRecurringTime(val, recurringMinute.value) }
})
const recurringMinute = computed({
  get: () => {
    const t = createFormData.value.recurringTime
    if (t && t.includes(':')) return parseInt(t.split(':')[1])
    return 0
  },
  set: (val) => { syncRecurringTime(recurringHour.value, val) }
})
const syncRecurringTime = (h, m) => {
  createFormData.value.recurringTime = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}
// 初始化时确保默认时间写入 recurringTime
syncRecurringTime(9, 0)

// 一次性待办的时/分双向绑定
const reminderHour = computed({
  get: () => {
    if (!createFormData.value.reminderTime || !createFormData.value.reminderTime.includes(' ')) return 9
    return parseInt(createFormData.value.reminderTime.split(' ')[1].split(':')[0] || '9')
  },
  set: (val) => {
    const hh = String(val).padStart(2, '0')
    if (createFormData.value.reminderTime && createFormData.value.reminderTime.includes(' ')) {
      const date = createFormData.value.reminderTime.split(' ')[0]
      const mm = createFormData.value.reminderTime.split(' ')[1]?.split(':')[1] || '00'
      createFormData.value.reminderTime = `${date} ${hh}:${mm}`
    } else if (createFormData.value.reminderTime) {
      createFormData.value.reminderTime = `${createFormData.value.reminderTime} ${hh}:00`
    }
  }
})
const reminderMinute = computed({
  get: () => {
    if (!createFormData.value.reminderTime || !createFormData.value.reminderTime.includes(' ')) return 0
    return parseInt(createFormData.value.reminderTime.split(' ')[1]?.split(':')[1] || '0')
  },
  set: (val) => {
    const mm = String(val).padStart(2, '0')
    if (createFormData.value.reminderTime && createFormData.value.reminderTime.includes(' ')) {
      const date = createFormData.value.reminderTime.split(' ')[0]
      const hh = createFormData.value.reminderTime.split(' ')[1]?.split(':')[0] || '09'
      createFormData.value.reminderTime = `${date} ${hh}:${mm}`
    } else if (createFormData.value.reminderTime) {
      createFormData.value.reminderTime = `${createFormData.value.reminderTime} 09:${mm}`
    }
  }
})

// 构建周期性提醒显示文本
const buildRecurringReminderTime = () => {
  const fd = createFormData.value
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

const loadTodoList = async () => {
  const username = sessionStorage.getItem('user')
  if (!username) return
  todoLoading.value = true
  try {
    const res = await getTodoList({ username, page: 1, pageSize: 200 })
    if (res.code === 200) {
      const allList = res.data.records || []
      const todayStr = new Date().toISOString().slice(0, 10)
      // 显示所有启用(status=0) + 今日已完成(status=1且completedTime为今天)的待办
      todoList.value = allList.filter(t => t.status === 0 || (t.status === 1 && t.completedTime && t.completedTime.startsWith(todayStr)))
      selectedTodo.value = todoList.value.length > 0 ? todoList.value[0] : null
    }
  } catch (e) {
    console.error('加载待办列表失败:', e.message)
  } finally {
    todoLoading.value = false
  }
}

// 判断待办是否为今日已提醒（只读状态）
const isTodoReminded = (todo) => {
  if (!todo) return false
  const todayStr = new Date().toISOString().slice(0, 10)
  if (!todo.completedTime || !todo.completedTime.startsWith(todayStr)) return false
  // 周期性待办：completedTime 时间需在 recurring_time ±30s 窗口内（与后端匹配）
  if (todo.todoType === 1 && todo.recurringTime) {
    const timePart = todo.completedTime.split(' ')[1] || '00:00:00'
    const compSec = parseInt(timePart.split(':')[0]) * 3600 + parseInt(timePart.split(':')[1]) * 60 + parseInt(timePart.split(':')[2] || '0')
    const recParts = todo.recurringTime.split(':')
    const recSec = parseInt(recParts[0]) * 3600 + parseInt(recParts[1]) * 60
    return Math.abs(compSec - recSec) <= 30
  }
  return true
}

const openTodoDialog = () => {
  closeContextMenu()
  todoDialogVisible.value = true
  loadTodoList()
}

const selectTodo = (todo) => {
  selectedTodo.value = todo
}

const resetCreateForm = () => {
  editId.value = null
  createFormData.value = { title: '', content: '', todoType: 0, reminderTime: '', recurringPattern: '', recurringDay: '', recurringTime: '09:00' }
  syncRecurringTime(9, 0)
}

const openCreateTodoDialog = () => {
  resetCreateForm()
  todoCreateDialogVisible.value = true
}

const openEditTodoDialog = (todo) => {
  resetCreateForm()
  editId.value = todo.id
  createFormData.value = {
    title: todo.title || '',
    content: todo.content || '',
    todoType: todo.todoType || 0,
    reminderTime: todo.reminderTime || '',
    recurringPattern: todo.recurringPattern !== null && todo.recurringPattern !== undefined ? todo.recurringPattern : '',
    recurringDay: todo.recurringDay !== null && todo.recurringDay !== undefined ? todo.recurringDay : '',
    recurringTime: todo.recurringTime || ''
  }
  if (createFormData.value.recurringTime && createFormData.value.recurringTime.includes(':')) {
    const parts = createFormData.value.recurringTime.split(':')
    syncRecurringTime(parseInt(parts[0]), parseInt(parts[1]))
  }
  todoCreateDialogVisible.value = true
}

const handleContextMenuCommand = (todo, cmd) => {
  closeContextMenu()
  if (cmd === 'edit') {
    openEditTodoDialog(todo)
  } else if (cmd === 'delete') {
    handleDeleteTodo(todo)
  } else if (cmd === 'toggle') {
    handleToggleTodoStatus(todo)
  }
}

const handleDeleteTodo = async (todo) => {
  try {
    await ElMessageBox.confirm('<div style="display:flex;align-items:flex-start;gap:14px;"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#f56c6c" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:1px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg><span style="font-size:14px;color:#303133;line-height:1.8;">确定要删除待办事项吗？</span></div>', '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'todo-header-confirm-box', showClose: false, dangerouslyUseHTMLString: true, top: '12vh',
    })
    const res = await deleteTodo(todo.id)
    if (res.code === 200) {
      ElMessage.success('删除成功')
      if (selectedTodo.value?.id === todo.id) selectedTodo.value = null
      loadTodoList()
      window.dispatchEvent(new Event('todo-reminded'))
    } else {
      ElMessage.error(res.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('删除失败：' + e.message)
  }
}

const handleToggleTodoStatus = async (todo) => {
  const actionText = todo.status === 0 ? '停用' : '启用'
  const iconColor = todo.status === 0 ? '#e6a23c' : '#67c23a'
  try {
    await ElMessageBox.confirm(`<div style="display:flex;align-items:flex-start;gap:14px;"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="${iconColor}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:1px;">${todo.status === 0 ? '<polyline points="20 6 9 17 4 12"/>' : '<circle cx="12" cy="12" r="10"/>'}</svg><span style="font-size:14px;color:#303133;line-height:1.8;">确定要${actionText}该待办事项吗？</span></div>`, '提示', {
      confirmButtonText: '确定', cancelButtonText: '取消',
      customClass: 'todo-header-confirm-box', showClose: false, dangerouslyUseHTMLString: true, top: '12vh',
    })
    const res = await toggleTodoStatus(todo.id)
    if (res.code === 200) {
      ElMessage.success(todo.status === 0 ? '已停用' : '已启用')
      if (selectedTodo.value?.id === todo.id) selectedTodo.value = null
      loadTodoList()
      window.dispatchEvent(new Event('todo-reminded'))
    } else {
      ElMessage.error(res.message || '状态更新失败')
    }
  } catch (e) {
    if (e !== 'cancel') ElMessage.error('状态更新失败：' + e.message)
  }
}

const handleCreateTodo = async () => {
  if (!createFormData.value.title.trim()) {
    ElMessage.warning('请输入待办标题')
    return
  }
  if (!createFormData.value.content.trim()) {
    ElMessage.warning('请输入待办内容')
    return
  }
  const username = sessionStorage.getItem('user')
  if (!username) return
  createSaving.value = true
  try {
    const payload = {
      title: createFormData.value.title,
      content: createFormData.value.content,
      todoType: createFormData.value.todoType,
      reminderTime: createFormData.value.reminderTime
        ? (createFormData.value.reminderTime.includes(' ') ? createFormData.value.reminderTime : createFormData.value.reminderTime + ' 09:00')
        : '',
      recurringPattern: createFormData.value.recurringPattern !== '' ? createFormData.value.recurringPattern : '',
      recurringDay: createFormData.value.recurringDay !== '' ? createFormData.value.recurringDay : '',
      recurringTime: createFormData.value.recurringTime || ''
    }
    if (isEditMode.value) {
      payload.id = editId.value
      const res = await updateTodo(payload)
      if (res.code === 200) {
        ElMessage.success('更新成功')
        resetCreateForm()
        todoCreateDialogVisible.value = false
        loadTodoList()
        window.dispatchEvent(new Event('todo-reminded'))
      } else {
        ElMessage.error(res.message || '更新失败')
      }
    } else {
      payload.createdBy = username
      const res = await createTodo(payload)
      if (res.code === 200) {
        ElMessage.success('创建成功')
        resetCreateForm()
        todoCreateDialogVisible.value = false
        loadTodoList()
        window.dispatchEvent(new Event('todo-reminded'))
      } else {
        ElMessage.error(res.message || '创建失败')
      }
    }
  } catch (e) {
    ElMessage.error((isEditMode.value ? '更新' : '创建') + '失败：' + e.message)
  } finally {
    createSaving.value = false
  }
}

// 系统通知铃铛
const recentNotifications = ref([])
const notifDialogVisible = ref(false)
const recentLoading = ref(false)
const hasNotifications = ref(false)

// 打开通知历史模态框
const openNotifDialog = () => {
  loadRecentNotifications(true)
  notifDialogVisible.value = true
}

// 通知搜索与分页
const notifPage = ref(1)
const notifPageSize = ref(10)
const notifTotal = ref(0)
const notifSearchTitle = ref('')
const notifDateRange = ref([])
const notifTypeStyles = {
  success: { label: '普通通知', color: '#67c23a', bg: '#e8f5e9' },
  warning: { label: '重要通知', color: '#e6a23c', bg: '#fff3e0' },
  error: { label: '紧急通知', color: '#f56c6c', bg: '#fce4ec' },
}

const getNotifStyle = (type) => notifTypeStyles[type] || notifTypeStyles.success

// 通知类型 → el-tag type 映射
const getElTagType = (type) => {
  const map = { success: 'success', warning: 'warning', error: 'danger' }
  return map[type] || 'info'
}

const loadRecentNotifications = async (markRead = false) => {
  if (recentLoading.value) return
  recentLoading.value = true
  try {
    const username = sessionStorage.getItem('user') || ''
    const params = {
      username,
      page: notifPage.value,
      pageSize: notifPageSize.value,
      title: notifSearchTitle.value,
    }
    if (notifDateRange.value && notifDateRange.value.length === 2) {
      params.startDate = notifDateRange.value[0]
      params.endDate = notifDateRange.value[1]
    }
    if (markRead) {
      // 用户打开了通知弹窗：后端持久化已读标记（跨登录/跨设备生效）
      try {
        await markUserNotificationsRead(username)
        hasNotifications.value = false
      } catch (e) {
        console.error('标记通知已读失败：', e.message)
      }
    }
    const res = await getUserNotificationHistory(params)
    if (res.code === 200) {
      recentNotifications.value = res.data.records || []
      notifTotal.value = res.data.total || 0
    }
    if (!markRead) {
      // 后台加载（如 onMounted），红点 = 后端未读数量 > 0
      try {
        const cntRes = await getUserUnreadCount(username)
        hasNotifications.value = cntRes.code === 200 && cntRes.data && cntRes.data.unreadCount > 0
      } catch (e) {
        console.error('获取未读通知数失败：', e.message)
      }
    }
  } catch (e) {
    console.error('加载通知历史失败：', e.message)
  } finally {
    recentLoading.value = false
  }
}

const formatTime = (timeStr) => {
  if (!timeStr) return ''
  return timeStr.substring(0, 16)
}

// 通知"最新"标签时间窗口（毫秒）：接收时间在此窗口内的通知显示"最新"标签
const NOTIF_NEW_WINDOW_MS = 24 * 60 * 60 * 1000

const isNewNotif = (item) => {
  const t = item.publishTime || item.createdTime
  if (!t) return false
  // 兼容 Safari：'YYYY-MM-DD HH:MM:SS' 需替换为 '/' 才能被 new Date 解析
  const ts = new Date(t.replace(/-/g, '/')).getTime()
  if (isNaN(ts)) return false
  return Date.now() - ts <= NOTIF_NEW_WINDOW_MS
}

// 获取内容预览（去除 HTML 标签，截取前 60 字符）
const getContentPreview = (content) => {
  if (!content) return ''
  const text = content.replace(/<[^>]*>/g, '')
  return text.length > 60 ? text.substring(0, 60) + '...' : text
}

const handleNotifClick = (item) => {
  if (item.source === 'system') {
    // 系统通知 → 派发事件让 App.vue 打开模态框（历史对话框保持打开）
    window.dispatchEvent(new CustomEvent('show-system-notification', {
      detail: {
        title: item.title,
        content: item.content,
        type: item.notificationType,
        publishTime: item.publishTime || item.createdTime || '',
      }
    }))
  }
}

// 搜索通知
const handleNotifSearch = () => {
  notifPage.value = 1
  loadRecentNotifications()
}

// 重置搜索
const handleNotifReset = () => {
  notifSearchTitle.value = ''
  notifDateRange.value = []
  notifPage.value = 1
  loadRecentNotifications()
}

let _onNotifReceived

const _onDocumentClick = () => { closeContextMenu() }

onMounted(() => {
  loadRecentNotifications()
  _onNotifReceived = () => loadRecentNotifications()
  window.addEventListener('system-notification-received', _onNotifReceived)
  document.addEventListener('click', _onDocumentClick)
})

onUnmounted(() => {
  window.removeEventListener('system-notification-received', _onNotifReceived)
  document.removeEventListener('click', _onDocumentClick)
})
const breadcrumbList = computed(() => {
  // 过滤掉没有breadcrumb的路由记录
  return route.matched.filter(item => item.meta && item.meta.breadcrumb)
})
// 侦听开启/关闭语音播报状态的更新
watch( stopSpeaking, async (newVal) => {
  if (newVal === false) {
    content.value = '点击关闭语音播报'
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.success({
      message: '已开启语音播报',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  } else {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel() // 清除之前的播报
    }
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    content.value = '点击开启语音播报'
    messageInstance.value = ElMessage.warning({
      message: '已关闭语音播报',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  }
},
  { flush: 'sync' } // 立即触发回调函数
)

// 控制个人信息菜单的展开与收起
const changeDirection = (isVisible) => {
  direction.value = isVisible
}
const logout = async () =>{
  if (isSsoLogin.value){
    // SSO登录退出
    authStore.logoutInfoClear()
    window.location.replace('https://100.18.16.180/next/portal')
  } else {
    // 域登录退出
    authStore.logoutInfoClear()
    router.push('/login')
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.success({
      message: '退出登录',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  }
}
// onMounted(() => {
//   if (sessionStorage.getItem('user')) {
//     user.value = sessionStorage.getItem('user')
//   }
// })
</script>

<template>
  <div class="bread-crumb">
    <!-- 面包屑组件开始 -->
    <el-breadcrumb :separator-icon="ArrowRight" ref="breadCrumb">
      <el-breadcrumb-item
        v-for="(item, index) in breadcrumbList"
        :key="index"
        :to="item.path"
      >
        {{ item.meta.breadcrumb }}
      </el-breadcrumb-item>
    </el-breadcrumb>
    <!-- 面包屑组件结束 -->
  </div>
  <div class="user">
    <!-- 待办备忘录入口 -->
    <div class="header-todo-wrapper">
      <el-tooltip content="待办备忘录" placement="bottom" popper-class="header-icon-tooltip">
        <el-icon class="speak header-todo-icon" @click="openTodoDialog">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M9 11l3 3L22 4"/>
            <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/>
          </svg>
        </el-icon>
      </el-tooltip>
    </div>
    <!-- 通知铃铛 -->
    <div class="header-notif-wrapper">
      <el-tooltip content="通知历史" placement="bottom" popper-class="header-icon-tooltip">
        <el-icon class="speak header-notif-icon" @click="openNotifDialog">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" stroke="none" class="notif-bell-icon"><path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/></svg>
        </el-icon>
      </el-tooltip>
      <span v-if="hasNotifications" class="header-notif-dot"></span>
    </div>

    <!-- 通知历史模态框 -->
    <el-dialog v-model="notifDialogVisible" width="600px" class="notif-history-dialog" top="6vh" :show-close="false" :close-on-click-modal="false" @opened="loadRecentNotifications(true)">
      <template #header>
        <div class="notif-dialog-header">
          <div style="display:flex;align-items:center;gap:16px;">
            <div class="notif-dialog-header-icon">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
            </div>
            <div class="notif-dialog-header-text">
              <span class="notif-dialog-title-text">通知历史</span>
              <span style="font-size:12px;color:rgba(255,255,255,0.7);">共 {{ notifTotal }} 条</span>
            </div>
          </div>
        </div>
      </template>
      <button class="notif-dialog-close" @click="notifDialogVisible = false">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
      </button>

      <!-- 搜索栏 -->
      <div class="notif-search-bar">
        <el-input v-model="notifSearchTitle" placeholder="搜索标题" clearable style="width:140px;" size="small" @keyup.enter="handleNotifSearch" />
        <el-date-picker v-model="notifDateRange" type="daterange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="YYYY-MM-DD" style="width:210px;" size="small" @change="handleNotifSearch" />
        <el-button size="small" class="notif-search-btn" @click="handleNotifSearch">搜索</el-button>
        <el-button size="small" class="notif-reset-btn" @click="handleNotifReset">重置</el-button>
      </div>

      <!-- 通知列表 -->
      <el-scrollbar max-height="450px" v-loading="recentLoading">
        <div v-if="recentNotifications.length === 0 && !recentLoading" class="recent-notif-empty">
              <el-empty description="暂无通知" :image-size="80" />
            </div>
        <div v-for="item in recentNotifications" :key="item.id" class="recent-notif-item" :class="{ 'new-notif-item': isNewNotif(item) }" @click="handleNotifClick(item)" :style="{ borderLeftColor: getNotifStyle(item.notificationType).color }">
          <div class="recent-notif-item-top">
            <span class="recent-notif-source-tag" :style="{ background: getNotifStyle(item.notificationType).bg, color: getNotifStyle(item.notificationType).color, borderColor: getNotifStyle(item.notificationType).color }">
              <span class="source-dot" :style="{ background: getNotifStyle(item.notificationType).color }"></span>
              {{ getNotifStyle(item.notificationType).label }}
            </span>
            <span class="recent-notif-top-right">
              <span v-if="isNewNotif(item)" class="recent-notif-new-badge">
                <svg viewBox="0 0 24 24" width="11" height="11" fill="currentColor" stroke="none"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                NEW
              </span>
              <span class="recent-notif-time">{{ formatTime(item.publishTime || item.createdTime) }}</span>
            </span>
          </div>
          <div class="recent-notif-item-title">
            <el-tag size="small" :type="getElTagType(item.notificationType)" effect="plain" style="font-size:10px;padding:0 4px;height:18px;line-height:18px;border-radius:3px;">标题</el-tag>
            <span :style="{ color: getNotifStyle(item.notificationType).color }">{{ item.title }}</span>
          </div>
          <div class="recent-notif-item-desc">
            <el-tag size="small" :type="getElTagType(item.notificationType)" effect="plain" style="font-size:10px;padding:0 4px;height:18px;line-height:18px;border-radius:3px;">正文</el-tag>
            <span>{{ getContentPreview(item.content) }}</span>
          </div>
        </div>
      </el-scrollbar>

      <!-- 分页 -->
      <div v-if="notifTotal > 10" class="notif-pagination">
        <el-pagination v-model:current-page="notifPage" :page-size="notifPageSize" :total="notifTotal" layout="prev, pager, next" small background @current-change="loadRecentNotifications" />
      </div>
    </el-dialog>

    <!-- 备忘录待办模态框 -->
    <el-dialog v-model="todoDialogVisible" width="800px" class="memo-todo-dialog" top="8vh" :show-close="false" :close-on-click-modal="false">
      <template #header>
        <div class="memo-todo-header">
          <div class="memo-todo-header-left">
            <div class="memo-todo-header-icon">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/></svg>
            </div>
            <div class="memo-todo-header-text">
              <span class="memo-todo-title-text">备忘录待办</span>
              <span style="font-size:12px;color:rgba(255,255,255,0.7);">{{ todoList.length }} 条待办</span>
            </div>
          </div>
          <button class="memo-todo-close" @click="todoDialogVisible = false">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
      </template>

      <div class="memo-todo-body">
        <!-- 左侧：目录 -->
        <div class="memo-todo-sidebar">
          <div class="memo-todo-sidebar-top">
            <button class="memo-todo-add-btn" @click="openCreateTodoDialog">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>
              <span>新建待办</span>
            </button>
          </div>
          <el-scrollbar class="memo-todo-list" v-loading="todoLoading">
            <div v-if="todoList.length === 0 && !todoLoading" class="memo-todo-empty">暂无待办</div>
            <div
              v-for="todo in todoList" :key="todo.id"
              class="memo-todo-item"
              :class="{ active: selectedTodo?.id === todo.id }"
              @click="selectTodo(todo)"
              @contextmenu.prevent="handleContextMenu($event, todo)"
            >
              <div class="memo-todo-item-type" :class="todo.todoType === 1 ? 'type-recurring' : 'type-once'">
                {{ todo.todoType === 1 ? '周' : '次' }}
              </div>
              <span class="memo-todo-item-title" :class="{ 'title-reminded': todo.status === 1 }" :title="todo.title">{{ todo.title }}</span>
              <span v-if="isTodoReminded(todo)" class="memo-todo-reminded-badge">已提醒</span>
            </div>
          </el-scrollbar>
          <!-- 右键菜单 -->
          <div v-if="contextMenuVisible" class="memo-todo-context-menu" :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }" @click.stop>
            <div class="memo-todo-context-item" @click="handleContextMenuCommand(contextMenuTodo, 'edit')">
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
              <span>编辑</span>
            </div>
            <div class="memo-todo-context-item" @click="handleContextMenuCommand(contextMenuTodo, 'delete')">
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>
              <span>删除</span>
            </div>
            <div class="memo-todo-context-item" @click="handleContextMenuCommand(contextMenuTodo, 'toggle')">
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline v-if="contextMenuTodo?.status === 0" points="20 6 9 17 4 12"/><circle v-else cx="12" cy="12" r="10"/></svg>
              <span>{{ contextMenuTodo?.status === 0 ? '停用' : '启用' }}</span>
            </div>
          </div>
        </div>

        <!-- 右侧：内容 -->
        <div class="memo-todo-content">
          <el-scrollbar class="memo-todo-content-scrollbar">
            <template v-if="selectedTodo">
              <div class="memo-todo-content-header">
                <span class="memo-todo-content-title">{{ selectedTodo.title }}</span>
                <span style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
                  <el-tag size="small" type="warning" effect="plain" :style="{ visibility: isTodoReminded(selectedTodo) ? 'visible' : 'hidden', flexShrink: 0 }">已提醒</el-tag>
                  <el-tag size="small" :type="selectedTodo.todoType === 1 ? 'primary' : 'info'" effect="plain" style="flex-shrink:0;">
                    {{ selectedTodo.todoType === 1 ? '周期性' : '一次性' }}
                  </el-tag>
                </span>
              </div>
              <div class="memo-todo-content-meta">
                <span v-if="selectedTodo.todoType === 0 && selectedTodo.reminderTime" style="color:#e6a23c;">⏰ {{ selectedTodo.reminderTime?.substring(5, 16) }}</span>
                <span v-if="selectedTodo.todoType === 1 && selectedTodo.recurringTime" style="color:#667eea;">🔄 {{ selectedTodo.recurringTime }} · {{ selectedTodo.recurringPattern === 2 ? '每天' : selectedTodo.recurringPattern === 1 ? '每周' : selectedTodo.recurringPattern === 0 ? '每月' : '' }}</span>
                <span style="color:#909399;">修改于 {{ selectedTodo.updateTime || selectedTodo.createTime?.substring(0, 16) || '-' }}</span>
              </div>
              <el-divider style="margin:12px 0;" />
              <div class="memo-todo-content-text">
                <p v-if="selectedTodo.content" style="white-space:pre-wrap;">{{ selectedTodo.content }}</p>
                <span v-else style="color:#c0c4cc;">暂无内容</span>
              </div>
            </template>
            <template v-else>
              <div class="memo-todo-empty-content">
                <span style="color:#c0c4cc;font-size:14px;">请从左侧选择待办查看内容</span>
              </div>
            </template>
          </el-scrollbar>
        </div>
      </div>
    </el-dialog>
    <!-- 新建待办模态框 -->
    <el-dialog v-model="todoCreateDialogVisible" width="650px" :show-close="false" class="todo-create-dialog" top="18vh">
      <template #header>
        <div class="todo-create-header">
          <div class="todo-create-header-left">
            <div class="todo-create-header-icon">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>
            </div>
            <div class="todo-create-header-text">
              <span class="todo-create-title-text">{{ isEditMode ? '编辑待办' : '新建待办' }}</span>
              <span style="font-size:12px;color:rgba(255,255,255,0.7);">{{ isEditMode ? '修改待办事项内容' : '记录一条待办事项' }}</span>
            </div>
          </div>
          <button class="todo-create-close" @click="todoCreateDialogVisible = false">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
      </template>

      <div class="todo-create-body">
        <el-scrollbar max-height="450px">
          <el-form ref="createFormRef" :model="createFormData" label-position="top" autocomplete="off">
            <!-- 待办标题 -->
            <div class="todo-create-section">
              <div class="todo-create-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                待办标题 <span style="color:#f56c6c;">*</span>
              </div>
              <el-form-item :rules="{ required: true, message: '请输入待办标题', trigger: 'blur' }">
                <el-input v-model="createFormData.title" type="textarea" maxlength="100" :show-word-limit="true" placeholder="输入待办标题..." spellcheck="false" resize="none" :autosize="{ minRows: 2 }" />
              </el-form-item>
            </div>

            <!-- 待办内容 -->
            <div class="todo-create-section">
              <div class="todo-create-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>
                待办内容 <span style="color:#f56c6c;">*</span>
              </div>
              <el-form-item :rules="{ required: true, message: '请输入待办内容', trigger: 'blur' }">
                <el-input v-model="createFormData.content" type="textarea" placeholder="输入待办内容..." spellcheck="false" resize="none" :autosize="{ minRows: 3 }" />
              </el-form-item>
            </div>

            <!-- 待办类型 -->
            <div class="todo-create-section">
              <div class="todo-create-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                待办类型
              </div>
              <div class="todo-create-type-selector">
                <div
                  v-for="opt in todoTypeOptions" :key="opt.value"
                  class="todo-create-type-card"
                  :class="{ active: createFormData.todoType === opt.value }"
                  @click="createFormData.todoType = opt.value"
                >
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path :d="opt.icon"/>
                  </svg>
                  <span>{{ opt.label }}</span>
                </div>
              </div>
            </div>

            <!-- 一次性待办：选择日期时间 -->
            <div v-if="createFormData.todoType === 0" class="todo-create-section">
              <div class="todo-create-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                提醒时间（可选）
              </div>
              <el-form-item>
                <div class="todo-create-reminder-row">
                  <el-date-picker
                    v-model="createFormData.reminderTime"
                    type="date"
                    placeholder="选择日期"
                    value-format="YYYY-MM-DD"
                    style="width:140px"
                    :disabled-date="(time) => time.getTime() < Date.now() - 86400000"
                  />
                  <template v-if="createFormData.reminderTime">
                    <el-select v-model="reminderHour" placeholder="时" style="width:72px">
                      <el-option v-for="h in hourOptions" :key="h.value" :label="h.label" :value="h.value" />
                    </el-select>
                    <span style="color:#303133;font-weight:600;">:</span>
                    <el-select v-model="reminderMinute" placeholder="分" style="width:72px">
                      <el-option v-for="m in minuteOptions" :key="m.value" :label="m.label" :value="m.value" />
                    </el-select>
                  </template>
                </div>
              </el-form-item>
              <div style="margin-top:2px;font-size:12px;color:#909399;">设置后将在指定时间弹出提醒</div>
            </div>

            <!-- 周期性待办：选择周期模式+时间 -->
            <div v-if="createFormData.todoType === 1" class="todo-create-section">
              <div class="todo-create-section-title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 014-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 01-4 4H3"/></svg>
                重复周期
              </div>
              <div class="todo-create-recurring-row">
                <el-select v-model="createFormData.recurringPattern" placeholder="选择周期" style="width:100px">
                  <el-option v-for="p in recurringPatternOptions" :key="p.value" :label="p.label" :value="p.value" />
                </el-select>
                <!-- 按周：选择星期几 -->
                <el-select v-if="createFormData.recurringPattern === 1" v-model="createFormData.recurringDay" placeholder="选择星期" style="width:110px">
                  <el-option v-for="w in weekdayOptions" :key="w.value" :label="w.label" :value="w.value" />
                </el-select>
                <!-- 按月：选择几号 -->
                <el-select v-if="createFormData.recurringPattern === 0" v-model="createFormData.recurringDay" placeholder="选择日期" style="width:110px">
                  <el-option v-for="d in monthDayOptions" :key="d.value" :label="d.label" :value="d.value" />
                </el-select>
                <span v-if="createFormData.recurringPattern !== '' && createFormData.recurringPattern !== null" style="color:#909399;margin:0 2px;">的</span>
                <!-- 时间选择 -->
                <template v-if="createFormData.recurringPattern !== '' && createFormData.recurringPattern !== null">
                  <el-select v-model="recurringHour" placeholder="时" style="width:72px">
                    <el-option v-for="h in hourOptions" :key="h.value" :label="h.label" :value="h.value" />
                  </el-select>
                  <span style="color:#303133;font-weight:600;">:</span>
                  <el-select v-model="recurringMinute" placeholder="分" style="width:72px">
                    <el-option v-for="m in minuteOptions" :key="m.value" :label="m.label" :value="m.value" />
                  </el-select>
                </template>
              </div>
              <div v-if="buildRecurringReminderTime()" style="margin-top:10px;padding:8px 14px;background:#f0f4ff;border-radius:8px;font-size:13px;color:#5b7fff;">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle;margin-right:4px;"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                将在「<strong>{{ buildRecurringReminderTime() }}</strong>」自动提醒
              </div>
            </div>
          </el-form>
        </el-scrollbar>
      </div>

      <template #footer>
        <div class="todo-create-footer">
          <el-button class="todo-create-btn-cancel" @click="todoCreateDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="todo-create-btn-save" type="primary" :loading="createSaving" @click="handleCreateTodo">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>&nbsp;{{ isEditMode ? '保存修改' : '创建待办' }}
          </el-button>
        </div>
      </template>
    </el-dialog>
    <!--  告警开关控制图标  -->
    <el-tooltip :visible="alarmVisible" popper-class="header-icon-tooltip"
                :content="content"
    >
      <el-icon class="speak" @click="stopSpeaking = !stopSpeaking" @mouseenter="alarmVisible = true" @mouseleave="alarmVisible = false">
        <svg class="icon" aria-hidden="true" style="pointer-events: none">
          <use v-show="!stopSpeaking" xlink:href="#icon-lingdang_mian"></use>
          <use v-show="stopSpeaking" xlink:href="#icon-lingdang-jingyin_mian"></use>
        </svg>
      </el-icon>
    </el-tooltip>
    <!--  告警喇叭图标  -->
    <el-tooltip :visible="visible" popper-class="header-icon-tooltip"
      content="停止语音播报"
    >
      <el-icon class="speak" @click="stopSpeak" @mouseenter="visible = true" @mouseleave="visible = false">
        <svg class="icon" aria-hidden="true" style="pointer-events: none">
          <use v-show="!isSpeaking" xlink:href="#icon-bobao-no"></use>
          <use v-show="isSpeaking" xlink:href="#icon-bobao"></use>
        </svg>
      </el-icon>
    </el-tooltip>
    <!-- 用户图标 -->
    <el-icon style="font-size: 1.2em">
      <svg class="icon" aria-hidden="true">
        <use xlink:href="#icon-yonghuguanli"></use>
      </svg>
    </el-icon>
    <!-- 顶部个人信息下拉框组件开始 -->
    <el-dropdown  @visible-change="changeDirection" trigger="click">
      <span class="el-dropdown-link">
        <span class="user-name" style="font-size: 1em">
          {{ permissionStore.userInfo?.nickname || user }}
        </span>
        <el-icon  style="font-size: 0.9em; color: rgba(255, 255, 255, 1);">
          <svg class="icon" aria-hidden="true">
            <use v-show="direction" xlink:href="#icon-xiajiantou"></use>
            <use v-show="!direction" xlink:href="#icon-shangjiantou"></use>
          </svg>
        </el-icon>
      </span>
      <template #dropdown>
        <el-dropdown-menu>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-gerenxinxi"></use>
              </svg>
            </el-icon>
            修改个人信息
          </el-dropdown-item>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-xiugaimima"></use>
              </svg>
            </el-icon>
            修改密码
          </el-dropdown-item>
          <el-dropdown-item @click="logout">
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-tcdl"></use>
              </svg>
            </el-icon>
            退出登录
          </el-dropdown-item>
        </el-dropdown-menu>
      </template>
    </el-dropdown>
    <!-- 顶部个人信息下拉框组件结束 -->
  </div>
</template>

<style scoped>
* {
  user-select: none;
}
.bread-crumb {
  flex: 1;
  justify-content: flex-start;
}
.user {
  flex: 1;
}
.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
.example-showcase .el-dropdown-link {
  cursor: pointer;
  color: var(--el-color-primary);
  display: flex;
  align-items: center;
}
.user {
  flex: 1;
  display: flex;
  justify-content: flex-end;
  align-items: center;
  color: rgba(207, 211, 217, 1);
}
.speak {
  font-size: 1.2em;
  cursor: pointer;
  margin-right: 20px;
}
/* 待办备忘录图标 - 紫蓝渐变（与新建待办主题一致） */
.header-todo-icon {
  font-size: 1.2em;
  cursor: pointer;
  margin-right: 16px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 8px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  transition: all 0.25s ease;
  color: #fff;
  filter: drop-shadow(0 1px 2px rgba(0,0,0,0.15));
}
.header-todo-icon:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102,126,234,0.45);
}
.header-todo-wrapper {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

/* 通知铃铛 - 匹配新建通知模态框风格 */
.header-notif-icon {
  font-size: 1.2em;
  cursor: pointer;
  margin-right: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 8px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  transition: all 0.25s ease;
}
.header-notif-icon:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102,126,234,0.45);
}
.notif-bell-icon {
  color: #fff;
  filter: drop-shadow(0 1px 2px rgba(0,0,0,0.15));
}
.header-notif-wrapper {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.header-notif-dot {
  position: absolute;
  top: -2px;
  left: 50%;
  transform: translateX(-50%);
  width: 7px;
  height: 7px;
  background: #f56c6c;
  border-radius: 50%;
  box-shadow: 0 0 3px rgba(245,108,108,0.6);
}
:global(.header-notif-popper) {
  padding: 0 !important;
  border-radius: 20px !important;
  overflow: hidden;
  box-shadow: 0 8px 32px rgba(102,126,234,0.18) !important;
  border: none !important;
}
.recent-notif-list {
  padding: 0;
}
/* popover 头部 - 匹配新建通知模态框 */
.popover-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 20px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.popover-header-icon {
  width: 36px;
  height: 36px;
  background: rgba(255,255,255,0.2);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
  flex-shrink: 0;
}
.popover-header-text {
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.popover-title {
  font-size: 16px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.3px;
}
.popover-subtitle {
  font-size: 12px;
  color: rgba(255,255,255,0.7);
}
/* popover 主体 */
.popover-body {
  background: #f8f9fe;
  padding: 0;
  max-height: 420px;
  overflow: hidden;
}
.recent-notif-empty {
  text-align: center;
  padding: 40px 20px;
  color: #909399;
  font-size: 13px;
}
.recent-notif-item {
  padding: 14px 18px;
  border-bottom: 1px solid #e8eaf0;
  cursor: pointer;
  transition: all 0.2s;
  border-left: 3px solid transparent;
  padding-left: 15px;
}
.recent-notif-item:last-child {
  border-bottom: none;
}
.recent-notif-item:not(:last-child) {
  margin-bottom: 2px;
}
.recent-notif-item:hover {
  background: #edf0ff;
}
.recent-notif-item.new-notif-item {
  background: linear-gradient(90deg, rgba(255, 81, 47, 0.08), rgba(255, 81, 47, 0.03) 70%, transparent);
}
.recent-notif-item.new-notif-item:hover {
  background: #edf0ff;
}
.recent-notif-item-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}
.recent-notif-source-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 1px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 500;
  border: 1px solid;
  line-height: 20px;
}
.source-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  display: inline-block;
}
.recent-notif-time {
  font-size: 11px;
  color: #b0b4c0;
}
.recent-notif-top-right {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.recent-notif-new-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  padding: 3px 7px 2px 7px;
  line-height: 1;
  border-radius: 10px;
  font-size: 10px;
  font-weight: 700;
  font-style: italic;
  letter-spacing: 0.5px;
  color: #fff;
  background: linear-gradient(135deg, #ff512f, #dd2476);
  box-shadow: 0 2px 8px rgba(221, 36, 118, 0.45);
  flex-shrink: 0;
}
.recent-notif-new-badge svg {
  flex-shrink: 0;
  display: block;
}
.recent-notif-item-title {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.5;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  display: flex;
  align-items: baseline;
  gap: 4px;
}
.recent-notif-item-desc {
  font-size: 12px;
  color: #909399;
  line-height: 1.4;
  margin-top: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  display: flex;
  align-items: baseline;
  gap: 4px;
}

/* 通知搜索栏 */
.notif-search-bar {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 14px 20px;
  flex-wrap: wrap;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border-bottom: 2px solid #e8eaf0;
}
.notif-search-bar .el-input__wrapper {
  padding: 1px 8px !important;
  box-shadow: 0 0 0 1px rgba(255,255,255,0.3) inset !important;
  border-radius: 6px;
  height: 28px;
  background: rgba(255,255,255,0.15);
}
.notif-search-bar .el-input__inner {
  height: 28px;
  font-size: 12px;
  color: #fff;
}
.notif-search-bar .el-input__inner::placeholder {
  color: rgba(255,255,255,0.6);
}
.notif-search-bar .el-date-editor .el-range-input {
  background: transparent !important;
  color: #fff !important;
  font-size: 12px;
}
.notif-search-bar .el-date-editor .el-range-separator {
  color: rgba(255,255,255,0.6) !important;
  font-size: 12px;
}
.notif-search-bar .el-date-editor .el-range__icon {
  color: rgba(255,255,255,0.6);
}
.notif-search-bar .el-date-editor .el-range__close-icon {
  color: rgba(255,255,255,0.6);
}
.notif-search-btn, .notif-reset-btn {
  padding: 0 10px;
  height: 28px;
  font-size: 12px;
  border-radius: 6px !important;
  border: 1px solid rgba(255,255,255,0.3);
  background: rgba(255,255,255,0.2);
  color: #fff;
}
.notif-search-btn:hover {
  background: rgba(255,255,255,0.35);
  border-color: rgba(255,255,255,0.5);
}
.notif-reset-btn:hover {
  background: rgba(255,255,255,0.35);
  border-color: rgba(255,255,255,0.5);
}

/* 通知分页 */
.notif-pagination {
  display: flex;
  justify-content: center;
  padding: 12px 20px 20px;
}

/* 通知历史模态框 */
.notif-history-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.notif-history-dialog .el-dialog__header {
  padding: 0;
  margin: 0;
}
.notif-history-dialog .el-dialog__body {
  padding: 0;
}
.notif-history-dialog .el-dialog__footer {
  padding: 0;
}
.notif-history-dialog .notif-dialog-header {
  justify-content: space-between;
}

/* 头部关闭按钮 */
.notif-dialog-close {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: rgba(255,255,255,0.15);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}
.notif-dialog-close:hover {
  background: rgba(255,255,255,0.3);
}

/* 分页紫色主题 */
.notif-pagination .el-pagination.is-background .el-pager li:not(.is-disabled).is-active {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff;
}
.user-name {
  font-size: 15px;
  margin-left: 8px;
  margin-right: 8px;
  color: rgba(207, 211, 217, 1);
}
.user-name:hover {
  color: rgba(255, 255, 255, 1);
}
/* 面包屑组件样式 */
/* 可点击的上级面包屑 */
.el-breadcrumb :deep(.el-breadcrumb__inner)  {
  color: rgba(207, 211, 217, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
.el-breadcrumb__item:hover :deep(.el-breadcrumb__inner)  {
  color: rgba(255, 255, 255, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
/* 不可点击的当前级面包屑 */
.el-breadcrumb__item:last-child :deep(.el-breadcrumb__inner) {
  color: rgba(255, 255, 255, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
/* 不可点击的面包屑分级符号 */
.el-breadcrumb__item :deep(.el-breadcrumb__separator) {
  color: rgba(255, 255, 255, 0.9) !important;
  font-size: 15px;
  font-weight:400 !important;
}
.item {
  margin-top: 10px;
  margin-right: 10px;
}

/* 备忘录待办模态框 */
.memo-todo-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.memo-todo-dialog .el-dialog__header {
  padding: 0;
  margin: 0;
}
.memo-todo-dialog .el-dialog__body {
  padding: 0;
}
.memo-todo-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.memo-todo-header-left {
  display: flex;
  align-items: center;
  gap: 14px;
}
.memo-todo-header-icon {
  width: 40px;
  height: 40px;
  background: rgba(255,255,255,0.2);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
  flex-shrink: 0;
}
.memo-todo-header-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.memo-todo-title-text {
  font-size: 18px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.5px;
}
.memo-todo-close {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: rgba(255,255,255,0.15);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}
.memo-todo-close:hover {
  background: rgba(255,255,255,0.3);
}
.memo-todo-body {
  display: flex;
  height: 560px;
  background: #f8f9fe;
}
/* 左侧边栏 */
.memo-todo-sidebar {
  width: 220px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  border-right: 1px solid #e8eaf0;
  background: #fff;
}
.memo-todo-sidebar-top {
  padding: 12px;
  border-bottom: 1px solid #e8eaf0;
}
.memo-todo-add-btn {
  width: 100%;
  height: 36px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  transition: all 0.25s ease;
}
.memo-todo-add-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102,126,234,0.4);
}
.memo-todo-list {
  flex: 1;
  padding: 6px 0;
}
.memo-todo-list :deep(.el-scrollbar__wrap) {
  overflow-x: hidden;
}
.memo-todo-list :deep(.el-scrollbar__view) {
  height: 100%;
}
.memo-todo-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 0 12px;
  color: #c0c4cc;
  font-size: 13px;
}
.memo-todo-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  cursor: pointer;
  transition: all 0.15s;
  border-left: 3px solid transparent;
}
.memo-todo-item:hover {
  background: #f0f2ff;
}
.memo-todo-item.active {
  background: #eef0ff;
  border-left-color: #667eea;
}
.memo-todo-item-type {
  width: 20px;
  height: 20px;
  border-radius: 4px;
  font-size: 10px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: #fff;
}
.memo-todo-item-type.type-once {
  background: #e6a23c;
}
.memo-todo-item-type.type-recurring {
  background: #667eea;
}
.memo-todo-item-title {
  font-size: 13px;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}
.memo-todo-item-title.title-reminded {
  color: #909399;
  text-decoration: line-through;
}
.memo-todo-reminded-badge {
  flex-shrink: 0;
  font-size: 10px;
  color: #e6a23c;
  background: #fdf6ec;
  padding: 0 6px;
  border-radius: 4px;
  line-height: 18px;
  font-weight: 500;
  margin-left: 4px;
}
/* 右侧内容区 */
.memo-todo-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 20px 24px;
}
.memo-todo-content .memo-todo-content-scrollbar {
  flex: 1;
  height: 0;
  min-height: 0;
}
.memo-todo-content .memo-todo-content-scrollbar :deep(.el-scrollbar__wrap) {
  overflow-x: hidden;
}
.memo-todo-content .memo-todo-content-scrollbar :deep(.el-scrollbar__view) {
  height: 100%;
}
.memo-todo-content-header {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-bottom: 8px;
}
.memo-todo-content-title {
  font-size: 16px;
  font-weight: 700;
  color: #303133;
  line-height: 1.5;
  flex: 1;
  word-break: break-word;
}
.memo-todo-content-meta {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 12px;
  flex-wrap: wrap;
}
.memo-todo-content-text {
  font-size: 14px;
  color: #303133;
  line-height: 1.8;
  word-break: break-word;
}
.memo-todo-empty-content {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 新建待办对话框样式 */
.todo-create-body {
  padding: 20px 24px;
  background: #f8f9fe;
}
.todo-create-section {
  margin-bottom: 18px;
}
.todo-create-section-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 8px;
}
.todo-create-type-selector {
  display: flex;
  gap: 10px;
}
.todo-create-type-card {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 10px;
  border: 2px solid #e4e7f0;
  cursor: pointer;
  transition: all 0.25s ease;
  background: #fff;
  color: #606266;
  font-size: 13px;
  font-weight: 500;
}
.todo-create-type-card:hover {
  border-color: #667eea;
  background: #f5f6ff;
}
.todo-create-type-card.active {
  border-color: #667eea;
  background: #eef0ff;
  color: #667eea;
}
.todo-create-reminder-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.todo-create-recurring-row {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}
.todo-create-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 12px 24px;
  border-top: 1px solid #e8eaf0;
  background: #f8f9fe;
}
.todo-create-btn-cancel {
  border-radius: 8px !important;
}
.todo-create-btn-save {
  border-radius: 8px !important;
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  border: none !important;
  color: #fff !important;
  font-weight: 500;
}
.todo-create-btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102,126,234,0.4) !important;
}

/* 右键菜单 - 紫蓝渐变主题 */
.memo-todo-context-menu {
  position: fixed;
  z-index: 9999;
  background: #fff;
  border-radius: 12px;
  border: 1px solid rgba(102,126,234,0.15);
  box-shadow: 0 6px 24px rgba(102,126,234,0.18), 0 2px 8px rgba(0,0,0,0.08);
  padding: 6px 0;
  min-width: 130px;
  overflow: hidden;
  animation: memoContextMenuIn 0.15s ease;
}
@keyframes memoContextMenuIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}
.memo-todo-context-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 18px;
  font-size: 13px;
  font-weight: 500;
  color: #303133;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
  border-left: 3px solid transparent;
  position: relative;
}
.memo-todo-context-item svg {
  flex-shrink: 0;
  width: 15px;
  height: 15px;
  color: #909399;
  transition: color 0.2s;
}
.memo-todo-context-item:hover {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: #fff;
  border-left-color: rgba(255,255,255,0.6);
}
.memo-todo-context-item:hover svg {
  color: #fff;
}
</style>

<style>
/* 非 scoped 样式：覆盖 el-dialog Teleport 导致的 scoped CSS 失效问题 */
.notif-history-dialog .notif-dialog-header {
  justify-content: space-between !important;
}
.notif-pagination .el-pagination.is-background .el-pager li:not(.is-disabled).is-active {
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  border: none !important;
  color: #fff !important;
}
.notif-dialog-close {
  position: absolute;
  top: 16px;
  right: 16px;
  z-index: 10;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  cursor: pointer;
  display: flex !important;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}
.notif-dialog-close:hover svg {
  opacity: 0.7;
}

/* 搜索栏紫色主题 */
.notif-history-dialog .notif-search-bar {
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  padding: 14px 20px !important;
  border-bottom: 2px solid #e8eaf0 !important;
}
.notif-history-dialog .notif-search-bar .el-input__wrapper {
  background: rgba(255,255,255,0.15) !important;
  box-shadow: 0 0 0 1px rgba(255,255,255,0.3) inset !important;
}
.notif-history-dialog .notif-search-bar .el-input__inner {
  color: #fff !important;
}
.notif-history-dialog .notif-search-bar .el-input__inner::placeholder {
  color: rgba(255,255,255,0.6) !important;
}
.notif-history-dialog .notif-search-bar .el-date-editor .el-range-input {
  background: transparent !important;
  color: #fff !important;
}
.notif-history-dialog .notif-search-bar .el-date-editor .el-range-separator {
  color: rgba(255,255,255,0.6) !important;
}
.notif-history-dialog .notif-search-bar .el-date-editor .el-range__icon,
.notif-history-dialog .notif-search-bar .el-date-editor .el-range__close-icon {
  color: rgba(255,255,255,0.6) !important;
}
.notif-history-dialog .notif-search-btn,
.notif-history-dialog .notif-reset-btn {
  border: 1px solid rgba(255,255,255,0.3) !important;
  background: rgba(255,255,255,0.2) !important;
  color: #fff !important;
}
.notif-history-dialog .notif-search-btn:hover,
.notif-history-dialog .notif-reset-btn:hover {
  background: rgba(255,255,255,0.35) !important;
  border-color: rgba(255,255,255,0.5) !important;
}

/* 通知列表与搜索栏分隔 */
.notif-history-dialog .el-scrollbar {
  border-top: none;
}
.notif-history-dialog .recent-notif-empty {
  padding: 40px 20px !important;
}

/* 分页区域 */
.notif-history-dialog .notif-pagination {
  display: flex;
  justify-content: center;
  padding: 12px 20px 20px !important;
}

/* 备忘录待办模态框 - 非 scoped（覆盖 Teleport） */
.memo-todo-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.memo-todo-dialog .el-dialog__header {
  padding: 0 !important;
  margin: 0 !important;
}
.memo-todo-dialog .el-dialog__body {
  padding: 0 !important;
}
.memo-todo-close {
  position: absolute;
  top: 18px;
  right: 18px;
  z-index: 10;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  cursor: pointer;
  display: flex !important;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}
.memo-todo-close:hover svg {
  opacity: 0.7;
}

/* 新建待办模态框 - 非 scoped（覆盖 Teleport） */
.todo-create-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.todo-create-dialog .el-dialog__header {
  padding: 0 !important;
  margin: 0 !important;
}
.todo-create-dialog .el-dialog__body {
  padding: 0 !important;
}
.todo-create-dialog .el-dialog__footer {
  padding: 0 !important;
}
.todo-create-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.todo-create-header-left {
  display: flex;
  align-items: center;
  gap: 14px;
}
.todo-create-header-icon {
  width: 40px;
  height: 40px;
  background: rgba(255,255,255,0.2);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
  flex-shrink: 0;
}
.todo-create-header-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.todo-create-title-text {
  font-size: 18px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.5px;
}
.todo-create-close {
  position: absolute;
  top: 18px;
  right: 18px;
  z-index: 10;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  cursor: pointer;
  display: flex !important;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}
.todo-create-close:hover svg {
  opacity: 0.7;
}

/* 删除/停用确认弹框 - 紫蓝渐变主题（ElMessageBox 渲染在 body 下，需非 scoped） */
.todo-header-confirm-box {
  border-radius: 16px !important;
  padding: 0 !important;
  overflow: hidden;
}
.todo-header-confirm-box .el-message-box__header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 18px 24px;
  margin: 0;
}
.todo-header-confirm-box .el-message-box__title {
  color: #fff !important;
  font-size: 16px;
  font-weight: 600;
}
.todo-header-confirm-box .el-message-box__close {
  color: rgba(255,255,255,0.75) !important;
}
.todo-header-confirm-box .el-message-box__close:hover {
  color: #fff !important;
}
.todo-header-confirm-box .el-message-box__content {
  padding: 24px;
  background: #f8f9fe;
}
.todo-header-confirm-box .el-message-box__message {
  font-size: 14px;
  color: #303133;
  line-height: 1.6;
}
.todo-header-confirm-box .el-message-box__btns {
  padding: 16px 24px;
  background: #f8f9fe;
  border-top: 1px solid #e8eaf0;
  display: flex;
  justify-content: flex-end;
}
.todo-header-confirm-box .el-message-box__btns .el-button--primary {
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
.todo-header-confirm-box .el-message-box__btns .el-button--primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4) !important;
}
.todo-header-confirm-box .el-message-box__btns .el-button--default {
  border-radius: 10px !important;
  height: 36px;
  padding: 0 20px;
  font-size: 13px;
  border: 1px solid #e4e7f0;
  transition: all 0.25s ease;
}

/* Header 图标 hover 提示 - 紫蓝渐变主题 */
.header-icon-tooltip {
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
  border: none !important;
  color: #fff !important;
  font-size: 12px;
  font-weight: 500;
  padding: 6px 12px;
  border-radius: 6px !important;
  box-shadow: 0 4px 14px rgba(102,126,234,0.3) !important;
}
.header-icon-tooltip .el-popper__arrow::before {
  background: linear-gradient(135deg, #667eea, #764ba2) !important;
}
</style>
