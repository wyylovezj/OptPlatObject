<script setup>
import { ref } from 'vue'
import { selectedRows, DialogVisibleClose, refresh, searchQuery, dataDictionary } from '@/utils/publicData.js'
import { getAlarmDictionary } from '@/api/interface.js'
import { ElMessage } from 'element-plus'


const severityOptions = [
  {
    value: 4,
    label: '普通',
    color: '#6cbc45',
  },
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
    color: '#FF0000',
  },
]



const stateOptions = [
  {
    value: '未处理',
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
    // 重置表单验证和字段值
    formSearch.value.resetFields()
    // 重置数据模型值
    searchQuery.value = {
      category: '',      // 告警分类
      severity: '',      // 告警级别
      ip: '',            // IP地址
      object: '',        // 主机名
      system_name: '',   // 业务系统
      occurrenceTime: [], // 发生时间
      state:'',         // 告警状态
      source: ''         // 告警来源
    }
    // 重置数据字典值
    dataDictionary.value.category= []
    dataDictionary.value.system_name= []
  }
}

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
        <el-select v-model="searchQuery.category" clearable placeholder="请选择" style="width: 150px" @visible-change="(visible) => getAlarmDictionary(visible, '告警分类')" @clear="searchQuery.category = '';dataDictionary.category = []">
          <el-option v-for="(item, index) in dataDictionary.category" :key="index" :label="Object.values(item)[0]" :value="Object.keys(item)[0]" />
        </el-select>
      </el-form-item>
      <el-form-item label="告警级别：" prop="severity">
        <el-select v-model="searchQuery.severity" clearable placeholder="请选择" style="width: 150px" @clear="searchQuery.severity = ''">
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
        <el-select v-model="searchQuery.system_name" clearable placeholder="请选择" style="width: 200px"  @visible-change="(visible) => getAlarmDictionary(visible, '系统名称')" @clear="searchQuery.system_name = '';dataDictionary.system_name = []">
          <el-option v-for="(item,index) in dataDictionary.system_name" :key="index" :value="item" />
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
          @clear="searchQuery.occurrenceTime = []"
        />
      </el-form-item>
      <el-form-item label="告警状态：" prop="state">
        <el-select v-model="searchQuery.state" clearable placeholder="请选择" style="width: 150px" @clear="searchQuery.state = ''">
          <el-option v-for="item in stateOptions" :key="item.value" :label="item.label" :value="item.value"/>
        </el-select>
      </el-form-item>
      <el-form-item label="告警来源："  prop="source">
        <el-select v-model="searchQuery.source" clearable placeholder="请选择" style="width: 150px" @clear="searchQuery.source = ''">
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
/* 下拉框文本居中 */
:deep(.el-select-dropdown__item) {
  text-align: center;
}

:deep(.el-select__wrapper) {
  text-align: center;
}
</style>
