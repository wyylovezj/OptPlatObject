<script setup>
import { ref, reactive, computed } from 'vue'
import { Plus, ArrowLeft, ArrowRight, Document, Edit, Paperclip } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'

// ============ 日期导航 ============
const logDate = ref(new Date(2026, 4, 12)) // May 12, 2026

const logDateLabel = computed(() => {
  const days = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  const d = logDate.value
  return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日 · ' + days[d.getDay()]
})

const shiftLogDate = (dir) => {
  logDate.value.setDate(logDate.value.getDate() + dir)
  logDate.value = new Date(logDate.value)
}

const goLogToday = () => {
  logDate.value = new Date(2026, 4, 12)
}

// ============ 日志条目 ============
const logEntries = ref([
  {
    time: '09:00',
    dotClass: 'success',
    title: '早班到岗 · 常规巡检',
    desc: '完成机房巡检，设备运行正常。检查空调、UPS、消防系统状态均正常。核对监控大屏各项指标。',
    tags: [{ text: '巡检', class: 'info' }],
  },
  {
    time: '09:45',
    dotClass: 'warn',
    title: '告警触发 · MQ-03 消息积压',
    desc: '中间件 MQ-03 节点消费者组异常停止，消息积压 1200+ 条。已重启消费者组服务，积压正在消化中，预计 2 小时内恢复。',
    tags: [
      { text: '告警', class: 'alert' },
      { text: '已恢复', class: 'resolve' },
    ],
  },
  {
    time: '11:30',
    dotClass: '',
    title: '工单处理 · 用户权限申请',
    desc: '处理研发部 3 例数据库只读权限申请，已审批并配置完成。关联工单 #4583 - #4585。',
    tags: [{ text: '工单', class: 'info' }],
  },
  {
    time: '14:00',
    dotClass: '',
    title: '专项巡检 · 存储阵列 DS-02',
    desc: '针对凌晨 DS-02 IOPS 飙升事件做专项巡检。磁盘 SMART 状态正常，RAID 组无降级。已联系厂商远程协助分析，初步判断为缓存策略触发。',
    tags: [
      { text: '巡检', class: 'info' },
      { text: '待跟进', class: 'warn' },
    ],
  },
  {
    time: '15:20',
    dotClass: 'danger',
    title: '告警触发 · Web 前端集群 CPU 过载',
    desc: 'Web-Node-05 CPU 使用率持续 >90% 超过 5 分钟。经排查为某接口死循环导致，已通知开发紧急修复并临时限流。当前 CPU 已降至 45%。',
    tags: [
      { text: '紧急', class: 'alert' },
      { text: '已恢复', class: 'resolve' },
    ],
    attachment: '性能截图.png',
  },
  {
    time: '17:30',
    dotClass: 'success',
    title: '常规巡检 · 下午检查',
    desc: '下午例行巡检完成，各系统运行平稳。确认 MQ-03 积压已完全消化，Web 集群 CPU 恢复正常。',
    tags: [{ text: '巡检', class: 'info' }],
  },
])

// ============ 值班备注 ============
const dutyNote = ref(`1. DS-02 存储阵列 IOPS 问题已提交厂商工单，预计明日回复
2. 存储扩容计划已确认，明早 09:30 开始，预计影响窗口 2 小时
3. MQ-03 消费者组稳定性需持续观察，已设置监控告警阈值`)

// ============ 新增日志弹窗 ============
const logModalVisible = ref(false)
const newLog = reactive({
  time: '16:30',
  type: 'alert',
  title: '',
  desc: '',
  tags: [],
})
const availableTags = [
  { value: 'alert', label: '告警', class: 'alert' },
  { value: 'resolve', label: '已解决', class: 'resolve' },
  { value: 'info', label: '巡检', class: 'info' },
  { value: 'warn', label: '待跟进', class: 'warn' },
]

const toggleTag = (value) => {
  const idx = newLog.tags.indexOf(value)
  if (idx >= 0) {
    newLog.tags.splice(idx, 1)
  } else {
    newLog.tags.push(value)
  }
}

const openLogModal = () => {
  logModalVisible.value = true
}
const submitLog = () => {
  ElMessage.success('日志已保存')
  logModalVisible.value = false
}
</script>

<template>
  <div class="log-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">值班日志</h2>
      <div class="toolbar-actions">
        <el-button class="btn-outline">导出日志</el-button>
        <el-button type="primary" class="btn-primary-custom" @click="openLogModal">
          <el-icon><Plus /></el-icon>
          新增日志
        </el-button>
      </div>
    </div>

    <!-- 日期导航 -->
    <div class="log-header-bar">
      <div class="log-date-nav">
        <button class="log-nav-btn" @click="shiftLogDate(-1)">
          <el-icon><ArrowLeft /></el-icon>
        </button>
        <div class="log-current-date">{{ logDateLabel }}</div>
        <button class="log-nav-btn" @click="shiftLogDate(1)">
          <el-icon><ArrowRight /></el-icon>
        </button>
        <el-button size="small" @click="goLogToday">今天</el-button>
      </div>
    </div>

    <!-- 日志主体 -->
    <div class="log-body-wrapper">
      <!-- 日志时间线 -->
      <div class="card log-timeline-card">
        <div class="card-header">
          <div class="card-title">
            <el-icon><Document /></el-icon> 值班日志时间线
          </div>
          <div class="log-tag-row">
            <span class="log-tag log-tag-alert">告警</span>
            <span class="log-tag log-tag-resolve">已解决</span>
            <span class="log-tag log-tag-info">巡检</span>
            <span class="log-tag log-tag-warn">注意</span>
          </div>
        </div>
        <div class="log-timeline-scroll">
          <div class="log-timeline">
            <div v-for="(entry, idx) in logEntries" :key="idx" class="log-entry">
              <div class="log-time-col">
                <div class="log-time">{{ entry.time }}</div>
              </div>
              <div class="log-dot-col">
                <div :class="['log-dot', entry.dotClass]"></div>
                <div v-if="idx < logEntries.length - 1" class="log-line"></div>
              </div>
              <div class="log-content">
                <div class="log-content-title">{{ entry.title }}</div>
                <div class="log-content-desc">{{ entry.desc }}</div>
                <div class="log-content-tags">
                  <span v-for="tag in entry.tags" :key="tag" :class="['log-tag', 'log-tag-' + tag.class]">{{ tag.text }}</span>
                </div>
                <div v-if="entry.attachment" class="log-attachment">
                  <el-icon><Paperclip /></el-icon> {{ entry.attachment }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 值班备注 -->
      <div class="card log-note-card">
        <div class="card-header">
          <div class="card-title">
            <el-icon><Edit /></el-icon> 今日值班备注
          </div>
        </div>
        <div class="log-note-body">
          <textarea v-model="dutyNote" class="log-note-area" placeholder="记录今日值班补充说明..." rows="6"></textarea>
        </div>
      </div>
    </div>

    <!-- 新增日志弹窗 -->
    <el-dialog v-model="logModalVisible" title="新增值班日志" width="580px" :close-on-click-modal="false">
      <el-form label-width="80px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="时间">
              <el-time-picker v-model="newLog.time" value-format="HH:mm" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="事件类型">
              <el-select v-model="newLog.type" style="width: 100%">
                <el-option label="告警处理" value="alert" />
                <el-option label="巡检记录" value="inspect" />
                <el-option label="工单处理" value="ticket" />
                <el-option label="设备维护" value="maintain" />
                <el-option label="其他" value="other" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="事件标题">
          <el-input v-model="newLog.title" placeholder="简要描述事件" />
        </el-form-item>
        <el-form-item label="详细描述">
          <el-input v-model="newLog.desc" type="textarea" :rows="4" placeholder="详细记录事件经过、处理措施和结果..." />
        </el-form-item>
        <el-form-item label="标签">
          <div class="tag-selector">
            <span
              v-for="tag in availableTags"
              :key="tag.value"
              :class="['log-tag', 'log-tag-' + tag.class, { selected: newLog.tags.includes(tag.value) }]"
              @click="toggleTag(tag.value)"
              >{{ tag.label }}</span
            >
          </div>
        </el-form-item>
        <el-form-item label="附件">
          <div class="upload-area-box">
            <div class="upload-desc-text">点击或拖拽上传附件</div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="logModalVisible = false">取消</el-button>
        <el-button type="primary" @click="submitLog">保存日志</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.log-page {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 16px 24px;
  height: 100%;
  box-sizing: border-box;
  overflow-y: auto;
  --primary: #2563eb;
  --primary-light: #3b82f6;
  --primary-bg: #eff6ff;
  --primary-border: #bfdbfe;
  --purple: #7c3aed;
  --warning: #f59e0b;
  --danger: #dc2626;
  --success: #16a34a;
  --text-1: #0f172a;
  --text-2: #334155;
  --text-3: #64748b;
  --text-4: #94a3b8;
  --bg-page: #f1f5f9;
  --bg-card: #ffffff;
  --border: #e2e8f0;
  --border-light: #f1f5f9;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.04);
  --radius: 10px;
  --radius-sm: 6px;
  --warning-bg: #fffbeb;
  --warning-border: #fde68a;
  --danger-bg: #fef2f2;
  --danger-border: #fecaca;
  --success-bg: #f0fdf4;
  --success-border: #bbf7d0;
  --bg-sidebar: #0f172a;
}

/* 工具栏 */
.page-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
  flex-shrink: 0;
}
.page-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-1);
  margin: 0;
}
.toolbar-actions {
  display: flex;
  gap: 10px;
}

/* 按钮 */
.btn-outline {
  border: 1px solid var(--border) !important;
  color: var(--text-2) !important;
  background: var(--bg-card) !important;
}
.btn-outline:hover {
  border-color: var(--primary) !important;
  color: var(--primary) !important;
}
.btn-primary-custom {
  background: var(--primary) !important;
  border-color: var(--primary) !important;
}
.btn-primary-custom:hover {
  background: var(--primary-light) !important;
}

/* 日期导航 */
.log-header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}
.log-date-nav {
  display: flex;
  align-items: center;
  gap: 12px;
}
.log-current-date {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-1);
  min-width: 300px;
  text-align: center;
}
.log-nav-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-3);
  padding: 0;
}
.log-nav-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}

/* 卡片 */
.card {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.card-header {
  padding: 10px 16px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fafafa;
}
.card-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 日志主体布局 */
.log-body-wrapper {
  display: flex;
  flex-direction: column;
  gap: 14px;
  flex: 1;
  min-height: 0;
}
.log-timeline-card {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

/* 标签行 */
.log-tag-row {
  display: flex;
  gap: 6px;
}
.log-tag {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
}
.log-tag-alert {
  background: var(--danger-bg);
  color: var(--danger);
  border: 1px solid var(--danger-border);
}
.log-tag-resolve {
  background: var(--success-bg);
  color: var(--success);
  border: 1px solid var(--success-border);
}
.log-tag-info {
  background: var(--primary-bg);
  color: var(--primary);
  border: 1px solid var(--primary-border);
}
.log-tag-warn {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}

/* 日志时间线 */
.log-timeline-scroll {
  padding: 16px;
  flex: 1;
  overflow-y: auto;
}
.log-timeline {
  display: flex;
  flex-direction: column;
  gap: 0;
}
.log-entry {
  display: flex;
  gap: 14px;
  padding: 14px 0;
  border-bottom: 1px solid var(--border-light);
  position: relative;
}
.log-entry:last-child {
  border-bottom: none;
}
.log-time-col {
  width: 60px;
  flex-shrink: 0;
  text-align: right;
  padding-top: 2px;
}
.log-time {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-1);
  font-family: monospace;
}
.log-dot-col {
  width: 20px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.log-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--primary);
  flex-shrink: 0;
  margin-top: 5px;
}
.log-dot.warn {
  background: var(--warning);
}
.log-dot.danger {
  background: var(--danger);
}
.log-dot.success {
  background: var(--success);
}
.log-line {
  width: 2px;
  flex: 1;
  background: var(--border);
  margin-top: 4px;
}
.log-content {
  flex: 1;
  min-width: 0;
}
.log-content-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
  margin-bottom: 4px;
}
.log-content-desc {
  font-size: 13px;
  color: var(--text-2);
  line-height: 1.6;
}
.log-content-tags {
  display: flex;
  gap: 6px;
  margin-top: 6px;
  flex-wrap: wrap;
}
.log-attachment {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--primary);
  cursor: pointer;
  margin-top: 6px;
}

/* 值班备注 */
.log-note-card {
  flex-shrink: 0;
}
.log-note-body {
  padding: 12px 16px;
}
.log-note-area {
  width: 100%;
  min-height: 80px;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 13px;
  outline: none;
  resize: vertical;
  font-family: inherit;
  line-height: 1.6;
  box-sizing: border-box;
}
.log-note-area:focus {
  border-color: var(--primary);
}

/* 弹窗 */
.upload-area-box {
  border: 2px dashed var(--border);
  border-radius: 8px;
  padding: 20px;
  text-align: center;
  background: var(--bg-page);
  cursor: pointer;
}
.upload-area-box:hover {
  border-color: var(--primary);
  background: var(--primary-bg);
}
.upload-desc-text {
  font-size: 12px;
  color: var(--text-4);
}
.tag-selector {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.tag-selector .log-tag {
  cursor: pointer;
  opacity: 0.5;
  transition: all 0.2s;
}
.tag-selector .log-tag:hover {
  opacity: 0.8;
}
.tag-selector .log-tag.selected {
  opacity: 1;
}
</style>
