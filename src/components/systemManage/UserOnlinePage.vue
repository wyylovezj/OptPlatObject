<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { ElMessage } from 'element-plus'
import axios from 'axios'
import { getUserOnlineHistory } from '@/api/systemNotificationApi.js'

const rbacIp = window.APP_CONFIG?.RBAC_IP || '127.0.0.1'

const activeTab = ref('realtime')

// ========== 实时监控 ==========
const users = ref([])
const loading = ref(false)
const manualRefreshing = ref(false)
let refreshTimer = null

// 展开行缓存 { username: [records] }
const expandedHistory = ref({})
const expandedLoading = ref({})

const realtimePage = ref(1)
const realtimePageSize = ref(20)
const realtimeFilter = ref({ nickname: '', username: '', status: '' })

const filteredUsers = computed(() => {
  const f = realtimeFilter.value
  return users.value.filter(u => {
    if (f.nickname && !u.nickname.toLowerCase().includes(f.nickname.toLowerCase())) return false
    if (f.username && !u.username.toLowerCase().includes(f.username.toLowerCase())) return false
    if (f.status !== '' && f.status !== null) {
      const isOnline = f.status === 'online'
      if (u.online !== isOnline) return false
    }
    return true
  })
})

const paginatedUsers = computed(() => {
  const start = (realtimePage.value - 1) * realtimePageSize.value
  return filteredUsers.value.slice(start, start + realtimePageSize.value)
})

// 数据刷新后仅校正页码越界（自动刷新不强制回到第一页，避免翻页被打断）
watch(filteredUsers, () => {
  const maxPage = Math.max(1, Math.ceil(filteredUsers.value.length / realtimePageSize.value))
  if (realtimePage.value > maxPage) realtimePage.value = maxPage
})

const handleRealtimeSearch = () => { realtimePage.value = 1 }
const handleRealtimeReset = () => {
  realtimeFilter.value = { nickname: '', username: '', status: '' }
  realtimePage.value = 1
}

const onlineCount = computed(() => users.value.filter(u => u.online).length)
const offlineCount = computed(() => users.value.filter(u => !u.online).length)
const totalCount = computed(() => users.value.length)

const loadOnlineStatus = async (isManual = false) => {
  loading.value = true
  if (isManual) manualRefreshing.value = true
  try {
    const res = await axios.get(`${rbacIp}/getUserOnlineStatus`)
    if (res.data.code === 200) {
      const data = res.data.data || []
      data.sort((a, b) => {
        if (a.online !== b.online) return a.online ? -1 : 1
        return a.username.localeCompare(b.username)
      })
      users.value = data
    } else {
      ElMessage.error(res.data.message || '加载失败')
    }
  } catch (e) {
    console.warn('获取在线状态失败', e)
  } finally {
    loading.value = false
    if (isManual) manualRefreshing.value = false
  }
}

const startAutoRefresh = () => {
  stopAutoRefresh()
  refreshTimer = setInterval(loadOnlineStatus, 1000)
}

const stopAutoRefresh = () => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
    refreshTimer = null
  }
}

// ========== 历史记录 ==========
const today = new Date()
const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

const historyList = ref([])
const historyTotal = ref(0)
const historyPage = ref(1)
const historyPageSize = ref(20)
const historyLoading = ref(false)
const historyFilter = ref({ nickname: '', username: '' })
const dateRange = ref([todayStr, todayStr])

const loadHistory = async () => {
  historyLoading.value = true
  try {
    const params = { page: historyPage.value, pageSize: historyPageSize.value }
    const f = historyFilter.value
    if (f.nickname) params.nickname = f.nickname
    if (f.username) params.username = f.username
    if (dateRange.value && dateRange.value[0]) params.startDate = dateRange.value[0]
    if (dateRange.value && dateRange.value[1]) params.endDate = dateRange.value[1]
    const res = await getUserOnlineHistory(params)
    if (res.code === 200) {
      historyList.value = res.data.records || []
      historyTotal.value = res.data.total || 0
    } else {
      ElMessage.error(res.message || '加载失败')
    }
  } catch (e) {
    ElMessage.error('加载历史记录失败：' + e.message)
  } finally {
    historyLoading.value = false
  }
}

const handleHistorySearch = () => {
  historyPage.value = 1
  loadHistory()
}

const handleHistoryReset = () => {
  historyFilter.value = { nickname: '', username: '' }
  dateRange.value = [todayStr, todayStr]
  historyPage.value = 1
  loadHistory()
}

const handleHistoryPageChange = (page) => {
  historyPage.value = page
  loadHistory()
}

// 实时计算在线时长（针对未离线用户）
const liveTick = ref(0)
let liveTimer = null

// 通用时长格式化：秒数 → HH:MM:SS（两位数）
const formatSeconds = (totalSec) => {
  if (totalSec < 0) return '-'
  const h = Math.floor(totalSec / 3600)
  const m = Math.floor((totalSec % 3600) / 60)
  const s = totalSec % 60
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// 从 User-Agent 解析简短浏览器名称
const parseBrowserName = (ua) => {
  if (!ua) return '-'
  if (/Edg\//i.test(ua)) return 'Edge'
  if (/OPR\//i.test(ua) || /Opera/i.test(ua)) return 'Opera'
  if (/Firefox\//i.test(ua)) return 'Firefox'
  if (/QIHU|360EE|360SE|Qihoo/i.test(ua)) return '360'
  if (/Chrome\//i.test(ua)) return 'Chrome'
  if (/Safari\//i.test(ua) && !/Chrome\//i.test(ua)) return 'Safari'
  if (/MSIE|Trident\//i.test(ua)) return 'IE'
  // 截取第一段作为兜底
  const match = ua.match(/^[^/]+/)
  return match ? match[0] : ua.substring(0, 20)
}

const getDuration = (row, tick) => {
  // tick 用于建立模板响应式依赖，触发每秒重渲染
  void tick
  if (!row.logoutTime) {
    if (!row.loginTime) return '-'
    const login = new Date(row.loginTime).getTime()
    if (isNaN(login)) return '-'
    const diff = Math.floor((Date.now() - login) / 1000)
    return formatSeconds(diff)
  }
  // 已离线：从 loginTime 到 logoutTime 计算时长
  if (row.loginTime && row.logoutTime) {
    const login = new Date(row.loginTime).getTime()
    const logout = new Date(row.logoutTime).getTime()
    if (!isNaN(login) && !isNaN(logout)) {
      const diff = Math.floor((logout - login) / 1000)
      if (diff >= 0) return formatSeconds(diff)
    }
  }
  return row.duration || '-'
}

// ========== 动态计算表格高度实现表头固定 + 内容滚动 ==========
const realtimeBodyRef = ref(null)
const historyBodyRef = ref(null)
const tableMaxHeight = ref(500)

// 加载指定用户今日登录明细（用于展开行）
const loadUserTodayHistory = async (username) => {
  if (expandedHistory.value[username] || expandedLoading.value[username]) return
  expandedLoading.value = { ...expandedLoading.value, [username]: true }
  try {
    const params = { page: 1, pageSize: 100, username, startDate: todayStr, endDate: todayStr }
    const res = await getUserOnlineHistory(params)
    if (res.code === 200) {
      const records = (res.data.records || []).sort((a, b) => {
        return (b.loginTime || '').localeCompare(a.loginTime || '')
      })
      expandedHistory.value = { ...expandedHistory.value, [username]: records }
    }
  } catch (e) {
    console.warn('加载用户登录明细失败', e)
  } finally {
    expandedLoading.value = { ...expandedLoading.value, [username]: false }
  }
}

// 展开行变化时加载数据
const handleExpandChange = (row, expanded) => {
  if (expanded && row.username) {
    loadUserTodayHistory(row.username)
  }
}

let resizeObserver = null

const refreshTableHeight = () => {
  const el = activeTab.value === 'realtime' ? realtimeBodyRef.value : historyBodyRef.value
  if (el) {
    const h = el.clientHeight
    if (h > 0) tableMaxHeight.value = h
  }
}

onMounted(() => {
  loadOnlineStatus()
  startAutoRefresh()
  loadHistory()
  // 每秒刷新在线时长
  liveTimer = setInterval(() => { liveTick.value++ }, 1000)

  nextTick(() => {
    // 观察两个 table-body-area，仅当前可见的会返回正确高度
    resizeObserver = new ResizeObserver(refreshTableHeight)
    const els = [realtimeBodyRef.value, historyBodyRef.value].filter(Boolean)
    els.forEach(el => resizeObserver.observe(el))
    refreshTableHeight()
  })
})

onUnmounted(() => {
  stopAutoRefresh()
  if (resizeObserver) resizeObserver.disconnect()
  if (liveTimer) clearInterval(liveTimer)
})

watch(activeTab, () => {
  nextTick(refreshTableHeight)
  // 切换 tab 时刷新对应数据
  if (activeTab.value === 'realtime') {
    loadOnlineStatus()
  } else if (activeTab.value === 'history') {
    loadHistory()
  }
})
</script>

<template>
  <div class="online-page">
    <div class="stats-row">
      <div class="stat-card stat-total">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ totalCount }}</span>
          <span class="stat-label">所有用户</span>
        </div>
      </div>
      <div class="stat-card stat-online">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ onlineCount }}</span>
          <span class="stat-label">在线用户</span>
        </div>
      </div>
      <div class="stat-card stat-offline">
        <div class="stat-icon"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg></div>
        <div class="stat-info">
          <span class="stat-value">{{ offlineCount }}</span>
          <span class="stat-label">离线用户</span>
        </div>
      </div>
    </div>

    <el-tabs v-model="activeTab" class="page-tabs">
      <!-- 实时监控 -->
      <el-tab-pane label="实时监控" name="realtime">
        <div class="filter-bar">
          <el-form inline class="filter-form">
            <el-form-item class="filter-item">
              <el-input v-model="realtimeFilter.nickname" placeholder="姓名" clearable style="width: 130px" @keyup.enter="handleRealtimeSearch" />
            </el-form-item>
            <el-form-item class="filter-item">
              <el-input v-model="realtimeFilter.username" placeholder="账号" clearable style="width: 130px" @keyup.enter="handleRealtimeSearch" />
            </el-form-item>
            <el-form-item class="filter-item">
              <el-select v-model="realtimeFilter.status" placeholder="状态" clearable style="width: 100px">
                <el-option label="在线" value="online" />
                <el-option label="离线" value="offline" />
              </el-select>
            </el-form-item>
            <span class="filter-sep"></span>
            <div class="filter-actions">
              <el-button class="search-btn" @click="handleRealtimeSearch">
                <svg class="icon-svg sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>&nbsp;搜索
              </el-button>
              <el-button class="reset-btn" @click="handleRealtimeReset">
                <svg class="icon-svg sm" viewBox="0 0 24 24"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;重置
              </el-button>
            </div>
          </el-form>
        </div>

        <el-card class="list-card" shadow="never">
          <div class="table-wrapper">
            <div class="table-toolbar">
              <div class="toolbar-left">
                <span class="toolbar-title">用户列表</span>
                <span class="toolbar-sep"></span>
                <span class="toolbar-hint">每 1 秒自动刷新</span>
              </div>
              <div class="toolbar-actions">
                <el-button class="toolbar-btn-refresh" :loading="manualRefreshing" @click="loadOnlineStatus(true)">
                  <svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>
                </el-button>
              </div>
            </div>
            <div class="table-body-area" ref="realtimeBodyRef">
            <el-table :data="paginatedUsers" :max-height="tableMaxHeight" v-loading="loading" style="width: 100%" stripe empty-text="暂无用户数据" :table-layout="'auto'" :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }" @expand-change="handleExpandChange" :row-key="row => row.username">
              <el-table-column type="expand">
                <template #default="{ row }">
                  <div class="expand-detail">
                    <div v-if="expandedLoading[row.username]" style="text-align:center;padding:12px;color:#909399;font-size:13px;">加载中...</div>
                    <el-table v-else-if="expandedHistory[row.username] && expandedHistory[row.username].length" :data="expandedHistory[row.username]" style="width: 100%" stripe :show-header="true" size="small" :header-cell-style="{ textAlign: 'center', background: '#f5f7fa', color: '#606266', fontWeight: '600', fontSize: '12px' }" :cell-style="{ fontSize: '12px' }">
                      <el-table-column type="index" label="序号" align="center" width="50" />
                      <el-table-column label="状态" align="center">
                        <template #default="{ row: r }">
                          <span class="status-indicator" :class="{ on: !r.logoutTime, off: !!r.logoutTime }">
                            <span class="status-text" :class="{ on: !r.logoutTime, off: !!r.logoutTime }">{{ !r.logoutTime ? '在线' : '离线' }}</span>
                          </span>
                        </template>
                      </el-table-column>
                      <el-table-column prop="loginTime" label="上线时间" align="center" />
                      <el-table-column label="离线时间" align="center">
                        <template #default="{ row: r }">
                          <span v-if="!r.logoutTime" style="color:#67c23a;font-weight:500;">在线</span>
                          <span v-else>{{ r.logoutTime }}</span>
                        </template>
                      </el-table-column>
                      <el-table-column label="在线时长" align="center">
                        <template #default="{ row: r }">
                          <span v-if="!r.logoutTime" class="live-duration">{{ getDuration(r, liveTick) }}</span>
                          <span v-else>{{ getDuration(r, liveTick) }}</span>
                        </template>
                      </el-table-column>
                      <el-table-column prop="ipAddress" label="客户端IP" align="center" />
                      <el-table-column label="浏览器" align="center">
                        <template #default="{ row: r }">
                          <span :title="r.userAgent">{{ parseBrowserName(r.userAgent) }}</span>
                        </template>
                      </el-table-column>
                      <el-table-column prop="tabId" label="SSE连接标识" align="center" />
                    </el-table>
                    <div v-else style="text-align:center;padding:12px;color:#c0c4cc;font-size:13px;">暂无今日登录记录</div>
                  </div>
                </template>
              </el-table-column>
              <el-table-column type="index" label="序号" align="center" :index="(index) => (realtimePage - 1) * realtimePageSize + index + 1" />
              <el-table-column label="状态" align="center">
                <template #default="{ row }">
                  <div class="status-indicator" :class="{ on: row.online, off: !row.online }">
                    <span class="status-text" :class="{ on: row.online, off: !row.online }">{{ row.online ? '在线' : '离线' }}</span>
                  </div>
                </template>
              </el-table-column>
              <el-table-column label="姓名" align="center">
                <template #default="{ row }">
                  <span class="user-name">{{ row.nickname }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="username" label="账号" align="center" />
            </el-table>
            </div>
          </div>
          <div class="pagination-wrapper" v-if="filteredUsers.length > 0">
            <span class="pagination-total">共 {{ filteredUsers.length }} 条</span>
            <el-pagination v-model:current-page="realtimePage" :page-size="realtimePageSize" :total="filteredUsers.length" layout="prev, pager, next" @current-change="() => {}" background />
          </div>
        </el-card>
      </el-tab-pane>

      <!-- 历史记录 -->
      <el-tab-pane label="登录历史" name="history">
        <div class="filter-bar">
          <el-form inline class="filter-form">
            <el-form-item class="filter-item">
              <el-input v-model="historyFilter.nickname" placeholder="用户" clearable style="width: 130px" @keyup.enter="handleHistorySearch" />
            </el-form-item>
            <el-form-item class="filter-item">
              <el-input v-model="historyFilter.username" placeholder="账号" clearable style="width: 130px" @keyup.enter="handleHistorySearch" />
            </el-form-item>
            <el-form-item class="filter-item">
              <el-date-picker v-model="dateRange" type="daterange" range-separator="-" start-placeholder="开始日期" end-placeholder="结束日期" value-format="YYYY-MM-DD" style="width: 260px" clearable :max-range="31 * 24 * 60 * 60 * 1000" @clear="dateRange = [todayStr, todayStr]" />
            </el-form-item>
            <span class="filter-sep"></span>
            <div class="filter-actions">
              <el-button class="search-btn" @click="handleHistorySearch">
                <svg class="icon-svg sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>&nbsp;搜索
              </el-button>
              <el-button class="reset-btn" @click="handleHistoryReset">
                <svg class="icon-svg sm" viewBox="0 0 24 24"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;重置
              </el-button>
            </div>
          </el-form>
        </div>

        <el-card class="list-card" shadow="never">
          <div class="table-wrapper">
            <div class="table-toolbar">
              <div class="toolbar-left">
                <span class="toolbar-title">登录记录</span>
                <span class="toolbar-sep"></span>
              </div>
            </div>
            <div class="table-body-area" ref="historyBodyRef">
            <el-table :data="historyList" :max-height="tableMaxHeight" v-loading="historyLoading" style="width: 100%" stripe empty-text="暂无登录记录" :table-layout="'auto'" :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }">
              <el-table-column type="index" label="序号" align="center" :index="(index) => (historyPage - 1) * historyPageSize + index + 1" />
              <el-table-column label="用户" align="center">
                <template #default="{ row }">
                  <span class="user-name">{{ row.nickname }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="username" label="账号" align="center" />
              <el-table-column prop="loginTime" label="上线时间" align="center" />
              <el-table-column prop="logoutTime" label="离线时间" align="center">
                <template #default="{ row }">
                  <span v-if="!row.logoutTime" class="inline-online"><span class="online-dot"></span>在线</span>
                  <span v-else>{{ row.logoutTime }}</span>
                </template>
              </el-table-column>
              <el-table-column label="在线时长" align="center">
                <template #default="{ row }">
                  <span :class="{ 'live-duration': !row.logoutTime }">{{ getDuration(row, liveTick) }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="ipAddress" label="客户端IP" align="center" />
              <el-table-column prop="userAgent" label="浏览器" align="center">
                <template #default="{ row }">
                  <span :title="row.userAgent">{{ parseBrowserName(row.userAgent) }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="tabId" label="SSE连接标识" align="center" />
            </el-table>
            </div>
          </div>
          <div class="pagination-wrapper" v-if="historyTotal > 0">
            <span class="pagination-total">共 {{ historyTotal }} 条</span>
            <el-pagination v-model:current-page="historyPage" :page-size="historyPageSize" :total="historyTotal" layout="prev, pager, next" @current-change="handleHistoryPageChange" background />
          </div>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<style scoped>
.online-page {
  display: flex; flex-direction: column; height: 100%; box-sizing: border-box; user-select: none;
}
/* Tabs */
.page-tabs {
  flex: 1; min-height: 0; display: flex; flex-direction: column;
}
.page-tabs :deep(.el-tabs__content) {
  flex: 1; min-height: 0; display: flex; flex-direction: column;
}
.page-tabs :deep(.el-tab-pane) {
  flex: 1; min-height: 0; display: flex; flex-direction: column;
}
.page-tabs :deep(.el-tab-pane[name="history"]) {
  padding-bottom: 16px;
}
.page-tabs :deep(.el-tabs__header) {
  margin-bottom: 12px;
}
.page-tabs :deep(.el-tabs__nav-wrap::after) {
  height: 1px;
  background: #e2e8f0;
}
.page-tabs :deep(.el-tabs__item) {
  font-size: 15px;
  font-weight: 600;
  color: #909399;
  padding: 0 20px;
  text-align: center;
  transition: color 0.2s;
}
.page-tabs :deep(.el-tabs__item:hover) {
  color: #606266;
}
.page-tabs :deep(.el-tabs__item.is-active) {
  color: #409eff;
  font-weight: 700;
}

/* 统计卡片 - 参照系统通知页面风格 */
.stats-row {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 16px;
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
.stat-total {
  background: linear-gradient(135deg, #e3f2fd, #bbdefb);
  border-color: #90caf9;
}
.stat-total .stat-icon { background: rgba(33,150,243,0.15); color: #1565c0; }
.stat-total .stat-value { color: #0d47a1; }
.stat-total .stat-label { color: #1565c0; }
.stat-online {
  background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  border-color: #a5d6a7;
}
.stat-online .stat-icon { background: rgba(76,175,80,0.15); color: #2e7d32; }
.stat-online .stat-value { color: #1b5e20; }
.stat-online .stat-label { color: #2e7d32; }
.stat-offline {
  background: linear-gradient(135deg, #fff3e0, #ffe0b2);
  border-color: #ffcc80;
}
.stat-offline .stat-icon { background: rgba(255,152,0,0.15); color: #e65100; }
.stat-offline .stat-value { color: #bf360c; }
.stat-offline .stat-label { color: #e65100; }

/* 列表卡片 */
.list-card {
  flex: 1; border-radius: 10px; overflow: hidden; display: flex; flex-direction: column;
}
/* 修复el-card__body的高度链断裂，使其参与flex布局 */
.list-card :deep(.el-card__body) {
  flex: 1; display: flex; flex-direction: column; padding: 16px 20px; overflow: hidden;
}
.table-wrapper { flex: 1; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
.table-toolbar {
  display: flex; justify-content: space-between; align-items: center; padding: 2px 0 8px; flex-shrink: 0;
}
.toolbar-title { font-size: 14px; font-weight: 600; color: #303133; user-select: none; }
.toolbar-sep { width: 1px; height: 24px; background: #e2e8f0; flex-shrink: 0; }
.toolbar-hint { font-size: 12px; color: #c0c4cc; }
.toolbar-left { display: flex; align-items: center; gap: 12px; }
.toolbar-actions { display: flex; gap: 8px; flex-shrink: 0; }

/* 刷新按钮 */
.toolbar-btn-refresh {
  width: 32px; height: 32px; padding: 0; border-radius: 8px !important;
  display: inline-flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #f0f2f5, #e8eaef); border: none;
  transition: all 0.25s ease;
}
.toolbar-btn-refresh:hover {
  background: linear-gradient(135deg, #e5e7eb, #dcdde2);
  transform: translateY(-1px);
}

/* 历史记录过滤栏 */
/* 过滤栏 */
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

.search-btn, .reset-btn {
  padding: 0 10px; min-width: auto; height: 32px;
  border-radius: 8px !important; display: inline-flex;
  align-items: center; justify-content: center; gap: 5px;
  font-size: 13px; font-weight: 500; border: none; color: #fff;
  transition: all 0.25s ease;
}
.search-btn { background: linear-gradient(135deg, #409eff, #337ecc); }
.search-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 14px rgba(64,158,255,0.4); }
.reset-btn { background: linear-gradient(135deg, #e6a23c, #c68a2e); }
.reset-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 14px rgba(230,162,60,0.4); }

/* 状态指示圆点 + 文字 */
.status-indicator {
  display: inline-flex; align-items: center; gap: 5px; justify-content: center;
}
.status-indicator::before {
  content: ''; width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; transition: all 0.3s;
}
.status-indicator.on::before { background: #67c23a; box-shadow: 0 0 4px rgba(103,194,58,0.5); }
.status-indicator.off::before { background: #c0c4cc; }
.status-text { font-size: 13px; font-weight: 500; }
.status-text.on { color: #67c23a; }
.status-text.off { color: #909399; }

.user-name { font-size: 14px; font-weight: 500; color: #303133; }

/* 离线时间列在线状态 */
.inline-online { display: inline-flex; align-items: center; gap: 5px; color: #67c23a; font-weight: 500; }
.online-dot { width: 8px; height: 8px; border-radius: 50%; background: #67c23a; box-shadow: 0 0 4px rgba(103,194,58,0.5); flex-shrink: 0; }

/* 动态在线时长 */
.live-duration {
  color: #67c23a;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

/* 图标 */
.icon-svg {
  width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-width: 2;
  stroke-linecap: round; stroke-linejoin: round;
}
.icon-svg.sm { width: 14px; height: 14px; }

/* 表格 & 分页 */
.table-body-area { flex: 1; min-height: 0; }
/* 展开行明细区域 */
.expand-detail { padding: 8px 12px; background: #fafafa; border-radius: 6px; }
.pagination-wrapper {
  display: flex; justify-content: space-between; align-items: center;
  flex-shrink: 0; padding: 16px 16px 4px;
}
.pagination-total {
  font-size: 13px; color: #606266;
}

/* 分页紫色主题（与备忘录一致） */
.pagination-wrapper :deep(.el-pagination.is-background .el-pager li:not(.is-disabled).is-active) {
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  color: #fff;
}
.text-ellipsis {
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block;
}
</style>
