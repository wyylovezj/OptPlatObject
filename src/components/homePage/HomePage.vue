<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：首页 - 告警数据统计展示（重新设计版）
 * @date： 2026-04-22
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-04-24
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Bell, Warning, CircleCheck, Clock, TrendCharts, DataAnalysis, Document, Timer } from '@element-plus/icons-vue'
import { ElScrollbar } from 'element-plus'

const router = useRouter()

// 模拟告警统计数据
const alarmStats = ref({
  todayTotal: 156,
  yesterdayTotal: 142,
  criticalCount: 23,
  criticalRate: 14.74,
  warningCount: 87,
  warningRate: 55.77,
  infoCount: 46,
  infoRate: 29.49,
  resolvedCount: 134,
  resolveRate: 85.9,
  pendingCount: 22,
  avgHandleTime: 2.5,
  monthTotal: 4523,
  weekTotal: 1089,
  criticalTrend: [5, 8, 3, 6, 4, 7, 2],
  overtimeCount: 8,
  estimatedCompleteTime: '16:30',
  fastestHandleTime: 0.5,
  slowestHandleTime: 8.2,
  todayResolved: 89,
  weekResolved: 623,
})

// 计算环比变化
const totalChange = computed(() => {
  const change = (((alarmStats.value.todayTotal - alarmStats.value.yesterdayTotal) / alarmStats.value.yesterdayTotal) * 100).toFixed(1)
  return parseFloat(change)
})

// 告警级别分布数据
const alarmLevelData = computed(() => [
  {
    label: '严重',
    value: alarmStats.value.criticalCount,
    rate: alarmStats.value.criticalRate,
    color: '#ff4757',
    icon: Warning,
  },
  {
    label: '警告',
    value: alarmStats.value.warningCount,
    rate: alarmStats.value.warningRate,
    color: '#ffa502',
    icon: Bell,
  },
  {
    label: '提示',
    value: alarmStats.value.infoCount,
    rate: alarmStats.value.infoRate,
    color: '#2ed573',
    icon: DataAnalysis,
  },
])

// 处理状态分布
const statusData = computed(() => [
  {
    label: '已处理',
    value: alarmStats.value.resolvedCount,
    rate: alarmStats.value.resolveRate,
    color: '#1e90ff',
    bgColor: 'rgba(30, 144, 255, 0.1)',
  },
  {
    label: '待处理',
    value: alarmStats.value.pendingCount,
    rate: (100 - alarmStats.value.resolveRate).toFixed(2),
    color: '#ff6348',
    bgColor: 'rgba(255, 99, 72, 0.1)',
  },
])

// 最近告警趋势（模拟7天数据）
const trendData = ref([
  { day: '周一', count: 128 },
  { day: '周二', count: 145 },
  { day: '周三', count: 132 },
  { day: '周四', count: 156 },
  { day: '周五', count: 142 },
  { day: '周六', count: 98 },
  { day: '周日', count: 87 },
])

// 计算趋势最大值用于进度条
const maxTrendValue = computed(() => Math.max(...trendData.value.map((item) => item.count)))

// OA待办工单数据 - 按类型分类
const oaTodoList = ref({
  publish: [
    { id: 'OA2026042401', title: '系统升级审批', applicant: '张三', type: '审批', priority: 'high', createTime: '2026-04-24 09:15', status: 'pending' },
    { id: 'OA2026042402', title: '采购申请审核', applicant: '李四', type: '审核', priority: 'medium', createTime: '2026-04-24 10:30', status: 'pending' },
    { id: 'OA2026042402', title: '采购申请审核', applicant: '李四', type: '审核', priority: 'medium', createTime: '2026-04-24 10:30', status: 'pending' },
    { id: 'OA2026042402', title: '采购申请审核', applicant: '李四', type: '审核', priority: 'medium', createTime: '2026-04-24 10:30', status: 'pending' },
  ],
  event: [
    { id: 'OA2026042403', title: '请假申请审批', applicant: '王五', type: '审批', priority: 'low', createTime: '2026-04-24 11:20', status: 'processing' },
    { id: 'OA2026042404', title: '费用报销审核', applicant: '赵六', type: '审核', priority: 'medium', createTime: '2026-04-24 13:45', status: 'pending' },
  ],
  change: [
  ],
})

// 当前激活的标签页
const activeTab = ref('publish')

// 获取当前标签页的工单列表
const currentTodoList = computed(() => {
  return oaTodoList.value[activeTab.value] || []
})

// 获取各类型工单数量
const todoCounts = computed(() => ({
  publish: oaTodoList.value.publish.length,
  event: oaTodoList.value.event.length,
  change: oaTodoList.value.change.length,
}))

// OA本周统计数据
const oaWeekStats = ref({
  total: 45,
  completed: 38,
  processing: 5,
  pending: 2,
  avgProcessTime: 1.8,
  completionRate: 84.44,
})

// 格式化数字
const formatNumber = (num) => {
  return num.toLocaleString('zh-CN')
}

// 获取优先级标签类型
const getPriorityType = (priority) => {
  const map = { high: 'danger', medium: 'warning', low: 'info' }
  return map[priority] || 'info'
}

// 获取优先级文本
const getPriorityText = (priority) => {
  const map = { high: '紧急', medium: '普通', low: '低' }
  return map[priority] || '普通'
}

// 跳转到告警列表
const goToAlarmList = () => {
  router.push('/alarmManagement/alarmItem')
}

onMounted(() => {
  console.log('首页数据加载完成')
})
</script>

<template>
  <div class="dashboard-container">
    <!-- 主内容区：左右3:1布局 -->
    <div class="main-content">
      <!-- 左侧：告警统计（占3份） -->
      <div class="left-panel">
        <!-- 顶部欢迎区域 -->
        <div class="welcome-section">
          <div class="welcome-content">
            <h1 class="welcome-title">
              <el-icon :size="32"><TrendCharts /></el-icon>
              告警监控中心
            </h1>
            <p class="welcome-subtitle">实时掌握系统运行状态，快速响应异常情况</p>
          </div>
          <div class="time-badge">
            <el-icon :size="18"><Clock /></el-icon>
            <span class="time-text">{{
                new Date()
                  .toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })
                  .replace(/(\d{4}年\d{1,2}月\d{1,2}日)(.+)/, '$1   $2')
              }}</span>
          </div>
        </div>

        <!-- 核心指标卡片 -->
        <div class="metrics-grid">
          <!-- 今日告警总数 -->
          <div class="metric-card metric-primary">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Bell /></el-icon>
                </div>
                <div class="metric-trend" :class="totalChange >= 0 ? 'trend-up' : 'trend-down'">
                  <span class="trend-arrow">{{ totalChange >= 0 ? '↑' : '↓' }}</span>
                  <span>{{ Math.abs(totalChange) }}%</span>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ formatNumber(alarmStats.todayTotal) }}</div>
                <div class="metric-label">今日告警总数</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">昨日</span>
                  <span class="detail-value">{{ formatNumber(alarmStats.yesterdayTotal) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">本周</span>
                  <span class="detail-value">{{ formatNumber(alarmStats.weekTotal) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">本月</span>
                  <span class="detail-value">{{ formatNumber(alarmStats.monthTotal) }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 严重告警 -->
          <div class="metric-card metric-danger">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Warning /></el-icon>
                </div>
                <div class="metric-rate-badge">{{ alarmStats.criticalRate }}%</div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ formatNumber(alarmStats.criticalCount) }}</div>
                <div class="metric-label">严重告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row highlight">
                  <span class="detail-label">需立即处理</span>
                  <span class="detail-value danger-text">{{ alarmStats.criticalCount }} 条</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">占比</span>
                  <span class="detail-value">{{ alarmStats.criticalRate }}%</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 处理率 -->
          <div class="metric-card metric-success">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><CircleCheck /></el-icon>
                </div>
                <div class="metric-rate-badge success">{{ alarmStats.resolveRate }}%</div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ formatNumber(alarmStats.resolvedCount) }}</div>
                <div class="metric-label">已处理告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row">
                  <span class="detail-label">平均耗时</span>
                  <span class="detail-value">{{ alarmStats.avgHandleTime }}h</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">最快处理</span>
                  <span class="detail-value">{{ alarmStats.fastestHandleTime }}h</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">最慢处理</span>
                  <span class="detail-value">{{ alarmStats.slowestHandleTime }}h</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 待处理 -->
          <div class="metric-card metric-warning">
            <div class="metric-bg-pattern"></div>
            <div class="metric-content">
              <div class="metric-header">
                <div class="metric-icon-wrapper">
                  <el-icon :size="28"><Clock /></el-icon>
                </div>
                <div class="metric-pending-indicator">
                  <span class="pulse-dot"></span>
                  <span>进行中</span>
                </div>
              </div>
              <div class="metric-body">
                <div class="metric-value">{{ formatNumber(alarmStats.pendingCount) }}</div>
                <div class="metric-label">待处理告警</div>
              </div>
              <div class="metric-details">
                <div class="detail-row highlight">
                  <span class="detail-label">超时未处理</span>
                  <span class="detail-value warning-text">{{ alarmStats.overtimeCount }} 条</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">预计完成</span>
                  <span class="detail-value">{{ alarmStats.estimatedCompleteTime }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">本月累计</span>
                  <span class="detail-value">{{ formatNumber(alarmStats.monthTotal) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 中间数据展示区：整合为两个卡片 -->
        <div class="data-showcase-integrated">
          <!-- 告警总数统计卡片 -->
          <div class="data-panel stats-panel">
            <div class="panel-header">
              <div class="panel-title">
                <span class="title-bar"></span>
                <h3>告警总数统计</h3>
              </div>
              <span class="panel-subtitle">综合数据分析</span>
            </div>
            <div class="panel-body stats-body">
              <div class="stats-content">
                <!-- 告警级别分布 -->
                <div class="stats-section">
                  <div class="section-title">告警级别分布</div>
                  <div class="level-items">
                    <div v-for="(level, index) in alarmLevelData" :key="level.label" class="level-item-modern" :style="{ animationDelay: `${index * 0.1}s` }">
                      <div class="level-main">
                        <div class="level-icon-box" :style="{ backgroundColor: level.color + '20' }">
                          <el-icon :size="22" :color="level.color">
                            <component :is="level.icon" />
                          </el-icon>
                        </div>
                        <div class="level-info">
                          <div class="level-name">{{ level.label }}</div>
                          <div class="level-count-large">{{ formatNumber(level.value) }}</div>
                        </div>
                      </div>
                      <div class="level-progress-modern">
                        <div class="progress-track">
                          <div
                            class="progress-fill"
                            :style="{
                              width: level.rate + '%',
                              background: `linear-gradient(90deg, ${level.color}, ${level.color}dd)`,
                            }"
                          ></div>
                        </div>
                        <div class="progress-label">{{ level.rate }}%</div>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 处理状态 -->
                <div class="stats-section">
                  <div class="section-title">处理状态</div>
                  <div class="status-circles">
                    <div v-for="status in statusData" :key="status.label" class="status-circle-item">
                      <div class="circle-wrapper">
                        <svg class="circle-svg" viewBox="0 0 100 100">
                          <circle class="circle-bg" cx="50" cy="50" r="40" :stroke="status.bgColor" />
                          <circle class="circle-progress" cx="50" cy="50" r="40" :stroke="status.color" :stroke-dasharray="`${status.rate * 2.51} 251`" />
                        </svg>
                        <div class="circle-center">
                          <div class="circle-value">{{ status.rate }}%</div>
                        </div>
                      </div>
                      <div class="circle-label">{{ status.label }}</div>
                      <div class="circle-count">{{ formatNumber(status.value) }}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- 处理时效卡片 -->
          <div class="data-panel timing-panel">
            <div class="panel-header">
              <div class="panel-title">
                <span class="title-bar"></span>
                <h3>处理时效分析</h3>
              </div>
              <span class="panel-subtitle">时间维度统计</span>
            </div>
            <div class="panel-body timing-body">
              <div class="timing-content">
                <!-- 告警趋势 -->
                <div class="timing-section">
                  <div class="section-title">近7天告警趋势</div>
                  <div class="trend-chart">
                    <div v-for="(item, index) in trendData" :key="item.day" class="trend-bar-wrapper" :style="{ animationDelay: `${index * 0.08}s` }">
                      <div class="trend-bar-container">
                        <div
                          class="trend-bar"
                          :style="{
                            height: (item.count / maxTrendValue) * 100 + '%',
                            background: `linear-gradient(180deg, #667eea 0%, #764ba2 100%)`,
                          }"
                        >
                          <div class="trend-bar-value">{{ item.count }}</div>
                        </div>
                      </div>
                      <div class="trend-bar-label">{{ item.day }}</div>
                    </div>
                  </div>
                </div>

                <!-- 处理时间统计 -->
                <div class="timing-section">
                  <div class="section-title">处理时间统计</div>
                  <div class="time-stats-grid">
                    <div class="time-stat-card">
                      <div class="stat-icon avg">
                        <el-icon :size="24"><Timer /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">平均处理时长</div>
                        <div class="stat-value">{{ alarmStats.avgHandleTime }}h</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon fast">
                        <el-icon :size="24"><Clock /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">最快处理</div>
                        <div class="stat-value">{{ alarmStats.fastestHandleTime }}h</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon slow">
                        <el-icon :size="24"><Clock /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">最慢处理</div>
                        <div class="stat-value">{{ alarmStats.slowestHandleTime }}h</div>
                      </div>
                    </div>
                    <div class="time-stat-card">
                      <div class="stat-icon overtime">
                        <el-icon :size="24"><Warning /></el-icon>
                      </div>
                      <div class="stat-info">
                        <div class="stat-label">超时工单</div>
                        <div class="stat-value danger">{{ alarmStats.overtimeCount }}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 右侧：OA待办（占1份） -->
      <div class="right-panel">
        <!-- 上半部分：实时待办工单（占2份） -->
        <div class="oa-section oa-todo-list">
          <div class="section-header">
            <div class="section-title">
<!--              <el-icon :size="18"><Document /></el-icon>-->
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-daiban"></use>
              </svg>
              <h3>ITSM 待办</h3>
            </div>
          </div>
          <div class="section-body">
            <el-tabs v-model="activeTab" class="oa-tabs">
              <el-tab-pane name="publish">
                <template #label>
                  <span class="tab-label">
                    发布
                    <el-tag size="small" type="primary" effect="plain">{{ todoCounts.publish }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list">
                    <div v-for="todo in currentTodoList" :key="todo.id" class="todo-item">
                      <div class="todo-header">
                        <span class="todo-id">{{ todo.id }}</span>
                        <el-tag :type="getPriorityType(todo.priority)" size="small">{{ getPriorityText(todo.priority) }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" :type="todo.status === 'pending' ? 'warning' : 'primary'">
                          {{ todo.status === 'pending' ? '待处理' : '处理中' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无待办工单" :image-size="60" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>

              <el-tab-pane name="event">
                <template #label>
                  <span class="tab-label">
                    事件
                    <el-tag size="small" type="success" effect="plain">{{ todoCounts.event }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list">
                    <div v-for="todo in currentTodoList" :key="todo.id" class="todo-item">
                      <div class="todo-header">
                        <span class="todo-id">{{ todo.id }}</span>
                        <el-tag :type="getPriorityType(todo.priority)" size="small">{{ getPriorityText(todo.priority) }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" :type="todo.status === 'pending' ? 'warning' : 'primary'">
                          {{ todo.status === 'pending' ? '待处理' : '处理中' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无待办工单" :image-size="60" />
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>

              <el-tab-pane name="change">
                <template #label>
                  <span class="tab-label">
                    变更
                    <el-tag size="small" type="warning" effect="plain">{{ todoCounts.change }}</el-tag>
                  </span>
                </template>
                <el-scrollbar class="todo-scrollbar">
                  <div class="todo-list">
                    <div v-for="todo in currentTodoList" :key="todo.id" class="todo-item">
                      <div class="todo-header">
                        <span class="todo-id">{{ todo.id }}</span>
                        <el-tag :type="getPriorityType(todo.priority)" size="small">{{ getPriorityText(todo.priority) }}</el-tag>
                      </div>
                      <div class="todo-title">{{ todo.title }}</div>
                      <div class="todo-meta">
                        <span class="meta-item">申请人：{{ todo.applicant }}</span>
                        <span class="meta-item">{{ todo.createTime }}</span>
                      </div>
                      <div class="todo-footer">
                        <el-tag size="small" :type="todo.status === 'pending' ? 'warning' : 'primary'">
                          {{ todo.status === 'pending' ? '待处理' : '处理中' }}
                        </el-tag>
                      </div>
                    </div>
                    <div v-if="currentTodoList.length === 0" class="empty-state">
                      <el-empty description="暂无待办工单"/>
                    </div>
                  </div>
                </el-scrollbar>
              </el-tab-pane>
            </el-tabs>
          </div>
        </div>

        <!-- 下半部分：本周工单统计（占1份） -->
        <div class="oa-section oa-week-stats">
          <div class="section-header">
            <div class="section-title">
              <el-icon :size="18"><TrendCharts /></el-icon>
              <h3>本周工单统计</h3>
            </div>
          </div>
          <div class="section-body">
            <div class="week-stats-content">
              <div class="stats-overview">
                <div class="overview-item total">
                  <div class="overview-value">{{ oaWeekStats.total }}</div>
                  <div class="overview-label">工单总数</div>
                </div>
                <div class="overview-item completed">
                  <div class="overview-value">{{ oaWeekStats.completed }}</div>
                  <div class="overview-label">已完成</div>
                </div>
              </div>
              <div class="stats-details">
                <div class="detail-item">
                  <span class="detail-label">处理中</span>
                  <span class="detail-value primary">{{ oaWeekStats.processing }}</span>
                </div>
                <div class="detail-item">
                  <span class="detail-label">待处理</span>
                  <span class="detail-value warning">{{ oaWeekStats.pending }}</span>
                </div>
                <div class="detail-item">
                  <span class="detail-label">完成率</span>
                  <span class="detail-value success">{{ oaWeekStats.completionRate }}%</span>
                </div>
                <div class="detail-item">
                  <span class="detail-label">平均耗时</span>
                  <span class="detail-value">{{ oaWeekStats.avgProcessTime }}h</span>
                </div>
              </div>
              <div class="completion-progress">
                <div class="progress-label">
                  <span>完成进度</span>
                  <span>{{ oaWeekStats.completionRate }}%</span>
                </div>
                <div class="progress-bar">
                  <div class="progress-fill" :style="{ width: oaWeekStats.completionRate + '%' }"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-container {
  padding: 20px 28px;
  background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  border-radius: 10px;
  user-select: none;
}

/* 主内容区：左右3:1布局 */
.main-content {
  display: grid;
  grid-template-columns: 3fr 1fr;
  gap: 16px;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

/* 左侧面板 */
.left-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

/* 欢迎区域 */
.welcome-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 16px;
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.25);
  position: relative;
  overflow: hidden;
  flex-shrink: 0;
}

.welcome-section::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -10%;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
  border-radius: 50%;
}

.welcome-content {
  position: relative;
  z-index: 1;
}

.welcome-title {
  margin: 0 0 6px 0;
  font-size: 24px;
  font-weight: 700;
  color: #fff;
  display: flex;
  align-items: center;
  gap: 10px;
}

.title-icon {
  font-size: 28px;
}

.welcome-subtitle {
  margin: 0;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.85);
  letter-spacing: 0.5px;
}

.time-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border-radius: 24px;
  color: #fff;
  font-size: 13px;
  font-weight: 500;
  position: relative;
  z-index: 1;
}
.time-badge :deep(.el-icon) {
  display: flex;
  align-items: center;
}
.time-icon {
  font-size: 18px;
}
.time-text {
  white-space: pre;
}

/* 核心指标网格 */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  flex-shrink: 0;
}

.metric-card {
  position: relative;
  border-radius: 16px;
  overflow: hidden;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
}

.metric-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.15);
}

.metric-bg-pattern {
  position: absolute;
  top: 0;
  right: 0;
  width: 120px;
  height: 120px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.15) 0%, transparent 70%);
  border-radius: 50%;
  transform: translate(30%, -30%);
}

.metric-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.metric-danger {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.metric-success {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
}

.metric-warning {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
}

.metric-content {
  position: relative;
  z-index: 1;
  padding: 18px 20px;
  color: #fff;
}

.metric-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.metric-icon-wrapper {
  width: 46px;
  height: 46px;
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
}

.metric-primary .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
}

.metric-danger .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(255, 71, 87, 0.3));
}

.metric-success .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(30, 144, 255, 0.3));
}

.metric-warning .metric-icon-wrapper :deep(.el-icon) {
  color: #fff;
  filter: drop-shadow(0 2px 6px rgba(255, 165, 2, 0.3));
}

.metric-trend {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.trend-up {
  background: rgba(46, 213, 115, 0.3);
}

.trend-down {
  background: rgba(255, 71, 87, 0.3);
}

.trend-arrow {
  font-size: 14px;
  line-height: 1;
  display: inline-flex;
  align-items: center;
  transform: translateY(-3px);
}
.metric-rate-badge {
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.metric-rate-badge.success {
  background: rgba(46, 213, 115, 0.3);
}

.metric-pending-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.pulse-dot {
  width: 8px;
  height: 8px;
  background: #fff;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%,
  100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.5;
    transform: scale(1.2);
  }
}

.metric-body {
  margin-bottom: 10px;
}

.metric-value {
  font-size: 32px;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 4px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.metric-label {
  font-size: 13px;
  opacity: 0.9;
  font-weight: 500;
}

.metric-details {
  margin-bottom: 0;
  padding: 8px 10px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  backdrop-filter: blur(5px);
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 3px 0;
  font-size: 11px;
}

.detail-row:not(:last-child) {
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.detail-row.highlight {
  background: rgba(255, 255, 255, 0.05);
  margin: 0 -10px;
  padding: 5px 10px;
  border-radius: 4px;
}

.detail-label {
  opacity: 0.85;
  font-weight: 500;
}

.detail-value {
  font-weight: 600;
}

.danger-text {
  color: #ffe0e0;
  font-weight: 700;
}

.warning-text {
  color: #fff5d6;
  font-weight: 700;
}

/* 数据展示区：整合为两个卡片 */
.data-showcase-integrated {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.data-panel {
  background: #fff;
  border-radius: 16px;
  padding: 18px 20px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
  transition: all 0.3s ease;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.data-panel:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  flex-shrink: 0;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.title-bar {
  width: 4px;
  height: 18px;
  background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
  border-radius: 2px;
}

.panel-title h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #2d3436;
}

.panel-subtitle {
  font-size: 11px;
  color: #b2bec3;
}

.panel-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.stats-body,
.timing-body {
  display: flex;
  align-items: stretch;
}

.stats-content,
.timing-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  width: 100%;
}

.stats-section,
.timing-section {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.section-title {
  font-size: 13px;
  font-weight: 600;
  color: #636e72;
  margin-bottom: 12px;
  padding-left: 8px;
  border-left: 3px solid #667eea;
}

/* 告警级别分布 */
.level-items {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
}

.level-item-modern {
  animation: slideInLeft 0.5s ease-out forwards;
  opacity: 0;
}

@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.level-main {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
}

.level-icon-box {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.level-icon-box :deep(.el-icon) {
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
}

.level-info {
  flex: 1;
}

.level-name {
  font-size: 12px;
  color: #636e72;
  margin-bottom: 3px;
}

.level-count-large {
  font-size: 20px;
  font-weight: 700;
  color: #2d3436;
}

.level-progress-modern {
  display: flex;
  align-items: center;
  gap: 8px;
}

.progress-track {
  flex: 1;
  height: 6px;
  background: #f0f2f5;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
}

.progress-label {
  font-size: 12px;
  font-weight: 600;
  color: #636e72;
  min-width: 40px;
  text-align: right;
}

/* 状态圆环 */
.status-circles {
  display: flex;
  justify-content: space-around;
  align-items: center;
  gap: 16px;
}

.status-circle-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.circle-wrapper {
  position: relative;
  width: 80px;
  height: 80px;
}

.circle-svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.circle-bg {
  fill: none;
  stroke-width: 8;
}

.circle-progress {
  fill: none;
  stroke-width: 8;
  stroke-linecap: round;
  transition: stroke-dasharray 0.8s ease;
}

.circle-center {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  text-align: center;
}

.circle-value {
  font-size: 16px;
  font-weight: 700;
  color: #2d3436;
}

.circle-label {
  font-size: 12px;
  color: #636e72;
  font-weight: 500;
}

.circle-count {
  font-size: 14px;
  font-weight: 700;
  color: #2d3436;
}

/* 趋势图表 */
.trend-chart {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  height: 140px;
  gap: 8px;
  padding-top: 10px;
  width: 100%;
}

.trend-bar-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  animation: fadeInUp 0.6s ease-out forwards;
  opacity: 0;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.trend-bar-container {
  width: 100%;
  height: 110px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.trend-bar {
  width: 100%;
  max-width: 32px;
  border-radius: 6px 6px 0 0;
  position: relative;
  transition: all 0.3s ease;
  cursor: pointer;
}

.trend-bar:hover {
  opacity: 0.8;
  transform: scaleY(1.05);
}

.trend-bar-value {
  position: absolute;
  top: -20px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 11px;
  font-weight: 600;
  color: #667eea;
  white-space: nowrap;
}

.trend-bar-label {
  font-size: 11px;
  color: #636e72;
  font-weight: 500;
}

/* 处理时间统计网格 */
.time-stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.time-stat-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 10px;
  transition: all 0.3s ease;
}

.time-stat-card:hover {
  background: #f0f2f5;
  transform: translateY(-2px);
}

.stat-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-icon.avg {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
}

.stat-icon.fast {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: #fff;
}

.stat-icon.slow {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
  color: #fff;
}

.stat-icon.overtime {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
  color: #fff;
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 11px;
  color: #636e72;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 18px;
  font-weight: 700;
  color: #2d3436;
}

.stat-value.danger {
  color: #ff4757;
}

/* 右侧面板 */
.right-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

/* OA区域通用样式 */
.oa-section {
  background: #fff;
  border-radius: 16px;
  padding: 16px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: all 0.3s ease;
}

.oa-section:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
}

.oa-todo-list {
  flex: 2;
}

.oa-week-stats {
  flex: 1;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  flex-shrink: 0;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.section-title h3 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: #2d3436;
}

.section-title :deep(.el-icon) {
  color: #667eea;
}

.section-badge {
  padding: 4px 10px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.section-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

/* Element Plus Tabs样式 */
.oa-tabs {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.oa-tabs :deep(.el-tabs__header) {
  margin: 0 0 12px 0;
  flex-shrink: 0;
}

.oa-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0 4px;
}

.oa-tabs :deep(.el-tabs__content) {
  flex: 1;
  overflow: hidden;
  height: 0;
}

.oa-tabs :deep(.el-tab-pane) {
  height: 100%;
}

.tab-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
}

.tab-label :deep(.el-tag) {
  margin-left: 2px;
}

/* Element Plus滚动条样式 */
.todo-scrollbar {
  height: 100%;
  width: 100%;
}

.todo-scrollbar :deep(.el-scrollbar__wrap) {
  overflow-x: hidden;
}

.todo-scrollbar :deep(.el-scrollbar__bar.is-vertical) {
  width: 8px;
  right: 4px;
}

.todo-scrollbar :deep(.el-scrollbar__thumb) {
  background-color: rgba(144, 147, 153, 0.3);
  border-radius: 4px;
  transition: all 0.3s ease;
}

.todo-scrollbar :deep(.el-scrollbar__thumb:hover) {
  background-color: rgba(144, 147, 153, 0.5);
}

/* 待办工单列表 */
.todo-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  height: 100%;
  padding-right: 8px;
}

.todo-item {
  padding: 12px;
  background: #f8f9fa;
  border-radius: 10px;
  border-left: 3px solid #667eea;
  transition: all 0.3s ease;
  min-width: 0;
}

.todo-item:hover {
  background: #f0f2f5;
  transform: translateX(4px);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.todo-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
  flex-wrap: wrap;
  gap: 4px;
}

.todo-id {
  font-size: 11px;
  color: #b2bec3;
  font-weight: 500;
  word-break: break-all;
  flex-shrink: 0;
}

.todo-title {
  font-size: 13px;
  font-weight: 600;
  color: #2d3436;
  margin-bottom: 6px;
  line-height: 1.4;
  word-break: break-word;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.todo-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 11px;
  color: #636e72;
  margin-bottom: 6px;
  flex-wrap: wrap;
  gap: 4px;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 4px;
  word-break: break-all;
  flex-shrink: 0;
}

.todo-footer {
  display: flex;
  justify-content: flex-end;
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  min-height: 150px;
}

/* 本周工单统计 */
.week-stats-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
  height: 100%;
}

.stats-overview {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
}

.overview-item {
  padding: 12px;
  border-radius: 10px;
  text-align: center;
  transition: all 0.3s ease;
}

.overview-item:hover {
  transform: translateY(-2px);
}

.overview-item.total {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
}

.overview-item.completed {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: #fff;
}

.overview-value {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 4px;
}

.overview-label {
  font-size: 11px;
  opacity: 0.9;
}

.stats-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.detail-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 10px;
  background: #f8f9fa;
  border-radius: 8px;
}

.detail-label {
  font-size: 12px;
  color: #636e72;
}

.detail-value {
  font-size: 14px;
  font-weight: 700;
  color: #2d3436;
}

.detail-value.primary {
  color: #1e90ff;
}

.detail-value.warning {
  color: #ffa502;
}

.detail-value.success {
  color: #2ed573;
}

.completion-progress {
  margin-top: auto;
}

.progress-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #636e72;
  margin-bottom: 6px;
  font-weight: 600;
}

.progress-bar {
  height: 8px;
  background: #f0f2f5;
  border-radius: 4px;
  overflow: hidden;
}

.progress-bar .progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
  border-radius: 4px;
  transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
}

/* 响应式调整 */
@media (max-width: 1400px) {
  .main-content {
    grid-template-columns: 1fr;
  }

  .right-panel {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
  }

  .oa-todo-list {
    flex: none;
  }

  .oa-week-stats {
    flex: none;
  }
}

@media (max-width: 1200px) {
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .data-showcase-integrated {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .dashboard-container {
    padding: 12px;
  }

  .welcome-section {
    flex-direction: column;
    gap: 12px;
    text-align: center;
    padding: 14px 18px;
  }

  .welcome-title {
    font-size: 20px;
  }

  .metrics-grid {
    grid-template-columns: 1fr;
  }

  .metric-value {
    font-size: 28px;
  }

  .data-showcase-integrated {
    grid-template-columns: 1fr;
  }

  .right-panel {
    grid-template-columns: 1fr;
  }

  .time-stats-grid {
    grid-template-columns: 1fr;
  }
}
.icon {
  width: 1.5em;
  height: 1.5em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
</style>
