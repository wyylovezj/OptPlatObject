<script setup>
import { ref } from 'vue'
import { closeAlert } from '@/api/interface.js'
import { ElMessage } from 'element-plus'

const tableData = ref('')
  tableData.value = [
  {
    event_id: '123456',
    severity: '紧急',
    state: '未处理',
    system_name: '新核心系统',
    category: "中间件",
    object: "zcddfsjg1",
    ip: "192.168.0.1",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:31",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    event_id: '123456',
    severity: '严重',
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
    event_id: '123456',
    severity: '不严重',
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

// 《查看》按钮模态框显示标识符
const dialogVisibleView = ref(false)

// 《查看》模态框中当前表格行变量
const currentRow = ref({})

// 《关闭》按钮模态框显示标识符
const DialogVisibleClose = ref(false)
const handleOpinion = ref('')

// 表格《告警级别》列排序规则回调函数
const sortSeverity = (a, b) =>{
  const severityOrder = { '紧急': 1, '严重': 2 , '通知': 3 }
  return severityOrder[a.severity] - severityOrder[b.severity]
}

// 表格《告警级别》列自定义内容回调函数
const getSeverityColor = (severity) =>{
  const colorMap = {
    '紧急': '#ff4d4f',
    '严重': '#fa8c16',
    '不严重': '#52c41a'
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
  <div>
    <el-table
      :data="tableData"
      border
      stripe
      style="width: 100%"
      :cell-style="{textAlign:'center'}"
      :header-cell-style="{textAlign:'center'}"
      :default-sort="{ prop: 'occurrenceTime', order: 'descending' }"
    >
      <el-table-column type="selection" min-width="3%" :resizable="false"/>
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
      <el-table-column prop="occurrenceTime" sortable :sort-orders="['descending']" class-name="no-sort-icon" label="发生时间" min-width="10%" :resizable="false"/>
      <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false"/>
      <el-table-column prop="operation" label="操作" min-width="13%" :resizable="false">
        <template #default="scope">
          <div class="operation-buttons">
            <el-button type="primary"  plain size="small" @click="handleView(scope.row)">查看</el-button>
            <el-button type="primary"  plain size="small" @click="handleClose(scope.row)">关闭</el-button>
            <el-button type="primary"  plain size="small" @click="handleCreateTicket(scope.row)">触发工单</el-button>
            <el-button type="primary"  plain size="small" @click="handleForward(scope.row)">转发</el-button>
          </div>
        </template>
      </el-table-column>
    </el-table>
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
            <span class="severity-indicator" :class="{ 'severity-blink': scope.row.severity === '紧急' }" :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"></span>
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
/* 发生时间列排序按钮隐藏 */
:deep(.no-sort-icon .caret-wrapper) {
  display: none;
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
