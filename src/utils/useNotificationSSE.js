/**
 * SSE 通知推送 composable
 * - 建立 EventSource 连接，实时接收服务端推送的通知
 * - 支持自动重连、断线缓存拉取
 */
import { ref, onUnmounted } from 'vue'
import { ElNotification } from 'element-plus'
import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'

/**
 * 使用 SSE 通知推送
 * @param {import('vue').ComputedRef<string>} usernameRef - 当前用户 username（computed ref）
 */
export function useNotificationSSE(usernameRef) {
  const isConnected = ref(false)
  let eventSource = null
  let reconnectTimer = null
  let reconnectAttempts = 0
  const MAX_RECONNECT_ATTEMPTS = 10
  const RECONNECT_BASE_DELAY = 3000 // 3秒
  let currentRemindNotification = null // 跟踪当前周报提醒弹框实例

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
        message: data.htmlMessage || data.message,
        type: 'warning',
        duration: 0, // 不自动关闭，需用户手动点击
        position: 'top-right',
        dangerouslyUseHTMLString: true,
      })
    } else if (data.type === 'weekly_report_status_change') {
      // 周报状态变更（提交/保存草稿/打回）：派发自定义事件，由各页面监听后自动刷新
      // 不弹窗，仅触发数据刷新
      window.dispatchEvent(new CustomEvent('weekly-report-status-change', { detail: data }))
    } else if (data.type === 'weekly_report_returned') {
      // 周报被打回：弹窗提醒填报人 + 派发事件触发页面刷新
      if (currentRemindNotification) {
        currentRemindNotification.close()
        currentRemindNotification = null
      }
      currentRemindNotification = ElNotification({
        title: data.title || '周报被打回',
        message: data.htmlMessage || data.message || '您的周报已被打回，请重新编辑后提交。',
        type: 'warning',
        duration: 0,
        position: 'top-right',
        dangerouslyUseHTMLString: true,
      })
      window.dispatchEvent(new CustomEvent('weekly-report-returned', { detail: data }))
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

    const url = `${RBAC_IP.value}/notifications/stream?username=${encodeURIComponent(usernameRef.value)}`
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

  // 计划重连
  const scheduleReconnect = () => {
    if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      console.warn('[SSE] 已达最大重连次数，停止重连')
      return
    }
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

  return { isConnected, connect, disconnect }
}
