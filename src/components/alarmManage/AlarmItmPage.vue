<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 告警列表界面组件：显示详细的告警信息列表
 * @date： 2025-12-08 09:45:07
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-08 09:45:07
 */
import { closeAlert, getUserGroup, searchData, creatOrder } from '@/api/interface.js'
import { convertAlarmDataToTreeOptimized, loadLazyChildren } from '@/utils/treeData.js'
import { Edit, Plus, Minus } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { computed, nextTick, ref, onMounted, watch, onUnmounted } from 'vue'
import {
  tableRef,
  loading,
  currentPage,
  selectedRows,
  selectedEventIds,
  DialogVisibleClose,
  handleOpinion,
  tableData,
  messageInstance,
  blinkTrigger,
  sortSeverity,
  handleSortChange, dataDictionary, user, orderModel, refresh, isFilter, searchQuery, isAggregate
} from '@/utils/publicData.js'

/**
 * 初始化表格数据：获取当前查询参数下的告警列表数据，此时数据还未渲染到表格，仅仅是保存在数组中，后续将通过currentPage计算属性进行分页处理
 * @returns {Promise<void>}
 */
const initTableData = async () => {
  try {
    // 获取所有数据
    const allData = await searchData(searchQuery.value)
    // 对所有数据进行排序
    const sortedData = allData.sort(sortSeverity)

    if (isAggregate.value) {
      // 聚合模式：转换为树形数据
      tableData.value = convertAlarmDataToTreeOptimized(sortedData)
      // 如果不是懒加载模式，对子节点进行排序
      tableData.value.forEach(rootNode => {
        if (rootNode.children && rootNode.children.length > 0) {
          rootNode.children.sort((a, b) => (a.index || 0) - (b.index || 0))
        }
      })
    } else {
      // 非聚合模式：使用原始数据
      tableData.value = sortedData
    }
  } catch (error) {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.error({
      message: error.message,    // 错误信息内容
      duration: 1000,        // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,   // 垂直偏移量，使消息垂直居中
      onClose: () => {       // 消息关闭时的回调
        messageInstance.value = null    // 清空消息实例引用
      }
    })
  }
}

// 懒加载子节点的处理函数
const loadTreeNode = (row, treeNode, resolve) => {
  console.log('加载子节点:', row.event_id)

  // 模拟异步加载延迟
  setTimeout(() => {
    try {
      // 获取缓存的子节点数据
      const children = loadLazyChildren(row)

      if (children && children.length > 0) {
        // 对子节点进行排序
        const sortedChildren = [...children].sort((a, b) => {
          // 按严重级别和时间排序
          const severityOrder = { "严重": 2, "一般": 1 }
          const severityDiff = severityOrder[b.severity] - severityOrder[a.severity]
          if (severityDiff !== 0) return severityDiff

          return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
        })

        console.log(`加载了 ${sortedChildren.length} 个子节点`)
        resolve(sortedChildren)
      } else {
        resolve([])
      }
    } catch (error) {
      console.error('加载子节点失败:', error)
      resolve([])
    }
  }, 300) // 300ms 模拟网络延迟
}
// 监听 isAggregate 变化，自动重新加载数据
watch(isAggregate, async (newVal, oldVal) => {

  if (newVal === oldVal) return
  globalLoading.value = true
  try {
    // 清除展开状态
    clearExpandStates()
    await initTableData()
    // 重置到第一页
    currentPage.value = 1

    // 等待DOM更新完成后重新同步状态
    await nextTick()
    syncExpandStates()
    await new Promise(resolve => setTimeout(resolve, 500))
  }
  catch (error) {
    console.error('聚合模式切换失败:', error)
  }
  finally {
    globalLoading.value = false
  }
})
// 创建全局加载状态
const globalLoading = ref(false)


// 聚合开关的处理函数
const handleAggregateChange = async () => {
  // 立即显示全局加载状态
  globalLoading.value = true
  // 立即显示加载状态
  loading.value = true
  try {
    // 清除展开状态
    clearExpandStates()

    await initTableData()
    currentPage.value = 1
    // 等待DOM更新完成后重新同步状态
    await nextTick()
    syncExpandStates()
    // 确保有足够的加载时间让用户感知
    await new Promise(resolve => setTimeout(resolve, 500))
  }
  catch (error) {
    console.error('切换聚合模式失败:', error)
  }
  finally {
    // 同时关闭两种加载状态
    globalLoading.value = false
    loading.value = false
  }
}
// 清除所有展开状态
const clearExpandStates = () => {
  expandedRows.value.clear()
  // 如果使用了Element Plus的树形表格，也需要清除其内部状态
  if (tableRef.value && typeof tableRef.value.setExpandedKeys === 'function') {
    tableRef.value.setExpandedKeys([])
  }
  blinkTrigger.value = false
}

// 同步展开状态
const syncExpandStates = async () => {
  // 重新设置展开状态（如果需要的话）
  // expandedRows.value.forEach(eventId => {
  //   const row = findRowByEventId(tableData.value, eventId)
  //   if (row) {
  //     tableRef.value?.toggleRowExpansion(row, true)
  //   }
  // })
  await nextTick()
  blinkTrigger.value = true
}
// 辅助函数：根据event_id查找行数据
// const findRowByEventId = (data, targetEventId) => {
//   for (const item of data) {
//     if (item.event_id === targetEventId) {
//       return item
//     }
//     if (item.children && item.children.length > 0) {
//       const found = findRowByEventId(item.children, targetEventId)
//       if (found) return found
//     }
//   }
//   return null
// }
onMounted(async () => {
  // 在模版挂载前初始化表格数据，当模版挂载时数据就已经准备好
  await initTableData()
  if (sessionStorage.getItem('user')) {
    user.value = sessionStorage.getItem('user')
    orderModel.value.createUser = user.value
  }
})


// 全选功能函数
const handleSelectAll = () => {
  selectedRows.value = []
  // 调用表格的toggleAllSelection方法，全选当前页所有行
  // ?是可选链操作符，防止 tableRef.value 为 null 或 undefined 时报错
  tableRef.value?.toggleAllSelection()
}

// 反选功能函数
const handleReverseSelection = () => {
  // 获取当前页的所有数据行
  const allRows = currentPageData.value
  // 遍历每一行，切换其选中状态
  allRows.forEach((row) => {
    // 使用tableRef的toggleRowSelection方法切换行选中状态
    // 如果该行不在已选中列表中，则选中它；如果在，则取消选中
    // ?是可选链操作符，防止 tableRef.value 为 null 或 undefined 时报错
    tableRef.value?.toggleRowSelection(row, !selectedRows.value.some((selected) => selected.event_id === row.event_id))
  })
}

// 每页条数：默认为10
const pageSize = ref(10)

// 数组：每页可选显示行数
const pageSizeOptions = [5, 10, 20, 50]

// 计算当前页显示的数据的索引范围
const currentPageData = computed(() => {
  // 计算当前页的起始数据的索引：索引从0开始计算
  const start = (currentPage.value - 1) * pageSize.value
  // 计算当前页的结束数据的索引
  const end = start + pageSize.value
  // 返回当前页的数据的切片
  return tableData.value.slice(start, end)
})

/**
 * 处理每页条数变化
 * @param size - 每页条数
 */
const handleSizeChange = (size) => {
  // 将响应式变量blinkTrigger的值设置为false，用于关闭闪烁效果
  blinkTrigger.value = false
  // 将响应式变量pageSize的值更新为新的每页显示数量
  pageSize.value = size
  // 将响应式变量currentPage的值重置为第一页，currentPage绑定到分页组件的当前页码属性
  currentPage.value = 1
  // 等待DOM更新完成
  nextTick(() => {
    // 将响应式变量blinkTrigger的值设置为true，用于重启闪烁效果，同步闪烁效果
    blinkTrigger.value = true
  })

}

/**
 * 处理页码变化
 * @param page - 分页组件的当前页码
 */
const handleCurrentChange = (page) => {
  // page是分页组件current-change事件传递的参数，表示当前页码
  // 将响应式变量currentPage的值更新为新的页码，currentPage绑定到分页组件的当前页码属性
  currentPage.value = page
}

/**
 * 处理选择变化事件,用于多行关闭时获取当前选中行
 * @param selection - 当前选中行的数组
 */
const handleSelectionChange = (selection) => {
  // selection是表格组件selection-change事件传递的参数，表示当前选中行的数组
  // 将响应式变量selectedRows的值更新为新的选中行数组，selectedRows绑定到表格组件的选中行属性
  selectedRows.value = selection
}

//
/**
 * 使用 nextTick 确保 DOM 更新完成后再执行行选择操作，配合reserve-selection，实现在数据刷新后之前选中的行仍然选中
 * 这个代码块主要用于在表格数据加载后，根据已选中的行 ID 自动勾选对应的表格行
 */
nextTick(() => {
  // 检查是否有选中的行数据
  if (selectedRows.value.length > 0) {
    // 遍历所有选中的行
    selectedRows.value.forEach((row) => {
      // 在表格数据中查找与当前选中行 event_id 相匹配的数据项
      const found = tableData.value.find((item) => item.event_id === row.event_id)
      // 如果找到匹配的数据项
      if (found) {
        // 使用表格引用 toggleRowSelection 方法勾选对应的行
        // 可选链操作符 (?.) 确保在 tableRef.value 不为 null 或 undefined 时才执行方法
        tableRef.value?.toggleRowSelection(found, true)
      }
    })
  }
})

// 《查看》按钮弹出的模态框的显示标识符
const dialogVisibleView = ref(false)

// 《查看》按钮弹出的模态框中当前表格行数据的变量
const currentRow = ref({})

// 《触发工单》按钮弹出的模态框的显示标识符
const dialogVisibleOrder = ref(false)

/**
 * 表格《告警级别》列自定义内容：根据问题严重程度获取对应的颜色代码
 * @param severity - 问题的严重程度，可选值为："严重"、"重要"、"一般"
 * @returns {*|string}- 返回对应的十六进制颜色代码，如果输入不匹配则返回默认颜色
 *
 */
const getSeverityColor = (severity) => {
  // 定义严重程度与颜色的映射关系
  const colorMap = {
    "严重": '#FF0000', // 红色，表示最高优先级
    "重要": '#fa8c16', // 橙色，表示中等优先级
    "一般": '#ffd100', // 黄色，表示较低优先级
    "普通": '#6cbc45', // 黄色，表示较低优先级
  }
  // 返回匹配的颜色代码，如果没有匹配则返回默认灰色
  return colorMap[severity] || '#d9d9d9'
}

/**
 * 表格《告警状态》列自定义内容：根据问题严重程度获取对应的颜色代码
 * @param {string} state - 状态值
 * @returns {string} - 对应的CSS类名
 */
const getStateClass = (state) => {
  const classMap = {
    '未处理': 'status-unprocessed',
    '已分派': 'status-assigned',
    '已关闭': 'status-closed',
  }
  return classMap[state] || 'status-default'
}


/**
 * 表格中《操作》中查看按钮回调函数
 * @param row - 要查看的行数据对象，包含需要展示的详细信息
 */
const handleView = (row) => {
  // row 为表格列传入的当前行变量
  // 将当前选中的行数据保存到响应式变量中
  // 这些数据将被用于查看对话框的内容展示
  currentRow.value = row
  // 打开查看对话框
  dialogVisibleView.value = true
}

/**
 * 表格中《操作》中关闭列按钮回调函数
 * 根据是否有选中的行数据，执行不同的关闭逻辑：
 * 1. 如果有选中的行数据，显示提示消息
 * 2. 如果没有选中的行数据，打开关闭确认模态框
 * @param row - 要关闭的行数据对象
 * @returns {Promise<void>}
 */
const handleClose = async (row) => {
  // 检查是否有选中的行数据
  if (selectedRows.value.length > 0) {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示警告消息，提示用户使用批量关闭
    messageInstance.value = ElMessage.warning({
      message: '已勾选数据，请点击批量关闭', // 提示内容
      duration: 1000,    // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,  // 垂直偏移量，使消息垂直居中
      onClose: () => {    // 消息关闭时的回调
        messageInstance.value = null   // 清空消息实例引用
      }
    })
    return  // 终止函数执行，不打开关闭确认模态框
  }
  // 如果没有选中的行数据，执行以下逻辑：
  // 将当前行数据保存在currentRow中，用于关闭确认模态框中显示
  currentRow.value = row
  // 打开关闭确认模态框
  DialogVisibleClose.value = true
}

/**
 * 表格中《操作》中触发工单按钮回调函数
 * @param row
 */
const handleCreateTicket = (row) => {
  // row 为表格列传入的当前行变量
  // 将当前选中的行数据保存到响应式变量中
  // 这些数据将被用于查看对话框的内容展示
  currentRow.value = row
  // 获取告警事件ID
  orderModel.value.eventId = row.event_id
  orderModel.value.system_name = row.system_name
  // 打开查看对话框
  dialogVisibleOrder.value = true
}
const createTicket = async () => {
  try {
    // 当用户名和密码为空时
    if (orderModel.value.userGroup === '' || orderModel.value.username === '') {
      // 如果已有提示框在显示，先关闭它
      if (messageInstance.value) {
        // 关闭所有消息
        ElMessage.closeAll()
        // 等待消息关闭动画完成
        await new Promise(resolve => setTimeout(resolve, 0));
      }
      messageInstance.value= ElMessage.warning({
        message: '用户组名或用户名不能为空',
        duration: 500,  // 显示持续时间(毫秒)
        offset: window.innerHeight / 2 - 140,  // 垂直偏移量，使消息垂直居中
        onClose: () => {   // 消息关闭时的回调
          messageInstance.value = null   // 清空消息实例引用
        }
      })
      return
    }
    await creatOrder(orderModel.value)
      .then(async () => {
          // 关闭工单模态框
          dialogVisibleOrder.value = false
          // 清空数据模型
          orderModel.value.system_name = ''
          orderModel.value.eventId = ''
          orderModel.value.userGroup = ''
          orderModel.value.username = ''
          orderModel.value.orderHandleOpinion = ''
          // 更新数据
          refresh()
          // 显示成功提示消息
          if (messageInstance.value) {
            // 先关闭所有可能存在的消息
            ElMessage.closeAll()
            // 等待消息关闭动画完成
            await new Promise(resolve => setTimeout(resolve, 0));
          }

          // 显示成功提示
          messageInstance.value = ElMessage.success({
            message: '工单创建成功', // 成功提示内容
            duration: 1000,  // 显示持续时间(毫秒)
            offset: window.innerHeight / 2 - 140,  // 垂直偏移量，使消息垂直居中
            onClose: () => {   // 消息关闭时的回调
              messageInstance.value = null   // 清空消息实例引用
            }
          })
      })
      .catch(async () => {
        // 显示成功提示消息
        if (messageInstance.value) {
          // 先关闭所有可能存在的消息
          ElMessage.closeAll()
          // 等待消息关闭动画完成
          await new Promise(resolve => setTimeout(resolve, 0));
        }

        // 显示成功提示
        messageInstance.value = ElMessage.error({
          message: '工单创建失败', // 成功提示内容
          duration: 1000,  // 显示持续时间(毫秒)
          offset: window.innerHeight / 2 - 20,  // 垂直偏移量，使消息垂直居中
          onClose: () => {   // 消息关闭时的回调
            messageInstance.value = null   // 清空消息实例引用
          }
        })
      })
  }
  catch (e) {
    console.log(e)
  }
}

/**
 * 《关闭》模态框中《确认》按钮回调函数
 *  关闭当前告警的异步函数
 *  处理告警关闭的完整流程：
 *  1. 准备关闭数据（当前行或选中行）
 *  2. 调用关闭接口
 *  3. 更新表格数据
 *  4. 显示操作结果
 * @returns {Promise<void>} - 返回一个Promise，表示异步操作的完成状态
 */
const closeCurrentAlert = async () => {
  try {
    // 单行关闭时将当前行加入到接口保存要关闭的event_id的selectedRows数组中
    // 多行关闭时直接通过表格的selected属性获取选中行。
    if (selectedRows.value.length === 0) {
      selectedRows.value.push(currentRow.value)
    }
    const handleUser = sessionStorage.getItem('user')
    // 调用关闭告警接口
    // 参数：选中的告警ID列表和处理意见
    // await：阻塞代码执行，等待异步函数closeAlert执行完成
    await closeAlert(selectedEventIds.value, handleOpinion.value,handleUser)
    // 根据是否为聚合模式采用不同的数据移除策略
    if (isAggregate.value) {
      // 聚合模式：从树形结构中移除节点
      removeNodesFromTree(tableData.value, selectedEventIds.value)
    } else {
      // 非聚合模式：从平面数组中移除
      removeNodesFromArray(tableData.value, selectedEventIds.value)
    }
    // 清空选中行数组
    selectedRows.value = []
    // 清除表格的选中状态，这样即使旧数据重新被加载进来，也不会保持选择状态
    tableRef.value?.clearSelection()
    // 重置模态框状态，关闭确认对话框
    DialogVisibleClose.value = false
    // 重置处理意见
    handleOpinion.value = ''
    // 显示成功提示消息
    if (messageInstance.value) {
      // 先关闭所有可能存在的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示成功提示
    messageInstance.value = ElMessage.success({
      message: '告警关闭成功', // 成功提示内容
      duration: 1000,  // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,  // 垂直偏移量，使消息垂直居中
      onClose: () => {   // 消息关闭时的回调
        messageInstance.value = null   // 清空消息实例引用
      }
    })
    // 错误处理部分
  } catch (error) {
    if (messageInstance.value) {
      // 如果已有提示框在显示，先关闭它
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.error({
      message: error.message,    // 错误信息内容
      duration: 1000,        // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,   // 垂直偏移量，使消息垂直居中
      onClose: () => {       // 消息关闭时的回调
        messageInstance.value = null    // 清空消息实例引用
      }
    })
  }
}

// 从树形结构中移除节点的辅助函数
const removeNodesFromTree = (treeData, eventIdsToRemove) => {
  for (let i = treeData.length - 1; i >= 0; i--) {
    const node = treeData[i]

    // 如果当前节点需要被移除
    if (eventIdsToRemove.includes(node.event_id)) {
      treeData.splice(i, 1)
      continue
    }

    // 递归处理子节点
    if (node.children && node.children.length > 0) {
      removeNodesFromTree(node.children, eventIdsToRemove)

      // 如果子节点都被移除了，清理空的children数组
      if (node.children.length === 0) {
        delete node.children
      }

      // 更新根节点的统计信息
      if (node.isHostNode) {
        updateRootNodeStatistics(node)
      }
    }
  }
  // 第二步：清理没有子节点的根节点
  cleanupEmptyRootNodes(treeData)
}

// 清理空根节点的函数
const cleanupEmptyRootNodes = (treeData) => {
  for (let i = treeData.length - 1; i >= 0; i--) {
    const node = treeData[i]

    // 如果是根节点且没有子节点，则删除
    if (node.isHostNode && (!node.children || node.children.length === 0)) {
      treeData.splice(i, 1)
    }
  }
}
// 从平面数组中移除节点的辅助函数
const removeNodesFromArray = (arrayData, eventIdsToRemove) => {
  for (let i = arrayData.length - 1; i >= 0; i--) {
    if (eventIdsToRemove.includes(arrayData[i].event_id)) {
      arrayData.splice(i, 1)
    }
  }
}

// 更新根节点统计信息
const updateRootNodeStatistics = (rootNode) => {
  if (rootNode.children && rootNode.children.length > 0) {
    const stats = {
      total: rootNode.children.length,
      critical: rootNode.children.filter(child => child.severity === '严重').length,
      normal: rootNode.children.filter(child => child.severity === '一般').length,
      processed: rootNode.children.filter(child => child.state === '已分派' || child.state === '已关闭').length,
      unprocessed: rootNode.children.filter(child => child.state === '未处理').length,
    }

    rootNode.statistics = stats
    rootNode.alarm_details = `(总计: ${stats.total}, 严重: ${stats.critical}, 一般: ${stats.normal})`

    // 更新根节点的最高级别和最新时间
    rootNode.severity = getHighestSeverity(rootNode.children)
    rootNode.occurrenceTime = getLatestTime(rootNode.children)
  }
}

// 获取最高级别（从 treeData.js 中提取的逻辑）
const getHighestSeverity = (children) => {
  return children.reduce((highest, alarm) => {
    if (alarm.severity === "严重") return "严重"
    if (highest === "严重") return "严重"
    return alarm.severity
  }, "一般")
}

// 获取最新时间（从 treeData.js 中提取的逻辑）
const getLatestTime = (children) => {
  return children.reduce((latest, alarm) => {
    const currentTime = new Date(alarm.occurrenceTime)
    const latestTime = new Date(latest)
    return currentTime > latestTime ? alarm.occurrenceTime : latest
  }, "1970-01-01 00:00:00")
}

// 展开状态管理：使用 Set 数据结构存储已展开行的 event_i，自动去重，查找效率高
const expandedRows = ref(new Set())

// 切换行展开和折叠状态
const toggleRowExpansion = async (row) => {
  // 确保在聚合模式下才处理展开
  if (!isAggregate.value) return
  // 折叠逻辑
  if (expandedRows.value.has(row.event_id)) {
    // 从集合中删除
    expandedRows.value.delete(row.event_id)
    // 调用表格组件收缩方法
    tableRef.value?.toggleRowExpansion(row, false)
  } else {
    // 展开逻辑
    // 展开前先同步图标闪烁状态
    blinkTrigger.value = false
    // 等待DOM更新完成
    await nextTick()
    // 添加到展开集合
    expandedRows.value.add(row.event_id)
    // 调用表格组件展开方法
    tableRef.value?.toggleRowExpansion(row, true)

    // 等待展开完成
    await nextTick()
    // 展开后重新图标同步
    blinkTrigger.value = true
  }
}
// 检查行是否展开
const isRowExpanded = (row) => {
  return expandedRows.value.has(row.event_id)
}


// 聚合模式下计算子节点的独立序号
// const getChildNodeIndex = (row) => {
//   // 非聚合模式直接返回空字符串
//   if (!isAggregate.value) return ''
//
//   // 获取当前页的展平数据（包含所有节点）
//   const flattenedData = []
//
//   const flattenTree = (nodes) => {
//     nodes.forEach(node => {
//       // 将当前节点加入数组
//       flattenedData.push(node)
//       if (node.children && node.children.length > 0) {
//         // 递归处理子节点
//         flattenTree(node.children)
//       }
//     })
//   }
//   // 展平当前页的所有数据
//   flattenTree(currentPageData.value)
//
//   // 只为子节点分配序号
//   let childIndex = 1
//   for (let i = 0; i < flattenedData.length; i++) {
//     const currentNode = flattenedData[i]
//
//     // 跳过根节点
//     if (currentNode.children && currentNode.children.length > 0) {
//       continue
//     }
//
//     // 找到目标子节点
//     if (currentNode.event_id === row.event_id) {
//       return childIndex
//     }
//
//     // 子节点序号递增
//     childIndex++
//   }
//
//   return ''
// }
// 在组件卸载时清理状态
// const getChildNodeIndex = (row) => {
//   // 非聚合模式直接返回空字符串
//   if (!isAggregate.value) return ''
//
//   // 找到当前行所属的根节点
//   const findRootNode = (data, targetRow) => {
//     for (const node of data) {
//       if (node.children && node.children.length > 0) {
//         // 检查目标行是否在当前根节点的子节点中
//         if (node.children.some(child => child.event_id === targetRow.event_id)) {
//           return node
//         }
//         // 递归检查子节点
//         const found = findRootNode(node.children, targetRow)
//         if (found) return found
//       }
//     }
//     return null
//   }
//
//   // 在当前页数据中找到根节点
//   const rootNode = findRootNode(currentPageData.value, row)
//
//   if (!rootNode || !rootNode.children) {
//     return ''
//   }
//
//   // 在当前根节点的子节点中计算序号（从1开始）
//   let childIndex = 1
//   for (const child of rootNode.children) {
//     if (child.event_id === row.event_id) {
//       return childIndex
//     }
//     childIndex++
//   }
//
//   return ''
// }
// 优化聚合模式下子节点序号计算（支持懒加载）
const getChildNodeIndex = (row) => {
  // 非聚合模式直接返回空字符串
  if (!isAggregate.value) return ''

  // 检查是否为根节点
  if (row.hasChildren) {
    return ''
  }

  // 在整个表格数据中查找包含该子节点的根节点
  // 使用递归方式在整个树结构中查找
  const findRootNodeWithChild = (data, targetEventId) => {
    for (const node of data) {
      // 检查当前节点是否为根节点且包含目标子节点
      if (node.hasChildren) {
        // 检查已加载的子节点
        if (node.children && node.children.some(child => child.event_id === targetEventId)) {
          return { rootNode: node, children: node.children }
        }
        // 检查缓存的子节点（未展开的情况）
        if (node._cachedChildren && node._cachedChildren.some(child => child.event_id === targetEventId)) {
          return { rootNode: node, children: node._cachedChildren }
        }
      }

      // 递归检查已展开的子节点树结构
      if (node.children && node.children.length > 0) {
        const result = findRootNodeWithChild(node.children, targetEventId)
        if (result) return result
      }
    }
    return null
  }

  // 在完整的表格数据中查找（而不仅仅是当前页）
  const result = findRootNodeWithChild(tableData.value, row.event_id)

  if (!result || !result.children) {
    console.warn('未找到子节点的父节点:', row.event_id)
    return ''
  }

  // 在找到的子节点数组中计算序号（从1开始）
  let childIndex = 1
  for (const child of result.children) {
    if (child.event_id === row.event_id) {
      return childIndex
    }
    childIndex++
  }

  return ''
}
onUnmounted(() => {
  clearExpandStates()
})
</script>

<template>
  <div class="item-page-container">

    <!--  全选/反选按钮-->
    <div style="display: flex; justify-content: space-between; align-items: center;">
      <!--  全选/反选按钮-->
      <div style="display: flex; align-items: center;">
        <el-button type="primary" @click="handleSelectAll">全选</el-button>
        <el-button type="primary" @click="handleReverseSelection">反选</el-button>
      </div>
      <el-switch
        v-model="isAggregate"
        class="ml-2"
        inline-prompt
        width="60"
        active-text="聚合"
        inactive-text="不聚合"
        @change="handleAggregateChange"
      />
    </div>
    <!-- 表格 -->
    <div class="table-container">
      <!-- 全局加载遮罩 -->
      <div v-if="globalLoading" class="global-loading-overlay">
        <div class="loading-content">
          <div class="loading-text">正在切换表格模式...</div>
        </div>
      </div>
      <el-table
        v-if="!globalLoading"
        ref="tableRef"
        :data="currentPageData"
        border
        stripe
        style="width: 100%; font-size: 13px;"
        :cell-style="{ textAlign: 'center' }"
        :header-cell-style="{ textAlign: 'center' }"
        row-key="event_id"
        :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
        @selection-change="handleSelectionChange"
        @sort-change="handleSortChange"
        v-loading="loading"
        lazy
        :load="loadTreeNode"
      >
        <el-table-column type="selection" reserve-selection min-width="2%" :resizable="false" />
<!--        <el-table-column prop="ID" label="聚合" min-width="4%" :resizable="false" />-->
        <!-- 自定义展开列 -->
        <el-table-column v-if="isAggregate" label="聚合" min-width="4%" :resizable="false">
          <template #default="{ row }">
            <div class="expand-column" @click.stop="toggleRowExpansion(row)">
              <el-button
                v-if="row.hasChildren"
                :icon="isRowExpanded(row) ? Minus : Plus"
                circle
                size="small"
                class="expand-btn"
                :class="{ 'expanded': isRowExpanded(row) }"
              />
              <div v-else class="empty-expand"></div>
            </div>
          </template>
        </el-table-column>
<!--        <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" min-width="4%" :resizable="false" />-->
        <el-table-column label="序号" min-width="5%" :resizable="false">
          <template #default="{ row, $index }">
            <span
              :class="{ 'root-node-index': isAggregate && row.hasChildren }"
              :style="{
                  backgroundColor: isAggregate && row.hasChildren ? '#409eff' : 'transparent',
                  color: isAggregate && row.hasChildren ? 'white' : 'inherit',
                  padding: isAggregate && row.hasChildren ? '2px 6px' : '0',
                  borderRadius: isAggregate && row.hasChildren ? '4px' : '0'
              }"
            >
              <span v-if="isAggregate">
                <!-- 聚合模式：根节点显示子节点个数，子节点显示独立序号 -->
                <span v-if="row.hasChildren">
                  {{ row._cachedChildren ? row._cachedChildren.length : (row.children ? row.children.length : 0) }}
                </span>
                <span v-else>
                  {{ getChildNodeIndex(row) }}
                </span>
              </span>
              <span v-else>
                <!-- 非聚合模式：正常序号 -->
                {{ (currentPage - 1) * pageSize + $index + 1 }}
              </span>
            </span>
          </template>
        </el-table-column>

        <el-table-column prop="event_id" label="事件ID" v-if="false" />
        <el-table-column prop="severity" label="级别" :sortable="isAggregate ? false : 'custom'" min-width="5%" :resizable="false">
          <template #default="scope">
          <span
            class="severity-indicator"
            :class="{ 'severity-blink': blinkTrigger && scope.row.severity === '严重' }"
            :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"
          ></span>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="5%" :resizable="false">
          <template #default="{row}">
              <span :class="getStateClass(row.state)">{{ row.state }}</span>
          </template>
        </el-table-column>>
        <el-table-column prop="system_name" label="业务系统" show-overflow-tooltip min-width="10%" :resizable="false">
        <template #default="{row}">
          {{ row.system_name || '/' }}
        </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" show-overflow-tooltip min-width="5%" :resizable="false">
          <template #default="{row}">
            {{ row.category || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="object" label="主机名" min-width="16%" show-overflow-tooltip :resizable="false">
          <template #default="{row}">
            <el-button type="primary" class="truncate-button" plain @click="handleView(row)" style="max-width: 100%; overflow: hidden;">
              {{ row.object || '/' }}
            </el-button>
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP地址" show-overflow-tooltip min-width="8%" :resizable="false">
          <template #default="{row}">
            {{ row.ip || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="alarm_details" label="告警描述" show-overflow-tooltip :min-width="isAggregate ? '20%' : '24%'" :resizable="false">
          <template #default="{row}">
            {{ row.alarm_details || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.occurrenceTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.processingTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="operation" label="操作" min-width="5%" :resizable="false">
<!--          <template #default="scope">-->
<!--            <div class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center; user-select: none;">-->
<!--              <el-dropdown trigger="click">-->
<!--                <el-button type="primary" :icon="Edit"></el-button>>-->
<!--                <template #dropdown>-->
<!--                  <el-dropdown-menu style="user-select: none">-->
<!--                    <el-dropdown-item @click="handleView(scope.row)" style="color: #409EFF;font-weight: bold" >查看</el-dropdown-item>-->
<!--                    <el-dropdown-item v-if="scope.row.state === '已关闭'" disabled @click="handleClose(scope.row)">关闭</el-dropdown-item>-->
<!--                    <el-dropdown-item v-else @click="handleClose(scope.row)" style="color: #409EFF;font-weight: bold">关闭</el-dropdown-item>-->
<!--                    <el-dropdown-item v-if="scope.row.state === '已关闭' || scope.row.state === '已分派'" disabled @click="handleCreateTicket(scope.row)">触发工单</el-dropdown-item>-->
<!--                    <el-dropdown-item v-else @click="handleCreateTicket(scope.row)" style="color: #409EFF;font-weight: bold">触发工单</el-dropdown-item>-->
<!--                  </el-dropdown-menu>-->
<!--                </template>-->
<!--              </el-dropdown>-->
<!--            </div>-->
<!--          </template>-->
          <template #default="scope">
            <div class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center; user-select: none;">
              <el-dropdown trigger="click">
                <el-button
                  type="primary"
                  :icon="Edit"
                  :disabled="isAggregate && scope.row.children && scope.row.children.length > 0"
                >
                </el-button>
                <template #dropdown>
                  <el-dropdown-menu style="user-select: none">
                    <el-dropdown-item
                      @click="handleView(scope.row)"
                      style="color: #409EFF;font-weight: bold"
                    >
                      查看
                    </el-dropdown-item>
                    <el-dropdown-item
                      v-if="scope.row.state === '已关闭'"
                      disabled
                      @click="handleClose(scope.row)"
                    >
                      关闭
                    </el-dropdown-item>
                    <el-dropdown-item
                      v-else
                      @click="handleClose(scope.row)"
                      style="color: #409EFF;font-weight: bold"
                    >
                      关闭
                    </el-dropdown-item>
                    <el-dropdown-item
                      v-if="scope.row.state === '已关闭' || scope.row.state === '已分派'"
                      disabled
                      @click="handleCreateTicket(scope.row)"
                    >
                      触发工单
                    </el-dropdown-item>
                    <el-dropdown-item
                      v-else
                      @click="handleCreateTicket(scope.row)"
                      style="color: #409EFF;font-weight: bold"
                    >
                      触发工单
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </div>
    <!-- 下方分页：显示总数、每页条数、页码导航 -->
    <div style="display: flex; justify-content: space-between; align-items: center;user-select:none;">
      <!--  显示总数  -->
      <div style="display: flex; align-items: center;">
        <span style="line-height: 20px">共 {{ tableData.length }} 条</span>
      </div>
      <div style="display: flex; align-items: center;">
        <!--  每页条数  -->
        <div style="display: flex; align-items: flex-start; margin-right: 10px; user-select: none">
          <el-select v-model="pageSize" style="width: 70px; margin: 0" @change="handleSizeChange">
            <el-option v-for="item in pageSizeOptions" :key="item" :label="item" :value="item" />
          </el-select>
          <span style="line-height: 32px;margin-left: 10px;">条/页</span>
        </div>
        <!--  页码导航  -->
        <div style="display: flex; align-items: center;">
          <el-pagination
            background
            v-model:current-page="currentPage"
            :page-size="pageSize"
            :total="tableData.length"
            layout="prev, pager, next"
            @current-change="handleCurrentChange"
          />
        </div>
      </div>
    </div>
    <!--    查看按钮模态框  -->
    <el-dialog
      v-model="dialogVisibleView"
      top="15%" title="告警详情"
      width="80%"
      center
      style="user-select: text"
      destroy-on-close
      @close="() => { dialogVisibleView = false }"
    >
      <el-table
        :data="[currentRow]"
        border
        :cell-style="{ textAlign: 'center', verticalAlign: 'middle', padding: '8px 0' }"
        :header-cell-style="{ textAlign: 'center' }"
      >
        <el-table-column prop="event_id" label="事件ID" min-width="10%"/>
        <el-table-column prop="severity" label="级别" min-width="5%" :resizable="false">
          <template #default="scope">
            <span
              class="severity-indicator"
              :class="{ 'severity-blink': scope.row.severity === '严重' }"
              :style="{ backgroundColor: getSeverityColor(scope.row.severity) }"
            ></span>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="5%" :resizable="false">
          <template #default="{row}">
            <span :class="getStateClass(row.state)">{{ row.state }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="system_name" label="业务系统" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.system_name || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" min-width="5%" :resizable="false">
          <template #default="{row}">
            {{ row.category || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="object" label="主机名" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.object || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP地址" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.ip || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="alarm_details" label="告警描述" min-width="20%" :resizable="false">
          <template #default="{row}">
            {{ row.alarm_details || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.occurrenceTime || '/' }}
          </template>
        </el-table-column>
        <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false">
          <template #default="{row}">
            {{ row.processingTime || '/' }}
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>
    <!-- 关闭按钮模态框 -->
    <el-dialog
      v-model="DialogVisibleClose"
      top="10%" title="关闭告警"
      width="30%"
      center
      :show-close="false"
      @close="() => { handleOpinion = ''; DialogVisibleClose = false }"
    >
      <div style="font-size: 20px; color: #606266; user-select: none">处理意见：</div>
      <div style="display: flex; align-items: center; justify-content: center; margin-bottom: 15px; margin-top: 5px">
        <el-input
          v-model="handleOpinion"
          style="width: 100%; font-size: 16px"
          type="textarea"
          :autosize="{ maxRows: 10, minRows: 5 }"
          resize="none"
          placeholder="请输入……"
          maxlength="100"
          show-word-limit
        />
      </div>
      <div style="display: flex; align-items: center; justify-content: flex-end; margin-top: 10px">
        <el-button type="primary" @click="handleOpinion = ''">清空</el-button>
        <el-button type="primary" @click="closeCurrentAlert">确认</el-button>
        <el-button
          type="primary"
          @click="
            DialogVisibleClose = false;
            handleOpinion = ''
          "
        >取消</el-button>
      </div>
    </el-dialog>
    <!-- 触发工单按钮模态框 -->
    <el-dialog
      v-model="dialogVisibleOrder"
      top="10%"
      title="触发工单"
      width="30%"
      center
      :show-close="false"
      @close="() => { orderModel.system_name = '';orderModel.eventId = '';orderModel.userGroup = '';orderModel.username ='';orderModel.orderHandleOpinion = '';dialogVisibleOrder = false}"
    >
      <el-form
        :inline="true"
        :model="orderModel"
        style=" display: flex;align-items: center;flex-wrap: wrap;user-select: none"
      >
        <div style="display: flex; justify-content: space-between; width: 100%">
          <el-form-item label="用户组名" prop="userGroup">
            <el-select v-model="orderModel.userGroup" class="center-placeholder" :filterable="isFilter" clearable placeholder="请选择" style="width: 150px" @change="orderModel.username = '';dataDictionary.username = []" @visible-change="(visible) => {isFilter = visible;getUserGroup(visible, '用户组')}" @clear="orderModel.userGroup = '';orderModel.username = '';dataDictionary.userGroup = [];dataDictionary.username = []">
              <el-option v-for="(item, index) in dataDictionary.userGroup" :key="index" :value="item" />
            </el-select>
          </el-form-item>
          <el-form-item label="用户名" prop="username">
            <el-select v-model="orderModel.username" class="center-placeholder" :filterable="isFilter" clearable placeholder="请选择" style="width: 150px"  @visible-change="(visible) => {isFilter = visible;getUserGroup(visible, '用户')}" @clear="orderModel.username = '';dataDictionary.username = []">
              <el-option v-for="(item, index) in dataDictionary.username" :key="index" :label="item[1]" :value="item[0]" />
            </el-select>
          </el-form-item>
        </div>
        <el-form-item label="处理意见" prop="orderHandleOpinion" style="width: 100%">
          <div style="display: flex; flex: 1;align-items: center; justify-content: center; margin-bottom: 15px; margin-top: 5px">
            <el-input
              v-model="orderModel.orderHandleOpinion"
              style="font-size: 16px;width: 100%"
              type="textarea"
              :autosize="{ maxRows: 10, minRows: 5 }"
              resize="none"
              placeholder="请输入……"
              maxlength="100"
              show-word-limit
            />
          </div>
        </el-form-item>
        <el-form-item style="flex: none;margin-left: auto;margin-right: 5px;">
          <div style="display: flex;justify-content: flex-end;gap: 10px;flex-wrap: nowrap;">
            <el-button type="primary" @click="orderModel.orderHandleOpinion = ''">清空</el-button>
            <el-button type="primary" @click="createTicket">确认</el-button>
            <el-button
              type="primary"
              @click="
                dialogVisibleOrder = false;
                // 清空数据模型
                orderModel.value.system_name = ''
                orderModel.value.eventId = ''
                orderModel.value.userGroup = ''
                orderModel.value.username = ''
                orderModel.value.orderHandleOpinion = ''
                "
            >取消</el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-dialog>
  </div>

</template>

<style scoped>
/* 表格容器父容器样式 */
.item-page-container {
  display: flex;
  height: 85%;
  flex-direction: column;
  box-sizing: border-box;
  position: relative;  /* 添加相对定位,用于切换聚合模式时遮罩层定位 */
}

/* 表格容器样式：防止表格行多时溢出 */
.table-container {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  padding: 20px 0;
  position: relative; /* 添加相对定位,用于切换聚合模式时遮罩层定位 */
}

/* 告警图形样式和闪烁动画 */
.severity-indicator {
  display: inline-block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  vertical-align: middle;
  transition: all 0.5s ease;
  margin: 5px 0;
}
.severity-blink {
  animation: blink 0.5s infinite;
}
@keyframes blink {
  0%,100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.3;
    transform: scale(1.4);
    filter: brightness(1);
  }
}
/* 告警状态颜色 */
.status-unprocessed {
  color: #909399; /* 未处理 - 蓝色 */
  background-color: transparent !important;
}
.status-closed {
  color: #67C23A; /* 已处理 - 绿色 */
  background-color: transparent !important;
}
.status-assigned {
  color: #E6A23C; /* 已分配 - 黄色 */
  background-color: transparent !important;
}
.status-default {
  color: #909399; /* 默认状态 - 灰色 */
  background-color: transparent !important;
}
/* 表格行样式 */
:deep(.el-table__body tr) {
  transition: background-color 0.3s ease;
}
/* 表格行hover样式 */
:deep(.el-table__body tr:hover > td) {
  background-color: inherit !important;
}

/* 操作列按钮样式 */
.operation-buttons {
  display: flex;
  gap: 2px;
  white-space: nowrap;
  align-items: center;
}

.operation-buttons :deep(.el-button) {
  padding: 5px 8px;
  margin: 0;
}

/* 模态框title标题颜色 */
:deep(.el-dialog__title) {
  user-select: none;
  color: #409eff; /* 可以根据需要调整颜色值 */
}

/* 关闭按钮告警模态框样式 */
:deep(.el-dialog__header) {
  border-bottom: 1px solid #dcdfe6;
  margin-bottom: 0;
}

:deep(.el-dialog__body) {
  padding-top: 20px;
}

:deep(.el-textarea__inner) {
  border-color: #409eff;
}

/* 禁止表头文本选中 */
:deep(.el-table__header-wrapper th) {
  user-select: none;
}
/* 设置表头字体颜色为黑色 */
:deep(.el-table__header-wrapper th .cell) {
  font-size: 13px;
  color: black !important;
}

/* 设置每页条数选项文本居中 */
:deep(.el-select-dropdown__item) {
  text-align: center;
}

/* 设置每页条数选项文本居中 */
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
/* 下拉框光标居中 */
.centerPlaceholder :deep(.el-select__wrapper) {
  justify-content: center;
}

.centerPlaceholder :deep(.el-select__selected-item) {
  text-align: center;
  width: 100%;
}

.centerPlaceholder :deep(.el-select__input) {
  text-align: center !important;
  width: 100%;
}

.centerPlaceholder :deep(.el-select__input.is-focus) {
  text-align: center !important;
}


/* 自定义展开列样式 */
.expand-column {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 80%;
  cursor: pointer;
}

.expand-btn {
  transition: all 0.3s ease;
  border: 1px solid #dcdfe6;
}

.expand-btn:hover {
  background-color: #ecf5ff;
  border-color: #409eff;
}

.expand-btn.expanded {
  background-color: #409eff;
  border-color: #409eff;
  color: white;
}

.empty-expand {
  width: 20px;
  height: 20px;
}

/* 隐藏默认的展开图标 */
:deep(.el-table__expand-icon) {
  display: none !important;
}

/* 聚合模式下根节点序号样式 */
.root-node-index {
  background-color: #409eff !important;
  color: white !important;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: bold;
}
/* 全局加载遮罩样式 */
.global-loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(255, 255, 255, 0.9);
  z-index: 1000;
  display: flex;
  justify-content: center;
  align-items: center;
  backdrop-filter: blur(2px);
}

.loading-content {
  text-align: center;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  min-width: 300px;
}

.loading-text {
  margin-top: 10px;
  color: #6cbc45;
  font-size: 15px;
}
</style>
