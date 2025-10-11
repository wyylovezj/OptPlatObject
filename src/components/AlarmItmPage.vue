<script setup>
const tableData = [
  {
    severity: '紧急',
    state: '未处理',
    system_name: '新核心系统',
    category: "中间件",
    object: "zcddfsjg1",
    ip: "192.168.0.1",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
    severity: '严重',
    state: '未处理',
    system_name: '客户关系系统',
    category: "中间件",
    object: "zcddfsjg2",
    ip: "192.168.0.2",
    alarm_details: "您所拨打的电话已关机，请稍后再拨，sorry，your called phone number is down，please try again soon！",
    occurrenceTime: "2025-10-13 18:00:32",
    processingTime:  "2025-10-13 21:00:32",
    operation: "查看"
  },
  {
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

function sortSeverity(a, b){
  const severityOrder = { '紧急': 1, '严重': 2 , '通知': 3 }
  return severityOrder[a.severity] - severityOrder[b.severity]
}
function getSeverityColor(severity) {
  const colorMap = {
    '紧急': '#ff4d4f',
    '严重': '#fa8c16',
    '不严重': '#52c41a'
  }
  return colorMap[severity] || '#d9d9d9'
}
</script>

<template>
  <el-table :data="tableData" border stripe style="width: 100%" :cell-style="{textAlign:'center'}" :header-cell-style="{textAlign:'center'}">
    <el-table-column type="selection" min-width="3%"/>
    <el-table-column label="序号" type="index"  :index="1" min-width="4%"/>
    <el-table-column prop="severity" sortable label="告警级别" :sort-method="sortSeverity"	 min-width="7%">
      <template #default="scope">
        <span class="severity-indicator" :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"></span>
      </template>
    </el-table-column>
    <el-table-column prop="state" label="状态" min-width="5%"/>
    <el-table-column prop="system_name" label="业务系统" min-width="10%"/>
    <el-table-column prop="category" label="告警分类" min-width="5%"/>
    <el-table-column prop="object" label="主机" min-width="6%"/>
    <el-table-column prop="ip" label="IP地址" min-width="7%"/>
    <el-table-column prop="alarm_details" label="告警描述" show-overflow-tooltip min-width="20%"/>
    <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%"/>
    <el-table-column prop="processingTime" label="处理时间" min-width="10%"/>
    <el-table-column prop="operation" label="操作" min-width="12%"/>
  </el-table>
</template>

<style scoped>
.severity-indicator {
  display: inline-block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  margin-right: 8px;
}
:deep(.el-table__body tr:hover>td) {
  background-color: inherit !important;
}
</style>
