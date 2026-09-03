<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: Linux系统工具模态框组件（包含历史任务功能）
 * @date: 2026-09-01
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-09-01
 */
import { ref, computed, h, watch, defineProps, defineEmits } from 'vue'
import { ElMessage, ElButton, ElTag, ElAutoResizer, ElTableV2, ElLoading } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { linuxToolExecute, historyLinuxToolTask, checkLinuxToolRoot } from '@/api/linuxToolApi.js'
import { historyLinuxToolDataModel } from '@/utils/publicDataTools.js'

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

// 监听 modelValue，当模态框打开时鉴定root权限并根据 defaultHistoryMode 决定显示模式
watch(
  () => props.modelValue,
  (newValue) => {
    if (newValue) {
      // 模态框打开时鉴定当前用户是否拥有root权限
      checkRootPermission()
      if (props.defaultHistoryMode) {
        // 模态框打开且需要默认显示历史任务模式
        switchToHistoryMode()
      }
    }
  },
)

// 控制台表单数据模型
const linuxToolForm = ref({
  sys_user: '', // 系统用户
  host: [], // 目的主机列表
  time_out: 10, // 超时时间（秒）
  script: [], // 脚本内容（按行拆分，保留行内空格）
})

// 表单实例引用
const formRef = ref(null)

// 表单校验规则
const formRules = ref({
  sys_user: [
    {
      required: true,
      message: '请选择系统用户',
      trigger: 'change',
    },
  ],
  host: [
    {
      required: true,
      message: '请输入或导入目的主机',
      trigger: 'blur',
    },
  ],
  time_out: [
    {
      required: true,
      message: '请输入超时时间',
      trigger: 'blur',
    },
  ],
  script: [
    {
      required: true,
      message: '请输入或导入脚本内容',
      trigger: 'blur',
    },
  ],
})

// 按钮禁用状态
const submitDisabled = ref(false)

// 加载实例（用于全局遮罩层）
let loadingInstance = null

// 当前登录用户名（用于root权限鉴定与身份确认比对）
const currentUsername = sessionStorage.getItem('user') || ''

// 系统用户选项（root选项根据后端权限鉴定结果动态显示）
const sysUserOptions = ref([
  { label: 'sysmonitor', value: 'sysmonitor' },
])

// 请求后端鉴定当前用户是否拥有root权限，控制系统用户下拉框中root选项的可见性
const checkRootPermission = async () => {
  try {
    const responseData = await checkLinuxToolRoot(currentUsername)
    const hasRoot = responseData?.data?.root === true
    if (hasRoot) {
      // 拥有root权限：下拉框中追加root选项
      if (!sysUserOptions.value.some((item) => item.value === 'root')) {
        sysUserOptions.value.push({ label: 'root', value: 'root' })
      }
    } else {
      // 无root权限：移除root选项，并清空已选中的root
      sysUserOptions.value = sysUserOptions.value.filter((item) => item.value !== 'root')
      if (linuxToolForm.value.sys_user === 'root') {
        linuxToolForm.value.sys_user = ''
      }
    }
  } catch (error) {
    console.error('root权限鉴定失败:', error)
    ElMessage.error('root权限鉴定失败: ' + error.message)
  }
}

// 计算属性：模态框宽度（控制台表单始终包含文本域组件，固定为700px）
const dialogWidth = computed(() => {
  return '800px'
})

// 目的主机文本域的值（用于显示和编辑）
const hostText = ref('')

// 脚本内容文本域的值（用于显示和编辑）
const scriptText = ref('')

// 解析目的主机文本域内容为数组（以换行符分隔，去除每行首尾空格）
const parseHostToArray = (text) => {
  if (!text || text.trim() === '') return []
  return text
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter((item) => item !== '')
}

// 解析脚本内容为行数组（以换行符分隔，保留每行原始空格与缩进，仅过滤纯空行）
const parseScriptToLines = (text) => {
  if (!text || text.trim() === '') return []
  return text
    .split(/\r?\n/)
    .filter((line) => line.trim() !== '')
}

// 目的主机文本域变化处理（在模板中使用）
const handleHostChange = (value) => {
  linuxToolForm.value.host = parseHostToArray(value)
}

// 脚本内容文本域变化处理（在模板中使用）
const handleScriptChange = (value) => {
  linuxToolForm.value.script = parseScriptToLines(value)
}

// 从文件导入目的主机（在模板中使用）
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

    // 将内容设置到文本域（每个IP占一行）
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

// 从文件导入脚本内容（在模板中使用）
const importScriptFile = async (file) => {
  try {
    const fileType = file.name.substring(file.name.lastIndexOf('.') + 1).toLowerCase()
    const fileSize = file.size / 1024 / 1024 // MB

    if (fileSize > 1) {
      ElMessage.error('文件大小不能超过1M')
      return false
    }

    if (!['txt', 'sh'].includes(fileType)) {
      ElMessage.error('只支持txt、sh格式的文件')
      return false
    }

    // 读取txt文件，保持shell脚本原格式（空格与缩进原样保留）
    const content = await readTxtFile(file.raw || file)

    // 将内容设置到文本域
    scriptText.value = content
    handleScriptChange(content)

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

// 身份确认模态框显示状态
const confirmDialogVisible = ref(false)

// 身份确认表单数据模型
const confirmForm = ref({
  username: '', // 确认用户名
  password: '', // 确认密码
})

// 身份确认表单实例引用
const confirmFormRef = ref(null)

// 身份确认表单校验规则
const confirmFormRules = ref({
  username: [
    {
      required: true,
      message: '请输入用户名',
      trigger: 'blur',
    },
  ],
  password: [
    {
      required: true,
      message: '请输入密码',
      trigger: 'blur',
    },
  ],
})

// 确认按钮点击事件：表单校验通过后弹出身份确认模态框
const handleSubmit = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (valid) {
      // 打开身份确认模态框
      confirmDialogVisible.value = true
    }
  })
}

// 身份确认模态框确定按钮：比对输入用户名与当前登录用户，一致才提交任务
const handleConfirmSubmit = async () => {
  if (!confirmFormRef.value) return

  await confirmFormRef.value.validate((valid) => {
    if (!valid) return
    // 比对输入的用户名与当前登录用户是否一致
    if (confirmForm.value.username !== currentUsername) {
      ElMessage.error({
        message: '用户与当前登录用户不一致',
        duration: 2000,
      })
      return
    }
    // 用户名一致：关闭身份确认模态框并提交任务
    confirmDialogVisible.value = false
    submitTask()
  })
}

// 身份确认模态框取消按钮：关闭模态框并重置身份确认表单
const handleConfirmCancel = () => {
  confirmDialogVisible.value = false
  confirmForm.value.username = ''
  confirmForm.value.password = ''
  if (confirmFormRef.value) {
    confirmFormRef.value.clearValidate()
  }
}

// 将执行结果写入文件并下载到浏览器
const downloadResultFile = (taskId, resultData) => {
  const statusText = resultData.status === 'success' ? '成功' : resultData.status === 'fail' ? '失败' : resultData.status || '未知'
  // 执行结果内容：整体字符串（内部已含换行符），兼容历史数据中的逐行数组格式
  const resultText = Array.isArray(resultData.result) ? resultData.result.join('\n') : resultData.result || ''
  // 首行记录执行状态，其余为脚本输出内容
  const content = [`执行状态：${statusText}`, '', resultText].join('\n')

  // 创建 Blob 并下载
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${taskId}.log`
  link.click()
  window.URL.revokeObjectURL(url)
}

// 提交任务到后端
const submitTask = async () => {
  submitDisabled.value = true
  // 显示全局遮罩层（服务端等待脚本执行完成后才响应，遮罩持续到响应返回）
  loadingInstance = ElLoading.service({
    lock: true,
    text: '温馨提示：任务执行中，请耐心等待，不要离开页面！',
    background: 'rgba(0, 0, 0, 0.7)',
    customClass: 'custom-loading-progress',
  })

  try {
    // 生成任务ID（UUID）
    const taskId = crypto.randomUUID()
    console.log('taskId:', taskId)

    // 调用后端接口（服务端轮询等待执行结果写回后才响应）
    const response = await linuxToolExecute({
      taskId: taskId,
      sys_user: linuxToolForm.value.sys_user,
      host: linuxToolForm.value.host,
      time_out: linuxToolForm.value.time_out, // 超时时间（秒）
      script: linuxToolForm.value.script,
      operator_username: confirmForm.value.username, // 身份确认用户名
      operator_password: confirmForm.value.password, // 身份确认密码
    })
    console.log('任务提交结果:', response)

    const resultData = response?.data || {}
    if (resultData.status) {
      // 服务端已返回执行结果：将结果数据写入文件下载到浏览器
      downloadResultFile(taskId, resultData)
      ElMessage.success({
        message: '任务执行完成，结果文件已下载',
        duration: 2000,
      })
      // 关闭模态框
      handleClose()
    } else if (resultData.status === 'error') {
      // 等待结果超时：任务已提交，可稍后在历史任务中查看
      ElMessage.error({
        message: '用户密码校验失败，请重新输入',
        duration: 3000,
      })
    } else {
      // 等待结果超时：任务已提交，可稍后在历史任务中查看
      ElMessage.warning({
        message: '任务已提交，执行结果获取超时，请稍后在历史任务中查看',
        duration: 3000,
      })
      // 关闭模态框
      handleClose()
    }
  } catch (error) {
    console.error('任务提交失败:', error)
    ElMessage.error({
      message: '任务提交失败: ' + error.message,
      duration: 2000,
    })
  } finally {
    submitDisabled.value = false
    // 关闭全局遮罩层
    if (loadingInstance) {
      loadingInstance.close()
      loadingInstance = null
    }
    // 重置身份确认表单
    confirmForm.value.username = ''
    confirmForm.value.password = ''
    if (confirmFormRef.value) {
      confirmFormRef.value.clearValidate()
    }
  }
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
  // 关闭并重置身份确认模态框
  handleConfirmCancel()
  // 清空历史任务搜索条件
  historyLinuxToolDataModel.value.reset()
  historyData.value = []
}

// 重置表单
const resetForm = () => {
  linuxToolForm.value = {
    sys_user: '',
    host: [],
    time_out: 10,
    script: [],
  }

  // 清空文本域
  hostText.value = ''
  scriptText.value = ''

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

// 历史任务表格高度：表头50px + 每行50px，表格不内部滚动，超出可视高度由外层el-scrollbar滚动
const historyTableHeight = computed(() => {
  return Math.max(50 + historyData.value.length * 50, 300)
})

// 默认时间范围
const defaultTime = ref([new Date(2000, 1, 1, 0, 0, 0), new Date(2000, 2, 1, 23, 59, 59)])

// 历史任务表格列定义（序号列固定宽度，其余业务列按权重均匀分布占满整行）
const historyBaseColumns = [
  {
    key: 'index',
    title: '序号',
    dataKey: 'index',
    width: 50,
    align: 'center',
  },
  {
    key: 'create_time',
    title: '创建日期',
    dataKey: 'create_time',
    align: 'center',
  },
  {
    key: 'task_id',
    title: '任务号',
    dataKey: 'task_id',
    align: 'center',
  },
  {
    key: 'sys_user',
    title: '系统用户',
    dataKey: 'sys_user',
    align: 'center',
  },
  {
    key: 'user_name',
    title: '执行人',
    dataKey: 'user_name',
    align: 'center',
  },
  {
    key: 'status',
    title: '状态',
    dataKey: 'status',
    align: 'center',
    // 执行状态渲染：success显示绿色成功，fail显示红色失败，其余显示原值
    cellRenderer: ({ rowData }) => {
      const isSuccess = rowData.status === 'success'
      const isFail = rowData.status === 'fail'
      return h(
        ElTag,
        {
          type: isSuccess ? 'success' : isFail ? 'danger' : 'info',
          size: 'small',
        },
        { default: () => (isSuccess ? '成功' : isFail ? '失败' : rowData.status || '未知') },
      )
    },
  },
  {
    key: 'taskDetail',
    title: '脚本详情',
    dataKey: 'taskDetail',
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
            exportScriptFile(rowData)
          },
        },
        { default: () => '导出' },
      )
    },
  },
  {
    key: 'exportFile',
    title: '主机列表',
    dataKey: 'exportFile',
    align: 'center',
    cellRenderer: ({ rowData }) => {
      return h(
        ElButton,
        {
          type: 'success',
          size: 'small',
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
  {
    key: 'result',
    title: '执行结果',
    dataKey: 'result',
    align: 'center',
    cellRenderer: ({ rowData }) => {
      return h(
        ElButton,
        {
          type: 'warning',
          size: 'small',
          style: {
            padding: '5px 10px',
          },
          onClick: (event) => {
            event.stopPropagation()
            exportResultFile(rowData)
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
      // 任务号需完整显示UUID，权重最大；其余列按内容长度分配，视觉均匀
      task_id: 2.6,
      create_time: 1.3,
      sys_user: 0.9,
      user_name: 0.9,
      status: 0.7,
      taskDetail: 0.9,
      exportFile: 0.9,
      result: 0.9,
    }

    const totalWeight = autoColumns.reduce((sum, col) => {
      return sum + (weightMap[col.key] || 1)
    }, 0)

    const widthPerWeight = availableWidth / totalWeight

    // 保底宽度提升会使列宽总和超出容器，需从最宽列回收差值，避免出现水平滚动条
    const columns = historyBaseColumns.map((col) => {
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

    const overflowWidth = columns.reduce((sum, col) => sum + col.width, 0) - parentWidth
    if (overflowWidth > 0) {
      const widestColumn = columns.reduce((max, col) => (col.width > max.width ? col : max), columns[0])
      widestColumn.width -= overflowWidth
    }

    return columns
  }

  return historyBaseColumns.map((col) => ({
    ...col,
    width: col.width || 150,
  }))
}

// 初始化历史任务表格
const initHistoryTaskTable = async () => {
  try {
    const execUser = historyLinuxToolDataModel.value.execUser
    const sysUser = historyLinuxToolDataModel.value.sysUser
    const execTime = historyLinuxToolDataModel.value.execTime
    const status = historyLinuxToolDataModel.value.status
    console.log('execUser:', execUser)
    console.log('sysUser:', sysUser)
    console.log('execTime:', execTime)
    console.log('status:', status)
    // 调用后端接口
    const responseData = await historyLinuxToolTask(execUser, execTime, sysUser, status)
    if (responseData) {
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

// 导出脚本详情文件
const exportScriptFile = (rowData) => {
  console.log('导出脚本详情:', rowData)

  const scriptLines = Array.isArray(rowData.script) ? rowData.script : []

  // 检查是否有脚本内容可导出
  if (!scriptLines || scriptLines.length === 0) {
    ElMessage.warning('该任务没有脚本内容可导出')
    return
  }

  // 将脚本行转换为每行一条的文本内容
  const content = scriptLines.join('\n')

  // 创建 Blob 并下载
  const blob = new Blob([content], { type: 'text/x-sh;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${rowData.task_id}.sh`
  link.click()
  window.URL.revokeObjectURL(url)

  ElMessage.success({
    message: '脚本内容导出成功',
    duration: 1500,
  })
}

// 导出主机列表文件
const exportHostListFile = (rowData) => {
  console.log('导出主机列表:', rowData)

  const hostList = Array.isArray(rowData.host) ? rowData.host : []

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
  link.download = `${rowData.task_id}.txt`
  link.click()
  window.URL.revokeObjectURL(url)

  ElMessage.success({
    message: `成功导出 ${hostList.length} 条主机数据`,
    duration: 1500,
  })
}

// 导出执行结果文件
const exportResultFile = (rowData) => {
  console.log('导出执行结果:', rowData)

  // 执行结果内容：整体字符串（内部已含换行符），兼容历史数据中的逐行数组格式
  const resultText = Array.isArray(rowData.result) ? rowData.result.join('\n') : rowData.result || ''

  // 检查是否有结果内容可导出
  if (!resultText || resultText.trim() === '') {
    ElMessage.warning('该任务没有执行结果可导出')
    return
  }

  // 字符串本身已按换行符分行，直接作为文件内容
  const content = resultText

  // 创建 Blob 并下载
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${rowData.task_id}.log`
  link.click()
  window.URL.revokeObjectURL(url)

  ElMessage.success({
    message: '执行结果导出成功',
    duration: 1500,
  })
}

// 切换到历史任务模式
const switchToHistoryMode = () => {
  displayMode.value = 'history'
  // 模态框打开时自动加载历史任务数据
  initHistoryTaskTable()
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
    :title="displayMode === 'form' ? 'Linux系统工具' : '历史任务'"
    :width="displayMode === 'form' ? dialogWidth : '1250px'"
    center
    destroy-on-close
    :show-close="displayMode === 'form' ? false : true"
    append-to-body
    style="user-select: none"
    @close="handleClose"
    :close-on-click-modal="false"
  >
    <!-- 表单模式 -->
    <div v-if="displayMode === 'form'">
      <el-form
        ref="formRef"
        :model="linuxToolForm"
        :rules="formRules"
        label-position="right"
        label-width="120px"
        style="display: flex; flex-direction: column; justify-content: center"
      >
        <!-- 第1个组件：系统用户 -->
        <el-form-item label="系统用户" prop="sys_user">
          <el-select v-model="linuxToolForm.sys_user" placeholder="请选择系统用户" clearable style="width: 200px">
            <el-option v-for="item in sysUserOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <!-- 第2个组件：目的主机 -->
        <el-form-item label="目的主机" prop="host">
          <div style="display: flex; align-items: flex-start; gap: 10px">
            <el-input
              v-model="hostText"
              type="textarea"
              :autosize="{ minRows: 5, maxRows: 5 }"
              placeholder="请输入目的主机IP，每行一个"
              style="width: 250px"
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

        <!-- 第3个组件：超时时间 -->
        <el-form-item label="超时时间" prop="time_out">
          <el-input-number v-model="linuxToolForm.time_out" :min="10" :max="3600" :step="10" style="width: 200px">
            <template #suffix>
              <span>秒</span>
            </template>
          </el-input-number>
          <span style="font-size: 12px; color: #909399; margin-left: 10px">有效范围：10 ~ 3600</span>
        </el-form-item>

        <!-- 第4个组件：脚本内容 -->
        <el-form-item label="脚本内容" prop="script">
          <div style="display: flex; align-items: flex-start; gap: 10px">
            <el-input
              v-model="scriptText"
              type="textarea"
              :autosize="{ minRows: 5, maxRows: 10, minColumns: 50, maxColumns: 100 }"
              placeholder="请输入shell脚本内容，保持脚本原格式"
              style="width: 500px"
              resize="none"
              @input="handleScriptChange"
              SPELLCHECK="false"
            />
            <div style="display: flex; flex-direction: column; gap: 8px">
              <el-upload action="#" :auto-upload="false" :on-change="importScriptFile" :show-file-list="false" accept=".txt,.sh">
                <el-button type="primary">从文件导入</el-button>
              </el-upload>
              <span style="font-size: 12px; color: #909399">支持txt、sh格式的文件，保留脚本原格式</span>
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
          :model="historyLinuxToolDataModel"
          :inline="true"
          label-position="right"
          label-width="auto"
          style="display: flex; flex-wrap: nowrap; gap: 2px; align-items: center"
        >
          <el-form-item label="执行用户" prop="execUser" style="margin-right: 10px; margin-bottom: 0">
            <el-input
              v-model="historyLinuxToolDataModel.execUser"
              style="width: 140px"
              placeholder="请输入执行用户"
              maxlength="15"
              type="text"
              clearable
              spellcheck="false"
              @clear="historyLinuxToolDataModel.execUser = ''"
            />
          </el-form-item>
          <el-form-item label="系统用户" prop="sysUser" style="margin-right: 10px; margin-bottom: 0">
            <el-select
              v-model="historyLinuxToolDataModel.sysUser"
              placeholder="请选择系统用户"
              clearable
              style="width: 120px"
              @clear="historyLinuxToolDataModel.sysUser = ''"
            >
              <el-option label="sysmonitor" value="sysmonitor" />
              <el-option label="root" value="root" />
            </el-select>
          </el-form-item>
          <el-form-item label="创建时间" prop="execTime" style="margin-right: 10px; margin-bottom: 0">
            <el-date-picker
              v-model="historyLinuxToolDataModel.execTime"
              type="daterange"
              start-placeholder="开始日期"
              end-placeholder="结束日期"
              value-format="YYYY-MM-DD HH:mm:ss"
              unlink-panels
              :default-time="defaultTime"
              style="width: 260px"
              @clear="historyLinuxToolDataModel.execTime = []"
            />
          </el-form-item>
          <el-form-item label="执行状态" prop="status" style="margin-right: 10px; margin-bottom: 0">
            <el-select
              v-model="historyLinuxToolDataModel.status"
              placeholder="请选择执行状态"
              clearable
              style="width: 120px"
              @clear="historyLinuxToolDataModel.status = ''"
            >
              <el-option label="成功" value="success" />
              <el-option label="失败" value="fail" />
            </el-select>
          </el-form-item>
          <el-form-item style="flex: none; margin-left: 4px; margin-right: 5px; margin-bottom: 0">
            <el-button type="primary" :icon="Search" circle @click="initHistoryTaskTable" size="default" />
          </el-form-item>
        </el-form>
      </div>
      <!-- 历史任务表格：数据超出可视高度时由el-scrollbar滚动 -->
      <el-scrollbar max-height="600px">
        <el-auto-resizer>
          <template #default="{ width }">
            <el-table-v2 :columns="getHistoryColumns(width)" :data="historyData" :width="width" :height="historyTableHeight" fixed />
          </template>
        </el-auto-resizer>
      </el-scrollbar>
    </div>
  </el-dialog>

  <!-- 身份确认子模态框：提交任务前确认操作用户身份 -->
  <el-dialog
    v-model="confirmDialogVisible"
    title="身份确认"
    width="420px"
    center
    destroy-on-close
    :show-close="true"
    append-to-body
    style="user-select: none"
    @close="handleConfirmCancel"
    :close-on-click-modal="false"
  >
    <el-form
      ref="confirmFormRef"
      :model="confirmForm"
      :rules="confirmFormRules"
      label-position="right"
      label-width="80px"
    >
      <el-form-item label="用户名" prop="username">
        <el-input
          v-model="confirmForm.username"
          placeholder="请输入用户名"
          maxlength="50"
          clearable
          spellcheck="false"
          style="width: 240px"
        />
      </el-form-item>
      <el-form-item label="密码" prop="password">
        <el-input
          v-model="confirmForm.password"
          type="password"
          placeholder="请输入密码"
          maxlength="100"
          show-password
          style="width: 240px"
        />
      </el-form-item>
    </el-form>
    <div style="display: flex; justify-content: center; gap: 10px; margin-top: 20px">
      <el-button type="primary" @click="handleConfirmSubmit">确定</el-button>
      <el-button type="primary" @click="handleConfirmCancel">取消</el-button>
    </div>
  </el-dialog>
</template>

<style scoped>
/* 可以在这里添加自定义样式 */
</style>
