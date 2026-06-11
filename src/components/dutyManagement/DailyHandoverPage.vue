<template>
  <div class="daily-handover-container">
    <!-- 标题栏 -->
    <div class="header-bar">
      <div class="page-title">{{ pageTitle }}</div>
    </div>

    <!-- 工具栏 -->
    <div class="toolbar">
      <div class="toolbar-left">
        <el-date-picker
          v-model="dateRange"
          type="daterange"
          range-separator="至"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          format="YYYY-MM-DD"
          value-format="YYYY-MM-DD"
          :shortcuts="dateShortcuts"
          @change="handleDateRangeChange"
          @clear="handleClear"
        />
      </div>
      <span class="filter-sep"></span>
      <div class="toolbar-right">
        <div class="toolbar-actions-left">
          <el-button v-if="permissionStore.hasPermission('daily:revoke')" size="small" @click="handleUndo">
            <el-icon><RefreshLeft /></el-icon>&nbsp;撤销
          </el-button>
          <el-button v-if="permissionStore.hasPermission('daily:save')" type="success" size="small" @click="handleSave">
            <el-icon><Check /></el-icon>&nbsp;保存
          </el-button>
          <el-button v-if="permissionStore.hasPermission('daily:load')" size="small" @click="loadData">
            <el-icon><Refresh /></el-icon>&nbsp;加载
          </el-button>
          <el-button v-if="permissionStore.hasPermission('daily:export')" size="small" type="warning" @click="handleExport">
            <el-icon><Download /></el-icon>&nbsp;导出
          </el-button>
          <el-button v-if="permissionStore.hasPermission('daily:mergeExport')" size="small" type="warning" @click="handleMergeExport">
            <el-icon><Files /></el-icon>&nbsp;合并导出
          </el-button>
        </div>
        <div class="toolbar-actions-right">
          <el-button v-if="permissionStore.hasPermission('daily:addRow')" type="primary" plain size="small" @click="handleAddRow">
            <el-icon><Plus /></el-icon>&nbsp;新增行
          </el-button>
          <el-button v-if="permissionStore.hasPermission('daily:columnManage')" plain size="small" @click="columnDialogVisible = true">
            <el-icon><Setting /></el-icon>&nbsp;列管理
          </el-button>
        </div>
      </div>
    </div>

    <!-- 表格容器 -->
    <div class="table-wrapper" ref="tableWrapperRef">
      <el-table
        :data="tableData"
        border
        style="width: 100%"
        :max-height="tableMaxHeight"
        :span-method="spanMethod"
        :header-cell-style="{ background: '#f5f7fa', color: '#303133', fontWeight: '600', textAlign: 'center' }"
        :cell-style="{ textAlign: 'center' }"
        @cell-click="onCellClick"
      >
        <!-- 工作内容列组 -->
        <el-table-column label="工作内容" align="center">
          <el-table-column prop="date" label="日期" width="60" />
          <el-table-column label="备注" width="60" />
        </el-table-column>

        <!-- 值班人 -->
        <el-table-column label="值班人" width="80">
          <template #default="{ row }">
            <div class="duty-person-cell">
              <div>{{ row.dutyPerson }}</div>
              <div class="duty-person-shift">{{ row.shiftLabel }}</div>
            </div>
          </template>
        </el-table-column>

        <!-- 动态工作内容列 -->
        <el-table-column
          v-for="col in sortedColumns"
          :key="col.field"
          :prop="col.field"
          :label="col.label"
          :header-class-name="col.visible ? '' : 'hidden-col'"
          class-name="dynamic-col"
        >
          <template #default="{ row }">
            <div v-if="col.visible" class="cell-clickable" :class="{ 'cell-modified-td': isCellModified(row, col.field) }">
              <span v-if="row[col.field + 'Status'] === '正常'" class="cell-status">√</span>
              <el-input
                v-else-if="row[col.field + 'Status'] === '其他'"
                v-model="row[col.field]"
                size="small"
                spellcheck="false"
                class="cell-input"
                placeholder="请输入内容"
                readonly
                :title="row[col.field]"
                @click.stop="openEditDialog(row, col.field)"
              />
              <span v-else class="cell-placeholder">点击填写</span>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 单元格选择对话框 -->
    <el-dialog v-model="cellDialogVisible" title="选择状态" width="360px" center :close-on-click-modal="false" class="cell-status-dialog">
      <div class="cell-dialog-content">
        <div class="dialog-hint">请选择当前工作状态</div>
        <el-radio-group v-model="selectedStatus" class="cell-radio-group">
          <el-radio-button value="正常" class="cell-radio-btn">
            <span class="radio-icon">✓</span>
            <span class="radio-text">正常</span>
          </el-radio-button>
          <el-radio-button value="其他" class="cell-radio-btn">
            <span class="radio-icon">✎</span>
            <span class="radio-text">其他</span>
          </el-radio-button>
        </el-radio-group>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="cellDialogVisible = false" round>取消</el-button>
          <el-button type="primary" @click="confirmCellStatus" round>确定</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 文本编辑对话框 -->
    <el-dialog v-model="editDialogVisible" title="编辑内容" width="420px" center :close-on-click-modal="false" class="cell-edit-dialog">
      <div class="edit-dialog-content">
        <el-scrollbar max-height="300px" class="edit-scrollbar">
          <div
            class="edit-textarea"
            contenteditable="true"
            ref="editContentRef"
            @input="editValue = $event.target.innerText"
            spellcheck="false"
          ></div>
        </el-scrollbar>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="editDialogVisible = false" round>取消</el-button>
          <el-button type="primary" @click="confirmEdit" round>确定</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 列管理对话框 -->
    <el-dialog v-model="columnDialogVisible" title="⚙ 列管理" width="560px" center :close-on-click-modal="false" class="column-manage-dialog">
      <div class="column-dialog-content">
        <div class="column-section-title">
          字段列表
          <span class="column-count">{{ sortConfigList.length }} 项</span>
        </div>
        <div class="column-list">
          <el-scrollbar max-height="330px" class="column-scrollbar">
            <div v-for="(col, index) in sortConfigList" :key="col.field" class="column-item">
              <div class="column-item-left">
                <template v-if="editingLabel === col.field">
                  <el-input
                    v-model="editingLabelValue"
                    size="small"
                    class="label-edit-input"
                    placeholder="输入新名称..."
                    @click.stop
                    @keyup.enter.stop="confirmLabelEdit(col)"
                  />
                  <span class="edit-actions">
                    <el-button size="small" text @click.stop="cancelLabelEdit">
                      <el-icon><Close /></el-icon>
                    </el-button>
                    <el-button size="small" text type="primary" @click.stop="confirmLabelEdit(col)">
                      <el-icon><Check /></el-icon>
                    </el-button>
                  </span>
                </template>
                <template v-else>
                  <el-checkbox v-model="col.visible" class="column-checkbox">{{ col.label }}</el-checkbox>
                  <el-tag v-if="col.isSystem" size="small" class="column-tag is-system" round>系统</el-tag>
                  <el-tag v-else size="small" class="column-tag is-custom" round>自定义</el-tag>
                  <el-button size="small" text @click.stop="startLabelEdit(col)" class="edit-label-btn">
                    <el-icon><Edit /></el-icon>
                  </el-button>
                </template>
              </div>
              <div class="column-item-right">
                <el-button size="small" text :disabled="index === 0" @click="moveColumn(col, 'up')" class="move-btn" :class="{ 'is-disabled': index === 0 }">
                  <el-icon><Top /></el-icon>
                </el-button>
                <el-button size="small" text :disabled="index === sortConfigList.length - 1" @click="moveColumn(col, 'down')" class="move-btn" :class="{ 'is-disabled': index === sortConfigList.length - 1 }">
                  <el-icon><Bottom /></el-icon>
                </el-button>
              </div>
            </div>
          </el-scrollbar>
        </div>
        <el-divider class="column-divider" />
        <div class="column-add-section">
          <div class="column-section-title">新增自定义字段</div>
          <div class="column-add-form">
            <el-input v-model="newColumnForm.field" placeholder="字段标识（英文）" spellcheck="false" size="default" class="add-input" />
            <el-input v-model="newColumnForm.label" placeholder="显示名称" spellcheck="false" size="default" class="add-input" />
            <el-button type="primary" @click="handleAddColumn" class="add-btn">新增</el-button>
          </div>
        </div>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="columnDialogVisible = false" class="close-btn">关闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onUnmounted } from 'vue'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import { Plus, Setting, Check, Refresh, Download, Top, Bottom, Edit, Close, Files, RefreshLeft } from '@element-plus/icons-vue'
import { usePermissionStore } from '@/stores/permissionStore.js'

const permissionStore = usePermissionStore()

// 统一消息提示：弹出前关闭已有提示，避免重叠
const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

// 待保存通知管理
let unsavedNotifyInstance = null
let hasNewRowSinceLastSave = false // 是否有新增但从未保存过的行

const showUnsavedNotify = () => {
  if (unsavedNotifyInstance) return
  ElMessage.closeAll()
  unsavedNotifyInstance = ElNotification({
    title: '',
    dangerouslyUseHTMLString: true,
    message: `
      <div class="unsaved-card">
        <div class="unsaved-card-accent"></div>
        <div class="unsaved-card-body">
          <div class="unsaved-card-icon">📝</div>
          <div class="unsaved-card-content">
            <div class="unsaved-card-title">数据未保存</div>
            <div class="unsaved-card-desc">你有待保存的数据，请及时保存</div>
          </div>
        </div>
      </div>
    `,
    duration: 0,
    position: 'top-right',
    customClass: 'unsaved-notification',
  })
}

const hideUnsavedNotify = () => {
  if (unsavedNotifyInstance) {
    unsavedNotifyInstance.close()
    unsavedNotifyInstance = null
  }
}
import { saveDailyHandoverData, getDailyHandoverData, getDailyHandoverFieldConfig, addDailyHandoverField, updateDailyHandoverFieldLabel, updateDailyHandoverFieldSortOrder, exportDailyHandover, exportMergedHandover, getDuty } from '@/api/dutyPageInterface'

// 表格容器引用，用于动态计算 max-height
const tableWrapperRef = ref(null)
const tableMaxHeight = ref(0)

// 日期范围选择器
const today = new Date().toISOString().split('T')[0]
const dateRange = ref([today, today])

// 快捷日期导航
const dateShortcuts = [
  {
    text: '本月',
    value: () => {
      const now = new Date()
      const first = new Date(now.getFullYear(), now.getMonth(), 1)
      return [first, now]
    },
  },
  {
    text: '上月',
    value: () => {
      const now = new Date()
      const first = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const last = new Date(now.getFullYear(), now.getMonth(), 0)
      return [first, last]
    },
  },
]

// 单元格对话框状态
const cellDialogVisible = ref(false)
const selectedStatus = ref('正常')
const currentCell = ref({ row: null, field: '' })

// 文本编辑对话框状态
const editDialogVisible = ref(false)
const editValue = ref('')
const currentEditRow = ref(null)
const currentEditField = ref('')
const editContentRef = ref(null)

// ========== 动态列配置 ==========
const columnConfig = ref([])

// 所有列（按排序，含隐藏列，用于保留列槽位避免跳动）
const sortedColumns = computed(() =>
  [...columnConfig.value].sort((a, b) => a.sortOrder - b.sortOrder)
)

// 可见列（按排序，仅可见列用于交互逻辑）
const visibleColumns = computed(() =>
  sortedColumns.value.filter((c) => c.visible)
)

// 工作内容字段列表（动态计算，只含可见列）
const workContentFields = computed(() => visibleColumns.value.map((c) => c.field))

// 列管理对话框状态
const columnDialogVisible = ref(false)

// 新增列表单
const newColumnForm = ref({ field: '', label: '' })

// 列名编辑状态
const editingLabel = ref('')
const editingLabelValue = ref('')

// 动态标题
const pageTitle = computed(() => {
  if (!dateRange.value || dateRange.value.length !== 2) {
    return '日常工作交接'
  }

  const [start] = dateRange.value
  const dateObj = new Date(start)
  const year = dateObj.getFullYear()
  const month = dateObj.getMonth() + 1
  return `${year}年${month}月日常工作交接`
})

// 所有数据（初始为空，由用户通过新增按钮添加）
const allData = ref([])

// 最后一次保存/加载时的数据快照，用于撤销恢复
const savedDataCopy = ref([])
const updateSavedDataCopy = () => {
  savedDataCopy.value = JSON.parse(JSON.stringify(allData.value))
}

// 检查单元格值是否与上次保存/加载时不同
const isCellModified = (row, field) => {
  const idx = allData.value.indexOf(row)
  if (idx === -1 || idx >= savedDataCopy.value.length) return false
  const savedRow = savedDataCopy.value[idx]
  if (!savedRow) return false
  return (row[field] || '') !== (savedRow[field] || '') ||
         (row[field + 'Status'] || '') !== (savedRow[field + 'Status'] || '')
}

// 过滤后的表格数据
const tableData = ref([])

// 根据日期范围过滤数据
const filterDataByDateRange = () => {
  if (!dateRange.value || dateRange.value.length !== 2) {
    tableData.value = allData.value
    return
  }

  const [startDate, endDate] = dateRange.value

  tableData.value = allData.value.filter((row) => {
    // 白班行有date，夜班行date为空
    const rowDate = row.date
    if (!rowDate) {
      // 夜班行：检查对应的白班行是否在范围内
      const index = allData.value.indexOf(row)
      const dayRow = allData.value[index - 1]
      if (dayRow && dayRow.date) {
        return dayRow.date >= startDate && dayRow.date <= endDate
      }
      return false
    }
    // 白班行：直接判断日期
    return rowDate >= startDate && rowDate <= endDate
  })
}

// 日期范围变化处理
const handleDateRangeChange = () => {
  filterDataByDateRange()
  loadData()
}

// 点击清除按钮重置为当天
const handleClear = () => {
  dateRange.value = [today, today]
  handleDateRangeChange()
}

// 初始化时过滤数据
filterDataByDateRange()

// 合并单元格方法
const spanMethod = ({ row, column, rowIndex, columnIndex }) => {
  // 第0列(日期)：每2行合并，且占2列（日期+备注1）
  if (columnIndex === 0) {
    if (rowIndex % 2 === 0) {
      return {
        rowspan: 2,
        colspan: 2, // 占2列
      }
    } else {
      return {
        rowspan: 0,
        colspan: 0,
      }
    }
  }

  // 第1列(备注1)：被第0列合并覆盖
  if (columnIndex === 1) {
    return {
      rowspan: 0,
      colspan: 0,
    }
  }

  return {
    rowspan: 1,
    colspan: 1,
  }
}

// 单元格点击处理（通过 el-table 的 @cell-click 事件代理）
const onCellClick = (row, column) => {
  const field = column.property
  // 只处理工作内容列，不处理日期、值班人、备注等列
  if (!field || !workContentFields.value.includes(field)) return

  currentCell.value = { row, field }
  selectedStatus.value = row[field + 'Status'] || '正常'
  cellDialogVisible.value = true
}

// 确认单元格状态
const confirmCellStatus = () => {
  const { row, field } = currentCell.value
  if (!row || !field) return

  row[field + 'Status'] = selectedStatus.value

  if (selectedStatus.value === '正常') {
    // 选择正常，清空文本内容
    row[field] = ''
    showUnsavedNotify()
  } else if (selectedStatus.value === '其他') {
    // 选择其他，默认空文本
    if (!row[field]) {
      row[field] = ''
    }
  }

  cellDialogVisible.value = false

  // 选择其他后，直接弹出文本编辑框
  if (selectedStatus.value === '其他') {
    openEditDialog(row, field)
  }
}

// 打开文本编辑对话框
const openEditDialog = (row, field) => {
  currentEditRow.value = row
  currentEditField.value = field
  editValue.value = row[field] || ''
  editDialogVisible.value = true
  nextTick(() => {
    if (editContentRef.value) {
      editContentRef.value.innerText = row[field] || ''
    }
  })
}

// 撤销所有未保存的修改，恢复到上次保存/加载的状态
const handleUndo = async () => {
  if (savedDataCopy.value.length === 0) {
    msg('warning', '没有可撤销的数据')
    return
  }
  // 深度比对：若无实际变更（如新增行后未修改），也提示无数据可撤销
  if (JSON.stringify(allData.value) === JSON.stringify(savedDataCopy.value)) {
    msg('warning', '没有可撤销的数据')
    return
  }
  try {
    await ElMessageBox.confirm('确定要撤销所有未保存的修改吗？', '撤销确认', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })
    allData.value = JSON.parse(JSON.stringify(savedDataCopy.value))
    filterDataByDateRange()
    if (!hasNewRowSinceLastSave) {
      hideUnsavedNotify()
    }
    msg('success', '已撤销所有未保存的修改')
  } catch {
    // 用户取消，不做任何操作
  }
}

// 确认文本编辑
const confirmEdit = () => {
  const row = currentEditRow.value
  const field = currentEditField.value
  if (row && field) {
    row[field] = editValue.value
    showUnsavedNotify()
  }
  editDialogVisible.value = false
}

// ========== 新增行 ==========
const handleAddRow = async () => {
  const todayStr = new Date().toISOString().split('T')[0]
  const todayExists = allData.value.some((row) => row.date === todayStr)
  if (todayExists) {
    msg('warning', `今日（${todayStr}）的行数据已存在，无需重复新增`)
    return
  }

  const createRow = (date, dutyPerson, shiftLabel) => {
    const row = { date, remark1: '', dutyPerson, shiftLabel }
    columnConfig.value.forEach((col) => {
      row[col.field] = ''
      row[col.field + 'Status'] = '正常'
    })
    return row
  }

  // 查询ECC排班获取值班人
  let dayPersonName = null
  let nightPersonName = null
  try {
    const res = await getDuty([todayStr, todayStr])
    if (res && res.length > 0) {
      dayPersonName = res[0].eccDayPersonnelName
      nightPersonName = res[0].eccNightPersonnelName
    }
  } catch (e) {
    console.warn('获取ECC排班失败', e)
  }

  allData.value.push(
    createRow(todayStr, dayPersonName || 'ecc-白班', '（白班）'),
    createRow('', nightPersonName || 'ecc-夜班', '（夜班）')
  )
  filterDataByDateRange()
  updateSavedDataCopy()
  hasNewRowSinceLastSave = true
  showUnsavedNotify()
  msg('success', `已成功新增 ${todayStr} 的行数据`)
}

// ========== 列管理 ==========
// 新增自定义列
const handleAddColumn = async () => {
  const { field, label } = newColumnForm.value
  if (!field || !label) {
    msg('warning', '请填写字段标识和显示名称')
    return
  }
  if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(field)) {
    msg('warning', '字段标识必须以英文字母开头，只能包含字母、数字和下划线')
    return
  }
  if (columnConfig.value.some((c) => c.field === field)) {
    msg('warning', `字段标识 "${field}" 已存在，请使用其他标识`)
    return
  }
  const maxSort = Math.max(...columnConfig.value.map((c) => c.sortOrder), 0)
  // 先调用后端接口持久化
  try {
    const res = await addDailyHandoverField(field, label)
    if (res.status === 'success') {
      columnConfig.value.push({
        field,
        label,
        visible: true,
        isSystem: false,
        sortOrder: maxSort + 1,
      })
      // 初始化所有已有行的新字段
      allData.value.forEach((row) => {
        row[field] = ''
        row[field + 'Status'] = '正常'
      })
      newColumnForm.value = { field: '', label: '' }
      updateSavedDataCopy()
      showUnsavedNotify()
      msg('success', `新增字段 "${label}" 成功`)
    } else {
      msg('error', res.message || '新增字段失败')
    }
  } catch (e) {
    msg('error', e.message || '新增字段失败')
  }
}

// 列排序（上移/下移）
const moveColumn = async (col, direction) => {
  const sorted = sortConfigList.value
  const idx = sorted.findIndex((c) => c.field === col.field)
  if (idx === -1) return
  const targetIdx = direction === 'up' ? idx - 1 : idx + 1
  if (targetIdx < 0 || targetIdx >= sorted.length) return

  // 交换 sortOrder（sorted 中的对象引用自 columnConfig，直接修改即可）
  const tempSort = sorted[idx].sortOrder
  sorted[idx].sortOrder = sorted[targetIdx].sortOrder
  sorted[targetIdx].sortOrder = tempSort

  // 持久化到数据库
  try {
    await updateDailyHandoverFieldSortOrder([
      { field_key: sorted[idx].field, field_label: sorted[idx].label, sort_order: sorted[idx].sortOrder },
      { field_key: sorted[targetIdx].field, field_label: sorted[targetIdx].label, sort_order: sorted[targetIdx].sortOrder },
    ])
  } catch (e) {
    console.warn('保存排序失败', e)
  }
}

// 开始编辑列名
const startLabelEdit = (col) => {
  editingLabel.value = col.field
  editingLabelValue.value = col.label
}

// 取消列名编辑
const cancelLabelEdit = () => {
  editingLabel.value = ''
  editingLabelValue.value = ''
}

// 确认列名编辑
const confirmLabelEdit = async (col) => {
  const newLabel = editingLabelValue.value.trim()
  if (!newLabel) {
    msg('warning', '显示名称不能为空')
    return
  }
  if (newLabel === col.label) {
    cancelLabelEdit()
    return
  }
  try {
    const res = await updateDailyHandoverFieldLabel(col.field, newLabel)
    if (res.status === 'success') {
      col.label = newLabel
      cancelLabelEdit()
      msg('success', `字段名称已更新为 "${newLabel}"`)
    } else {
      msg('error', res.message || '更新字段名称失败')
    }
  } catch (e) {
    msg('error', e.message || '更新字段名称失败')
  }
}

// 按 sortOrder 排序的配置列表（用于列管理对话框展示）
const sortConfigList = computed(() =>
  [...columnConfig.value].sort((a, b) => a.sortOrder - b.sortOrder)
)

// ========== 导出 ==========
// 合并导出（交接记录sheet1 + 工作内容sheet2）
const handleMergeExport = async () => {
  if (!dateRange.value || dateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }

  try {
    const response = await exportMergedHandover(dateRange.value)
    // 从日期范围构建文件名
    const [startDate] = dateRange.value
    const dateObj = new Date(startDate)
    const year = dateObj.getFullYear()
    const month = dateObj.getMonth() + 1
    let filename = `${year}年${month}月ECC交接记录.xlsx`
    // 创建下载链接
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '合并导出成功')
  } catch (e) {
    msg('error', e.message || '合并导出失败')
  }
}

const handleExport = async () => {
  if (!dateRange.value || dateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }

  try {
    const response = await exportDailyHandover(dateRange.value)
    // 从响应头中获取文件名
    const contentDisposition = response.headers['content-disposition']
    let filename = '日常交接记录.xlsx'
    if (contentDisposition) {
      const match = contentDisposition.match(/filename\*?=(?:UTF-8'')?([^;\n]+)/i)
      if (match) {
        filename = decodeURIComponent(match[1])
      }
    }
    // 创建下载链接
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '导出成功')
  } catch (e) {
    msg('error', e.message || '导出失败')
  }
}

// ========== 保存与加载 ==========
// 将前端表格数据转换为后端格式并保存
const handleSave = async () => {
  try {
    await ElMessageBox.confirm('确定要保存当前数据吗？', '保存确认', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'info',
    })
  } catch {
    return // 用户取消，不做任何操作
  }
  const records = []

  // 每两行为一组（白班 + 夜班）
  for (let i = 0; i < allData.value.length; i += 2) {
    const dayRow = allData.value[i]
    const nightRow = allData.value[i + 1]

    if (!dayRow || !dayRow.date) continue

    const handoverDate = dayRow.date

    // 白班记录 shift_type=1
    const dayRecord = {
      handover_date: handoverDate,
      shift_type: 1,
      duty_person: dayRow.dutyPerson || 'ecc-白班',
      remark1: dayRow.remark1 || '',
      items: columnConfig.value.map(col => ({
        field_key: col.field,
        field_value: dayRow[col.field] || '',
        field_status: dayRow[col.field + 'Status'] || '',
        sort_order: col.sortOrder,
      })),
    }
    records.push(dayRecord)

    // 夜班记录 shift_type=2
    if (nightRow) {
      const nightRecord = {
        handover_date: handoverDate,
        shift_type: 2,
        duty_person: nightRow.dutyPerson || 'ecc-夜班',
        remark1: nightRow.remark1 || '',
        items: columnConfig.value.map(col => ({
          field_key: col.field,
          field_value: nightRow[col.field] || '',
          field_status: nightRow[col.field + 'Status'] || '',
          sort_order: col.sortOrder,
        })),
      }
      records.push(nightRecord)
    }
  }

  if (records.length === 0) {
    msg('warning', '没有数据需要保存')
    return
  }

  try {
    const res = await saveDailyHandoverData(records)
    if (res.status === 'success') {
      updateSavedDataCopy()
      hasNewRowSinceLastSave = false
      hideUnsavedNotify()
      msg('success', '保存成功')
    } else {
      msg('error', res.message || '保存失败')
    }
  } catch (e) {
    msg('error', e.message || '保存失败')
  }
}

// 将后端记录转换为前端行对象
const createFrontendRow = (date, dutyPerson, shiftLabel, backendRecord) => {
  const row = { date, remark1: backendRecord.remark1 || '', dutyPerson, shiftLabel }
  // 从后端 items 构建字段映射
  const itemMap = {}
  if (backendRecord.items) {
    backendRecord.items.forEach(item => {
      itemMap[item.field_key] = item
    })
  }
  columnConfig.value.forEach(col => {
    const item = itemMap[col.field]
    row[col.field] = item ? item.field_value : ''
    row[col.field + 'Status'] = item ? item.field_status : ''
  })
  return row
}

// 从后端加载数据
const loadData = async () => {
  hasNewRowSinceLastSave = false
  hideUnsavedNotify()
  if (!dateRange.value || dateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }

  try {
    const res = await getDailyHandoverData(dateRange.value)
    if (res.status === 'success' && res.data) {
      // 按日期分组
      const groupedByDate = {}
      res.data.forEach(record => {
        if (!groupedByDate[record.handover_date]) {
          groupedByDate[record.handover_date] = {}
        }
        groupedByDate[record.handover_date][record.shift_type] = record
      })

      const newRows = []
      Object.keys(groupedByDate)
        .sort()
        .forEach(dateStr => {
          const dayRecord = groupedByDate[dateStr][1]
          const nightRecord = groupedByDate[dateStr][2]

          if (dayRecord) {
            newRows.push(createFrontendRow(dateStr, dayRecord.duty_person || 'ecc-白班', '（白班）', dayRecord))
          } else {
            newRows.push(createFrontendRow(dateStr, 'ecc-白班', '（白班）', { remark1: '', items: [] }))
          }

          if (nightRecord) {
            newRows.push(createFrontendRow('', nightRecord.duty_person || 'ecc-夜班', '（夜班）', nightRecord))
          } else {
            newRows.push(createFrontendRow('', 'ecc-夜班', '（夜班）', { remark1: '', items: [] }))
          }
        })

      allData.value = newRows
      updateSavedDataCopy()
      filterDataByDateRange()
      msg('success', `已加载 ${new Set(res.data.map(r => r.handover_date)).size} 条记录`)
    } else {
      allData.value = []
      filterDataByDateRange()
    }
  } catch (e) {
    msg('error', e.message || '加载数据失败')
  }
}

// 页面加载时先加载字段配置，再加载数据（避免新字段数据丢失）
// 同时监听表格容器高度变化，动态更新 max-height
let resizeObserver = null
onMounted(async () => {
  await loadFieldConfig()
  loadData()

  // 使用 ResizeObserver 监听容器高度，确保表格滚动正常工作
  nextTick(() => {
    if (tableWrapperRef.value) {
      const updateHeight = () => {
        tableMaxHeight.value = tableWrapperRef.value.clientHeight
      }
      updateHeight()
      resizeObserver = new ResizeObserver(updateHeight)
      resizeObserver.observe(tableWrapperRef.value)
    }
  })
})

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect()
  }
  ElMessage.closeAll()
  hideUnsavedNotify()
})

// 从后端加载完整的字段配置（不再硬编码系统字段）
const loadFieldConfig = async () => {
  try {
    const res = await getDailyHandoverFieldConfig()
    if (res.status === 'success' && res.data) {
      // 从后端构建全部列配置（系统字段 + 自定义字段）
      const configs = res.data.map(cfg => ({
        field: cfg.field_key,
        label: cfg.field_label,
        visible: cfg.is_visible === 1,
        isSystem: cfg.is_system === 1,
        sortOrder: cfg.sort_order,
      }))
      configs.sort((a, b) => a.sortOrder - b.sortOrder)
      columnConfig.value = configs

      // 初始化已有数据行的新字段
      allData.value.forEach((row) => {
        configs.forEach(col => {
          if (row[col.field] === undefined) {
            row[col.field] = ''
            row[col.field + 'Status'] = ''
          }
        })
      })
    } else {
      console.warn('后端字段配置为空', res)
    }
  } catch (e) {
    console.warn('加载字段配置失败', e)
  }
}


</script>

<style scoped>
.daily-handover-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  background-color: #fff;
  overflow: hidden;
  padding: 20px;
  box-sizing: border-box;
}

.header-bar {
  text-align: center;
  margin-bottom: 16px;
  flex-shrink: 0;
}

/* 日期范围选择器 - 紧凑、轮廓清晰 */
.daily-handover-container :deep(.el-range-editor) {
  height: 28px !important;
  padding: 0 6px !important;
  border: 1.5px solid #c0c4cc !important;
  border-radius: 6px !important;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06) !important;
  transition: border-color 0.2s, box-shadow 0.2s !important;
  max-width: 240px !important;
}

.daily-handover-container :deep(.el-range-editor:hover) {
  border-color: #909399 !important;
}

.daily-handover-container :deep(.el-range-editor.is-active) {
  border-color: #409eff !important;
  box-shadow: 0 0 0 2px rgba(64, 158, 255, 0.15) !important;
}

.daily-handover-container :deep(.el-range-editor .el-range-separator) {
  padding: 0 2px !important;
  line-height: 24px !important;
  font-size: 12px !important;
  color: #909399 !important;
}

.daily-handover-container :deep(.el-range-editor .el-range-input) {
  font-size: 12px !important;
}

.daily-handover-container :deep(.el-range-editor .el-range__icon) {
  font-size: 12px !important;
}

.daily-handover-container :deep(.el-range-editor .el-range__close-icon) {
  font-size: 12px !important;
}

.page-title {
  text-align: center;
  font-size: 18px;
  font-weight: bold;
  color: #303133;
}

/* 工具栏 */
.toolbar {
  display: flex;
  align-items: center;
  margin-bottom: 12px;
  flex-shrink: 0;
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  gap: 12px;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.toolbar-right {
  display: flex;
  align-items: center;
  flex: 1;
  gap: 8px;
  flex-shrink: 0;
  flex-wrap: wrap;
}

.toolbar-right .el-button {
  display: flex;
  align-items: center;
  gap: 4px;
}

.toolbar-actions-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.toolbar-actions-right {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}

/* 筛选栏竖线分割 */
.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}



/* 列管理对话框 */
:deep(.column-manage-dialog) {
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15), 0 4px 16px rgba(0, 0, 0, 0.06);
}

:deep(.column-manage-dialog .el-dialog__header) {
  padding: 20px 28px 16px;
  margin-right: 0;
  border-bottom: 1.5px solid #f0f1f3;
}

:deep(.column-manage-dialog .el-dialog__title) {
  font-size: 17px;
  font-weight: 700;
  color: #1a1a2e;
  letter-spacing: 0.2px;
}

:deep(.column-manage-dialog .el-dialog__headerbtn) {
  top: 22px;
  right: 22px;
  font-size: 16px;
}

:deep(.column-manage-dialog .el-dialog__body) {
  padding: 22px 28px 10px;
}

:deep(.column-manage-dialog .el-dialog__footer) {
  padding: 14px 28px 20px;
  border-top: 1.5px solid #f0f1f3;
}

.column-dialog-content {
  width: 100%;
}

.column-section-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 14px;
  font-weight: 600;
  color: #1a1a2e;
  margin-bottom: 10px;
}

.column-count {
  font-size: 11px;
  font-weight: 500;
  color: #8c8fa3;
  margin-left: auto;
  background: #f3f4f6;
  padding: 0 10px;
  border-radius: 10px;
  line-height: 20px;
  letter-spacing: 0.2px;
}

.column-list {
  border: 1px solid #e8e9ed;
  border-radius: 10px;
  overflow: hidden;
  background: #fff;
  margin-bottom: 0;
}

.column-scrollbar {
  max-height: 330px;
}

/* 隐藏原生滚动条 */
.column-scrollbar :deep(.el-scrollbar__wrap) {
  overflow-x: hidden !important;
}

.column-scrollbar :deep(.el-scrollbar__bar.is-horizontal) {
  display: none !important;
}

.column-scrollbar :deep(.el-scrollbar__bar.is-vertical) {
  width: 4px;
  background: transparent;
}

.column-scrollbar :deep(.el-scrollbar__thumb) {
  background-color: #d0d2da !important;
  border-radius: 4px !important;
  transition: background-color 0.2s !important;
}

.column-scrollbar :deep(.el-scrollbar__thumb:hover) {
  background-color: #b0b2be !important;
}

.column-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  border-bottom: 1px solid #f0f1f3;
  transition: all 0.15s ease;
}

.column-item:last-child {
  border-bottom: none;
}

.column-item:hover {
  background: linear-gradient(135deg, #f8f9ff 0%, #f1f4ff 100%);
}

.column-item-left {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  overflow: hidden;
  min-width: 0;
}

.column-checkbox {
  margin-right: 2px;
}

.column-checkbox :deep(.el-checkbox__label) {
  font-size: 13.5px;
  font-weight: 500;
  color: #1a1a2e;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 180px;
}

.column-tag {
  flex-shrink: 0;
  font-weight: 500 !important;
  border: none !important;
}

.column-tag.is-system {
  background: #f0f1f6 !important;
  color: #6b7280 !important;
  border: none;
  padding: 0 10px !important;
}

.column-tag.is-custom {
  background: #ecfdf5 !important;
  color: #059669 !important;
  border: none;
  padding: 0 10px !important;
}

.edit-label-btn {
  flex-shrink: 0;
  color: #c0c3ce !important;
  transition: all 0.15s !important;
  margin-left: -2px;
}

.column-item:hover .edit-label-btn {
  color: #6366f1 !important;
}

.label-edit-input {
  width: 160px;
}

.label-edit-input :deep(.el-input__wrapper) {
  padding: 0 10px !important;
  height: 30px !important;
  border-radius: 8px !important;
  border-color: #d0d2da !important;
}

.label-edit-input :deep(.el-input__wrapper.is-focus) {
  border-color: #6366f1 !important;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1) !important;
}

.edit-actions {
  display: inline-flex;
  align-items: center;
  gap: 0;
  flex-shrink: 0;
}

.edit-actions .el-button {
  padding: 6px 4px;
  font-size: 15px;
}

.column-item-right {
  display: flex;
  align-items: center;
  gap: 2px;
  flex-shrink: 0;
  margin-left: 10px;
}

.move-btn {
  color: #c0c3ce !important;
  transition: all 0.15s !important;
  padding: 4px !important;
  border-radius: 6px !important;
}

.move-btn:not(:disabled):hover {
  background: #f0f1ff !important;
  color: #6366f1 !important;
}

.move-btn.is-disabled {
  opacity: 0.3;
}

/* 分割线 */
.column-divider {
  margin: 18px 0 14px;
  border-top: 1.5px solid #f0f1f3;
}

:deep(.column-divider.el-divider--horizontal) {
  margin: 18px 0 14px;
}

.column-add-section {
  padding: 0;
}

.column-add-section .column-section-title {
  margin-bottom: 10px;
}

.column-add-form {
  display: flex;
  gap: 8px;
  align-items: center;
}

.add-input {
  flex: 1;
}

.add-input :deep(.el-input__wrapper) {
  border-radius: 8px !important;
  border-color: #e0e1e6 !important;
  height: 36px !important;
}

.add-input :deep(.el-input__wrapper.is-focus) {
  border-color: #6366f1 !important;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.08) !important;
}

.add-btn {
  flex-shrink: 0;
  border-radius: 8px !important;
  padding: 8px 20px !important;
  height: 36px !important;
  font-weight: 600 !important;
  background: #6366f1 !important;
  border-color: #6366f1 !important;
}

.add-btn:hover {
  background: #4f46e5 !important;
  border-color: #4f46e5 !important;
}

.close-btn {
  padding: 8px 32px !important;
  border-radius: 8px !important;
  font-weight: 500 !important;
  height: 36px !important;
}

.table-wrapper {
  flex: 1;
  overflow: hidden;
  min-height: 0;
}

/* 自定义输入框样式 - 默认无边框无阴影，hover 时显示 */
:deep(.el-input__wrapper) {
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 0;
  transition: border-color 0.2s;
}
:deep(.el-table__body tr:hover .el-input__wrapper) {
  border-color: var(--el-border-color) !important;
}
:deep(.el-input__wrapper.is-focus) {
  border-color: var(--el-color-primary) !important;
}

:deep(.el-input__inner) {
  text-align: center;
  padding: 8px;
}

:deep(.el-table__header) {
  background-color: #f5f7fa;
}

:deep(.el-table__header th) {
  background-color: #f5f7fa !important;
}

/* 移除表格默认斑马纹，统一所有单元格背景色为白色 */
:deep(.el-table__body tr.el-table__row) {
  background-color: #fff !important;
}
:deep(.el-table__body tr.el-table__row--striped) {
  background-color: #fff !important;
}
:deep(.el-table__body tr.el-table__row td) {
  background-color: #fff !important;
}

/* 日期列背景色 */
:deep(.el-table__body tr td:first-child) {
  background-color: #fafafa;
  font-weight: 500;
  text-align: center;
  vertical-align: middle;
}

/* 值班人列背景色 */
:deep(.el-table__body tr td:nth-child(3)) {
  background-color: #fafafa;
  font-weight: 500;
}

/* 值班人单元格样式 */
.duty-person-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  line-height: 1.4;
  padding: 4px 0;
}

.duty-person-shift {
  font-size: 11px;
  color: #909399;
  font-weight: 400;
}

/* 滚动条样式 - 表格内部滚动 */
.table-wrapper :deep(.el-scrollbar__bar.is-horizontal) {
  height: 8px;
}

.table-wrapper :deep(.el-scrollbar__bar.is-vertical) {
  width: 8px;
}

.table-wrapper :deep(.el-scrollbar__thumb) {
  background-color: #c1c1c1 !important;
  border-radius: 4px !important;
}

.table-wrapper :deep(.el-scrollbar__thumb:hover) {
  background-color: #a8a8a8 !important;
}

/* 单元格交互样式 */
.cell-clickable {
  cursor: pointer;
  padding: 0 8px;
  min-height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
  width: 100%;
  height: 100%;
  box-sizing: border-box;
}

.cell-clickable:hover {
  background-color: var(--el-fill-color-light);
}

.cell-status {
  font-size: 18px;
  color: #67c23a;
  font-weight: bold;
}

/* 已修改未保存的单元格高亮 */
.cell-modified-td {
  background-color: #fff7e6;
}

.cell-modified-td .cell-status {
  color: #d48806;
}

.cell-modified-td .cell-placeholder {
  color: #d48806;
}

.cell-modified-td :deep(.el-input__inner) {
  color: #d48806;
}

/* 撑满单元格：取消 <td> 内边距，由子元素控制 */
:deep(.dynamic-col .cell) {
  padding: 0 !important;
}
.cell-clickable {
  padding: 4px 8px;
  width: 100%;
  height: 100%;
  box-sizing: border-box;
}



.cell-placeholder {
  color: var(--el-text-color-placeholder);
  font-size: 12px;
}

/* 未保存通知卡片样式（:global 因为通知渲染在组件 DOM 树之外） */
:global(.unsaved-notification) {
  padding: 0 !important;
  border: none !important;
  border-radius: 14px !important;
  background: transparent !important;
  box-shadow: none !important;
  min-width: 340px;
}

:global(.unsaved-notification .el-notification__group) {
  margin-left: 0 !important;
  padding: 0 !important;
  align-items: stretch !important;
  width: 100%;
}

:global(.unsaved-notification .el-notification__title) {
  display: none !important;
}

:global(.unsaved-notification .el-notification__content) {
  margin: 0 !important;
  width: 100%;
}

:global(.unsaved-notification .el-notification__icon) {
  display: none !important;
}

:global(.unsaved-notification .el-notification__closeBtn) {
  position: absolute !important;
  top: 8px !important;
  right: 10px !important;
  font-size: 16px !important;
  color: #bbb !important;
  transition: color 0.2s, transform 0.2s !important;
  z-index: 1;
}

:global(.unsaved-notification .el-notification__closeBtn:hover) {
  color: #666 !important;
  transform: rotate(90deg) scale(1.15) !important;
}

:global(.unsaved-card) {
  position: relative;
  display: flex;
  background: linear-gradient(135deg, #fffaf0, #fef7e6);
  border: 1px solid #fdecc8;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.10), 0 2px 8px rgba(0, 0, 0, 0.06);
  animation: unsaved-slide-in 0.35s cubic-bezier(0.16, 1, 0.3, 1);
}

:global(.unsaved-card-accent) {
  width: 4px;
  flex-shrink: 0;
  background: linear-gradient(180deg, #fbbf24, #f59e0b);
}

:global(.unsaved-card-body) {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
}

:global(.unsaved-card-icon) {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border-radius: 10px;
  background: linear-gradient(135deg, #fef3c7, #fde68a);
  font-size: 18px;
  flex-shrink: 0;
  animation: unsaved-bounce 2s ease-in-out infinite;
}

:global(.unsaved-card-content) {
  flex: 1;
  min-width: 0;
}

:global(.unsaved-card-title) {
  font-size: 14px;
  font-weight: 700;
  color: #92400e;
  line-height: 1.4;
}

:global(.unsaved-card-desc) {
  font-size: 12.5px;
  color: #a16207;
  line-height: 1.4;
  margin-top: 1px;
}

@keyframes unsaved-slide-in {
  from {
    opacity: 0;
    transform: translateX(40px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateX(0) scale(1);
  }
}

@keyframes unsaved-bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-3px); }
}

.cell-input {
  width: 100%;
}

.cell-input :deep(.el-input__wrapper) {
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 0;
}

.cell-input :deep(.el-input__wrapper.is-focus) {
  border-color: var(--el-color-primary) !important;
}

/* 对话框样式优化 */
:deep(.cell-status-dialog) {
  border-radius: 16px;
  overflow: hidden;
}

:deep(.cell-status-dialog .el-dialog__header) {
  padding: 20px 24px 16px;
  border-bottom: 1px solid #f0f0f0;
  margin-right: 0;
}

:deep(.cell-status-dialog .el-dialog__title) {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

:deep(.cell-status-dialog .el-dialog__body) {
  padding: 24px;
}

:deep(.cell-status-dialog .el-dialog__footer) {
  padding: 16px 24px 20px;
  border-top: 1px solid #f0f0f0;
}

.cell-dialog-content {
  padding: 8px 0;
}

.dialog-hint {
  text-align: center;
  font-size: 13px;
  color: #909399;
  margin-bottom: 20px;
}

.cell-radio-group {
  display: flex;
  gap: 16px;
  justify-content: center;
}

:deep(.cell-radio-btn) {
  flex: 1;
  border-radius: 12px !important;
  border: 2px solid #e4e7ed !important;
  background: #fff !important;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
  padding: 20px 16px !important;
  height: auto !important;
  min-height: 80px !important;
  display: flex !important;
  flex-direction: column !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 8px !important;
  cursor: pointer !important;
}

:deep(.cell-radio-btn:hover) {
  border-color: #409eff !important;
  background: #ecf5ff !important;
  transform: translateY(-2px) !important;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.2) !important;
}

:deep(.cell-radio-btn.is-active) {
  border-color: #409eff !important;
  background: linear-gradient(135deg, #ecf5ff 0%, #f0f7ff 100%) !important;
  box-shadow: 0 4px 16px rgba(64, 158, 255, 0.3) !important;
  transform: scale(1.02) !important;
}

:deep(.cell-radio-btn .el-radio-button__inner) {
  padding: 0 !important;
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
}

.radio-icon {
  font-size: 28px;
  line-height: 1;
  color: #67c23a;
  transition: all 0.3s;
}

:deep(.cell-radio-btn.is-active .radio-icon) {
  color: #409eff;
  transform: scale(1.1);
}

.radio-text {
  font-size: 14px;
  font-weight: 600;
  color: #606266;
  transition: all 0.3s;
}

:deep(.cell-radio-btn.is-active .radio-text) {
  color: #409eff;
}

.dialog-footer {
  display: flex;
  gap: 12px;
  justify-content: center;
}

.dialog-footer :deep(.el-button) {
  min-width: 80px;
  font-weight: 500;
}

/* 文本编辑对话框样式 */
:deep(.cell-edit-dialog) {
  border-radius: 16px;
  overflow: hidden;
}

:deep(.cell-edit-dialog .el-dialog__header) {
  padding: 20px 24px 16px;
  border-bottom: 1px solid #f0f0f0;
  margin-right: 0;
}

:deep(.cell-edit-dialog .el-dialog__title) {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

:deep(.cell-edit-dialog .el-dialog__body) {
  padding: 20px 24px;
}

:deep(.cell-edit-dialog .el-dialog__footer) {
  padding: 16px 24px 20px;
  border-top: 1px solid #f0f0f0;
}

.edit-dialog-content {
  width: 100%;
}

.edit-scrollbar {
  border: 1px solid var(--el-border-color);
  border-radius: 4px;
  padding: 0 12px;
  transition: border-color 0.2s;
}

.edit-scrollbar:hover {
  border-color: var(--el-border-color-hover);
}

.edit-scrollbar:focus-within {
  border-color: var(--el-color-primary);
}

.edit-textarea {
  width: 100%;
  min-height: 200px;
  padding: 8px 0;
  font-size: 14px;
  line-height: 1.6;
  color: #303133;
  outline: none;
  word-wrap: break-word;
  white-space: pre-wrap;
}

.edit-textarea:empty::before {
  content: '请输入内容';
  color: var(--el-text-color-placeholder);
  pointer-events: none;
}

/* 隐藏列样式：保留 DOM 槽位，但视觉上隐藏 */
.hidden-col {
  width: 0 !important;
  min-width: 0 !important;
  max-width: 0 !important;
  overflow: hidden !important;
  padding: 0 !important;
  border: none !important;
  font-size: 0 !important;
  line-height: 0 !important;
}
.hidden-col .cell {
  display: none !important;
}
</style>
