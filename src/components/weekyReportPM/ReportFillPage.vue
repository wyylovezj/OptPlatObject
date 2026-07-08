<template>
  <div class="report-fill-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">运维周报填写</h2>
    </div>

    <!-- Tab 切换 -->
    <el-tabs v-model="activeTab" class="report-tabs" @tab-click="handleTabClick">
      <el-tab-pane label="填写周报" name="fill" />
      <el-tab-pane label="周报记录" name="history" />
    </el-tabs>

    <!-- Tab - 填写周报 -->
    <div v-show="activeTab === 'fill'" class="tab-content">
      <!-- 筛选栏 -->
      <div class="filter-bar">
        <div class="period-switch">
          <el-radio-group v-model="fillWeekKey" size="small" @change="handleWeekChange">
            <el-radio-button :value="'current'">本周 (第{{ currentWeek }}周)</el-radio-button>
            <el-radio-button :value="'prev'">上周 (第{{ currentWeek - 1 }}周)</el-radio-button>
          </el-radio-group>
        </div>
        <el-tag type="primary" effect="light" class="week-tag">
          {{ weekDateLabel }}
        </el-tag>
        <div class="fill-status-area">
          <el-tag :type="overallStatusType" size="small" effect="light">{{ overallStatusText }}</el-tag>
          <span class="deadline-hint">提交截止：每周五 18:00</span>
        </div>
        <el-button v-if="!editRecordId" type="primary" size="small" @click="openAddDialog" :disabled="fillWeekKey === 'prev'">
          <el-icon><Plus /></el-icon>
          &nbsp;新增周报
        </el-button>
        <el-button
          v-if="!editRecordId"
          type="success"
          size="small"
          @click="handleSubmitAllDrafts"
          :disabled="fillWeekKey === 'prev' || !hasDraftRecords"
        >
          一键提交所有草稿
        </el-button>
      </div>

      <!-- 已有条目列表（Tab 形式） -->
      <div v-if="records.length === 0" class="empty-form-hint">
        <el-empty description="本周暂无周报记录，点击「新增周报」开始填写" :image-size="80" />
      </div>

      <div v-else ref="recordsTabsWrapRef" class="records-tabs-wrap">
        <el-tabs v-model="activeRecordId" class="records-tabs" @tab-remove="handleTabRemove">
          <el-tab-pane
            v-for="rec in records"
            :key="rec.id"
            :name="String(rec.id)"
            :closable="rec.status !== 'submitted'"
          >
            <template #label>
              <span class="tab-label">
                <span class="tab-dot" :style="{ background: getModuleColor(rec.moduleId) }"></span>
                {{ getModuleName(rec.moduleId) }}
                <el-tag 
                  size="small" 
                  :type="rec.status === 'submitted' ? 'success' : rec.status === 'returned' ? 'warning' : 'info'" 
                  effect="plain" 
                  round 
                  class="tab-count"
                >
                  {{ rec.status === 'submitted' ? '已提交' : rec.status === 'returned' ? '已打回' : '草稿' }}
                </el-tag>
              </span>
            </template>

            <!-- 工具栏 -->
            <div class="record-tab-toolbar">
              <div class="record-tab-info">
                <el-tag size="small" type="info" effect="plain">{{ getModuleCategory(rec.moduleId) }}</el-tag>
                <el-tag
                  :type="rec.status === 'submitted' ? 'success' : rec.status === 'returned' ? 'warning' : 'info'"
                  size="small"
                  effect="light"
                >
                  {{ rec.status === 'submitted' ? '✓ 已提交' : rec.status === 'returned' ? '⚠ 已打回，请重新编辑提交' : '草稿' }}
                </el-tag>
                <span class="record-time">{{ rec.updatedTime || '' }}</span>
              </div>
              <div class="record-tab-actions">
                <template v-if="editRecordId !== rec.id">
                  <el-button
                    v-if="rec.status !== 'submitted'"
                    type="success"
                    size="small"
                    text
                    @click="handleSubmitSingleRecord(rec)"
                    :disabled="!parseLines(rec.content).length"
                  >
                    <el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交
                  </el-button>
                  <el-button v-if="rec.status !== 'submitted'" type="primary" size="small" text @click="startInlineEdit(rec)">
                    <el-icon><Edit /></el-icon>&nbsp;编辑
                  </el-button>
                  <el-button v-if="rec.status !== 'submitted'" type="danger" size="small" text @click="handleDeleteRecord(rec.id)">
                    <el-icon><Delete /></el-icon>&nbsp;删除
                  </el-button>
                </template>
                <template v-else>
                  <el-button size="small" text @click="cancelInlineEdit">&nbsp;取消</el-button>
                  <el-button type="primary" size="small" text @click="saveInlineEdit(rec.id)">
                    <el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存
                  </el-button>
                </template>
              </div>
            </div>

            <!-- 内容行（查看 / 编辑统一样式） -->
            <div class="record-content-lines">
              <!-- 查看模式 -->
              <template v-if="editRecordId !== rec.id">
                <el-scrollbar class="edit-scrollbar">
                  <template v-if="parseLines(rec.content).length > 0">
                    <div v-for="(line, li) in parseLines(rec.content)" :key="li" class="content-line is-idle">
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
                  <span v-else style="color:#c0c4cc;">暂未填写内容</span>
                </el-scrollbar>
              </template>

              <!-- 编辑模式 -->
              <template v-else>
                <el-scrollbar class="edit-scrollbar">
                  <div
                    v-for="(line, idx) in editLines"
                  :key="idx"
                  class="content-line"
                  :class="{ 'is-editing': editingLineIdx === idx, 'is-idle': editingLineIdx !== idx }"
                  @click="activateLine(idx)"
                >
                  <span class="line-num">{{ idx + 1 }}.</span>
                  <!-- 激活行：文本域（自动换行） -->
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
                  <!-- 非激活行：纯文本 -->
                  <span v-else class="line-text" :class="{ 'empty-hint': !line.text }">
                    {{ line.text || '点击此处编辑...' }}
                  </span>
                  <!-- 行操作按钮（非激活行悬浮可见） -->
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
                <el-button size="small" text type="primary" @click="addLineAfter(editLines.length - 1)" class="add-line-btn">
                  <el-icon><Plus /></el-icon>&nbsp;添加一行
                </el-button>
                </el-scrollbar>
              </template>
            </div>
          </el-tab-pane>
        </el-tabs>
      </div>
    </div>

    <!-- Tab - 周报记录 -->
    <div v-show="activeTab === 'history'" class="tab-content history-content">
      <div class="history-scroll-wrap">
        <!-- 统计概览 -->
        <div class="history-stats">
          <el-card v-for="stat in historyStats" :key="stat.label" shadow="never" class="stat-card">
            <div class="stat-label">{{ stat.label }}</div>
            <div class="stat-value" :style="{ color: stat.color }">{{ stat.value }}</div>
            <div class="stat-sub">{{ stat.sub }}</div>
          </el-card>
        </div>

        <!-- 历史列表 -->
        <el-card shadow="never" class="history-list-card">
          <template #header>
            <div class="history-list-header">
              <span class="section-title">
                <el-icon><Clock /></el-icon>
                历史周报记录
              </span>
              <span class="history-count">共 {{ historyList.length }} 条记录</span>
            </div>
          </template>

          <div v-if="historyList.length === 0" class="history-empty">
            <el-empty description="暂无周报记录" :image-size="80" />
          </div>

          <el-timeline v-else>
            <el-timeline-item
              v-for="item in historyList"
              :key="item.weekNum"
              :type="item.hasSubmitted ? 'success' : 'warning'"
              :hollow="!item.hasSubmitted"
            >
              <el-card shadow="hover" class="history-card" @click="toggleHistoryExpand(item.weekNum)">
                <div class="history-card-header">
                  <div class="history-week-info">
                    <span class="history-week-num">第{{ item.weekNum }}周</span>
                    <span class="history-week-date">{{ item.dateRange }}</span>
                    <el-tag v-if="item.weekNum === currentWeek" size="small" type="primary" effect="light">当前周</el-tag>
                  </div>
                  <div class="history-meta">
                    <el-tag :type="item.hasSubmitted ? 'success' : 'warning'" size="small" effect="light">
                      {{ item.hasSubmitted ? '✓ 已提交' : '草稿' }}
                    </el-tag>
                    <span class="module-count-badge">{{ item.records.length }} 条记录</span>
                  </div>
                </div>

                <!-- 展开内容 -->
                <div v-show="expandedWeeks.includes(item.weekNum)" class="history-card-body">
                  <div
                    v-for="rec in item.records"
                    :key="rec.id"
                    class="history-content-block"
                    :style="{ borderLeftColor: getModuleColor(rec.moduleId) }"
                  >
                    <div class="history-content-module">
                      <span class="tag-dot" :style="{ background: getModuleColor(rec.moduleId) }"></span>
                      {{ getModuleName(rec.moduleId) }}
                      <el-tag
                        :type="rec.status === 'submitted' ? 'success' : rec.status === 'returned' ? 'warning' : 'info'"
                        size="small"
                        effect="light"
                        style="margin-left: 8px;"
                      >
                        {{ rec.status === 'submitted' ? '已提交' : rec.status === 'returned' ? '已打回' : '草稿' }}
                      </el-tag>
                    </div>
                    <div class="history-content-text">
                      <template v-if="parseLines(rec.content).length > 0">
                        <div v-for="(line, li) in parseLines(rec.content)" :key="li">
                          {{ li + 1 }}. {{ line.text }}
                        </div>
                      </template>
                      <span v-else>暂未填写</span>
                    </div>
                  </div>

                  <div class="history-card-footer">
                    <span class="history-time">{{ item.submitTime || '' }}</span>
                    <el-button size="small" @click.stop="goFillWeek(item.weekNum)">查看</el-button>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-card>
      </div>
    </div>

    <!-- 新增周报对话框 -->
    <el-dialog
      v-model="addDialogVisible"
      title="新增周报"
      width="560px"
      :close-on-click-modal="false"
      @closed="resetAddForm"
    >
      <div class="add-form">
        <div class="add-form-row">
          <span class="add-form-label">选择本周负责模块（可多选）</span>
          <div class="module-selector">
            <div
              v-for="mod in activeModules"
              :key="mod.id"
              class="module-tag"
              :class="{ selected: addForm.moduleIds.includes(mod.id), disabled: existingModuleIds.includes(mod.id) }"
              @click="!existingModuleIds.includes(mod.id) && toggleAddModule(mod.id)"
            >
              <span class="tag-dot" :style="{ background: mod.color }"></span>
              {{ mod.name }}
              <el-tag v-if="existingModuleIds.includes(mod.id)" size="small" type="info" effect="plain" style="margin-left:4px;">已有</el-tag>
            </div>
          </div>
        </div>
      </div>
      <template #footer>
        <el-button @click="addDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleAddConfirm">确认新增</el-button>
      </template>
    </el-dialog>

    <!-- 编辑对话框已移除，改为内联编辑 -->
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Edit, Delete, Clock, CopyDocument, DocumentCopy, Select } from '@element-plus/icons-vue'
import { usePermissionStore } from '@/stores/permissionStore'
import {
  getReportModules, saveReport, getMyReports, updateReport, deleteReport, submitAllDrafts,
  getWeekConfig
} from '@/api/weeklyReportApi'
import {
  reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN,
  setWeekConfig
} from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

// 当前登录用户（从权限返回结果中获取）
const permissionStore = usePermissionStore()
const username = computed(() => permissionStore.userInfo?.username || '')
const nickname = computed(() => permissionStore.userInfo?.nickname || '')

// 当前周次
const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()
const fillWeekKey = ref('current')
const activeTab = ref('fill')

// 周报记录列表（当前周次，多条）
const records = ref([])
const activeRecordId = ref('')

// 对话框状态
const addDialogVisible = ref(false)
const addForm = ref({ moduleIds: [] })

// 内联编辑状态
const editRecordId = ref(null)
const editingLineIdx = ref(null)
const editLines = ref([])
const clipboardText = ref('')

// 动态计算滚动区域高度
const recordsTabsWrapRef = ref(null)
const scrollContentHeight = ref('500px')
let resizeObserver = null
const updateScrollHeight = () => {
  const wrap = recordsTabsWrapRef.value
  if (!wrap) return
  const tabsContent = wrap.querySelector('.el-tabs__content')
  if (!tabsContent) return
  const toolbar = tabsContent.querySelector('.record-tab-toolbar')
  const toolbarHeight = toolbar?.offsetHeight || 40
  // tabsContent.clientHeight - padding(16*2) - toolbarHeight
  const available = tabsContent.clientHeight - 32 - toolbarHeight
  scrollContentHeight.value = Math.max(available, 200) + 'px'
}

watch(() => records.value.length, (len) => {
  if (len > 0) {
    nextTick(() => {
      if (recordsTabsWrapRef.value && !resizeObserver) {
        resizeObserver = new ResizeObserver(updateScrollHeight)
        resizeObserver.observe(recordsTabsWrapRef.value)
      }
      updateScrollHeight()
    })
  }
})

onUnmounted(() => {
  resizeObserver?.disconnect()
  document.removeEventListener('mousedown', handleOutsideClick)
  window.removeEventListener('weekly-report-returned', handleReportReturned)
})

// 历史数据
const historyList = ref([])
const expandedWeeks = ref([])

// 激活的模块
const activeModules = computed(() => reportModules.value.filter(m => m.active))

// 周日期标签
const weekDateLabel = computed(() => {
  const weekNum = fillWeekKey.value === 'current' ? currentWeek : currentWeek - 1
  const { monday, sunday } = getWeekDateRange(currentYear, weekNum)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)}`
})

// 当前填报周次
const fillWeek = computed(() => fillWeekKey.value === 'current' ? currentWeek : currentWeek - 1)

// 整体状态
const overallStatusType = computed(() => {
  if (records.value.some(r => r.status === 'submitted')) return 'success'
  if (records.value.some(r => r.status === 'returned')) return 'warning'
  if (records.value.length > 0) return 'info'
  return 'info'
})
const overallStatusText = computed(() => {
  const returnedCnt = records.value.filter(r => r.status === 'returned').length
  if (returnedCnt > 0) return `⚠ 已打回 ${returnedCnt} 条，请重新编辑提交`
  if (records.value.some(r => r.status === 'submitted')) {
    const cnt = records.value.filter(r => r.status === 'submitted').length
    return `✓ 已提交 ${cnt} 条`
  }
  if (records.value.length > 0) return `草稿 ${records.value.length} 条`
  return '未填写'
})

// 辅助函数
const getModuleName = (mid) => {
  const mod = reportModules.value.find(m => m.id === mid)
  return mod ? mod.name : '未知模块'
}
const getModuleColor = (mid) => {
  const mod = reportModules.value.find(m => m.id === mid)
  return mod ? mod.color : '#2563eb'
}
const getModuleCategory = (mid) => {
  const mod = reportModules.value.find(m => m.id === mid)
  return mod ? mod.category : ''
}

// 周次切换
const handleWeekChange = () => { loadFillData() }

// 记录变化时自动选中第一个 Tab
watch(() => records.value.length, () => {
  if (records.value.length > 0) {
    // 如果当前选中的 Tab 已不存在，自动切到第一个
    const ids = records.value.map(r => String(r.id))
    if (!ids.includes(activeRecordId.value)) {
      activeRecordId.value = ids[0]
    }
  } else {
    activeRecordId.value = ''
  }
})

// Tab 关闭（删除）
const handleTabRemove = (targetId) => {
  handleDeleteRecord(Number(targetId))
}

// 加载当前周数据
const loadFillData = async () => {
  if (!username.value) return
  try {
    const data = await getMyReports(fillWeek.value, username.value)
    records.value = data?.records || []
  } catch {
    records.value = []
  }
}

// 打开新增对话框
const openAddDialog = () => {
  addForm.value = { moduleIds: [] }
  addDialogVisible.value = true
}
const resetAddForm = () => { addForm.value = { moduleIds: [] } }

// 新增 - 切换模块选中
const toggleAddModule = (mid) => {
  const idx = addForm.value.moduleIds.indexOf(mid)
  if (idx >= 0) {
    addForm.value.moduleIds.splice(idx, 1)
  } else {
    addForm.value.moduleIds.push(mid)
  }
}

// 当前周已有记录的模块ID列表
const existingModuleIds = computed(() => records.value.map(r => r.moduleId))

// 是否存在草稿记录
const hasDraftRecords = computed(() => records.value.some(r => r.status !== 'submitted'))

// 一键提交所有草稿
const handleSubmitAllDrafts = async () => {
  try {
    await ElMessageBox.confirm(
      '确认将当前所有草稿和已打回的周报一键提交？提交后不可撤回。',
      '一键提交确认',
      { confirmButtonText: '确认提交', cancelButtonText: '取消', type: 'warning' }
    )
    const res = await submitAllDrafts(username.value)
    if (res.status === 'success') {
      msg('success', '所有草稿周报已提交')
      loadFillData()
    } else {
      msg('error', res.message || '一键提交失败')
    }
  } catch (e) {
    if (e !== 'cancel') msg('error', e.message || '一键提交失败')
  }
}

// 新增 - 确认新增（为每个选中模块创建一条空记录）
const handleAddConfirm = async () => {
  if (addForm.value.moduleIds.length === 0) { msg('warning', '请至少选择一个模块'); return }
  try {
    const entries = addForm.value.moduleIds.map(mid => ({ moduleId: mid, content: '' }))
    const res = await saveReport({
      username: username.value,
      weekNum: fillWeek.value,
      entries,
      status: 'draft'
    })
    if (res.status === 'success') {
      addDialogVisible.value = false
      msg('success', `已新增 ${entries.length} 个模块周报`)
      loadFillData()
    } else {
      msg('error', res.message || '新增失败')
    }
  } catch (e) {
    msg('error', e.message || '新增失败')
  }
}

// 开始内联编辑
const startInlineEdit = (rec) => {
  editRecordId.value = rec.id
  const ts = nowStr()
  const lines = parseLines(rec.content)
  editLines.value = lines.length > 0
    ? lines.map(l => ({ ...l, _origText: l.text, updatedBy: displayName.value, updatedAt: ts }))
    : [{ text: '', updatedBy: displayName.value, updatedAt: ts }]
  // 自动激活第一行
  editingLineIdx.value = 0
  nextTick(() => {
    const input = document.querySelector('.record-content-lines .line-input textarea')
    if (input) input.focus()
  })
  // 监听点击外部：内容为空时自动保存退出
  nextTick(() => document.addEventListener('mousedown', handleOutsideClick))
}

// 点击编辑区域外部时，若内容为空则自动保存退出
const handleOutsideClick = (e) => {
  if (!editRecordId.value) return
  const tabPane = document.querySelector('.el-tab-pane.is-active')
  if (tabPane && !tabPane.contains(e.target)) {
    const allEmpty = editLines.value.every(l => !l.text.trim())
    if (allEmpty) {
      autoSaveAndExit()
    }
  }
}

// 自动保存并退出编辑（内容为空时使用）
const autoSaveAndExit = async () => {
  if (!editRecordId.value) return
  const recordId = editRecordId.value
  const contentStr = JSON.stringify([])
  try {
    const rec = records.value.find(r => r.id === recordId)
    const updateData = { content: contentStr }
    if (rec && rec.status === 'returned') updateData.status = 'submitted'
    await updateReport(recordId, updateData)
    editRecordId.value = null
    editingLineIdx.value = null
    editLines.value = []
    document.removeEventListener('mousedown', handleOutsideClick)
    loadFillData()
  } catch { /* 静默处理 */ }
}

// 激活某行进入输入状态
const activateLine = (idx) => {
  editingLineIdx.value = idx
  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[0].focus()
  })
}

const cancelInlineEdit = () => {
  editRecordId.value = null
  editingLineIdx.value = null
  editLines.value = []
  document.removeEventListener('mousedown', handleOutsideClick)
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

// 获取当前时间字符串
const nowStr = () => {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// 当前用户的显示名（优先 nickname）
const displayName = computed(() => nickname.value || username.value)

// 复制文本到系统剪贴板（查看模式用）
const copyText = async (text) => {
  if (!text) return
  clipboardText.value = text
  try {
    await navigator.clipboard.writeText(text)
  } catch { /* 不支持系统剪贴板时仅内部记录 */ }
  msg('success', '已复制到剪贴板')
}

// 行操作
const addLineAfter = (idx) => {
  const ts = nowStr()
  editLines.value.splice(idx + 1, 0, { text: '', updatedBy: displayName.value, updatedAt: ts })
  editingLineIdx.value = idx + 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[0].focus()
  })
}
const moveToPrevLine = (idx) => {
  if (idx <= 0) return
  editingLineIdx.value = idx - 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[inputs.length - 1].focus()
  })
}
const moveToNextLine = (idx) => {
  if (idx >= editLines.value.length - 1) return
  editingLineIdx.value = idx + 1
  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input textarea')
    if (inputs.length > 0) inputs[inputs.length - 1].focus()
  })
}
const deleteLine = (idx) => {
  if (editLines.value.length <= 1) return
  editLines.value.splice(idx, 1)
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

// 保存内联编辑
const saveInlineEdit = async (recordId) => {
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
    const updateData = { content: contentStr }
    const res = await updateReport(recordId, updateData)
    if (res.status === 'success') {
      editRecordId.value = null
      editingLineIdx.value = null
      editLines.value = []
      document.removeEventListener('mousedown', handleOutsideClick)
      msg('success', '修改已保存')
      loadFillData()
    } else {
      msg('error', res.message || '更新失败')
    }
  } catch (e) {
    msg('error', e.message || '更新失败')
  }
}

// 提交单条周报
const handleSubmitSingleRecord = async (rec) => {
  if (!parseLines(rec.content).length) {
    msg('warning', '内容为空，无法提交')
    return
  }
  try {
    await ElMessageBox.confirm(
      `确认提交「${getModuleName(rec.moduleId)}」模块周报？提交后不可撤回。`,
      '提交确认',
      { confirmButtonText: '确认提交', cancelButtonText: '取消', type: 'warning' }
    )
    const res = await updateReport(rec.id, { status: 'submitted' })
    if (res.status === 'success') {
      msg('success', '已提交')
      loadFillData()
    } else {
      msg('error', res.message || '提交失败')
    }
  } catch (e) {
    if (e !== 'cancel') msg('error', e.message || '提交失败')
  }
}

// 删除记录
const handleDeleteRecord = async (reportId) => {
  try {
    await ElMessageBox.confirm('确认删除该条周报记录？删除后不可恢复。', '确认删除', {
      confirmButtonText: '确认删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
    const res = await deleteReport(reportId)
    if (res.status === 'success') {
      msg('success', '已删除')
      loadFillData()
    } else {
      msg('error', res.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') msg('error', e.message || '删除失败')
  }
}

// Tab 切换
const handleTabClick = () => {
  if (activeTab.value === 'history') loadHistory()
}

// 历史统计
const historyStats = computed(() => {
  const submittedWeeks = historyList.value.filter(h => h.hasSubmitted)
  const total = submittedWeeks.length
  const drafts = historyList.value.filter(h => !h.hasSubmitted).length
  let totalRecords = 0
  submittedWeeks.forEach(h => { totalRecords += h.records.filter(r => r.status === 'submitted').length })
  const avg = total > 0 ? (totalRecords / total).toFixed(1) : '0'

  let streak = 0
  const weekNums = submittedWeeks.map(h => h.weekNum).sort((a, b) => b - a)
  for (let w = currentWeek; w >= 1; w--) {
    if (weekNums.includes(w)) streak++
    else break
  }

  return [
    { label: '累计提交', value: total, sub: '周', color: '#303133' },
    { label: '草稿', value: drafts, sub: '周', color: '#e6a23c' },
    { label: '平均提交条目', value: avg, sub: '条/周', color: '#303133' },
    { label: '连续提交', value: streak, sub: '周', color: '#67c23a' },
  ]
})

// 加载历史数据
const loadHistory = async () => {
  if (!username.value) return
  try {
    const allHistory = []
    for (let w = currentWeek; w >= 1; w--) {
      try {
        const data = await getMyReports(w, username.value)
        const recs = data?.records || []
        if (recs.length > 0) {
          const { monday, sunday } = getWeekDateRange(currentYear, w)
          const hasSubmitted = recs.some(r => r.status === 'submitted')
          const latestSubmit = recs
            .filter(r => r.submitTime)
            .sort((a, b) => new Date(b.submitTime) - new Date(a.submitTime))[0]?.submitTime || ''
          allHistory.push({
            weekNum: w,
            dateRange: `${fmtDateCN(monday)} 至 ${fmtDateCN(sunday)}`,
            records: recs,
            hasSubmitted,
            submitTime: latestSubmit,
          })
        }
      } catch { /* 某些周可能没有数据 */ }
    }
    historyList.value = allHistory
  } catch (e) {
    console.warn('加载历史周报失败', e)
  }
}

// 展开/折叠历史卡片
const toggleHistoryExpand = (weekNum) => {
  const idx = expandedWeeks.value.indexOf(weekNum)
  if (idx >= 0) expandedWeeks.value.splice(idx, 1)
  else expandedWeeks.value.push(weekNum)
}

// 跳转到指定周
const goFillWeek = (weekNum) => {
  if (weekNum === currentWeek) fillWeekKey.value = 'current'
  else if (weekNum === currentWeek - 1) fillWeekKey.value = 'prev'
  activeTab.value = 'fill'
  loadFillData()
}

// ======== SSE 打回通知监听：实时刷新周报填写页 ========
const handleReportReturned = (e) => {
  const { weekNum } = e.detail
  // 只有当前查看的周次与通知的周次一致时才刷新
  if (weekNum !== fillWeek.value) return
  loadFillData()
}

onMounted(async () => {
  if (reportModules.value.length === 0) {
    try { reportModules.value = await getReportModules() }
    catch (e) { console.warn('加载模块列表失败', e) }
  }
  // 加载当前周的自定义配置
  try {
    const res = await getWeekConfig(currentWeek)
    if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) {
      setWeekConfig(currentWeek, res.data.startDate, res.data.endDate)
    }
  } catch (e) { /* 静默处理 */ }
  loadFillData()
  // 监听周报被打回事件
  window.addEventListener('weekly-report-returned', handleReportReturned)
})
</script>

<style scoped>
.report-fill-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header { margin-bottom: 12px; flex-shrink: 0; }
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

.report-tabs { flex-shrink: 0; }
.tab-content { flex: 1; min-height: 0; overflow: hidden; display: flex; flex-direction: column; gap: 14px; padding-bottom: 16px; }

/* 筛选栏 */
.filter-bar {
  background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed;
  display: flex; align-items: center; gap: 12px; flex-wrap: wrap; flex-shrink: 0;
}
.fill-status-area { margin-left: auto; display: flex; align-items: center; gap: 10px; }
.week-tag { font-weight: 600; }
.deadline-hint { font-size: 12px; color: #909399; white-space: nowrap; }

/* 记录 Tab 区域 */
.records-tabs-wrap { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.records-tabs { flex: 1; display: flex; flex-direction: column; min-height: 0; overflow: hidden; }
.records-tabs :deep(.el-tabs__header) { margin-bottom: 0; flex-shrink: 0; }
.records-tabs :deep(.el-tabs__content) {
  flex: 1; min-height: 0; overflow: hidden; padding: 16px 0;
  display: flex; flex-direction: column;
}
.records-tabs :deep(.el-tab-pane.is-active) {
  flex: 1 !important; min-height: 0 !important; overflow: hidden;
  display: flex !important; flex-direction: column !important;
}
.records-tabs :deep(.el-tab-pane) {
  position: relative;
}
.records-tabs :deep(.el-tabs__item) {
  display: inline-flex; align-items: center; gap: 6px; font-size: 13px;
}
.tab-label { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; }
.tab-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
.tab-count { margin-left: 2px; }


.record-tab-toolbar {
  display: flex; justify-content: space-between; align-items: center; gap: 8px; margin-bottom: 10px;
  min-height: 32px;
  flex-shrink: 0;
}
.record-tab-info { display: flex; align-items: center; gap: 8px; }
.record-tab-actions { display: flex; align-items: center; gap: 4px; }
.record-time { font-size: 11px; color: #c0c4cc; }
.record-content-lines {
  flex: 1; min-height: 0;
  font-size: 13px; color: #606266;
}
.record-content-lines::-webkit-scrollbar { width: 6px; }
.record-content-lines::-webkit-scrollbar-thumb { background: #c0c4cc; border-radius: 3px; }
.record-content-lines::-webkit-scrollbar-track { background: transparent; }
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
.line-text { flex: 1; color: #303133; line-height: 1.6; margin-right: 10px; white-space: pre-wrap; word-break: break-word; }
.line-text.empty-hint { color: #c0c4cc; font-style: italic; margin-right: 10px; }
.line-meta {
  font-size: 11px; color: #c0c4cc; white-space: nowrap; flex-shrink: 0; line-height: 1.6;
}
.line-input { flex: 1; min-width: 0; margin-right: 10px; }
.line-input :deep(.el-textarea) { box-shadow: none; }
.line-input :deep(.el-textarea__inner) {
  font-size: 13px; box-shadow: none !important; border: none; border-radius: 0;
  padding: 0; background: transparent; resize: none; line-height: 1.6;
  min-height: 22px;
}
.add-line-btn { align-self: flex-start; margin-top: 4px; }
/* 内容容器（无高度约束，由父级 record-content-lines 负责滚动） */
.edit-scrollbar {
  height: v-bind(scrollContentHeight);
}
/* 悬浮操作按钮（非激活行可见） */
.line-hover-actions {
  display: none; align-items: center; gap: 0; flex-shrink: 0;
}
.content-line.is-idle:hover .line-hover-actions { display: flex; }
.line-hover-actions .el-button { padding: 2px; }
.active-line-actions {
  display: flex; align-items: center; gap: 0; flex-shrink: 0;
}
.active-line-actions .el-button { padding: 2px; }
.empty-form-hint { text-align: center; padding: 40px; }

/* 对话框表单 */
.add-form { padding: 0 4px; }
.add-form-row { display: flex; flex-direction: column; gap: 6px; }
.add-form-label { font-size: 13px; font-weight: 600; color: #303133; margin-bottom: 4px; }

/* 模块多选标签 */
.module-selector { display: flex; flex-wrap: wrap; gap: 8px; padding: 8px 0; }
.module-tag {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all 0.2s;
  border: 1px solid #e4e7ed; background: #fff; user-select: none;
}
.module-tag:hover { border-color: #409eff; color: #409eff; }
.module-tag.selected {
  background: #ecf5ff; border-color: #409eff; color: #409eff; font-weight: 600;
}
.module-tag.disabled {
  opacity: 0.5; cursor: not-allowed; background: #f5f7fa; border-color: #e4e7ed; color: #c0c4cc;
}
.module-tag.disabled:hover {
  border-color: #e4e7ed; color: #c0c4cc;
}

/* 历史页 */
.history-content { overflow: hidden; }
.history-scroll-wrap {
  flex: 1; min-height: 0; overflow-y: scroll; padding-right: 6px;
}
.history-scroll-wrap::-webkit-scrollbar {
  width: 6px;
}
.history-scroll-wrap::-webkit-scrollbar-thumb {
  background: #c0c4cc; border-radius: 3px;
}
.history-scroll-wrap::-webkit-scrollbar-track {
  background: transparent;
}
.history-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; flex-shrink: 0; }
.stat-card { text-align: center; }
.stat-card :deep(.el-card__body) { padding: 16px; display: flex; flex-direction: column; gap: 4px; }
.stat-label { font-size: 12px; color: #909399; font-weight: 500; }
.stat-value { font-size: 24px; font-weight: 700; }
.stat-sub { font-size: 11px; color: #c0c4cc; }

.history-list-card { display: flex; flex-direction: column; min-height: 0; margin-top: 14px; }
.history-list-header { display: flex; justify-content: space-between; align-items: center; }
.history-count { font-size: 12px; color: #909399; }
.history-empty { padding: 40px; }

.history-card { cursor: pointer; transition: box-shadow 0.2s; }
.history-card:hover { box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06); }
.history-card :deep(.el-card__body) { padding: 0; }
.history-card-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 12px 16px; border-bottom: 1px solid #f0f0f0;
}
.history-week-info { display: flex; align-items: center; gap: 10px; }
.history-week-num { font-size: 15px; font-weight: 700; color: #303133; }
.history-week-date { font-size: 12px; color: #909399; }
.history-meta { display: flex; align-items: center; gap: 10px; }
.module-count-badge {
  font-size: 12px; color: #909399; background: #f4f4f5; padding: 2px 10px; border-radius: 10px;
}

.history-card-body { padding: 16px; }
.history-content-block {
  margin-bottom: 10px; padding: 10px 14px; background: #f5f7fa; border-radius: 8px;
  border-left: 3px solid #e4e7ed;
}
.history-content-block:last-child { margin-bottom: 0; }
.history-content-module {
  font-size: 13px; font-weight: 600; color: #303133; margin-bottom: 4px;
  display: flex; align-items: center; gap: 6px;
}
.history-content-text {
  font-size: 13px; color: #606266; line-height: 1.7; white-space: pre-wrap;
}
.history-card-footer {
  display: flex; justify-content: space-between; align-items: center;
  margin-top: 12px; padding-top: 10px; border-top: 1px solid #f0f0f0;
}
.history-time { font-size: 11px; color: #c0c4cc; }

.tag-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
</style>
