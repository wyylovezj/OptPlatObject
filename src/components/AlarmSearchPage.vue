<script setup>
import { nextTick, ref } from 'vue'
import { searchData } from '@/api/interface.js'
import { tableRef,loading, currentPage, Query, selectedRows, DialogVisibleClose, tableData, throttle ,blinkTrigger, sortSeverity } from '@/utils/publicData.js'
import { ElMessage } from 'element-plus'

// 表单查询数据模型
const searchQuery = ref(JSON.parse(JSON.stringify(Query)))
// 告警分类选择器
const categoryOptions = [
  {
    value: '操作系统',
  },
  {
    value: '中间件',
  },
]
const severityOptions = [
  {
    value: 3,
    label: '一般',
    color: '#ffd100',
  },
  {
    value: 2,
    label: '重要',
    color: '#fa8c16',
  },
  {
    value: 1,
    label: '严重',
    color: '#ff4d4f',
  },
]

const system_nameOptions = [

]

const stateOptions = [
  {
    value: '未处理',
  },
  {
    value: '已处理',
  },
  {
    value: '已分派',
  },
  {
    value: '已关闭',
  },
]
const sourceOptions = [
  {
    value: '云上告警',
  },
  {
    value: '云下告警',
  },
]
// IP地址输入处理函数
const handleIpInput = (value) => {
  // 只允许输入数字和点
  const ipValue = value.replace(/[^\d.]/g, '')
  // 确保不会出现连续的点
  const cleanIp = ipValue.replace(/\.+/g, '.')
  // 确保不会以点开头
  searchQuery.value.ip = cleanIp.replace(/^\./g, '')
}
// 主机名输入处理函数
const handleHostInput = (value) => {
  // 只允许输入英文字母和数字
  searchQuery.value.object = value.replace(/[^a-zA-Z0-9]/g, '')
}

// 日期选择器快捷选项
const shortcuts = [
  {
    text: '今天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime())
      return [start, end]
    },
  },
  {
    text: '昨天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24)
      end.setTime(end.getTime() - 3600 * 1000 * 24)
      return [start, end]
    },
  },
  {
    text: '7 天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24 * 6)
      return [start, end]
    },
  },
  {
    text: '30 天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24 * 29)
      return [start, end]
    },
  },
  {
    text: '90 天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24 * 89)
      return [start, end]
    },
  },
  {
    text: '180 天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24 * 179)
      return [start, end]
    },
  },
  {
    text: '365 天',
    value: () => {
      const end = new Date()
      const start = new Date()
      start.setTime(start.getTime() - 3600 * 1000 * 24 * 364)
      return [start, end]
    },
  },
]

// 重置按钮清空搜索数据
const formSearch = ref(null)

const clearSearch = () => {
  if (formSearch.value) {
    formSearch.value.resetFields()
  }
}
// 搜索按钮、刷新按钮查询数据,增加了节流控制
const refresh = throttle(async () => {
  // 设置加载标志为true,控制表格加载动画
  loading.value = true
  // 关闭告警图形动画
  blinkTrigger.value = false
  // 为防止刷新数据过程太快导致加载动画不显示，设置一个最小延迟promise，确保异步过程至少是300 ms
  const minDelay = new Promise(resolve => setTimeout(resolve, 300))
  try {
    // 将Promise数组中第一个promise执行结果复制给data
    const [data] = await Promise.all([
      searchData(searchQuery.value),
      minDelay
    ])
    // 对获取的数据进行排序后再赋值给tableData
    tableData.value = data.sort(sortSeverity)
    // 重置表格组件中级别列的排序图标为默认状态
    if (tableRef.value) {
      tableRef.value.clearSort()
    }
    // 重新开启动画，确保动画开始时间相同，频率一致
    blinkTrigger.value = true
    currentPage.value = 1
  }
  finally {
    loading.value = false
  }
}, 300)

// 批量关闭功能
// 存储当前显示的提示框实例
let messageInstance = null
const batchClose = async () => {
  if (selectedRows.value.length === 0) {
    // 如果已有提示框在显示，先关闭它
    if (messageInstance) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 使用setTimeout给DOM更新留出时间
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance = ElMessage.warning({
      message: '请先选择要关闭的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance = null
      }
    })
    return
  }
  DialogVisibleClose.value = true
}
</script>

<template>
  <div class="search-page-container">
    <el-form ref="formSearch" :inline="true" :model="searchQuery" style=" display: flex;align-items: center;  flex-wrap: wrap;width: 100%;">
      <el-form-item label="告警分类：" prop="category">
        <el-select v-model="searchQuery.category" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in categoryOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="告警级别：" prop="severity">
        <el-select v-model="searchQuery.severity" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in severityOptions" :key="item.value" :label="item.label" :value="item.value">
            <div class="flex items-center">
              <el-tag :color="item.color" style="margin-right: 8px" size="small" />
              <span :style="{ color: item.color }">{{ item.label }}</span>
            </div>
          </el-option>
        </el-select>
      </el-form-item>
      <el-form-item label="IP地址：" prop="ip">
        <el-input
          v-model="searchQuery.ip"
          style="width: 150px"
          placeholder="IP 地址"
          maxlength="15"
          type="text"
          @input="handleIpInput"
          class="center-placeholder"
        />
      </el-form-item>
      <el-form-item label="主机名：" prop="object">
        <el-input
          v-model="searchQuery.object"
          style="width: 150px"
          placeholder="主机名"
          maxlength="15"
          type="text"
          @input="handleHostInput"
          class="center-placeholder"
        />
      </el-form-item>
      <el-form-item label="业务系统：" prop="system_name">
        <el-select v-model="searchQuery.system_name" clearable placeholder="请选择" style="width: 200px">
          <el-option v-for="item in system_nameOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发生时间：" prop="occurrenceTime">
        <el-date-picker
          v-model="searchQuery.occurrenceTime"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD HH:mm:ss"
          :shortcuts="shortcuts"
          unlink-panels
        />
      </el-form-item>
      <el-form-item label="告警状态：" prop="state">
        <el-select v-model="searchQuery.state" clearable placeholder="请选择" style="width: 100px">
          <el-option v-for="item in stateOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
      </el-form-item>
      <el-form-item label="告警来源："  prop="source">
        <el-select v-model="searchQuery.source" clearable placeholder="请选择" style="width: 100px">
          <el-option v-for="item in sourceOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
      </el-form-item>
      <el-form-item style="flex: none;margin-left: auto;margin-right: 5px;">
        <div style="display: flex;justify-content: flex-end;gap: 10px;flex-wrap: nowrap;">
          <el-button type="primary" @click="clearSearch">重置</el-button>
          <el-button type="primary" @click="refresh">刷新</el-button>
          <el-button type="primary" @click="refresh">搜索</el-button>
          <el-button type="primary" @click="batchClose">批量关闭</el-button>
        </div>
      </el-form-item>
    </el-form>
  </div>
</template>

<style scoped>
/* 查询界面容器样式 */
.search-page-container {
  padding-bottom: 20px;
  user-select: none;
  height: 15%;
  flex-shrink: 0;
  box-sizing: border-box;
  min-width: fit-content;
  min-height: fit-content;
}
/*输入框内容居中显示*/
.center-placeholder :deep(.el-input__inner) {
  text-align: center;
}
.center-placeholder :deep(.el-input__inner)::placeholder {
  text-align: center;
}
.el-tag {
  border: none;
  aspect-ratio: 1;
  width: 16px;
  height: 16px;
  padding: 0;
  border-radius: 50%;
  display: inline-block;
  margin-right: 8px;
}
</style>
