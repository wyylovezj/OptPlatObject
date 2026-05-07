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
import { computed, onBeforeUnmount, onMounted, watch, h, } from 'vue'
import { useRoute } from 'vue-router'

// 获取store实例
const authStore = useAuthStore()
const alarmStore = useSpeakStore()
// 获取当前路由实例
const route = useRoute()

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

  if (isFirstLogin) {
    // 首次登录：延迟执行，等待页面完全加载
    setTimeout(() => {
      checkAndNotifyTodos()
    }, 1000)
  } else {
    // 页面刷新或定时触发：立即执行检查
    checkAndNotifyTodos()
  }

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

// 在 onMounted 中添加 watch, 每60s 刷新一次数据并播报告警信息
onMounted(() => {
  // 初始化用户信息
  if (sessionStorage.getItem('user')) {
    user.value = sessionStorage.getItem('user')
    console.log('用户信息：', user.value)
    // 初始化工单导出接口用户名
    WorkOrderDataModel.value.username = user.value
  }
  unwatch = watch(
    () => authStore.isAuthenticated,
    (newValue) => {
      if (newValue) {
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
      } else if (searchTimer) {
        clearInterval(searchTimer)
        // 停止待办检查定时器
        stopTodoCheckTimer()
        searchTimer = null
        window.resetRefreshTimer = null
      }
    },
    { immediate: true }, //
  )
  // 初始化已播报队列
  alarmStore.initAlreadySpeakQueue()
  // 添加页面卸载事件监听
  window.addEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
})

onBeforeUnmount(() => {
  // 移除页面卸载事件监听
  window.removeEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
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
  margin-top: -15% !important;
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
