<script setup>
import { ref, reactive, computed } from 'vue'
import { Plus, User, UserFilled, Monitor, Document } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'

// ============ 筛选 ============
const filterRole = ref('')
const filterStatus = ref('')
const filterDate = ref('2026-05-12')

// ============ 交接班数据 ============
const handoverList = ref([
  {
    date: '2026-05-12',
    role: 'ECC 指挥中心',
    shiftClass: 'shift-day',
    shiftLabel: '白班 → 夜班',
    statusClass: 'completed',
    statusBadgeClass: 'status-completed',
    statusIcon: '✓',
    statusText: '已完成',
    fromName: '李四光',
    fromSurname: '李',
    fromColor: 'var(--primary)',
    fromRoleDesc: 'ECC 白班 · 09:00-18:00',
    toName: '张三丰',
    toSurname: '张',
    toColor: 'var(--text-3)',
    toRoleDesc: 'ECC 夜班 · 18:00-09:00',
    systemStatus: [
      { text: '核心业务系统运行正常，CPU 均值 42%，内存使用率 68%' },
      { text: '数据库集群主从同步正常，延迟 <100ms' },
      { text: '中间件 MQ-03 节点消息积压 1200+ 条，已触发告警，需夜间持续关注', warn: true },
    ],
    todoItems: [
      { text: 'MQ-03 积压处理：预计凌晨 02:00 前消费完成，若未完成需重启消费者组', warn: true },
      { text: '明日 09:30 计划维护窗口 — 存储扩容（已审批），需夜班协助做前置检查' },
    ],
    handoverTime: '2026-05-12 17:55',
    confirmText: '已确认',
    confirmColor: 'var(--success)',
    confirmTime: '18:02',
  },
  {
    date: '2026-05-12',
    role: '系统运维',
    shiftClass: 'shift-day',
    shiftLabel: '白班交接',
    statusClass: 'completed',
    statusBadgeClass: 'status-completed',
    statusIcon: '✓',
    statusText: '已完成',
    fromName: '王五一',
    fromSurname: '王',
    fromColor: 'var(--purple)',
    fromRoleDesc: '系统运维 · 05-11 白班',
    toName: '赵六六',
    toSurname: '赵',
    toColor: 'var(--purple)',
    toRoleDesc: '系统运维 · 05-12 白班',
    systemStatus: [
      { text: '全部服务器健康检查通过，无异常进程' },
      { text: '昨日备份任务完成，数据校验一致' },
      { text: '已按计划完成 3 台虚拟机资源回收，释放 vCPU 16核 / 内存 32GB' },
    ],
    todoItems: [{ text: '明日 09:30 存储扩容操作，需提前确认 SAN Zone 配置' }, { text: '月度安全扫描报告预计下午出具，需关注高危漏洞修复' }],
    handoverTime: '2026-05-12 09:10',
    confirmText: '已确认',
    confirmColor: 'var(--success)',
    confirmTime: '09:15',
  },
  {
    date: '2026-05-11',
    role: 'ECC 指挥中心',
    shiftClass: 'shift-night',
    shiftLabel: '夜班 → 白班',
    statusClass: 'pending',
    statusBadgeClass: 'status-pending',
    statusIcon: '⏳',
    statusText: '待确认',
    fromName: '张三丰',
    fromSurname: '张',
    fromColor: 'var(--text-3)',
    fromRoleDesc: 'ECC 夜班 · 05-10 18:00 - 05-11 09:00',
    toName: '张三丰',
    toSurname: '张',
    toColor: 'var(--primary)',
    toRoleDesc: 'ECC 白班 · 05-11 09:00-18:00',
    systemStatus: [
      { text: '凌晨 03:20 存储阵列 DS-02 告警，IOPS 短暂飙升后自动恢复，已记录工单 #4582', danger: true },
      { text: '夜班期间处理 2 例用户工单，均已关闭' },
    ],
    todoItems: [{ text: 'DS-02 存储阵列需排查 IOPS 飙升根因，建议联系厂商支持', danger: true }, { text: '夜班监控无新增告警，待白班复核' }],
    handoverTime: '2026-05-11 08:50',
    confirmText: '待确认',
    confirmColor: 'var(--warning)',
  },
])

const filteredHandoverList = computed(() => {
  return handoverList.value.filter((item) => {
    if (filterRole.value && !item.role.includes(filterRole.value === 'ecc' ? 'ECC' : filterRole.value === 'sys' ? '系统' : '网络')) return false
    if (filterStatus.value) {
      if (filterStatus.value === 'completed' && item.statusClass !== 'completed') return false
      if (filterStatus.value === 'pending' && item.statusClass !== 'pending') return false
    }
    if (filterDate.value && item.date !== filterDate.value) return false
    return true
  })
})

// ============ 新建交接班弹窗 ============
const handoverModalVisible = ref(false)
const newHandover = reactive({
  role: 'ecc',
  date: '2026-05-12',
  from: '',
  to: '',
  systemStatus: '',
  todo: '',
})

const openHandoverModal = () => {
  handoverModalVisible.value = true
}
const submitHandover = () => {
  ElMessage.success('交接班记录已提交')
  handoverModalVisible.value = false
}
</script>

<template>
  <div class="handover-page">
    <!-- 页面工具栏 -->
    <div class="page-toolbar">
      <h2 class="page-title">交接班记录</h2>
      <div class="toolbar-actions">
        <el-button class="btn-outline">导出记录</el-button>
        <el-button type="primary" class="btn-primary-custom" @click="openHandoverModal">
          <el-icon><Plus /></el-icon>
          新建交接班
        </el-button>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="filter-group">
        <span class="filter-label">值班角色</span>
        <el-select v-model="filterRole" size="small" class="filter-select">
          <el-option label="全部角色" value="" />
          <el-option label="ECC 指挥中心" value="ecc" />
          <el-option label="系统运维" value="sys" />
          <el-option label="网络运维" value="net" />
        </el-select>
      </div>
      <div class="filter-group">
        <span class="filter-label">交接状态</span>
        <el-select v-model="filterStatus" size="small" class="filter-select">
          <el-option label="全部" value="" />
          <el-option label="已完成" value="completed" />
          <el-option label="待确认" value="pending" />
        </el-select>
      </div>
      <div class="filter-group ml-auto">
        <span class="filter-label">日期</span>
        <el-date-picker v-model="filterDate" type="date" value-format="YYYY-MM-DD" size="small" class="filter-date-picker" />
      </div>
    </div>

    <!-- 交接班时间线 -->
    <div class="handover-timeline">
      <div v-for="(item, index) in filteredHandoverList" :key="index" class="handover-item">
        <div :class="['handover-dot', item.statusClass]"></div>
        <div class="handover-card">
          <div class="handover-card-header">
            <div class="handover-date">{{ item.date }} · {{ item.role }}</div>
            <div class="handover-shift-info">
              <span :class="['badge-shift', item.shiftClass]">{{ item.shiftLabel }}</span>
              <span :class="['handover-status', item.statusBadgeClass]">{{ item.statusIcon }} {{ item.statusText }}</span>
            </div>
          </div>
          <div class="handover-body">
            <!-- 交班人 -->
            <div class="handover-col">
              <div class="handover-section-title">
                <el-icon><User /></el-icon> 交班人
              </div>
              <div class="handover-person-row">
                <div class="handover-person-avatar" :style="{ background: item.fromColor }">{{ item.fromSurname }}</div>
                <div class="handover-person-info">
                  <div class="handover-person-name">{{ item.fromName }}</div>
                  <div class="handover-person-role">{{ item.fromRoleDesc }}</div>
                </div>
              </div>
            </div>
            <!-- 接班人 -->
            <div class="handover-col">
              <div class="handover-section-title">
                <el-icon><UserFilled /></el-icon> 接班人
              </div>
              <div class="handover-person-row">
                <div class="handover-person-avatar" :style="{ background: item.toColor }">{{ item.toSurname }}</div>
                <div class="handover-person-info">
                  <div class="handover-person-name">{{ item.toName }}</div>
                  <div class="handover-person-role">{{ item.toRoleDesc }}</div>
                </div>
              </div>
            </div>

            <div class="handover-divider"></div>

            <!-- 系统运行状态 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Monitor /></el-icon> 系统运行状态
              </div>
              <ul class="handover-list">
                <li v-for="(line, li) in item.systemStatus" :key="'s-' + li" :class="{ 'warn-item': line.warn, 'danger-item': line.danger }">
                  {{ line.text }}
                </li>
              </ul>
            </div>

            <!-- 待跟进事项 -->
            <div class="handover-content-block">
              <div class="handover-content-title">
                <el-icon><Document /></el-icon> 待跟进事项
              </div>
              <ul class="handover-list">
                <li v-for="(line, li) in item.todoItems" :key="'t-' + li" :class="{ 'warn-item': line.warn, 'danger-item': line.danger }">
                  {{ line.text }}
                </li>
              </ul>
            </div>

            <!-- 交接确认 -->
            <div class="handover-content-block">
              <div class="handover-sign">
                交接时间：{{ item.handoverTime }} &nbsp;|&nbsp; 接班人确认：<strong :style="{ color: item.confirmColor }">{{
                  item.confirmText
                }}</strong>
                <template v-if="item.confirmTime">&nbsp;|&nbsp; 确认时间：{{ item.confirmTime }}</template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 新建交接班弹窗 -->
    <el-dialog v-model="handoverModalVisible" title="新建交接班记录" width="620px" :close-on-click-modal="false">
      <el-form label-width="100px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="值班角色">
              <el-select v-model="newHandover.role" style="width: 100%">
                <el-option label="ECC 指挥中心" value="ecc" />
                <el-option label="系统运维" value="sys" />
                <el-option label="网络运维" value="net" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="交接日期">
              <el-date-picker v-model="newHandover.date" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="交班人">
              <el-select v-model="newHandover.from" style="width: 100%">
                <el-option label="李四光" value="李四光" />
                <el-option label="张三丰" value="张三丰" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="接班人">
              <el-select v-model="newHandover.to" style="width: 100%">
                <el-option label="张三丰" value="张三丰" />
                <el-option label="李四光" value="李四光" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="系统运行状态">
          <el-input v-model="newHandover.systemStatus" type="textarea" :rows="3" placeholder="描述当前各系统运行状况..." />
        </el-form-item>
        <el-form-item label="待跟进事项">
          <el-input v-model="newHandover.todo" type="textarea" :rows="3" placeholder="需要接班人关注的事项..." />
        </el-form-item>
        <el-form-item label="附件">
          <div class="upload-area-box">
            <div class="upload-desc-text">点击或拖拽上传附件（截图、文档等）</div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="handoverModalVisible = false">取消</el-button>
        <el-button type="primary" @click="submitHandover">提交交接</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.handover-page {
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
  --cyan: #0891b2;
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
.ml-auto {
  margin-left: auto;
}

/* 筛选栏 */
.filter-bar {
  background: var(--bg-card);
  padding: 10px 16px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  display: flex;
  gap: 16px;
  align-items: center;
  flex-shrink: 0;
}
.filter-group {
  display: flex;
  align-items: center;
  gap: 8px;
}
.filter-label {
  font-size: 13px;
  color: var(--text-3);
  white-space: nowrap;
}
.filter-select {
  width: 140px;
}
.filter-date-picker {
  width: 150px;
}

/* 标签 */
.badge-shift {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
}
.shift-day {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}
.shift-night {
  background: var(--bg-sidebar);
  color: var(--text-4);
  border: 1px solid var(--text-2);
}

/* 交接班时间线 */
.handover-timeline {
  position: relative;
  padding-left: 28px;
  flex: 1;
  overflow-y: auto;
}
.handover-timeline::before {
  content: '';
  position: absolute;
  left: 10px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: var(--border);
}
.handover-item {
  position: relative;
  margin-bottom: 16px;
}
.handover-dot {
  position: absolute;
  left: -22px;
  top: 18px;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 2px solid var(--primary);
  background: var(--bg-card);
  z-index: 1;
}
.handover-dot.completed {
  background: var(--success);
  border-color: var(--success);
}
.handover-dot.pending {
  background: var(--warning-bg);
  border-color: var(--warning);
}
.handover-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  overflow: hidden;
  transition: box-shadow 0.2s;
}
.handover-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
}
.handover-card-header {
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border-light);
}
.handover-date {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-1);
}
.handover-shift-info {
  display: flex;
  align-items: center;
  gap: 8px;
}
.handover-status {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 20px;
  font-weight: 600;
}
.status-completed {
  background: var(--success-bg);
  color: var(--success);
  border: 1px solid var(--success-border);
}
.status-pending {
  background: var(--warning-bg);
  color: #92400e;
  border: 1px solid var(--warning-border);
}

.handover-body {
  padding: 14px 16px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.handover-col {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.handover-section-title {
  font-size: 11px;
  font-weight: 600;
  color: var(--text-4);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 2px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.handover-person-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.handover-person-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  color: #fff;
  flex-shrink: 0;
}
.handover-person-info {
  flex: 1;
}
.handover-person-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-1);
}
.handover-person-role {
  font-size: 11px;
  color: var(--text-3);
}

.handover-divider {
  grid-column: 1 / -1;
  height: 1px;
  background: var(--border-light);
  margin: 2px 0;
}
.handover-content-block {
  grid-column: 1 / -1;
}
.handover-content-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-2);
  margin-bottom: 6px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.handover-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 0;
  margin: 0;
}
.handover-list li {
  font-size: 13px;
  color: var(--text-2);
  padding: 6px 10px;
  background: var(--bg-page);
  border-radius: 6px;
  display: flex;
  align-items: flex-start;
  gap: 8px;
  line-height: 1.5;
}
.handover-list li::before {
  content: '';
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--primary);
  flex-shrink: 0;
  margin-top: 7px;
}
.handover-list li.warn-item::before {
  background: var(--warning);
}
.handover-list li.danger-item::before {
  background: var(--danger);
}
.handover-sign {
  font-size: 12px;
  color: var(--text-3);
  text-align: right;
  padding-top: 8px;
  border-top: 1px dashed var(--border-light);
  margin-top: 6px;
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
</style>
