<script setup>
import { ref, markRaw,watch,onMounted  } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete,CirclePlusFilled,RemoveFilled,Refresh } from '@element-plus/icons-vue'
import {
  countLeafNodes,
  handleNodeClick,
  leafNodeCount,
  selectedNode,
  toolSTree
} from '@/utils/publicDataTools.js'

// 目录树实例
const treeRef2 = ref(null)
// 目录树筛选字符
const filterText = ref('')

// 构建过滤后的树结构
const getFilteredTree = (nodes, filterValue) => {
  const result = [];
  nodes.forEach(node => {
    // 检查当前节点是否匹配
    const isMatch = node.label.includes(filterValue);

    // 递归处理子节点
    const filteredChildren = node.children ? getFilteredTree(node.children, filterValue) : [];

    // 如果当前节点匹配或者有匹配的子节点，则保留该节点
    if (isMatch || filteredChildren.length > 0) {
      result.push({
        ...node,
        children: isMatch ? node.children : filteredChildren // 若当前节点匹配，保留所有子节点；否则保留过滤后的子节点
      });
    }
  });
  return result;
};



// 监听筛选字符变化
watch(filterText, (val) => {
  treeRef2.value?.filter(val)
  console.log(treeRef2.value?.filter(val))
  // 使用过滤后的树结构，filteredTree是一个数据，需要使用其第一个元素作为节点对象
  const filteredTree = getFilteredTree(dataSource.value, filterText.value);
  selectedNode.value = filteredTree[0]
  console.log(filteredTree)
})
const dataSource = ref(toolSTree)
// 构建父子关系映射
const buildParentMap = (nodes, parentMap = {}) => {
  nodes.forEach(node => {
    if (node.children && node.children.length > 0) {
      node.children.forEach(child => {
        parentMap[child.id] = node.id // 记录子节点的父节点ID
      })
      buildParentMap(node.children, parentMap) // 递归处理子节点
    }
  })
  return parentMap
}
// 根据子节点找父节点
const parentMap = buildParentMap(dataSource.value)

// 目录树筛选函数
const filterNode = (value, data) => {
  if (!value) {
    // 没有值时，返回根节点
    return selectedNode.value
  }

  // 检查当前节点是否匹配
  const isCurrentMatch = data.label.includes(value)

  // 检查父节点是否匹配
  let isParentMatch = false
  let parentId = parentMap[data.id]
  while (parentId) {
    const parentNode = findNodeById(dataSource.value, parentId)
    if (parentNode && parentNode.label.includes(value)) {
      isParentMatch = true
      break
    }
    parentId = parentMap[parentId] // 继续向上查找父节点
  }

  return isCurrentMatch || isParentMatch
}

// 根据节点ID查找节点
const findNodeById = (nodes, id) => {
  for (const node of nodes) {
    if (node.id === id) return node
    if (node.children && node.children.length > 0) {
      const found = findNodeById(node.children, id)
      if (found) return found
    }
  }
  return null
}




let id = 1000
const refresh = (data) => {
  console.log(data)
}
// 新增目录或节点
const append = (data) => {
  ElMessageBox.prompt('', '新增子节点', {
    confirmButtonText: '确认',
    cancelButtonText: '取消',
    inputPattern: /[a-zA-Z0-9\u4e00-\u9fa5]/,
    inputErrorMessage: '节点名仅支持中文、数字和英文',
    inputPlaceholder: '请输入节点名',
    customClass: 'custom-message-box-tools'
  })
    .then(({ value }) => {
      const newChild = { id: id++, label: value, children: [] }
      treeRef2.value?.append(newChild, data)
      // 新增：展开父节点
      treeRef2.value?.expend(data)
      ElMessage({
        type: 'success',
        message: `新增子节点：${value}`,
      })
    })
}
// 删除目录或节点
const remove = (node, data) => {
  ElMessageBox.confirm(
    `确认要删除节点：${data.label}?`,
    '删除节点',
    {
      confirmButtonText: '确认',
      cancelButtonText: '取消',
      type: 'warning',
      icon: markRaw(Delete),
      customClass: 'custom-message-box'
    }
  )
    .then(() => {
      treeRef2.value?.remove(data)
      ElMessage({
        type: 'success',
        message: `节点${data.label}已删除`,
      })
    })
}
// 高亮树节点搜索中匹配的字符
const highlightText = (text, keyword) => {
  if (!keyword) return text; // 如果没有输入过滤字符，直接返回原文本
  const regex = new RegExp(`(${keyword})`, 'gi'); // 创建正则表达式，忽略大小写
  return text.replace(regex, '<mark>$1</mark>'); // 将匹配的部分用 <mark> 标签包裹
};

onMounted(() => {
  selectedNode.value = toolSTree[0]
  leafNodeCount.value = countLeafNodes(toolSTree[0])
})
</script>

<template>
  <div class="toolsDirectory">
    <p style="text-align: center;">工具库分类</p>
    <el-input
      v-model="filterText"
      class="w-60 mb-2"
      placeholder="搜索"
      style="margin-bottom: 20px;"
      clearable
    />
    <el-scrollbar height="85%;">
      <el-tree
        ref="treeRef2"
        style="margin-right: 5px;"
        :data="dataSource"
        node-key="id"
        default-expand-all
        :filter-node-method="filterNode"
        check-on-click-node
        @node-click="handleNodeClick"
      >
        <template #default="{ node }">
          <div class="custom-tree-node">
            <!-- 使用 v-html 渲染高亮文本 -->
            <span v-html="highlightText(node.label, filterText)"></span>
          </div>
        </template>
      </el-tree>
    </el-scrollbar>

  </div>
</template>

<style scoped>
.custom-tree-node {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 14px;
  padding-right: 8px;
}
.toolsDirectory {
  display: flex;
  flex-direction: column;
  width: 15%;
  user-select: none;
  border: #DCDFE6 solid 1px;
  padding: 15px 30px;
  background-color: #FFFFFF;
  border-radius: 10px;
  margin-right: 10px;
}
/*.el-tree::-webkit-scrollbar {
  width: 0; !* 隐藏滚动条 *!
}

.el-tree {
  max-height: 85%;
  overflow-y: scroll;
  scrollbar-width: thin; !* Firefox 隐藏滚动条 *!
}*/
mark {
  background-color: yellow;
  color: black;
  padding: 2px 4px;
  border-radius: 4px;
}

</style>
