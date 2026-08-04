/**
 * SSE 通知推送 composable
 * - 建立 EventSource 连接，实时接收服务端推送的通知
 * - 支持自动重连、断线缓存拉取
 */
import { ref, onUnmounted, h } from 'vue'
import { ElNotification, ElScrollbar } from 'element-plus'
import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'
import { marked } from 'marked'

// 生成当前标签页唯一编号（在页面刷新前保持不变）
const TAB_ID = 'tab_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8)

/**
 * 使用 SSE 通知推送
 * @param {import('vue').ComputedRef<string>} usernameRef - 当前用户 username（computed ref）
 */
export function useNotificationSSE(usernameRef) {
  const isConnected = ref(false)
  let eventSource = null
  let reconnectTimer = null
  let reconnectAttempts = 0
  const RECONNECT_BASE_DELAY = 3000 // 3秒
  let currentRemindNotification = null // 跟踪当前周报提醒弹框实例
  const currentSystemNotification = ref(null) // 当前系统通知弹框数据
  const systemNotificationQueue = [] // 系统通知队列（避免多个通知互相覆盖）
  const systemNotifShownCache = {} // 内存去重缓存 {notificationId: timestamp}

  // sessionStorage 持久化去重（替代内存 Set + 5秒超时）
  // 无论 SSE 重连还是页面刷新，同标签页内同一通知只展示一次
  const SYSTEM_NOTIF_DEDUP_KEY = 'system_notif_dedup_ids'
  const MAX_DEDUP_IDS = 200

  const isSystemNotifDisplayed = (notifId) => {
    try {
      const stored = sessionStorage.getItem(SYSTEM_NOTIF_DEDUP_KEY)
      if (!stored) return false
      return JSON.parse(stored).includes(notifId)
    } catch { return false }
  }

  const markSystemNotifDisplayed = (notifId) => {
    try {
      const stored = sessionStorage.getItem(SYSTEM_NOTIF_DEDUP_KEY)
      let ids = stored ? JSON.parse(stored) : []
      if (!ids.includes(notifId)) {
        ids.push(notifId)
        if (ids.length > MAX_DEDUP_IDS) ids = ids.slice(-MAX_DEDUP_IDS)
        sessionStorage.setItem(SYSTEM_NOTIF_DEDUP_KEY, JSON.stringify(ids))
      }
    } catch { /* 忽略存储错误 */ }
  }

  // 实时校验用户是否真的还未提交周报（防止缓存的过期通知误导已提交用户）
  const isUserTrulyUnsubmitted = async (weekNum) => {
    const username = usernameRef.value
    if (!username || !weekNum) return true // 无法校验时默认展示
    try {
      const res = await axios.get(`${RBAC_IP.value}/myReports`, {
        params: { weekNum, username }
      })
      const records = res.data?.data?.records || []
      // 仅当没有任何记录（完全未提交），或存在非已提交状态（草稿/打回）的记录时才需要提醒
      // 如果所有记录都已提交，说明已全部完成，忽略过期提醒
      return records.length === 0 || records.some(r => r.status !== 'submitted')
    } catch {
      return true // 接口异常时默认展示
    }
  }

  // 处理收到的通知
  const handleNotification = async (data) => {
    if (!data) return
    if (data.type === 'weekly_report_remind') {
      // 实时校验：确认当前用户该周确实还未提交，才弹出提醒
      const trulyUnsubmitted = await isUserTrulyUnsubmitted(data.weekNum)
      if (!trulyUnsubmitted) {
        console.log('[SSE] 用户已提交周报，忽略过期提醒通知')
        return
      }
      // 新弹框弹出前，先关闭旧的周报提醒弹框
      if (currentRemindNotification) {
        currentRemindNotification.close()
        currentRemindNotification = null
      }
      currentRemindNotification = ElNotification({
        title: data.title || '周报提交提醒',
        message: h(ElScrollbar, { maxHeight: '300px' }, {
          default: () => h('div', { innerHTML: data.htmlMessage || data.message })
        }),
        type: 'warning',
        duration: 0, // 不自动关闭，需用户手动点击
        position: 'top-right',
      })
    } else if (data.type === 'weekly_report_status_change') {
      // 周报状态变更（提交/保存草稿/打回）：
      // 提交时弹窗展示提交人和模块表格 + 派发事件触发页面刷新
      if (data.action === 'submitted' && data.name && data.modules && data.modules.length > 0) {
        // 按模块名排序，便于父模块合并
        const sorted = [...data.modules].sort((a, b) => {
          if (a.moduleName < b.moduleName) return -1
          if (a.moduleName > b.moduleName) return 1
          return (a.subModuleName || '').localeCompare(b.subModuleName || '')
        })
        // 计算每个模块的出现次数
        const modCount = {}
        sorted.forEach(m => {
          modCount[m.moduleName] = (modCount[m.moduleName] || 0) + 1
        })
        // 构建表格行，父模块合并
        const seenMods = new Set()
        const moduleRows = sorted.map(m => {
          const subName = m.subModuleName || '-'
          let modCell = ''
          if (!seenMods.has(m.moduleName)) {
            seenMods.add(m.moduleName)
            const rs = modCount[m.moduleName]
            modCell = `<td rowspan="${rs}" style="padding:4px 10px;border:1px solid #e4e7ed;text-align:center;font-size:12px;color:#303133;vertical-align:middle;">${m.moduleName}</td>`
          }
          return `<tr>${modCell}<td style="padding:4px 10px;border:1px solid #e4e7ed;text-align:center;font-size:12px;color:#303133;">${subName}</td></tr>`
        }).join('')
        const tableHtml = `
          <div style="font-size:13px;margin-bottom:6px;color:#303133;">${data.name} 提交了以下模块：</div>
          <table style="border-collapse:collapse;width:100%;">
            <thead><tr style="background:#f5f7fa;">
              <th style="padding:5px 10px;border:1px solid #e4e7ed;text-align:center;font-size:12px;color:#606266;">运维模块</th>
              <th style="padding:5px 10px;border:1px solid #e4e7ed;text-align:center;font-size:12px;color:#606266;">子模块</th>
            </tr></thead>
            <tbody>${moduleRows}</tbody>
          </table>`
        ElNotification({
          title: '周报提交通知',
          message: h(ElScrollbar, { maxHeight: '300px' }, {
            default: () => h('div', { innerHTML: tableHtml })
          }),
          type: 'success',
          duration: 5000,
          position: 'top-right',
        })
      }
      // 派发事件触发页面刷新
      window.dispatchEvent(new CustomEvent('weekly-report-status-change', { detail: data }))
    } else if (data.type === 'weekly_report_returned') {
      // 周报被退回：弹窗提醒填报人 + 派发事件触发页面刷新
      if (currentRemindNotification) {
        currentRemindNotification.close()
        currentRemindNotification = null
      }
      currentRemindNotification = ElNotification({
        title: data.title || '周报已被退回',
        message: h(ElScrollbar, { maxHeight: '300px' }, {
          default: () => h('div', { innerHTML: data.htmlMessage || data.message || '您的周报已被退回，请重新编辑后提交。' })
        }),
        type: 'warning',
        duration: 0,
        position: 'top-right',
      })
      window.dispatchEvent(new CustomEvent('weekly-report-returned', { detail: data }))
    } else if (data.type === 'system_notification') {
      // 系统通知：sessionStorage 持久化去重
      // 覆盖场景：同 Worker 内双重投递、SSE 重连后离线补推
      const notifId = data.notificationId
      if (notifId !== undefined && !isNaN(notifId)) {
        if (isSystemNotifDisplayed(notifId)) {
          console.log('[SSE] 跳过重复的系统通知 notificationId=' + notifId)
          return
        }
        markSystemNotifDisplayed(notifId)
      }
      // 入队，由队列管理展示模态框（避免离线补推时多个通知互相覆盖）
      systemNotificationQueue.push({
        title: data.title || '系统通知',
        content: data.message || '',
        type: data.notificationType || 'info',
        timestamp: data.timestamp || '',
      })
      // 若当前没有展示中的模态框，立即展示下一个
      if (currentSystemNotification.value === null) {
        showNextSystemNotification()
      }
      // 通知 HeaderBar 刷新通知列表
      window.dispatchEvent(new CustomEvent('system-notification-received'))
    } else if (data.type === 'report_module_change') {
      // 模块/子模块变更（新增/编辑/删除/启停/排序）：
      // 弹出变更通知 + 触发填写页和汇总页响应式更新
      const { action, moduleName, subModuleName, statusText } = data
      // 构建清晰的描述文本
      let descText = ''
      let notifType = 'info'
      if (action === 'sorted') {
        // 排序：直接使用 moduleName（如"模块排序已更新"）
        descText = `${moduleName}已更新`
      } else if (subModuleName) {
        // 子模块操作
        const actionText = {
          'created': '已创建',
          'updated': '有更新',
          'deleted': '已删除',
        }[action] || action
        descText = `模块「${moduleName}」&gt; 子模块「${subModuleName}」${actionText}`
      } else if (action === 'status_changed') {
        descText = `模块「${moduleName}」已${statusText || '变更状态'}`
        notifType = statusText === '启用' ? 'success' : 'warning'
      } else {
        const actionText = {
          'created': '已创建',
          'updated': '有更新',
          'deleted': '已删除',
        }[action] || action
        descText = `模块「${moduleName}」${actionText}`
      }
      if (action === 'deleted') notifType = 'warning'
      else if (action === 'created') notifType = 'success'
      else if (action !== 'status_changed') notifType = 'info'
      const borderColor = notifType === 'success' ? '#67c23a' : notifType === 'warning' ? '#e6a23c' : '#409eff'
      const notifMsg = h(ElScrollbar, { maxHeight: '300px' }, {
        default: () => h('div', {
          style: 'font-size:13px;color:#303133;line-height:1.6;padding:2px 0;',
          innerHTML: `<span style="display:inline-block;width:4px;height:14px;border-radius:2px;background:${borderColor};vertical-align:middle;margin-right:8px;"></span>${descText}`
        })
      })
      ElNotification({
        title: '运维模块变更',
        message: notifMsg,
        type: notifType,
        duration: 4000,
        position: 'top-right',
      })
      window.dispatchEvent(new CustomEvent('weekly-report-module-change', { detail: data }))
    } else if (data.type === 'summary_filler_changed') {
      // 综述填写开关变更：更新共享状态 + 弹窗提示
      import('@/utils/weeklyReportData').then(mod => {
        mod.summaryFillerEnabled.value = data.enabled
      })
      ElNotification({
        title: '综述填写开关',
        message: `综述填写功能已${data.enabled ? '开启' : '关闭'}`,
        type: data.enabled ? 'success' : 'warning',
        duration: 3000,
        position: 'top-right',
      })
    } else {
      // 通用通知
      ElNotification({
        title: data.title || '通知',
        message: data.message || '',
        type: 'info',
        duration: 5000,
        position: 'top-right',
      })
    }
  }

  // 拉取离线缓存的待处理通知
  const fetchPendingNotifications = async () => {
    if (!usernameRef.value) return
    try {
      const res = await axios.get(`${RBAC_IP.value}/notifications/pending`, {
        params: { username: usernameRef.value }
      })
      const pending = res.data?.data || []
      pending.forEach(handleNotification)
    } catch (e) {
      console.warn('拉取离线通知失败', e)
    }
  }

  // 建立 SSE 连接
  const connect = () => {
    if (!usernameRef.value) return
    if (eventSource) disconnect()

    const url = `${RBAC_IP.value}/notifications/stream?username=${encodeURIComponent(usernameRef.value)}&tabId=${encodeURIComponent(TAB_ID)}`
    eventSource = new EventSource(url)

    eventSource.addEventListener('connected', () => {
      isConnected.value = true
      reconnectAttempts = 0
      // 连接成功后拉取离线缓存的通知
      fetchPendingNotifications()
    })

    eventSource.addEventListener('notification', (event) => {
      try {
        const data = JSON.parse(event.data)
        handleNotification(data)
      } catch (e) {
        console.warn('解析通知数据失败', e)
      }
    })

    eventSource.addEventListener('heartbeat', () => {
      // 心跳包，保持连接活跃，无需处理
    })

    eventSource.onerror = () => {
      isConnected.value = false
      eventSource.close()
      eventSource = null
      scheduleReconnect()
    }
  }

  // 计划重连（指数退避，无限重连）
  const scheduleReconnect = () => {
    const delay = RECONNECT_BASE_DELAY * Math.pow(1.5, reconnectAttempts)
    reconnectTimer = setTimeout(() => {
      reconnectAttempts++
      connect()
    }, Math.min(delay, 30000)) // 最大间隔 30 秒
  }

  // 断开连接
  const disconnect = () => {
    if (eventSource) {
      eventSource.close()
      eventSource = null
    }
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    isConnected.value = false
    currentRemindNotification = null
  }

  // 组件卸载时自动断开
  onUnmounted(disconnect)

  // 展示队列中的下一个系统通知
  const showNextSystemNotification = () => {
    if (systemNotificationQueue.length === 0) return
    currentSystemNotification.value = systemNotificationQueue.shift()
  }

  // 关闭当前系统通知并展示下一个（由 App.vue 在模态框关闭时调用）
  const dismissSystemNotification = () => {
    currentSystemNotification.value = null
    showNextSystemNotification()
  }

  return { isConnected, connect, disconnect, currentSystemNotification, dismissSystemNotification }
}
