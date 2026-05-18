<script setup>
import { usePermissionStore } from '@/stores/permissionStore.js'
import { WorkOrderDataModel } from '@/utils/publicDataTools.js'

/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：告警页面搜索栏组件
 * @date： 2026-01-28 09:29:55
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:29:55
 */
import { ref, watch, onUnmounted, nextTick, computed, onMounted } from 'vue'
import { selectedRows, DialogVisibleClose, refresh, searchQuery, dataDictionary, isFilter, tableData } from '@/utils/publicData.js'
import { getAlarmDictionary } from '@/api/interface.js'
import { getAlertStatisticData } from '@/api/homePage.js'
import { ElMessage } from 'element-plus'
import * as XLSX from 'xlsx'
import { alarmMonitoringData } from '@/utils/homePageData.js'

// 权限状态管理
const permissionStore = usePermissionStore()
const defaultTime = ref([new Date(2000, 1, 1, 0, 0, 0), new Date(2000, 2, 1, 23, 59, 59)])

// 刷新四张卡片的数据
const refreshCardData = async () => {
  try {
    const response = await getAlertStatisticData()
    if (response.status === 'success') {
      alarmMonitoringData.value.unprocessed.totalCount = response.unprocessed.totalCount
      alarmMonitoringData.value.unprocessed.critical = response.unprocessed.critical
      alarmMonitoringData.value.unprocessed.assigned = response.unprocessed.assigned
      alarmMonitoringData.value.added.today = response.added.today
      alarmMonitoringData.value.added.yesterday = response.added.yesterday
      alarmMonitoringData.value.added.week = response.added.week
      alarmMonitoringData.value.added.month = response.added.month
      alarmMonitoringData.value.serious.count = response.serious.count
      alarmMonitoringData.value.serious.recently = response.serious.recently
      alarmMonitoringData.value.serious.furthest = response.serious.furthest
      alarmMonitoringData.value.serious.totalCritical = response.serious.totalCritical
      alarmMonitoringData.value.completed.count = response.completed.count
      alarmMonitoringData.value.completed.average = response.completed.average
      alarmMonitoringData.value.completed.fastest = response.completed.fastest
      alarmMonitoringData.value.completed.slowest = response.completed.slowest
    }
  } catch (error) {
    console.error('刷新卡片数据失败:', error)
  }
}

// 监听refresh函数，当表格数据刷新时同步刷新卡片数据
watch(
  tableData,
  () => {
    refreshCardData()
  },
  { deep: true },
)

// 计算统计数据
const statistics = computed(() => {
  const criticalCount = alarmMonitoringData.value.serious.count // 使用首页严重告警数据
  const totalCritical = alarmMonitoringData.value.serious.totalCritical  // 今日新增严重告警
  const majorCount = tableData.value.filter((row) => row.severity === '重要' && row.state !== '已关闭').length
  const pendingCount = alarmMonitoringData.value.unprocessed.totalCount // 使用首页待处理告警数据
  const todayAdded = alarmMonitoringData.value.added.today // 使用首页今日新增告警数据
  const todayCompleted = alarmMonitoringData.value.completed.count // 使用首页已处理告警数据
  const totalCount = tableData.value.length

  return {
    critical: criticalCount,
    major: majorCount,
    pending: pendingCount,
    todayAdded: todayAdded,
    todayCompleted: todayCompleted,
    totalCritical: totalCritical,
    total: totalCount,
  }
})
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
    value: '已挂起',
  },
  {
    value: '已关闭',
  },
]

// const sourceOptions = [
//   {
//     value: '云上告警',
//   },
//   {
//     value: '云下告警',
//   },
// ]

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
// 监听搜索数据模型变化：触发搜索框全选权限功能
watch(
  searchQuery,
  (val) => {
    if (val.category.length === 0) {
      checkAllCategory.value = false
      indeterminateCategory.value = false
    } else if (val.category.length === dataDictionary.value.category.length) {
      checkAllCategory.value = true
      indeterminateCategory.value = false
    } else if (val.category.length > 0) {
      indeterminateCategory.value = true
    }
    if (val.system_name.length === 0) {
      checkAllSystem.value = false
      indeterminateSystem.value = false
    } else if (val.system_name.length === dataDictionary.value.system_name.length) {
      checkAllSystem.value = true
      indeterminateSystem.value = false
    } else if (val.system_name.length > 0) {
      indeterminateSystem.value = true
    }
  },
  { deep: true },
)
// 告警分类全选按钮标志
const checkAllCategory = ref(false)
const indeterminateCategory = ref(false)
// 告警分类搜索关键词
const searchKeywordCategory = ref('')

// 告警分类过滤后的选项列表
const filteredOptionsCategory = ref([])
// 告警分类初始化过滤选项
const initFilteredOptionsCategory = () => {
  if (searchKeywordCategory.value) {
    // 如果搜索关键词不为空，根据关键词过滤选项
    filteredOptionsCategory.value = dataDictionary.value.category.filter((item) =>
      Object.values(item)[0].toLowerCase().includes(searchKeywordCategory.value),
    )
  } else {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsCategory.value = [...dataDictionary.value.category]
  }
}

// 告警分类过滤选项函数
const filterOptionsCategory = () => {
  if (!searchKeywordCategory.value) {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsCategory.value = [...dataDictionary.value.category]
  } else {
    // 根据关键词过滤选项
    filteredOptionsCategory.value = dataDictionary.value.category.filter((item) =>
      Object.values(item)[0].toLowerCase().includes(searchKeywordCategory.value),
    )
  }
}
// 告警分类监听下拉框显示状态，初始化过滤选项
watch((visible) => {
  if (visible) {
    initFilteredOptionsCategory()
  }
})
// 告警分类全选按钮
const handleCheckAllCategory = (val) => {
  indeterminateCategory.value = false
  if (val) {
    searchQuery.value.category = filteredOptionsCategory.value.map((item) => Object.keys(item)[0])
  } else {
    searchQuery.value.category = []
  }
}
// 业务系统按钮标志
const checkAllSystem = ref(false)
const indeterminateSystem = ref(false)

// 业务系统搜索关键词
const searchKeywordSystemName = ref('')

// 业务系统过滤后的选项列表
const filteredOptionsSystemName = ref([])
// 业务系统初始化过滤选项
const initFilteredOptionsSystemName = () => {
  if (searchKeywordSystemName.value) {
    // 如果搜索关键词不为空，根据关键词过滤选项
    filteredOptionsSystemName.value = dataDictionary.value.system_name.filter((item) => item.includes(searchKeywordSystemName.value))
  } else {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsSystemName.value = [...dataDictionary.value.system_name]
  }
}

// 业务系统过滤选项函数
const filterOptionsSystemName = () => {
  if (!searchKeywordSystemName.value) {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsSystemName.value = [...dataDictionary.value.system_name]
  } else {
    // 根据关键词过滤选项
    filteredOptionsSystemName.value = dataDictionary.value.system_name.filter((item) => item.includes(searchKeywordSystemName.value))
  }
}
// 业务系统监听下拉框显示状态，初始化过滤选项
watch((visible) => {
  if (visible) {
    initFilteredOptionsSystemName()
  }
})
// 业务系统全选逻辑
const handleCheckAllSystem = (val) => {
  indeterminateSystem.value = false
  if (val) {
    searchQuery.value.system_name = [...filteredOptionsSystemName.value]
  } else {
    searchQuery.value.system_name = []
  }
}
// 重置按钮清空搜索数据
const formSearch = ref(null)

const clearSearch = () => {
  if (formSearch.value) {
    // 重置表单验证和字段值
    formSearch.value.resetFields()
    // 重置数据模型值
    searchQuery.value = {
      category: [], // 告警分类
      severity: '', // 告警级别
      ip: '', // IP地址
      object: '', // 主机名
      system_name: [], // 业务系统
      occurrenceTime: [], // 发生时间
      processingTime: [], // 处理时间
      state: '', // 告警状态
      // source: '', // 告警来源
    }
    // 重置数据字典值
    dataDictionary.value.category = []
    dataDictionary.value.system_name = []
    indeterminateCategory.value = false
    indeterminateSystem.value = false
    checkAllCategory.value = false
    checkAllSystem.value = false
  }
}

// 批量关闭功能
// 存储当前显示的提示框实例
const messageInstance = ref(null)
const batchClose = async () => {
  console.log('start', new Date().getTime())
  // 如果已有提示框在显示，先关闭它
  if (messageInstance.value) {
    // 关闭所有消息
    ElMessage.closeAll()
    // 使用setTimeout给DOM更新留出时间
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
  // 检查选中的节点中是否有状态为"已关闭"的告警
  const closedRows = selectedRows.value.filter((row) => row.state === '已关闭')
  if (closedRows.length > 0) {
    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `选中的 ${closedRows.length} 条告警状态为"已关闭"，不允许再次关闭`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  if (selectedRows.value.length === 0) {
    messageInstance.value = ElMessage.warning({
      message: '请先选择要关闭的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  console.log('endtime', new Date().getTime())
  DialogVisibleClose.value = true
  // 等待模态框关闭动画完成
  await nextTick()
}
// 批量挂起功能
const batchSuspend = async () => {
  console.log('start', new Date().getTime())
  // 如果已有提示框在显示，先关闭它
  if (messageInstance.value) {
    // 关闭所有消息
    ElMessage.closeAll()
    // 使用setTimeout给DOM更新留出时间
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
  // 检查选中的节点中是否有状态为"已关闭"的告警
  const closedRows = selectedRows.value.filter((row) => row.state === '已关闭')
  if (closedRows.length > 0) {
    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `选中的 ${closedRows.length} 条告警状态为"已关闭"，不允许挂起`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  if (selectedRows.value.length === 0) {
    messageInstance.value = ElMessage.warning({
      message: '请先选择要挂起的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  console.log('endtime', new Date().getTime())
}
// 批量分派工单功能
const batchCreateTickets = async () => {
  // 检查选中的节点中是否有状态为"已分派"的告警
  const closedRows = selectedRows.value.filter((row) => row.state === '已分派')
  if (closedRows.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `选中的 ${closedRows.length} 条告警状态为"已分派"，不允许再次分派工单`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  if (selectedRows.value.length === 0) {
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 使用setTimeout给DOM更新留出时间
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.warning({
      message: '请先选择要分派的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  console.log('batchCreateTickets')
}

const exportAlarmData = async () => {
  try {
    let exportData = []

    if (selectedRows.value.length > 0) {
      exportData = selectedRows.value
    } else {
      exportData = tableData.value
    }

    if (exportData.length === 0) {
      if (messageInstance.value) {
        ElMessage.closeAll()
        await new Promise((resolve) => setTimeout(resolve, 0))
      }
      messageInstance.value = ElMessage.warning({
        message: '没有可导出的数据',
        duration: 1000,
        offset: window.innerHeight / 2 - 20,
        onClose: () => {
          messageInstance.value = null
        },
      })
      return
    }

    const excelData = exportData.map((row) => ({
      事件ID: row.event_id || '',
      告警级别: row.severity || '',
      告警状态: row.state || '',
      业务系统: row.system_name || '',
      告警分类: row.category || '',
      主机名: row.object || '',
      IP地址: row.ip || '',
      告警描述: row.alarm_details || '',
      发生时间: row.occurrenceTime || '',
      处理时间: row.processingTime || '',
      告警来源: row.source || '',
      处理意见: row.alart_remarks || '',
      处理人: row.Alarm_Handler || '',
    }))

    const worksheet = XLSX.utils.json_to_sheet(excelData)
    const workbook = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(workbook, worksheet, '告警数据')

    const now = new Date()
    const dateStr = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}${String(now.getSeconds()).padStart(2, '0')}`
    const fileName = `告警数据_${dateStr}.xlsx`

    XLSX.writeFile(workbook, fileName)

    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.success({
      message: `成功导出 ${exportData.length} 条告警数据`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
  } catch (error) {
    console.error('导出失败:', error)
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.error({
      message: '导出失败，请稍后重试',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
}
onUnmounted(() => {
  clearSearch()
})

// 组件挂载时初次加载卡片数据
onMounted(() => {
  refreshCardData()
})
</script>

<template>
  <div class="search-page-container">
    <!-- 统计卡片 -->
    <div class="stats-bar">
      <div class="stat-card">
        <div class="stat-icon critical">
          <svg class="icon-svg lg" viewBox="0 0 24 24">
            <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
            <line x1="12" y1="9" x2="12" y2="13" />
            <line x1="12" y1="17" x2="12.01" y2="17" />
          </svg>
        </div>
        <div class="stat-info">
          <div class="stat-label">严重告警</div>
          <div class="stat-value critical">{{ statistics.critical }}</div>
        </div>
        <el-tag class="stat-today-added" type="warning" effect="light" round>
          今日新增: {{ statistics.totalCritical }}
        </el-tag>
      </div>
      <div class="stat-card">
        <div class="stat-icon pending">
          <svg class="icon-svg lg" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" />
            <polyline points="12 6 12 12 16 14" />
          </svg>
        </div>
        <div class="stat-info">
          <div class="stat-label">待处理</div>
          <div class="stat-value pending">{{ statistics.pending }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon major">
          <svg class="icon-svg lg" viewBox="0 0 24 24">
            <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" />
            <path d="M13.73 21a2 2 0 01-3.46 0" />
          </svg>
        </div>
        <div class="stat-info">
          <div class="stat-label">今日新增</div>
          <div class="stat-value major">{{ statistics.todayAdded }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon total">
          <svg class="icon-svg lg" viewBox="0 0 24 24">
            <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
            <polyline points="22 4 12 14.01 9 11.01" />
          </svg>
        </div>
        <div class="stat-info">
          <div class="stat-label">今日已处理</div>
          <div class="stat-value total">{{ statistics.todayCompleted }}</div>
        </div>
      </div>
    </div>

    <!-- 搜索表单 - 卡片式布局 -->
    <div class="filter-bar">
      <el-form ref="formSearch" :inline="true" :model="searchQuery" class="filter-form">
        <el-form-item prop="category" class="filter-item">
          <el-select
            v-model="searchQuery.category"
            multiple
            collapse-tags
            collapse-tags-tooltip
            default-first-option
            fit-input-width
            :class="{ centerPlaceholder: searchQuery.category.length === 0 }"
            clearable
            placeholder="告警分类"
            style="width: 130px"
            @visible-change="
              (visible) => {
                getAlarmDictionary(visible, '告警分类')
              }
            "
            @clear="
              () => {
                checkAllCategory = false
                searchQuery.category = []
                dataDictionary.category = []
              }
            "
          >
            <template #header>
              <!-- 自定义搜索输入框 -->
              <el-input v-model="searchKeywordCategory" placeholder="搜索选项" @input="filterOptionsCategory" clearable spellcheck="false" />
              <el-checkbox v-model="checkAllCategory" :indeterminate="indeterminateCategory" @change="handleCheckAllCategory"> 全选 </el-checkbox>
            </template>
            <el-option v-for="(item, index) in filteredOptionsCategory" :key="index" :label="Object.values(item)[0]" :value="Object.keys(item)[0]" />
          </el-select>
        </el-form-item>

        <el-form-item prop="severity" class="filter-item">
          <el-select v-model="searchQuery.severity" clearable placeholder="告警级别" style="width: 110px" @clear="searchQuery.severity = ''">
            <el-option v-for="item in severityOptions" :key="item.value" :label="item.label" :value="item.value">
              <div class="flex items-center">
                <el-tag :color="item.color" style="margin-right: 8px" size="small" />
                <span :style="{ color: item.color }">{{ item.label }}</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>

        <el-form-item prop="ip" class="filter-item">
          <el-input
            v-model="searchQuery.ip"
            style="width: 110px"
            placeholder="IP地址"
            maxlength="15"
            type="text"
            @input="handleIpInput"
            class="center-placeholder"
            clearable
            spellcheck="false"
          />
        </el-form-item>

        <el-form-item prop="object" class="filter-item">
          <el-input
            v-model="searchQuery.object"
            style="width: 110px"
            placeholder="主机名"
            maxlength="15"
            type="text"
            @input="handleHostInput"
            class="center-placeholder"
            clearable
            spellcheck="false"
          />
        </el-form-item>

        <el-form-item prop="system_name" class="filter-item">
          <el-select
            v-model="searchQuery.system_name"
            multiple
            collapse-tags
            collapse-tags-tooltip
            default-first-option
            fit-input-width
            :class="{ centerPlaceholder: searchQuery.system_name.length === 0 }"
            clearable
            placeholder="业务系统"
            style="width: 130px"
            @visible-change="
              (visible) => {
                getAlarmDictionary(visible, '系统名称')
              }
            "
            @clear="
              () => {
                checkAllSystem = false
                searchQuery.system_name = []
                dataDictionary.system_name = []
              }
            "
          >
            <template #header>
              <!-- 自定义搜索输入框 -->
              <el-input v-model="searchKeywordSystemName" placeholder="搜索选项" @input="filterOptionsSystemName" clearable spellcheck="false" />
              <el-checkbox v-model="checkAllSystem" :indeterminate="indeterminateSystem" @change="handleCheckAllSystem"> 全选 </el-checkbox>
            </template>
            <el-option v-for="(item, index) in filteredOptionsSystemName" :key="index" :value="item" />
          </el-select>
        </el-form-item>

        <el-form-item prop="state" class="filter-item">
          <el-select v-model="searchQuery.state" clearable placeholder="告警状态" style="width: 110px" @clear="searchQuery.state = ''">
            <el-option v-for="item in stateOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <el-form-item prop="occurrenceTime" class="filter-item filter-date-range">
          <el-date-picker
            v-model="searchQuery.occurrenceTime"
            type="daterange"
            start-placeholder="发生日期(开始)"
            end-placeholder="发生日期(结束)"
            value-format="YYYY-MM-DD HH:mm:ss"
            :shortcuts="shortcuts"
            unlink-panels
            @clear="
              () => {
                searchQuery.occurrenceTime = []
              }
            "
            :default-time="defaultTime"
            style="width: 240px"
          />
        </el-form-item>

        <el-form-item prop="processingTime" class="filter-item filter-date-range">
          <el-date-picker
            v-model="searchQuery.processingTime"
            type="daterange"
            start-placeholder="处理日期(开始)"
            end-placeholder="处理日期(结束)"
            value-format="YYYY-MM-DD HH:mm:ss"
            :shortcuts="shortcuts"
            unlink-panels
            @clear="
              () => {
                searchQuery.processingTime = []
              }
            "
            :default-time="defaultTime"
            style="width: 240px"
          />
        </el-form-item>

        <!-- 分隔线 -->
        <span class="filter-sep"></span>

        <!-- 按钮组 -->
        <div class="filter-actions">
          <el-button v-if="permissionStore.hasPermission('alarm:reset')" type="info" plain @click="clearSearch" class="reset-btn">
            <svg class="icon-svg sm" viewBox="0 0 24 24">
              <polyline points="1 4 1 10 7 10" />
              <path d="M3.51 15a9 9 0 102.13-9.36L1 10" />
            </svg>
            &nbsp;重置
          </el-button>
          <el-button v-if="permissionStore.hasPermission('alarm:search')" type="primary" @click="refresh" class="search-btn">
            <svg class="icon-svg sm" viewBox="0 0 24 24">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            &nbsp;查询
          </el-button>
        </div>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
/* 查询界面容器样式 */
.search-page-container {
  flex: 1;
  padding: 0 0 12px 0;
  user-select: none;
  flex-shrink: 0;
  box-sizing: border-box;
  min-width: fit-content;
}

/* 统计卡片样式 */
.stats-bar {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  background: var(--bg-card, #ffffff);
  border-radius: 12px;
  padding: 20px 24px;
  border: 1px solid #e2e8f0;
  display: flex;
  align-items: center;
  gap: 16px;
  transition: box-shadow 0.2s;
  position: relative;
}

.stat-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  border-color: transparent;
}

.stat-icon {
  width: 52px;
  height: 52px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-icon.critical {
  background: #fef2f2;
  color: #dc2626;
}

.stat-icon.major {
  background: #fff7ed;
  color: #ea580c;
}

.stat-icon.pending {
  background: #eff6ff;
  color: #2563eb;
}

.stat-icon.total {
  background: #f0fdf4;
  color: #16a34a;
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 13px;
  color: #64748b;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

.stat-value.critical {
  color: #dc2626;
}

.stat-value.major {
  color: #ea580c;
}

.stat-value.pending {
  color: #2563eb;
}

.stat-value.total {
  color: #16a34a;
}

/* 今日新增标签样式 - 显示在卡片右上角 */
.stat-today-added {
  position: absolute;
  top: 20px;
  right: 2ch;
  font-size: 14px;
  font-weight: 600;
}

/* 覆盖全局el-tag样式，确保今日新增标签正常显示 */
.stat-today-added :deep(.el-tag) {
  border-radius: 12px !important;
  width: auto !important;
  height: auto !important;
  padding: 6px 14px !important;
  aspect-ratio: unset !important;
  font-size: 15px !important;
}

.icon-svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.icon-svg.sm {
  width: 14px;
  height: 14px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

/* 搜索栏卡片样式 - 参考样例HTML */
.filter-bar {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.filter-form {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  width: 100%;
}

/* 移除el-form-item默认的margin */
.filter-form :deep(.el-form-item) {
  margin-right: 0;
  margin-bottom: 0;
}

/* 筛选项样式 */
.filter-item {
  flex: 0 0 auto;
}

/* 日期范围样式 */
.filter-date-range {
  display: flex;
  align-items: center;
}

/* 分隔线 */
.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}

/* 按钮组 */
.filter-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
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

/* 输入框内容居中显示 */
.centerPlaceholder :deep(.el-input__inner) {
  text-align: center;
}

.centerPlaceholder :deep(.el-input__inner)::placeholder {
  text-align: center;
}

/* 优化输入框和选择器样式 */
:deep(.el-input__wrapper) {
  padding: 1px 8px !important;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  height: 32px;
  transition:
    border-color 0.2s,
    box-shadow 0.2s;
}

:deep(.el-input__inner) {
  height: 32px;
  font-size: 13px;
}

:deep(.el-select__wrapper) {
  height: 32px;
  min-height: 32px;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  font-size: 13px;
  padding: 1px 8px;
  transition:
    border-color 0.2s,
    box-shadow 0.2s;
}

:deep(.el-input__wrapper.is-focus),
:deep(.el-select__wrapper.is-focused) {
  box-shadow:
    0 0 0 1px #2563eb inset,
    0 0 0 3px rgba(37, 99, 235, 0.1) !important;
}

/* 按钮样式优化 */
:deep(.el-button) {
  height: 32px;
  padding: 0 14px;
  font-size: 13px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
}

/* 按钮内图标样式 - 与样例HTML保持一致 */
:deep(.el-button .el-icon) {
  width: 14px;
  height: 14px;
  font-size: 14px;
}

/* 重置按钮样式优化 */
.reset-btn {
  padding: 0 10px;
  min-width: auto;
}

/* 查询按钮样式优化 */
.search-btn {
  padding: 0 10px;
  min-width: auto;
}
</style>
