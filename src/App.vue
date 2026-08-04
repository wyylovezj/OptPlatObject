<script setup>
import { getOrderData } from '@/api/homePage.js'
import { getTodoReminders } from '@/api/todoApi.js'

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
import { computed, onBeforeUnmount, onMounted, watch, h, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useNotificationSSE } from '@/utils/useNotificationSSE'
import { marked } from 'marked'

// 获取store实例
const authStore = useAuthStore()
const alarmStore = useSpeakStore()
// 获取当前路由实例
const route = useRoute()

// SSE 通知推送（全局，实时接收管理员一键提醒等服务端推送）
const sseUsername = computed(() => sessionStorage.getItem('user') || '')
const { connect: connectSSE, disconnect: disconnectSSE, currentSystemNotification, dismissSystemNotification } = useNotificationSSE(sseUsername)

// 系统通知模态框控制
const systemNotifVisible = ref(false)
const systemNotifContent = ref('')
const notifTypeStyles = {
  success: { c: '#67c23a', label: '普通通知' },
  warning: { c: '#e6a23c', label: '重要通知' },
  error: { c: '#f56c6c', label: '紧急通知' },
  info: { c: '#667eea', label: '系统通知' },
}
const currentTypeStyle = computed(() => notifTypeStyles[currentSystemNotification.value?.type || 'info'] || notifTypeStyles.info)
watch(currentSystemNotification, (val) => {
  if (val) {
    // marked v18 中 parse() 返回 Promise，使用同步方式兼容
    try {
      const parsed = marked.parse(val.content || '', { async: false })
      if (parsed instanceof Promise) {
        parsed.then(html => { systemNotifContent.value = html })
      } else {
        systemNotifContent.value = parsed
      }
    } catch (e) {
      systemNotifContent.value = val.content || ''
      console.warn('Markdown 解析失败，使用原始内容：', e)
    }
    systemNotifVisible.value = true
  }
})

// 从 HeaderBar 铃铛历史列表打开系统通知
const handleShowSystemNotification = (event) => {
  const { title, content, type, timestamp, publishTime } = event.detail
  currentSystemNotification.value = { title, content, type, timestamp: publishTime || timestamp || '' }
}

// 所有登录用户都连接 SSE，用于接收系统通知等实时消息
const connectSSEForUser = () => {
  const username = sessionStorage.getItem('user')
  if (!username) return
  connectSSE()
  console.log(`[SSE] 用户 ${username} 已连接 SSE`)
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
// ======== 待办备忘录提醒检查 ========
let todoRemindTimer = null
// sessionStorage 持久化去重 key = `{todoId}_{reminderTime|recurringTime}` → 时间戳
// 冷却期130秒（略大于后端2分钟窗口），防止页面刷新后重复弹窗
// 时间变了 key 就变，修改待办后可以重新触发
const STORAGE_KEY = 'todo_reminded_keys'
const REMINDER_COOLDOWN_MS = 180000

const loadRemindedKeys = () => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    return stored ? new Map(Object.entries(JSON.parse(stored))) : new Map()
  } catch { return new Map() }
}
const saveRemindedKeys = (map) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(Object.fromEntries(map)))
  } catch {}
}

const makeRemindKey = (todo) =>
  `${todo.id}_${todo.reminderTime || todo.recurringTime || ''}`

const checkTodoReminders = async () => {
  const username = sessionStorage.getItem('user')
  if (!username) return
  try {
    const res = await getTodoReminders(username)
    if (res.code === 200 && res.data && res.data.length > 0) {
      const now = Date.now()
      const remindedKeys = loadRemindedKeys()
      let changed = false

      // 清理过期记录
      for (const [key, ts] of remindedKeys) {
        if (now - ts > REMINDER_COOLDOWN_MS) {
          remindedKeys.delete(key)
          changed = true
        }
      }

      // 收集新到期的待办（冷却期内不再提醒）
      const newlyAdded = []
      for (const todo of res.data) {
        const key = makeRemindKey(todo)
        if (!remindedKeys.has(key)) {
          remindedKeys.set(key, now)
          newlyAdded.push(todo)
          changed = true
        }
      }

      if (changed) saveRemindedKeys(remindedKeys)
      // 有新到期的待办，合并为一条通知展示（避免多通知互相覆盖）
      if (newlyAdded.length > 0) {
        const isMultiple = newlyAdded.length > 1
        const titleText = isMultiple
          ? `📝 ${newlyAdded.length} 条备忘录待办`
          : '📝 备忘录待办'

        // 构建待办周期/时间标签
        const getRecurringLabel = (t) => {
          if (t.todoType !== 1 || t.recurringPattern === null || t.recurringPattern === undefined) return null
          const patterns = ['每月', '每周', '每日']
          let label = patterns[t.recurringPattern] || ''
          if (t.recurringPattern === 0 && t.recurringDay) label += `${t.recurringDay}号`
          else if (t.recurringPattern === 1 && t.recurringDay) {
            label += (['周一','周二','周三','周四','周五','周六','周日'][t.recurringDay - 1] || '')
          }
          if (t.recurringTime) label += ` ${t.recurringTime}`
          return label
        }

        // 卡片式待办列表
        const todoCards = newlyAdded.map((t, i) => {
          const isRecurring = t.todoType === 1
          const typeLabel = isRecurring ? '周期性' : '一次性'
          const typeColor = isRecurring ? '#667eea' : '#e6a23c'
          const recurringLabel = getRecurringLabel(t)
          const reminderTime = t.reminderTime ? t.reminderTime.substring(5, 16) : null
          return h('div', {
            class: 'memo-remind-todo-card',
            style: `margin-bottom:${i < newlyAdded.length - 1 ? '10px' : '0'};border-radius:8px;background:#f5f7fa;padding:12px 14px;border-left:3px solid ${typeColor};cursor:pointer;transition:box-shadow 0.2s,transform 0.15s;`,
            onClick: () => {
              const cards = document.querySelectorAll('.memo-remind-todo-card')
              if (cards[i]) {
                const wrap = cards[i].closest('.el-scrollbar__wrap')
                if (wrap) {
                  const offset = cards[i].offsetTop - wrap.offsetTop - wrap.clientHeight / 2 + cards[i].offsetHeight / 2
                  wrap.scrollTo({ top: offset, behavior: 'smooth' })
                }
              }
            }
          }, [
            h('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:6px;' }, [
              h('span', { style: `display:inline-block;padding:2px 10px;border-radius:4px;background:${typeColor}1a;color:${typeColor};font-size:12px;font-weight:600;letter-spacing:0.3px;white-space:nowrap;flex-shrink:0;` }, '标题'),
              h('span', { style: 'font-size:14px;font-weight:600;color:#303133;line-height:1.5;word-break:break-word;' }, t.title),
            ]),
            t.content
              ? h('div', { style: 'background:#eef0f5;border-radius:6px;padding:8px 10px;margin-bottom:6px;font-size:13px;color:#606266;line-height:1.6;word-break:break-word;', innerHTML: (() => { try { const r = marked.parse(t.content, { async: false }); return r instanceof Promise ? t.content : r } catch(e) { return t.content } })() })
              : null,
            h('div', { style: 'display:flex;align-items:center;gap:10px;font-size:12px;' }, [
              h('span', { style: `display:inline-block;padding:2px 8px;border-radius:4px;background:${typeColor}18;color:${typeColor};font-weight:500;` }, typeLabel),
              isRecurring && recurringLabel
                ? h('span', { style: 'color:#909399;' }, `🔄 ${recurringLabel}`)
                : (!isRecurring && reminderTime
                  ? h('span', { style: 'color:#e6a23c;' }, `⏰ ${reminderTime}`)
                  : h('span', { style: 'color:#c0c4cc;' }, '—')),
            ]),
          ])
        })

        ElNotification({
          title: titleText,
          message: h('div', { style: 'font-size:14px;line-height:1.6;' }, [
            h(ElScrollbar, { maxHeight: '500px' }, { default: () => todoCards }),
          ]),
          customClass: 'memo-remind-notification',
          duration: 0,
          position: 'top-right',
          offset: 60,
        })
        // 通知备忘录页面刷新数据（一次性待办提醒后状态已变为停用）
        window.dispatchEvent(new CustomEvent('todo-reminded'))
      }
    }
  } catch (e) {
    console.error('检查待办提醒失败:', e.message)
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
  // 待办提醒也由 HomePage 触发
  // 这样可以确保用户已经进入首页界面
  console.log('待办检查定时器已启动，等待 HomePage 触发首次检查')

  // 每30秒检查一次
  todoCheckTimer = setInterval(checkAndNotifyTodos, 30000)
  // 每30秒检查一次待办提醒
  if (todoRemindTimer) clearInterval(todoRemindTimer)
  todoRemindTimer = setInterval(checkTodoReminders, 30000)
  // 立即执行一次
  checkTodoReminders()
}

// 停止待办检查定时器
const stopTodoCheckTimer = () => {
  if (todoCheckTimer) {
    clearInterval(todoCheckTimer)
    todoCheckTimer = null
  }
  if (todoRemindTimer) {
    clearInterval(todoRemindTimer)
    todoRemindTimer = null
  }
}
// 监听 HomePage 发出的待办检查事件
const handleCheckTodos = () => {
  console.log('收到待办检查事件，执行检查')
  checkAndNotifyTodos()
}

// 页面从后台切回时立即检查待办提醒
const handleVisibilityChange = () => {
  if (document.visibilityState === 'visible') {
    checkTodoReminders()
  }
}

// 日历库及节假日数据年度更新提醒（每年12月提醒管理员）
const codeStyle = {
  background: '#e3e8ef',
  padding: '1px 6px',
  borderRadius: '4px',
  fontFamily: 'monospace',
  fontSize: '13px',
  color: '#476582',
}
const checkCalendarUpdatePrompt = () => {
  const now = new Date()
  // 12月（getMonth() 返回 11）
  if (now.getMonth() !== 11) return
  // 只提示一次
  if (sessionStorage.getItem('calendar_update_prompted')) return

  const userType = sessionStorage.getItem('userType')
  if (userType !== 'admin') return

  const nextYear = now.getFullYear() + 1
  sessionStorage.setItem('calendar_update_prompted', 'true')

  ElMessageBox.alert(
    h('div', { style: 'line-height:1.8;color:#606266;font-size:14px' }, [
      h('p', { style: 'margin:0 0 14px 0;font-weight:600;font-size:15px' }, [
        '以下 ', h('strong', { style: 'color:#e6a23c' }, '3项'),
        ' 节假日数据更新请在 ', h('strong', { style: 'color:#e6a23c' }, `${nextYear}年`),
        ' 前完成：'
      ]),
      // 第1项：lunar-javascript
      h('div', { style: 'margin-bottom:14px;padding:12px 16px;background:#f8f9fa;border-radius:8px;border:1px solid #ebeef5' }, [
        h('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:6px;color:#e6a23c;font-size:13px;font-weight:500' }, [
          h('span', null, '① 前端依赖：lunar-javascript'),
        ]),
        h('p', { style: 'margin:0 0 8px 12px;color:#909399;font-size:13px' },
          '用于值班管理中日历自动识别日期类型，影响法定节假日判断'
        ),
        h('div', { style: 'display:flex;align-items:center;gap:10px;margin-left:12px' }, [
          h('code', { style: 'flex:1;padding:8px 12px;background:#1e2a3a;color:#a8c8e8;border-radius:6px;font-family:Consolas,monospace;font-size:13px;user-select:all;cursor:text;letter-spacing:0.3px;white-space:nowrap' },
            'npm install lunar-javascript@latest'
          ),
        ]),
      ]),
      // 第2项：chinese_calendar
      h('div', { style: 'margin-bottom:14px;padding:12px 16px;background:#f8f9fa;border-radius:8px;border:1px solid #ebeef5' }, [
        h('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:6px;color:#409eff;font-size:13px;font-weight:500' }, [
          h('span', null, '② 后端依赖：chinese_calendar'),
        ]),
        h('p', { style: 'margin:0 0 8px 12px;color:#909399;font-size:13px' },
          '用于周报有效周计算和自动排班识别节假日，影响周报和周范围判定'
        ),
        h('div', { style: 'display:flex;align-items:center;gap:10px;margin-left:12px' }, [
          h('code', { style: 'flex:1;padding:8px 12px;background:#1e2a3a;color:#a8c8e8;border-radius:6px;font-family:Consolas,monospace;font-size:13px;user-select:all;cursor:text;letter-spacing:0.3px;white-space:nowrap' },
            'pip install --upgrade chinese_calendar'
          ),
        ]),
      ]),
      // 第3项：generate_schedule.py 硬编码字典
      h('div', { style: 'margin-bottom:4px;padding:12px 16px;background:#f8f9fa;border-radius:8px;border:1px solid #ebeef5' }, [
        h('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:6px;color:#67c23a;font-size:13px;font-weight:500' }, [
          h('span', null, '③ 后端硬编码：generate_schedule.py'),
        ]),
        h('p', { style: 'margin:0 0 8px 12px;color:#909399;font-size:13px' },
          'chinese_calendar 不可用时的降级数据（_KNOWN_HOLIDAYS 和 _KNOWN_WORKDAYS 字典）'
        ),
        h('div', { style: 'display:flex;align-items:center;gap:10px;margin-left:12px' }, [
          h('code', { style: 'flex:1;padding:8px 12px;background:#1e2a3a;color:#a8c8e8;border-radius:6px;font-family:Consolas,monospace;font-size:13px;user-select:all;cursor:text;letter-spacing:0.3px;white-space:normal;word-break:break-all' },
            '手动更新 generate_schedule.py 第41行和第62行'
          ),
        ]),
      ]),
    ]),
    '节假日数据年度更新提醒',
    {
      confirmButtonText: '知道了',
      type: 'warning',
      customClass: 'custom-message-box',
      showClose: true,
      closeOnClickModal: true,
      width: '520px',
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
        // 所有登录用户均连接 SSE，用于接收系统通知等实时消息
        connectSSEForUser()
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

  // 首页加载完成后触发日历库年度更新提醒
  window.addEventListener('check-calendar-update', checkCalendarUpdatePrompt)
  // 接收 HeaderBar 铃铛点击打开系统通知
  window.addEventListener('show-system-notification', handleShowSystemNotification)
  // 页面从后台切回时立即检查待办提醒（解决浏览器后台节流导致漏检）
  window.addEventListener('visibilitychange', handleVisibilityChange)
})

onBeforeUnmount(() => {
  // 移除页面卸载事件监听
  window.removeEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
  // 移除待办检查事件监听
  window.removeEventListener('check-todos', handleCheckTodos)
  // 移除日历库年度更新提醒事件监听
  window.removeEventListener('check-calendar-update', checkCalendarUpdatePrompt)
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
  // 移除 HeaderBar 系统通知事件
  window.removeEventListener('show-system-notification', handleShowSystemNotification)
  window.removeEventListener('visibilitychange', handleVisibilityChange)
  alarmStore.persistAlreadySpeakQueue()
})
</script>

<template>
  <div id="app">
    <router-view v-if="route.name === 'NotFound'" name="NotFound"></router-view>
    <router-view v-else-if="!isAuthenticated || route.name === 'LoginPage'" name="LoginPage"></router-view>
    <IndexPage v-else></IndexPage>

    <!-- 系统通知模态框 -->
    <el-dialog v-model="systemNotifVisible" width="560px" :show-close="false" class="system-notif-dialog" top="8vh" :close-on-click-modal="false" @closed="dismissSystemNotification()">
      <template #header>
        <div class="notif-dialog-header" v-if="currentSystemNotification">
          <div class="notif-dialog-header-icon">
            <!-- 普通通知-铃铛 -->
            <svg v-if="currentSystemNotification.type === 'success'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
            <!-- 重要通知-三角警告 -->
            <svg v-else-if="currentSystemNotification.type === 'warning'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
            <!-- 紧急通知-扩音器 -->
            <svg v-else-if="currentSystemNotification.type === 'error'" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 14s3 2 3 5V5s-3 2-3 5"/><path d="M3 10v4a2 2 0 002 2h3l3 4V4L8 8H5a2 2 0 00-2 2z"/></svg>
            <!-- 默认-铃铛 -->
            <svg v-else viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
          </div>
          <div class="notif-dialog-header-text">
            <span class="notif-dialog-title-text">{{ currentSystemNotification.title }}</span>
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <el-tag :type="currentSystemNotification.type" size="small" effect="dark">{{ currentTypeStyle.label }}</el-tag>
              <span v-if="currentSystemNotification.timestamp" style="font-size: 12px; color: rgba(255,255,255,0.7);">{{ currentSystemNotification.timestamp }}</span>
            </div>
          </div>
        </div>
      </template>
      <div class="notif-dialog-body">
        <el-scrollbar max-height="400px">
          <div class="notif-dialog-content" v-html="systemNotifContent"></div>
        </el-scrollbar>
      </div>
      <template #footer>
        <div class="notif-dialog-footer">
          <el-button class="notif-dialog-btn" @click="systemNotifVisible = false">我知道了</el-button>
        </div>
      </template>
    </el-dialog>
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

/* 系统通知弹出框样式 */
.system-notification-popup {
  border-radius: 12px !important;
  border: 1px solid #e8ecf1 !important;
  box-shadow: 0 8px 28px rgba(0,0,0,0.10) !important;
  padding: 18px 22px !important;
  width: 380px !important;
  background: #fff !important;
}
.system-notification-popup .el-notification__title {
  font-size: 15px !important;
  font-weight: 600 !important;
  color: #303133 !important;
  padding-bottom: 10px !important;
  border-bottom: 1px solid #f0f2f5 !important;
  margin-bottom: 10px !important;
}
.system-notification-popup .el-notification__content {
  font-size: 13px !important;
  color: #606266 !important;
  line-height: 1.8 !important;
  margin: 0 !important;
  padding: 0 !important;
}
.system-notification-popup .el-notification__content p {
  margin: 0 0 8px !important;
  line-height: 1.8 !important;
}
.system-notification-popup .el-notification__content p:last-child {
  margin-bottom: 0 !important;
}
.system-notification-popup .el-notification__content strong {
  font-weight: 600;
  color: #303133;
}
.system-notification-popup .el-notification__content code {
  background: #f5f7fa;
  padding: 1px 5px;
  border-radius: 3px;
  font-size: 12px;
  color: #476582;
}
.system-notification-popup .el-notification__content a {
  color: #409eff;
  text-decoration: none;
}
.system-notification-popup .el-notification__content a:hover {
  text-decoration: underline;
}
.system-notification-popup .el-notification__content ul,
.system-notification-popup .el-notification__content ol {
  padding-left: 20px;
  margin: 6px 0;
}
.system-notification-popup .el-notification__content li {
  margin-bottom: 4px;
}
.system-notification-popup .el-notification__closeBtn {
  top: 18px !important;
  right: 18px !important;
  font-size: 16px !important;
  color: #c0c4cc !important;
}
.system-notification-popup .el-notification__closeBtn:hover {
  color: #909399 !important;
}
/* type 颜色定制 */
.system-notification-popup.el-notification--success {
  border-left: 4px solid #67c23a !important;
}
.system-notification-popup.el-notification--warning {
  border-left: 4px solid #e6a23c !important;
}
.system-notification-popup.el-notification--error {
  border-left: 4px solid #f56c6c !important;
}
.system-notification-popup.el-notification--info {
  border-left: 4px solid #909399 !important;
}

/* 系统通知模态框样式 - 匹配新建通知风格 */
.system-notif-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.system-notif-dialog .el-dialog__header {
  padding: 0;
  margin: 0;
}
.system-notif-dialog .el-dialog__body {
  padding: 0;
}
.system-notif-dialog .el-dialog__footer {
  padding: 0;
}
.notif-dialog-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 24px 28px;
  display: flex;
  align-items: center;
  gap: 16px;
}
.notif-dialog-header-icon {
  width: 52px;
  height: 52px;
  background: rgba(255,255,255,0.2);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  backdrop-filter: blur(4px);
}
.notif-dialog-header-text {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
  align-items: flex-start;
}
.notif-dialog-header-text .el-tag {
  font-weight: 600;
}
.notif-dialog-title-text {
  font-size: 20px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.5px;
  line-height: 1.3;
  word-break: break-word;
}
.notif-dialog-body {
  padding: 24px 28px;
  background: #f8f9fe;
}
.notif-dialog-body .el-scrollbar__wrap {
  padding: 0;
}
.notif-dialog-content {
  font-size: 14px;
  color: #303133;
  line-height: 1.8;
}
.notif-dialog-content p {
  margin: 0 0 10px;
}
.notif-dialog-content p:last-child {
  margin-bottom: 0;
}
.notif-dialog-content strong {
  font-weight: 600;
  color: #1a1a2e;
}
.notif-dialog-content code {
  background: #f0f2f5;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13px;
  color: #476582;
}
.notif-dialog-content a {
  color: #409eff;
  text-decoration: none;
}
.notif-dialog-content a:hover {
  text-decoration: underline;
}
.notif-dialog-content ul,
.notif-dialog-content ol {
  padding-left: 20px;
  margin: 8px 0;
}
.notif-dialog-content li {
  margin-bottom: 4px;
}
.notif-dialog-footer {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px 28px;
  background: #f8f9fe;
  border-top: 1px solid #e8eaf0;
}
.notif-dialog-btn {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 28px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff !important;
  font-size: 13px;
  font-weight: 600;
  transition: all 0.25s ease;
}
.notif-dialog-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
  color: #fff !important;
}

/* 备忘录待办提醒弹框 - 匹配新建待办模态框紫蓝渐变主题 */
.memo-remind-notification {
  background: #fff !important;
  border: none !important;
  border-radius: 14px !important;
  box-shadow: 0 8px 32px rgba(102, 126, 234, 0.3), 0 4px 16px rgba(0, 0, 0, 0.08) !important;
  padding: 0 !important;
  min-width: 360px;
  max-width: 650px;
  width: auto !important;
  overflow: hidden;
  user-select: none;
}
.memo-remind-notification .el-notification__title {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  margin: 0 !important;
  padding: 18px 20px !important;
  font-size: 15px !important;
  font-weight: 600 !important;
  color: #fff !important;
  letter-spacing: 0.5px;
}
.memo-remind-notification .el-notification__content {
  padding: 16px 20px !important;
  margin: 0 !important;
  background: #f8f9fe;
}
.memo-remind-notification .el-notification__closeBtn {
  color: rgba(255,255,255,0.75) !important;
  font-size: 16px !important;
  top: 18px !important;
  right: 18px !important;
  transition: color 0.2s;
}
.memo-remind-notification .el-notification__closeBtn:hover {
  color: #fff !important;
}
.memo-remind-notification .el-notification__icon {
  display: none !important;
}
.memo-remind-notification .el-notification__group {
  margin-left: 0 !important;
  width: 100%;
}
</style>
