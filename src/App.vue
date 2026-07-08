<script setup>
import { getOrderData } from '@/api/homePage.js'

/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：应用根组件
 * @date： 2026-01-28 09:30:17
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:30:17
 */
import IndexPage from '@/components/IndexPage.vue'
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { itsmTodoData } from '@/utils/homePageData.js'
import { isSsoLogin, messageInstance, refresh, stopSpeaking, user } from '@/utils/publicData.js'
import { WorkOrderDataModel } from '@/utils/publicDataTools.js'
import { ElMessage, ElMessageBox, ElNotification, ElScrollbar } from 'element-plus'
import { computed, onBeforeUnmount, onMounted, watch, h } from 'vue'
import { useRoute } from 'vue-router'
import { useNotificationSSE } from '@/utils/useNotificationSSE'
import axios from 'axios'
import { RBAC_IP } from '@/utils/dutyPageData.js'

// 获取store实例
const authStore = useAuthStore()
const alarmStore = useSpeakStore()
// 获取当前路由实例
const route = useRoute()

// SSE 通知推送（全局，实时接收管理员一键提醒等服务端推送）
const sseUsername = computed(() => sessionStorage.getItem('user') || '')
const { connect: connectSSE, disconnect: disconnectSSE } = useNotificationSSE(sseUsername)

// 检查当前用户是否为甲方，只有 personnel_type=4 需要连接 SSE
const checkServiceDeskAndConnect = async () => {
  const username = sessionStorage.getItem('user')
  if (!username) return
  try {
    const res = await axios.get(`${RBAC_IP.value}/checkServiceDesk`, {
      params: { username }
    })
    if (res.data?.isServiceDesk) {
      connectSSE()
    } else {
      console.log(`[SSE] 用户 ${username} 非甲方，跳过 SSE 连接`)
    }
  } catch (e) {
    console.warn('[SSE] 检查服务台身份失败，默认不连接', e)
  }
}

const isAuthenticated = computed(() => authStore.isAuthenticated)
// 全局定时器
let searchTimer = null
let todoCheckTimer = null
let unwatch = null

// 存储所有待办项ID的Set
const TODO_STORAGE_KEY = 'itsm_todo_ids_cache'

// 从 localStorage 加载已存在的待办ID
const loadTodoIdsFromStorage = () => {
  try {
    const stored = localStorage.getItem(TODO_STORAGE_KEY)
    if (stored) {
      const ids = JSON.parse(stored)
      return new Set(ids)
    }
  } catch (error) {
    console.error('加载待办ID缓存失败:', error)
  }
  return new Set()
}
// 全局待办ID集合
const globalTodoIdSet = loadTodoIdsFromStorage()
// 保存待办ID到 localStorage
const saveTodoIdsToStorage = () => {
  try {
    const idsArray = Array.from(globalTodoIdSet)
    localStorage.setItem(TODO_STORAGE_KEY, JSON.stringify(idsArray))
  } catch (error) {
    console.error('保存待办ID缓存失败:', error)
  }
}
// 检查待办并发送通知
const checkAndNotifyTodos = async () => {
  const username = sessionStorage.getItem('user')
  if (!username) return

  try {
    const response = await getOrderData(username)

    if (response.status === 'success') {
      // 收集接口返回的所有待办项ID
      const newTodoIds = new Set()

      // 遍历所有类型的待办项，收集ID
      const allTodos = [
        ...response.publish.map((item) => ({ ...item, type: '发布' })),
        ...response.event.map((item) => ({ ...item, type: '事件' })),
        ...response.change.map((item) => ({ ...item, type: '变更' })),
        ...response.request.map((item) => ({ ...item, type: '请求' })),
        ...response.problem.map((item) => ({ ...item, type: '问题' })),
      ]

      // 将新返回的ID添加到集合中
      allTodos.forEach((todo) => {
        newTodoIds.add(todo.id)
      })

      // 找出新增的待办项（在新集合中但不在旧集合中）
      const newTodos = allTodos.filter((todo) => !globalTodoIdSet.has(todo.id))

      // 找出已移除的待办项（在旧集合中但不在新集合中）
      const removedIds = [...globalTodoIdSet].filter((id) => !newTodoIds.has(id))

      // 如果有新增的待办项，发送通知
      if (newTodos.length > 0) {
        // 按类型分组统计
        const typeGroups = {}
        newTodos.forEach((todo) => {
          if (!typeGroups[todo.type]) {
            typeGroups[todo.type] = []
          }
          typeGroups[todo.type].push(todo.id)
        })

        const typeColors = {
          发布: { bg: '#ecf5ff', border: '#409eff', text: '#409eff' },
          事件: { bg: '#f0f9eb', border: '#67c23a', text: '#67c23a' },
          变更: { bg: '#fdf6ec', border: '#e6a23c', text: '#e6a23c' },
          请求: { bg: '#f3e5f5', border: '#9c27b0', text: '#9c27b0' },
          问题: { bg: '#fef0f0', border: '#f56c6c', text: '#f56c6c' },
        }

        // 使用 VNode 渲染通知内容
        const notificationContent = h('div', { class: 'notification-content' }, [
          // 标题部分
          h('div', { class: 'notification-header' }, [
            h('span', null, '🎯 共有 '),
            h(
              'span',
              {
                style: { color: '#409eff', fontSize: '18px', fontWeight: '700' },
              },
              newTodos.length,
            ),
            h('span', null, ' 条新待办'),
          ]),

          // 滚动列表部分 - 使用 el-scrollbar
          h(
            ElScrollbar,
            { maxHeight: '600px' },
            {
              default: () =>
                h(
                  'div',
                  { class: 'notification-list' },
                  Object.entries(typeGroups).map(([type, ids]) => {
                    const colors = typeColors[type] || { bg: '#f4f4f5', border: '#909399', text: '#909399' }
                    return h(
                      'div',
                      {
                        class: 'type-card',
                        style: {
                          marginBottom: '10px',
                          padding: '10px 12px',
                          background: colors.bg,
                          borderLeft: `3px solid ${colors.border}`,
                          borderRadius: '4px',
                        },
                      },
                      [
                        // 类型标题
                        h(
                          'div',
                          {
                            style: {
                              fontSize: '12px',
                              color: colors.text,
                              fontWeight: '600',
                              marginBottom: '6px',
                            },
                          },
                          type,
                        ),

                        // ID 列表
                        h(
                          'div',
                          {
                            style: {
                              display: 'flex',
                              flexDirection: 'column',
                              gap: '4px',
                            },
                          },
                          ids.map((id) =>
                            h(
                              'div',
                              {
                                style: {
                                  fontSize: '13px',
                                  color: '#606266',
                                  paddingLeft: '8px',
                                  lineHeight: '1.6',
                                },
                              },
                              `• ${id}`,
                            ),
                          ),
                        ),
                      ],
                    )
                  }),
                ),
            },
          ),
        ])

        const Notification = ElNotification({
          title: '🔔 新待办提醒',
          message: notificationContent,
          type: 'primary',
          duration: 2000,
          position: 'top-right',
          offset: 60,
          customClass: 'custom-todo-notification',
          showClose: false,
          onClick: () => {
            // 手动触发自定义关闭动画
            const element = document.querySelector('.custom-todo-notification')
            if (element) {
              // 添加关闭动画类
              element.classList.add('notification-closing')
              // 等待动画完成后真正关闭
              setTimeout(() => {
                Notification.close()
              }, 400)
            } else {
              Notification.close()
            }
          },
          onClose: () => {
            // 手动触发自定义关闭动画
            const element = document.querySelector('.custom-todo-notification')
            if (element) {
              // 添加关闭动画类
              element.classList.add('notification-closing')
              // 等待动画完成后真正关闭
              setTimeout(() => {
                Notification.close()
              }, 400)
            }
          },
        })
      }

      // 更新Set：删除已移除的ID，添加新增的ID
      removedIds.forEach((id) => globalTodoIdSet.delete(id))
      newTodoIds.forEach((id) => globalTodoIdSet.add(id))

      // 持久化到 localStorage
      saveTodoIdsToStorage()
      itsmTodoData.value.publish = response.publish
      itsmTodoData.value.event = response.event
      itsmTodoData.value.change = response.change
      itsmTodoData.value.request = response.request
      itsmTodoData.value.problem = response.problem
    }
  } catch (error) {
    console.error('检查待办失败:', error)
  }
}
// 启动待办检查定时器
const startTodoCheckTimer = async (isFirstLogin = false) => {
  if (todoCheckTimer) {
    clearInterval(todoCheckTimer)
  }

  // 不再在这里检查待办，统一由 HomePage 组件挂载后触发
  // 这样可以确保用户已经进入首页界面
  console.log('待办检查定时器已启动，等待 HomePage 触发首次检查')

  // 每30秒检查一次
  todoCheckTimer = setInterval(checkAndNotifyTodos, 30000)
}

// 停止待办检查定时器
const stopTodoCheckTimer = () => {
  if (todoCheckTimer) {
    clearInterval(todoCheckTimer)
    todoCheckTimer = null
  }
}
// 监听 HomePage 发出的待办检查事件
const handleCheckTodos = () => {
  console.log('收到待办检查事件，执行检查')
  checkAndNotifyTodos()
}

// lunar-javascript 库更新提示（每年12月提醒管理员）
const codeStyle = {
  background: '#e3e8ef',
  padding: '1px 6px',
  borderRadius: '4px',
  fontFamily: 'monospace',
  fontSize: '13px',
  color: '#476582',
}
const checkLunarUpdatePrompt = () => {
  const now = new Date()
  // 12月（getMonth() 返回 11）
  if (now.getMonth() !== 11) return
  // 只提示一次
  if (sessionStorage.getItem('lunar_update_prompted')) return

  const userType = sessionStorage.getItem('userType')
  if (userType !== 'admin') return

  const nextYear = now.getFullYear() + 1
  sessionStorage.setItem('lunar_update_prompted', 'true')

  ElMessageBox.alert(
    h('div', { style: 'line-height:1.8;color:#606266;font-size:14px' }, [
      h('p', { style: 'margin:0 0 12px 0' }, [
        '请尽快更新 ', h('code', { style: codeStyle }, 'lunar-javascript'),
        ' 库，获取',h('strong', { style: 'color:#e6a23c' }, `${nextYear}年`),'法定节假日数据。'
      ]),
      h('p', { style: 'margin:0 0 8px 0;color:#909399;font-size:13px' },
        '否则会影响值班管理中自动识别法定节假日！'
      ),
      h('div', { style: 'margin-top:14px;padding:12px 16px;background:#f8f9fa;border-radius:8px;border:1px solid #ebeef5' }, [
        h('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:6px;color:#909399;font-size:12px' }, [
          h('span', null, '🔧'),
          h('span', null, '更新命令'),
        ]),
        h('div', { style: 'display:flex;align-items:center;gap:10px' }, [
          h('code', { style: 'flex:1;padding:8px 12px;background:#1e2a3a;color:#a8c8e8;border-radius:6px;font-family:Consolas,monospace;font-size:13px;user-select:all;cursor:text;letter-spacing:0.3px;white-space:nowrap' },
            'npm install lunar-javascript@latest'
          ),
        ]),
      ]),
    ]),
    '节假日库更新提醒',
    {
      confirmButtonText: '知道了',
      type: 'warning',
      customClass: 'custom-message-box',
      showClose: true,
      closeOnClickModal: true,
    }
  )
}

// 在 onMounted 中添加 watch, 每60s 刷新一次数据并播报告警信息
onMounted(() => {
  // 初始化用户信息
  if (sessionStorage.getItem('user')) {
    user.value = sessionStorage.getItem('user')
    console.log('用户信息：', user.value)
    // 初始化工单导出接口用户名
    WorkOrderDataModel.value.username = user.value
  }

  window.addEventListener('check-todos', handleCheckTodos)

  unwatch = watch(
    () => authStore.isAuthenticated,
    (newValue) => {
      if (newValue) {
        // 先判断当前用户是否为运维服务台人员（只有 personnel_type=5 才需要 SSE）
        checkServiceDeskAndConnect()
        // 检查是否是登录重定向，如果不是才启动定时器
        const wasLoginRedirect = sessionStorage.getItem('isLoginRedirect')
        // 检测页面是否是通过刷新加载的
        const navigationEntries = performance.getEntriesByType('navigation')
        const isRefresh = navigationEntries.length > 0 && navigationEntries[0].type === 'reload'
        // 判断当前是否在告警管理页面（包括告警管理的所有子路由）
        // 使用更可靠的方式获取路由状态
        const isAlarmPage = window.location.pathname.startsWith('/alarmManagement')

        if (isRefresh && !wasLoginRedirect && isAlarmPage) {
          ElMessageBox.confirm('页面刷新会终止语音播报，请点击开启或关闭语音播报！', '提示', {
            showClose: false,
            confirmButtonText: '开启',
            cancelButtonText: '关闭',
            type: 'success',
            customClass: 'custom-message-box',
          })
            .then(async () => {
              stopSpeaking.value = false
              // 如果已有提示框在显示，先关闭它
              if (messageInstance.value) {
                // 关闭所有消息
                ElMessage.closeAll()
                // 等待消息关闭动画完成
                await new Promise((resolve) => setTimeout(resolve, 0))
              }
              messageInstance.value = ElMessage.success({
                message: '已开启语音播报',
                duration: 1000,
                onClose: () => {
                  messageInstance.value = null
                },
              })
            })
            .catch(() => {
              stopSpeaking.value = true
            })
        }
        // 判断是否是首次登录（在清除标记之前判断）
        const isFirstLogin = !isRefresh && wasLoginRedirect
        console.log('isRefresh：', isRefresh)
        console.log('wasLoginRedirect：', wasLoginRedirect)
        console.log('是否是首次登录：', isFirstLogin)
        // 启动全局待办检查定时器
        startTodoCheckTimer(isFirstLogin)
        // 这是登录重定向，清除标记但不启动定时器
        sessionStorage.removeItem('isLoginRedirect')
        // 创建一个函数来重启定时器
        const restartTimer = () => {
          if (searchTimer) {
            clearInterval(searchTimer)
          }
          searchTimer = setInterval(() => {
            refresh()
          }, 60000) // 60秒刷新一次数据
        }
        // 首次启动定时器
        restartTimer()

        // 监听手动刷新事件，重置定时器
        // 需要在全局范围内暴露重置函数
        window.resetRefreshTimer = restartTimer
      } else {
        // 用户登出时断开 SSE
        disconnectSSE()
        if (searchTimer) {
          clearInterval(searchTimer)
          searchTimer = null
        }
        // 停止待办检查定时器
        stopTodoCheckTimer()
        window.resetRefreshTimer = null
      }
    },
    { immediate: true }, //
  )
  // 初始化已播报队列
  alarmStore.initAlreadySpeakQueue()
  // 添加页面卸载事件监听
  window.addEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())

  // 首页加载完成后触发 lunar-javascript 更新提示
  window.addEventListener('check-lunar-update', checkLunarUpdatePrompt)
})

onBeforeUnmount(() => {
  // 移除页面卸载事件监听
  window.removeEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
  // 移除待办检查事件监听
  window.removeEventListener('check-todos', handleCheckTodos)
  // 移除 lunar 更新提示事件监听
  window.removeEventListener('check-lunar-update', checkLunarUpdatePrompt)
  // 关闭页面时清除标记
  if (isSsoLogin.value) {
    authStore.logoutInfoClear()
  }
  // 在组件卸载时取消监听
  if (unwatch) {
    unwatch()
  }
  // 清除全局定时器
  if (searchTimer) {
    clearInterval(searchTimer)
  }
  // 停止待办检查定时器
  stopTodoCheckTimer()
  // 断开 SSE 连接
  disconnectSSE()
  alarmStore.persistAlreadySpeakQueue()
})
</script>

<template>
  <div id="app">
    <router-view v-if="route.name === 'NotFound'" name="NotFound"></router-view>
    <router-view v-else-if="!isAuthenticated || route.name === 'LoginPage'" name="LoginPage"></router-view>
    <IndexPage v-else></IndexPage>
  </div>
</template>

<style>
/* 因element组件高度默认是内容高度，在此设置高度为页面高度 */
html,
body {
  height: 100%;
  margin: 0;
  padding: 0;
  font-family: 'Helvetica Neue', Arial, sans-serif;
  box-sizing: border-box;
}
#app {
  height: 100%;
}
/* ElMessage字体大小样式 */
.el-message {
  font-size: 16px !important;
}

.el-message__content {
  font-size: 16px !important;
}
.custom-message-box {
  margin-top: -10% !important;
  border-radius: 12px !important;
  width: 520px !important;
  overflow: hidden;
}
.custom-message-box .el-message-box__header {
  padding: 18px 24px 8px !important;
  border-bottom: 1px solid #f0f0f0 !important;
}
.custom-message-box .el-message-box__title {
  display: flex !important;
  align-items: center !important;
}
.custom-message-box .el-message-box__content {
  padding: 20px 24px !important;
}
.custom-message-box .el-message-box__btns {
  padding: 12px 24px 18px !important;
  border-top: 1px solid #f0f0f0 !important;
  display: flex;
  justify-content: flex-end;
}
.custom-message-box .el-message-box__btns .el-button--primary {
  border-radius: 8px !important;
  padding: 8px 28px !important;
  font-size: 13px !important;
  font-weight: 500 !important;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
  border: none !important;
  transition: all 0.25s !important;
}
.custom-message-box .el-message-box__btns .el-button--primary:hover {
  box-shadow: 0 4px 14px rgba(102, 126, 234, 0.4) !important;
  transform: translateY(-1px);
}
.custom-message-box .el-icon.el-message-box__status.el-icon--warning {
  display: none !important;
}
.custom-message-box .el-message-box__status {
  display: none !important;
}

/* 自定义待办通知样式 */
.custom-todo-notification {
  background: linear-gradient(135deg, rgba(240, 244, 255, 0.2) 0%, rgba(232, 238, 255, 0.95) 100%) !important;
  border: 2px solid rgba(165, 179, 237, 1) !important;
  box-shadow:
    0 12px 32px rgba(102, 126, 234, 0.35),
    0 8px 16px rgba(0, 0, 0, 0.1) !important;
  border-radius: 12px !important;
  padding: 16px 20px !important;
  width: 300px !important;
  user-select: none;
  /* 进入动画 */
  animation: slideInRight 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  /* 确保过渡平滑 */
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1) !important;
  backdrop-filter: blur(5px);
  -webkit-backdrop-filter: blur(10px);
}

/* 进入动画：从右侧滑入 */
@keyframes slideInRight {
  from {
    opacity: 0;
    transform: translateX(100%);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

/* 关闭时的动画状态 */
.custom-todo-notification.notification-closing {
  opacity: 0 !important;
  transform: translateX(100%) !important;
  pointer-events: none !important;
}

.custom-todo-notification .el-notification__title {
  font-size: 16px !important;
  font-weight: 700 !important;
  color: #303133 !important;
  margin-bottom: 8px !important;
  padding-bottom: 12px !important;
  border-bottom: 2px solid rgba(102, 126, 234, 0.2) !important;
}

.custom-todo-notification .el-notification__content {
  padding: 0 !important;
}

/* 通知内容容器 */
.custom-todo-notification .notification-content {
  padding: 8px 0;
}

.custom-todo-notification .notification-header {
  margin-bottom: 12px;
  font-size: 14px;
  color: #303133;
  font-weight: 600;
}

/* el-scrollbar 样式定制 */
.custom-todo-notification .el-scrollbar__wrap {
  overflow-x: hidden;
}

.custom-todo-notification .el-scrollbar__bar.is-vertical {
  width: 6px !important;
  right: 2px !important;
}

.custom-todo-notification .el-scrollbar__thumb {
  background-color: rgba(102, 126, 234, 0.4) !important;
  border-radius: 3px !important;
  transition: background-color 0.3s !important;
}

.custom-todo-notification .el-scrollbar__thumb:hover {
  background-color: rgba(102, 126, 234, 0.6) !important;
}

.custom-todo-notification .el-scrollbar__thumb:active {
  background-color: rgba(102, 126, 234, 0.8) !important;
}

/* 类型卡片 */
.custom-todo-notification .type-card {
  margin-bottom: 10px;
  padding: 10px 12px;
  border-left: 3px solid;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.7) !important;
  backdrop-filter: blur(10px);
}

.custom-todo-notification .type-title {
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 6px;
}

.custom-todo-notification .id-list {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.custom-todo-notification .id-item {
  font-size: 13px;
  color: #606266;
  padding-left: 8px;
  line-height: 1.6;
}
</style>
