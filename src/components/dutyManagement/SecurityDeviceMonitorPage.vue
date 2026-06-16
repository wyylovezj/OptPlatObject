<template>
  <div class="security-device-container">
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
          @change="handleDateChange"
          @clear="handleClear"
        />
      </div>
      <span class="filter-sep"></span>
      <div class="toolbar-right">
        <div class="toolbar-actions-left">
          <el-button v-if="permissionStore.hasPermission('security:save')" type="success" size="small" @click="handleSave">
            <el-icon><Check /></el-icon>&nbsp;保存
          </el-button>
          <el-button v-if="permissionStore.hasPermission('security:load')" size="small" @click="loadData">
            <el-icon><Refresh /></el-icon>&nbsp;加载
          </el-button>
          <el-button v-if="permissionStore.hasPermission('security:export')" size="small" type="warning" @click="handleExport">
            <el-icon><Download /></el-icon>&nbsp;导出
          </el-button>
        </div>
        <div class="toolbar-actions-right">
          <el-button v-if="permissionStore.hasPermission('security:addRow')" type="primary" plain size="small" @click="handleAddRow">
            <el-icon><Plus /></el-icon>&nbsp;新增行
          </el-button>
          <el-button v-if="permissionStore.hasPermission('security:deleteRow')" type="danger" plain size="small" @click="handleDeleteRow">
            <el-icon><Delete /></el-icon>&nbsp;删除选中
          </el-button>
        </div>
      </div>
    </div>
    <!-- 表格 -->
    <div class="table-wrapper" ref="tableRef">
      <el-table
        :data="tableData"
        border
        style="width: 100%"
        :max-height="tableMaxHeight"
        :header-cell-style="{ background: '#5B9BD5', color: '#FFFFFF', fontWeight: '600', textAlign: 'center' }"
        :cell-style="{ textAlign: 'center' }"
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="40" />
        <el-table-column type="index" label="序号" width="60" />
        <el-table-column label="日期" width="130">
          <template #default="{ row }">
            <el-date-picker v-model="row.record_date" type="date" placeholder="日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" size="small" style="width: 100%" @change="onRowDateChange(row)" />
          </template>
        </el-table-column>
        <el-table-column label="告警内容" min-width="280">
          <template #default="{ row }">
            <el-input v-model="row.alert_content" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
          </template>
        </el-table-column>
        <el-table-column label="ECC值班员" width="140">
          <template #default="{ row }">
            <el-select v-model="row.ecc_duty_person" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onEccSelectVisibleChange(row, $event)">
              <template #header>
                <el-input v-model="eccSearchKeyword" size="small" placeholder="搜索" clearable @click.stop @input="() => {}" style="width: 100%" />
              </template>
              <el-option v-for="p in filteredEccDutyList" :key="p.userCode" :label="p.name" :value="p.name">
                <span>{{ p.name }}</span>
                <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
              </el-option>
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="二线运维告警确认人" width="180">
          <template #default="{ row }">
            <el-select v-model="row.ops_confirm_person" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onOpsSelectVisibleChange">
              <template #header>
                <el-input v-model="opsSearchKeyword" size="small" placeholder="搜索" clearable @click.stop @input="() => {}" style="width: 100%" />
              </template>
              <el-option v-for="p in filteredOpsList" :key="p.userCode" :label="p.name" :value="p.name">
                <span>{{ p.name }}</span>
                <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
              </el-option>
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="备注" min-width="160">
          <template #default="{ row }">
            <el-input v-model="row.remark" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Check, Refresh, Download, Delete } from '@element-plus/icons-vue'
import {
  saveSecurityDeviceRecord, getSecurityDeviceRecord, deleteSecurityDeviceRecord, exportSecurityDeviceRecord,
  getDuty
} from '@/api/securityDeviceMonitorApi'
import { getSys, getNet } from '@/api/dutyPageInterface'
import { usePermissionStore } from '@/stores/permissionStore.js'

// 统一消息提示
const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }
const permissionStore = usePermissionStore()

// 表格容器引用
const tableRef = ref(null)
const tableMaxHeight = ref(0)

// 日期快捷选项
const today = new Date().toISOString().split('T')[0]
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

// 数据
const dateRange = ref([today, today])
const tableData = ref([])
const selectedRows = ref([])

// 下拉数据源
const eccDutyMap = ref({}) // 按日期缓存ECC值班人员 { 'YYYY-MM-DD': [{name, userCode}] }
const eccCurrentRow = ref(null) // 当前打开下拉框的行
const opsList = ref([])

// 下拉框搜索关键词
const eccSearchKeyword = ref('')
const opsSearchKeyword = ref('')

// 过滤后的下拉列表
const filteredEccDutyList = computed(() => {
  const date = eccCurrentRow.value?.record_date
  const list = date ? (eccDutyMap.value[date] || []) : []
  const kw = eccSearchKeyword.value.trim().toLowerCase()
  if (!kw) return list
  return list.filter(p =>
    p.name.toLowerCase().includes(kw) ||
    (p.userCode || '').toLowerCase().includes(kw)
  )
})

const filteredOpsList = computed(() => {
  const kw = opsSearchKeyword.value.trim().toLowerCase()
  if (!kw) return opsList.value
  return opsList.value.filter(p =>
    p.name.toLowerCase().includes(kw) ||
    (p.userCode || '').toLowerCase().includes(kw)
  )
})

// 下拉展开/收起时清空搜索
const onEccSelectVisibleChange = async (row, visible) => {
  if (visible) {
    eccCurrentRow.value = row
    if (row.record_date && !eccDutyMap.value[row.record_date]) {
      await fetchEccDutyForDate(row.record_date)
    }
  } else {
    eccSearchKeyword.value = ''
    eccCurrentRow.value = null
  }
}
const onOpsSelectVisibleChange = (visible) => { if (!visible) opsSearchKeyword.value = '' }

// 日期变化时清空ECC值班人（因为值班人列表按日期加载）
const onRowDateChange = (row) => {
  row.ecc_duty_person = ''
}

// username 反查辅助函数
const getEccPersonUsername = (name) => {
  if (!name) return ''
  for (const date in eccDutyMap.value) {
    const person = eccDutyMap.value[date]?.find(p => p.name === name)
    if (person) return person.userCode || ''
  }
  return ''
}
const getOpsPersonUsername = (name) => {
  if (!name) return ''
  const person = opsList.value.find(p => p.name === name)
  return person?.userCode || ''
}

// ==================== 未保存提示 ====================
const dirty = ref(false)
const isLoadingData = ref(false) // 加载数据时抑制watch

// 浏览器关闭/刷新提示
const handleBeforeUnload = (e) => {
  if (dirty.value) {
    e.preventDefault()
    e.returnValue = ''
  }
}

// 路由离开前提示
onBeforeRouteLeave(async () => {
  if (dirty.value) {
    try {
      await ElMessageBox.confirm('当前有未保存的修改，确定要离开吗？', '未保存提示', {
        confirmButtonText: '离开', cancelButtonText: '取消', type: 'warning',
      })
      return true
    } catch { return false }
  }
  return true
})

// 监听数据变化，标记未保存状态（放在 tableData 声明之后）
watch(tableData, () => { if (!isLoadingData.value) dirty.value = true }, { deep: true })

// 动态标题
const pageTitle = computed(() => {
  if (!dateRange.value || dateRange.value.length !== 2) return 'NGSOC告警ECC监控记录'
  const [start] = dateRange.value
  const d = new Date(start)
  return `${d.getFullYear()}年${d.getMonth() + 1}月NGSOC告警ECC监控记录`
})

const handleSelectionChange = (rows) => { selectedRows.value = rows }
const handleDateChange = () => { loadData() }
const handleClear = () => { dateRange.value = [today, today]; loadData() }

const handleAddRow = () => {
  tableData.value.push({
    _isNew: true,
    record_date: today,
    alert_content: '',
    ecc_duty_person: '',
    ops_confirm_person: '',
    remark: '',
  })
  loadEccDutyByTableDates()
}

const handleDeleteRow = async () => {
  if (selectedRows.value.length === 0) {
    msg('warning', '请先选中要删除的行')
    return
  }
  try {
    await ElMessageBox.confirm(`确定要删除选中的 ${selectedRows.value.length} 条记录吗？`, '删除确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'warning',
    })
  } catch { return }

  const newRows = selectedRows.value.filter(r => r._isNew)
  const savedRows = selectedRows.value.filter(r => !r._isNew && r.id)

  isLoadingData.value = true
  newRows.forEach(r => {
    const idx = tableData.value.indexOf(r)
    if (idx !== -1) tableData.value.splice(idx, 1)
  })

  for (const r of savedRows) {
    try {
      const res = await deleteSecurityDeviceRecord(r.id)
      if (res.status === 'success') {
        const idx = tableData.value.findIndex(item => item.id === r.id)
        if (idx !== -1) tableData.value.splice(idx, 1)
      } else {
        msg('error', res.message || '删除失败')
      }
    } catch (e) { msg('error', e.message || '删除失败') }
  }
  await nextTick()
  isLoadingData.value = false
  dirty.value = false
  msg('success', '删除完成')
}

const handleSave = async () => {
  const noDateRows = tableData.value.filter(r => !r.record_date)
  if (noDateRows.length > 0) {
    msg('warning', '存在未填写日期的行，请补充后再保存')
    return
  }
  try {
    await ElMessageBox.confirm('确定要保存当前数据吗？', '保存确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'info',
    })
  } catch { return }

  const records = tableData.value.map(r => ({
    id: r._isNew ? null : r.id,
    record_date: r.record_date,
    alert_content: r.alert_content || '',
    ecc_duty_person: r.ecc_duty_person || '',
    ecc_duty_person_username: getEccPersonUsername(r.ecc_duty_person),
    ops_confirm_person: r.ops_confirm_person || '',
    ops_confirm_person_username: getOpsPersonUsername(r.ops_confirm_person),
    remark: r.remark || '',
  }))

  try {
    const res = await saveSecurityDeviceRecord(records)
    if (res.status === 'success') {
      msg('success', '保存成功')
      dirty.value = false
      loadData()
      loadEccDutyByTableDates()
    } else {
      msg('error', res.message || '保存失败')
    }
  } catch (e) { msg('error', e.message || '保存失败') }
}

const loadData = async () => {
  if (dirty.value) {
    try {
      await ElMessageBox.confirm('当前有未保存的修改，重新加载将丢失更改，是否继续？', '未保存提示', {
        confirmButtonText: '继续加载', cancelButtonText: '取消', type: 'warning',
      })
    } catch { return }
  }
  if (!dateRange.value || dateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  try {
    const res = await getSecurityDeviceRecord(dateRange.value)
    if (res.status === 'success' && res.data) {
      isLoadingData.value = true
      tableData.value = res.data.map(r => ({ ...r, _isNew: false }))
      await nextTick()
      dirty.value = false
      isLoadingData.value = false
      msg('success', `已加载 ${res.data.length} 条记录`)
      loadEccDutyByTableDates()
    } else {
      isLoadingData.value = true
      tableData.value = []
      await nextTick()
      dirty.value = false
      isLoadingData.value = false
    }
  } catch (e) { msg('error', e.message || '加载数据失败') }
}

// 根据行日期加载ECC值班人员
const fetchEccDutyForDate = async (date) => {
  try {
    const data = await getDuty([date, date])
    if (data && data.length > 0) {
      const schedule = data[0]
      const list = []
      if (schedule.eccDayPersonnelName && schedule.eccDayPersonnelId) {
        list.push({ name: schedule.eccDayPersonnelName, userCode: schedule.eccDayPersonnelId })
      }
      if (schedule.eccNightPersonnelName && schedule.eccNightPersonnelId) {
        list.push({ name: schedule.eccNightPersonnelName, userCode: schedule.eccNightPersonnelId })
      }
      eccDutyMap.value[date] = list
    } else {
      eccDutyMap.value[date] = []
    }
  } catch (e) { console.error('加载ECC排班失败', e) }
}

// 根据表格中的日期批量加载ECC值班人员
const loadEccDutyByTableDates = async () => {
  const dates = [...new Set(tableData.value.map(r => r.record_date).filter(Boolean))]
  const newDates = dates.filter(d => !eccDutyMap.value[d])
  await Promise.all(newDates.map(d => fetchEccDutyForDate(d)))
}

// 加载二线运维告警确认人（系统运维 + 网络运维人员）
const loadOpsConfirmList = async () => {
  try {
    const [sysList, netList] = await Promise.all([getSys(), getNet()])
    const sysItems = (sysList || []).filter(p => p.status === 1).map(p => ({ name: p.name, userCode: p.userCode }))
    const netItems = (netList || []).filter(p => p.status === 1).map(p => ({ name: p.name, userCode: p.userCode }))
    // 合并去重（按 userCode）
    const seen = new Set()
    const merged = []
    for (const item of [...sysItems, ...netItems]) {
      if (!seen.has(item.userCode)) {
        seen.add(item.userCode)
        merged.push(item)
      }
    }
    opsList.value = merged
  } catch (e) { console.error('加载二线运维人员失败', e) }
}

const handleExport = async () => {
  if (!dateRange.value || dateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  try {
    const response = await exportSecurityDeviceRecord(dateRange.value)
    const [startDate] = dateRange.value
    const d = new Date(startDate)
    let filename = `${d.getFullYear()}年${d.getMonth() + 1}月NGSOC告警ECC监控记录表.xlsx`
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '导出成功')
  } catch (e) { msg('error', e.message || '导出失败') }
}

// ==================== 动态计算表格高度 ====================
let resizeObserver = null
const calcTableHeight = () => {
  if (tableRef.value) {
    tableMaxHeight.value = tableRef.value.clientHeight
  }
}

onMounted(() => {
  loadData()
  loadOpsConfirmList()
  window.addEventListener('beforeunload', handleBeforeUnload)
  nextTick(() => {
    calcTableHeight()
    const container = document.querySelector('.security-device-container')
    if (container) {
      resizeObserver = new ResizeObserver(calcTableHeight)
      resizeObserver.observe(container)
    }
  })
})

onUnmounted(() => {
  if (resizeObserver) resizeObserver.disconnect()
  window.removeEventListener('beforeunload', handleBeforeUnload)
  ElMessage.closeAll()
})
</script>

<style scoped>
.security-device-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  background-color: #fff;
  overflow: hidden;
  padding: 20px;
  box-sizing: border-box;
  user-select: none;
}

.header-bar {
  text-align: center;
  margin-bottom: 16px;
  flex-shrink: 0;
}

.page-title {
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

.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}

/* 日期选择器 */
.security-device-container :deep(.el-range-editor) {
  height: 28px !important;
  padding: 0 6px !important;
  border: 1.5px solid #c0c4cc !important;
  border-radius: 6px !important;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06) !important;
  max-width: 240px !important;
}

.security-device-container :deep(.el-range-editor .el-range-separator) {
  padding: 0 2px !important;
  line-height: 24px !important;
  font-size: 12px !important;
  color: #909399 !important;
}

.security-device-container :deep(.el-range-editor .el-range-input) {
  font-size: 12px !important;
}

/* 表格容器 */
.table-wrapper {
  flex: 1;
  overflow: hidden;
  min-height: 0;
}

/* 输入框样式 */
:deep(.el-input__wrapper) {
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 0 4px;
  transition: border-color 0.2s;
  justify-content: center;
}

:deep(.el-table__body tr:hover .el-input__wrapper) {
  border-color: var(--el-border-color) !important;
}

:deep(.el-input__wrapper.is-focus) {
  border-color: var(--el-color-primary) !important;
}

:deep(.el-input__inner) {
  text-align: center;
  padding: 4px 8px;
}

/* 多行文本框居中 */
:deep(.el-textarea__inner) {
  text-align: center;
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 4px 8px;
  resize: none;
}

:deep(.el-table__body tr:hover .el-textarea__inner) {
  border-color: var(--el-border-color) !important;
}

:deep(.el-textarea__inner:focus) {
  border-color: var(--el-color-primary) !important;
}

/* 下拉选择框 */
:deep(.el-select .el-select__wrapper) {
  border: 1px solid var(--el-border-color) !important;
  padding: 0 8px !important;
}

:deep(.el-select .el-select__input) {
  text-align: center !important;
  flex: 1;
  min-width: 0;
}

:deep(.el-select .el-select__suffix) {
  display: inline-flex !important;
  flex-shrink: 0;
}

:deep(.el-select .el-select__placeholder) {
  text-align: center !important;
}

:deep(.el-select .el-select__selected-item) {
  justify-content: center;
}

/* 下拉面板搜索框 */
:deep(.el-select .el-select-dropdown__header) {
  padding: 6px 8px 4px !important;
}

:deep(.el-select .el-select-dropdown__header .el-input__wrapper) {
  border: 1px solid var(--el-border-color) !important;
  box-shadow: none !important;
  background: #fff !important;
  justify-content: flex-start !important;
}

:deep(.el-select .el-select-dropdown__header .el-input__inner) {
  text-align: left !important;
}

/* 隐藏日期/时间组件前缀图标 */
:deep(.el-date-editor .el-input__prefix),
:deep(.el-time-picker .el-input__prefix) {
  display: none !important;
}

/* 隐藏下拉框箭头图标（不影响清除按钮，两者共用 .el-select__caret 类） */
:deep(.el-select .el-select__caret:not(.el-select__clear)) {
  display: none !important;
}

/* 表格行hover */
:deep(.el-table__body tr:hover td) {
  background-color: #f0f7ff !important;
}

/* 滚动条 */
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

/* 工具栏按钮 */
.toolbar-right .el-button {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>

<style>
/* 全局样式：下拉弹出面板宽度控制（teleported内容不受scoped影响） */
.el-select-dropdown {
  max-width: 180px !important;
}

.el-select-dropdown__header {
  padding: 6px 8px 4px !important;
}

.el-select-dropdown__header .el-input__wrapper {
  border: 1px solid var(--el-border-color) !important;
  box-shadow: none !important;
  background: #fff !important;
  justify-content: flex-start !important;
}

.el-select-dropdown__header .el-input__inner {
  text-align: left !important;
}

.el-select-dropdown__item {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
