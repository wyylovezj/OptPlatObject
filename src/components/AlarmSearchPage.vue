<script setup>
import { ref } from 'vue'

const searchData = ref({
  category: '',
  severity: '',
  ip: '',
  object: '',
  system_name: '',
  occurrenceTime: [],
  timeSelect: '',
  state:'',
  source: ''
})
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
  searchData.value.ip = cleanIp.replace(/^\./g, '')
}
// 主机名输入处理函数
const handleHostInput = (value) => {
  // 只允许输入英文字母和数字
  searchData.value.object = value.replace(/[^a-zA-Z0-9]/g, '')
}



// 发生时间的选择器和日期选择器处理
const handleTimeSelect = (value) => {
  if (!value) {
    searchData.value.occurrenceTime = []
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
    searchData.value.occurrenceTime = [formatDate(startOfDay), formatDate(endOfDay)]
  } else if (value === '昨天') {
    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)
    const startOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 0, 0, 0)
    const endOfYesterday = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 23, 59, 59)
    searchData.value.occurrenceTime = [formatDate(startOfYesterday), formatDate(endOfYesterday)]
  }
}

// 监听日期变化，清空选择器
const handleDateChange = () => {
  // 当日期被手动修改时，清空时间选择器的值
  if (searchData.value.timeSelect) {
    searchData.value.timeSelect = ''
  }
}

</script>

<template>
  <div style="margin-bottom: 10px;margin-top: 10px;user-select: none">
    <el-form :inline="true" :model="searchData" class="demo-form-inline">
      <el-form-item label="告警分类：">
        <el-select v-model="searchData.category" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in categoryOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="告警级别：">
        <el-select v-model="searchData.severity" clearable placeholder="请选择" style="width: 150px">
          <el-option v-for="item in severityOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="IP地址：">
        <el-input
          v-model="searchData.ip"
          style="width: 150px"
          placeholder="IP 地址"
          maxlength="15"
          type="text"
          @input="handleIpInput"
          class="center-placeholder"
        />
      </el-form-item>
      <el-form-item label="主机名：">
        <el-input
          v-model="searchData.object"
          style="width: 150px"
          placeholder="主机名"
          maxlength="15"
          type="text"
          @input="handleHostInput"
          class="center-placeholder"
        />
      </el-form-item>
      <el-form-item label="业务系统：">
        <el-select v-model="searchData.system_name" clearable placeholder="请选择" style="width: 200px">
          <el-option v-for="item in system_nameOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发生时间：">
        <el-select v-model="searchData.timeSelect" clearable placeholder="请选择" style="width: 100px" @change="handleTimeSelect" @clear="() => searchData.occurrenceTime = []">
          <el-option v-for="item in occurrenceTimeOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
        <el-date-picker
          v-model="searchData.occurrenceTime"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD HH:mm:ss"
          @change="handleDateChange"
        />
      </el-form-item>
      <el-form-item label="告警状态：">
        <el-select v-model="searchData.state" clearable placeholder="请选择" style="width: 100px">
          <el-option v-for="item in stateOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
      </el-form-item>
      <el-form-item label="告警来源：">
        <el-select v-model="searchData.source" clearable placeholder="请选择" style="width: 100px">
          <el-option v-for="item in sourceOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
      </el-form-item>
      <el-form-item style="margin-left: 50px">
        <el-button
          type="primary"
          class="login-btn"
          @click="clearSearchData"
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
          @click="SearchData"
        >
          搜索
        </el-button>
      </el-form-item>
      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          @click="batchCloseAlarm"
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
