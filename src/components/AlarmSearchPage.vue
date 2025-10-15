<script setup>
import { ref } from 'vue'
import { searchData } from '@/api/interface.js'
import { loading, currentPage, Query, selectedRows, DialogVisibleClose } from '@/utils/tools.js'
import { ElMessage } from 'element-plus'

// 表单查询数据模型
const searchQuery = ref(Query)
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
  },
  {
    value: 2,
    label: '重要',
  },
  {
    value: 1,
    label: '严重',
  },
]
const system_nameOptions = [

]
const occurrenceTimeOptions = [
  {
    value: '今天',
  },
  {
    value: '昨天',
  },
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



// 发生时间的选择器和日期选择器处理
const handleTimeSelect = (value) => {
  if (!value) {
    searchQuery.value.occurrenceTime = []
    return
  }

  const today = new Date()
  const formatDate = (date) => {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
  }

  if (value === '今天') {
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0)
    const endOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59)
    searchQuery.value.occurrenceTime = [formatDate(startOfDay), formatDate(endOfDay)]
  } else if (value === '昨天') {
    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)
    const startOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 0, 0, 0)
    const endOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 23, 59, 59)
    searchQuery.value.occurrenceTime = [formatDate(startOfYesterday), formatDate(endOfYesterday)]
  }
}

// 监听日期变化，清空选择器
const handleDateChange = () => {
  // 当日期被手动修改时，清空时间选择器的值
  if (searchQuery.value.timeSelect) {
    searchQuery.value.timeSelect = ''
  }
}

// 重置按钮清空搜索数据
const formSearch = ref(null)

const clearSearch = () => {
  if (formSearch.value) {
    formSearch.value.resetFields()
    handleDateChange()
  }
}
// 刷新按钮查询数据
const refresh = async () => {
  loading.value = true
  try {
    clearSearch()
    await searchData(searchQuery.value)
    currentPage.value = 1
  } finally {
    setTimeout(() => {
      loading.value = false
    }, 1000)
  }
}
// 搜索按钮查询数据
const search = async () => {
  loading.value = true
  try {
    await searchData(searchQuery.value)
    currentPage.value = 1
  } finally {
    setTimeout(() => {
      loading.value = false
    }, 1000)
  }
}
// 批量关闭功能
const batchClose = () => {
  if (selectedRows.value.length === 0) {
    ElMessage.warning('请先选择要关闭的数据')
    return
  }
  DialogVisibleClose.value = true
}

</script>

<template>
  <div style="margin-bottom: 10px;margin-top: 10px;user-select: none">
    <el-form ref="formSearch" :inline="true" :model="searchQuery" class="demo-form-inline">
      <el-form-item label="告警分类：" prop="category">
        <el-select v-model="searchQuery.category" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in categoryOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="告警级别：" prop="severity">
        <el-select v-model="searchQuery.severity" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in severityOptions" :key="item.value" :label="item.label" :value="item.value" />
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
        <el-select v-model="searchQuery.timeSelect" clearable placeholder="请选择" style="width: 100px" @change="handleTimeSelect" @clear="() => searchQuery.occurrenceTime = []">
          <el-option v-for="item in occurrenceTimeOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
        <el-date-picker
          v-model="searchQuery.occurrenceTime"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD HH:mm:ss"
          @change="handleDateChange"
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
      <el-form-item style="margin-left: 50px">
        <el-button
          type="primary"
          class="login-btn"
          @click="clearSearch"
        >
          重置
        </el-button>
      </el-form-item>
      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          @click="refresh"
        >
          刷新
        </el-button>
      </el-form-item>
      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          @click="search"
        >
          搜索
        </el-button>
      </el-form-item>
      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          @click="batchClose"
        >
          批量关闭
        </el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<style scoped>
/*输入框内容居中显示*/
.center-placeholder :deep(.el-input__inner) {
  text-align: center;
}
.center-placeholder :deep(.el-input__inner)::placeholder {
  text-align: center;
}
</style>
