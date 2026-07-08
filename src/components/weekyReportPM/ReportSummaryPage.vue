<template>
  <div class="report-summary-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">周报汇总</h2>
      <el-button @click="goExportPage">
        <el-icon><Download /></el-icon>
        &nbsp;导出周报
      </el-button>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="week-nav">
        <span class="filter-label">查看周次</span>
        <el-button size="small" :icon="ArrowLeft" circle @click="shiftWeek(-1)" :disabled="summaryWeek <= 1" />
        <el-tag type="primary" effect="light" class="week-tag">{{ weekLabel }}</el-tag>
        <el-button size="small" :icon="ArrowRight" circle @click="shiftWeek(1)" :disabled="summaryWeek >= currentWeek" />
      </div>
      <el-button type="warning" size="small" @click="handleRemindAll">
        <el-icon><Bell /></el-icon>
        &nbsp;一键提醒
      </el-button>
    </div>

    <!-- 提交统计 -->
    <div class="summary-stats">
      <el-card 
        v-for="stat in statsCards" 
        :key="stat.label" 
        shadow="never" 
        class="stat-card"
        :class="{ 'clickable': true }"
        @click="showStatDialog(stat.label)"
      >
        <div class="stat-label">{{ stat.label }}</div>
        <transition name="stat-number" mode="out-in">
          <div :key="stat.value" class="stat-value" :style="{ color: stat.color }">{{ stat.value }}</div>
        </transition>
        <div class="stat-sub">{{ stat.sub }}</div>
      </el-card>
    </div>
    
    <!-- 人员名单对话框 -->
    <el-dialog v-model="peopleDialogVisible" :title="peopleDialogTitle" :width="peopleDialogType === '草稿' ? '720px' : '860px'" :close-on-click-modal="true">
      <el-empty v-if="peopleList.length === 0" description="暂无数据" :image-size="80" />
      <div v-else :style="{ width: peopleDialogType === '草稿' ? '670px' : '800px', overflow: 'hidden' }">
        <el-table :data="peopleList" border size="small" style="width: 100%" max-height="400" :span-method="cellSpanMethod" :cell-style="{ textAlign: 'center' }">
        <el-table-column label="序号" width="60" align="center">
          <template #default="{ row }">
            <span v-if="row._rowSpan > 0">{{ row.seqIndex }}</span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="姓名" width="80" align="center" />
        <el-table-column label="提交状态" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.moduleStatus || 'pending')" size="small" effect="light" round>
              {{ getStatusText(row.moduleStatus || 'pending') }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="模块名" width="110" align="center">
          <template #default="{ row }">
            <el-tag size="small" effect="plain" round>{{ row.moduleName || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType !== '草稿'" label="提交时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.submitTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="修改时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.moduleUpdateTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType === '草稿'" label="创建时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.createdTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType !== '草稿'" label="打回时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.moduleReturnedTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80" align="center">
          <template #default="{ row }">
            <el-button
              v-if="row.userCode && row.status !== 'submitted'"
              type="warning" size="small" text
              :loading="remindingUser === row.userCode"
              @click="handleRemindPerson(row.userCode, row.name)"
            >
              <el-icon><Bell /></el-icon>&nbsp;提醒
            </el-button>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
      </el-table>
    </div>
    </el-dialog>

    <div class="summary-tabs-wrapper">
      <el-tabs v-if="moduleGroups.length > 0" v-model="activeTab" class="summary-tabs">
        <el-tab-pane v-for="group in moduleGroups" :key="group.moduleId" :name="group.moduleId">
          <template #label>
            <span class="tab-label">
              <span class="module-dot" :style="{ background: group.color }"></span>
              {{ group.name }}
              <el-tag size="small" type="info" effect="plain" round class="tab-count">{{ group.entries.length }}</el-tag>
            </span>
          </template>
          <el-scrollbar class="tab-scroll">
            <div class="tab-content">
              <div
                v-for="entry in group.entries"
                :key="entry.reportId"
                class="summary-entry"
              >
                <el-avatar :size="32" :style="{ background: entry.color, fontSize: '12px' }">
                  {{ entry.avatar }}
                </el-avatar>
                <div class="entry-info">
                  <!-- 工具栏：与周报填写一致 -->
                  <div class="entry-toolbar">
                    <div class="entry-name">
                      {{ entry.name }}
                      <transition name="status-tag" mode="out-in">
                        <el-tag v-if="entry.status === 'returned'" :key="'returned'" size="small" type="warning" effect="light">已打回</el-tag>
                        <el-tag v-else :key="'submitted'" size="small" type="success" effect="light">已提交</el-tag>
                      </transition>
                      <span v-if="entry.updateTime" style="margin-left: 6px; font-size: 12px; color: #909399;">{{ entry.updateTime }}</span>
                    </div>
                    <div class="entry-actions">
                      <template v-if="editingKey !== entry.reportId">
                        <el-button type="primary" size="small" text @click="startEdit(entry.reportId, group.moduleId, entry.content)">
                          <el-icon><Edit /></el-icon>&nbsp;编辑
                        </el-button>
                        <transition name="action-btn" mode="out-in">
                          <el-button v-if="entry.status !== 'returned'" :key="'return'" size="small" text type="warning" @click="handleReturn(entry.reportId)">
                            <el-icon><RefreshLeft /></el-icon>&nbsp;打回
                          </el-button>
                        </transition>
                        <el-button size="small" text type="danger" @click="handleDeleteEntry(entry.reportId)">
                          <el-icon><Delete /></el-icon>&nbsp;删除
                        </el-button>
                      </template>
                      <template v-else>
                        <el-button size="small" text @click="cancelEdit">&nbsp;取消</el-button>
                        <el-button size="small" text type="primary" @click="saveEdit(entry.reportId, entry.engineerId)">
                          <el-icon><Select /></el-icon>&nbsp;保存
                        </el-button>
                      </template>
                    </div>
                  </div>
                  <!-- 查看模式：逐行展示 -->
                  <div v-if="editingKey !== entry.reportId" class="entry-content-lines">
                    <template v-if="parseLines(entry.content).length > 0">
                      <div v-for="(line, li) in parseLines(entry.content)" :key="li" class="content-line is-idle">
                        <span class="line-num">{{ li + 1 }}.</span>
                        <span class="line-text">{{ line.text }}</span>
                        <span v-if="line.updatedBy" class="line-meta">{{ line.updatedBy }} · {{ line.updatedAt }}</span>
                        <div class="line-hover-actions">
                          <el-button size="small" text @click="copyText(line.text)" title="复制">
                            <el-icon><CopyDocument /></el-icon>
                          </el-button>
                        </div>
                      </div>
                    </template>
                    <span v-else style="color:#c0c4cc; padding: 4px 6px;">暂未填写内容</span>
                  </div>
                  <!-- 编辑模式：逐行内联编辑 -->
                  <div v-else class="entry-content-lines">
                    <div
                      v-for="(line, idx) in editLines"
                      :key="idx"
                      class="content-line"
                      :class="{ 'is-editing': editingLineIdx === idx, 'is-idle': editingLineIdx !== idx }"
                      @click="activateLine(idx)"
                    >
                      <span class="line-num">{{ idx + 1 }}.</span>
                      <el-input
                        v-if="editingLineIdx === idx"
                        v-model="line.text"
                        type="textarea"
                        :autosize="{ minRows: 1 }"
                        placeholder="请输入工作内容..."
                        @keydown.enter.prevent="addLineAfter(idx)"
                        @keydown.up.prevent="moveToPrevLine(idx)"
                        @keydown.down.prevent="moveToNextLine(idx)"
                        class="line-input"
                      />
                      <span v-else class="line-text" :class="{ 'empty-hint': !line.text }">
                        {{ line.text || '点击此处编辑...' }}
                      </span>
                      <div v-if="editingLineIdx !== idx" class="line-hover-actions">
                        <el-button size="small" text @click.stop="copyLine(idx)" title="复制">
                          <el-icon><CopyDocument /></el-icon>
                        </el-button>
                        <el-button size="small" text @click.stop="pasteLine(idx)" title="粘贴">
                          <el-icon><DocumentCopy /></el-icon>
                        </el-button>
                        <el-button size="small" text type="danger" @click.stop="deleteLine(idx)" title="删除" :disabled="editLines.length <= 1">
                          <el-icon><Delete /></el-icon>
                        </el-button>
                      </div>
                      <!-- 激活行操作按钮（始终可见） -->
                      <span v-if="editingLineIdx === idx" class="active-line-actions">
                        <el-button size="small" text @click.stop="pasteLine(idx)" title="粘贴">
                          <el-icon><DocumentCopy /></el-icon>
                        </el-button>
                        <el-button size="small" text type="danger" @click.stop="deleteLine(idx)" title="删除" :disabled="editLines.length <= 1">
                          <el-icon><Delete /></el-icon>
                        </el-button>
                      </span>
                      <span v-if="line.updatedBy" class="line-meta">{{ line.updatedBy }} · {{ line.updatedAt }}</span>
                    </div>
                    <div class="edit-actions">
                      <el-button size="small" text type="primary" @click="addLineAfter(editLines.length - 1)">
                        <el-icon><Plus /></el-icon>添加一行
                      </el-button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </el-scrollbar>
        </el-tab-pane>
      </el-tabs>
      <div v-else class="empty-summary">
        <el-empty description="本周暂无已提交的周报数据" :image-size="80" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Download, ArrowLeft, ArrowRight, Bell, Edit, Plus, Delete, CopyDocument, DocumentCopy, Select, RefreshLeft } from '@element-plus/icons-vue'
import { usePermissionStore } from '@/stores/permissionStore'
import { getReportModules, getSummaryReports, editSummaryContent, remindUnsubmitted, remindPerson, deleteReport, returnReport, getWeekConfig } from '@/api/weeklyReportApi'
import { reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN, setWeekConfig } from '@/utils/weeklyReportData'

const router = useRouter()
const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }
const permissionStore = usePermissionStore()
const username = computed(() => permissionStore.userInfo?.username || '')
const nickname = computed(() => permissionStore.userInfo?.nickname || '')

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()
const summaryWeek = ref(currentWeek)

// 汇总数据
const summaryData = ref(null)
// 编辑状态（逐行编辑）
const editingKey = ref('')
const editingModuleId = ref(null)
const editLines = ref([])
const editingLineIdx = ref(null)
const clipboardText = ref('')
const displayName = computed(() => nickname.value || username.value)
// 当前激活的Tab
const activeTab = ref('')

// 周标签
const weekLabel = computed(() => {
  const { monday, sunday } = getWeekDateRange(currentYear, summaryWeek.value)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)} · 第${summaryWeek.value}周`
})

// 切换周次
const shiftWeek = (dir) => {
  const newWeek = summaryWeek.value + dir
  if (newWeek >= 1 && newWeek <= currentWeek) {
    summaryWeek.value = newWeek
    loadSummary()
  }
}

// 统计卡片
const statsCards = computed(() => {
  const data = summaryData.value
  if (!data) return []
  return [
    { label: '团队成员', value: data.total || 0, sub: '人', color: '#303133' },
    { label: '已提交', value: data.submitted || 0, sub: '人', color: '#67c23a' },
    { label: '已打回', value: data.returned || 0, sub: '人', color: '#e6a23c' },
    { label: '部分提交', value: data.partial || 0, sub: '人', color: '#409eff' },
    { label: '草稿', value: data.draft || 0, sub: '人', color: '#e6a23c' },
    { label: '未提交', value: data.pending || 0, sub: '人', color: '#f56c6c' },
  ]
})

// 当前显示的统计类型（未提交/部分提交/已打回/团队成员）
const peopleDialogVisible = ref(false)
const peopleDialogType = ref('') // 未提交/部分提交/已打回/团队成员
const peopleList = ref([]) // 对应的人员列表
const remindingUser = ref('') // 正在发送提醒的用户

// 对话框标题
const peopleDialogTitle = computed(() => {
  const titleMap = {
    '未提交': '未提交人员名单',
    '部分提交': '部分提交人员名单',
    '已打回': '已打回人员名单',
    '已提交': '已提交人员名单',
    '草稿': '草稿人员名单',
    '团队成员': '团队成员名单'
  }
  return titleMap[peopleDialogType.value] || '人员名单'
})

// 时间列标签：已提交/已打回/团队成员→提交时间，未提交/草稿/部分提交→修改时间
const timeColumnLabel = computed(() => {
  const submitLabels = ['已提交', '已打回', '团队成员']
  return submitLabels.includes(peopleDialogType.value) ? '提交时间' : '修改时间'
})

// 格式化人员时间
const formatPersonTime = (row) => {
  const submitLabels = ['已提交', '已打回', '团队成员']
  if (submitLabels.includes(peopleDialogType.value)) {
    return row.submitTime || '-'
  }
  return row.updateTime || '-'
}

// 模块修改时间列标签：按卡片类型动态切换
const moduleTimeLabel = computed(() => {
  if (peopleDialogType.value === '已打回') return '打回时间'
  if (peopleDialogType.value === '团队成员') return '修改/打回时间'
  return '修改时间'
})

// 获取状态对应的颜色类型
const getStatusType = (status) => {
  const statusMap = {
    'submitted': 'success',
    'returned': 'warning',
    'partial': 'info',
    'draft': 'warning',
    'pending': 'danger'
  }
  return statusMap[status] || 'info'
}

// 获取状态对应的显示文本
const getStatusText = (status) => {
  const textMap = {
    'submitted': '已提交',
    'returned': '已打回',
    'partial': '部分提交',
    'draft': '草稿',
    'pending': '未提交'
  }
  return textMap[status] || status
}

// 构建模块状态条目（去重，优先级：已打回 > 已提交 > 草稿）
const buildModuleEntries = (draftMods, submittedMods, returnedMods, submitTimeMap = {}, updateTimeMap = {}, returnedTimeMap = {}, createdTimeMap = {}) => {
  const map = new Map()
  ;(draftMods || []).forEach(m => { if (!map.has(m)) map.set(m, {moduleStatus: 'draft'}) })
  ;(submittedMods || []).forEach(m => { if (!map.has(m)) map.set(m, {moduleStatus: 'submitted'}) })
  ;(returnedMods || []).forEach(m => map.set(m, {moduleStatus: 'returned'}))
  return Array.from(map, ([moduleName, val]) => ({
    moduleName,
    ...val,
    submitTime: submitTimeMap[moduleName] || null,
    moduleUpdateTime: updateTimeMap[moduleName] || null,
    moduleReturnedTime: returnedTimeMap[moduleName] || null,
    createdTime: createdTimeMap[moduleName] || null,
  }))
}

// 显示统计卡片对应的对话框
const showStatDialog = (label) => {
  peopleDialogType.value = label
  const rawList = []
  const unsubmittedData = summaryData.value?.unsubmitted || []

  if (label === '未提交') {
    unsubmittedData
      .filter(user => user.status === 'pending')
      .forEach(user => rawList.push({
        id: user.id, name: user.name, userCode: user.userCode, status: 'pending',
        submitTime: user.submitTime, updateTime: user.updateTime,
        moduleEntries: []
      }))
  } else if (label === '草稿') {
    unsubmittedData
      .filter(user => user.status === 'draft')
      .forEach(user => rawList.push({
        id: user.id, name: user.name, userCode: user.userCode, status: 'draft',
        submitTime: user.submitTime, updateTime: user.updateTime,
        moduleEntries: buildModuleEntries(user.draftModules, [], [], user.moduleSubmitTimeMap, user.moduleUpdateTimeMap, user.moduleReturnedTimeMap, user.moduleCreatedTimeMap)
      }))
  } else if (label === '部分提交') {
    unsubmittedData
      .filter(user => user.status === 'partial')
      .forEach(user => rawList.push({
        id: user.id, name: user.name, userCode: user.userCode, status: 'partial',
        submitTime: user.submitTime, updateTime: user.updateTime,
        moduleEntries: buildModuleEntries(user.draftModules, user.submittedModules, user.returnedModules, user.moduleSubmitTimeMap, user.moduleUpdateTimeMap, user.moduleReturnedTimeMap, user.moduleCreatedTimeMap)
      }))
  } else if (label === '已打回') {
    unsubmittedData
      .filter(user => user.status === 'returned')
      .forEach(user => rawList.push({
        id: user.engineerId,
        name: user.name,
        userCode: user.userCode,
        status: 'returned',
        submitTime: user.submitTime,
        updateTime: user.updateTime,
        moduleEntries: buildModuleEntries(
          user.draftModules, user.submittedModules, user.returnedModules,
          user.moduleSubmitTimeMap, user.moduleUpdateTimeMap,
          user.moduleReturnedTimeMap, user.moduleCreatedTimeMap
        )
      }))
  } else if (label === '已提交') {
    // 排除已打回和部分提交人员（不列入已提交卡片）
    const excludedNames = new Set(
      unsubmittedData.filter(u => u.status === 'returned' || u.status === 'partial').map(u => u.name)
    )
    const personMap = new Map() // name -> { engineerId, name, userCode, entries }
    if (summaryData.value?.moduleGroups) {
      summaryData.value.moduleGroups.forEach(group => {
        group.entries.forEach(entry => {
          if (entry.status !== 'submitted') return
          if (excludedNames.has(entry.name)) return // 跳过已打回/部分提交人员
          if (!personMap.has(entry.name)) {
            personMap.set(entry.name, {
              engineerId: entry.engineerId,
              name: entry.name,
              userCode: entry.userCode || '',
              entries: []
            })
          }
          const person = personMap.get(entry.name)
          // 去重（同一人同一模块只记一次）
          if (!person.entries.some(e => e.moduleName === entry.moduleName)) {
            person.entries.push({
              moduleName: entry.moduleName,
              moduleStatus: 'submitted',
              submitTime: entry.submitTime || null,
              moduleUpdateTime: entry.updateTime || null,
              moduleReturnedTime: entry.returnedTime || null
            })
          }
        })
      })
    }
    personMap.forEach(person => {
      rawList.push({
        id: person.engineerId,
        name: person.name,
        userCode: person.userCode,
        status: 'submitted',
        submitTime: null,
        updateTime: null,
        moduleEntries: person.entries
      })
    })
  } else if (label === '团队成员') {
    const seen = new Set()
    // 1. 从未提交列表中添加（按 all_engineers 的 id 顺序）
    unsubmittedData.forEach(user => {
      if (!seen.has(user.name)) {
        seen.add(user.name)
        rawList.push({
          engineerId: user.engineerId,
          name: user.name, userCode: user.userCode, status: user.status,
          submitTime: user.submitTime, updateTime: user.updateTime,
          moduleEntries: buildModuleEntries(user.draftModules, user.submittedModules, user.returnedModules, user.moduleSubmitTimeMap, user.moduleUpdateTimeMap, user.moduleReturnedTimeMap, user.moduleCreatedTimeMap)
        })
      }
    })
    // 2. 从 moduleGroups 添加（已存在则追加模块条目）
    if (summaryData.value?.moduleGroups) {
      summaryData.value.moduleGroups.forEach(group => {
        group.entries.forEach(entry => {
          if (!seen.has(entry.name)) {
            seen.add(entry.name)
            rawList.push({
              engineerId: entry.engineerId,
              name: entry.name, userCode: entry.userCode || '',
              status: entry.status, submitTime: entry.submitTime, updateTime: entry.updateTime,
              moduleEntries: entry.moduleName ? [{moduleName: entry.moduleName, moduleStatus: entry.status, submitTime: entry.submitTime || null, moduleUpdateTime: entry.updateTime || null, moduleReturnedTime: entry.returnedTime || null}] : []
            })
          } else if (entry.moduleName) {
            // 追加模块条目（去重）
            const existing = rawList.find(e => e.name === entry.name)
            if (existing && !existing.moduleEntries.some(e => e.moduleName === entry.moduleName)) {
              existing.moduleEntries.push({moduleName: entry.moduleName, moduleStatus: entry.status, submitTime: entry.submitTime || null, moduleUpdateTime: entry.updateTime || null, moduleReturnedTime: entry.returnedTime || null})
            }
          }
        })
      })
    }
    // 按 engineerId 升序排列，与 weekly_report_personnel.id 一致
    rawList.sort((a, b) => (a.engineerId || 0) - (b.engineerId || 0))
  }

  // 展平：将 moduleEntries 展开为多行
  const flattened = []
  let seq = 0
  for (const person of rawList) {
    const entries = person.moduleEntries && person.moduleEntries.length > 0
      ? person.moduleEntries
      : [{moduleName: null, moduleStatus: null}]
    const count = entries.length
    seq++
    entries.forEach((entry, idx) => {
      flattened.push({
        ...person,
        _rowSpan: idx === 0 ? count : 0,
        moduleName: entry.moduleName,
        moduleStatus: entry.moduleStatus,
        submitTime: entry.submitTime || person.submitTime || null,
        moduleUpdateTime: entry.moduleUpdateTime || person.updateTime || null,
        moduleReturnedTime: entry.moduleReturnedTime || null,
        createdTime: entry.createdTime || null,
        seqIndex: idx === 0 ? seq : 0
      })
    })
  }

  peopleList.value = flattened
  peopleDialogVisible.value = true
}

// 表格合并方法：根据卡片类型动态适配列数
// 草稿: 0序号 1姓名 2提交状态 3模块名 4创建时间 5修改时间 6操作
// 其他: 0序号 1姓名 2提交状态 3模块名 4提交时间 5修改时间 6打回时间 7操作
const cellSpanMethod = ({ row, columnIndex }) => {
  if (peopleDialogType.value === '草稿') {
    if (columnIndex <= 1 || columnIndex === 6) {
      if (row._rowSpan > 0) return [row._rowSpan, 1]
      return [0, 1]
    }
    return [1, 1]
  }
  if (columnIndex <= 1 || columnIndex === 7) {
    if (row._rowSpan > 0) return [row._rowSpan, 1]
    return [0, 1]
  }
  return [1, 1]
}

const moduleGroups = computed(() => {
  if (!summaryData.value || !summaryData.value.moduleGroups) return []
  return summaryData.value.moduleGroups.map(g => ({
    ...g,
    color: reportModules.value.find(m => m.id === g.moduleId)?.color || '#2563eb'
  }))
})

// 加载汇总数据
const loadSummary = async () => {
  try {
    // 加载当前查看周次的自定义配置
    try {
      const res = await getWeekConfig(summaryWeek.value)
      if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) {
        setWeekConfig(summaryWeek.value, res.data.startDate, res.data.endDate)
      }
    } catch (e) { /* 静默处理 */ }
    summaryData.value = await getSummaryReports(summaryWeek.value)
    // 数据加载后自动选中第一个Tab
    await nextTick()
    if (moduleGroups.value.length > 0) {
      activeTab.value = moduleGroups.value[0].moduleId
    }
  } catch (e) {
    console.warn('加载汇总数据失败', e)
    summaryData.value = null
  }
}

// 一键提醒
const handleRemindAll = async () => {
  try {
    await ElMessageBox.confirm(
      '确认向所有未完全提交的人员发送周报提醒通知？',
      '一键提醒确认',
      { confirmButtonText: '确认发送', cancelButtonText: '取消', type: 'warning' }
    )
  } catch { return }
  try {
    const res = await remindUnsubmitted(summaryWeek.value)
    if (res.status === 'success') {
      msg('success', '已发送提醒通知给未提交人员')
    } else {
      msg('error', res.message || '发送提醒失败')
    }
  } catch (e) {
    msg('error', e.message || '发送提醒失败')
  }
}

// 向指定人员发送提醒
const handleRemindPerson = async (userCode, name) => {
  // 从当前 peopleList 中收集该人员的所有模块条目
  const personRows = peopleList.value.filter(p => p.userCode === userCode)
  const personStatus = personRows.length > 0 ? personRows[0].status : ''
  const moduleEntries = personRows
    .filter(p => p.moduleName)
    .map(p => ({ moduleName: p.moduleName, moduleStatus: p.moduleStatus }))

  const missingModules = []
  const returnedModules = []

  if (moduleEntries.length > 0) {
    // 有模块条目：去重并按状态分类（优先级：已打回 > 其他）
    const dedupMap = new Map()
    moduleEntries.forEach(e => {
      if (!dedupMap.has(e.moduleName)) {
        dedupMap.set(e.moduleName, e.moduleStatus)
      } else if (e.moduleStatus === 'returned' && dedupMap.get(e.moduleName) !== 'returned') {
        dedupMap.set(e.moduleName, 'returned')
      }
    })
    dedupMap.forEach((status, modName) => {
      if (status === 'returned') returnedModules.push(modName)
      else if (status !== 'submitted') missingModules.push(modName)
    })
  } else if (personStatus === 'pending' || personStatus === 'draft') {
    // 完全未提交/仅草稿人员：无任何模块条目，所有活跃模块都需要提醒
    const allActiveModules = reportModules.value
      .filter(m => m.active !== false && m.deleted !== 1)
      .map(m => m.name)
    allActiveModules.forEach(m => missingModules.push(m))
  }

  // 如果所有模块都已提交，无需提醒
  if (missingModules.length === 0 && returnedModules.length === 0) {
    msg('info', `${name} 的所有模块已全部提交，无需提醒`)
    return
  }

  // 构建确认消息
  let confirmMsg = `确认向 ${name} 发送周报提交提醒？`
  if (missingModules.length > 0) {
    confirmMsg += `\n\n未提交模块：${missingModules.join('、')}`
  }
  if (returnedModules.length > 0) {
    confirmMsg += `\n\n已打回需重填：${returnedModules.join('、')}`
  }

  try {
    await ElMessageBox.confirm(confirmMsg, '发送提醒确认', {
      confirmButtonText: '确认发送',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch {
    return // 用户取消
  }

  remindingUser.value = userCode
  try {
    const res = await remindPerson(userCode, summaryWeek.value)
    if (res.status === 'success') {
      // 使用后端返回的详细模块信息展示
      const resMissing = res.missingModules || []
      const resReturned = res.returnedModules || []
      let detail = ''
      if (resMissing.length > 0) detail += `未提交：${resMissing.join('、')}`
      if (resReturned.length > 0) {
        if (detail) detail += '；'
        detail += `已打回：${resReturned.join('、')}`
      }
      if (detail) {
        msg('success', `已向 ${name} 发送提醒通知（${detail}）`)
      } else {
        msg('success', `已向 ${name} 发送提醒通知`)
      }
    } else {
      msg('error', res.message || '发送提醒失败')
    }
  } catch (e) {
    msg('error', e.message || '发送提醒失败')
  } finally {
    remindingUser.value = ''
  }
}

// 解析内容为行数组（兼容 JSON 和纯文本）
const parseLines = (content) => {
  if (!content || !content.trim()) return []
  try {
    const parsed = JSON.parse(content)
    if (Array.isArray(parsed)) return parsed.filter(l => l && l.text !== undefined)
  } catch { /* 非 JSON，按纯文本处理 */ }
  return content.split('\n').filter(t => t.trim()).map(t => ({ text: t, updatedBy: '', updatedAt: '' }))
}

const startEdit = (reportId, moduleId, content) => {
  if (editingKey.value === reportId) { editingKey.value = ''; return }
  editingKey.value = reportId
  editingModuleId.value = moduleId
  const ts = nowStr()
  const lines = parseLines(content)
  editLines.value = lines.length > 0
    ? lines.map(l => ({ ...l, _origText: l.text, updatedBy: displayName.value, updatedAt: ts }))
    : [{ text: '', updatedBy: displayName.value, updatedAt: ts }]
  editingLineIdx.value = 0
  nextTick(() => {
    const input = document.querySelector('.entry-content-lines .line-input textarea')
    if (input) input.focus()
  })
}

const activateLine = (idx) => {
  editingLineIdx.value = idx
  nextTick(() => {
    const inputs = document.querySelectorAll('.entry-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[0].focus()
  })
}

const cancelEdit = () => {
  editingKey.value = ''
  editingModuleId.value = null
  editingLineIdx.value = null
  editLines.value = []
}

const addLineAfter = (idx) => {
  const ts = nowStr()
  editLines.value.splice(idx + 1, 0, { text: '', updatedBy: displayName.value, updatedAt: ts })
  editingLineIdx.value = idx + 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.entry-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[0].focus()
  })
}

const moveToPrevLine = (idx) => {
  if (idx <= 0) return
  editingLineIdx.value = idx - 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.entry-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[inputs.length - 1].focus()
  })
}

const moveToNextLine = (idx) => {
  if (idx >= editLines.value.length - 1) return
  editingLineIdx.value = idx + 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.entry-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[inputs.length - 1].focus()
  })
}

const deleteLine = (idx) => {
  if (editLines.value.length <= 1) return
  editLines.value.splice(idx, 1)
}

// 复制文本到系统剪贴板（查看模式用）
const copyText = async (text) => {
  if (!text) return
  clipboardText.value = text
  try {
    await navigator.clipboard.writeText(text)
  } catch { /* 不支持系统剪贴板时仅内部记录 */ }
  msg('success', '已复制到剪贴板')
}

const copyLine = async (idx) => {
  const text = editLines.value[idx].text
  clipboardText.value = text
  try {
    await navigator.clipboard.writeText(text)
  } catch { /* 不支持系统剪贴板时仅内部记录 */ }
  msg('success', '已复制到剪贴板')
}

const pasteLine = async (idx) => {
  let text = clipboardText.value
  if (!text) {
    try {
      text = await navigator.clipboard.readText()
    } catch { /* 无法读取系统剪贴板 */ }
  }
  if (!text) { msg('warning', '剪贴板为空，请先复制'); return }
  // 激活行：追加到当前行末尾；非激活行：插入新行到下方
  if (idx === editingLineIdx.value) {
    const existing = editLines.value[idx].text
    editLines.value[idx].text = existing ? existing + text : text
    msg('success', '已粘贴到当前行')
  } else {
    const ts = nowStr()
    editLines.value.splice(idx + 1, 0, { text, updatedBy: displayName.value, updatedAt: ts })
  }
}

const saveEdit = async (reportId, engineerId) => {
  if (!editingKey.value) return
  const moduleId = editingModuleId.value
  const ts = nowStr()
  const nonEmpty = editLines.value.filter(l => l.text.trim())
  nonEmpty.forEach(l => {
    if (!l.updatedBy || l.text !== l._origText) {
      l.updatedBy = displayName.value
      l.updatedAt = ts
    }
  })
  const contentStr = JSON.stringify(nonEmpty)
  try {
    const res = await editSummaryContent({ reportId, content: contentStr })
    if (res.status === 'success') {
      const group = summaryData.value?.moduleGroups?.find(g => g.moduleId === moduleId)
      if (group) {
        const entry = group.entries.find(e => e.engineerId === engineerId)
        if (entry) entry.content = contentStr
      }
      msg('success', '内容已更新')
    } else {
      msg('error', res.message || '更新失败')
    }
  } catch (e) {
    msg('error', e.message || '更新失败')
  }
  editingKey.value = ''
  editingModuleId.value = null
  editingLineIdx.value = null
  editLines.value = []
}

// 删除周报条目
const handleDeleteEntry = async (reportId) => {
  try {
    await ElMessageBox.confirm('确认删除该条周报记录？删除后不可恢复。', '确认删除', {
      confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning'
    })
    const res = await deleteReport(reportId)
    if (res.status === 'success') {
      msg('success', '已删除')
      loadSummary()
    } else {
      msg('error', res.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') msg('error', e.message || '删除失败')
  }
}

// 打回周报
const handleReturn = async (reportId) => {
  try {
    await ElMessageBox.confirm('打回后该周报将返回给填报人重新编辑，确认打回？', '打回确认', {
      confirmButtonText: '确认打回', cancelButtonText: '取消', type: 'warning'
    })
    const res = await returnReport(reportId)
    if (res.status === 'success') {
      msg('success', '已成功打回该周报')
      loadSummary()
    } else {
      msg('error', res.message || '打回失败')
    }
  } catch (e) {
    if (e !== 'cancel') msg('error', e.message || '打回失败')
  }
}

// 跳转导出页
const goExportPage = () => {
  router.push('/weeklyReport/reportExport')
}

// ======== SSE 状态变更监听：实时刷新汇总数据 ========
let summaryRefreshTimer = null
const handleSummaryStatusChange = (e) => {
  const { weekNum } = e.detail
  // 只有当前查看的周次与通知的周次一致时才刷新
  if (weekNum !== summaryWeek.value) return
  // 防抖：500ms 内多次触发只刷新一次，避免频繁请求
  if (summaryRefreshTimer) clearTimeout(summaryRefreshTimer)
  summaryRefreshTimer = setTimeout(() => {
    loadSummary()
    summaryRefreshTimer = null
  }, 500)
}

onMounted(async () => {
  if (reportModules.value.length === 0) {
    try { reportModules.value = await getReportModules() } catch (e) { console.warn('加载模块列表失败', e) }
  }
  loadSummary()
  // 监听周报状态变更事件（提交/保存草稿/打回）
  window.addEventListener('weekly-report-status-change', handleSummaryStatusChange)
})

onUnmounted(() => {
  window.removeEventListener('weekly-report-status-change', handleSummaryStatusChange)
  if (summaryRefreshTimer) clearTimeout(summaryRefreshTimer)
})

const nowStr = () => {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}
</script>

<style scoped>
.report-summary-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 12px; flex-shrink: 0;
}
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

/* 筛选栏 */
.filter-bar {
  background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed;
  display: flex; align-items: center; gap: 16px; flex-shrink: 0; margin-bottom: 14px;
}
.week-nav { display: flex; align-items: center; gap: 10px; }
.filter-label { font-size: 13px; color: #909399; white-space: nowrap; }
.week-tag { font-weight: 600; white-space: nowrap; }

/* 统计卡片 */
.summary-stats {
  display: grid; grid-template-columns: repeat(6, 1fr); gap: 12px; margin-bottom: 14px; flex-shrink: 0;
}
.stat-card :deep(.el-card__body) { padding: 16px; text-align: center; }
.stat-label { font-size: 12px; color: #909399; font-weight: 500; }
.stat-value { font-size: 24px; font-weight: 700; margin: 4px 0; transition: color 0.2s ease; }
.stat-sub { font-size: 11px; color: #c0c4cc; }

/* 统计数字变化动画 */
.stat-number-enter-active,
.stat-number-leave-active {
  transition: all 0.3s ease;
}
.stat-number-enter-from {
  opacity: 0;
  transform: scale(0.8);
}
.stat-number-leave-to {
  opacity: 0;
  transform: scale(0.8);
}

/* 状态标签切换动画 */
.status-tag-enter-active,
.status-tag-leave-active {
  transition: all 0.25s ease;
}
.status-tag-enter-from,
.status-tag-leave-to {
  opacity: 0;
  transform: translateX(-10px);
}

/* 操作按钮出现/消失动画 */
.action-btn-enter-active,
.action-btn-leave-active {
  transition: all 0.2s ease;
}
.action-btn-enter-from,
.action-btn-leave-to {
  opacity: 0;
  transform: translateX(-5px);
}

/* 模块聚合 Tab */
.summary-tabs-wrapper { flex: 1; display: flex; flex-direction: column; min-height: 0; overflow: hidden; }
.summary-tabs { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.summary-tabs :deep(.el-tabs__header) { flex-shrink: 0; margin-bottom: 0; }
.summary-tabs :deep(.el-tabs__content) { flex: 1; min-height: 0; overflow: hidden; }
.summary-tabs :deep(.el-tab-pane) { height: 100%; }
.tab-label { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; }
.module-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.tab-count { margin-left: 2px; }
.tab-scroll { height: 100%; }
.tab-content { padding: 4px 4px 0; }
.summary-entry {
  display: flex; gap: 12px; align-items: flex-start;
  padding: 12px 0; border-bottom: 1px solid #f0f0f0;
  position: relative;
  transition: background-color 0.2s ease;
}
.summary-entry:hover {
  background-color: #fafafa;
}
.summary-entry:last-child { border-bottom: none; }

/* 列表项刷新时的淡入效果 */
.entry-fade-enter-active,
.entry-fade-leave-active {
  transition: all 0.25s ease;
}
.entry-fade-enter-from,
.entry-fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
.entry-info { flex: 1; min-width: 0; }
.entry-toolbar {
  display: flex; justify-content: space-between; align-items: center;
  gap: 8px; margin-bottom: 4px;
}
.entry-name {
  font-size: 13px; font-weight: 600; color: #303133;
  display: flex; align-items: center; gap: 8px;
}
.entry-actions { display: flex; align-items: center; gap: 4px; }
.entry-content-lines { font-size: 13px; color: #606266; }
.content-line {
  display: flex; align-items: flex-start; gap: 6px; padding: 4px 6px; border-radius: 4px;
  transition: background 0.15s; position: relative; min-height: 32px;
}
.content-line.is-idle { cursor: pointer; }
.content-line.is-idle:hover { background: #f5f7fa; }
.content-line.is-editing { background: #f0f7ff; }
.line-num {
  color: #909399; font-weight: 600; min-width: 24px; text-align: right;
  flex-shrink: 0; line-height: 1.6;
}
.line-text { flex: 1; color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; }
.line-text.empty-hint { color: #c0c4cc; font-style: italic; }
.line-input { flex: 1; min-width: 0; }
.line-input :deep(.el-textarea) { box-shadow: none; }
.line-input :deep(.el-textarea__inner) {
  font-size: 13px; box-shadow: none !important; border: none; border-radius: 0;
  padding: 0; background: transparent; resize: none; line-height: 1.6;
  min-height: 22px;
}
.line-hover-actions {
  display: none; align-items: center; gap: 0; flex-shrink: 0;
}
.line-meta {
  font-size: 11px; color: #c0c4cc; white-space: nowrap; flex-shrink: 0; line-height: 1.6;
}
.content-line.is-idle:hover .line-hover-actions { display: flex; }
.line-hover-actions .el-button { padding: 2px; }
.active-line-actions {
  display: flex; align-items: center; gap: 0; flex-shrink: 0;
}
.active-line-actions .el-button { padding: 2px; }
.edit-actions {
  display: flex; align-items: center; gap: 8px; margin-top: 6px; padding-left: 30px;
}
.empty-summary { text-align: center; padding: 40px; flex: 1; display: flex; align-items: center; justify-content: center; }

/* 可点击卡片 */
.stat-card.clickable {
  cursor: pointer;
  transition: box-shadow 0.2s ease, transform 0.1s ease;
}
.stat-card.clickable:hover {
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

</style>
