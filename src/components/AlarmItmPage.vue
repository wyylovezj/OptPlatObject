<script setup>
import { ref,nextTick,computed   } from 'vue'
import { closeAlert } from '@/api/interface.js'
import { ElMessage } from 'element-plus'

const tableData = ref('')
  tableData.value = [
  {
    event_id: '1',
    severity: '严重',
    state: '未处理',
    system_name: '新核心系统',
    category: "中间件",
    object: "zcddfsjg1",
    ip: "192.168.0.1",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:31",
    processingTime:  "2025-10-13 20:00:32",
    operation: "查看"
  },
    {
      event_id: '2',
      severity: '严重',
      state: '未处理',
      system_name: '新核心系统',
      category: "中间件",
      object: "zcddfsjg1",
      ip: "192.168.0.1",
      alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
      occurrenceTime: "2025-10-13 17:00:31",
      processingTime:  "2025-10-13 21:00:32",
      operation: "查看"
    },
  {
    event_id: '3',
    severity: '重要',
    state: '未处理',
    system_name: '客户关系系统',
    category: "中间件",
    object: "zcddfsjg2",
    ip: "192.168.0.2",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:33",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '4',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '5',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '6',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '7',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },  {
    event_id: '8',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '9',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '10',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '123456',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '11',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '12',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '13',
    severity: '一般',
    state: '未处理',
    system_name: '内部评级系统',
    category: "中间件",
    object: "zcddfsjg3",
    ip: "192.168.0.3",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
]
// 全选功能
const handleSelectAll = () => {
  tableRef.value?.toggleAllSelection()
}

// 反选功能
const handleReverseSelection = () => {
  const allRows = currentPageData.value
  allRows.forEach(row => {
    tableRef.value?.toggleRowSelection(row, !selectedRows.value.some(selected => selected.event_id === row.event_id))
  })
}

// 分页相关变量
const currentPage = ref(1)
const pageSize = ref(10)
const pageSizeOptions = [10, 20, 50, 100]

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
// 表格当前选中行的数组
const selectedRows = ref([])
// 处理选择变化事件的回调函数
const handleSelectionChange = (selection) => {
  selectedRows.value = selection
}
// 配合reserve-selection，实现在数据刷新后之前选中的行仍然选中
nextTick(() => {
  if (selectedRows.value.length > 0) {
    selectedRows.value.forEach(row => {
      const found = tableData.value.find(item => item.event_id === row.event_id)
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

// 《关闭》按钮模态框显示标识符
const DialogVisibleClose = ref(false)
const handleOpinion = ref('')

// 表格《告警级别》列排序规则回调函数
const sortSeverity = (a, b) =>{
  const severityOrder = { '严重': 1, '重要': 2 , '一般': 3 }
  const severityDiff = severityOrder[a.severity] - severityOrder[b.severity]
  if (severityDiff === 0) {
    return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
  }
  return severityDiff
}

// 表格《告警级别》列自定义内容回调函数
const getSeverityColor = (severity) =>{
  const colorMap = {
    '严重': '#ff4d4f',
    '重要': '#fa8c16',
    '一般': '#52c41a'
  }
  return colorMap[severity] || '#d9d9d9'
}

// 表格中《操作》中查看列按钮回调函数
const handleView = (row) => {
  currentRow.value = row
  dialogVisibleView.value = true
  // 这里可以添加查看详情的逻辑，比如打开对话框或跳转页面
}

const handleClose = (row) =>{
  currentRow.value = row
  DialogVisibleClose.value = true
  // 这里可以添加关闭告警的逻辑
}

const handleCreateTicket = (row) => {
  console.log('触发工单', row);
  // 这里可以添加触发工单的逻辑
}

const handleForward = (row) => {
  console.log('转发告警', row);
  // 这里可以添加转发告警的逻辑
}

// 《关闭》模态框中《确认》按钮回调函数
const closeCurrentAlert = async () => {
  try {
    await closeAlert(currentRow.value.event_id, handleOpinion.value)
    const index = tableData.value.findIndex(item => String(item.event_id) === currentRow.value.event_id)
    console.log(index)
    if (index !== -1) {
      tableData.value.splice(index, 1)
    }
    DialogVisibleClose.value = false
    handleOpinion.value = ''
    ElMessage.success('告警关闭成功')
    // 这里可以添加成功提示
  } catch (error) {
    // 这里可以添加错误提示
    console.error(error.message)
  }
}
</script>

<template>
  <!--  全选/反选按钮-->
  <div style="margin-bottom: 10px">
    <el-button type="primary" @click="handleSelectAll">全选</el-button>
    <el-button type="primary" @click="handleReverseSelection">反选</el-button>
  </div>
  <!-- 上方分页：每页条数选择 -->
  <div style="display: flex; align-items: flex-start; margin-bottom: 20px;margin-top: 20px">
    <span style="line-height: 30px">显示</span>
    <el-select v-model="pageSize" style="width: 70px; margin: 0 10px" @change="handleSizeChange">
      <el-option
        v-for="item in pageSizeOptions"
        :key="item"
        :label="item"
        :value="item"
      />
    </el-select>
    <span style="line-height: 32px">条记录</span>
  </div>
  <!-- 表格 -->
  <div>
    <el-table
      ref="tableRef"
      :data="currentPageData"
      border
      stripe
      height = "calc(100vh - 400px)"
      max-height ="calc(100vh - 300px)"
      style ="width: 100%;"
      :cell-style="{textAlign:'center'}"
      :header-cell-style="{textAlign:'center'}"
      :default-sort="{ prop: 'severity', order: 'ascending' }"
      row-key="event_id"
      @selection-change="handleSelectionChange"
    >
      <el-table-column type="selection" reserve-selection	label="事件ID" min-width="3%" :resizable="false"/>
      <el-table-column label="序号" type="index"  :index="1" min-width="4%" :resizable="false"/>
      <el-table-column prop="event_id" label="事件ID" v-if="false"/>
      <el-table-column prop="severity" sortable label="告警级别" :sort-method="sortSeverity" min-width="7%" :resizable="false">
        <template #default="scope">
          <span class="severity-indicator" :class="{ 'severity-blink': scope.row.severity === '紧急' }" :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"></span>
        </template>
      </el-table-column>
      <el-table-column prop="state" label="状态" min-width="5%" :resizable="false"/>
      <el-table-column prop="system_name" label="业务系统" min-width="10%" :resizable="false"/>
      <el-table-column prop="category" label="告警分类" min-width="5%" :resizable="false"/>
      <el-table-column prop="object" label="主机" min-width="6%" :resizable="false"/>
      <el-table-column prop="ip" label="IP地址" min-width="7%" :resizable="false"/>
      <el-table-column prop="alarm_details" label="告警描述" show-overflow-tooltip min-width="20%" :resizable="false"/>
      <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false"/>
      <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false"/>
      <el-table-column prop="operation" label="操作" min-width="13%" :resizable="false">
        <template #default="scope">
          <div class="operation-buttons" style="display: flex;justify-content: center;align-items: center">
            <el-button type="primary"  plain size="small" @click="handleView(scope.row)">查看</el-button>
            <el-button type="primary"  plain size="small" @click="handleClose(scope.row)">关闭</el-button>
            <el-button type="primary"  plain size="small" @click="handleCreateTicket(scope.row)">触发工单</el-button>
            <el-button type="primary"  plain size="small" @click="handleForward(scope.row)">转发</el-button>
          </div>
        </template>
      </el-table-column>
    </el-table>
    <!-- 下方分页：显示总数和页码导航 -->
    <div style="display: flex; justify-content: space-between; align-items: center;">
      <div style="display: flex; align-items: center;margin-top: 20px">
        <span style="line-height: 20px">共 {{ tableData.length }} 条</span>
      </div>
      <div style="display: flex; align-items: center;margin-top: 20px">
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
    <el-dialog
      v-model="dialogVisibleView"
      title="告警详情"
      width="80%"
      :center="true"
    >
      <el-table
        :data="[currentRow]"
        border
        :cell-style="{textAlign:'center', verticalAlign:'middle', padding: '8px 0'}"
        :header-cell-style="{textAlign:'center'}"
      >
        <el-table-column prop="event_id" label="事件ID" v-if="true"/>
        <el-table-column prop="severity" label="告警级别" min-width="50" :resizable="false">
          <template #default="scope">
            <span class="severity-indicator" :class="{ 'severity-blink': scope.row.severity === '严重' }" :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"></span>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="50" :resizable="false"/>
        <el-table-column prop="system_name" label="业务系统" min-width="80" :resizable="false"/>
        <el-table-column prop="category" label="告警分类" min-width="50" :resizable="false"/>
        <el-table-column prop="object" label="主机" min-width="50" :resizable="false"/>
        <el-table-column prop="ip" label="IP地址" min-width="50" :resizable="false"/>
        <el-table-column prop="alarm_details" label="告警描述" min-width="150" :resizable="false"/>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="80" :resizable="false"/>
        <el-table-column prop="processingTime" label="处理时间" min-width="80" :resizable="false"/>
      </el-table>
    </el-dialog>
<!-- 关闭按钮模态框 -->
    <el-dialog
      v-model="DialogVisibleClose"
      title="关闭告警"
      width="40%"
      :center="true"
      :show-close="false"
    >
      <div style="font-size: 20px;color: #606266;user-select: none">处理意见：</div>
      <div style="display: flex; align-items: center; justify-content: center;margin-bottom: 15px;margin-top: 5px">
        <el-input
          v-model="handleOpinion"
          style="width: 100%;font-size: 16px"
          type="textarea"
          :autosize="{maxRows: 15,minRows: 10}"
          resize="none"
          placeholder="请输入……"
        />
      </div>
      <div style="display: flex; align-items: center; justify-content: flex-end;margin-top: 10px">
        <el-button type="primary" @click="handleOpinion = ''">清空</el-button>
        <el-button type="primary" @click="closeCurrentAlert">确认</el-button>
        <el-button type="primary" @click="DialogVisibleClose = false;handleOpinion = ''">取消</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<style scoped>
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
:deep(.el-table__body tr:hover>td) {
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
  color: #409EFF;  /* 可以根据需要调整颜色值 */
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
  border-color: #409EFF;
}

/* 禁止表头文本选中 */
:deep(.el-table__header-wrapper th) {
  user-select: none;
}

</style>
