<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 菜单管理页面
 * @date: 2026-03-30 10:00:00
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-03-30 10:00:00
 */
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getMenuList, createMenu, updateMenu, deleteMenu } from '@/api/userPermisssion.js'
import { usePermissionStore } from '@/stores/permissionStore.js'



// 权限状态管理
const permissionStore = usePermissionStore()

// 菜单树形结构
const menuTree = ref([])
// 加载状态
const loading = ref(false)
// 对话框可见性
const dialogVisible = ref(false)
// 当前编辑的菜单
const currentMenu = ref(null)
// 表单数据
const formData = ref({
  parentId: null,
  parentName: null,
  name: '',
  path: '',
  icon: '',
  permissionCode: '',
  order: 0,
  type: ''
})
// 表单验证规则
const formRules = ref({
  name: [
    { required: true, message: '请输入菜单名称', trigger: 'blur' }
  ],
  path: [
    { required: true, message: '请输入路由路径', trigger: 'blur' }
  ]
})
// Form ref
const formRef = ref(null)
// 展开的节点
const expandedKeys = ref([])

// 加载菜单树
const loadMenuTree = async () => {
  loading.value = true
  try {
    const menus = await getMenuList()
    menuTree.value = formatMenuTree(menus)
  } catch (error) {
    ElMessage.error('加载菜单树失败：' + error.message)
  } finally {
    loading.value = false
  }
}

// 格式化菜单树
const formatMenuTree = (menus,level = 1) => {
  console.log('menus',menus)
  return menus.map(menu => ({
    id: menu.id,
    label: menu.name,
    path: menu.path,
    icon: menu.icon,
    permissionCode: menu.permissionCode,
    order: menu.orderNum,
    type: menu.menuType,
    level: level,
    children: menu.children ? formatMenuTree(menu.children,level + 1) : []
  }))
}

// 打开新增菜单对话框
const openCreateDialog = (parent) => {
  console.log('parent',parent)
  currentMenu.value = null
  formData.value = {
    parentId: parent ? parent.id : null,
    parentName: parent ? parent.label : null,
    name: '',
    path: '',
    icon: '',
    permissionCode: '',
    order: 0,
    type: 'menu'
  }
  dialogVisible.value = true
}

// 打开编辑菜单对话框
const openEditDialog = (menu) => {
  console.log('menu',menu)
  currentMenu.value = menu
  formData.value = {
    parentId: menu.parentId,
    parentName: parent ? parent.label : null,
    name: menu.label,
    path: menu.path,
    icon: menu.icon || '',
    permissionCode: menu.permissionCode || '',
    order: menu.order || 0,
    type: menu.type || 'menu'
  }
  dialogVisible.value = true
}

// 保存菜单（新增或编辑）
const saveMenu = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (!valid) return

    try {
      if (currentMenu.value) {
        // 编辑菜单
        await updateMenu(currentMenu.value.id, {
          name: formData.value.name,
          path: formData.value.path,
          icon: formData.value.icon,
          permissionCode: formData.value.permissionCode,
          order: formData.value.order,
          type: formData.value.type
        })
        ElMessage.success('更新菜单成功')
      } else {
        // 新增菜单
        await createMenu(formData.value)
        ElMessage.success('创建菜单成功')
      }
      dialogVisible.value = false
      loadMenuTree()
    } catch (error) {
      ElMessage.error((currentMenu.value ? '更新' : '创建') + '菜单失败：' + error.message)
    }
  })
}

// 删除菜单
const handleDelete = async (menu) => {
  try {
    await ElMessageBox.confirm(`确定要删除菜单"${menu.label}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteMenu(menu.id)
    ElMessage.success('删除菜单成功')
    loadMenuTree()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除菜单失败：' + error.message)
    }
  }
}

// 处理节点展开/折叠
const handleNodeExpand = (node) => {
  if (!expandedKeys.value.includes(node.id)) {
    expandedKeys.value.push(node.id)
  }
}

const handleNodeCollapse = (node) => {
  const index = expandedKeys.value.indexOf(node.id)
  if (index > -1) {
    expandedKeys.value.splice(index, 1)
  }
}

onMounted(() => {
  loadMenuTree()
})
</script>

<template>
  <div class="menu-manage-container">
    <el-card class="tree-card" body-style="height: 85%;">
      <template #header>
        <div class="card-header">
          <span>菜单树</span>
          <div>
            <el-button type="primary" @click="loadMenuTree">刷新</el-button>
            <el-button v-if="permissionStore.hasPermission('system:createRoot')" type="primary" @click="openCreateDialog(null)">新增根菜单</el-button>
          </div>
        </div>
      </template>
      <el-scrollbar height="100%;">
        <el-tree
          :data="menuTree"
          v-loading="loading"
          node-key="id"
          style="margin-right: 10px;"
          :expanded-keys="expandedKeys"
          default-expand-all
          :expand-on-click-node="false"
          @node-expand="handleNodeExpand"
          @node-collapse="handleNodeCollapse"
        >
          <template #default="{ node, data }">
          <span class="custom-tree-node">
            <span>
              <el-icon v-if="data.icon" :style="{ width: data.level === 1 ? '20px' : '18px', height: data.level === 1 ? '20px' : '18px', fontSize: data.level === 1 ? '20px' : '18px', verticalAlign: 'middle' }">
                <svg class="icon" aria-hidden="true">
                  <use :xlink:href="'#' + data.icon"></use>
                </svg>
              </el-icon>
              <span :style="{ fontSize: (20 - (data.level - 1) * 3) + 'px', verticalAlign: 'middle', marginLeft: '5px' }">{{ node.label }}</span>
            </span>
            <span class="tree-actions">
              <el-button v-if="permissionStore.hasPermission('system:createChildNode')" type="primary" size="small" @click="openCreateDialog(data)">
                新增子项
              </el-button>
              <el-button v-if="permissionStore.hasPermission('system:editMenus')" type="warning" size="small" @click="openEditDialog(data)">
                编辑
              </el-button>
              <el-button
                v-if="data.level && data.level >= 2 && permissionStore.hasPermission('system:deleteMenus')"
                type="danger"
                size="small"
                @click="handleDelete(data)"
              >
                删除
              </el-button>
            </span>
          </span>
          </template>
        </el-tree>
      </el-scrollbar>

    </el-card>

    <!-- 新增/编辑菜单对话框 -->
    <el-dialog
      v-model="dialogVisible"
      :title="currentMenu ? '编辑菜单 - ' + currentMenu.label : '新增菜单'"
      width="600px"
      style="user-select: none"
    >
      <el-form ref="formRef" :model="formData" :rules="formRules" label-width="100px" autocomplete="off">
        <el-form-item label="父级菜单">
          <el-tag
            style="margin-right: 5px; font-size: 14px;"
          >
            {{ formData.parentId? formData.parentName : '无（根菜单）' }}
          </el-tag>
        </el-form-item>
        <el-form-item label="菜单名称" prop="name">
          <el-input v-model="formData.name" placeholder="请输入菜单名称" spellcheck="false"/>
        </el-form-item>
        <el-form-item label="路由路径" prop="path">
          <el-input v-model="formData.path" placeholder="请输入路由路径，如：/alarmManagement" spellcheck="false"/>
        </el-form-item>
        <el-form-item label="图标">
          <el-input v-model="formData.icon" placeholder="请输入图标类名，如：icon-gaojingguanli" spellcheck="false"/>
        </el-form-item>
        <el-form-item label="权限码">
          <el-input
            v-model="formData.permissionCode"
            placeholder="请输入权限码，如：alarm:manage"
            spellcheck="false"
          />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="formData.order" :min="0" :max="999" />
        </el-form-item>
        <el-form-item label="类型">
          <el-radio-group v-model="formData.type">
            <el-radio :label="1">目录</el-radio>
            <el-radio :label="2">菜单</el-radio>
            <el-radio :label="3">按钮</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveMenu">
          确定
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.menu-manage-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  border-radius: 10px;
  user-select: none;
}

.tree-card {
  flex: 1;
  border-radius: 10px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.custom-tree-node {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 14px;
  padding-right: 8px;
}

.tree-actions {
  display: flex;
  gap: 5px;
}

.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
  margin-right: 5px;
}
</style>
