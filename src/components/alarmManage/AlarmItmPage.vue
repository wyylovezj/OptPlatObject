<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 告警列表界面组件：显示详细的告警信息列表
 * @date： 2025-12-08 09:45:07
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-08 09:45:07
 */
import { closeAlert, getUserGroup, searchData, creatOrder, suspendAlarm, unSuspendAlarm } from '@/api/interface.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { convertAlarmDataToTreeOptimized, loadLazyChildren } from '@/utils/treeData.js'
import { Edit, Plus, Minus, Search } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, nextTick, ref, onMounted, watch, onUnmounted, h } from 'vue'
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
  handleSortChange,
  dataDictionary,
  user,
  orderModel,
  refresh,
  isFilter,
  searchQuery,
  isAggregate,
  sortRootNodes,
  debounce,
  lastScrollTop,
  startIndex,
} from '@/utils/publicData.js'
import * as XLSX from 'xlsx'

// 权限状态管理
const permissionStore = usePermissionStore()
// 每页条数：默认为10
const pageSize = ref(10)

// 前端本地搜索（不向后端发送请求，在已获取的数据中检索）
const localSearchText = ref('')

// 清空本地搜索
const clearLocalSearch = () => {
  localSearchText.value = ''
}

// 过滤后的显示数据：在 tableData 基础上按本地搜索关键字进行模糊检索
const displayData = computed(() => {
  const keyword = localSearchText.value.trim().toLowerCase()
  if (!keyword) return tableData.value

  return tableData.value.filter(row => {
    if (row.__spacer__) return true

    if (isAggregate.value && row.hasChildren) {
      // 聚合模式：根节点自身字段匹配 或 任意子节点匹配
      const rootMatch = matchesRow(row, keyword)
      const children = row.children || row._cachedChildren || []
      const childMatch = children.some(child => matchesRow(child, keyword))
      return rootMatch || childMatch
    }

    return matchesRow(row, keyword)
  })
})

// 判断单行数据是否匹配搜索关键字
const matchesRow = (row, keyword) => {
  if (!row || row.__spacer__) return false
  const fields = [
    row.event_id, row.alarm_details, row.severity, row.state,
    row.system_name, row.category, row.object, row.ip,
    row.occurrenceTime, row.processingTime, row.source, row.alart_remarks
  ]
  return fields.some(field => field && String(field).toLowerCase().includes(keyword))
}

// 搜索文本变化时重置分页到第一页
watch(localSearchText, () => {
  currentPage.value = 1
  startIndex.value = 0
})

// 高亮搜索匹配文本：将关键字在文本中的匹配部分用 <mark> 标签包裹
const highlightText = (text) => {
  if (!text) return '-'
  const keyword = localSearchText.value.trim()
  if (!keyword) return String(text)
  // 转义 HTML 特殊字符防止 XSS
  const escapeHtml = (str) => str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const escapedText = escapeHtml(String(text))
  // 转义正则特殊字符
  const escapedKeyword = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const regex = new RegExp(`(${escapedKeyword})`, 'gi')
  return escapedText.replace(regex, '<mark class="search-highlight">$1</mark>')
}

// JS 驱动的全局同步闪烁：所有严重告警圆点绑定同一个 opacity 值，避免 CSS animation 因 DOM 重建导致闪烁不同步
const blinkOpacity = ref(1)
let blinkTimer = null
const startBlinkTimer = () => {
  if (blinkTimer) return
  blinkTimer = setInterval(() => {
    blinkOpacity.value = blinkOpacity.value === 1 ? 0.2 : 1
  }, 500)
}
const stopBlinkTimer = () => {
  if (blinkTimer) {
    clearInterval(blinkTimer)
    blinkTimer = null
    blinkOpacity.value = 1
  }
}
// 组件挂载时启动闪烁定时器
startBlinkTimer()

// 批量关闭功能
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

// 导出功能
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
// 计算当前页显示的数据的索引范围
const currentPageData = computed(() => {
  // 计算当前页的起始数据的索引：索引从0开始计算
  const start = (currentPage.value - 1) * pageSize.value
  // 计算当前页的结束数据的索引
  const end = start + pageSize.value
  // 返回当前页的数据的切片
  console.log('end', new Date().getTime())
  return displayData.value.slice(start, end)
})
// 虚拟滚动相关变量
const rowHeight = 45 // 每行高度（包括边框），根据实际测量调整

// 动态计算可见行数：根据表格容器实际高度 ÷ 行高 + 缓冲，避免写死导致底部行渲染不到
const getVisibleRowCount = () => {
  const tableEl = tableRef.value?.$el
  if (tableEl) {
    const bodyWrapper = tableEl.querySelector('.el-table__body-wrapper')
    const viewportHeight = bodyWrapper?.clientHeight || tableEl.clientHeight || 540
    return Math.ceil(viewportHeight / rowHeight) + 3 // +3 作为缓冲，防止行高微小偏差导致末尾行缺失
  }
  return 15 // 默认值（兼容 DOM 未就绪时）
}

// 计算需要渲染的数据片段（仅用于非聚合模式）
const virtualData = computed(() => {
  // 计算当前页的起始数据的索引：索引从0开始计算
  const start = (currentPage.value - 1) * pageSize.value
  // 计算当前页的结束数据的索引
  const end = start + pageSize.value

  // 当 pageSize <= 10 时，渲染所有数据（不启用虚拟滚动）
  if (pageSize.value <= 10) {
    return displayData.value.slice(start, end)
  }

  // 当 pageSize > 10 时，启用虚拟滚动，只渲染可视区域 + 缓冲行数
  // startIndex.value 表示当前可视区域的起始索引（相对于当前页）
  const visibleCount = getVisibleRowCount()
  const renderStart = start + startIndex.value
  const renderEnd = Math.min(renderStart + visibleCount, end)

  return displayData.value.slice(renderStart, renderEnd)
})

// 计算带空白行的虚拟数据（用于保持滚动条高度）
const virtualDataWithSpacers = computed(() => {
  if (!isAggregate.value && pageSize.value > 10) {
    const result = []

    // 添加前置空白行
    if (startIndex.value > 0) {
      result.push({ __spacer__: true, __height__: startIndex.value * rowHeight })
    }

    // 添加实际数据
    result.push(...virtualData.value)

    // 添加后置空白行
    const start = (currentPage.value - 1) * pageSize.value
    const totalRows = Math.min(pageSize.value, displayData.value.length - start)
    const renderedRows = virtualData.value.length
    const remainingRows = totalRows - startIndex.value - renderedRows

    if (remainingRows > 0) {
      result.push({ __spacer__: true, __height__: remainingRows * rowHeight })
    }

    return result
  }
  return virtualData.value
})

// 处理表格滚动事件
const handleTableScroll = (event) => {
  if (!isAggregate.value && pageSize.value > 10) {
    // 从事件对象中获取scrollTop
    const scrollTop = event.target?.scrollTop || event.scrollTop || 0

    // 计算新的起始索引（相对于当前页的偏移量）
    const newIndex = Math.floor(scrollTop / rowHeight)

    // 计算最大允许的起始索引（确保不会超出范围）
    const visibleCount = getVisibleRowCount()
    const maxStartIndex = Math.min(pageSize.value, displayData.value.length - (currentPage.value - 1) * pageSize.value) - visibleCount

    // 限制起始索引在合理范围内
    const clampedIndex = Math.max(0, Math.min(newIndex, maxStartIndex))

    // 只有当索引发生变化时才更新
    if (clampedIndex !== startIndex.value) {
      startIndex.value = clampedIndex

      // 关键修改：在数据更新前关闭闪烁，更新后再开启，确保同步
      blinkTrigger.value = false
      nextTick(() => {
        blinkTrigger.value = true
      })
    }
  }
}

// 获取真实行索引（用于序号显示）
const getRealRowIndex = (row) => {
  if (!row || row.__spacer__) return ''

  // 在displayData中查找该行的实际索引（支持本地搜索过滤后的数据）
  const realIndex = displayData.value.findIndex(item => item.event_id === row.event_id)

  if (realIndex === -1) return ''

  // 返回从1开始的序号
  return realIndex + 1
}

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
      // 对根节点进行排序（按照级别和发生时间）
      sortRootNodes(tableData.value)
      // // 如果不是懒加载模式，对子节点进行排序
      // tableData.value.forEach(rootNode => {
      //   if (rootNode.children && rootNode.children.length > 0) {
      //     rootNode.children.sort((a, b) => (a.index || 0) - (b.index || 0))
      //   }
      // })
    } else {
      // 非聚合模式：使用原始数据
      tableData.value = sortedData
      // 关键修改：在数据更新前关闭闪烁，更新后再开启，确保同步
      blinkTrigger.value = false
      nextTick(() => {
        blinkTrigger.value = true
      })
    }
  } catch (error) {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.error({
      message: error.message, // 错误信息内容
      duration: 1000, // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
      onClose: () => {
        // 消息关闭时的回调
        messageInstance.value = null // 清空消息实例引用
      },
    })
  }
}

// 监听 isAggregate 变化，自动重新加载数据
watch(isAggregate, async (newVal, oldVal) => {
  if (newVal === oldVal) return
  globalLoading.value = true
  try {
    // 清空当前选择行
    selectedRows.value = []
    tableRef.value?.clearSelection()
    // 清除展开状态
    clearExpandStates()
    await initTableData()
    // 重置到第一页
    currentPage.value = 1

    // 等待DOM更新完成后重新同步状态
    await nextTick()
    syncExpandStates()
    await new Promise((resolve) => setTimeout(resolve, 500))
  } catch (error) {
    console.error('聚合模式切换失败:', error)
  } finally {
    globalLoading.value = false
  }
})
// 创建全局加载状态
const globalLoading = ref(false)

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
  await nextTick()
  blinkTrigger.value = true
}

onMounted(async () => {
  // 在模版挂载前初始化表格数据，当模版挂载时数据就已经准备好
  await initTableData()

  if (sessionStorage.getItem('user')) {
    user.value = sessionStorage.getItem('user')
    orderModel.value.createUser = user.value
  }
})
// 优化的根节点处理函数
const handleOptimizedParentSelection = (parentRow, isSelected) => {
  if (!isAggregate.value) return

  let childNodes = []
  if (parentRow.children && parentRow.children.length > 0) {
    childNodes = parentRow.children
  } else if (parentRow._cachedChildren) {
    childNodes = parentRow._cachedChildren
  }

  console.log(`优化处理父节点 ${parentRow.event_id}: ${isSelected ? '选中' : '取消'} ${childNodes.length} 个子节点`)

  if (childNodes.length === 0) return

  // 准备批量操作
  const operations = []

  if (isSelected) {
    // 选中父节点 -> 批量选中所有子节点
    childNodes.forEach((child) => {
      operations.push({ action: 'select', node: child })
    })
  } else {
    // 取消父节点 -> 批量取消所有子节点
    childNodes.forEach((child) => {
      operations.push({ action: 'deselect', node: child })
    })
  }

  // 执行批量操作
  batchUpdateSelection(operations)
}

// 全选功能函数
const handleSelectAll = async () => {
  if (!isAggregate.value) {
    // 非聚合模式优化逻辑
    const currentSelection = tableRef.value?.getSelectionRows() || []
    const currentPageRows = currentPageData.value

    console.log('非聚合模式全选操作')
    console.log('当前选中行数:', currentSelection.length)
    console.log('当前页总行数:', currentPageRows.length)

    // 判断当前页面的选中状态
    const currentPageSelectedCount = currentPageRows.filter((row) => currentSelection.some((selected) => selected.event_id === row.event_id)).length
    // 检查是否当前页所有行都已选中
    const isCurrentPageFullySelected = currentPageSelectedCount === currentPageRows.length && currentPageRows.length > 0
    if (isCurrentPageFullySelected) {
      // 当前页面所有行都已选中 -> 取消全选
      console.log('取消非聚合全选')
      tableRef.value?.clearSelection()
      selectedRows.value = []
    } else {
      // 当前页面有未选中的行 -> 手动选中所有行
      console.log('执行非聚合全选')
      selectedRows.value = []

      // 先清除当前选择
      tableRef.value?.clearSelection()

      // 手动选中当前页所有行
      currentPageRows.forEach((row) => {
        tableRef.value?.toggleRowSelection(row, true)
      })
    }

    return
  }
  // 获取当前页的所有根节点
  const allRootNodes = currentPageData.value.filter((row) => row.hasChildren)

  // 检查是否有根节点未被展开
  const unexpandedRootNodes = allRootNodes.filter((rootNode) => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  // 聚合模式下的全选逻辑
  const currentSelection = tableRef.value?.getSelectionRows() || []
  const currentPageRows = currentPageData.value

  // 检查是否所有根节点都被选中
  const rootNodes = currentPageRows.filter((row) => row.hasChildren)
  const allRootsSelected = rootNodes.every((root) => currentSelection.some((selected) => selected.event_id === root.event_id))

  if (allRootsSelected && rootNodes.length > 0) {
    // 当前所有根节点都已选中 -> 取消全选
    console.log('取消聚合全选')
    tableRef.value?.clearSelection()
    selectedRows.value = []

    // 收集所有需要取消的子节点
    const cancelOperations = []
    // 确保所有子节点也被取消
    rootNodes.forEach((root) => {
      let childNodes = []
      if (root.children && root.children.length > 0) {
        childNodes = root.children
      } else if (root._cachedChildren) {
        childNodes = root._cachedChildren
      }

      childNodes.forEach((child) => {
        cancelOperations.push({ action: 'deselect', node: child })
      })
    })
    // 使用批量操作取消所有子节点（与直接点击根节点相同的逻辑）
    if (cancelOperations.length > 0) {
      batchUpdateSelection(cancelOperations)
    }
  } else {
    // 执行聚合全选
    console.log('执行聚合全选')
    selectedRows.value = []
    tableRef.value?.toggleAllSelection()
    // 智能同步父子节点状态
    // 使用您现有的优化函数
    nextTick(() => {
      setTimeout(() => {
        rootNodes.forEach((root) => {
          // 先确保根节点被选中
          tableRef.value?.toggleRowSelection(root, true)
          // 重用您现有的优化处理函数
          handleOptimizedParentSelection(root, true)
        })

        // 更新最终状态
        setTimeout(() => {
          if (tableRef.value) {
            selectedRows.value = tableRef.value.getSelectionRows()
          }
        }, 100)
      }, 50)
    })
  }
}

// 反选功能函数
const handleReverseSelection = async () => {
  // 非聚合模式
  if (!isAggregate.value) {
    const allRows = currentPageData.value
    allRows.forEach((row) => {
      tableRef.value?.toggleRowSelection(row, !selectedRows.value.some((selected) => selected.event_id === row.event_id))
    })
    return
  }
  // 获取当前页的所有根节点
  const allRootNodes = currentPageData.value.filter((row) => row.hasChildren)

  // 检查是否有根节点未被展开
  const unexpandedRootNodes = allRootNodes.filter((rootNode) => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })
    return
  }
  // 聚合模式
  const rootNodes = currentPageData.value.filter((row) => row.hasChildren)
  const currentSelection = tableRef.value?.getSelectionRows() || []
  const operations = []
  // 处理根节点反选
  rootNodes.forEach((root) => {
    // 获取根节点和子节点的当前选中状态
    const isRootSelected = currentSelection.some((selected) => selected.event_id === root.event_id)
    const childNodes = root.children || root._cachedChildren || []
    const selectedChildCount = childNodes.filter((child) => currentSelection.some((selected) => selected.event_id === child.event_id)).length
    // 判断当前状态
    const isFullySelected = isRootSelected && selectedChildCount === childNodes.length && childNodes.length > 0
    const isFullyUnselected = !isRootSelected && selectedChildCount === 0
    const isPartiallySelected = selectedChildCount > 0 && selectedChildCount < childNodes.length

    // 根据当前状态决定反选操作
    if (isFullySelected) {
      // 完全选中状态 -> 取消全选（复用根节点点击逻辑）
      console.log('取消根节点全选:', root.event_id)
      tableRef.value?.toggleRowSelection(root, false)
      handleOptimizedParentSelection(root, false)
    } else if (isFullyUnselected) {
      // 完全未选状态 -> 全选（复用根节点点击逻辑）
      console.log('选中根节点全选:', root.event_id)
      tableRef.value?.toggleRowSelection(root, true)
      handleOptimizedParentSelection(root, true)
    } else if (isPartiallySelected) {
      console.log('优化部分选中反选:', root.event_id)

      // 精确反选子节点：已选的取消，未选的选中
      childNodes.forEach((child) => {
        const isChildCurrentlySelected = currentSelection.some((selected) => selected.event_id === child.event_id)

        if (isChildCurrentlySelected) {
          // 当前已选中的子节点 -> 取消选择
          console.log('取消子节点选择:', child.event_id)
          operations.push({ action: 'deselect', node: child })
        } else {
          // 当前未选中的子节点 -> 选中
          console.log('选中子节点:', child.event_id)
          operations.push({ action: 'select', node: child })
        }
      })
      // 执行批量操作
      batchUpdateSelection(operations)
    }
  })

  // 更新选中状态
  setTimeout(() => {
    if (tableRef.value) {
      selectedRows.value = tableRef.value.getSelectionRows()
    }
  }, 100)
}

// 每页条数：默认为10
// const pageSize = ref(10)

// 数组：每页可选显示行数
const pageSizeOptions = [10, 20, 50, 100, 500]

/**
 * 处理每页条数变化
 * @param size - 每页条数
 */
const handleSizeChange = (size) => {
  console.log('start', new Date().getTime())
  // 将响应式变量blinkTrigger的值设置为false，用于关闭闪烁效果
  blinkTrigger.value = false

  // 重置虚拟滚动状态
  startIndex.value = 0
  lastScrollTop.value = 0
  if (tableRef.value && tableRef.value.setScrollTop) {
    tableRef.value.setScrollTop(0)
  }

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
  // 重置虚拟滚动状态
  startIndex.value = 0
  if (tableRef.value && tableRef.value.setScrollTop) {
    tableRef.value.setScrollTop(0)
  }
}

/**
 * 处理选择变化事件,用于多行关闭时获取当前选中行
 * @param selection - 当前选中行的数组
 */
const handleSelectionChange = debounce((selection) => {
  // 防止在同步过程中触发额外的处理
  if (isSyncingSelection) {
    console.log('跳过选择变更处理，正在同步中...')
    return
  }
  // 如果是刚处理完行选择，跳过这次同步（避免与 handleRowSelect 冲突）
  if (isRowSelectProcessing) {
    console.log('跳过选择变更处理，正在处理行选择...')
    return
  }
  // selection是表格组件selection-change事件传递的参数，表示当前选中行的数组
  // 将响应式变量selectedRows的值更新为新的选中行数组，selectedRows绑定到表格组件的选中行属性
  selectedRows.value = selection
  console.log(
    '选择变更:',
    selection.map((row) => row.event_id),
  )
  // 在聚合模式下处理父子节点联动
  if (isAggregate.value) {
    // 延迟执行父子节点同步
    setTimeout(() => {
      syncParentChildSelection()
    }, 100)
  }
}, 100)
// 新增：标记是否正在处理行选择事件
let isRowSelectProcessing = false
// 新增：自定义行选择处理函数
const handleRowSelect = (selection, row) => {
  console.log('行选择事件:', row.event_id, row.hasChildren)
  console.log('行选择事件:', selectedEventIds.value)
  // 设置处理中标志，防止 handleSelectionChange 干扰
  isRowSelectProcessing = true
  // 将响应式变量selectedRows的值更新为新的选中行数组，selectedRows绑定到表格组件的选中行属性
  selectedRows.value = selection

  try {
    // 更新全局选中状态
    // selectedRows.value = selection
    // 在聚合模式下，如果是根节点被选中，需要特殊处理
    if (isAggregate.value) {
      if (row.hasChildren) {
        // 父节点选择处理
        const isSelected = selection.includes(row)
        // 使用优化的处理函数
        handleOptimizedParentSelection(row, isSelected)
      } else {
        // // 子节点选择处理 - 独立处理
        // handleChildNodeSelection(selection, row)
        // 子节点处理保持原有逻辑
        setTimeout(() => {
          if (!isSyncingSelection) {
            updateParentNodeState(row)
          }
        }, 10)
      }
    }
    console.log('行选择事件结束:', selectedEventIds.value)
    console.log('行选择事件结束:selectedRows', selectedRows.value)
  } finally {
    // 延迟释放标志位，让 handleSelectionChange 能够正常更新 selectedRows
    setTimeout(() => {
      isRowSelectProcessing = false
      console.log('行选择处理完成，解锁 handleSelectionChange')
    }, 50)
  }
}
// 新增：处理父节点取消选择的函数
// const handleParentNodeDeselection = (deselectedParent) => {
//   if (!isAggregate.value) return
//
//   console.log('处理父节点取消选择:', deselectedParent.event_id)
//
//   let childNodes = []
//   if (deselectedParent.children && deselectedParent.children.length > 0) {
//     childNodes = deselectedParent.children
//   } else if (deselectedParent._cachedChildren) {
//     childNodes = deselectedParent._cachedChildren
//   }
//
//   console.log(`取消父节点 ${deselectedParent.event_id} 的 ${childNodes.length} 个子节点选择`)
//
//   // 取消所有子节点的选择
//   childNodes.forEach(child => {
//     console.log('取消子节点选择:', child.event_id)
//     tableRef.value?.toggleRowSelection(child, false)
//   })
// }
/**
 * 处理表头全选框点击事件
 * 在聚合模式下检查根节点展开状态，若全部展开则执行默认全选逻辑
 */
const handleSelectAllHeader = async (selection) => {
  console.log('表头全选框被点击')

  // 非聚合模式：选中/取消选中当前页的全部数据
  if (!isAggregate.value) {
    console.log('非聚合模式，切换当前页全部数据的选中状态')

    // 判断是全选还是取消全选：如果selection为空数组，说明是取消全选
    const isSelectAll = selection.length > 0

    if (isSelectAll) {
      // 全选：选中当前页全部数据
      selectedRows.value = currentPageData.value

      // 同时更新表格的选中状态，确保UI同步
      nextTick(() => {
        tableRef.value?.clearSelection()
        currentPageData.value.forEach((row) => {
          tableRef.value?.toggleRowSelection(row, true)
        })
      })
    } else {
      // 取消全选：清空选中状态
      selectedRows.value = []

      // 同时更新表格的选中状态
      nextTick(() => {
        tableRef.value?.clearSelection()
      })
    }
    return
  }

  // 聚合模式：先检查根节点展开状态
  const allRootNodes = currentPageData.value.filter((row) => row.hasChildren)
  const unexpandedRootNodes = allRootNodes.filter((rootNode) => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 阻止默认的全选行为
    // 注意：Element Plus 的 select-all 事件无法直接阻止，我们通过不执行后续操作来实现

    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })

    // 重要：恢复表格的选中状态到点击前的状态
    // 因为 select-all 事件已经触发了全选/取消全选，我们需要撤销这个操作
    nextTick(() => {
      tableRef.value?.clearSelection()
      // 恢复之前的选中状态
      if (selectedRows.value.length > 0) {
        selectedRows.value.forEach((row) => {
          tableRef.value?.toggleRowSelection(row, true)
        })
      }
    })

    return
  }

  // 所有根节点都已展开，执行默认的全选逻辑
  console.log('所有根节点已展开，执行默认全选逻辑')
  // 只需要更新 selectedRows 即可
  selectedRows.value = selection
}
// 辅助函数：根据子节点ID找到父节点
const findParentNode = (childEventId) => {
  for (const node of tableData.value) {
    if (node.hasChildren) {
      // 检查已加载的子节点
      if (node.children && node.children.some((child) => child.event_id === childEventId)) {
        return node
      }
      // 检查缓存的子节点
      if (node._cachedChildren && node._cachedChildren.some((child) => child.event_id === childEventId)) {
        return node
      }
    }
  }
  return null
}
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
  // 定义严重程度与颜色的映射关系（与HTML样例保持一致）
  const colorMap = {
    严重: '#dc2626', // 红色，表示最高优先级
    重要: '#ea580c', // 橙色，表示中等优先级
    一般: '#f59e0b', // 黄色，表示较低优先级
    普通: '#6cbc45', // 绿色，表示普通级别（与搜索框一致）
  }
  // 返回匹配的颜色代码，如果没有匹配则返回默认灰色
  return colorMap[severity] || '#6b7280'
}

/**
 * 获取告警级别的背景色
 * @param severity - 告警级别
 * @returns {string} - 背景色
 */
const getSeverityBgColor = (severity) => {
  const bgColorMap = {
    严重: '#fef2f2',
    重要: '#fff7ed',
    一般: '#fffbeb',
    普通: '#f0fdf4',
  }
  return bgColorMap[severity] || '#f9fafb'
}

/**
 * 获取告警级别的边框色
 * @param severity - 告警级别
 * @returns {string} - 边框色
 */
const getSeverityBorderColor = (severity) => {
  const borderColorMap = {
    严重: '#fecaca',
    重要: '#fed7aa',
    一般: '#fde68a',
    普通: '#bbf7d0',
  }
  return borderColorMap[severity] || '#e5e7eb'
}

/**
 * 获取告警级别的文字颜色
 * @param severity - 告警级别
 * @returns {string} - 文字颜色
 */
const getSeverityTextColor = (severity) => {
  const textColorMap = {
    严重: '#dc2626',
    重要: '#9a3412',
    一般: '#b45309',
    普通: '#16a34a',
  }
  return textColorMap[severity] || '#6b7280'
}

/**
 * 表格《告警状态》列自定义内容：根据问题严重程度获取对应的颜色代码
 * @param {string} state - 状态值
 * @returns {string} - 对应的CSS类名
 */
const getStateClass = (state) => {
  const classMap = {
    未处理: 'status-unprocessed',
    已分派: 'status-assigned',
    已挂起: 'status-suspended',
    已关闭: 'status-closed',
  }
  return classMap[state] || 'status-default'
}

/**
 * 表格《告警状态》列el-tag类型映射
 * @param {string} state - 状态值
 * @returns {string} - 对应的el-tag type
 */
const getStateType = (state) => {
  const typeMap = {
    未处理: '',
    已分派: 'warning',
    已挂起: 'danger',
    已关闭: 'success',
  }
  return typeMap[state] || ''
}

/**
 * 获取表格行的类名，根据告警级别添加不同的样式类
 * @param {Object} row - 行数据对象
 * @returns {string} - CSS类名
 */
const getRowClassName = ({ row }) => {
  if (!row || !row.severity) return ''

  // 根据告警级别返回对应的类名（与HTML样例保持一致）
  const levelClassMap = {
    严重: 'row-critical',
    重要: 'row-major',
    一般: 'row-warning',
    普通: 'row-info',
  }

  return levelClassMap[row.severity] || ''
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
  console.log('查看当前行数据：', row)
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
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    // 显示警告消息，提示用户使用批量关闭
    messageInstance.value = ElMessage.warning({
      message: '已勾选数据，请点击批量关闭', // 提示内容
      duration: 1000, // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
      onClose: () => {
        // 消息关闭时的回调
        messageInstance.value = null // 清空消息实例引用
      },
    })
    return // 终止函数执行，不打开关闭确认模态框
  }
  // 如果没有选中的行数据，执行以下逻辑：
  // 将当前行数据保存在currentRow中，用于关闭确认模态框中显示
  currentRow.value = row
  // 打开关闭确认模态框
  DialogVisibleClose.value = true
}

/**
 * 表格中《操作》中挂起列按钮回调函数
 * @param row - 要挂起的行数据对象
 * @returns {Promise<void>}
 */
const suspend = async (row) => {
  // 检查是否有选中的行数据
  if (selectedRows.value.length > 0) {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    // 显示警告消息，提示用户使用批量关闭
    messageInstance.value = ElMessage.warning({
      message: '已勾选数据，请先取消勾选', // 提示内容
      duration: 1000, // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
      onClose: () => {
        // 消息关闭时的回调
        messageInstance.value = null // 清空消息实例引用
      },
    })
    return // 终止函数执行，不打开关闭确认模态框
  }
  // 如果没有选中的行数据，执行以下逻辑：
  // 将当前行数据保存在currentRow中，用于关闭确认模态框中显示
  currentRow.value = row
  // 单行挂起时将当前行加入到接口保存要关闭的event_id的selectedRows数组中
  // 多行挂起时直接通过表格的selected属性获取选中行。
  if (selectedRows.value.length === 0) {
    selectedRows.value.push(currentRow.value)
  }
  // 获取工单ID
  const isSuspended = row.state === '已挂起'
  const messageText = isSuspended
    ? '取消挂起后，告警将重新统计在未处理严重告警播报语音中。'
    : '挂起后告警将不再统计在未处理严重告警播报语音中，直到您手动解除挂起！'

  try {
    // 等待用户确认
    await ElMessageBox.confirm(
      h('p', { style: 'text-indent: 2em; margin: 0;' }, messageText),
      isSuspended ? '提示' : '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: isSuspended ? 'success' : 'warning',
        center: true,
      },
    )
    // 等待 MessageBox 完全关闭后再刷新数据
    await nextTick()
    await new Promise((resolve) => setTimeout(resolve, 300))
    // 刷新数据
    refresh()
    // 用户点击确认后执行
    const resultMessageText = isSuspended ? '告警已取消挂起！' : '告警已挂起！'

    // 调用挂起接口
    if (isSuspended) {
      await unSuspendAlarm(selectedEventIds.value)
    } else {
      await suspendAlarm(selectedEventIds.value)
    }
    // // 清空选中行数组
    selectedRows.value = []
    // 接口成功后显示成功提示
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise((resolve) => setTimeout(resolve, 0))
    }

    messageInstance.value = ElMessage.success({
      message: resultMessageText,
      duration: 1500,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      },
    })

  } catch (error) {
    // 清空选中行数组
    selectedRows.value = []
    // 用户点击取消或接口失败
    if (error === 'cancel' || error === 'close') {
      // 用户取消操作
      ElMessage({
        type: 'info',
        message: '挂起操作已取消！',
      })
    } else {

      // 接口失败时显示错误提示
      if (messageInstance.value) {
        ElMessage.closeAll()
        await new Promise((resolve) => setTimeout(resolve, 0))
      }

      messageInstance.value = ElMessage.error({
        message: error.message || '挂起操作失败',
        duration: 1500,
        offset: window.innerHeight / 2 - 20,
        onClose: () => {
          messageInstance.value = null
        },
      })
    }
  }
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
  orderModel.value.orderHandleOpinion = row.alarm_details
  // 打开触发工单对话框
  dialogVisibleOrder.value = true
}
// 触发工单模态框中提交工单按钮回调函数
const createTicket = async () => {
  try {
    // 当用户名和密码为空时
    if (orderModel.value.userGroup === '' || orderModel.value.username === '') {
      // 如果已有提示框在显示，先关闭它
      if (messageInstance.value) {
        // 关闭所有消息
        ElMessage.closeAll()
        // 等待消息关闭动画完成
        await new Promise((resolve) => setTimeout(resolve, 0))
      }
      messageInstance.value = ElMessage.warning({
        message: '用户组名或用户名不能为空',
        duration: 500, // 显示持续时间(毫秒)
        offset: window.innerHeight / 2 - 140, // 垂直偏移量，使消息垂直居中
        onClose: () => {
          // 消息关闭时的回调
          messageInstance.value = null // 清空消息实例引用
        },
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
          await new Promise((resolve) => setTimeout(resolve, 0))
        }

        // 显示成功提示
        messageInstance.value = ElMessage.success({
          message: '工单创建成功', // 成功提示内容
          duration: 1000, // 显示持续时间(毫秒)
          offset: window.innerHeight / 2 - 140, // 垂直偏移量，使消息垂直居中
          onClose: () => {
            // 消息关闭时的回调
            messageInstance.value = null // 清空消息实例引用
          },
        })
      })
      .catch(async () => {
        // 显示成功提示消息
        if (messageInstance.value) {
          // 先关闭所有可能存在的消息
          ElMessage.closeAll()
          // 等待消息关闭动画完成
          await new Promise((resolve) => setTimeout(resolve, 0))
        }

        // 显示成功提示
        messageInstance.value = ElMessage.error({
          message: '工单创建失败', // 成功提示内容
          duration: 1000, // 显示持续时间(毫秒)
          offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
          onClose: () => {
            // 消息关闭时的回调
            messageInstance.value = null // 清空消息实例引用
          },
        })
      })
  } catch (e) {
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
    // 立即显示表格加载状态
    loading.value = true
    console.log('start', new Date().getTime())
    // 单行关闭时将当前行加入到接口保存要关闭的event_id的selectedRows数组中
    // 多行关闭时直接通过表格的selected属性获取选中行。
    if (selectedRows.value.length === 0) {
      selectedRows.value.push(currentRow.value)
    }

    // 重要：在修改 tableData 之前先获取选中的 event IDs，使用闭包保存快照
    const eventIdsToClose = selectedRows.value.filter((row) => !(isAggregate.value && row.hasChildren)).map((row) => row.event_id)
    console.log('eventIdsToClose', eventIdsToClose)
    const handleUser = sessionStorage.getItem('user')
    // 重置模态框状态，关闭确认对话框
    DialogVisibleClose.value = false

    // 等待模态框关闭动画完成
    await nextTick()
    // 调用关闭告警接口
    // 参数：选中的告警ID列表和处理意见
    // await：阻塞代码执行，等待异步函数closeAlert执行完成
    await closeAlert(selectedEventIds.value, handleOpinion.value, handleUser)
    console.log('tableData1', tableData.value)
    // 根据是否为聚合模式采用不同的数据移除策略
    if (isAggregate.value) {
      // 聚合模式：从树形结构中移除节点
      removeNodesFromTree(tableData.value, selectedEventIds.value)
    } else {
      // 非聚合模式：从平面数组中移除
      // removeNodesFromArray(tableData.value, selectedEventIds.value)
      // 非聚合模式：使用批量过滤替代多次 splice
      tableData.value = tableData.value.filter((item) => !selectedEventIds.value.includes(item.event_id))
    }
    console.log('tableData2', tableData.value)
    // 清空选中行数组
    selectedRows.value = []
    // 清除表格的选中状态，这样即使旧数据重新被加载进来，也不会保持选择状态
    tableRef.value?.clearSelection()
    // 重置处理意见
    handleOpinion.value = ''
    // 关闭加载状态
    loading.value = false
    // 显示成功提示消息
    await nextTick()
    if (messageInstance.value) {
      // 先关闭所有可能存在的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    // 显示成功提示
    messageInstance.value = ElMessage.success({
      message: '告警关闭成功', // 成功提示内容
      duration: 1500, // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
      onClose: () => {
        // 消息关闭时的回调
        messageInstance.value = null // 清空消息实例引用
      },
    })
    console.log('endtiime', new Date().getTime())
    // 错误处理部分
  } catch (error) {
    // 关闭加载状态
    loading.value = false
    if (messageInstance.value) {
      // 如果已有提示框在显示，先关闭它
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.error({
      message: error.message, // 错误信息内容
      duration: 1000, // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20, // 垂直偏移量，使消息垂直居中
      onClose: () => {
        // 消息关闭时的回调
        messageInstance.value = null // 清空消息实例引用
      },
    })
  }
}

// 从树形结构中移除节点的辅助函数
const removeNodesFromTree = (treeData, eventIdsToRemove) => {
  if (!tableRef.value) return

  const lazyTreeNodeMap = tableRef.value.store.states.lazyTreeNodeMap.value
  console.log('lazyTreeNodeMap', lazyTreeNodeMap)
  console.log('treeData', treeData)
  // 记录需要更新的根节点
  const rootNodesToUpdate = new Set()

  for (let i = treeData.length - 1; i >= 0; i--) {
    const node = treeData[i]
    console.log('node', node)
    const parentNode = lazyTreeNodeMap[node.event_id]
    console.log('parentNode1', parentNode)
    // 如果是根节点（聚合模式下的主机节点）
    if (node.isHostNode) {
      // 检查根节点本身是否需要被移除
      if (eventIdsToRemove.includes(node.event_id)) {
        console.log('移除根节点', node)
        // 清除该根节点的展开状态记录
        if (expandedRows.value.has(node.event_id)) {
          expandedRows.value.delete(node.event_id)
          console.log('已清除根节点展开状态记录:', node.event_id)
        }
        // 根节点本身需要关闭：移除整个根节点及其所有子节点
        treeData.splice(i, 1)
        continue
      }
      console.log('执行到这了。。。。。' + '')
      // 处理子节点的移除
      if (node._cachedChildren && node._cachedChildren.length > 0) {
        let hasChanges = false
        // 从 children 数组中移除需要关闭的子节点
        for (let j = node._cachedChildren.length - 1; j >= 0; j--) {
          const child = node._cachedChildren[j]
          if (eventIdsToRemove.includes(child.event_id)) {
            console.log('移除子节点:', child.event_id)
            node._cachedChildren.splice(j, 1)
            node.children.splice(j, 1)
            hasChanges = true
            console.log('parentNode', parentNode)
            if (parentNode && j < parentNode.length) {
              parentNode.splice(j, 1)
            }
            console.log('parentNode2', parentNode)
            console.log('parentNode3', tableData.value)
          }
        }
        // 如果有变化，标记需要更新
        if (hasChanges) {
          rootNodesToUpdate.add(node.event_id)

          // 如果缓存数组为空，删除该属性
          if (node._cachedChildren.length === 0) {
            delete node._cachedChildren
          }
        }
      }
      // 更新根节点的统计信息
      updateRootNodeStatistics(node)

      // 检查是否应该移除根节点（当所有子节点都被移除后）
      const hasChildren = (node.children && node.children.length > 0) || (node._cachedChildren && node._cachedChildren.length > 0)

      if (!hasChildren) {
        // 所有子节点都已被移除，删除根节点
        console.log('所有子节点已关闭，移除根节点:', node.event_id)
        // 清除该根节点的展开状态记录
        if (expandedRows.value.has(node.event_id)) {
          expandedRows.value.delete(node.event_id)

          console.log('已清除展开状态记录:', node.event_id)
        }
        treeData.splice(i, 1)
      }
    } else {
      console.log('非根节点:', node.event_id)
      // 非根节点的处理（如果是普通节点）
      if (eventIdsToRemove.includes(node.event_id)) {
        treeData.splice(i, 1)
        continue
      }

      // 递归处理子节点
      if (node.children && node.children.length > 0) {
        removeNodesFromTree(node.children, eventIdsToRemove)

        // 如果子节点都被移除了，清理空的 children 数组
        if (node.children.length === 0) {
          delete node.children
        }
      }
    }
  }
  // 强制更新有变化的根节点的 children 引用，触发响应式更新
  if (rootNodesToUpdate.size > 0) {
    nextTick(() => {
      rootNodesToUpdate.forEach((eventId) => {
        const rootNode = treeData.find((node) => node.event_id === eventId)
        if (rootNode && rootNode._cachedChildren) {
          // 重新赋值 children，触发响应式更新
          const cachedChildren = [...rootNode._cachedChildren]
          // 限制为前 50 条
          rootNode.children = cachedChildren.slice(0, 50)
          console.log(`更新根节点 ${eventId} 的 children，数量：${rootNode.children.length}`)
          // 更新懒加载映射表中的子节点数据为最新的_cachedChildren
          if (lazyTreeNodeMap[eventId]) {
            lazyTreeNodeMap[eventId] = [...cachedChildren.slice(0, 50)]
            console.log(`更新懒加载映射表 ${eventId}，数量：${cachedChildren.length}`)
          }
        }
      })
    })
  }
}

// 懒加载子节点的处理函数
const loadTreeNode = (row, treeNode, resolve) => {
  // const id = row.event_id
  // recordNodes.set(id, { row, treeNode, resolve })
  console.log('loadTreeNode:', row)
  console.log('加载子节点:', row.event_id)
  // 模拟异步加载延迟
  setTimeout(() => {
    try {
      console.log('row:', row)
      // 获取缓存的子节点数据
      const children = loadLazyChildren(row)
      console.log('children:', children)
      console.log('tableData:', tableData.value)
      if (children && children.length > 0) {
        // 对子节点进行排序
        const sortedChildren = [...children].sort((a, b) => {
          // 按严重级别和时间排序
          const severityOrder = { 严重: 3, 重要: 2, 一般: 1, 普通: 0 }
          const severityDiff = severityOrder[b.severity] - severityOrder[a.severity]
          if (severityDiff !== 0) return severityDiff

          return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
        })
        // 限制为前 50 条
        const limitedSortedChildren = sortedChildren.slice(0, 50)
        // 限制加载数量为前 50 条
        tableData.value = tableData.value.map((node) => {
          if (node.event_id === row.event_id) {
            // 节点懒加载后将根节点的children属性赋予_cachedChildren的值
            node.children = limitedSortedChildren
          }
          return node
        })
        // 在 resolve 之前，确保 blinkTrigger 为 true，使子节点与根节点闪烁同步
        // 先关闭闪烁
        blinkTrigger.value = false
        console.log(`加载了 ${sortedChildren.length} 个子节点`)
        resolve(sortedChildren)
        // 等待 DOM 更新后，再开启闪烁，这样所有子节点的动画会同步
        nextTick(() => {
          // 短暂延迟后重新开启闪烁，确保所有子节点都已渲染
          setTimeout(() => {
            blinkTrigger.value = true
            console.log('懒加载完成，同步闪烁状态')
          }, 50)
        })
      } else {
        resolve([])
      }
    } catch (error) {
      console.error('加载子节点失败:', error)
      resolve([])
    }
  }, 300) // 300ms 模拟网络延迟
}

// 从平面数组中移除节点的辅助函数
const removeNodesFromArray = (arrayData, eventIdsToRemove) => {
  // for (let i = arrayData.length - 1; i >= 0; i--) {
  //   if (eventIdsToRemove.includes(arrayData[i].event_id)) {
  //     arrayData.splice(i, 1)
  //   }
  // }
  const idsToRemoveSet = new Set(eventIdsToRemove)
  for (let i = arrayData.length - 1; i >= 0; i--) {
    if (idsToRemoveSet.has(arrayData[i].event_id)) {
      arrayData.splice(i, 1)
    }
  }
}

// 更新根节点统计信息
const updateRootNodeStatistics = (rootNode) => {
  if ((rootNode.children && rootNode.children.length > 0) || (rootNode._cachedChildren && rootNode._cachedChildren.length > 0)) {
    const stats = {
      total: rootNode._cachedChildren ? rootNode._cachedChildren.length : 0,
      critical: rootNode._cachedChildren ? rootNode._cachedChildren.filter((child) => child.severity === '严重').length : 0,
      important: rootNode._cachedChildren ? rootNode._cachedChildren.filter((child) => child.severity === '重要').length : 0,
      normal: rootNode._cachedChildren ? rootNode._cachedChildren.filter((child) => child.severity === '一般').length : 0,
      ordinary: rootNode._cachedChildren ? rootNode._cachedChildren.filter((child) => child.severity === '普通').length : 0,
      processed: rootNode._cachedChildren
        ? rootNode._cachedChildren.filter((child) => child.state === '已分派' || child.state === '已关闭').length
        : 0,
      unprocessed: rootNode._cachedChildren ? rootNode._cachedChildren.filter((child) => child.state === '未处理').length : 0,
    }

    rootNode.statistics = stats
    rootNode.alarm_details = `(总计：${stats.total}, 严重：${stats.critical},重要：${stats.important},一般：${stats.normal},普通：${stats.ordinary})`

    // 更新根节点的最高级别和最新时间
    rootNode.severity = getHighestSeverity(rootNode._cachedChildren)
    rootNode.occurrenceTime = getLatestTime(rootNode._cachedChildren)
  }
}

// 获取最高级别（从 treeData.js 中提取的逻辑）
const getHighestSeverity = (children) => {
  // 定义严重程度顺序映射，数值越大表示级别越高
  const severityOrder = { 严重: 4, 重要: 3, 一般: 2, 普通: 1 }

  // 如果没有子节点，返回默认级别
  if (!children || children.length === 0) {
    return '普通'
  }

  // 使用 reduce 方法遍历数组，找出最高严重级别
  return children.reduce((highest, alarm) => {
    const currentLevel = severityOrder[alarm.severity] || 0
    const highestLevel = severityOrder[highest] || 0

    // 如果当前报警级别高于已知最高级别，更新最高级别
    return currentLevel > highestLevel ? alarm.severity : highest
  }, '普通') // 初始最高级别设为"普通"
}

// 获取最新时间（从 treeData.js 中提取的逻辑）
const getLatestTime = (children) => {
  return children.reduce((latest, alarm) => {
    const currentTime = new Date(alarm.occurrenceTime)
    const latestTime = new Date(latest)
    return currentTime > latestTime ? alarm.occurrenceTime : latest
  }, '1970-01-01 00:00:00')
}
// 添加防循环标志
let isSyncingSelection = false
// 展开状态管理：使用 Set 数据结构存储已展开行的 event_id，自动去重，查找效率高
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
    // 等待DOM更新完成
    await nextTick()
    // 展开前先同步图标闪烁状态
    blinkTrigger.value = false
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
        if (node.children && node.children.some((child) => child.event_id === targetEventId)) {
          return { rootNode: node, children: node.children }
        }
        // 检查缓存的子节点（未展开的情况）
        if (node._cachedChildren && node._cachedChildren.some((child) => child.event_id === targetEventId)) {
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

// 处理父子节点联动选择的函数
// 完全重写的父子节点联动处理函数
const syncParentChildSelection = () => {
  // 防止无限循环
  if (isSyncingSelection) {
    console.log('跳过同步，已在同步中...')
    return
  }
  if (!isAggregate.value || !tableRef.value) return
  try {
    isSyncingSelection = true
    console.log('开始同步选择状态...')
    // 获取当前表格中所有选中的行
    const currentSelection = tableRef.value.getSelectionRows()
    console.log(
      '当前选中行:',
      currentSelection.map((row) => ({
        id: row.event_id,
        type: row.hasChildren ? 'parent' : 'child',
        root: row.hasChildren ? row : '',
      })),
    )

    // 找出所有根节点（无论是否选中）
    const allParents = currentPageData.value.filter((row) => row.hasChildren)

    allParents.forEach((parent) => {
      const isParentSelected = currentSelection.some((row) => row.event_id === parent.event_id)
      console.log(`isParentSelected: ${isParentSelected}`)
      // 获取子节点
      let childNodes = []
      if (parent.children && parent.children.length > 0) {
        childNodes = parent.children
      } else if (parent._cachedChildren) {
        childNodes = parent._cachedChildren
      }
      console.log('childNodes', childNodes)
      const selectedChildren = childNodes.filter((child) => currentSelection.some((selected) => selected.event_id === child.event_id))
      console.log('selectedChildren', selectedChildren)
      console.log(`父节点 ${parent.event_id}: 选中=${isParentSelected}, 子节点总数=${childNodes.length}, 已选中子节点=${selectedChildren.length}`)

      if (isParentSelected) {
        // 父节点被选中 -> 确保所有子节点都被选中
        childNodes.forEach((child) => {
          if (!currentSelection.some((selected) => selected.event_id === child.event_id)) {
            console.log('补选子节点:', child.event_id)
            tableRef.value.toggleRowSelection(child, true)
          }
        })
      } else if (selectedChildren.length > 0 && selectedChildren.length < childNodes.length) {
        // 部分子节点被选中 -> 设置父节点为半选状态
        console.log('设置父节点半选状态:', parent.event_id)
        // Element Plus 会自动处理半选状态的显示
      }
      console.log('已选中子节点:', selectedEventIds.value)
    })
  } finally {
    // 确保标志位被重置
    setTimeout(() => {
      isSyncingSelection = false
      console.log('同步完成')
    }, 0)
  }
}
// 新增：处理子节点选择变化影响父节点状态的函数
const updateParentNodeState = (childNode) => {
  // 防止在同步过程中执行
  if (isSyncingSelection) return
  const parentNode = findParentNode(childNode.event_id)
  if (!parentNode) return

  let childNodes = []
  if (parentNode.children && parentNode.children.length > 0) {
    childNodes = parentNode.children
  } else if (parentNode._cachedChildren) {
    childNodes = parentNode._cachedChildren
  }

  const selectedChildren = childNodes.filter((child) => selectedRows.value.some((selected) => selected.event_id === child.event_id))

  console.log(`父节点 ${parentNode.event_id} 的子节点选择情况: ${selectedChildren.length}/${childNodes.length}`)

  // 根据子节点选择情况更新父节点状态
  if (selectedChildren.length === childNodes.length && childNodes.length > 0) {
    // 所有子节点都被选中 -> 选中父节点
    if (!selectedRows.value.some((row) => row.event_id === parentNode.event_id)) {
      console.log('所有子节点选中，选中父节点:', parentNode.event_id)
      tableRef.value?.toggleRowSelection(parentNode, true)
    }
  } else if (selectedChildren.length === 0) {
    // 没有子节点被选中 -> 取消父节点选择
    if (selectedRows.value.some((row) => row.event_id === parentNode.event_id)) {
      console.log('无子节点选中，取消父节点:', parentNode.event_id)
      tableRef.value?.toggleRowSelection(parentNode, false)
    }
  }
  // 部分子节点被选中时，Element Plus 会自动显示半选状态
}
// 优化后的 batchUpdateSelection（恢复防循环机制）
let isBatchProcessing = false

// 批量更新函数 - 一次性处理多个选择操作
const batchUpdateSelection = (operations) => {
  // if (isSyncingSelection || !tableRef.value) return
  //
  // isSyncingSelection = true
  // 简单有效的并发控制
  if (isBatchProcessing) {
    console.log('批量操作正在进行中，排队等待...')
    setTimeout(() => batchUpdateSelection(operations), 50)
    return
  }
  if (!tableRef.value) return
  isBatchProcessing = true
  try {
    console.log(`批量处理 ${operations.length} 个选择操作`)

    // 收集所有需要操作的节点
    const nodesToSelect = []
    const nodesToDeselect = []

    operations.forEach((op) => {
      if (op.action === 'select') {
        nodesToSelect.push(op.node)
      } else {
        nodesToDeselect.push(op.node)
      }
    })

    // 批量执行选择操作
    if (nodesToSelect.length > 0) {
      console.log(`批量选中 ${nodesToSelect.length} 个节点`)
      nodesToSelect.forEach((node) => {
        tableRef.value.toggleRowSelection(node, true)
      })
    }

    if (nodesToDeselect.length > 0) {
      console.log(`批量取消 ${nodesToDeselect.length} 个节点`)
      nodesToDeselect.forEach((node) => {
        tableRef.value.toggleRowSelection(node, false)
      })
    }
  } finally {
    setTimeout(() => {
      isBatchProcessing = false
      // isSyncingSelection = false
    }, 0)
  }
}
// 查看告警详情中标签页默认值
const activeName = ref('基本信息')

// 标签页点击事件
const handleClick = (tab, event) => {
  console.log(tab, event)
}
onUnmounted(() => {
  stopBlinkTimer()
  clearExpandStates()
  // 清空当前选择行
  selectedRows.value = []
  tableRef.value?.clearSelection()
  // 重置到第一页
  currentPage.value = 1
  // 页面刷新时清空根节点缓存
  // recordNodes.clear()
})
</script>

<template>
  <div class="item-page-container">
    <!-- 工具栏 -->
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px">
      <!-- 左侧：全选/反选按钮 -->
      <div style="display: flex; align-items: center; gap: 10px">
        <span style="font-size: 14px; font-weight: 600; color: #303133; user-select: none">告警列表</span>
        <span style="width: 1px; height: 24px; background: #e2e8f0; margin: 0 12px"></span>
        <el-button type="info" plain @click="handleSelectAll">全选</el-button>
        <el-button type="info" plain @click="handleReverseSelection">反选</el-button>
      </div>

      <!-- 中间：搜索框 + 聚合开关 -->
      <div style="display: flex; align-items: center; gap: 12px">
        <el-input
          v-model="localSearchText"
          placeholder="搜索告警内容、系统、主机、IP..."
          clearable
          :prefix-icon="Search"
          style="width: 280px"
          @clear="clearLocalSearch"
        />
        <el-switch
          v-model="isAggregate"
          v-if="permissionStore.hasPermission('alarm:aggregation')"
          class="ml-2"
          inline-prompt
          width="60"
          active-text="聚合"
          inactive-text="不聚合"
        />
      </div>

      <!-- 右侧：操作按钮 -->
      <div style="display: flex; align-items: center; gap: 10px">
        <el-button v-if="permissionStore.hasPermission('alarm:refresh')" type="info" plain @click="refresh" class="refresh-btn">
          <svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>
        </el-button>
        <el-button v-if="permissionStore.hasPermission('alarm:export')" type="info" plain @click="exportAlarmData" class="export-btn">
          <svg class="icon-svg sm" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          &nbsp;导出
        </el-button>
        <el-button v-if="permissionStore.hasPermission('alarm:batchClose')" type="danger" @click="batchClose" class="batch-close-btn">
          <svg class="icon-svg sm" viewBox="0 0 24 24"><path d="M18 6L6 18M6 6l12 12"/></svg>
          &nbsp;批量关闭
        </el-button>
      </div>
    </div>
    <!-- 表格 -->
    <div class="table-container">
      <!-- 全局加载遮罩 -->
      <div v-if="globalLoading" class="global-loading-overlay">
        <div class="loading-content">
          <div class="loading-text">正在切换表格模式...</div>
        </div>
      </div>

      <!-- 统一的表格（支持虚拟滚动） -->
      <el-table
        ref="tableRef"
        :data="isAggregate ? currentPageData : (pageSize > 10 ? virtualDataWithSpacers : virtualData)"
        :size="'small'"
        :row-style="({ row }) => row.__spacer__ ? { height: row.__height__ + 'px', padding: 0 } : { height: '45px' }"
        :row-class-name="({ row }) => row.__spacer__ ? 'spacer-row' : getRowClassName({ row })"
        style="width: 100%; font-size: 13px; color: #303133"
        :cell-style="({ column, row }) => {
          if (row.__spacer__) return { padding: 0, border: 'none' }
          return column.prop === 'alarm_details' ? { textAlign: 'left', padding: '6px 14px' } : { textAlign: 'center', padding: '6px 0' }
        }"
        :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px', padding: '10px 0' }"
        row-key="event_id"
        :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
        @selection-change="handleSelectionChange"
        @sort-change="handleSortChange"
        v-loading="loading"
        lazy
        :load="loadTreeNode"
        @select="handleRowSelect"
        :select-on-indeterminate="false"
        @select-all="handleSelectAllHeader"
        @scroll="handleTableScroll"
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
                :class="{ expanded: isRowExpanded(row) }"
              />
              <div v-else class="empty-expand"></div>
            </div>
          </template>
        </el-table-column>
        <!--        <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" min-width="4%" :resizable="false" />-->
        <el-table-column label="序号" min-width="5%" :resizable="false">
          <template #default="{ row, $index }">
            <!-- 空白行不显示序号 -->
            <span v-if="row.__spacer__"></span>
            <span
              v-else
              :class="{ 'root-node-index': isAggregate && row.hasChildren }"
              :style="{
                backgroundColor: isAggregate && row.hasChildren ? '#409eff' : 'transparent',
                color: isAggregate && row.hasChildren ? 'white' : 'inherit',
                padding: isAggregate && row.hasChildren ? '2px 6px' : '0',
                borderRadius: isAggregate && row.hasChildren ? '4px' : '0',
              }"
            >
              <span v-if="isAggregate">
                <!-- 聚合模式：根节点显示子节点个数，子节点显示独立序号 -->
                <span v-if="row.hasChildren">
                  {{ row._cachedChildren ? row._cachedChildren.length : row.children ? row.children.length : 0 }}
                </span>
                <span v-else>
                  {{ getChildNodeIndex(row) }}
                </span>
              </span>
              <span v-else>
                <!-- 非聚合模式：正常序号 -->
                <!-- 通过event_id在tableData中查找真实索引 -->
                {{ getRealRowIndex(row) }}
              </span>
            </span>
          </template>
        </el-table-column>

        <el-table-column prop="event_id" label="事件ID" v-if="false" />
        <el-table-column prop="alarm_details" label="告警内容" :min-width="isAggregate ? '28%' : '24%'" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <div v-if="row.__spacer__"></div>
            <div
              v-else
              class="alarm-content-cell"
              :title="row.alarm_details"
              :style="{
                color: row.severity === '严重' ? '#dc2626' : 'inherit',
                fontWeight: row.severity === '严重' ? '600' : '400'
              }"
              v-html="highlightText(row.alarm_details)"
            ></div>
          </template>
        </el-table-column>
        <el-table-column prop="severity" label="级别" :sortable="false" min-width="8%" :resizable="false">
          <template #default="scope">
            <!-- 空白行不显示内容 -->
            <div v-if="scope.row.__spacer__"></div>
            <el-tag
              v-else
              size="small"
              effect="light"
              round
              class="severity-tag"
              :style="{
                backgroundColor: getSeverityBgColor(scope.row.severity),
                borderColor: getSeverityBorderColor(scope.row.severity),
                color: getSeverityTextColor(scope.row.severity)
              }"
            >
              <span
                class="severity-indicator-small"
                :style="{
                  backgroundColor: getSeverityColor(scope.row.severity),
                  opacity: (blinkTrigger && scope.row.severity === '严重' && scope.row.state !== '已关闭') ? blinkOpacity : 1
                }"
              ></span>
              {{ scope.row.severity }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="5%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <div v-if="row.__spacer__"></div>
            <el-tag
              v-else
              :type="getStateType(row.state)"
              size="small"
              effect="light"
              round
            >
              {{ row.state }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="system_name" label="业务系统" show-overflow-tooltip min-width="10%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <span v-if="row.__spacer__"></span>
            <span v-else v-html="highlightText(row.system_name)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" show-overflow-tooltip min-width="5%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <span v-if="row.__spacer__"></span>
            <span v-else v-html="highlightText(row.category)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="object" label="主机名" min-width="8%" show-overflow-tooltip :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <div v-if="row.__spacer__"></div>
            <el-button v-else type="primary" class="truncate-button" plain @click="handleView(row)" style="max-width: 100%; overflow: hidden; padding: 4px 8px; font-size: 12px; min-height: 28px; height: 28px">
              <span v-html="highlightText(row.object)"></span>
            </el-button>
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP地址" show-overflow-tooltip min-width="8%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <span v-if="row.__spacer__"></span>
            <span v-else v-html="highlightText(row.ip)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <span v-if="row.__spacer__"></span>
            <span v-else v-html="highlightText(row.occurrenceTime)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false">
          <template #default="{ row }">
            <!-- 空白行不显示内容 -->
            <span v-if="row.__spacer__"></span>
            <span v-else v-html="highlightText(row.processingTime)"></span>
          </template>
        </el-table-column>
        <el-table-column prop="operation" label="操作" min-width="5%" :resizable="false">
          <template #default="scope">
            <!-- 空白行不显示操作按钮 -->
            <div v-if="scope.row.__spacer__"></div>
            <div v-else class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center; user-select: none">
              <el-dropdown trigger="click">
                <el-button type="primary" :icon="Edit" :disabled="isAggregate && scope.row.hasChildren"> </el-button>
                <template #dropdown>
                  <el-dropdown-menu style="user-select: none">
                    <el-dropdown-item @click="handleView(scope.row)" style="color: #409eff; font-weight: bold"> 查看 </el-dropdown-item>
                    <el-dropdown-item
                      :disabled="scope.row.state === '已关闭'"
                      @click="handleClose(scope.row)"
                      :class="{ isActive: !(scope.row.state === '已关闭') }"
                    >
                      关闭
                    </el-dropdown-item>
                    <el-dropdown-item
                      :disabled="scope.row.state === '已关闭' || scope.row.state === '已分派'"
                      @click="handleCreateTicket(scope.row)"
                      :class="{ isActive: !(scope.row.state === '已关闭' || scope.row.state === '已分派') }"
                    >
                      触发工单
                    </el-dropdown-item>
                    <el-dropdown-item
                      :disabled="scope.row.state === '已关闭'"
                      @click="suspend(scope.row)"
                      :class="{ isActive: !(scope.row.state === '已关闭') }"
                    >
                      {{ scope.row.state === '已挂起' ? '取消挂起' : '挂起' }}
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
    <div style="display: flex; justify-content: space-between; align-items: center; user-select: none">
      <!--  显示总数  -->
      <div style="display: flex; align-items: center">
        <span style="line-height: 20px">共 {{ displayData.length }} 条</span>
      </div>
      <div style="display: flex; align-items: center">
        <!--  每页条数  -->
        <div style="display: flex; align-items: flex-start; margin-right: 10px; user-select: none">
          <el-select v-model="pageSize" style="width: 70px; margin: 0" @change="handleSizeChange">
            <el-option v-for="item in pageSizeOptions" :key="item" :label="item" :value="item" />
          </el-select>
          <span style="line-height: 32px; margin-left: 10px">条/页</span>
        </div>
        <!--  页码导航  -->
        <div style="display: flex; align-items: center">
          <el-pagination
            background
            v-model:current-page="currentPage"
            :page-size="pageSize"
            :total="displayData.length"
            layout="prev, pager, next"
            @current-change="handleCurrentChange"
          />
        </div>
      </div>
    </div>
    <!--    查看按钮模态框  -->
    <el-dialog
      v-model="dialogVisibleView"
      top="15%"
      title="告警详情"
      width="80%"
      center
      style="user-select: text; min-height: 300px"
      destroy-on-close
      @close="
        () => {
          dialogVisibleView = false
        }
      "
    >
      <el-tabs v-model="activeName" type="card" class="demo-tabs" @tab-click="handleClick" style="user-select: none">
        <el-tab-pane label="基本信息" name="基本信息" style="user-select: text">
          <el-table
            :data="[currentRow]"
            border
            style="width: 100%; font-size: 13px; color: #303133"
            :cell-style="{ textAlign: 'center', verticalAlign: 'middle', padding: '8px 0' }"
            :header-cell-style="{
              textAlign: 'center',
              background: '#f5f7fa',
              color: '#303133',
              fontWeight: '600',
              fontSize: '14px',
              padding: '12px 0',
            }"
            :row-style="{ height: '60px' }"
          >
            <el-table-column prop="event_id" label="事件ID" min-width="10%" />
            <el-table-column prop="alarm_details" label="告警内容" min-width="20%" :resizable="false">
              <template #default="{ row }">
                {{ row.alarm_details || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="severity" label="级别" min-width="8%" :resizable="false">
              <template #default="scope">
                <el-tag
                  size="small"
                  effect="light"
                  round
                  class="severity-tag"
                  :style="{
                    backgroundColor: getSeverityBgColor(scope.row.severity),
                    borderColor: getSeverityBorderColor(scope.row.severity),
                    color: getSeverityTextColor(scope.row.severity)
                  }"
                >
                  <span
                    class="severity-indicator-small"
                    :style="{
                      backgroundColor: getSeverityColor(scope.row.severity),
                      opacity: (scope.row.severity === '严重' && scope.row.state !== '已关闭') ? blinkOpacity : 1
                    }"
                  ></span>
                  {{ scope.row.severity }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="state" label="状态" min-width="8%" :resizable="false">
              <template #default="{ row }">
                <el-tag
                  :type="getStateType(row.state)"
                  size="small"
                  effect="light"
                  round
                >
                  {{ row.state }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="system_name" label="业务系统" min-width="10%" :resizable="false">
              <template #default="{ row }">
                {{ row.system_name || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="category" label="分类" min-width="5%" :resizable="false">
              <template #default="{ row }">
                {{ row.category || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="object" label="主机名" min-width="10%" :resizable="false">
              <template #default="{ row }">
                {{ row.object || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="ip" label="IP地址" min-width="10%" :resizable="false">
              <template #default="{ row }">
                {{ row.ip || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="occurrenceTime" label="发生时间" min-width="10%" :resizable="false">
              <template #default="{ row }">
                {{ row.occurrenceTime || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="processingTime" label="处理时间" min-width="10%" :resizable="false">
              <template #default="{ row }">
                {{ row.processingTime || '-' }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
        <el-tab-pane v-if="currentRow.state === '已关闭'" label="处理过程" name="处理过程" style="user-select: text">
          <el-table
            :data="[currentRow]"
            border
            :cell-style="{ textAlign: 'center', verticalAlign: 'middle', padding: '8px 0' }"
            style="width: 100%; font-size: 13px; color: #303133"
            :header-cell-style="{
              textAlign: 'center',
              background: '#f5f7fa',
              color: '#303133',
              fontWeight: '600',
              fontSize: '14px',
              padding: '12px 0',
            }"
            :row-style="{ height: '60px' }"
          >
            <el-table-column prop="event_id" label="事件ID" min-width="10%" />
            <el-table-column prop="Alarm_Handler" label="处理人" min-width="15%" :resizable="false">
              <template #default="{ row }">
                {{ row.Alarm_Handler || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="processingTime" label="处理时间" min-width="25%" :resizable="false">
              <template #default="{ row }">
                {{ row.processingTime || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="alert_remarks" label="处理意见" min-width="50%" :resizable="false">
              <template #default="{ row }">
                {{ row.alert_remarks || '-' }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-dialog>
    <!-- 关闭按钮模态框 -->
    <el-dialog
      v-model="DialogVisibleClose"
      top="10%"
      title="关闭告警"
      width="30%"
      center
      :show-close="false"
      @close="
        () => {
          handleOpinion = ''
          DialogVisibleClose = false
        }
      "
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
            async () => {
              DialogVisibleClose = false
              // 等待模态框关闭动画完成
              await nextTick()
              handleOpinion = ''
            }
          "
          >取消</el-button
        >
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
      @close="
        () => {
          orderModel.system_name = ''
          orderModel.eventId = ''
          orderModel.userGroup = ''
          orderModel.username = ''
          orderModel.orderHandleOpinion = ''
          dialogVisibleOrder = false
        }
      "
    >
      <el-form :inline="true" :model="orderModel" style="display: flex; align-items: center; flex-wrap: wrap; user-select: none">
        <div style="display: flex; justify-content: space-between; width: 100%">
          <el-form-item label="用户组名" prop="userGroup">
            <el-select
              v-model="orderModel.userGroup"
              class="center-placeholder"
              :filterable="isFilter"
              clearable
              placeholder="请选择"
              style="width: 150px"
              @change="
                () => {
                  orderModel.username = ''
                  dataDictionary.username = []
                }
              "
              @visible-change="
                (visible) => {
                  isFilter = visible
                  getUserGroup(visible, '用户组')
                }
              "
              @clear="
                () => {
                  orderModel.userGroup = ''
                  orderModel.username = ''
                  dataDictionary.userGroup = []
                  dataDictionary.username = []
                }
              "
            >
              <el-option v-for="(item, index) in dataDictionary.userGroup" :key="index" :value="item" />
            </el-select>
          </el-form-item>
          <el-form-item label="用户名" prop="username">
            <el-select
              v-model="orderModel.username"
              class="center-placeholder"
              :filterable="isFilter"
              clearable
              placeholder="请选择"
              style="width: 150px"
              @visible-change="
                (visible) => {
                  isFilter = visible
                  getUserGroup(visible, '用户')
                }
              "
              @clear="
                () => {
                  orderModel.username = ''
                  dataDictionary.username = []
                }
              "
            >
              <el-option v-for="(item, index) in dataDictionary.username" :key="index" :label="item[1]" :value="item[0]" />
            </el-select>
          </el-form-item>
        </div>
        <el-form-item label="处理意见" prop="orderHandleOpinion" style="width: 100%">
          <div style="display: flex; flex: 1; align-items: center; justify-content: center; margin-bottom: 15px; margin-top: 5px">
            <el-input
              v-model="orderModel.orderHandleOpinion"
              style="font-size: 16px; width: 100%"
              type="textarea"
              :autosize="{ maxRows: 10, minRows: 5 }"
              resize="none"
              placeholder="请输入……"
              maxlength="100"
              show-word-limit
            />
          </div>
        </el-form-item>
        <el-form-item style="flex: none; margin-left: auto; margin-right: 5px">
          <div style="display: flex; justify-content: flex-end; gap: 10px; flex-wrap: nowrap">
            <el-button type="primary" @click="orderModel.orderHandleOpinion = ''">清空</el-button>
            <el-button type="primary" @click="createTicket">确认</el-button>
            <el-button
              type="primary"
              @click="
                () => {
                  dialogVisibleOrder = false
                  // 清空数据模型
                  orderModel.value.system_name = ''
                  orderModel.value.eventId = ''
                  orderModel.value.userGroup = ''
                  orderModel.value.username = ''
                  orderModel.value.orderHandleOpinion = ''
                }
              "
              >取消</el-button
            >
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
  height: calc(100vh - 40px - 32px - 220px); /* 减去header高度(40px)、main padding(32px)和搜索栏高度(约220px) */
  flex-direction: column;
  box-sizing: border-box;
  position: relative; /* 添加相对定位,用于切换聚合模式时遮罩层定位 */
  overflow: hidden; /* 防止溢出 */
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  margin-top: 12px;
}

/* 表格容器样式：防止表格行多时溢出 */
.table-container {
  flex: 1;
  overflow: auto;
  display: flex;
  flex-direction: column;
  padding: 10px 0;
  position: relative; /* 添加相对定位,用于切换聚合模式时遮罩层定位 */
}

/* 空白行（虚拟滚动占位行）样式 */
:deep(.el-table__body tr.spacer-row) {
  pointer-events: none;
}

:deep(.el-table__body tr.spacer-row td) {
  padding: 0 !important;
  border: none !important;
  background: transparent !important;
}

/* 隐藏占位行中的复选框 */
:deep(.el-table__body tr.spacer-row .el-checkbox) {
  visibility: hidden !important;
}

/* 关键修复：强制统一聚合模式子节点的内容高度，与非聚合模式保持一致 */
:deep(.el-table__body tr[class*="el-table__row--level"] .cell) {
  height: 32px !important;
  line-height: 32px !important;
  overflow: hidden;
}

/* 确保子节点行内的所有元素高度一致 */
:deep(.el-table__body tr[class*="el-table__row--level"] td) {
  height: 33px !important;
}

/* 告警图形样式 - 闪烁由 JS setInterval 驱动，transition 仅用于快速平滑 opacity 变化 */
.severity-indicator {
  display: inline-block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  vertical-align: middle;
  transition: opacity 0.15s ease;
  margin: 5px 0;
}

/* 小号告警指示器 - 用于el-tag内 */
.severity-indicator-small {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-right: 5px;
  transition: opacity 0.15s ease;
}
/* 告警状态颜色 */
.status-unprocessed {
  color: #909399; /* 未处理 - 蓝色 */
  background-color: transparent !important;
}
.status-closed {
  color: #67c23a; /* 已处理 - 绿色 */
  background-color: transparent !important;
}
.status-assigned {
  color: #e6a23c; /* 已分配 - 黄色 */
  background-color: transparent !important;
}
.status-suspended {
  color: #f56c6c; /* 已挂起 - 红色 */
  background-color: transparent !important;
}
.status-default {
  color: #909399; /* 默认状态 - 灰色 */
  background-color: transparent !important;
}
/* 表格行样式 - 添加严重告警行的特殊样式 */
:deep(.el-table__body tr) {
  transition: background-color 0.3s ease;
  position: relative;
}

/* 严重告警行样式 - 左侧红色边框 */
:deep(.el-table__body tr.row-critical) {
  border-left: 3px solid #dc2626;
}

/* 重要告警行样式 - 左侧橙色边框 */
:deep(.el-table__body tr.row-major) {
  border-left: 3px solid #ea580c;
}

/* 一般告警行样式 - 左侧黄色边框 */
:deep(.el-table__body tr.row-warning) {
  border-left: 3px solid #f59e0b;
}

/* 普通告警行样式 - 左侧蓝色边框 */
:deep(.el-table__body tr.row-info) {
  border-left: 3px solid #0ea5e9;
}

/* 严重告警行hover时显示红色背景 */
:deep(.el-table__body tr.row-critical:hover > td) {
  background-color: #fef2f2 !important;
}

/* 表格行hover样式 - 非严重告警保持原样 */
:deep(.el-table__body tr:not(.row-critical):hover > td) {
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

/* 级别标签样式 - 使用flex布局实现完美垂直居中 */
.severity-tag :deep(.el-tag__content) {
  display: inline-flex;
  align-items: center;
  gap: 0;
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
  background-color: rgba(255, 255, 255, 0.98);
  z-index: 1000;
  display: flex;
  justify-content: center;
  align-items: center;
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
:deep(.el-dropdown-menu__item.isActive) {
  color: #409eff !important;
  font-weight: bold !important;
}

/* SVG图标样式 - 与样例HTML保持一致 */
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
}

.icon-svg.lg {
  width: 18px;
  height: 18px;
}

/* 刷新按钮样式优化 */
.refresh-btn {
  padding: 0 10px;
  min-width: auto;
}

.refresh-btn :deep(.el-icon) {
  margin-right: 0;
}

/* 导出按钮样式优化 */
.export-btn {
  padding: 0 10px;
  min-width: auto;
}

/* 批量关闭按钮样式优化 */
.batch-close-btn {
  padding: 0 10px;
  min-width: auto;
}

/* 告警内容单元格样式 - 左对齐并支持溢出省略 */
.alarm-content-cell {
  text-align: left;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  width: 100%;
}

/* 搜索结果高亮样式 - v-html 渲染的内容需要用 :deep 穿透 scoped */
:deep(.search-highlight) {
  background-color: #fef08a;
  color: #854d0e;
  padding: 1px 2px;
  border-radius: 2px;
  font-weight: inherit;
}
</style>
