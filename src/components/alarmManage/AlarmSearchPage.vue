<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：告警页面搜索栏组件
 * @date： 2026-01-28 09:29:55
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:29:55
 */
import { ref,watch,onUnmounted } from 'vue'
import { selectedRows, DialogVisibleClose, refresh, searchQuery, dataDictionary, isFilter } from '@/utils/publicData.js'
import { getAlarmDictionary } from '@/api/interface.js'
import { ElMessage } from 'element-plus'

const defaultTime = ref([
  new Date(2000, 1, 1, 0, 0, 0),
  new Date(2000, 2, 1, 23, 59, 59),
])
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
// 监听搜索数据模型变化：触发搜索框全选权限功能
watch(searchQuery, (val) => {
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
  }  else if (val.system_name.length === dataDictionary.value.system_name.length) {
    checkAllSystem.value = true
    indeterminateSystem.value = false
  }  else if (val.system_name.length > 0) {
    indeterminateSystem.value = true
  }
}, { deep: true }
)
// 告警分类全选按钮标志
const checkAllCategory = ref(false)
const indeterminateCategory = ref(false)
// 告警分类搜索关键词
const searchKeywordCategory = ref('');

// 告警分类过滤后的选项列表
const filteredOptionsCategory = ref([]);
// 告警分类初始化过滤选项
const initFilteredOptionsCategory = () => {
  if (searchKeywordCategory.value) {
    // 如果搜索关键词不为空，根据关键词过滤选项
    filteredOptionsCategory.value = dataDictionary.value.category.filter((item) =>
      Object.values(item)[0].toLowerCase().includes(searchKeywordCategory.value)
    );
  } else {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsCategory.value = [...dataDictionary.value.category];
  }
};

// 告警分类过滤选项函数
const filterOptionsCategory = () => {
  if (!searchKeywordCategory.value) {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsCategory.value = [...dataDictionary.value.category];
  } else {
    // 根据关键词过滤选项
    filteredOptionsCategory.value = dataDictionary.value.category.filter((item) =>
      Object.values(item)[0].toLowerCase().includes(searchKeywordCategory.value)
    );
  }
};
// 告警分类监听下拉框显示状态，初始化过滤选项
watch((visible) => {
  if (visible) {
    initFilteredOptionsCategory();
  }
});
// 告警分类全选按钮
const handleCheckAllCategory = (val) => {
  indeterminateCategory.value = false
  if (val) {
    searchQuery.value.category = [...filteredOptionsCategory.value];
  } else {
    searchQuery.value.category = [];
  }
};
// 业务系统按钮标志
const checkAllSystem = ref(false)
const indeterminateSystem = ref(false)

// 业务系统搜索关键词
const searchKeywordSystemName = ref('');

// 业务系统过滤后的选项列表
const filteredOptionsSystemName = ref([]);
// 业务系统初始化过滤选项
const initFilteredOptionsSystemName = () => {
  if (searchKeywordSystemName.value) {
    // 如果搜索关键词不为空，根据关键词过滤选项
    filteredOptionsSystemName.value = dataDictionary.value.system_name.filter((item) =>
      item.includes(searchKeywordSystemName.value)
    );
  } else {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsSystemName.value = [...dataDictionary.value.system_name];
  }
};

// 业务系统过滤选项函数
const filterOptionsSystemName = () => {
  if (!searchKeywordSystemName.value) {
    // 如果搜索关键词为空，显示所有选项
    filteredOptionsSystemName.value = [...dataDictionary.value.system_name];
  } else {
    // 根据关键词过滤选项
    filteredOptionsSystemName.value = dataDictionary.value.system_name.filter((item) =>
      item.includes(searchKeywordSystemName.value)
    );
  }
};
// 业务系统监听下拉框显示状态，初始化过滤选项
watch((visible) => {
  if (visible) {
    initFilteredOptionsSystemName();
  }
});
// 业务系统全选逻辑
const handleCheckAllSystem = (val) => {
  indeterminateSystem.value = false;
  if (val) {
    searchQuery.value.system_name = [...filteredOptionsSystemName.value];
  } else {
    searchQuery.value.system_name = [];
  }
};
// 重置按钮清空搜索数据
const formSearch = ref(null)

const clearSearch = () => {
  if (formSearch.value) {
    // 重置表单验证和字段值
    formSearch.value.resetFields()
    // 重置数据模型值
    searchQuery.value = {
      category: [],      // 告警分类
      severity: '',      // 告警级别
      ip: '',            // IP地址
      object: '',        // 主机名
      system_name: [],   // 业务系统
      occurrenceTime: [], // 发生时间
      state: '',         // 告警状态
      source: ''         // 告警来源
    }
    // 重置数据字典值
    dataDictionary.value.category= []
    dataDictionary.value.system_name= []
    indeterminateCategory.value = false
    indeterminateSystem.value = false
    checkAllCategory.value= false
    checkAllSystem.value= false
  }
}

// 批量关闭功能
// 存储当前显示的提示框实例
const messageInstance = ref(null)
const batchClose = async () => {

  // 检查选中的节点中是否有状态为"已关闭"的告警
  const closedRows = selectedRows.value.filter(row => row.state === '已关闭')
  if (closedRows.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise(resolve => setTimeout(resolve, 0));
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `选中的 ${closedRows.length} 条告警状态为"已关闭"，不允许再次关闭`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  if (selectedRows.value.length === 0) {
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 使用setTimeout给DOM更新留出时间
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.warning({
      message: '请先选择要关闭的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  DialogVisibleClose.value = true
}
const batchCreateTickets = async () => {
  // 检查选中的节点中是否有状态为"已分派"的告警
  const closedRows = selectedRows.value.filter(row => row.state === '已分派')
  if (closedRows.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise(resolve => setTimeout(resolve, 0));
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `选中的 ${closedRows.length} 条告警状态为"已分派"，不允许再次分派工单`,
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  if (selectedRows.value.length === 0) {
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 使用setTimeout给DOM更新留出时间
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.warning({
      message: '请先选择要分派的数据',
      duration: 1000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  console.log('batchCreateTickets')
}
onUnmounted(() => {
  clearSearch()
})
</script>

<template>
  <div class="search-page-container">
    <el-form ref="formSearch" :inline="true" :model="searchQuery" style=" display: flex;align-items: center;  flex-wrap: wrap;width: 100%;">
      <el-form-item label="告警分类：" prop="category">
        <el-select
          v-model="searchQuery.category"
          multiple
          collapse-tags
          collapse-tags-tooltip
          default-first-option
          fit-input-width
          :class="{ centerPlaceholder: searchQuery.category.length === 0 }"
          clearable
          placeholder="请选择"
          style="width: 200px"
          @visible-change="(visible) => {getAlarmDictionary(visible, '告警分类')}"
          @clear="checkAllCategory= false;searchQuery.category = [];dataDictionary.category = []">
          <template #header>
            <!-- 自定义搜索输入框 -->
            <el-input
              v-model="searchKeywordCategory"
              placeholder="搜索选项"
              @input="filterOptionsCategory"
              clearable
            />
            <el-checkbox
              v-model="checkAllCategory"
              :indeterminate="indeterminateCategory"
              @change="handleCheckAllCategory"
            >
              全选
            </el-checkbox>
          </template>
          <el-option v-for="(item,index) in filteredOptionsCategory" :key="index" :label="Object.values(item)[0]" :value="Object.keys(item)[0]" />
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
          clearable
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
          clearable
        />
      </el-form-item>
      <el-form-item label="业务系统：" prop="system_name">
        <el-select
          v-model="searchQuery.system_name"
          multiple
          collapse-tags
          collapse-tags-tooltip
          default-first-option
          fit-input-width
          :class="{ centerPlaceholder: searchQuery.system_name.length === 0 }"
          clearable
          placeholder="请选择"
          style="width: 200px"
          @visible-change="(visible) => {getAlarmDictionary(visible, '系统名称');}"
          @clear="checkAllSystem= false;searchQuery.system_name = [];dataDictionary.system_name = []">
          <template #header>
            <!-- 自定义搜索输入框 -->
            <el-input
              v-model="searchKeywordSystemName"
              placeholder="搜索选项"
              @input="filterOptionsSystemName"
              clearable
            />
            <el-checkbox
              v-model="checkAllSystem"
              :indeterminate="indeterminateSystem"
              @change="handleCheckAllSystem"
            >
              全选
            </el-checkbox>
          </template>
          <el-option v-for="(item,index) in filteredOptionsSystemName" :key="index" :value="item" />
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
          :default-time="defaultTime"
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
          <el-button type="primary" @click="batchCreateTickets">批量触发工单</el-button>
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
/*输入框内容居中显示*/
.centerPlaceholder :deep(.el-input__inner) {
  text-align: center;
}
.centerPlaceholder :deep(.el-input__inner)::placeholder {
  text-align: center;
}

</style>
