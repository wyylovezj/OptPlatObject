<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 告警列表界面组件：显示详细的告警信息列表
 * @date： 2025-12-08 09:45:07
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-08 09:45:07
 */
import { closeAlert, searchData } from '@/api/interface.js'
import { Edit, More } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { computed, nextTick, ref } from 'vue'
import {
  tableRef,
  loading,
  currentPage,
  Query,
  selectedRows,
  selectedEventIds,
  DialogVisibleClose,
  handleOpinion,
  tableData,
  messageInstance,
  blinkTrigger,
  sortSeverity,
  handleSortChange,
} from '@/utils/publicData.js'



/**
 * 初始化表格数据：获取当前查询参数下的告警列表数据，此时数据还未渲染到表格，仅仅是保存在数组中，后续将通过currentPage计算属性进行分页处理
 * @returns {Promise<void>}
 */
const initTableData = async () => {
  try {
    // 获取所有数据
    const allData = await searchData(Query)
    // 对所有数据进行排序
    tableData.value = allData.sort(sortSeverity)
  } catch (error) {
    ElMessage.error(error.message)
  }
}


// 在模版挂载前初始化表格数据，当模版挂载时数据就已经准备好
initTableData()



// 全选功能函数
const handleSelectAll = () => {
  // 调用表格的toggleAllSelection方法，全选当前页所有行
  // ?是可选链操作符，防止 tableRef.value 为 null 或 undefined 时报错
  tableRef.value?.toggleAllSelection()
}

// 反选功能函数
const handleReverseSelection = () => {
  // 获取当前页的所有数据行
  const allRows = currentPageData.value
  // 遍历每一行，切换其选中状态
  allRows.forEach((row) => {
    // 使用tableRef的toggleRowSelection方法切换行选中状态
    // 如果该行不在已选中列表中，则选中它；如果在，则取消选中
    // ?是可选链操作符，防止 tableRef.value 为 null 或 undefined 时报错
    tableRef.value?.toggleRowSelection(row, !selectedRows.value.some((selected) => selected.event_id === row.event_id))
  })
}

// 每页条数：默认为10
const pageSize = ref(10)

// 数组：每页可选显示行数
const pageSizeOptions = [5, 10, 20, 50, 100]

// 计算当前页显示的数据的索引范围
const currentPageData = computed(() => {
  // 计算当前页的起始数据的索引：索引从0开始计算
  const start = (currentPage.value - 1) * pageSize.value
  // 计算当前页的结束数据的索引
  const end = start + pageSize.value
  // 返回当前页的数据的切片
  return tableData.value.slice(start, end)
})

/**
 * 处理每页条数变化
 * @param size - 每页条数
 */
const handleSizeChange = (size) => {
  // 将响应式变量blinkTrigger的值设置为false，用于关闭闪烁效果
  blinkTrigger.value = false
  // 将响应式变量pageSize的值更新为新的每页显示数量
  pageSize.value = size
  // 将响应式变量currentPage的值重置为第一页，currentPage绑定到分页组件的当前页码属性
  currentPage.value = 1
  // 等待DOM更新完成
  nextTick(() => {
    // 将响应式变量blinkTrigger的值设置为true，用于重启闪烁效果，同步闪烁效果
    blinkTrigger.value = true
  })

}

/**
 * 处理页码变化
 * @param page - 分页组件的当前页码
 */
const handleCurrentChange = (page) => {
  // page是分页组件current-change事件传递的参数，表示当前页码
  // 将响应式变量currentPage的值更新为新的页码，currentPage绑定到分页组件的当前页码属性
  currentPage.value = page
}

/**
 * 处理选择变化事件,用于多行关闭时获取当前选中行
 * @param selection - 当前选中行的数组
 */
const handleSelectionChange = (selection) => {
  // selection是表格组件selection-change事件传递的参数，表示当前选中行的数组
  // 将响应式变量selectedRows的值更新为新的选中行数组，selectedRows绑定到表格组件的选中行属性
  selectedRows.value = selection
}

//
/**
 * 使用 nextTick 确保 DOM 更新完成后再执行行选择操作，配合reserve-selection，实现在数据刷新后之前选中的行仍然选中
 * 这个代码块主要用于在表格数据加载后，根据已选中的行 ID 自动勾选对应的表格行
 */
nextTick(() => {
  // 检查是否有选中的行数据
  if (selectedRows.value.length > 0) {
    // 遍历所有选中的行
    selectedRows.value.forEach((row) => {
      // 在表格数据中查找与当前选中行 event_id 相匹配的数据项
      const found = tableData.value.find((item) => item.event_id === row.event_id)
      // 如果找到匹配的数据项
      if (found) {
        // 使用表格引用 toggleRowSelection 方法勾选对应的行
        // 可选链操作符 (?.) 确保在 tableRef.value 不为 null 或 undefined 时才执行方法
        tableRef.value?.toggleRowSelection(found, true)
      }
    })
  }
})

// 《查看》按钮弹出的模态框的显示标识符
const dialogVisibleView = ref(false)

// 《查看》按钮弹出的模态框中当前表格行数据的变量
const currentRow = ref({})


/**
 * 表格《告警级别》列自定义内容：根据问题严重程度获取对应的颜色代码
 * @param severity - 问题的严重程度，可选值为："严重"、"重要"、"一般"
 * @returns {*|string}- 返回对应的十六进制颜色代码，如果输入不匹配则返回默认颜色
 *
 */
const getSeverityColor = (severity) => {
  // 定义严重程度与颜色的映射关系
  const colorMap = {
    "严重": '#FF0000', // 红色，表示最高优先级
    "重要": '#fa8c16', // 橙色，表示中等优先级
    "一般": '#ffd100', // 黄色，表示较低优先级
  }
  // 返回匹配的颜色代码，如果没有匹配则返回默认灰色
  return colorMap[severity] || '#d9d9d9'
}

/**
 * 表格中《操作》中查看按钮回调函数
 * @param row - 要查看的行数据对象，包含需要展示的详细信息
 */
const handleView = (row) => {
  // row 为表格列传入的当前行变量
  // 将当前选中的行数据保存到响应式变量中
  // 这些数据将被用于查看对话框的内容展示
  currentRow.value = row
  // 打开查看对话框
  dialogVisibleView.value = true
}

/**
 * 表格中《操作》中关闭列按钮回调函数
 * 根据是否有选中的行数据，执行不同的关闭逻辑：
 * 1. 如果有选中的行数据，显示提示消息
 * 2. 如果没有选中的行数据，打开关闭确认模态框
 * @param row - 要关闭的行数据对象
 * @returns {Promise<void>}
 */
const handleClose = async (row) => {
  // 检查是否有选中的行数据
  if (selectedRows.value.length > 0) {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示警告消息，提示用户使用批量关闭
    messageInstance.value = ElMessage.warning({
      message: '已勾选数据，请点击批量关闭', // 提示内容
      duration: 1000,    // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,  // 垂直偏移量，使消息垂直居中
      onClose: () => {    // 消息关闭时的回调
        messageInstance.value = null   // 清空消息实例引用
      }
    })
    return  // 终止函数执行，不打开关闭确认模态框
  }
  // 如果没有选中的行数据，执行以下逻辑：
  // 将当前行数据保存在currentRow中，用于关闭确认模态框中显示
  currentRow.value = row
  // 打开关闭确认模态框
  DialogVisibleClose.value = true
}

/**
 * 表格中《操作》中触发工单按钮回调函数
 * @param row
 */
const handleCreateTicket = (row) => {
  console.log('触发工单', row)
  // 这里可以添加触发工单的逻辑
}

/**
 * 表格中《操作》中触发转发按钮回调函数
 * @param row
 */
const handleForward = (row) => {
  console.log('转发告警', row)
  // 这里可以添加转发告警的逻辑
}

/**
 * 《关闭》模态框中《确认》按钮回调函数
 *  关闭当前告警的异步函数
 *  处理告警关闭的完整流程：
 *  1. 准备关闭数据（当前行或选中行）
 *  2. 调用关闭接口
 *  3. 更新表格数据
 *  4. 显示操作结果
 * @returns {Promise<void>} - 返回一个Promise，表示异步操作的完成状态
 */
const closeCurrentAlert = async () => {
  try {
    // 单行关闭时将当前行加入到接口保存要关闭的event_id的selectedRows数组中
    // 多行关闭时直接通过表格的selected属性获取选中行。
    selectedRows.value.push(currentRow.value)
    // 调用关闭告警接口
    // 参数：选中的告警ID列表和处理意见
    // await：阻塞代码执行，等待异步函数closeAlert执行完成
    await closeAlert(selectedEventIds.value, handleOpinion.value)
    // 从表格数据中移除已关闭的告警
    selectedEventIds.value.forEach(id => {
      // 查找匹配的告警在表格数据中的索引
      const index = tableData.value.findIndex((item) => String(item.event_id) === String(id))
      if (index !== -1) {
        // 如果找到匹配项，则从表格数据中移除
        tableData.value.splice(index, 1)
      }
    })
    // 清空选中行数组
    selectedRows.value = []
    // 清除表格的选中状态，这样即使旧数据重新被加载进来，也不会保持选择状态
    tableRef.value?.clearSelection()
    // 重置模态框状态，关闭确认对话框
    DialogVisibleClose.value = false
    // 重置处理意见
    handleOpinion.value = ''
    // 显示成功提示消息
    if (messageInstance.value) {
      // 先关闭所有可能存在的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));

    }
    // 显示成功提示
    messageInstance.value = ElMessage.success({
      message: '告警关闭成功', // 成功提示内容
      duration: 1000,  // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,  // 垂直偏移量，使消息垂直居中
      onClose: () => {   // 消息关闭时的回调
        messageInstance.value = null   // 清空消息实例引用
      }
    })
    // 错误处理部分
  } catch (error) {
    if (messageInstance.value) {
      // 如果已有提示框在显示，先关闭它
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.error({
      message: error.message,    // 错误信息内容
      duration: 1000,        // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,   // 垂直偏移量，使消息垂直居中
      onClose: () => {       // 消息关闭时的回调
        messageInstance.value = null    // 清空消息实例引用
      }
    })
  }
}
</script>

<template>
  <div class="item-page-container">
    <!--  全选/反选按钮-->
    <div style="display: flex; align-items: center;">
      <el-button type="primary" @click="handleSelectAll">全选</el-button>
      <el-button type="primary" @click="handleReverseSelection">反选</el-button>
    </div>
    <!-- 表格 -->
    <div class="table-container">
      <el-table
        ref="tableRef"
        :data="currentPageData"
        border
        stripe
        style="width: 100%; font-size: 14px;"
        :cell-style="{ textAlign: 'center' }"
        :header-cell-style="{ textAlign: 'center' }"
        row-key="event_id"
        @selection-change="handleSelectionChange"
        @sort-change="handleSortChange"
        v-loading="loading"
      >
        <el-table-column type="selection" reserve-selection min-width="2%" :resizable="false" />
        <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" min-width="4%" :resizable="false" />
        <el-table-column prop="event_id" label="事件ID" v-if="false" />
        <el-table-column prop="severity" label="级别" sortable="custom"  min-width="5%" :resizable="false">
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
        <el-table-column prop="category" label="分类" min-width="5%" :resizable="false">
          <template #default="{row}">
            {{ row.category || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="object" label="主机名" min-width="10%" show-overflow-tooltip :resizable="false">
          <template #default="{row}">
            {{ row.object || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP地址" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.ip || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="alarm_details" label="告警描述" show-overflow-tooltip min-width="25%" :resizable="false">
          <template #default="{row}">
            {{ row.alarm_details || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="12%" :resizable="false">
          <template #default="{row}">
            {{ row.occurrenceTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="processingTime" label="处理时间" min-width="12%" :resizable="false">
          <template #default="{row}">
            {{ row.processingTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="operation" label="操作" min-width="5%" :resizable="false">
          <template #default="scope">
            <div class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center; user-select: none;">
              <el-dropdown trigger="click">
                <el-button type="primary" :icon="Edit"></el-button>>
                <template #dropdown>
                  <el-dropdown-menu style="user-select: none">
                    <el-dropdown-item @click="handleView(scope.row)">查看</el-dropdown-item>
                    <el-dropdown-item @click="handleClose(scope.row)">关闭</el-dropdown-item>
                    <el-dropdown-item @click="handleCreateTicket(scope.row)">触发工单</el-dropdown-item>
                    <el-dropdown-item @click="handleForward(scope.row)">转发</el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </template>
        </el-table-column>
      </el-table>
      </div>
    <!-- 下方分页：显示总数、每页条数、页码导航 -->
    <div style="display: flex; justify-content: space-between; align-items: center;user-select:none;">
      <!--  显示总数  -->
      <div style="display: flex; align-items: center;">
        <span style="line-height: 20px">共 {{ tableData.length }} 条</span>
      </div>
      <div style="display: flex; align-items: center;">
        <!--  每页条数  -->
        <div style="display: flex; align-items: flex-start; margin-right: 10px; user-select: none">
          <el-select v-model="pageSize" style="width: 70px; margin: 0" @change="handleSizeChange">
            <el-option v-for="item in pageSizeOptions" :key="item" :label="item" :value="item" />
          </el-select>
          <span style="line-height: 32px;margin-left: 10px;">条/页</span>
        </div>
        <!--  页码导航  -->
        <div style="display: flex; align-items: center;">
          <el-pagination
            background
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
          <el-table-column prop="system_name" label="业务系统" min-width="80" :resizable="false">
            <template #default="{row}">
              {{ row.system_name || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="category" label="告警分类" min-width="50" :resizable="false">
            <template #default="{row}">
              {{ row.category || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="object" label="主机" min-width="50" :resizable="false">
            <template #default="{row}">
              {{ row.object || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="ip" label="IP地址" min-width="50" :resizable="false">
            <template #default="{row}">
              {{ row.ip || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="alarm_details" label="告警描述" min-width="150" :resizable="false">
            <template #default="{row}">
              {{ row.alarm_details || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="occurrenceTime" label="发生时间" min-width="80" :resizable="false">
            <template #default="{row}">
              {{ row.occurrenceTime || '/' }}
            </template>
          </el-table-column>
          <el-table-column prop="processingTime" label="处理时间" min-width="80" :resizable="false">
            <template #default="{row}">
              {{ row.processingTime || '/' }}
            </template>
          </el-table-column>
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
  flex-direction: column;
  box-sizing: border-box;
}

/* 表格容器样式：防止表格行多时溢出 */
.table-container {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  padding: 20px 0 20px 0;
}

/* 告警图形样式和闪烁动画 */
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
    transform: scale(1.4);
    filter: brightness(1);
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
  font-size: 12px;
  color: black !important;
}

/* 设置每页条数选项文本居中 */
:deep(.el-select-dropdown__item) {
  text-align: center;
}

/* 设置每页条数选项文本居中 */
:deep(.el-select__wrapper) {
  text-align: center;
}

</style>
