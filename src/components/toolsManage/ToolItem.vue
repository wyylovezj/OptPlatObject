<script setup>
import { exportOrderFile, mobileTokenInterface, unlockAccountInterface,historyTask } from '@/api/interface.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { currentPage, messageInstance, searchQuery, user } from '@/utils/publicData.js'
import {
  cards,
  containsLabel, echoData,
  fileUploadDataModel, historyFileUploadDataModel,
  isAdmin,
  leafNodeCount,
  UnlockAccountDataModel,
  WorkOrderDataModel,
  selectedNode
} from '@/utils/publicDataTools.js'
import { CircleCheckFilled, CircleCloseFilled, UploadFilled } from '@element-plus/icons-vue'
import axios from 'axios'
import { ElMessage,ElButton,ElTableV2, ElAutoResizer } from 'element-plus'
import { computed, ref,onBeforeUnmount,watch,h } from 'vue'
import * as XLSX from 'xlsx'
import { Search } from '@element-plus/icons-vue'




// 权限状态管理
const permissionStore = usePermissionStore()
// 监听每个卡片的渲染状态
const cardRenderState = ref({
  exporterOrder: false,
  accountUnlock: false,
  scriptDistribution: false,
  tokenUnlock: false
})

// 新增：实时统计实际渲染的卡片数量（不依赖任何数据，只统计实际 DOM）
const filteredCardCount = computed(() => {
  // 直接返回实际渲染的卡片 DOM 数量
  const count = Object.values(cardRenderState.value).filter(state => state === true).length

  return count
})
// 历史任务表格列定义
const baseColumns = [
  {
    key: 'index',
    title: '序号',
    dataKey: 'index',
    width: 80,
    align: 'center',
  },
  {
    key: 'execute_time',
    title: '创建日期',
    dataKey: 'execute_time',
    width: 200,
    align: 'center',
  },
  {
    key: 'task_name',
    title: '任务号',
    dataKey: 'task_name',
    align: 'center',
  },
  {
    key: 'user',
    title: '执行人',
    dataKey: 'user',
    align: 'center',
  },
  {
    key: 'taskDetail',
    title: '任务详情',
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
              // 导出当前行的历史任务日志
              viewTaskDetail(rowData)
            },
          },
          { default: () => '查看' }
      )
    },
  },
  {
    key: 'exportFile',
    title: '导出',
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
            // 导出当前行的历史任务日志
            exportHistoryTaskLog(rowData)
          },
        },
        { default: () => '导出' }
      )
    },
  },
]
// 动态计算列宽
// 根据父容器宽度动态计算列宽的函数
const getColumns = (parentWidth) => {
  // 1. 计算固定宽度列的总宽（序号列已设置 width: 80）
  const fixedWidth = baseColumns.reduce((sum, col) => sum + (col.width || 0), 0);

  // 2. 找出需要自适应的列（没有设置 width 的列）
  const autoColumns = baseColumns.filter(col => col.width === undefined);

  // 3. 计算每列的自适应宽度（按 2:1:1 比例分配）
  if (autoColumns.length > 0 && parentWidth > fixedWidth) {
    // 可分配的剩余宽度
    const availableWidth = parentWidth - fixedWidth;

    // 权重分配：task_name 权重 2，其他列权重 1
    const weightMap = {
      'task_name': 2,
      'execute_time': 1,
      'user': 1,
    };

    // 计算总权重
    const totalWeight = autoColumns.reduce((sum, col) => {
      return sum + (weightMap[col.key] || 1);
    }, 0);

    // 计算每个权重单位的宽度
    const widthPerWeight = availableWidth / totalWeight;

    // 4. 返回计算后的列配置
    return baseColumns.map(col => {
      if (col.width === undefined) {
        // 按权重分配宽度
        const weight = weightMap[col.key] || 1;
        return {
          ...col,
          width: Math.max(100, Math.floor(weight * widthPerWeight)) // 最小宽度 100
        };
      } else {
        // 已有固定宽度的列保持不变
        return col;
      }
    });
  }

  // 默认情况：返回原始列配置
  return baseColumns.map(col => ({
    ...col,
    width: col.width || 150
  }));
};
// 历史任务表格数据
const data = ref([])

// 查看任务详情
const viewTaskDetail = (rowData) => {
  console.log('查看任务详情:', rowData)
  // 打开任务详情模态框
  dialogVisible.value.historyStandardOutputVisible = true
  console.log('查看任务详情:', rowData)
  // 这里可以根据 rowData 加载具体的任务回显数据
  // 直接设置回显数据，不使用打字机效果
  if (rowData.data_echo) {
    // 生成所有需要显示的行
    allTypewriterLines = generateTypewriterContent(rowData.data_echo)
    // 直接赋值给 typewriterLines，一次性显示所有内容
    typewriterLines.value = allTypewriterLines.map(line => ({
      group: line.group,
      type: line.type,
      text: line.text,
      deviceIp: line.deviceIp  // 新增：保留 deviceIp 字段
    }))
    // 重置打字机状态标记
    currentLineIndex.value = allTypewriterLines.length
    currentCharIndex.value = 0
    isTyping.value = false
    hasStartedTyping = true
    // 历史任务直接启用导出按钮
    // exportLogDisabled.value = false
  }
  else {
    // 如果没有回显数据，禁用导出按钮
    // exportLogDisabled.value = true
    typewriterLines.value = []
  }
  // 例如：echoData.value = rowData.echoData
}

// 导出任务日志到文件
const exportTaskLog = async () => {
  if (typewriterLines.value.length === 0) {
    ElMessage.warning('没有可导出的日志内容')
    return
  }

  // 生成日志文本内容
  let logContent = ''
  const timestamp = new Date().toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  }).replace(/\//g, '-')

  logContent += `任务日志导出时间：${timestamp}\n`
  logContent += '='.repeat(80) + '\n\n'

  // 按分组整理日志
  const groups = ['task', 'upload', 'login', 'execute', 'result']
  const groupNames = {
    task: '【任务详情】',
    upload: '【文件上传】',
    login: '【登录堡垒机】',
    execute: '【脚本下发执行】',
    result: '【任务执行结果】'
  }

  groups.forEach(group => {
    const groupLines = typewriterLines.value.filter(l => l.group === group)
    if (groupLines.length > 0) {
      logContent += `${groupNames[group]}\n`
      logContent += '-'.repeat(60) + '\n'

      groupLines.forEach(line => {
        logContent += `${line.text}\n`
      })

      logContent += '\n'
    }
  })

  logContent += '='.repeat(80) + '\n'
  logContent += '导出完成\n'

  // 创建 Blob 并下载
  const blob = new Blob([logContent], { type: 'text/plain;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  // 尝试从 typewriterLines 中获取任务 ID
  const taskLines = typewriterLines.value.filter(l => l.group === 'task' && l.type === 'info' && l.text.includes('任务 ID'))
  let taskId = ''
  if (taskLines.length > 0) {
    taskId = taskLines[0].text.split('任务 ID：')[1] || ''
  }

  // 文件名格式：日期_任务 UUID.txt
  const datePart = new Date().toISOString().slice(0, 10).replace(/-/g, '')
  const fileName = taskId ? `${datePart}_${taskId}.txt` : `任务日志_${timestamp.replace(/[:\s]/g, '')}.txt`
  link.download = fileName
  link.click()
  window.URL.revokeObjectURL(url)
  if (messageInstance.value) {
    ElMessage.closeAll()
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
  // 显示警告消息
  messageInstance.value = ElMessage.success({
    message: `日志导出成功`,
    duration: 1000,
    onClose: () => {
      messageInstance.value = null
    },
  })
}

// 导出历史任务日志
const exportHistoryTaskLog = async (rowData) => {
  console.log('导出历史任务日志:', rowData)

  if (!rowData.data_echo || rowData.data_echo.length === 0) {
    ElMessage.warning('该任务没有可导出的日志内容')
    return
  }

  // 生成需要显示的所有行
  const allTypewriterLines = generateTypewriterContent(rowData.data_echo)

  if (allTypewriterLines.length === 0) {
    ElMessage.warning('该任务没有可导出的日志内容')
    return
  }

  // 生成日志文本内容
  let logContent = ''
  const timestamp = new Date().toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  }).replace(/\//g, '-')

  logContent += `任务号：${rowData.task_name || '未知'}\n`
  logContent += `执行用户：${rowData.user || '未知'}\n`
  logContent += `创建日期：${rowData.execute_time || '未知'}\n`
  logContent += `导出时间：${timestamp}\n`
  logContent += '='.repeat(80) + '\n\n'

  // 按分组整理日志
  const groups = ['task', 'upload', 'login', 'execute', 'result']
  const groupNames = {
    task: '【任务详情】',
    upload: '【文件上传】',
    login: '【登录堡垒机】',
    execute: '【脚本下发执行】',
    result: '【任务执行结果】'
  }

  groups.forEach(group => {
    const groupLines = allTypewriterLines.filter(l => l.group === group)
    if (groupLines.length > 0) {
      logContent += `${groupNames[group]}\n`
      logContent += '-'.repeat(60) + '\n'

      groupLines.forEach(line => {
        logContent += `${line.text}\n`
      })

      logContent += '\n'
    }
  })

  logContent += '='.repeat(80) + '\n'
  logContent += '导出完成\n'

  // 创建 Blob 并下载
  const blob = new Blob([logContent], { type: 'text/plain;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  // 从 data_echo 中获取任务 ID
  let taskId = ''
  if (rowData.data_echo && rowData.data_echo.length >= 1 && rowData.data_echo[0]) {
    taskId = rowData.data_echo[0].taskId || ''
  }

  // 文件名格式：日期_任务 UUID.txt
  const datePart = new Date(rowData.execute_time || Date.now()).toISOString().slice(0, 10).replace(/-/g, '')
  const fileName = taskId ? `${datePart}_${taskId}.txt` : `历史任务日志_${rowData.task_name || timestamp.replace(/[:\s]/g, '')}.txt`
  link.download = fileName
  link.click()
  window.URL.revokeObjectURL(url)

  if (messageInstance.value) {
    ElMessage.closeAll()
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
  // 显示警告消息
  messageInstance.value = ElMessage.success({
    message: `日志导出成功`,
    duration: 1000,
    onClose: () => {
      messageInstance.value = null
    },
  })
}
// 初始化历史任务表格（模态框打开时调用）
const initHistoryTaskTable = async () => {
  try {
    const execUser = historyFileUploadDataModel.value.execUser
    const execTime = historyFileUploadDataModel.value.execTime
    const responseData = await historyTask(execUser, execTime)
    if (responseData.status === 'success') {
      data.value = responseData?.data || []
      // 为数据添加序号（从 1 开始）
      data.value = data.value.map((item, index) => ({
        ...item,
        index: index + 1,
      }))
    } else {
      ElMessage.error('获取历史任务数据失败')
    }
  }
  catch (error){
    ElMessage.error('获取历史任务数据失败:',error)
  }
}
// 表单验证定时器
let validateTimer = null
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
  mobileToken: false, // 移动令牌模态框可视
  historyScriptDistribute: false, // 历史任务模态框可视状态
  historyStandardOutputVisible: false, // 历史任务详情模态框可视状态
  validityPeriod: false, // 域账号密码有效期模态框可视状态
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
  validityPeriod: {
    message: '',  // 账号状态，0是正常，1是锁定，2是过期，3是不存在，4是无效
    password_expires: '', // 密码有效期
    days_expiry: '', // 剩余天数
  }
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
    thirtyOneDaysBefore.setDate(thirtyOneDaysBefore.getDate() - 31) // 结束时间往前推31天
    return time.getTime() < thirtyOneDaysBefore.getTime() || time.getTime() > endTime.getTime()
  }
  return false // 如果没有设置结束时间，则不禁用任何日期
}
// 限制结束时间 不能晚于开始时间30天
const disabledEndDate = (time) => {
  if (WorkOrderDataModel.value.startTime) {
    const startTime = new Date(WorkOrderDataModel.value.startTime)
    // 将开始时间的时分秒设置为 0，只比较日期
    startTime.setHours(0, 0, 0, 0)
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
      if  (validateTimer) {
        clearTimeout(validateTimer)
      }
      validateTimer = setTimeout(() => {
        if (exporterForm.value) {
          exporterForm.value.clearValidate()
        }
      }, 2000)
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
      if (UnlockAccountDataModel.value.type === '3') {
        dialogVisible.value.validityPeriod = true
      }
      else {
        exportDisabled.value.unlockAccount = true
        dialogVisible.value.unlockAccount = false
      }
      try {
        const status = await unlockAccountInterface(UnlockAccountDataModel.value)
        console.log(status)
        if (status) {
          if (UnlockAccountDataModel.value.type === '3') {
            responseData.value.validityPeriod.message = status.message
            responseData.value.validityPeriod.days_expiry = status.days_expiry
            responseData.value.validityPeriod.password_expires = status.password_expires
          }
          else {
            exportDisabled.value.unlockAccount = false
            responseData.value.unlock.message = status.message
            responseData.value.unlock.status = status.status
          }
        }
      } catch (error) {
        console.log(error.message)
        if (UnlockAccountDataModel.value.type === '3') {
          console.log(error.message)
        }
        else {
          responseData.value.unlock.message = error.message
          responseData.value.unlock.status = 'fail'
          exportDisabled.value.unlockAccount = false
        }
      }
    } else {
      if  (validateTimer) {
      clearTimeout(validateTimer)
    }
      validateTimer = setTimeout(() => {
        if (unlockAccountForm.value) {
          unlockAccountForm.value.clearValidate()
        }
      }, 2000)
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
      exportLogDisabled.value = true
      // dialogVisible.value.ScriptDistribute = false
      try {
        // 重置打字机状态，准备打印新任务
        resetTypewriter()
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
      if  (validateTimer) {
        clearTimeout(validateTimer)
      }
      validateTimer = setTimeout(() => {
        if (fileUpload.value) {
          fileUpload.value.clearValidate()
        }
      }, 2000)
      console.log('error submit!', fields)
    }
  })
}
const mobileTokenLogin = async () => {
  if (!mobileToken.value) return
  await mobileToken.value.validate(async (valid, fields) => {
    if (valid) {
      try {
        if (fileUploadDataModel.value.bastionHostUser === '' || fileUploadDataModel.value.bastionHostPasswd === '') {
          if (messageInstance.value) {
            ElMessage.closeAll()
            await new Promise((resolve) => setTimeout(resolve, 0))
          }
          // 显示警告消息
          messageInstance.value = ElMessage.warning({
            message: `堡垒机用户或密码不能为空`,
            duration: 1000,
            onClose: () => {
              messageInstance.value = null
            },
          })
        }
        else {
          const bastionHostUser = fileUploadDataModel.value.bastionHostUser
          const bastionHostPassword = fileUploadDataModel.value.bastionHostPasswd
          const mobileToken = fileUploadDataModel.value.mobileToken
          console.log('bastionHostPassword',bastionHostPassword)
          const response = await mobileTokenInterface(bastionHostUser, bastionHostPassword, mobileToken)
          if (response.status === 'success') {
            if (messageInstance.value) {
              ElMessage.closeAll()
              await new Promise((resolve) => setTimeout(resolve, 0))
            }
            // 显示警告消息
            messageInstance.value = ElMessage.success({
              message: `堡垒机登录成功！`,
              offset: window.innerHeight / 2 - 100,
              duration: 1000,
              onClose: () => {
                messageInstance.value = null
              },
            })
            fileUploadDataModel.value.mobileToken = ''
          } else {
            if (messageInstance.value) {
              ElMessage.closeAll()
              await new Promise((resolve) => setTimeout(resolve, 0))
            }
            // 显示警告消息
            messageInstance.value = ElMessage.error({
              message: `${response.message}`,
              offset: window.innerHeight / 2 - 100,
              duration: 1000,
              onClose: () => {
                messageInstance.value = null
              },
            })
          }
        }
      } catch (error) {
        console.log(error.message)
        fileUploadDataModel.value.mobileToken = ''
      }
    } else {
      if  (validateTimer) {
        clearTimeout(validateTimer)
      }
      validateTimer = setTimeout(() => {
        if (mobileToken.value) {
          mobileToken.value.clearValidate()
        }
      }, 2000)
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
  {
    value: '3',
    label: '域账号密码过期查询',
  },
]

// 账号输入即时校验函数
const handleAccountInput = async (value) => {
  const cleanedValue = value.replace(/\s/g, '')

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
  const cleanedValue = value.replace(/\s/g, '')
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
  const cleanedValue = value.replace(/\s/g, '')
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
// 脚本下发移动令牌输入即时校验函数
const handleMobileToken = async (value) => {
  const cleanedValue = value.replace(/\D/g, '').slice(0, 8)
  // 如果过滤后的值与原值不同，说明输入了非法字符
  if (cleanedValue !== value) {
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `只允许输入8位数字`,
      duration: 1000,
      offset: window.innerHeight / 2 - 100,
      onClose: () => {
        messageInstance.value = null
      },
    })
  }
  fileUploadDataModel.value.mobileToken = cleanedValue
}

// 脚本下发表单实例
const fileUpload = ref(null)
// 移动令牌表单实例
const mobileToken = ref(null)

// 脚本下发上传器实例
const uploadFile = ref(null)
const mobileTokenRules = ref({
  mobileToken: [
    {
      required: true,
      message: '请输入移动令牌',
      trigger: 'change',
    },
  ],
})
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
    {
      validator: async (rule, value, callback) => {
        if (!value || value.trim() === '') {
          callback(new Error('请输入网络设备 IP'))
          return
        }

        // 使用分隔符分割字符串：分号、逗号、制表符、空格、换行
        const separators = /[;\t,\n\r]|\s{1,}/g
        const ipArray = value
          .split(separators)
          .map((ip) => ip.trim())
          .filter((ip) => ip)

        // 验证并过滤有效的 IP 地址
        const ipRegex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
        const validIPs = ipArray.filter((ip) => ipRegex.test(ip))

        // 找出无效的 IP
        const invalidIPs = ipArray.filter((ip) => !ipRegex.test(ip))

        // 如果有无效的 IP，返回错误提示
        if (invalidIPs.length > 0) {
          callback(new Error(`以下 IP 地址格式不正确：${invalidIPs.join(', ')}`))
          return
        }

        // 如果没有有效的 IP，返回错误
        if (validIPs.length === 0) {
          callback(new Error('请至少输入一个有效的 IP 地址'))
          return
        }

        // 更新内部 IP 数组（去重）
        netWorkDeviceIP.value = [...new Set(validIPs)]
        console.log('netWorkDeviceIP', netWorkDeviceIP.value)

        // 校验通过，自动格式化输入值（用分号连接）
        fileUploadDataModel.value.netWorkDeviceIP = validIPs.join('; ')

        callback()
      },
      trigger: 'blur',
    },
  ],
  fileList: [
    {
      required: true,
      message: '请上传脚本文件或输入命令',
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

// 处理堡垒机账号解锁按钮点击事件
const handleUnlock = () => {
  window.open('https://www.baidu.com', '_blank')
}
// 脚本下发历史任务时间格式
const defaultTime = ref([
  new Date(2000, 1, 1, 0, 0, 0),
  new Date(2000, 2, 1, 23, 59, 59),
])
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
const typewriterLines = ref([]) // 已打印的行
const currentLineIndex = ref(0) // 当前行索引
const currentCharIndex = ref(0) // 当前字符索引
const isTyping = ref(false) // 是否正在打字
const typewriterSpeed = 0.1 // 打字速度 (毫秒/字符)
const lineDelay = 1 // 行间距延迟 (毫秒)
let typewriterTimer = null  // 打字机定时器
let allTypewriterLines = [] // 缓存所有需要显示的行
let hasStartedTyping = false // 标记是否已经开始打字
const scrollbarRef = ref(null) // 滚动条实例引用
// 导出按钮禁用状态
const exportLogDisabled = ref(true)
// 脚本文件上传按钮禁用状态
const uploadFileDisabled = ref(false)
// 手动输入和取消输入切换状态
const handlerInputStatus = ref(true)
const manualCommandText = ref('') // 存储手动输入的命令文本
const tempScriptFile = ref(null) // 存储创建的临时脚本文件
const previewDialogVisible = ref(false) // 控制预览对话框显示
const previewContent = ref('') // 预览内容
const previewFileInfo = ref(null) // 预览文件信息



const cancelHandlerInputButton = () => {
  handlerInputStatus.value = true
  uploadFileDisabled.value = false
  // 清空之前的输入和临时文件
  manualCommandText.value = ''
  tempScriptFile.value = null
  // 清除预览数据
  previewContent.value = ''
  previewFileInfo.value = null
  previewDialogVisible.value = false
}
const handlerInputButton = () => {
  handlerInputStatus.value = false
  uploadFileDisabled.value = true
  // 清空之前的输入和临时文件
  // manualCommandText.value = ''
  tempScriptFile.value = null
}
const handlerOverButton = () => {
  if (!manualCommandText.value.trim()) {
    ElMessage.warning('请输入命令内容')
    return
  }

  try {
    // 1. 按换行符分隔输入内容，过滤空行
    const commands = manualCommandText.value.split(/\r?\n/).filter(line => line.trim())

    if (commands.length === 0) {
      ElMessage.warning('未找到有效的命令')
      return
    }

    // 2. 将命令写入临时文件（每行一个命令）
    const fileContent = commands.join('\n')
    const blob = new Blob([fileContent], { type: 'text/plain' })
    const tempFile = new File([blob], 'script_commands.txt', {
      type: 'text/plain',
      lastModified: Date.now(),
    })

    // 3. 保存临时文件引用
    tempScriptFile.value = tempFile

    // 4. 更新数据模型中的文件列表
    fileUploadDataModel.value.fileList = [
      {
        name: tempFile.name,
        size: tempFile.size,
        raw: tempFile,
      },
    ]

    // 5. 显示成功提示
    ElMessage.success({
      message: `已将 ${commands.length} 条命令写入临时文件`,
      type: 'success',
      duration: 2000,
    })

    console.log('创建的临时脚本文件:', tempFile)
    console.log('命令列表:', commands)

    // 6. 切换回导入文件模式
    handlerInputStatus.value = true
    uploadFileDisabled.value = false

  } catch (error) {
    console.error('创建临时文件失败:', error)
    ElMessage.error({
      message: '创建临时文件失败：' + error.message,
      type: 'error',
      duration: 3000,
    })
  }
}

// 新增：预览临时文件内容（在 handlerOverButton 函数后面添加）
const previewUploadedFile = () => {
  // 检查是否有文件可预览
  let fileToPreview = null
  let fileInfo = null

  // 优先从上传器获取文件
  if (fileUploadDataModel.value.fileList && fileUploadDataModel.value.fileList.length > 0) {
    const uploadedFile = fileUploadDataModel.value.fileList[0]
    fileToPreview = uploadedFile.raw || uploadedFile
    fileInfo = {
      name: uploadedFile.name,
      size: uploadedFile.size,
      type: 'text/plain',
    }
  } else if (tempScriptFile.value) {
    // 如果没有上传器文件，使用临时文件
    fileToPreview = tempScriptFile.value
    fileInfo = {
      name: tempScriptFile.value.name,
      size: tempScriptFile.value.size,
      type: tempScriptFile.value.type,
    }
  }

  if (!fileToPreview) {
    ElMessage.warning('没有可预览的文件')
    return
  }

  // 读取文件内容
  const reader = new FileReader()
  reader.onload = (e) => {
    previewContent.value = e.target.result
    previewFileInfo.value = fileInfo
    previewDialogVisible.value = true
  }
  reader.onerror = () => {
    ElMessage.error('读取文件失败')
  }
  reader.readAsText(fileToPreview)
}
// 滚动条滚动到底部
const scrollToBottom = () => {
  if (scrollbarRef.value) {
    // 使用 nextTick 确保 DOM 更新后再滚动
    setTimeout(() => {
      const wrapRef = scrollbarRef.value.wrapRef
      if (wrapRef) {
        wrapRef.scrollTop = wrapRef.scrollHeight
      }
    }, 10)
  }
}

// 生成需要显示的所有行（包含所有回显内容，带分组信息）
// const generateTypewriterContent = (echoDataParam) => {
//   const lines = []
//
//   if (!echoDataParam || echoDataParam.length === 0) {
//     return lines
//   }
//   // 任务详情部分
//   if (echoDataParam.length >= 1 && echoDataParam[0]) {
//     if (echoDataParam[0].taskId) {
//       lines.push({ group: 'task', type: 'info', text: `任务 ID：${echoDataParam[0].taskId}` })
//     }
//     if (echoDataParam[0].createTaskTime) {
//       lines.push({ group: 'task', type: 'info', text: `创建时间：${echoDataParam[0].createTaskTime}` })
//     }
//     if (echoDataParam[0].fileName) {
//       lines.push({ group: 'task', type: 'info', text: `文件名：${echoDataParam[0].fileName}` })
//     }
//     if (echoDataParam[0].netWorkDeviceIP?.length >= 1) {
//       lines.push({ group: 'task', type: 'info', text: `网络设备 IP：` })
//       echoDataParam[0].netWorkDeviceIP.forEach((ip) => {
//         lines.push({ group: 'task', type: 'result', text: `  ${ip}` })
//       })
//     }
//   }
//
//   // 文件上传部分
//   if (echoDataParam.length >= 2 && echoDataParam[1]) {
//     if (echoDataParam[1].fileName) {
//       lines.push({ group: 'upload', type: 'info', text: `文件名：${echoDataParam[1].fileName}` })
//     }
//     if (echoDataParam[1].progress) {
//       lines.push({ group: 'upload', type: 'status', text: `上传结果：${echoDataParam[1].progress}` })
//     }
//   }
//
//   // 登录堡垒机部分
//   if (echoDataParam.length >= 3 && echoDataParam[2]) {
//     if (echoDataParam[2].bastionHostUser) {
//       lines.push({ group: 'login', type: 'info', text: `堡垒机用户：${echoDataParam[2].bastionHostUser}` })
//     }
//     if (echoDataParam[2].progress) {
//       lines.push({ group: 'login', type: 'status', text: `登录结果：${echoDataParam[2].progress}` })
//     }
//   }
//
//   // 脚本下发执行部分
//   if (echoDataParam.length >= 4 && echoDataParam[3]) {
//     // if (echoDataParam[3].fileName) {
//     //   lines.push({ group: 'execute', type: 'info', text: `脚本文件：${echoDataParam[3].fileName}` })
//     // }
//
//     if (echoDataParam[3].progress?.length >= 1) {
//       echoDataParam[3].progress.forEach((item) => {
//         if (item.netWorkDeviceIP) {
//           lines.push({ group: 'execute', type: 'info', text: `网络设备 IP: ${item.netWorkDeviceIP}` })
//         }
//
//         if (item.progress?.length >= 1 && item.progress) {
//           item.progress.forEach((itemCmd) => {
//             if (itemCmd.command) {
//               lines.push({ group: 'execute', type: 'command', text: `${itemCmd.command}` })
//             }
//             if (itemCmd.result) {
//               lines.push({ group: 'execute', type: 'result', text: `  ${itemCmd.result}` })
//             }
//           })
//         }
//
//         // if (item.status) {
//         //   lines.push({ group: 'execute', type: 'status', text: `执行结果：${item.status}` })
//         // }
//       })
//     }
//   }
//
//   // 任务执行结果部分
//   if (echoDataParam.length >= 5 && echoDataParam[4]) {
//     if (echoDataParam[4].status?.success?.length >= 1) {
//       lines.push({ group: 'result', type: 'info', text: `执行成功：` })
//       echoDataParam[4].status.success.forEach((item) => {
//         lines.push({ group: 'result', type: 'result', text: `  ${item}` })
//       })
//     }
//     if (echoDataParam[4].status?.fail?.length >= 1) {
//       lines.push({ group: 'result', type: 'info', text: `执行失败：` })
//       echoDataParam[4].status.fail.forEach((item) => {
//         lines.push({ group: 'result', type: 'result', text: `  ${item}` })
//       })
//     }
//   }
//
//   return lines
// }
// 生成需要显示的所有行（包含所有回显内容，带分组信息）
const generateTypewriterContent = (echoDataParam) => {
  const lines = []

  if (!echoDataParam || echoDataParam.length === 0) {
    return lines
  }

  // 辅助函数：添加一行或多行（如果文本包含换行符则分割）
  const addLine = (group, type, text, isCommandResult = false,isCommand = false,isNetIP=false,deviceIp=null) => {
    if (!text) return
    // 如果包含换行符，分割成多行
    const textLines = text.split('\n')
    textLines.forEach((line, index) => {
      let processedLine = line
      // 如果是命令执行结果的第一行且行首有两个空格，去掉这两个空格
      if (isCommandResult && index === 0 && line.startsWith('  ')) {
        processedLine = line.substring(2)
      }
      lines.push({
        group,
        type,
        text: processedLine,
        isOriginalLine: index < textLines.length - 1, // 标记是否是原始行（用于保持格式）
        isCommandResult: isCommandResult, // 标记是否是命令执行结果
        isCommand: isCommand,// 标记是否是命令
        isNetIP: isNetIP, // 标记是否是ip
        deviceIp: deviceIp,// 标记ip
      })
    })
  }

  // 任务详情部分
  if (echoDataParam.length >= 1 && echoDataParam[0]) {
    if (echoDataParam[0].taskId) {
      addLine('task', 'info', `任务 ID：${echoDataParam[0].taskId}`)
    }
    if (echoDataParam[0].createTaskTime) {
      addLine('task', 'info', `创建时间：${echoDataParam[0].createTaskTime}`)
    }
    if (echoDataParam[0].fileName) {
      addLine('task', 'info', `文件名：${echoDataParam[0].fileName}`)
    }
    if (echoDataParam[0].netWorkDeviceIP?.length >= 1) {
      addLine('task', 'info', `网络设备 IP：`)
      echoDataParam[0].netWorkDeviceIP.forEach((ip) => {
        addLine('task', 'result', `  ${ip}`)
      })
    }
  }

  // 文件上传部分
  if (echoDataParam.length >= 2 && echoDataParam[1]) {
    if (echoDataParam[1].fileName) {
      addLine('upload', 'info', `文件名：${echoDataParam[1].fileName}`)
    }
    if (echoDataParam[1].progress) {
      addLine('upload', 'status', `上传结果：${echoDataParam[1].progress}`)
    }
  }

  // 登录堡垒机部分
  if (echoDataParam.length >= 3 && echoDataParam[2]) {
    if (echoDataParam[2].bastionHostUser) {
      addLine('login', 'info', `堡垒机用户：${echoDataParam[2].bastionHostUser}`)
    }
    if (echoDataParam[2].progress) {
      addLine('login', 'status', `登录结果：${echoDataParam[2].progress}`)
    }
  }

  // 脚本下发执行部分
  if (echoDataParam.length >= 4 && echoDataParam[3]) {
    if (echoDataParam[3].progress?.length >= 1) {
      echoDataParam[3].progress.forEach((item) => {
        const currentDeviceIp = item.netWorkDeviceIP || 'unknown'
        if (item.netWorkDeviceIP) {
          addLine('execute', 'info', `网络设备 IP: ${item.netWorkDeviceIP}`, false,false,true,currentDeviceIp)
        }

        if (item.progress?.length >= 1 && item.progress) {
          item.progress.forEach((itemCmd) => {
            if (itemCmd.command) {
              addLine('execute', 'command', `${itemCmd.command}`, false,true,false)
            }
            if (itemCmd.result) {
              // 执行结果保留原始格式，包括换行符
              addLine('execute', 'result', `  ${itemCmd.result}`, true,false,false)
            }
          })
        }

        // if (item.status) {
        //   addLine('execute', 'status', `执行结果：${item.status}`)
        // }
      })
    }
  }

  // 任务执行结果部分
  if (echoDataParam.length >= 5 && echoDataParam[4]) {
    if (echoDataParam[4].status?.success?.length >= 1) {
      addLine('result', 'info', `执行成功：`)
      echoDataParam[4].status.success.forEach((item) => {
        addLine('result', 'result', `  ${item}`)
      })
    }
    if (echoDataParam[4].status?.fail?.length >= 1) {
      addLine('result', 'info', `执行失败：`)
      echoDataParam[4].status.fail.forEach((item) => {
        addLine('result', 'result', `  ${item}`)
      })
    }
  }

  return lines
}

// 新增：将 execute 组的行按 deviceIp 分组
const groupExecuteLines = (lines) => {
  const executeLines = lines.filter(l => l.group === 'execute')
  const groups = []
  let currentGroup = null

  executeLines.forEach((line) => {
    // 如果当前行有 deviceIp，创建新组
    if (line.deviceIp) {
      currentGroup = {
        deviceIp: line.deviceIp,
        lines: [line]
      }
      groups.push(currentGroup)
    }
    // 如果当前行没有 deviceIp 但已经有组了，加入当前组
    else if (currentGroup) {
      currentGroup.lines.push(line)
    }
    // 如果当前行没有 deviceIp 且还没有组（理论上不应该发生），创建默认组
    else {
      currentGroup = {
        deviceIp: 'default',
        lines: [line]
      }
      groups.push(currentGroup)
    }
  })

  return groups
}
// 打字机效果启动函数
// const startTypewriter = (echoDataParam) => {
//   // if (isTyping.value || hasStartedTyping) return
//   // 如果正在打字，先停止
//   if (isTyping.value) {
//     stopTypewriter()
//   }
//   // 只在开始时生成一次内容
//   allTypewriterLines = generateTypewriterContent(echoDataParam)
//   if (allTypewriterLines.length === 0) return
//
//   typewriterLines.value = []
//   currentLineIndex.value = 0
//   currentCharIndex.value = 0
//   isTyping.value = true
//   hasStartedTyping = true
//
//   typeNextCharacter()
// }

const startTypewriter = (echoDataParam) => {
  // 生成新的内容
  const newAllTypewriterLines = generateTypewriterContent(echoDataParam)
  if (newAllTypewriterLines.length === 0) return

  // 如果还没有开始打字，初始化
  if (!hasStartedTyping) {
    allTypewriterLines = newAllTypewriterLines
    typewriterLines.value = []
    currentLineIndex.value = 0
    currentCharIndex.value = 0
    isTyping.value = true
    hasStartedTyping = true
    typeNextCharacter()
    return
  }

  // 更新所有行为最新数据（始终使用最新数据）
  allTypewriterLines = newAllTypewriterLines

  // 如果正在打字，继续打
  if (isTyping.value) {
    // 不需要做任何事，让 typeNextCharacter 继续打就行
    return
  }

  // 如果已经打完当前行，但还有新行，继续打
  if (currentLineIndex.value < allTypewriterLines.length) {
    isTyping.value = true
    typeNextCharacter()
  }
}
// 逐字打印
const typeNextCharacter = () => {
  // 检查是否还有未打印的行
  if (currentLineIndex.value >= allTypewriterLines.length) {
    isTyping.value = false
    // 新增：检查 echoData 的 status 是否为 complete
    const isTaskComplete = echoData.value && echoData.value?.status === 'complete'
    // 只有当打字机状态为 false 且任务状态为 complete 时，才启用导出按钮
    if (!isTyping.value && isTaskComplete) {
      exportLogDisabled.value = false
      console.log('打印完成，导出按钮已启用，exportLogDisabled:', exportLogDisabled.value)
    }
    return
  }

  const currentLine = allTypewriterLines[currentLineIndex.value]

  // 如果是命令执行结果，直接显示完整内容
  if (currentLine.isCommandResult || currentLine.isCommand || currentLine.isNetIP) {
    // 直接显示完整行
    typewriterLines.value[currentLineIndex.value] = {
      group: currentLine.group,
      type: currentLine.type,
      text: currentLine.text,
      deviceIp: currentLine.deviceIp  // 新增：保留 deviceIp 字段
    }
    currentLineIndex.value++
    currentCharIndex.value = 0
    scrollToBottom()
    typeNextCharacter()
    // 继续处理下一行
    // if (currentLineIndex.value < allTypewriterLines.length) {
    //   setTimeout(() => {
    //
    //   }, lineDelay)
    // } else {
    //   isTyping.value = false
    //   const isTaskComplete = echoData.value && echoData.value?.status === 'complete'
    //   if (!isTyping.value && isTaskComplete) {
    //     exportLogDisabled.value = false
    //     console.log('打印完成，导出按钮已启用，exportLogDisabled:', exportLogDisabled.value)
    //   }
    // }
    return
  }

  // 如果当前行在 typewriterLines 中不存在，创建它（打一行分配一行）
  if (!typewriterLines.value[currentLineIndex.value]) {
    typewriterLines.value[currentLineIndex.value] = {
      group: currentLine.group,
      type: currentLine.type,
      text: '',
      deviceIp: currentLine.deviceIp  // 新增：保留 deviceIp 字段
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
    // 滚动到底部
    scrollToBottom()

    // 立即检查是否有新行并继续打
    if (currentLineIndex.value < allTypewriterLines.length) {
      typewriterTimer = setTimeout(() => {
        typeNextCharacter()
      }, lineDelay)
    } else {
      isTyping.value = false
      // 新增：检查 echoData 的 status 是否为 complete
      const isTaskComplete = echoData.value && echoData.value?.status === 'complete'
      // 只有当打字机状态为 false 且任务状态为 complete 时，才启用导出按钮
      if (!isTyping.value && isTaskComplete) {
        exportLogDisabled.value = false
        console.log('打印完成，导出按钮已启用，exportLogDisabled:', exportLogDisabled.value)
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
const resetTypewriter = () => {
  stopTypewriter()
  typewriterLines.value = []
  currentLineIndex.value = 0
  currentCharIndex.value = 0
  allTypewriterLines = []
  hasStartedTyping = false
}
// 监听 echoData 变化，自动启动打字机效果
let watchEchoDataTimer = null
// 监听 echoData 变化，自动启动打字机效果
watch(
  () => echoData.value,
  (newEchoData) => {
    if (newEchoData.data && newEchoData.data.length > 0) {
      // 延迟一点时间确保数据已经完全更新
      // 清除之前的定时器，避免重复触发
      if (watchEchoDataTimer) {
        clearTimeout(watchEchoDataTimer)
      }

      // 延迟一点时间确保数据已经完全更新
      watchEchoDataTimer = setTimeout(() => {
        startTypewriter(newEchoData.data)
      }, 100)
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
const handleFileRemove = (file, fileList) => {
  // 当文件被删除时（fileList 为空），清空相关文件数据
  if (!fileList || fileList.length === 0) {
    // 文件已被删除，清空临时文件引用
    tempScriptFile.value = null
    manualCommandText.value = ''
    fileUploadDataModel.value.fileList = []
    // 清空预览相关数据
    previewContent.value = ''
    previewFileInfo.value = null
    previewDialogVisible.value = false
    console.log('文件已删除，清空所有预览数据')
  }
}
// 文件列表变化处理
const handleFileChange = (file, fileList) => {
  handleFileRemove()
  console.log('文件列表变化:', fileList)
  const isValid = beforeUpload(file.raw)
  if (!isValid) {
    // 如果文件验证失败，清空文件列表
    uploadFile.value?.clearFiles()
    fileUploadDataModel.value.fileList = []
    return
  }
  // 重置打字机状态，准备打印新任务
  resetTypewriter()

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
  // if (fileUploadDataModel.value.netWorkDeviceIP!=='') {
  //   // 使用分隔符分割字符串：分号、逗号、制表符、空格、换行
  //   const separators = /[;\t,\n\r]|\s{1,}/g
  //   const ipArray = fileUploadDataModel.value.netWorkDeviceIP
  //     .split(separators)
  //     .map((ip) => ip.trim())
  //     .filter((ip) => ip)
  //
  //   // 验证并过滤有效的 IP 地址
  //   const ipRegex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
  //   const validIPs = ipArray.filter((ip) => ipRegex.test(ip))
  //
  //   // 去重
  //   netWorkDeviceIP.value = [...new Set(validIPs)]
  //   console.log('netWorkDeviceIP', netWorkDeviceIP.value)
  // }
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
    const seconds = String(date.getSeconds()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
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
          echoData.value = response.data;
          // 如果状态为 complete，终止定时器
          if (response.data.status === 'complete') {
            clearInterval(progressTimer)
            progressTimers.delete(taskId)
            console.log('任务完成，已清除定时器')
          }
        } catch (error) {
          console.error('Error clearing progress timer:', error)
          clearInterval(progressTimer)
          progressTimers.delete(taskId)
        }
      },100)
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
  // 新增：清理 watch 中的定时器
  if (watchEchoDataTimer) {
    clearTimeout(watchEchoDataTimer)
    watchEchoDataTimer = null
  }
})
</script>

<template>
  <div class="toolsItem">
    <div class="content-wrapper">
      <div class="card-container" v-if="hasVisibleCards">
        <!--    工单导出卡片    -->
        <el-card
          v-if="containsLabel('工单导出') && permissionStore.hasPermission('tool:orderExport')"
          shadow="hover"
          body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;"
          :ref="(el) => { cardRenderState.exporterOrder = !!el; }"
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
          v-if="containsLabel('账号解锁') && permissionStore.hasPermission('tool:accountUnlock')"
          shadow="hover"
          body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;"
          :ref="(el) => { cardRenderState.accountUnlock = !!el; }"
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
        <el-card
          v-if="containsLabel('脚本下发') && permissionStore.hasPermission('tool:scriptDistribution')"
          shadow="hover"
          body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;"
          :ref="(el) => { cardRenderState.tokenUnlock = !!el; }"
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
                <el-button type="danger" @click="dialogVisible.historyScriptDistribute = true">
                  历史任务
                </el-button>
                <el-button type="primary" :disabled="exportDisabled.ScriptDistribute" @click="dialogVisible.ScriptDistribute = true">
                  创建任务
                </el-button>
              </div>
            </div>
          </div>
        </el-card>
        <el-card
          v-if="containsLabel('堡垒机账号解锁') && permissionStore.hasPermission('tool:tokenUnlock')"
          shadow="hover"
          body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;"
          :ref="(el) => { cardRenderState.scriptDistribution = !!el; }"
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
                <p>堡垒机账号解锁</p>
              </div>
            </div>
            <!-- 下部分：按钮 -->
            <div class="bottom-section">
              <div style="flex: 1; display: flex; justify-content: flex-end">
                <el-button type="primary" @click="handleUnlock">
                  解锁
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
          <span style="line-height: 20px">共 {{ filteredCardCount }} 个</span>
        </div>
        <div class="pagination-nav">
          <!--  页码导航  -->
          <el-pagination
            background
            :current-page="currentCardPage"
            page-size="16"
            :total="filteredCardCount"
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
      destroy-on-close
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
      width="400px"
      center
      destroy-on-close
      :show-close="false"
      append-to-body
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
        <el-form-item :label="UnlockAccountDataModel.type === '3' ? '查询账号' : '解锁账号'" prop="username">
          <el-input
            v-model="UnlockAccountDataModel.username"
            style="width: 250px"
            placeholder="请输入账号"
            maxlength="15"
            type="text"
            @input="handleAccountInput"
            clearable
            spellcheck="false"
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
      <el-dialog
        v-model="dialogVisible.validityPeriod"
        title="域账号有效期信息"
        width="800px"
        center
        destroy-on-close
        @close="
            () => {
              dialogVisible.validityPeriod = false
            }
          "
      >
        <el-descriptions  :column="2" border :size="'large'" label-width="200px">
          <el-descriptions-item label="用户名" label-align="center" align="center">
            <el-tag :size="'large'" round>
              {{ UnlockAccountDataModel.username }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态" label-align="center" align="center">
            <el-tag
              :size="'large'"
              round
              :type="
                  responseData.validityPeriod.message === 0 ? 'success' :
                  responseData.validityPeriod.message === 1 ? 'danger' :
                  responseData.validityPeriod.message === 2 ? 'danger' :
                  responseData.validityPeriod.message === 3 ? 'info' :
                  responseData.validityPeriod.message === 4 ? 'info' :
                  ''"
            >
              {{
                responseData.validityPeriod.message === 0 ? '正常' :
                  responseData.validityPeriod.message === 1 ? '锁定' :
                    responseData.validityPeriod.message === 2 ? '过期' :
                      responseData.validityPeriod.message === 3 ? '不存在' :
                        responseData.validityPeriod.message === 4 ? '无效' :
                          responseData.validityPeriod.message
              }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="密码过期时间" label-align="center" align="center">
            {{ responseData.validityPeriod.password_expires }}
          </el-descriptions-item>
          <el-descriptions-item label="剩余天数" label-align="center" align="center">
            {{ responseData.validityPeriod.days_expiry }} 天
          </el-descriptions-item>
        </el-descriptions>
      </el-dialog>
    </el-dialog>
    <!--  脚本下发模态框  -->
    <el-dialog
      v-model="dialogVisible.ScriptDistribute"
      title="脚本下发"
      width="1000px"
      center
      :show-close="false"
      destroy-on-close
      :close-on-click-modal="false"
      @close="
        () => {
          dialogVisible.ScriptDistribute = false
          fileUploadDataModel.reset()
          netWorkDeviceIP = []
          typewriterLines = []
          currentLineIndex = 0
          currentCharIndex = 0
          allTypewriterLines = []
          hasStartedTyping = false
          isTyping = false
          exportLogDisabled = true
          buttonVisible.taskDetails = false
          cancelHandlerInputButton()
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
            spellcheck="false"
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
            spellcheck="false"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="dialogVisible.mobileToken = true">移动令牌</el-button>
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
            spellcheck="false"
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
            spellcheck="false"
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
            spellcheck="false"
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
          <!-- 终端风格输入框 -->
          <div style="margin-bottom: 10px;">
            <div style="background-color: #1e1e1e; border-radius: 6px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.3);">
              <!-- 终端标题栏 -->
              <div style="display: flex; align-items: center; padding: 8px 12px; background-color: #2d2d2d; border-bottom: 1px solid #404040;">
                <div style="display: flex; gap: 6px; margin-right: 12px;">
                  <div style="width: 12px; height: 12px; border-radius: 50%; background-color: #ff5f56;"></div>
                  <div style="width: 12px; height: 12px; border-radius: 50%; background-color: #ffbd2e;"></div>
                  <div style="width: 12px; height: 12px; border-radius: 50%; background-color: #27c93f;"></div>
                </div>
                <div style="color: #b8b8b8; font-size: 13px; font-family: 'Consolas', 'Monaco', monospace;">
                  {{ `${fileUploadDataModel.netWorkDeviceUser}@localhost:script_commands.txt` }}
                </div>
              </div>
              <!-- 终端内容区 -->
              <div style="position: relative;">
                <div style="display: flex; align-items: flex-start; padding: 12px;">
                  <el-input
                    v-model="manualCommandText"
                    placeholder="请输入命令，支持分隔符：换行"
                    :rows="8"
                    type="textarea"
                    clearable
                    resize="none"
                    style="flex: 1;"
                    :disabled="handlerInputStatus"
                    spellcheck="false"
                    :style="{
                      '--el-input-bg-color': 'transparent',
                      '--el-input-text-color': '#d4d4d4',
                      '--el-input-border-color': 'transparent',
                      '--el-input-hover-border-color': 'transparent',
                      '--el-input-focus-border-color': 'transparent',
                    }"
                    textarea-style="background-color: transparent; color: #d4d4d4; font-family: 'Consolas', 'Monaco', monospace; font-size: 14px; line-height: 1.6; border: none; box-shadow: none;"
                  />
                </div>
              </div>
              <!-- 终端底部状态栏 -->
              <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 12px; background-color: #2d2d2d; border-top: 1px solid #404040; font-size: 12px; color: #858585; font-family: 'Consolas', 'Monaco', monospace;">
                <span>Commands: {{ manualCommandText.split(/\r?\n/).filter(line => line.trim()).length }} lines</span>
                <span>bash</span>
              </div>
            </div>
            <div style="margin-top: 8px; display: flex; gap: 8px; align-items: center;">
              <el-button type="warning" :disabled="handlerInputStatus" @click.stop="handlerOverButton" size="small">输入完成</el-button>
              <span style="color: #909399; font-size: 12px;">提示：每行输入一个命令，点击"输入完成"后将自动生成临时文件并上传</span>
            </div>
          </div>
<!--          <el-input
            v-model="manualCommandText"
            style="width: 400px;"
            :placeholder="handlerInputStatus?'点击手动输入后支持输入命令' : '请输入命令，支持分隔符：换行'"
            :rows="10"
            type="textarea"
            clearable
            resize="none"
            :disabled="handlerInputStatus"
          />-->
          <el-upload
            class="upload-demo-input"
            ref="uploadFile"
            accept=".txt"
            :limit="1"
            :on-exceed="handleExceed"
            :file-list="fileUploadDataModel.fileList"
            :http-request="customUpload"
            :auto-upload="false"
            :on-change="handleFileChange"
            :on-remove="handleFileRemove"
          >
            <template #trigger>
              <el-button v-if="handlerInputStatus" type="success" @click.stop="handlerInputButton">手动输入</el-button>
              <el-button v-else type="danger" @click.stop="cancelHandlerInputButton">取消输入</el-button>
              <el-button type="primary" :disabled="uploadFileDisabled">导入文件</el-button>
<!--              <el-button v-if="!handlerInputStatus" type="warning" @click.stop="handlerOverButton">输入完成</el-button>-->
              <el-button
                v-if="fileUploadDataModel.fileList?.length > 0"
                type="info"
                round
                @click.stop="previewUploadedFile"
                style="padding: 5px 10px; font-size: 12px;"
              >
                预览
              </el-button>
            </template>
            <template #tip>
              <div class="el-upload__tip">支持上传 txt 文件，且不超过 10MB</div>
            </template>
          </el-upload>
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
        destroy-on-close
        :close-on-click-modal="false"
      >
        <el-scrollbar  ref="scrollbarRef" height="680px">
          <el-timeline style="width: 500px">
            <el-timeline-item timestamp="任务详情" placement="top">
              <el-card>
                <div class="shell-console">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'task')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'task').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
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
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
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
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="脚本下发执行" placement="top">
              <el-card>
                <!-- 按网络设备分组显示 - 遇到有 deviceIp 的行就新建一个 shell-console -->
                <template v-if="typewriterLines.some(l => l.group === 'execute')">
                  <div v-for="(group, groupIndex) in groupExecuteLines(typewriterLines)" :key="groupIndex">
                    <div class="shell-console" style="margin-bottom: 15px;">
                      <div v-for="(line, index) in group.lines" :key="index" class="shell-item" :class="{ 'shell-item-last': index === group.lines.length - 1 }">
                        <p v-if="line.type === 'device-header'" class="shell-device-header">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'info'" class="shell-info">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                      </div>
                    </div>
                  </div>
                </template>
              </el-card>
            </el-timeline-item>
<!--            <el-timeline-item timestamp="脚本下发执行" placement="top">-->
<!--              <el-card>-->
<!--                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'execute')">-->
<!--                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'execute')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'execute').length - 1 }">-->
<!--                    <p v-if="line.type === 'info'" class="shell-info">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--&lt;!&ndash;                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">&ndash;&gt;-->
<!--&lt;!&ndash;                      {{ line.text }}&ndash;&gt;-->
<!--&lt;!&ndash;                    </p>&ndash;&gt;-->
<!--                  </div>-->
<!--                </div>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
            <el-timeline-item timestamp="任务执行结果" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'result')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'result')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'result').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-scrollbar>
        <div style="display: flex; justify-content: flex-end; margin-top: 20px;height: 30px;">
          <el-button type="success" @click="exportTaskLog"  :disabled="exportLogDisabled">
            导出日志
          </el-button>
        </div>
      </el-dialog>
      <el-dialog
        v-model="dialogVisible.mobileToken"
        top="200px"
        width="300px"
        title="移动令牌"
        center
        append-to-body
      >
        <el-form
          :model="fileUploadDataModel"
          ref="mobileToken"
          label-position="right"
          label-width="auto"
          :rules="mobileTokenRules"
          style="display: flex; flex-direction: column; justify-content: center; flex-wrap: wrap; user-select: none"
        >
          <el-form-item label="移动令牌" prop="mobileToken">
            <el-input
              v-model="fileUploadDataModel.mobileToken"
              style="width: 200px"
              placeholder="请输入移动令牌"
              maxlength="15"
              type="text"
              @input="handleMobileToken"
              clearable
              spellcheck="false"
            />
          </el-form-item>
          <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: nowrap">
            <el-button type="primary" @click="mobileTokenLogin">确认</el-button>
            <el-button
              type="primary"
              @click="
              dialogVisible.mobileToken = false;
              // 清空数据模型
              fileUploadDataModel.mobileToken = '';
            "
            >取消</el-button
            >
          </div>
        </el-form>
      </el-dialog>
      <!-- 预览对话框 -->
      <el-dialog
        v-model="previewDialogVisible"
        :title="`预览文件：${previewFileInfo?.name || '未知'}`"
        width="800px"
        top="50px"
        append-to-body
        destroy-on-close
        :close-on-click-modal="false"
      >
        <div style="font-size: 12px; color: #909399; line-height: 1.8;">
          <div>文件名：{{ fileUploadDataModel.fileList[0].name }}</div>
          <div>文件大小：{{ (fileUploadDataModel.fileList[0].size / 1024).toFixed(2) }}  KB</div>
          <div>命令数量：{{ previewContent.split('\n').filter(line => line.trim()).length }} 条</div>
          <div>创建时间：{{ new Date().toLocaleString() }}</div>
          <div>文件格式：TXT</div>
        </div>
        <div style="max-height: 500px; overflow-y: auto; background-color: #1e1e1e; padding: 15px; border-radius: 4px; font-family: 'Consolas', 'Monaco', monospace; font-size: 13px; line-height: 1.6;">
          <div v-for="(line, index) in previewContent.split('\n')" :key="index" style="display: flex; margin-bottom: 2px;">
            <span style="color: #858585; min-width: 40px; text-align: right; padding-right: 15px; user-select: none; border-right: 1px solid #404040;">{{ index + 1 }}</span>
            <span style="color: #d4d4d4; padding-left: 15px; flex: 1;">{{ line || ' ' }}</span>
          </div>
        </div>

        <template #footer>
          <div style="display: flex; justify-content: flex-end; align-items: center;">
            <el-button type="primary" @click="previewDialogVisible = false">关闭</el-button>
          </div>
        </template>
      </el-dialog>
    </el-dialog>
    <!--  脚本下发历史任务模态框  -->
    <el-dialog
      v-model="dialogVisible.historyScriptDistribute"
      title="历史任务"
      width="55%"
      height="600px"
      center
      destroy-on-close
      :close-on-click-modal="false"
      @close="
        () => {
          dialogVisible.historyScriptDistribute = false
          historyFileUploadDataModel.reset()
        }
      "
      @open="initHistoryTaskTable"
    >
      <div style="height: 100px;">
        <el-form :model="historyFileUploadDataModel" ref="fileUpload" :inline="true" label-position="right" label-width="auto">
          <el-form-item label="执行用户" prop="execUser">
            <el-input
              v-model="historyFileUploadDataModel.execUser"
              style="width: 200px"
              placeholder="请输入执行用户"
              maxlength="15"
              type="text"
              clearable
              spellcheck="false"
            />
          </el-form-item>
          <el-form-item label="任务创建时间：" prop="execTime">
            <el-date-picker
              v-model="historyFileUploadDataModel.execTime"
              type="daterange"
              start-placeholder="开始日期"
              end-placeholder="结束日期"
              value-format="YYYY-MM-DD HH:mm:ss"
              unlink-panels
              @clear="searchQuery.occurrenceTime = []"
              :default-time="defaultTime"
            />
          </el-form-item>
          <el-form-item style="flex: none;margin-left: auto;margin-right: 5px;">
            <div style="display: flex;justify-content: flex-end;gap: 10px;flex-wrap: nowrap;">
              <el-button type="primary" :icon="Search" circle  @click="initHistoryTaskTable" size="default"/>
            </div>
          </el-form-item>
        </el-form>
      </div>
      <div style="height: 400px">
        <el-auto-resizer>
          <template #default="{ height, width }">
            <el-table-v2
              :columns="getColumns(width)"
              :data="data"
              :width="width"
              :height="height"
              fixed
            />
          </template>
        </el-auto-resizer>
      </div>
      <!--   历史任务详情模态框   -->
      <el-dialog
        v-model="dialogVisible.historyStandardOutputVisible"
        top="50px"
        width="600px"
        title="任务详情"
        center
        append-to-body
        destroy-on-close
        @close="() => {
          dialogVisible.historyStandardOutputVisible = false;
        }"
      >
        <el-scrollbar  ref="scrollbarRef" height="730px">
          <el-timeline style="width: 500px">
            <el-timeline-item timestamp="任务详情" placement="top">
              <el-card>
                <div class="shell-console">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'task')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'task').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
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
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
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
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
<!--            <el-timeline-item timestamp="脚本下发执行" placement="top">-->
<!--              <el-card>-->
<!--                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'execute')">-->
<!--                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'execute')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'execute').length - 1 }">-->
<!--                    <p v-if="line.type === 'info'" class="shell-info">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">-->
<!--                      {{ line.text }}-->
<!--                    </p>-->
<!--&lt;!&ndash;                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">&ndash;&gt;-->
<!--&lt;!&ndash;                      {{ line.text }}&ndash;&gt;-->
<!--&lt;!&ndash;                    </p>&ndash;&gt;-->
<!--                  </div>-->
<!--                </div>-->
<!--              </el-card>-->
<!--            </el-timeline-item>-->
            <el-timeline-item timestamp="脚本下发执行" placement="top">
              <el-card>
                <!-- 按网络设备分组显示 - 遇到有 deviceIp 的行就新建一个 shell-console -->
                <template v-if="typewriterLines.some(l => l.group === 'execute')">
                  <div v-for="(group, groupIndex) in groupExecuteLines(typewriterLines)" :key="groupIndex">
                    <div class="shell-console" style="margin-bottom: 15px;">
                      <div v-for="(line, index) in group.lines" :key="index" class="shell-item" :class="{ 'shell-item-last': index === group.lines.length - 1 }">
                        <p v-if="line.type === 'device-header'" class="shell-device-header">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'info'" class="shell-info">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                        <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
                          {{ line.text }}
                        </p>
                      </div>
                    </div>
                  </div>
                </template>
              </el-card>
            </el-timeline-item>
            <el-timeline-item timestamp="任务执行结果" placement="top">
              <el-card>
                <div class="shell-console" v-if="typewriterLines.some(l => l.group === 'result')">
                  <div v-for="(line, index) in typewriterLines.filter(l => l.group === 'result')" :key="index" class="shell-item" :class="{ 'shell-item-last': index === typewriterLines.filter(l => l.group === 'result').length - 1 }">
                    <p v-if="line.type === 'info'" class="shell-info" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'command'" class="shell-command" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'result'" class="shell-result" style="white-space: pre-wrap;">
                      {{ line.text }}
                    </p>
                    <p v-else-if="line.type === 'status'" class="shell-status" style="white-space: pre-wrap;">
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
  line-height: 1.4;
  overflow-x: auto;
  box-shadow: inset 0 0 8px rgba(0, 0, 0, 0.5);
}

.shell-item {
  margin-bottom: 6px;
  padding-bottom: 6px;
  border-bottom: 1px solid #3c3c3c;
}

.shell-item-last {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: 1px solid #3c3c3c;
}

.shell-info {
  color: #569cd6;
  margin: 2px 0;
}

.shell-prompt {
  color: #4ec9b0;
  font-weight: bold;
  margin-right: 8px;
}

.shell-command-block {
  margin: 4px 0;
  padding-left: 12px;
  border-left: 2px solid #3c3c3c;
}

.shell-command {
  color: #ce9178;
  margin: 2px 0;
  font-weight: 500;
}

.shell-result {
  color: #6a9955;
  margin: 2px 0;
  padding-left: 20px;
}

.shell-status {
  color: #dcdcaa;
  margin-top: 2px;
  margin-bottom: 2px;
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
