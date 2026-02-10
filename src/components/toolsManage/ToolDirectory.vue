<script setup>
import { ref, markRaw,watch  } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete,CirclePlusFilled,RemoveFilled,Refresh } from '@element-plus/icons-vue'
import { handleNodeClick } from '@/utils/publicDataTools.js'

// 目录树实例
const treeRef2 = ref(null)
// 目录树筛选字符
const filterText = ref('')
// 监听筛选字符变化
watch(filterText, (val) => {
  treeRef2.value?.filter(val)
})
// 目录树筛选函数
const filterNode = (value, data) => {
  if (!value) return true
  return data.label.includes(value)
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
const dataSource = ref([
  {
    id: 1,
    label: '工具库',
    children: [
      {
        id: 2,
        label: '系统工具',
        children: [
          {
            id: 4,
            label: '工单导出'
          },
          {
            id: 5,
            label: '域账号解锁'
          }
        ]
      },
      {
        id: 3,
        label: '网络工具'
      },
    ],
  },
])
</script>

<template>
  <div class="toolsDirectory">
    <p style="text-align: center;">工具库分类</p>
    <el-input
      v-model="filterText"
      class="w-60 mb-2"
      placeholder="搜索"
      style="margin-bottom: 20px;"
    />
    <el-tree
      ref="treeRef2"
      style="max-height: 85%;overflow: auto"
      :data="dataSource"
      node-key="id"
      default-expand-all
      :filter-node-method="filterNode"
      check-on-click-node
      @node-click="handleNodeClick"
    >
      <template #default="{ node, data }">
        <div class="custom-tree-node">
          <span>{{ node.label }}</span>
<!--          <div>-->
<!--            <el-button-->
<!--              v-if="node.level < 3"-->
<!--              type="primary"-->
<!--              link-->
<!--              @click.stop="append(data)">-->
<!--              <el-icon :size="15">-->
<!--                <CirclePlusFilled/>-->
<!--              </el-icon>-->
<!--            </el-button>-->
<!--            <el-button-->
<!--              v-if="node.level === 1"-->
<!--              type="primary"-->
<!--              link-->
<!--              @click.stop="refresh(node, data)"-->
<!--              style="margin-left: 0 "-->
<!--            >-->
<!--              <el-icon :size="15">-->
<!--                <Refresh />-->
<!--              </el-icon>-->
<!--            </el-button>-->
<!--            <el-button-->
<!--              v-if="node.level > 1 && (!data.children || data.children.length === 0)"-->
<!--              type="danger"-->
<!--              link-->
<!--              @click.stop="remove(node, data)"-->
<!--              style="margin-left: 0 "-->
<!--            >-->
<!--              <el-icon :size="15">-->
<!--                <RemoveFilled />-->
<!--              </el-icon>-->
<!--            </el-button>-->
<!--          </div>-->
        </div>
      </template>
    </el-tree>
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
.el-tree::-webkit-scrollbar {
  width: 0; /* 隐藏滚动条 */
}

.el-tree {
  max-height: 85%;
  overflow-y: scroll;
  scrollbar-width: thin; /* Firefox 隐藏滚动条 */
}
</style>
