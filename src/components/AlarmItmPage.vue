<script setup>
import { closeAlert, searchData } from '@/api/interface.js'
import { ElMessage } from 'element-plus'
import { computed, nextTick, ref } from 'vue'
import { loading,currentPage,Query, selectedRows, selectedEventIds, DialogVisibleClose, handleOpinion, tableData, messageInstance ,blinkTrigger } from '@/utils/publicData.js'



// 初始化表格数据
const initTableData = async () => {
  try {
    // 先关闭动画
    tableData.value = await searchData(Query)

  } catch (error) {
    ElMessage.error(error.message)
  }
}
initTableData()

// 全选功能
const handleSelectAll = () => {
  tableRef.value?.toggleAllSelection()
}

// 反选功能
const handleReverseSelection = () => {
  const allRows = currentPageData.value
  allRows.forEach((row) => {
    tableRef.value?.toggleRowSelection(row, !selectedRows.value.some((selected) => selected.event_id === row.event_id))
  })
}

// 分页相关变量
const pageSize = ref(10)
const pageSizeOptions = [1,5, 10, 20, 50, 100]

// 计算当前页显示的数据
const currentPageData = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  const end = start + pageSize.value
  return tableData.value.slice(start, end)
})

// 处理页码变化
const handleCurrentChange = (page) => {
  currentPage.value = page
}

// 处理每页条数变化
const handleSizeChange = (size) => {
  pageSize.value = size
  currentPage.value = 1
}

// 表格实例引用
const tableRef = ref(null)

// 处理选择变化事件的回调函数，用于多行关闭时获取当前选中行
const handleSelectionChange = (selection) => {
  selectedRows.value = selection
}
// DOM更新后执行的操作：配合reserve-selection，实现在数据刷新后之前选中的行仍然选中
nextTick(() => {
  if (selectedRows.value.length > 0) {
    selectedRows.value.forEach((row) => {
      const found = tableData.value.find((item) => item.event_id === row.event_id)
      if (found) {
        tableRef.value?.toggleRowSelection(found, true)
      }
    })
  }
})

// 《查看》按钮模态框显示标识符
const dialogVisibleView = ref(false)

// 《查看》模态框中当前表格行变量
const currentRow = ref({})



// 表格《告警级别》列排序规则回调函数
const sortSeverity = (a, b) => {
  const severityOrder = { "严重": 1, "重要": 2, "一般": 3 }
  const severityDiff = severityOrder[a.severity] - severityOrder[b.severity]
  if (severityDiff === 0) {
    return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
  }
  return severityDiff
}

// 表格《告警级别》列自定义内容回调函数
const getSeverityColor = (severity) => {
  const colorMap = {
    "严重": '#ff4d4f',
    "重要": '#fa8c16',
    "一般": '#ffd100',
  }
  return colorMap[severity] || '#d9d9d9'
}

// 表格中《操作》中查看列按钮回调函数
const handleView = (row) => {
  currentRow.value = row
  dialogVisibleView.value = true
  // 这里可以添加查看详情的逻辑，比如打开对话框或跳转页面
}
// 表格中《操作》中关闭列按钮回调函数
const handleClose = async (row) => {
  if (selectedRows.value.length > 0) {
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.warning({
      message: '已勾选数据，请点击批量关闭',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  // 将当前行数据保存在currentRow中
  currentRow.value = row
  // 打开查看模态框
  DialogVisibleClose.value = true
}

const handleCreateTicket = (row) => {
  console.log('触发工单', row)
  // 这里可以添加触发工单的逻辑
}

const handleForward = (row) => {
  console.log('转发告警', row)
  // 这里可以添加转发告警的逻辑
}

// 《关闭》模态框中《确认》按钮回调函数

// 批量删除选中的行
const closeCurrentAlert = async () => {
  try {
    // 单行关闭时将当前行加入到接口保存要关闭的event_id的selectedRows数组中，多行关闭时直接通过表格的selected属性获取选中行。
    selectedRows.value.push(currentRow.value)
    // 调用关闭告警接口
    await closeAlert(selectedEventIds.value, handleOpinion.value)
    selectedEventIds.value.forEach(id => {
      const index = tableData.value.findIndex((item) => String(item.event_id) === String(id))
      if (index !== -1) {
        tableData.value.splice(index, 1)
      }
    })
    // 清空选中行
    selectedRows.value = []
    // // 清除表格的选中状态，这样即使旧数据重新被加载进来，也不会保持选择状态
    tableRef.value?.clearSelection()
    console.log(selectedRows.value)
    // 重置模态框状态
    DialogVisibleClose.value = false
    // 重置处理意见
    handleOpinion.value = ''
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));

    }
    messageInstance.value = ElMessage.success({
      message: '告警关闭成功',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    // 错误提示
  } catch (error) {
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.error({
      message: error.message,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
  }
}
</script>

<template>
  <div class="item-page-container">
    <!--  全选/反选按钮-->
    <div style="margin-bottom: 10px">
      <el-button type="primary" @click="handleSelectAll">全选</el-button>
      <el-button type="primary" @click="handleReverseSelection">反选</el-button>
    </div>
    <!-- 上方分页：每页条数选择 -->
    <div style="display: flex; align-items: flex-start; margin-bottom: 20px; margin-top: 10px;user-select: none">
      <span style="line-height: 30px">显示</span>
      <el-select v-model="pageSize" style="width: 70px; margin: 0 10px" @change="handleSizeChange">
        <el-option v-for="item in pageSizeOptions" :key="item" :label="item" :value="item" />
      </el-select>
      <span style="line-height: 32px">条记录</span>
    </div>
    <!-- 表格 -->
    <div class="table-container">
      <el-table
        ref="tableRef"
        :data="currentPageData"
        border
        stripe
        style="width: 100%"
        :cell-style="{ textAlign: 'center' }"
        :header-cell-style="{ textAlign: 'center' }"
        :default-sort="{ prop: 'severity', order: 'ascending' }"
        row-key="event_id"
        @selection-change="handleSelectionChange"
        v-loading="loading"
      >
        <el-table-column type="selection" reserve-selection min-width="3%" :resizable="false" />
        <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" min-width="4%" :resizable="false" />
        <el-table-column prop="event_id" label="事件ID" v-if="false" />
        <el-table-column prop="severity" sortable label="告警级别" :sort-method="sortSeverity" min-width="7%" :resizable="false">
          <template #default="scope">
          <span
            class="severity-indicator"
            :class="{ 'severity-blink': blinkTrigger && scope.row.severity === '严重' }"
            :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"
          ></span>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="5%" :resizable="false" />
        <el-table-column prop="system_name" label="业务系统" show-overflow-tooltip min-width="10%" :resizable="false">
        <template #default="{row}">
          {{ row.system_name || '/' }}
        </template>
        </el-table-column>
        <el-table-column prop="category" label="告警分类" min-width="5%" :resizable="false">
          <template #default="{row}">
            {{ row.category || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="object" label="主机" min-width="6%" :resizable="false">
          <template #default="{row}">
            {{ row.object || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP地址" min-width="8%" :resizable="false">
          <template #default="{row}">
            {{ row.ip || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="alarm_details" label="告警描述" show-overflow-tooltip min-width="19%" :resizable="false">
          <template #default="{row}">
            {{ row.alarm_details || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.occurrenceTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.processingTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="operation" label="操作" min-width="13%" :resizable="false">
          <template #default="scope">
            <div class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center">
              <el-button type="primary" plain size="small" @click="handleView(scope.row)">查看</el-button>
              <el-button type="primary" plain size="small" @click="handleClose(scope.row)">关闭</el-button>
              <el-button type="primary" plain size="small" @click="handleCreateTicket(scope.row)">触发工单</el-button>
              <el-button type="primary" plain size="small" @click="handleForward(scope.row)">转发</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
      <!-- 下方分页：显示总数和页码导航 -->
      <div style="display: flex; justify-content: space-between; align-items: center;user-select:none;margin-top: 20px">
        <div style="display: flex; align-items: center;">
          <span style="line-height: 20px">共 {{ tableData.length }} 条</span>
        </div>
        <div style="display: flex; align-items: center;">
          <el-pagination
            v-model:current-page="currentPage"
            :page-size="pageSize"
            :total="tableData.length"
            layout="prev, pager, next"
            @current-change="handleCurrentChange"
          />
        </div>
      </div>
      <!--    查看按钮模态框  -->
      <el-dialog v-model="dialogVisibleView" top="15%" title="告警详情" width="80%" :center="true">
        <el-table
          :data="[currentRow]"
          border
          :cell-style="{ textAlign: 'center', verticalAlign: 'middle', padding: '8px 0' }"
          :header-cell-style="{ textAlign: 'center' }"
        >
          <el-table-column prop="event_id" label="事件ID" v-if="true" />
          <el-table-column prop="severity" label="告警级别" min-width="50" :resizable="false">
            <template #default="scope">
            <span
              class="severity-indicator"
              :class="{ 'severity-blink': scope.row.severity === '严重' }"
              :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"
            ></span>
            </template>
          </el-table-column>
          <el-table-column prop="state" label="状态" min-width="50" :resizable="false" />
          <el-table-column prop="system_name" label="业务系统" min-width="80" :resizable="false" />
          <el-table-column prop="category" label="告警分类" min-width="50" :resizable="false" />
          <el-table-column prop="object" label="主机" min-width="50" :resizable="false" />
          <el-table-column prop="ip" label="IP地址" min-width="50" :resizable="false" />
          <el-table-column prop="alarm_details" label="告警描述" min-width="150" :resizable="false" />
          <el-table-column prop="occurrenceTime" label="发生时间" min-width="80" :resizable="false" />
          <el-table-column prop="processingTime" label="处理时间" min-width="80" :resizable="false" />
        </el-table>
      </el-dialog>
      <!-- 关闭按钮模态框 -->
      <el-dialog v-model="DialogVisibleClose" top="10%" title="关闭告警" width="40%" :center="true" :show-close="false">
        <div style="font-size: 20px; color: #606266; user-select: none">处理意见：</div>
        <div style="display: flex; align-items: center; justify-content: center; margin-bottom: 15px; margin-top: 5px">
          <el-input
            v-model="handleOpinion"
            style="width: 100%; font-size: 16px"
            type="textarea"
            :autosize="{ maxRows: 15, minRows: 10 }"
            resize="none"
            placeholder="请输入……"
          />
        </div>
        <div style="display: flex; align-items: center; justify-content: flex-end; margin-top: 10px">
          <el-button type="primary" @click="handleOpinion = ''">清空</el-button>
          <el-button type="primary" @click="closeCurrentAlert">确认</el-button>
          <el-button
            type="primary"
            @click="
            DialogVisibleClose = false;
            handleOpinion = ''
          "
          >取消</el-button
          >
        </div>
      </el-dialog>
    </div>
  </div>

</template>

<style scoped>
/* 表格容器父容器样式 */
.item-page-container {
  display: flex;
  height: 85%;
  padding-bottom: 10px;
  flex-direction: column;
  box-sizing: border-box;
}
/* 表格容器样式：防止表格行多时溢出 */
.table-container {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* 告警图形样式 */
.severity-indicator {
  display: inline-block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  vertical-align: middle;
  transition: all 0.3s ease;
  margin: 5px 0;
}
.severity-blink {
  animation: blink 0.5s infinite;
}
@keyframes blink {
  0% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.3;
    transform: scale(1.2);
    filter: brightness(0.8);
  }
  100% {
    opacity: 1;
    transform: scale(1);
  }
}
/* 表格行hover样式 */
:deep(.el-table__body tr:hover > td) {
  background-color: inherit !important;
}

/* 操作列按钮样式 */
.operation-buttons {
  display: flex;
  gap: 2px;
  white-space: nowrap;
  align-items: center;
}

.operation-buttons :deep(.el-button) {
  padding: 5px 8px;
  margin: 0;
}

/* 模态框title标题颜色 */
:deep(.el-dialog__title) {
  user-select: none;
  color: #409eff; /* 可以根据需要调整颜色值 */
}

/* 关闭按钮告警模态框样式 */
:deep(.el-dialog__header) {
  border-bottom: 1px solid #dcdfe6;
  margin-bottom: 0;
}

:deep(.el-dialog__body) {
  padding-top: 20px;
}

:deep(.el-textarea__inner) {
  border-color: #409eff;
}

/* 禁止表头文本选中 */
:deep(.el-table__header-wrapper th) {
  user-select: none;
}
/* 设置表头字体颜色为黑色 */
:deep(.el-table__header-wrapper th .cell) {
  color: black !important;
}
</style>
