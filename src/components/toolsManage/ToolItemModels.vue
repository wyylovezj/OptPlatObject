<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 主机密码修改模态框组件（包含历史任务功能）
 * @date: 2026-05-11
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-05-12
 */
import { ref, computed, h, watch } from 'vue'
import { ElMessage, ElButton, ElAutoResizer, ElTableV2 } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { linuxPasswordChange, historyPasswordChangeTask } from '@/api/interface.js'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { historyFileUploadDataModel, historyPasswdModifyDataModel } from '@/utils/publicDataTools.js'

// 定义 props 和 emits（props在模板中使用）
const props = defineProps({
  modelValue: {
    type: Boolean,
    required: true,
  },
  // 是否默认以历史任务模式打开
  defaultHistoryMode: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['update:modelValue', 'close'])

// 获取用户认证信息
const authStore = useAuthStore()

// 监听 modelValue，当模态框打开时根据 defaultHistoryMode 决定显示模式
watch(
  () => props.modelValue,
  (newValue) => {
    if (newValue && props.defaultHistoryMode) {
      // 模态框打开且需要默认显示历史任务模式
      switchToHistoryMode()
    }
  },
)

// 监听历史任务搜索条件中改密类型的变化
watch(
  () => historyFileUploadDataModel.value.category,
  (newValue) => {
    if (newValue === '1') {
      // 当选择单用户改密时，清空账号类型
      historyFileUploadDataModel.value.type = ''
    }
  },
)

// 表单数据模型
const passwordModifyForm = ref({
  category: '', // 改密类型：1-单用户改密，2-多用户改密
  user_name: '', // 执行人（单用户改密时自动填充当前登录用户）
  type: '', // 账号类型（多用户改密时选择）
  app_pwd: '', // 主机应用用户（多用户+应用用户账号时填写）
  user_conf: [], // 主机列表（多用户+应用/系统用户账号时填写）
  task_name: '', // 任务名称
  passwd_user: '', // 用户（单用户改密时填写）
  host: [], // 主机列表（单用户改密时填写）
  taskId: '', // 任务ID（每次调用接口时生成UUID）
})

// 表单实例引用
const formRef = ref(null)

// 表单校验规则
const formRules = ref({
  category: [
    {
      required: true,
      message: '请选择改密类型',
      trigger: 'change',
    },
  ],
  type: [
    {
      required: true,
      message: '请选择账号类型',
      trigger: 'change',
    },
  ],
  app_pwd: [
    {
      required: true,
      message: '请输入主机应用用户',
      trigger: 'blur',
    },
  ],
  user_conf: [
    {
      required: true,
      message: '请输入主机',
      trigger: 'blur',
    },
  ],
  task_name: [
    {
      required: true,
      message: '请输入任务名称',
      trigger: 'blur',
    },
  ],
  passwd_user: [
    {
      required: true,
      message: '请输入用户',
      trigger: 'blur',
    },
  ],
  host: [
    {
      required: true,
      message: '请输入主机',
      trigger: 'blur',
    },
  ],
})

// 按钮禁用状态
const submitDisabled = ref(false)

// 改密类型选项（在模板中使用）
const categoryOptions = [
  { label: '单用户改密', value: '1' },
  { label: '多用户改密', value: '2' },
]

// 账号类型选项（在模板中使用）
const accountTypeOptions = [
  { label: '应用用户账号', value: '应用用户账号' },
  { label: '系统用户账号', value: '系统用户账号' },
  { label: '数据库用户账号', value: '数据库用户账号' },
]

// 计算属性：执行人是否禁用（始终禁用）
const userNameDisabled = computed(() => {
  return true
})

// 计算属性：是否显示账号类型（在模板中使用）
const showAccountType = computed(() => {
  return passwordModifyForm.value.category === '2'
})

// 计算属性：是否显示主机应用用户（多用户+应用用户账号时显示）
const showAppPwd = computed(() => {
  return passwordModifyForm.value.category === '2' && passwordModifyForm.value.type === '应用用户账号'
})

// 计算属性：是否显示user_conf主机列表（多用户+应用/系统用户账号时显示）
const showUserConf = computed(() => {
  return (
    passwordModifyForm.value.category === '2' &&
    (passwordModifyForm.value.type === '应用用户账号' || passwordModifyForm.value.type === '系统用户账号')
  )
})

// 计算属性：是否显示数据库用户（多用户+数据库用户账号时显示）
const showOracleUser = computed(() => {
  return passwordModifyForm.value.category === '2' && passwordModifyForm.value.type === '数据库用户账号'
})

// 计算属性：是否显示用户（在模板中使用）
const showPasswdUser = computed(() => {
  return passwordModifyForm.value.category === '1'
})

// 计算属性：是否显示host主机列表（在模板中使用）
const showHost = computed(() => {
  return passwordModifyForm.value.category === '1'
})

// 计算属性：模态框宽度（根据主机组件是否显示动态调整）
const dialogWidth = computed(() => {
  // 当主机组件显示时（单用户改密或多用户+应用/系统用户账号），宽度为700px
  if (showHost.value || showUserConf.value) {
    return '700px'
  }
  // 否则宽度为500px
  return '500px'
})

// user_conf文本域的值（用于显示和编辑）
const userConfText = ref('')

// host文本域的值（用于显示和编辑）
const hostText = ref('')

// 监听category变化，自动填充执行人
const handleCategoryChange = (value) => {
  // 不管选择什么类型，都自动填充当前登录用户
  passwordModifyForm.value.user_name = authStore.user || ''
}

// 解析文本域内容为数组
const parseTextAreaToArray = (text) => {
  if (!text || text.trim() === '') return []
  // 以分号或换行符分隔
  return text
    .split(/[;\n]/)
    .map((item) => item.trim())
    .filter((item) => item !== '')
}

// 将数组转换为文本域显示格式（用分号连接）
// eslint-disable-next-line no-unused-vars
const arrayToTextArea = (arr) => {
  if (!arr || arr.length === 0) return ''
  return arr.join(';')
}

// user_conf文本域变化处理（在模板中使用）
const handleUserConfChange = (value) => {
  passwordModifyForm.value.user_conf = parseTextAreaToArray(value)
}

// host文本域变化处理（在模板中使用）
const handleHostChange = (value) => {
  passwordModifyForm.value.host = parseTextAreaToArray(value)
}

// 从文件导入user_conf（在模板中使用）
const importUserConfFile = async (file) => {
  try {
    const fileType = file.name.substring(file.name.lastIndexOf('.') + 1).toLowerCase()
    const fileSize = file.size / 1024 / 1024 // MB

    if (fileSize > 1) {
      ElMessage.error('文件大小不能超过1M')
      return false
    }

    if (!['txt', 'xlsx', 'xls'].includes(fileType)) {
      ElMessage.error('只支持txt、excel格式的文件')
      return false
    }

    let content = ''

    if (fileType === 'txt') {
      // 读取txt文件
      content = await readTxtFile(file.raw || file)
    } else {
      // 读取excel文件
      content = await readExcelFile(file.raw || file)
    }

    // 将内容设置到文本域
    userConfText.value = content
    handleUserConfChange(content)

    ElMessage.success('文件导入成功')
    return false // 阻止默认上传行为
  } catch (error) {
    console.error('文件导入失败:', error)
    ElMessage.error('文件导入失败: ' + error.message)
    return false
  }
}

// 从文件导入host（在模板中使用）
const importHostFile = async (file) => {
  try {
    const fileType = file.name.substring(file.name.lastIndexOf('.') + 1).toLowerCase()
    const fileSize = file.size / 1024 / 1024 // MB

    if (fileSize > 1) {
      ElMessage.error('文件大小不能超过1M')
      return false
    }

    if (!['txt', 'xlsx', 'xls'].includes(fileType)) {
      ElMessage.error('只支持txt、excel格式的文件')
      return false
    }

    let content = ''

    if (fileType === 'txt') {
      // 读取txt文件
      content = await readTxtFile(file.raw || file)
    } else {
      // 读取excel文件
      content = await readExcelFile(file.raw || file)
    }

    // 将内容设置到文本域
    hostText.value = content
    handleHostChange(content)

    ElMessage.success('文件导入成功')
    return false // 阻止默认上传行为
  } catch (error) {
    console.error('文件导入失败:', error)
    ElMessage.error('文件导入失败: ' + error.message)
    return false
  }
}

// 读取txt文件
const readTxtFile = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      resolve(e.target.result)
    }
    reader.onerror = () => {
      reject(new Error('文件读取失败'))
    }
    reader.readAsText(file, 'UTF-8')
  })
}

// 读取excel文件（需要安装xlsx库）
const readExcelFile = async (file) => {
  try {
    // 使用FileReader读取文件
    const data = await new Promise((resolve, reject) => {
      const reader = new FileReader()

      reader.onload = (event) => {
        try {
          resolve(event.target.result)
        } catch (error) {
          reject(error)
        }
      }

      reader.onerror = () => {
        reject(new Error('文件读取失败'))
      }

      reader.readAsArrayBuffer(file)
    })

    // 动态导入xlsx库
    const XLSX = await import('xlsx')

    // 解析 Excel 文件
    const workbook = XLSX.read(data, { type: 'array' })

    // 获取所有工作表名称
    const sheetNames = workbook.SheetNames

    if (sheetNames.length === 0) {
      throw new Error('Excel 文件中没有工作表')
    }

    // 读取第一个工作表
    const worksheet = workbook.Sheets[sheetNames[0]]

    // 转换为 JSON 数组（二维数组）
    const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 })

    // 扁平化数组并提取非空值
    const allValues = jsonData.flat()
    const lines = allValues.filter((val) => val !== null && val !== undefined && val !== '').map((val) => String(val).trim())

    // 将所有值用换行符分隔
    return lines.join('\n')
  } catch (error) {
    console.error('Excel解析错误:', error)
    throw new Error('Excel文件解析失败: ' + error.message)
  }
}

// 确认按钮点击事件
const handleSubmit = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (valid) {
      submitDisabled.value = true

      try {
        // 生成任务ID（UUID）
        passwordModifyForm.value.taskId = crypto.randomUUID()
        console.log('taskId:', passwordModifyForm.value.taskId)

        // 调用后端接口
        const response = await linuxPasswordChange(passwordModifyForm.value)

        // 下载返回的excel文件
        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url

        // 生成文件名
        const datetime = new Date()
        const formattedDatetime =
          datetime.getFullYear().toString() +
          (datetime.getMonth() + 1).toString().padStart(2, '0') +
          datetime.getDate().toString().padStart(2, '0') +
          datetime.getHours().toString().padStart(2, '0') +
          datetime.getMinutes().toString().padStart(2, '0') +
          datetime.getSeconds().toString().padStart(2, '0')

        link.setAttribute('download', `改密结果-${formattedDatetime}.xlsx`)
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        window.URL.revokeObjectURL(url)

        ElMessage.success({
          message: '密码修改任务提交成功，文件已下载',
          duration: 2000,
        })

        // 关闭模态框
        handleClose()
      } catch (error) {
        console.error('密码修改失败:', error)
        ElMessage.error({
          message: '密码修改失败: ' + (error.response?.data?.message || error.message),
          duration: 2000,
        })
      } finally {
        submitDisabled.value = false
      }
    }
  })
}

// 取消按钮点击事件
const handleCancel = () => {
  handleClose()
}

// 关闭模态框并重置表单
const handleClose = () => {
  emit('update:modelValue', false)
  emit('close')
  resetForm()
  // 清空历史任务搜索条件
  historyFileUploadDataModel.value.reset()
  historyData.value = []
}

// 重置表单
const resetForm = () => {
  passwordModifyForm.value = {
    category: '',
    user_name: '',
    type: '',
    app_pwd: '',
    user_conf: [],
    task_name: '',
    passwd_user: '',
    host: [],
    taskId: '',
  }

  // 清空文本域
  userConfText.value = ''
  hostText.value = ''

  // 清除表单验证状态
  if (formRef.value) {
    formRef.value.clearValidate()
  }
}

// ==================== 历史任务相关功能 ====================

// 当前显示模式：'form' 表示表单模式，'history' 表示历史任务模式
const displayMode = ref('form')

// 历史任务表格数据
const historyData = ref([])

// 历史任务详情模态框显示状态
const detailDialogVisible = ref(false)

// 当前查看的历史任务详情数据
const currentTaskDetail = ref({})

// 默认时间范围
const defaultTime = ref([new Date(2000, 1, 1, 0, 0, 0), new Date(2000, 2, 1, 23, 59, 59)])

// 历史任务表格列定义
const historyBaseColumns = [
  {
    key: 'index',
    title: '序号',
    dataKey: 'index',
    width: 50,
    align: 'center',
  },
  {
    key: 'execute_time',
    title: '创建日期',
    dataKey: 'execute_time',
    width: 180,
    align: 'center',
  },
  {
    key: 'task_id',
    title: '任务号',
    dataKey: 'task_id',
    width: 280,
    align: 'center',
  },
  {
    key: 'category',
    title: '改密类型',
    dataKey: 'category',
    width: 110,
    align: 'center',
    cellRenderer: ({ rowData }) => {
      return rowData.category === 1 ? '单用户改密' : rowData.category === 2 ? '多用户改密' : '-'
    },
  },
  {
    key: 'type',
    title: '账号类型',
    dataKey: 'type',
    width: 130,
    align: 'center',
    cellRenderer: ({ rowData }) => {
      return rowData.category === 1 ? '-' : rowData.type || '-'
    },
  },
  {
    key: 'task_name',
    title: '任务名称',
    dataKey: 'task_name',
    width: 240,
    align: 'center',
  },
  {
    key: 'user_name',
    title: '执行人',
    dataKey: 'user_name',
    width: 120,
    align: 'center',
  },
  {
    key: 'taskDetail',
    title: '任务详情',
    dataKey: 'taskDetail',
    width: 90,
    align: 'center',
    cellRenderer: ({ rowData }) => {
      return h(
        ElButton,
        {
          type: 'primary',
          size: 'small',
          style: {
            padding: '5px 10px',
          },
          onClick: (event) => {
            event.stopPropagation()
            viewHistoryTaskDetail(rowData)
          },
        },
        { default: () => '查看' },
      )
    },
  },
  {
    key: 'exportFile',
    title: '导出主机列表',
    dataKey: 'exportFile',
    width: 110,
    align: 'center',
    cellRenderer: ({ rowData }) => {
      // 当 category = 2 且 type 为"数据库用户账号"时禁用
      const isDisabled = rowData.category === 2 && rowData.type === '数据库用户账号'

      return h(
        ElButton,
        {
          type: 'success',
          size: 'small',
          disabled: isDisabled,
          style: {
            padding: '5px 10px',
          },
          onClick: (event) => {
            event.stopPropagation()
            exportHostListFile(rowData)
          },
        },
        { default: () => '导出' },
      )
    },
  },
]

// 动态计算历史任务表格列宽
const getHistoryColumns = (parentWidth) => {
  const fixedWidth = historyBaseColumns.reduce((sum, col) => sum + (col.width || 0), 0)
  const autoColumns = historyBaseColumns.filter((col) => col.width === undefined)

  if (autoColumns.length > 0 && parentWidth > fixedWidth) {
    const availableWidth = parentWidth - fixedWidth
    const weightMap = {
      task_id: 2,
      category: 1,
      type: 1,
      task_name: 2,
      execute_time: 1,
      user_name: 1,
      taskDetail: 1,
      exportFile: 1,
    }

    const totalWeight = autoColumns.reduce((sum, col) => {
      return sum + (weightMap[col.key] || 1)
    }, 0)

    const widthPerWeight = availableWidth / totalWeight

    return historyBaseColumns.map((col) => {
      if (col.width === undefined) {
        const weight = weightMap[col.key] || 1
        return {
          ...col,
          width: Math.max(100, Math.floor(weight * widthPerWeight)),
        }
      } else {
        return col
      }
    })
  }

  return historyBaseColumns.map((col) => ({
    ...col,
    width: col.width || 150,
  }))
}

// 初始化历史任务表格
const initHistoryTaskTable = async () => {
  try {
    const execUser = historyPasswdModifyDataModel.value.execUser
    const execTime = historyPasswdModifyDataModel.value.execTime
    const category = historyPasswdModifyDataModel.value.category
    const type = historyPasswdModifyDataModel.value.type
    const responseData = await historyPasswordChangeTask(execUser, execTime, category, type)
    if (responseData.status === 'success') {
      historyData.value = responseData?.data || []
      // 为数据添加序号（从 1 开始）
      historyData.value = historyData.value.map((item, index) => ({
        ...item,
        index: index + 1,
      }))
    } else {
      ElMessage.error('获取历史任务数据失败')
    }
  } catch (error) {
    console.error('获取历史任务数据失败:', error)
    ElMessage.error(`获取历史任务数据失败: ${error.message || '未知错误'}`)
  }
}

// 查看历史任务详情
const viewHistoryTaskDetail = (rowData) => {
  console.log('查看任务详情:', rowData)
  // 将数组字段转换为字符串显示
  currentTaskDetail.value = {
    ...rowData,
    host: Array.isArray(rowData.host) ? rowData.host.join('; ') : rowData.host,
    user_conf: Array.isArray(rowData.user_conf) ? rowData.user_conf.join('; ') : rowData.user_conf,
  }
  detailDialogVisible.value = true
}

// 关闭详情模态框
const closeDetailDialog = () => {
  detailDialogVisible.value = false
  currentTaskDetail.value = {}
}

// 导出主机列表文件
const exportHostListFile = (rowData) => {
  console.log('导出主机列表:', rowData)

  let hostList = []
  let fileName = ''

  // 根据 category 和 type 确定导出的数据
  if (rowData.category === 1) {
    // 单用户改密，导出 host 字段
    hostList = Array.isArray(rowData.host) ? rowData.host : []
    fileName = `${rowData.task_id}.txt`
  } else if (rowData.category === 2 && (rowData.type === '应用用户账号' || rowData.type === '系统用户账号')) {
    // 多用户改密且为应用/系统用户账号，导出 user_conf 字段
    hostList = Array.isArray(rowData.user_conf) ? rowData.user_conf : []
    fileName = `${rowData.task_id}.txt`
  } else {
    ElMessage.warning('该任务没有可导出的主机列表')
    return
  }

  // 检查是否有数据可导出
  if (!hostList || hostList.length === 0) {
    ElMessage.warning('该任务没有可导出的主机列表')
    return
  }

  // 将数组转换为每行一个的文本内容
  const content = hostList.join('\n')

  // 创建 Blob 并下载
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = fileName
  link.click()
  window.URL.revokeObjectURL(url)

  ElMessage.success({
    message: `成功导出 ${hostList.length} 条主机数据`,
    duration: 1500,
  })
}

// 切换到历史任务模式
const switchToHistoryMode = () => {
  displayMode.value = 'history'
  // 模态框打开时自动加载历史任务数据
  initHistoryTaskTable()
}

// 切换回表单模式
const switchToFormMode = () => {
  displayMode.value = 'form'
}

// 关闭历史任务模式
const closeHistoryMode = () => {
  displayMode.value = 'form'
  historyFileUploadDataModel.value.reset()
  historyData.value = []
}

// 暴露方法给父组件调用
defineExpose({
  switchToHistoryMode,
})
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    top="10%"
    :title="displayMode === 'form' ? '主机密码修改' : '历史修改任务'"
    :width="displayMode === 'form' ? dialogWidth : '1350px'"
    center
    destroy-on-close
    :show-close="true"
    append-to-body
    style="user-select: none"
    @close="handleClose"
    :close-on-click-modal="false"
  >
    <!-- 表单模式 -->
    <div v-if="displayMode === 'form'">
      <el-form
        ref="formRef"
        :model="passwordModifyForm"
        :rules="formRules"
        label-position="right"
        label-width="120px"
        style="display: flex; flex-direction: column; justify-content: center"
      >
        <!-- 第1个组件：改密类型 -->
        <el-form-item label="改密类型" prop="category">
          <el-select v-model="passwordModifyForm.category" placeholder="请选择改密类型" clearable style="width: 300px" @change="handleCategoryChange">
            <el-option v-for="item in categoryOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <!-- 第2个组件：执行人（一直可见） -->
        <el-form-item label="执行人">
          <el-input v-model="passwordModifyForm.user_name" placeholder="当前登录用户" :disabled="userNameDisabled" style="width: 300px" />
        </el-form-item>

        <!-- 第7个组件：任务名称（一直显示） -->
        <el-form-item label="任务名称" prop="task_name">
          <el-input v-model="passwordModifyForm.task_name" placeholder="建议格式：yyyy-mm-dd xxxx改密" clearable style="width: 300px" />
        </el-form-item>

        <!-- 第3个组件：账号类型（多用户改密时显示） -->
        <el-form-item v-if="showAccountType" label="账号类型" prop="type">
          <el-select v-model="passwordModifyForm.type" placeholder="请选择账号类型" clearable style="width: 300px">
            <el-option v-for="item in accountTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <!-- 第4个组件：主机应用用户（多用户+应用用户账号时显示） -->
        <el-form-item v-if="showAppPwd" label="应用用户密码" prop="app_pwd">
          <el-input v-model="passwordModifyForm.app_pwd" placeholder="需要修改密码的主机应用用户账号" clearable style="width: 300px" />
        </el-form-item>

        <!-- 第5个组件：user_conf主机列表（多用户+应用/系统用户账号时显示） -->
        <el-form-item v-if="showUserConf" label="主机列表" prop="user_conf">
          <div style="display: flex; align-items: flex-start; gap: 10px">
            <el-input
              v-model="userConfText"
              type="textarea"
              :rows="10"
              placeholder="需要修改密码的主机"
              style="width: 400px"
              resize="none"
              @input="handleUserConfChange"
            />
            <div style="display: flex; flex-direction: column; gap: 8px">
              <el-upload action="#" :auto-upload="false" :on-change="importUserConfFile" :show-file-list="false" accept=".txt,.xlsx,.xls">
                <el-button type="primary">从文件导入</el-button>
              </el-upload>
              <span style="font-size: 12px; color: #909399">支持txt、excel格式的文件</span>
            </div>
          </div>
        </el-form-item>

        <!-- 第8个组件：用户（单用户改密时显示） -->
        <el-form-item v-if="showPasswdUser || showOracleUser" :label="showPasswdUser ? '用户账号' : '数据库用户账号'" prop="passwd_user">
          <el-input
            v-model="passwordModifyForm.passwd_user"
            :placeholder="showPasswdUser ? '需要修改密码的用户账号' : '需要修改密码的数据库用户账号'"
            clearable
            style="width: 300px"
          />
        </el-form-item>

        <!-- 第9个组件：host主机列表（单用户改密时显示） -->
        <el-form-item v-if="showHost" label="主机列表" prop="host">
          <div style="display: flex; align-items: flex-start; gap: 10px">
            <el-input
              v-model="hostText"
              type="textarea"
              :rows="10"
              placeholder="需要修改密码的主机"
              style="width: 400px"
              resize="none"
              @input="handleHostChange"
            />
            <div style="display: flex; flex-direction: column; gap: 8px">
              <el-upload action="#" :auto-upload="false" :on-change="importHostFile" :show-file-list="false" accept=".txt,.xlsx,.xls">
                <el-button type="primary">从文件导入</el-button>
              </el-upload>
              <span style="font-size: 12px; color: #909399">支持txt、excel格式的文件</span>
            </div>
          </div>
        </el-form-item>
      </el-form>

      <div style="display: flex; justify-content: center; gap: 10px; margin-top: 20px">
        <el-button type="primary" @click="handleSubmit" :disabled="submitDisabled">确认</el-button>
        <el-button type="primary" @click="handleCancel">取消</el-button>
      </div>
    </div>

    <!-- 历史任务模式 -->
    <div v-else>
      <div style="height: 100px">
        <el-form
          :model="historyFileUploadDataModel"
          :inline="true"
          label-position="right"
          label-width="auto"
          style="display: flex; flex-wrap: nowrap; gap: 2px; align-items: center"
        >
          <el-form-item label="执行用户" prop="execUser" style="margin-bottom: 0">
            <el-input
              v-model="historyFileUploadDataModel.execUser"
              style="width: 160px"
              placeholder="请输入执行用户"
              maxlength="15"
              type="text"
              clearable
              spellcheck="false"
            />
          </el-form-item>
          <el-form-item label="改密类型" prop="category" style="margin-bottom: 0">
            <el-select v-model="historyFileUploadDataModel.category" placeholder="请选择" clearable style="width: 130px">
              <el-option label="单用户改密" value="1" />
              <el-option label="多用户改密" value="2" />
            </el-select>
          </el-form-item>
          <el-form-item label="账号类型" prop="type" style="margin-bottom: 0">
            <el-select
              v-model="historyFileUploadDataModel.type"
              placeholder="请选择"
              clearable
              :disabled="historyFileUploadDataModel.category === '1'"
              style="width: 150px"
            >
              <el-option label="应用用户账号" value="应用用户账号" />
              <el-option label="系统用户账号" value="系统用户账号" />
              <el-option label="数据库用户账号" value="数据库用户账号" />
            </el-select>
          </el-form-item>
          <el-form-item label="创建时间" prop="execTime" style="margin-bottom: 0">
            <el-date-picker
              v-model="historyFileUploadDataModel.execTime"
              type="daterange"
              start-placeholder="开始日期"
              end-placeholder="结束日期"
              value-format="YYYY-MM-DD HH:mm:ss"
              unlink-panels
              :default-time="defaultTime"
              style="width: 300px"
            />
          </el-form-item>
          <el-form-item style="flex: none; margin-left: 4px; margin-right: 5px; margin-bottom: 0">
            <el-button type="primary" :icon="Search" circle @click="initHistoryTaskTable" size="default" />
          </el-form-item>
        </el-form>
      </div>
      <div style="height: 400px">
        <el-auto-resizer>
          <template #default="{ height, width }">
            <el-table-v2 :columns="getHistoryColumns(width)" :data="historyData" :width="width" :height="height" fixed />
          </template>
        </el-auto-resizer>
      </div>
    </div>
  </el-dialog>

  <!-- 历史任务详情子模态框 -->
  <el-dialog
    v-model="detailDialogVisible"
    title="任务详情"
    width="600px"
    center
    destroy-on-close
    :show-close="true"
    append-to-body
    style="user-select: none"
    @close="closeDetailDialog"
    :close-on-click-modal="false"
  >
    <el-scrollbar max-height="600px">
      <el-descriptions :column="1" border label-class-name="detail-label" content-class-name="detail-content" :label-width="130">
        <el-descriptions-item label="任务号">
          {{ currentTaskDetail.task_id || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="创建日期">
          {{ currentTaskDetail.execute_time || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="执行人">
          <el-tag type="primary" round>{{ currentTaskDetail.user_name || '-' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="改密类型">
          {{ currentTaskDetail.category === 1 ? '单用户改密' : currentTaskDetail.category === 2 ? '多用户改密' : '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="任务名称">
          {{ currentTaskDetail.task_name || '-' }}
        </el-descriptions-item>
        <el-descriptions-item v-if="currentTaskDetail.category === 2" label="账号类型">
          {{ currentTaskDetail.type || '-' }}
        </el-descriptions-item>
        <el-descriptions-item
          v-if="!(currentTaskDetail.category === 2 && (currentTaskDetail.type === '应用用户账号' || currentTaskDetail.type === '系统用户账号'))"
          :label="currentTaskDetail.category === 1 ? '用户账号' : '数据库用户账号'"
        >
          <el-tag type="warning" round>{{ currentTaskDetail.passwd_user || '-' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item
          v-if="
            !(
              currentTaskDetail.category === 2 &&
              (currentTaskDetail.type === '应用用户账号' || currentTaskDetail.type === '系统用户账号' || currentTaskDetail.type === '数据库用户账号')
            )
          "
          label="主机列表"
        >
          <div style="white-space: pre-wrap; word-break: break-all">
            {{ currentTaskDetail.host || '-' }}
          </div>
        </el-descriptions-item>
        <el-descriptions-item v-if="currentTaskDetail.category === 2 && currentTaskDetail.type === '应用用户账号'" label="应用用户密码">
          <el-tag type="success" round>{{ currentTaskDetail.app_pwd || '-' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item
          v-if="currentTaskDetail.category === 2 && (currentTaskDetail.type === '应用用户账号' || currentTaskDetail.type === '系统用户账号')"
          label="主机列表"
        >
          <div style="white-space: pre-wrap; word-break: break-all">
            {{ currentTaskDetail.user_conf || '-' }}
          </div>
        </el-descriptions-item>
      </el-descriptions>
    </el-scrollbar>
  </el-dialog>
</template>

<style scoped>
/* 可以在这里添加自定义样式 */
:deep(.detail-label) {
  width: 120px;
  font-weight: bold;
}

:deep(.detail-content) {
  word-break: break-all;
}
</style>
