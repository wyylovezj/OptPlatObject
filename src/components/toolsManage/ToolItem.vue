<script setup>
import { exportOrderFile, unlockAccountInterface } from '@/api/interface.js'
import { currentPage, messageInstance, user } from '@/utils/publicData.js'
import {
  cards,
  containsLabel, echoData,
  fileUploadDataModel,
  isAdmin,
  leafNodeCount,
  UnlockAccountDataModel,
  WorkOrderDataModel
} from '@/utils/publicDataTools.js'
import { CircleCheckFilled, CircleCloseFilled, UploadFilled } from '@element-plus/icons-vue'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { computed, ref,onBeforeUnmount,watch } from 'vue'
import * as XLSX from 'xlsx'

// 定义一个计算属性，判断是否有 el-card 需要显示
const hasVisibleCards = computed(() => {
  return cards.some((card) => containsLabel(card))
})
// 模态框可视状态
const dialogVisible = ref({
  OrderExporter: false, // 工单导出模态框可视状态
  unlockAccount: false, // 域账号解锁模态框可视状态
  ScriptDistribute: false, // 脚本下发模态框可视状态
  standardOutputVisible: false, // 脚本下发模态框内嵌标准输出模态框可视状态
})
const buttonVisible = ref({
  taskDetails: false,  //脚本下发后任务详情按钮显示状态
})
// 当前页码
const currentCardPage = ref(1)
// 页码切换
const pageChange = (page) => {
  currentCardPage.value = page
}
// 导出工单表单实例
const exporterForm = ref(null)
const responseData = ref({
  unlock: {
    message: '',
    status: '',
  },
})
// 解锁账号表单实例
const unlockAccountForm = ref(null)
// 按钮禁用
const exportDisabled = ref({
  exporterOrder: false, // 工单导出按钮禁用状态
  unlockAccount: false, // 域账号解锁按钮禁用状态
  createTask: false, // 脚本下发按钮禁用状态
})
// 进度条可视状态
const percentageVisible = ref({
  exporterOrder: true, // 工单导出进度条可视状态
})
// 进度条百分比
const percentageInfo = ref({
  percentage: 0,
  status: '',
})
// 限制开始时间 不能早于结束时间30天
const disabledStartDate = (time) => {
  if (WorkOrderDataModel.value.endTime) {
    const endTime = new Date(WorkOrderDataModel.value.endTime)
    const thirtyOneDaysBefore = new Date(endTime)
    thirtyOneDaysBefore.setDate(thirtyOneDaysBefore.getDate() - 30) // 结束时间往前推31天
    return time.getTime() < thirtyOneDaysBefore.getTime() || time.getTime() > endTime.getTime()
  }
  return false // 如果没有设置结束时间，则不禁用任何日期
}
// 限制结束时间 不能晚于开始时间30天
const disabledEndDate = (time) => {
  if (WorkOrderDataModel.value.startTime) {
    const startTime = new Date(WorkOrderDataModel.value.startTime)
    const thirtyOneDaysAfter = new Date(startTime)
    thirtyOneDaysAfter.setDate(thirtyOneDaysAfter.getDate() + 30) // 结束时间往前推31天
    return time.getTime() > thirtyOneDaysAfter.getTime() || time.getTime() < startTime.getTime()
  }
  return false // 如果没有设置结束时间，则不禁用任何日期
}
// 导出工单模态框中确定按钮点击事件
const exportWorkOrder = async () => {
  if (!exporterForm.value) return
  await exporterForm.value.validate(async (valid, fields) => {
    if (valid) {
      exportDisabled.value.exporterOrder = true
      dialogVisible.value.OrderExporter = false
      percentageVisible.value.exporterOrder = true
      percentageInfo.value.percentage = 0
      percentageInfo.value.status = ''
      try {
        const status = await exportOrderFile(WorkOrderDataModel.value, percentageInfo.value)
        if (status) {
          percentageInfo.value.status = ''
        } else {
          percentageInfo.value.status = 'failed'
        }
        exportDisabled.value.exporterOrder = false
      } catch (error) {
        console.error(error)
      }
    } else {
      console.log('error submit!', fields)
    }
  })
}
//   导出工单模态框中表单校验规则
const exporterOrderRules = ref({
  OrderType: [
    {
      required: true,
      message: '请选择工单类型',
      trigger: 'change',
    },
  ],
  startTime: [
    {
      type: 'date',
      required: true,
      message: '请选择开始时间',
      trigger: 'change',
    },
  ],
  endTime: [
    {
      type: 'date',
      required: true,
      message: '请选择结束时间',
      trigger: 'change',
    },
  ],
})

// 导出工单模态框中下拉框数据模型
const OrderTypeModel = [
  {
    value: '1',
    label: '事件工单',
  },
  {
    value: '2',
    label: '变更工单',
  },
  {
    value: '3',
    label: '发布工单',
  },
  {
    value: '4',
    label: '问题工单',
  },
  {
    value: '5',
    label: '变更工单（含资源、网络）',
  },
]
// 账号解锁模态框中表单校验规则
const unlockAccountRules = ref({
  type: [
    {
      required: true,
      message: '请选择解锁类型',
      trigger: 'change',
    },
  ],
  username: [
    {
      required: true,
      message: '请输入需要解锁的账号',
      trigger: 'change',
    },
  ],
})
// 用户解锁模态框中确定按钮点击事件
const unlockAccount = async () => {
  if (!unlockAccountForm.value) return
  await unlockAccountForm.value.validate(async (valid, fields) => {
    if (valid) {
      exportDisabled.value.unlockAccount = true
      dialogVisible.value.unlockAccount = false
      try {
        const status = await unlockAccountInterface(UnlockAccountDataModel.value)
        console.log(status)
        if (status) {
          exportDisabled.value.unlockAccount = false
          responseData.value.unlock.message = status.message
          responseData.value.unlock.status = status.status
        }
      } catch (error) {
        console.log(error.message)
        responseData.value.unlock.message = error.message
        responseData.value.unlock.status = 'fail'
        exportDisabled.value.unlockAccount = false
      }
    } else {
      console.log('error submit!', fields)
    }
  })
}
// 脚本下发模态框中确定按钮点击事件
const uploadFiles = async () => {
  console.log('uploadFiles', fileUploadDataModel.value.fileList)
  if (!fileUpload.value) return
  await fileUpload.value.validate(async (valid, fields) => {
    if (valid) {
      exportDisabled.value.createTask = true

      // dialogVisible.value.ScriptDistribute = false
      try {
        // 重置文件状态，确保可以重新上传
        if (uploadFile.value && fileUploadDataModel.value.fileList) {
          fileUploadDataModel.value.fileList.forEach(file => {
            file.status = 'ready'
            file.percentage = 0
          })
        }
        dialogVisible.value.standardOutputVisible = true
        uploadFile.value.submit()
        buttonVisible.value.taskDetails = true
        // console.log(status)
        // if (status) {
        //   exportDisabled.value.unlockAccount = false
        //   responseData.value.unlock.message = status.message
        //   responseData.value.unlock.status = status.status
        // }
      } catch (error) {
        console.log(error.message)
        // responseData.value.unlock.message = error.message
        // responseData.value.unlock.status = 'fail'
        // exportDisabled.value.unlockAccount = false
      }
    } else {
      console.log('error submit!', fields)
    }
  })
}
// 解锁账号模态框中下拉框数据模型
const unlockTypeModel = [
  {
    value: '1',
    label: '域账号解锁',
  },
  {
    value: '2',
    label: '邮箱账号解锁',
  },
]

// 主机名输入即时校验函数
const handleAccountInput = async (value) => {
  const cleanedValue = value.replace(/[^a-zA-Z0-9]/g, '')

  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入字母/数字`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }

  // 只允许输入英文字母和数字
  UnlockAccountDataModel.value.username = cleanedValue
}
// 脚本堡垒机用户输入即时校验函数
const bastionHostUser = async (value) => {
  const cleanedValue = value.replace(/[^a-zA-Z0-9]/g, '')
  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入字母/数字`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
  fileUploadDataModel.value.bastionHostUser = cleanedValue
}
// 脚本下发网络设备用户输入即时校验函数
const netWorkDeviceUser = async (value) => {
  const cleanedValue = value.replace(/[^a-zA-Z0-9]/g, '')
  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入字母/数字`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
  fileUploadDataModel.value.netWorkDeviceUser = cleanedValue
}
// 脚本下发堡垒机密码即时校验函数
const bastionHostPasswd = async (value) => {
  const cleanedValue = value.replace(/[^\w@#$%^&*()_+\-=\[\]{};:'",.<>/?\\|`~!]/g, '')
  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入字母/数字/特殊字符`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
  fileUploadDataModel.value.bastionHostPasswd = cleanedValue
}
// 脚本下发堡垒机密码即时校验函数
const netWorkDevicePasswd = async (value) => {
  const cleanedValue = value.replace(/[^\w@#$%^&*()_+\-=\[\]{};:'",.<>/?\\|`~!]/g, '')
  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入字母/数字/特殊字符`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
  fileUploadDataModel.value.netWorkDevicePasswd = cleanedValue
}
// 脚本下发表单实例
const fileUpload = ref(null)
// 脚本下发上传器实例
const uploadFile = ref(null)
// 脚本下发模态框中表单校验规则
const fileUploadRules = ref({
  bastionHostUser: [
    {
      required: true,
      message: '请输入堡垒机用户',
      trigger: 'change',
    },
  ],
  bastionHostPasswd: [
    {
      required: true,
      message: '请输入堡垒机密码',
      trigger: 'change',
    },
  ],
  netWorkDeviceUser: [
    {
      required: true,
      message: '请输入网络设备用户',
      trigger: 'change',
    },
  ],
  netWorkDevicePasswd: [
    {
      required: true,
      message: '请输入网络设备密码',
      trigger: 'change',
    },
  ],
  netWorkDeviceIP: [
    {
      required: true,
      message: '请输入网络设备IP',
      trigger: 'change',
    },
  ],
  fileList: [
    {
      required: true,
      message: '请上传脚本文件',
      trigger: 'change',
    },
    {
      validator: (rule, value, callback) => {
        // 检查是否为数组且不为空
        if (!Array.isArray(value) || value.length === 0) {
          callback(new Error('请至少上传一个文件'))
        } else {
          callback()
        }
      },
      trigger: 'change',
    },
  ],
})
// 导入
// 导入ip上传器实例
const inputFile = ref(null)
// 允许的文件扩展名
const ALLOWED_EXTENSIONS = ['.txt', '.xls', '.xlsx']
// 导入ip时接口中间变量
const netWorkDeviceIP = ref([])
// 从纯文本内容中提取 IP 地址
const extractIPsFromText = (content) => {
  // 按行分割
  const lines = content.split(/[\n\r]+/)
  const ips = []

  lines.forEach((line) => {
    const trimmedLine = line.trim()

    if (!trimmedLine) return

    // 支持多种分隔符：分号、逗号、制表符、多个空格
    const separators = /[;\t,]|\s{2,}/g

    if (separators.test(trimmedLine)) {
      const splitIPs = trimmedLine
        .split(separators)
        .map((ip) => ip.trim())
        .filter((ip) => ip)
      ips.push(...splitIPs)
    } else {
      ips.push(trimmedLine)
    }
  })

  // 验证 IP 地址格式
  const ipRegex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
  const validIPs = ips.filter((ip) => ipRegex.test(ip))

  // 去重
  const uniqueIPs = [...new Set(validIPs)]

  return uniqueIPs
}
// 从 TXT 文件中读取 IP 地址
const readIPsFromTXT = async (file) => {
  try {
    const content = await new Promise((resolve, reject) => {
      const reader = new FileReader()

      reader.onload = (event) => {
        resolve(event.target.result)
      }

      reader.onerror = () => {
        reject(new Error('文件读取失败'))
      }

      // 先尝试 UTF-8，如果失败会自动使用默认编码
      reader.readAsText(file.raw || file, 'UTF-8')
    })

    return extractIPsFromText(content)
  } catch (error) {
    console.error('读取 TXT 文件失败:', error)
    throw error
  }
}
// 从 Excel 文件（.xls/.xlsx）中读取 IP 地址
const readIPsFromExcel = async (file) => {
  try {
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

      reader.readAsArrayBuffer(file.raw || file)
    })

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

    // 扁平化数组并提取 IP 地址
    const allValues = jsonData.flat()
    const ipStrings = allValues.filter((val) => val !== null && val !== undefined && val !== '').map((val) => String(val).trim())

    // 使用文本提取逻辑处理
    const textContent = ipStrings.join('\n')
    return extractIPsFromText(textContent)
  } catch (error) {
    console.error('读取 Excel 文件失败:', error)
    throw error
  }
}
// 从文件中读取 IP 地址列表（仅支持 .txt/.xls/.xlsx）
const readIPsFromFile = async (file) => {
  const fileName = file.name.toLowerCase()

  // 根据文件扩展名选择读取方式
  if (fileName.endsWith('.txt')) {
    return await readIPsFromTXT(file)
  } else if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) {
    return await readIPsFromExcel(file)
  } else {
    throw new Error(`不支持的文件格式：${fileName.split('.').pop()}`)
  }
}
// 文件导入文件变化回调
const handleFileInputChange = async (file, fileList) => {
  // 如果没有文件，直接返回
  if (!file || !file.raw) {
    return
  }
  // 检查文件大小（不超过 10MB）
  const maxSize = 1024 * 1024 * 1
  if ((file.raw.size || file.size) > maxSize) {
    ElMessage.error('文件大小不能超过 10MB')
    inputFile.value?.clearFiles()
    return
  }
  // 严格检查文件扩展名
  const fileName = file.name.toLowerCase()
  const fileExtension = '.' + fileName.split('.').pop()

  if (!ALLOWED_EXTENSIONS.includes(fileExtension)) {
    ElMessage.error({
      message: `不支持 ${fileExtension.toUpperCase()} 格式，仅支持 TXT、XLS、XLSX 格式`,
      type: 'error',
      duration: 3000,
    })
    inputFile.value?.clearFiles()
    return
  }
  try {
    // 读取文件内容
    const ipList = await readIPsFromFile(file)
    if (ipList.length === 0) {
      ElMessage.warning('文件中未找到有效的 IP 地址')
      // 清空文件列表
      inputFile.value?.clearFiles()
      return
    }

    // 将 IP 列表转换为以分号分隔的字符串
    // 更新输入框的值
    fileUploadDataModel.value.netWorkDeviceIP = ipList.join('; ')
    console.log(fileUploadDataModel.value.netWorkDeviceIP)
    // 显示成功提示
    ElMessage.success({
      message: `已导入 ${ipList.length} 个 IP 地址`,
      type: 'success',
      duration: 2000,
    })

    console.log(`从文件 "${file.name}" 中导入的 IP:`, ipList)

    // 清空文件列表（因为只需要触发读取，不需要保留文件）
    inputFile.value?.clearFiles()
  } catch (error) {
    console.error('读取文件失败:', error)
    ElMessage.error({
      message: '读取文件失败，请确保文件格式正确',
      type: 'error',
      duration: 2000,
    })
    // 清空文件列表
    inputFile.value?.clearFiles()
  }
}

// 文件导入超出限制回调
const handleExceedInput = async (files, fileList) => {
  // 清空之前的文件列表
  inputFile.value?.clearFiles()
  // 获取第一个新选择的文件（忽略其他文件）
  const file = files[0]
  // 手动触发文件变化处理
  await handleFileInputChange(file, [])
  // file.uid = genFileId()
  // inputFile.value?.handleStart(file)
  // ElMessage.warning(`只能上传 1 个文件，当前选择了 ${files.length} 个文件`)
}

// 上传
// 上传地址
const uploadUrl = 'http://127.0.0.1:8000/api/upload'
// const fileList = ref([])
// 记录上传结果
const uploadResults = ref({
  success: [],
  failed: [],
})

// 上传进度和状态
const uploadProgress = ref(0)
const uploadStatus = ref('') // success, exception, warning
// 使用 Map 存储多个定时器，key 为 taskId，value 为定时器 ID
const progressTimers = new Map()

// 打字机效果相关状态
const typewriterLines = ref([])
const currentLineIndex = ref(0)
const currentCharIndex = ref(0)
const isTyping = ref(false)
const typewriterSpeed = 20 // 打字速度 (毫秒/字符)
const lineDelay = 50 // 行间距延迟 (毫秒)
let typewriterTimer = null
let allTypewriterLines = [] // 缓存所有需要显示的行
let hasStartedTyping = false // 标记是否已经开始打字

// 生成需要显示的所有行（包含所有回显内容，带分组信息）
const generateTypewriterContent = (echoDataParam) => {
  const lines = []

  if (!echoDataParam || echoDataParam.length === 0) {
    return lines
  }

  // 任务详情部分
  if (echoDataParam.length >= 1 && echoDataParam[0]) {
    if (echoDataParam[0].taskId) {
      lines.push({ group: 'task', type: 'info', text: `任务 ID：${echoDataParam[0].taskId}` })
    }
    if (echoDataParam[0].createTaskTime) {
      lines.push({ group: 'task', type: 'info', text: `创建时间：${echoDataParam[0].createTaskTime}` })
    }
    if (echoDataParam[0].fileName) {
      lines.push({ group: 'task', type: 'info', text: `文件名：${echoDataParam[0].fileName}` })
    }
    if (echoDataParam[0].netWorkDeviceIP?.length >= 1) {
      lines.push({ group: 'task', type: 'info', text: `网络设备 IP：` })
      echoDataParam[0].netWorkDeviceIP.forEach((ip) => {
        lines.push({ group: 'task', type: 'command', text: `  ${ip}` })
      })
    }
  }

  // 文件上传部分
  if (echoDataParam.length >= 2 && echoDataParam[1]) {
    if (echoDataParam[1].fileName) {
      lines.push({ group: 'upload', type: 'info', text: `文件名：${echoDataParam[1].fileName}` })
    }
    if (echoDataParam[1].progress) {
      lines.push({ group: 'upload', type: 'status', text: `上传结果：${echoDataParam[1].progress}` })
    }
  }

  // 登录堡垒机部分
  if (echoDataParam.length >= 3 && echoDataParam[2]) {
    if (echoDataParam[2].bastionHostUser) {
      lines.push({ group: 'login', type: 'info', text: `堡垒机用户：${echoDataParam[2].bastionHostUser}` })
    }
    if (echoDataParam[2].progress) {
      lines.push({ group: 'login', type: 'status', text: `登录结果：${echoDataParam[2].progress}` })
    }
  }

  // 脚本下发执行部分
  if (echoDataParam.length >= 4 && echoDataParam[3]) {
    if (echoDataParam[3].fileName) {
      lines.push({ group: 'execute', type: 'info', text: `脚本文件：${echoDataParam[3].fileName}` })
    }

    if (echoDataParam[3].progress?.length >= 1) {
      echoDataParam[3].progress.forEach((item) => {
        if (item.netWorkDeviceIP) {
          lines.push({ group: 'execute', type: 'info', text: `$ 网络设备 IP: ${item.netWorkDeviceIP}` })
        }

        if (item.progress?.length >= 1 && item.progress) {
          item.progress.forEach((itemCmd) => {
            if (itemCmd.command) {
              lines.push({ group: 'execute', type: 'command', text: `${itemCmd.command}` })
            }
            if (itemCmd.result) {
              lines.push({ group: 'execute', type: 'result', text: `  ${itemCmd.result}` })
            }
          })
        }

        if (item.status) {
          lines.push({ group: 'execute', type: 'status', text: `执行结果：${item.status}` })
        }
      })
    }
  }

  // 任务执行结果部分
  if (echoDataParam.length >= 5 && echoDataParam[4]) {
    if (echoDataParam[4].status?.success?.length >= 1) {
      lines.push({ group: 'result', type: 'info', text: `执行成功：` })
      echoDataParam[4].status.success.forEach((item) => {
        lines.push({ group: 'result', type: 'result', text: `  ${item}` })
      })
    }
    if (echoDataParam[4].status?.fail?.length >= 1) {
      lines.push({ group: 'result', type: 'info', text: `执行失败：` })
      echoDataParam[4].status.fail.forEach((item) => {
        lines.push({ group: 'result', type: 'result', text: `  ${item}` })
      })
    }
  }

  return lines
}

// 打字机效果启动函数
const startTypewriter = (echoDataParam) => {
  if (isTyping.value || hasStartedTyping) return

  // 只在开始时生成一次内容
  allTypewriterLines = generateTypewriterContent(echoDataParam)
  if (allTypewriterLines.length === 0) return

  typewriterLines.value = []
  currentLineIndex.value = 0
  currentCharIndex.value = 0
  isTyping.value = true
  hasStartedTyping = true

  typeNextCharacter()
}

// 逐字打印
const typeNextCharacter = () => {
  if (currentLineIndex.value >= allTypewriterLines.length) {
    isTyping.value = false
    return
  }

  const currentLine = allTypewriterLines[currentLineIndex.value]

  if (currentCharIndex.value <= currentLine.text.length) {
    // 确保当前行存在
    if (!typewriterLines.value[currentLineIndex.value]) {
      typewriterLines.value[currentLineIndex.value] = {
        group: currentLine.group,
        type: currentLine.type,
        text: ''
      }
    }

    // 添加下一个字符（如果还有字符）
    if (currentCharIndex.value < currentLine.text.length) {
      typewriterLines.value[currentLineIndex.value].text += currentLine.text[currentCharIndex.value]
      currentCharIndex.value++

      typewriterTimer = setTimeout(() => {
        typeNextCharacter()
      }, typewriterSpeed)
    } else {
      // 当前行完成，换下一行
      currentLineIndex.value++
      currentCharIndex.value = 0

      if (currentLineIndex.value < allTypewriterLines.length) {
        typewriterTimer = setTimeout(() => {
          typeNextCharacter()
        }, lineDelay)
      } else {
        isTyping.value = false
      }
    }
  }
}

// 停止打字机效果
const stopTypewriter = () => {
  if (typewriterTimer) {
    clearTimeout(typewriterTimer)
    typewriterTimer = null
  }
  isTyping.value = false
}

// 重置打字机状态
// const resetTypewriter = () => {
//   stopTypewriter()
//   typewriterLines.value = []
//   currentLineIndex.value = 0
//   currentCharIndex.value = 0
//   allTypewriterLines = []
//   hasStartedTyping = false
// }

// 监听 echoData 变化，自动启动打字机效果
watch(
  () => echoData.value,
  (newEchoData) => {
    if (newEchoData && newEchoData.length > 0 && !hasStartedTyping) {
      setTimeout(() => {
        startTypewriter(newEchoData)
      }, 300)
    }
  },
  { deep: true }
)

// 文件上传前的校验
const beforeUpload = (file) => {
  if (!file) return false

  // 检查文件扩展名
  const fileName = file.name.toLowerCase()
  const fileExtension = '.' + fileName.split('.').pop()

  if (fileExtension !== '.txt') {
    ElMessage.error({
      message: `只能上传 TXT 格式的文件，当前选择的是 ${fileExtension.toUpperCase()} 格式`,
      type: 'error',
      duration: 3000,
    })
    return false
  }

  // 检查文件大小 (10MB)
  const isLt10M = file.size / 1024 / 1024 < 10
  if (!isLt10M) {
    ElMessage.error('文件大小不能超过 10MB!')
    return false
  }

  return true
}
// 文件列表变化处理
const handleFileChange = (file, fileList) => {
  console.log('文件列表变化:', fileList)
  const isValid = beforeUpload(file.raw)
  if (!isValid) {
    // 如果文件验证失败，清空文件列表
    uploadFile.value?.clearFiles()
    fileUploadDataModel.value.fileList = []
    return
  }
  // 同步更新数据模型中的文件列表
  fileUploadDataModel.value.fileList = fileList
}

// 上传成功回调
const handleSuccess = (res, file, fileList) => {
  console.log('完整参数:', res, file, fileList) // 添加这行日志
  uploadProgress.value = 100
  uploadStatus.value = 'success'
  // 记录成功的文件
  uploadResults.value.success.push({
    name: file.name,
    size: file.size,
    result: res,
  })
  console.log('上传成功:', res)
}

// 上传失败回调
const handleError = (error, file, fileList) => {
  uploadStatus.value = 'exception'
  // 记录失败的文件
  uploadResults.value.failed.push({
    name: file.name,
    size: file.size,
    error: error.message,
  })
  console.error('上传失败:', error)
}
// 脚本上传超出限制回调
const handleExceed = (files, fileList) => {
  // 清空之前的文件列表
  uploadFile.value?.clearFiles()
  // 获取第一个新选择的文件（忽略其他文件）
  const file = files[0]
  // file.uid = genFileId()
  uploadFile.value?.handleStart(file)
  // ElMessage.warning(`只能上传 1 个文件，当前选择了 ${files.length} 个文件`)
}

// 如果需要更复杂的文件处理，可以使用自定义上传
const customUpload = async (options) => {
  const { file, onProgress } = options
  // 任务 uuid，用于标识上传任务
  const taskId = crypto.randomUUID()
  console.log('uuid:', taskId)
  // 如果用户在输入框中手动修改了 IP，需要重新解析
  if (fileUploadDataModel.value.netWorkDeviceIP) {
    // 使用分隔符分割字符串：分号、逗号、制表符、空格、换行
    const separators = /[;\t,\n\r]|\s{1,}/g
    const ipArray = fileUploadDataModel.value.netWorkDeviceIP
      .split(separators)
      .map((ip) => ip.trim())
      .filter((ip) => ip)

    // 验证并过滤有效的 IP 地址
    const ipRegex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
    const validIPs = ipArray.filter((ip) => ipRegex.test(ip))

    // 去重
    netWorkDeviceIP.value = [...new Set(validIPs)]
    console.log('netWorkDeviceIP', netWorkDeviceIP.value)
  }
  // 清理之前可能存在的同任务定时器
  if (progressTimers.has(taskId)) {
    clearInterval(progressTimers.get(taskId))
    progressTimers.delete(taskId)
  }
  // 格式化时间为 YYYY-MM-DD HH:mm 格式
  const formatDateTime = (date) => {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')

    return `${year}-${month}-${day} ${hours}:${minutes}`
  }
  const timeStamp = new Date()
  fileUploadDataModel.value.createTaskTime = formatDateTime(timeStamp)
  // 创建FormData
  const form = new FormData()
  form.append('file', file)
  form.append('taskId', taskId)
  form.append('bastionHostUser', fileUploadDataModel.value.bastionHostUser)
  form.append('bastionHostPasswd', fileUploadDataModel.value.bastionHostPasswd)
  form.append('netWorkDeviceIP', JSON.stringify(netWorkDeviceIP.value))
  form.append('netWorkDeviceUser', fileUploadDataModel.value.netWorkDeviceUser)
  form.append('netWorkDevicePasswd', fileUploadDataModel.value.netWorkDevicePasswd)
  form.append('createTaskTime', fileUploadDataModel.value.createTaskTime)
  console.log('form',form.get('netWorkDeviceIP'))
  try {
    const response = await axios.post(uploadUrl, form, {
      headers: {
        'Content-Type': 'multipart/form-data',
        'X-Requested-With': 'XMLHttpRequest',
      },
      onUploadProgress: (progressEvent) => {
        if (progressEvent.lengthComputable) {
          const percent = (progressEvent.loaded / progressEvent.total) * 100
          onProgress({ percent })
          console.log(`上传进度：${percent}%`)
        }
      },
    })
    if (response.status === 200) {
      // 直接在这里调用 handleSuccess，而不是通过 onSuccess
      handleSuccess(response.data, file, fileUploadDataModel.value.fileList)
      const progressTimer = setInterval(async () => {
        try {
          const response = await axios.post('http://127.0.0.1:8000/api/uploadPregress', {
            taskId: taskId,
          });
          console.log('上传进度：', response.data);
          echoData.value = response.data.data;
        } catch (error) {
          console.error('Error clearing progress timer:', error)
        }
      },1000)
      // 保存定时器到 Map
      progressTimers.set(taskId, progressTimer)
      console.log('上传成功', response.data)
    } else {
      handleError(new Error(response.data.error || '上传失败'), file)
    }
  } catch (error) {
    handleError(new Error(error || '上传失败'), file)
  }
}
// 组件卸载时清理所有定时器
onBeforeUnmount(() => {
  progressTimers.forEach((timer, taskId) => {
    clearInterval(timer)
    console.log(`清理任务 ${taskId} 的定时器`)
  })
  progressTimers.clear()
  stopTypewriter()
})
</script>

<template>
  <div class="toolsItem">
    <div class="content-wrapper">
      <div class="card-container" v-if="hasVisibleCards">
        <!--    工单导出卡片    -->
        <el-card v-if="containsLabel('工单导出')" shadow="hover" body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;">
          <!-- 卡片主体内容 -->
          <div class="card-content">
            <!-- 上部分：2:1 比例 -->
            <div class="top-section">
              <!-- 左侧：1:2 比例 -->
              <div class="left-part">
                <div class="circle-image">
                  <!-- 圆形框内显示 SVG 图片 -->
                  <svg class="icon" aria-hidden="true">
                    <use xlink:href="#icon-xiazaiwenjian_24"></use>
                  </svg>
                </div>
              </div>
              <!-- 右侧：1:2 比例 -->
              <div class="right-part">
                <p>工单导出</p>
              </div>
            </div>
            <!-- 下部分：按钮 -->
            <div class="bottom-section">
              <div v-if="percentageVisible.exporterOrder" class="demo-progress" style="flex: 3; width: 100%">
                <el-progress
                  :text-inside="true"
                  :stroke-width="20"
                  :percentage="percentageInfo.percentage"
                  striped
                  status="success"
                  :striped-flow="percentageInfo.percentage > 0 && percentageInfo.percentage < 100"
                >
                  <span
                    v-if="exportDisabled.exporterOrder && percentageInfo.percentage === 0 && percentageInfo.status === ''"
                    style="color: #ffd04b; font-weight: bold"
                    >正在创建导出任务...</span
                  >
                  <span v-else-if="percentageInfo.percentage === 0 && percentageInfo.status === ''" style="color: #6cbc45; font-weight: bold"
                    >导出功能已就绪！</span
                  >
                  <span v-else-if="percentageInfo.percentage === 100 && percentageInfo.status === ''" style="color: #ffffff; font-weight: bold"
                    >导出已完成！</span
                  >
                  <span v-else-if="percentageInfo.status === 'failed'" style="color: #d32323; font-weight: bold">导出失败，服务异常！</span>
                </el-progress>
              </div>
              <div style="flex: 1; display: flex; justify-content: flex-end">
                <el-button
                  type="primary"
                  :disabled="exportDisabled.exporterOrder"
                  @click="
                    dialogVisible.OrderExporter = true;
                    percentageInfo.percentage = 0;
                  "
                >
                  导出
                </el-button>
              </div>
            </div>
          </div>
        </el-card>
        <!--    账号解锁卡片    -->
        <el-card
          v-if="containsLabel('账号解锁') && isAdmin(user)"
          shadow="hover"
          body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;"
        >
          <!-- 卡片主体内容 -->
          <div class="card-content">
            <!-- 上部分：2:1 比例 -->
            <div class="top-section">
              <!-- 左侧：1:2 比例 -->
              <div class="left-part">
                <div class="circle-image">
                  <!-- 圆形框内显示 SVG 图片 -->
                  <svg class="icon" aria-hidden="true">
                    <use xlink:href="#icon-zhanghaojiesuo"></use>
                  </svg>
                </div>
              </div>
              <!-- 右侧：1:2 比例 -->
              <div class="right-part">
                <p>账号解锁</p>
              </div>
            </div>
            <!-- 下部分：按钮 -->
            <div class="bottom-section">
              <div :class="responseData.unlock.status" style="flex: 3; width: 100%; font-size: 15px; text-align: center; margin-top: 5px">
                <span style="vertical-align: middle; margin-right: 3px">{{ responseData.unlock.message }}</span>
                <el-icon v-if="responseData.unlock.status === 'success'" :size="17" style="vertical-align: middle"><CircleCheckFilled /></el-icon>
                <el-icon v-if="responseData.unlock.status === 'fail'" :size="17" style="vertical-align: middle"><CircleCloseFilled /></el-icon>
              </div>
              <div style="flex: 1; display: flex; justify-content: flex-end">
                <el-button type="primary" :disabled="exportDisabled.unlockAccount" @click="dialogVisible.unlockAccount = true"> 解锁 </el-button>
              </div>
            </div>
          </div>
        </el-card>
        <!--    脚本下发卡片    -->
        <el-card v-if="containsLabel('脚本下发')" shadow="hover" body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;">
          <!-- 卡片主体内容 -->
          <div class="card-content">
            <!-- 上部分：2:1 比例 -->
            <div class="top-section">
              <!-- 左侧：1:2 比例 -->
              <div class="left-part">
                <div class="circle-image">
                  <!-- 圆形框内显示 SVG 图片 -->
                  <svg class="icon" aria-hidden="true">
                    <use xlink:href="#icon-Python"></use>
                  </svg>
                </div>
              </div>
              <!-- 右侧：1:2 比例 -->
              <div class="right-part">
                <p>脚本下发</p>
              </div>
            </div>
            <!-- 下部分：按钮 -->
            <div class="bottom-section">
              <div style="flex: 1; display: flex; justify-content: flex-end">
                <el-button type="primary" :disabled="exportDisabled.ScriptDistribute" @click="dialogVisible.ScriptDistribute = true">
                  创建任务
                </el-button>
              </div>
            </div>
          </div>
        </el-card>
      </div>
      <el-empty v-if="!hasVisibleCards" description="无匹配数据" style="width: 100%; height: 95%" />
      <!-- 分页：显示总数、页码导航 -->
      <div class="pagination-section">
        <!--  显示总数  -->
        <div class="total-count">
          <span style="line-height: 20px">共 {{ leafNodeCount }} 个</span>
        </div>
        <div class="pagination-nav">
          <!--  页码导航  -->
          <el-pagination
            background
            v-model:current-page="currentPage"
            page-size="16"
            :total="leafNodeCount"
            layout="prev, pager, next"
            @current-change="pageChange"
          />
        </div>
      </div>
    </div>
    <!--  工单导出模态框  -->
    <el-dialog
      v-model="dialogVisible.OrderExporter"
      top="10%"
      title="工单导出"
      width="20%"
      center
      :show-close="false"
      @close="
        () => {
          WorkOrderDataModel.OrderType = ''
          WorkOrderDataModel.startTime = ''
          WorkOrderDataModel.endTime = ''
          dialogVisible.OrderExporter = false
        }
      "
    >
      <el-form
        :model="WorkOrderDataModel"
        ref="exporterForm"
        label-position="right"
        label-width="auto"
        :rules="exporterOrderRules"
        style="display: flex; flex-direction: column; justify-content: center; flex-wrap: wrap; user-select: none"
      >
        <el-form-item label="工单类型" prop="OrderType">
          <el-select
            v-model="WorkOrderDataModel.OrderType"
            class="center-placeholder"
            clearable
            placeholder="请选择"
            style="width: 250px"
            @clear="WorkOrderDataModel.OrderType = ''"
          >
            <el-option v-for="item in OrderTypeModel" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="开始时间" prop="startTime">
          <el-date-picker
            v-model="WorkOrderDataModel.startTime"
            type="date"
            placeholder="开始时间"
            format="YYYY/MM/DD"
            value-format="YYYY-MM-DD"
            style="width: 250px"
            :disabled-date="disabledStartDate"
          />
        </el-form-item>
        <el-form-item label="结束时间" prop="endTime">
          <el-date-picker
            v-model="WorkOrderDataModel.endTime"
            type="date"
            style="width: 250px"
            format="YYYY/MM/DD"
            value-format="YYYY-MM-DD"
            placeholder="结束时间"
            :disabled-date="disabledEndDate"
          />
        </el-form-item>
        <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: nowrap">
          <el-button type="primary" @click="exportWorkOrder">确认</el-button>
          <el-button
            type="primary"
            @click="
              dialogVisible.OrderExporter = false
              // 清空数据模型
            "
            >取消</el-button
          >
        </div>
      </el-form>
    </el-dialog>
    <!--  账号解锁模态框  -->
    <el-dialog
      v-model="dialogVisible.unlockAccount"
      top="10%"
      title="账号解锁"
      width="20%"
      center
      :show-close="false"
      @close="
        () => {
          UnlockAccountDataModel.type = ''
          UnlockAccountDataModel.username = ''
          dialogVisible.unlockAccount = false
        }
      "
    >
      <el-form
        :model="UnlockAccountDataModel"
        ref="unlockAccountForm"
        label-position="right"
        label-width="auto"
        :rules="unlockAccountRules"
        style="display: flex; flex-direction: column; justify-content: center; flex-wrap: wrap; user-select: none"
      >
        <el-form-item label="解锁类型" prop="type">
          <el-select
            v-model="UnlockAccountDataModel.type"
            class="center-placeholder"
            clearable
            placeholder="请选择"
            style="width: 250px"
            @clear="UnlockAccountDataModel.type = ''"
          >
            <el-option v-for="item in unlockTypeModel" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="解锁账号" prop="username">
          <el-input
            v-model="UnlockAccountDataModel.username"
            style="width: 250px"
            placeholder="请输入账号"
            maxlength="15"
            type="text"
            @input="handleAccountInput"
            clearable
          />
        </el-form-item>
        <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: nowrap">
          <el-button type="primary" @click="unlockAccount">确认</el-button>
          <el-button
            type="primary"
            @click="
              dialogVisible.unlockAccount = false
              // 清空数据模型
            "
            >取消</el-button
          >
        </div>
      </el-form>
    </el-dialog>
    <!--  脚本下发模态框  -->
    <el-dialog
      v-model="dialogVisible.ScriptDistribute"
      title="脚本下发"
      width="45%"
      center
      :show-close="false"
      :close-on-click-modal="false"
      @close="
        () => {
          dialogVisible.ScriptDistribute = false
          // fileUploadDataModel.reset()
        }
      "
    >
      <el-form :model="fileUploadDataModel" ref="fileUpload" :inline="true" label-position="right" label-width="auto" :rules="fileUploadRules">
        <el-form-item label="堡垒机用户" prop="bastionHostUser">
          <el-input
            v-model="fileUploadDataModel.bastionHostUser"
            style="width: 250px"
            placeholder="请输入堡垒机用户"
            maxlength="15"
            type="text"
            @input="bastionHostUser"
            clearable
          />
        </el-form-item>
        <el-form-item label="堡垒机密码" prop="bastionHostPasswd">
          <el-input
            v-model="fileUploadDataModel.bastionHostPasswd"
            style="width: 250px"
            placeholder="请输入堡垒机密码"
            maxlength="15"
            type="text"
            @input="bastionHostPasswd"
            clearable
          />
        </el-form-item>
        <el-form-item label="网络设备用户" prop="netWorkDeviceUser">
          <el-input
            v-model="fileUploadDataModel.netWorkDeviceUser"
            style="width: 250px"
            placeholder="请输入网络设备用户"
            maxlength="15"
            type="text"
            @input="netWorkDeviceUser"
            clearable
          />
        </el-form-item>
        <el-form-item label="网络设备密码" prop="netWorkDevicePasswd">
          <el-input
            v-model="fileUploadDataModel.netWorkDevicePasswd"
            style="width: 250px"
            placeholder="请输入网络设备用户"
            maxlength="15"
            type="text"
            @input="netWorkDevicePasswd"
            clearable
          />
        </el-form-item>
        <el-form-item label="网络设备IP" prop="netWorkDeviceIP">
          <el-input
            v-model="fileUploadDataModel.netWorkDeviceIP"
            style="width: 300px"
            placeholder="请输入网络设备IP，支持分隔符：分号、逗号、空格、换行"
            :rows="6"
            type="textarea"
            clearable
            resize="none"
          />
          <el-upload
            ref="inputFile"
            accept=".txt,.xls,.xlsx"
            class="upload-demo-input"
            :auto-upload="false"
            :limit="1"
            :on-exceed="handleExceedInput"
            :on-change="handleFileInputChange"
          >
            <template #trigger>
              <el-button type="primary">从文件导入</el-button>
            </template>
            <template #tip>
              <div class="el-upload__tip">支持导入 txt/xls/xlsx 文件，且不超过 1MB</div>
            </template>
          </el-upload>
        </el-form-item>
        <el-form-item label="脚本文件" prop="fileList">
          <el-upload
            class="upload-demo"
            ref="uploadFile"
            drag
            accept=".txt"
            :limit="1"
            :on-exceed="handleExceed"
            :file-list="fileUploadDataModel.fileList"
            :http-request="customUpload"
            :auto-upload="false"
            :on-change="handleFileChange"
          >
            <el-icon class="el-icon--upload"><upload-filled /></el-icon>
            <div class="el-upload__text">拖拽文件到此处或 <em>点击上传</em></div>
            <template #tip>
              <div class="el-upload__tip">支持上传 txt 文件，且不超过 10MB</div>
            </template>
          </el-upload>
          <!-- 显示上传进度 -->
          <!--          <div v-if="uploadProgress > 0" class="progress-container">
            <el-progress :percentage="uploadProgress" :status="uploadStatus" />
            <span>{{ uploadProgress }}%</span>
          </div>-->
        </el-form-item>
        <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: nowrap">
          <el-button type="primary" @click="uploadFiles">确认</el-button>
          <el-button
            type="primary"
            @click="
              dialogVisible.ScriptDistribute = false
              // 清空数据模型
            "
            >取消</el-button
          >
          <el-button v-if="buttonVisible.taskDetails" type="info" @click="dialogVisible.standardOutputVisible = true"  style="position: absolute; right: 40px;">任务详情</el-button>
        </div>
      </el-form>
      <!--   回显模态框   -->
      <el-dialog
        v-model="dialogVisible.standardOutputVisible"
        top="50px"
        width="600px"
        title="任务详情"
        center
        append-to-body
      >
<!--        <el-scrollbar height="730px">-->
<!--          <el-timeline style="width: 500px">-->
<!--            <el-timeline-item timestamp="任务详情" placement="top">-->
<!--              <el-card>-->
<!--                <p v-if="echoData.length >= 1 && echoData[0]?.taskId">任务ID：{{ echoData[0].taskId }}</p>-->
<!--                <p v-if="echoData.length >= 1 && echoData[0]?.createTaskTime">创建时间：{{ echoData[0].createTaskTime }}</p>-->
<!--                <p v-if="echoData.length >= 1 && echoData[0]?.fileName">文件名：{{ echoData[0].fileName }}</p>-->
<!--                <p v-if="echoData.length >= 1 && echoData[0]?.netWorkDeviceIP?.length >= 1">网络设备IP：</p>-->
<!--                <ul v-if="echoData.length >= 1 && echoData[0]?.netWorkDeviceIP?.length >= 1" style="list-style-type: none;">-->
<!--                  <li v-for="(item) in echoData[0]?.netWorkDeviceIP" :key="item">{{ item }}</li>-->
<!--                </ul>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
<!--            <el-timeline-item timestamp="文件上传" placement="top">-->
<!--              <el-card>-->
<!--                <p v-if="echoData.length >= 2 && echoData[1]?.fileName">文件名：{{ echoData[1].fileName }}</p>-->
<!--                <p v-if="echoData.length >= 2 && echoData[1]?.progress">上传结果：{{ echoData[1].progress }}</p>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
<!--            <el-timeline-item timestamp="登录堡垒机" placement="top">-->
<!--              <el-card>-->
<!--                <p v-if="echoData.length >= 3 && echoData[2]?.bastionHostUser">堡垒机用户：{{ echoData[2].bastionHostUser}}</p>-->
<!--                <p v-if="echoData.length >= 3 && echoData[2]?.progress">登录结果：{{ echoData[2].progress}}</p>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
<!--            <el-timeline-item timestamp="脚本下发执行" placement="top">-->
<!--              <el-card>-->
<!--                <p v-if="echoData.length >= 3 && echoData[3]?.fileName">脚本文件：{{ echoData[3].fileName }}</p>-->
<!--                <template v-if="echoData.length >= 3 && echoData[3]?.progress?.length >= 1">-->
<!--                  <div class="shell-console">-->
<!--                    <div v-for="(line, index) in typewriterLines" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.length - 1 }">-->
<!--                      <p v-if="line.type === 'info'" class="shell-info">-->
<!--                        {{ line.text }}-->
<!--                      </p>-->
<!--                      <p v-else-if="line.type === 'command'" class="shell-command">-->
<!--                        {{ line.text }}-->
<!--                      </p>-->
<!--                      <p v-else-if="line.type === 'result'" class="shell-result">-->
<!--                        {{ line.text }}-->
<!--                      </p>-->
<!--                      <p v-else-if="line.type === 'status'" class="shell-status">-->
<!--                        {{ line.text }}-->
<!--                      </p>-->
<!--                    </div>-->
<!--                  </div>-->
<!--                </template>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
<!--            <el-timeline-item timestamp="任务执行结果" placement="top">-->
<!--              <el-card>-->
<!--                <p v-if="echoData.length >= 4 && echoData[4]?.status?.success.length >= 1">执行成功：</p>-->
<!--                <ul v-if="echoData.length >= 4 && echoData[4]?.status?.success.length >= 1" style="list-style-type: none;">-->
<!--                  <li v-for="item in echoData[4]?.status?.success" :key="item">{{ item }}</li>-->
<!--                </ul>-->
<!--                <p v-if="echoData.length >= 4 && echoData[4]?.status?.fail?.length >= 1">执行失败：</p>-->
<!--                <ul v-if="echoData.length >= 4 && echoData[4]?.status?.fail.length >= 1" style="list-style-type: none;">-->
<!--                  <li v-for="item in echoData[4]?.status?.fail" :key="item">{{ item }}</li>-->
<!--                </ul>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
<!--          </el-timeline>-->
<!--        </el-scrollbar>-->
        <el-scrollbar height="730px">
          <el-timeline style="width: 500px">
            <el-timeline-item timestamp="任务详情" placement="top">
              <el-card>
                <div class="shell-console">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'task')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'task').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="文件上传" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'upload')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'upload')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'upload').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="登录堡垒机" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'login')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'login')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'login').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="脚本下发执行" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'execute')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'execute')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'execute').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="任务执行结果" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'result')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'result')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'result').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-scrollbar>
      </el-dialog>
    </el-dialog>
  </div>
</template>

<style scoped>
.toolsItem {
  flex: 1;
  display: flex;
  gap: 15px;
  align-items: stretch;
  user-select: none;
  border: #dcdfe6 solid 1px;
  padding: 15px 30px;
  background-color: #ffffff;
  border-radius: 10px;
  box-sizing: border-box;
  min-height: 0; /* 允许正确收缩 */
}
.content-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 15px;
  min-height: 0; /* 允许 flex 子项正确收缩 */
}
.card-container {
  display: grid;
  grid-template-columns: repeat(4, 1fr); /* 4 列，每列等宽 */
  grid-template-rows: repeat(4, 1fr); /* 4 行 */
  gap: 15px; /* 行列间距 */
  height: 95%;
}
.pagination-section {
  flex: 0 0 auto; /* 不放大，不缩小，自适应高度 */
  display: flex;
  justify-content: space-between;
  align-items: center;
  user-select: none;
  padding: 10px 0;
  box-sizing: border-box;
  min-height: 40px; /* 设置最小高度防止过度压缩 */
}
.total-count {
  display: flex;
  align-items: center;
  font-size: 15px;
}
.pagination-nav {
  display: flex;
  align-items: center;
}
.el-card {
  width: 100%;
  border: 1.5px solid #dcdfe6;
  min-height: 0;
}

/* 整体卡片内容容器 */
.card-content {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
}

/* 上部分：占据 2/3 高度 */
.top-section {
  flex: 2;
  display: flex;
  gap: 10px; /* 左右间距 */
}

/* 左侧部分：占据 1/3 宽度 */
.left-part {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
}

/* 圆形框样式 */
.circle-image {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid #ccc;
  display: flex;
  justify-content: center;
  align-items: center;
}

.circle-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 右侧部分：占据 2/3 宽度 */
.right-part {
  flex: 2;
  display: flex;
  align-items: center;
}

.right-part p {
  margin: 0;
  font-size: 16px;
  color: #333;
  align-items: center;
}

/* 下部分：占据 1/3 高度 */
.bottom-section {
  flex: 1;
  display: flex;
  justify-content: center;
}
.icon {
  width: 35px;
  height: 35px;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
.demo-progress .el-progress--line {
  margin-top: 5px;
  max-width: 90%;
}
.el-progress__text {
  min-width: auto;
}
.success {
  color: #88cf64;
}
.fail {
  color: #f56c6c;
}
/*上传*/
.upload-demo {
  width: 500px;
  height: 300px;
}
.upload-demo-input {
  width: 300px;
  height: 100%;
  margin-left: 10px;
}
.progress-container {
  margin-top: 20px;
  width: 360px;
}

.ml-3 {
  margin-left: 12px;
}

.el-upload__tip {
  color: #666;
  font-size: 12px;
  margin-top: 5px;
}


/* Shell 控制台样式 */
.shell-console {
  background-color: #1e1e1e;
  color: #d4d4d4;
  font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
  font-size: 13px;
  padding: 16px;
  border-radius: 6px;
  line-height: 1.6;
  overflow-x: auto;
  box-shadow: inset 0 0 8px rgba(0, 0, 0, 0.5);
}

.shell-item {
  margin-bottom: 12px;
  padding-bottom: 12px;
  border-bottom: 1px solid #3c3c3c;
}

.shell-item-last {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.shell-info {
  color: #569cd6;
  margin: 4px 0;
}

.shell-prompt {
  color: #4ec9b0;
  font-weight: bold;
  margin-right: 8px;
}

.shell-command-block {
  margin: 8px 0;
  padding-left: 12px;
  border-left: 2px solid #3c3c3c;
}

.shell-command {
  color: #ce9178;
  margin: 4px 0;
  font-weight: 500;
}

.shell-result {
  color: #6a9955;
  margin: 4px 0;
  padding-left: 20px;
}

.shell-status {
  color: #dcdcaa;
  margin-top: 8px;
  font-weight: 500;
}

.shell-console::-webkit-scrollbar {
  height: 8px;
}

.shell-console::-webkit-scrollbar-track {
  background: #2d2d2d;
  border-radius: 4px;
}

.shell-console::-webkit-scrollbar-thumb {
  background: #4d4d4d;
  border-radius: 4px;
}

.shell-console::-webkit-scrollbar-thumb:hover {
  background: #5d5d5d;
}
</style>
