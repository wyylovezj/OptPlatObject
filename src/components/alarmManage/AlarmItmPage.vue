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
  handleSortChange,
  dataDictionary,
  user,
  orderModel,
  refresh,
  isFilter,
  searchQuery,
  isAggregate,
  sortRootNodes
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
    // 清空当前选择行
    selectedRows.value = []
    tableRef.value?.clearSelection()
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
    childNodes.forEach(child => {
      operations.push({ action: 'select', node: child })
    })
  } else {
    // 取消父节点 -> 批量取消所有子节点
    childNodes.forEach(child => {
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
    const currentPageSelectedCount = currentPageRows.filter(row =>
      currentSelection.some(selected => selected.event_id === row.event_id)
    ).length
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
      currentPageRows.forEach(row => {
        tableRef.value?.toggleRowSelection(row, true)
      })
    }

    return
  }
  // 获取当前页的所有根节点
  const allRootNodes = currentPageData.value.filter(row => row.hasChildren)

  // 检查是否有根节点未被展开
  const unexpandedRootNodes = allRootNodes.filter(rootNode => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise(resolve => setTimeout(resolve, 0));
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  // 聚合模式下的全选逻辑
  const currentSelection = tableRef.value?.getSelectionRows() || []
  const currentPageRows = currentPageData.value

  // 检查是否所有根节点都被选中
  const rootNodes = currentPageRows.filter(row => row.hasChildren)
  const allRootsSelected = rootNodes.every(root =>
    currentSelection.some(selected => selected.event_id === root.event_id)
  )

  if (allRootsSelected && rootNodes.length > 0) {
    // 当前所有根节点都已选中 -> 取消全选
    console.log('取消聚合全选')
    tableRef.value?.clearSelection()
    selectedRows.value = []

    // 收集所有需要取消的子节点
    const cancelOperations = []
    // 确保所有子节点也被取消
    rootNodes.forEach(root => {
      let childNodes = []
      if (root.children && root.children.length > 0) {
        childNodes = root.children
      } else if (root._cachedChildren) {
        childNodes = root._cachedChildren
      }

      childNodes.forEach(child => {
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
        rootNodes.forEach(root => {
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
  const allRootNodes = currentPageData.value.filter(row => row.hasChildren)

  // 检查是否有根节点未被展开
  const unexpandedRootNodes = allRootNodes.filter(rootNode => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise(resolve => setTimeout(resolve, 0));
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })
    return
  }
  // 聚合模式
  const rootNodes = currentPageData.value.filter(row => row.hasChildren)
  const currentSelection = tableRef.value?.getSelectionRows() || []
  const operations = []
  // 处理根节点反选
  rootNodes.forEach(root => {
    // 获取根节点和子节点的当前选中状态
    const isRootSelected = currentSelection.some(selected => selected.event_id === root.event_id)
    const childNodes = root.children || root._cachedChildren || []
    const selectedChildCount = childNodes.filter(child =>
      currentSelection.some(selected => selected.event_id === child.event_id)
    ).length
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
    } else if (isPartiallySelected){

      console.log('优化部分选中反选:', root.event_id)


      // 精确反选子节点：已选的取消，未选的选中
      childNodes.forEach(child => {
        const isChildCurrentlySelected = currentSelection.some(selected => selected.event_id === child.event_id)

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
const pageSize = ref(10)

// 数组：每页可选显示行数
const pageSizeOptions = [5, 10, 20, 50,100,200]


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
  // nextTick(() => {
  //   // 将响应式变量blinkTrigger的值设置为true，用于重启闪烁效果，同步闪烁效果
    blinkTrigger.value = true
  // })
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
  console.log('选择变更:', selection.map(row => row.event_id))
  // 在聚合模式下处理父子节点联动
  if (isAggregate.value) {
    // 延迟执行父子节点同步
    setTimeout(() => {
      syncParentChildSelection()
    }, 100)
  }
}
// 新增：标记是否正在处理行选择事件
let isRowSelectProcessing = false
// 新增：自定义行选择处理函数
const handleRowSelect = (selection,row) => {
  console.log('行选择事件:', row.event_id, row.hasChildren)
  console.log('行选择事件:',selectedEventIds.value)
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
    console.log('行选择事件结束:',selectedEventIds.value)
    console.log('行选择事件结束:selectedRows',selectedRows.value)
  }
  finally {
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

  // 非聚合模式：直接执行默认全选逻辑
  // 非聚合模式：不干预，让 Element Plus 自动处理
  // Element Plus 的 @select-all 事件会自动完成全选/取消全选
  if (!isAggregate.value) {
    console.log('非聚合模式，由 Element Plus 自动处理全选')
    // 只需要更新 selectedRows 即可
    selectedRows.value = selection
    return
  }

  // 聚合模式：先检查根节点展开状态
  const allRootNodes = currentPageData.value.filter(row => row.hasChildren)
  const unexpandedRootNodes = allRootNodes.filter(rootNode => !expandedRows.value.has(rootNode.event_id))

  // 如果有未展开的根节点，提示用户
  if (unexpandedRootNodes.length > 0) {
    // 阻止默认的全选行为
    // 注意：Element Plus 的 select-all 事件无法直接阻止，我们通过不执行后续操作来实现

    // 如果已有消息实例，先关闭所有消息
    if (messageInstance.value) {
      ElMessage.closeAll()
      await new Promise(resolve => setTimeout(resolve, 0));
    }

    // 显示警告消息
    messageInstance.value = ElMessage.warning({
      message: `请展开所有根节点后再进行批量选择操作`,
      duration: 3000,
      offset: window.innerHeight / 2 - 20,
      onClose: () => {
        messageInstance.value = null
      }
    })

    // 重要：恢复表格的选中状态到点击前的状态
    // 因为 select-all 事件已经触发了全选/取消全选，我们需要撤销这个操作
    nextTick(() => {
      tableRef.value?.clearSelection()
      // 恢复之前的选中状态
      if (selectedRows.value.length > 0) {
        selectedRows.value.forEach(row => {
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
      if (node.children && node.children.some(child => child.event_id === childEventId)) {
        return node
      }
      // 检查缓存的子节点
      if (node._cachedChildren && node._cachedChildren.some(child => child.event_id === childEventId)) {
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

    // 重要：在修改 tableData 之前先获取选中的 event IDs，使用闭包保存快照
    const eventIdsToClose = selectedRows.value
      .filter(row => !(isAggregate.value && row.hasChildren))
      .map(row => row.event_id)
    console.log('eventIdsToClose',eventIdsToClose)
    const handleUser = sessionStorage.getItem('user')
    // 调用关闭告警接口
    // 参数：选中的告警ID列表和处理意见
    // await：阻塞代码执行，等待异步函数closeAlert执行完成
    await closeAlert(tableData.value,selectedEventIds.value, handleOpinion.value,handleUser)
    console.log('tableData1',tableData.value)
    // 根据是否为聚合模式采用不同的数据移除策略
    if (isAggregate.value) {
      // 聚合模式：从树形结构中移除节点
      removeNodesFromTree(tableData.value, selectedEventIds.value)
    } else {
      // 非聚合模式：从平面数组中移除
      removeNodesFromArray(tableData.value, selectedEventIds.value)
    }
    console.log('tableData2',tableData.value)
    // 清空选中行数组
    selectedRows.value = []
    // 清除表格的选中状态，这样即使旧数据重新被加载进来，也不会保持选择状态
    tableRef.value?.clearSelection()

    await nextTick(() => {
      // 重置模态框状态，关闭确认对话框
      DialogVisibleClose.value = false
    })
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
  if (!tableRef.value) return

  const lazyTreeNodeMap = tableRef.value.store.states.lazyTreeNodeMap.value
  console.log('lazyTreeNodeMap',lazyTreeNodeMap)
  console.log('treeData',treeData)
  // 记录需要更新的根节点
  const rootNodesToUpdate = new Set()

  for (let i = treeData.length - 1; i >= 0; i--) {
    const node = treeData[i]
    console.log('node',node)
    const parentNode = lazyTreeNodeMap[node.event_id]
    console.log('parentNode1',parentNode)
    // 如果是根节点（聚合模式下的主机节点）
    if (node.isHostNode) {
      // 检查根节点本身是否需要被移除
      if (eventIdsToRemove.includes(node.event_id)) {
        console.log('移除根节点',node)
        // 清除该根节点的展开状态记录
        if (expandedRows.value.has(node.event_id)) {
          expandedRows.value.delete(node.event_id)
          console.log('已清除根节点展开状态记录:', node.event_id)
        }
        // 根节点本身需要关闭：移除整个根节点及其所有子节点
        treeData.splice(i, 1)
        continue
      }
      console.log('执行到这了。。。。。' +
        '')
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
            console.log('parentNode',parentNode)
            if (parentNode && j < parentNode.length) {
              parentNode.splice(j, 1)
            }
            console.log('parentNode2',parentNode)
            console.log('parentNode3',tableData.value)
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
      const hasChildren = (node.children && node.children.length > 0) ||
        (node._cachedChildren && node._cachedChildren.length > 0)

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
      rootNodesToUpdate.forEach(eventId => {
        const rootNode = treeData.find(node => node.event_id === eventId)
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
          const severityOrder = { "严重": 3,"重要":2,"一般": 1,"普通": 0 }
          const severityDiff = severityOrder[b.severity] - severityOrder[a.severity]
          if (severityDiff !== 0) return severityDiff

          return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
        })
        // 限制为前 50 条
        const limitedSortedChildren = sortedChildren.slice(0, 50)
        // 限制加载数量为前 50 条
        tableData.value = tableData.value.map(node => {
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
  for (let i = arrayData.length - 1; i >= 0; i--) {
    if (eventIdsToRemove.includes(arrayData[i].event_id)) {
      arrayData.splice(i, 1)
    }
  }
}

// 更新根节点统计信息
const updateRootNodeStatistics = (rootNode) => {
  if (rootNode.children && rootNode.children.length > 0 || rootNode._cachedChildren && rootNode._cachedChildren.length > 0) {
    const stats = {
      total: rootNode._cachedChildren ? rootNode._cachedChildren.length : 0,
      critical: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.severity === '严重').length : 0,
      important: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.severity === '重要').length : 0,
      normal: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.severity === '一般').length : 0,
      ordinary: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.severity === '普通').length : 0,
      processed: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.state === '已分派' || child.state === '已关闭').length : 0,
      unprocessed: rootNode._cachedChildren ? rootNode._cachedChildren.filter(child => child.state === '未处理').length : 0,
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
  const severityOrder = { "严重": 4, "重要": 3, "一般": 2, "普通": 1 }

  // 如果没有子节点，返回默认级别
  if (!children || children.length === 0) {
    return "普通"
  }

  // 使用 reduce 方法遍历数组，找出最高严重级别
  return children.reduce((highest, alarm) => {
    const currentLevel = severityOrder[alarm.severity] || 0
    const highestLevel = severityOrder[highest] || 0

    // 如果当前报警级别高于已知最高级别，更新最高级别
    return currentLevel > highestLevel ? alarm.severity : highest
  }, "普通") // 初始最高级别设为"普通"
}

// 获取最新时间（从 treeData.js 中提取的逻辑）
const getLatestTime = (children) => {
  return children.reduce((latest, alarm) => {
    const currentTime = new Date(alarm.occurrenceTime)
    const latestTime = new Date(latest)
    return currentTime > latestTime ? alarm.occurrenceTime : latest
  }, "1970-01-01 00:00:00")
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
    console.log('当前选中行:', currentSelection.map(row => ({
      id: row.event_id,
      type: row.hasChildren ? 'parent' : 'child',
      root: row.hasChildren ? row : ''
    })))

    // 找出所有根节点（无论是否选中）
    const allParents = currentPageData.value.filter(row => row.hasChildren)

    allParents.forEach(parent => {
      const isParentSelected = currentSelection.some(row => row.event_id === parent.event_id)
      console.log(`isParentSelected: ${isParentSelected}`)
      // 获取子节点
      let childNodes = []
      if (parent.children && parent.children.length > 0) {
        childNodes = parent.children
      } else if (parent._cachedChildren) {
        childNodes = parent._cachedChildren
      }
      console.log('childNodes',childNodes)
      const selectedChildren = childNodes.filter(child =>
        currentSelection.some(selected => selected.event_id === child.event_id)
      )
      console.log('selectedChildren',selectedChildren)
      console.log(`父节点 ${parent.event_id}: 选中=${isParentSelected}, 子节点总数=${childNodes.length}, 已选中子节点=${selectedChildren.length}`)

      if (isParentSelected) {
        // 父节点被选中 -> 确保所有子节点都被选中
        childNodes.forEach(child => {
          if (!currentSelection.some(selected => selected.event_id === child.event_id)) {
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
  }
  finally {
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

  const selectedChildren = childNodes.filter(child =>
    selectedRows.value.some(selected => selected.event_id === child.event_id)
  )

  console.log(`父节点 ${parentNode.event_id} 的子节点选择情况: ${selectedChildren.length}/${childNodes.length}`)

  // 根据子节点选择情况更新父节点状态
  if (selectedChildren.length === childNodes.length && childNodes.length > 0) {
    // 所有子节点都被选中 -> 选中父节点
    if (!selectedRows.value.some(row => row.event_id === parentNode.event_id)) {
      console.log('所有子节点选中，选中父节点:', parentNode.event_id)
      tableRef.value?.toggleRowSelection(parentNode, true)
    }
  } else if (selectedChildren.length === 0) {
    // 没有子节点被选中 -> 取消父节点选择
    if (selectedRows.value.some(row => row.event_id === parentNode.event_id)) {
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

    operations.forEach(op => {
      if (op.action === 'select') {
        nodesToSelect.push(op.node)
      } else {
        nodesToDeselect.push(op.node)
      }
    })

    // 批量执行选择操作
    if (nodesToSelect.length > 0) {
      console.log(`批量选中 ${nodesToSelect.length} 个节点`)
      nodesToSelect.forEach(node => {
        tableRef.value.toggleRowSelection(node, true)
      })
    }

    if (nodesToDeselect.length > 0) {
      console.log(`批量取消 ${nodesToDeselect.length} 个节点`)
      nodesToDeselect.forEach(node => {
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
        @select="handleRowSelect"
        :select-on-indeterminate="false"
        @select-all="handleSelectAllHeader">
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
          <template #default="scope">
            <div class="operation-buttons" style="display: flex; justify-content: space-around; align-items: center; user-select: none;">
              <el-dropdown trigger="click">
                <el-button
                  type="primary"
                  :icon="Edit"
                  :disabled="isAggregate && scope.row.hasChildren"
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
      style="user-select: text;height: 300px"
      destroy-on-close
      @close="() => { dialogVisibleView = false }"
    >
      <el-tabs
        v-model="activeName"
        type="card"
        class="demo-tabs"
        @tab-click="handleClick"
        style="user-select: none;"
      >
        <el-tab-pane label="基本信息" name="基本信息" style="user-select: text;">
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
        </el-tab-pane>
        <el-tab-pane label="处理过程" name="处理过程" style="user-select: text;">
          <el-table
            :data="[currentRow]"
            border
            :cell-style="{ textAlign: 'center', verticalAlign: 'middle', padding: '8px 0' }"
            :header-cell-style="{ textAlign: 'center' }"
          >
            <el-table-column prop="state" label="操作类型" min-width="10%" :resizable="false">
              <template #default="{row}">
                <span :class="getStateClass(row.state)">{{ row.state }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="system_name" label="处理时间" min-width="20%" :resizable="false">
              <template #default="{row}">
                {{ row.system_name || '/' }}
              </template>
            </el-table-column>
            <el-table-column prop="category" label="操作人" min-width="15%" :resizable="false">
              <template #default="{row}">
                {{ row.category || '/' }}
              </template>
            </el-table-column>
            <el-table-column prop="object" label="相关对象" min-width="15%" :resizable="false">
              <template #default="{row}">
                {{ row.object || '/' }}
              </template>
            </el-table-column>
            <el-table-column prop="ip" label="处理意见" min-width="40%" :resizable="false">
              <template #default="{row}">
                {{ row.ip || '/' }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>

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
