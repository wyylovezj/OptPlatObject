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
const formatMenuTree = (menus, level = 1, parentId = null) => {
  console.log('menus',menus)
  return menus.map(menu => ({
    id: menu.id,
    parentId: parentId,
    label: menu.name,
    path: menu.path,
    icon: menu.icon,
    permissionCode: menu.permissionCode,
    order: menu.orderNum,
    type: menu.menuType,
    level: level,
    children: menu.children ? formatMenuTree(menu.children, level + 1, menu.id) : []
  }))
}

// 打开新增菜单对话框
const openCreateDialog = (parent) => {
  console.log('parent',parent)
  currentMenu.value = null

  // 根据父级层级确定新菜单的层级和默认类型
  let defaultType = 1  // 第一层默认目录
  let defaultPath = ''
  let defaultOrder = 0

  if (parent) {
    // 新增子项，路由路径默认填充父菜单的路由路径
    defaultPath = parent.path || ''
    // 排序根据已有的同级子菜单数量递增
    defaultOrder = parent.children ? parent.children.length : 0
    // 根据层级确定类型：第二层默认菜单，第三层默认按钮
    const childLevel = (parent.level || 1) + 1
    if (childLevel === 2) {
      defaultType = 2  // 菜单
    } else if (childLevel >= 3) {
      defaultType = 3  // 按钮
    }
  } else {
    // 新增根菜单，排序根据已有的根菜单数量递增
    defaultOrder = menuTree.value.length
  }

  formData.value = {
    parentId: parent ? parent.id : null,
    parentName: parent ? parent.label : null,
    name: '',
    path: defaultPath,
    icon: '',
    permissionCode: '',
    order: defaultOrder,
    type: defaultType
  }
  dialogVisible.value = true
}

// 根据子节点id在菜单树中查找父节点
const findParentInTree = (nodes, childId) => {
  for (const node of nodes) {
    if (node.children && node.children.some(c => c.id === childId)) {
      return node
    }
    if (node.children && node.children.length > 0) {
      const found = findParentInTree(node.children, childId)
      if (found) return found
    }
  }
  return null
}

// 打开编辑菜单对话框
const openEditDialog = (menu) => {
  console.log('menu',menu)
  currentMenu.value = menu
  const parent = findParentInTree(menuTree.value, menu.id)
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
    <el-card class="list-card" shadow="never">
      <div class="table-wrapper">
        <div class="table-toolbar">
          <div class="toolbar-left">
            <span class="toolbar-title">菜单树</span>
            <span class="toolbar-sep"></span>
          </div>
          <div class="toolbar-actions">
            <el-button class="toolbar-btn-refresh" @click="loadMenuTree">
              <svg class="icon-svg" viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>
            </el-button>
            <el-button v-if="permissionStore.hasPermission('system:createRoot')" class="toolbar-btn-create" @click="openCreateDialog(null)">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新增根菜单
            </el-button>
          </div>
        </div>
        <el-scrollbar style="flex: 1;" v-loading="loading">
          <el-tree
            :data="menuTree"
            node-key="id"
            style="margin-right: 10px;"
            :expanded-keys="expandedKeys"
            default-expand-all
            :expand-on-click-node="false"
            @node-expand="handleNodeExpand"
            @node-collapse="handleNodeCollapse"
          >
            <template #default="{ node, data }">
            <span class="custom-tree-node" :class="'tree-level-' + data.level">
              <span class="tree-node-label">
                <span v-if="data.icon" class="tree-icon-wrap" :class="'icon-level-' + data.level">
                  <el-icon :style="{ width: data.level === 1 ? '18px' : '16px', height: data.level === 1 ? '18px' : '16px', fontSize: data.level === 1 ? '18px' : '16px' }">
                    <svg class="icon" aria-hidden="true">
                      <use :xlink:href="'#' + data.icon"></use>
                    </svg>
                  </el-icon>
                </span>
                <span class="tree-node-name" :style="{ fontSize: (19 - (data.level - 1) * 3) + 'px' }">{{ node.label }}</span>
                <span class="tree-type-tag" :class="'type-' + data.type">
                  {{ {1:'目录',2:'菜单',3:'按钮'}[data.type] || '' }}
                </span>
                <template v-if="data.type === 3">
                  <el-tooltip v-if="data.permissionCode" :content="data.permissionCode" placement="top" :show-after="300">
                    <span class="tree-path-hint">{{ data.permissionCode }}</span>
                  </el-tooltip>
                </template>
                <template v-else>
                  <el-tooltip v-if="data.path" :content="data.path" placement="top" :show-after="300">
                    <span class="tree-path-hint">{{ data.path }}</span>
                  </el-tooltip>
                </template>
              </span>
              <span class="tree-actions">
                <el-button v-if="permissionStore.hasPermission('system:createChildNode')" class="table-btn-primary" size="small" @click="openCreateDialog(data)">
                  <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新增
                </el-button>
                <el-button v-if="permissionStore.hasPermission('system:editMenus')" class="table-btn-warning" size="small" @click="openEditDialog(data)">
                  <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </el-button>
                <el-button
                  v-if="data.level && data.level >= 2 && permissionStore.hasPermission('system:deleteMenus')"
                  class="table-btn-danger"
                  size="small"
                  @click="handleDelete(data)"
                >
                  <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>
                </el-button>
              </span>
            </span>
            </template>
          </el-tree>
        </el-scrollbar>
      </div>
    </el-card>

    <!-- 新增/编辑菜单对话框 -->
    <el-dialog v-model="dialogVisible" width="600px" :show-close="false" class="assign-dialog" top="5vh">
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">{{ currentMenu ? '编辑菜单' : '新增菜单' }}</span>
            <span class="dialog-subtitle">{{ currentMenu ? '修改菜单信息' : '创建新的菜单项' }}</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <el-form ref="formRef" :model="formData" :rules="formRules" label-width="100px" autocomplete="off">
          <el-form-item label="父级菜单">
            <el-tag style="margin-right: 5px; font-size: 14px;">{{ formData.parentId ? formData.parentName : '无（根菜单）' }}</el-tag>
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
            <el-input v-model="formData.permissionCode" placeholder="请输入权限码，如：alarm:manage" spellcheck="false"/>
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
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="dialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveMenu">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.menu-manage-container {
  display: flex; flex-direction: column; height: 100%; box-sizing: border-box; user-select: none;
}

/* 列表卡片 */
.list-card {
  flex: 1; border-radius: 10px; overflow: hidden; display: flex; flex-direction: column;
}
.list-card :deep(.el-card__body) {
  display: flex; flex-direction: column; flex: 1; padding: 16px 20px; overflow: hidden;
}
.table-wrapper {
  flex: 1; min-height: 0; display: flex; flex-direction: column;
}
.table-toolbar {
  display: flex; justify-content: space-between; align-items: center; padding: 2px 0 8px;
}
.toolbar-title {
  font-size: 14px; font-weight: 600; color: #303133; user-select: none;
}
.toolbar-sep {
  width: 1px; height: 24px; background: #e2e8f0; flex-shrink: 0;
}
.toolbar-left {
  display: flex; align-items: center; gap: 12px;
}
.toolbar-actions {
  display: flex; gap: 8px; flex-shrink: 0;
}

/* 刷新按钮 */
.toolbar-btn-refresh {
  width: 32px; height: 32px; padding: 0; border-radius: 8px !important;
  display: inline-flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #f0f2f5, #e8eaef); border: none;
  transition: all 0.25s ease;
}
.toolbar-btn-refresh:hover {
  background: linear-gradient(135deg, #e5e7eb, #dcdde2);
  transform: translateY(-1px);
}
:deep(.el-tree-node__content) {
  height: auto;
  padding: 1px 0;
}

:deep(.toolbar-btn-create) {
  padding: 0 14px; height: 32px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 5px;
  background: linear-gradient(135deg, #409eff, #337ecc);
  border: none; color: #fff; font-size: 13px; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.toolbar-btn-create:hover) {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(64, 158, 255, 0.4);
}

/* 图标 */
.icon-svg {
  width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-width: 2;
  stroke-linecap: round; stroke-linejoin: round;
}

.custom-tree-node {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 14px;
  padding: 1px 8px 1px 4px;
  border-radius: 6px;
  transition: all 0.2s ease;
}
.custom-tree-node:hover {
  background: #f5f7fa;
}
/* 一级节点（根目录） */
.tree-level-1 {
  background: #f8fafd;
  border-left: 3px solid #667eea;
}
.tree-level-1:hover {
  background: #eef2f9;
}
/* 二级节点（菜单） */
.tree-level-2 {
  border-left: 2px solid transparent;
}
.tree-level-2:hover {
  border-left-color: #e6a23c;
}
/* 三级节点（按钮） */
.tree-level-3 {
  border-left: 2px solid transparent;
}
.tree-level-3:hover {
  border-left-color: #67c23a;
}

/* 节点标签区域 */
.tree-node-label {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

/* 图标包裹 */
.tree-icon-wrap {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: #f0f2f5;
  color: #606266;
  transition: all 0.2s ease;
}
.custom-tree-node:hover .tree-icon-wrap {
  background: #e4e7ed;
}
.icon-level-1 {
  background: rgba(102, 126, 234, 0.12);
  color: #667eea;
}
.custom-tree-node:hover .icon-level-1 {
  background: rgba(102, 126, 234, 0.2);
}

/* 节点名称 */
.tree-node-name {
  font-weight: 500;
  color: #303133;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tree-level-1 .tree-node-name {
  font-weight: 600;
  color: #1a1a2e;
}

/* 类型标签 */
.tree-type-tag {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 500;
  flex-shrink: 0;
  line-height: 18px;
}
.type-1 {
  background: rgba(102, 126, 234, 0.1);
  color: #667eea;
}
.type-2 {
  background: rgba(230, 162, 60, 0.1);
  color: #e6a23c;
}
.type-3 {
  background: rgba(103, 194, 58, 0.1);
  color: #67c23a;
}

/* 路径提示 */
.tree-path-hint {
  font-size: 11px;
  color: #c0c4cc;
  margin-left: 6px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 180px;
  flex-shrink: 1;
  min-width: 0;
}


.tree-actions {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
  opacity: 0.7;
  transition: opacity 0.2s ease;
}
.custom-tree-node:hover .tree-actions {
  opacity: 1;
}

.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
  margin-right: 5px;
}

/* 树节点按钮 - 缩小高度避免撑大行高 */
:deep(.table-btn-primary) {
  height: 20px; padding: 0 5px; font-size: 11px; border-radius: 4px !important;
  display: inline-flex; align-items: center; gap: 2px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-primary:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.35);
}
:deep(.table-btn-warning) {
  height: 20px; padding: 0 5px; font-size: 11px; border-radius: 4px !important;
  display: inline-flex; align-items: center; gap: 2px;
  background: linear-gradient(135deg, #e6a23c, #cf9236);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-warning:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(230, 162, 60, 0.35);
}
:deep(.table-btn-danger) {
  height: 20px; padding: 0 5px; font-size: 11px; border-radius: 4px !important;
  display: inline-flex; align-items: center; gap: 2px;
  background: linear-gradient(135deg, #f56c6c, #d95555);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-danger:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(245, 108, 108, 0.35);
}

/* 对话框样式 */
.assign-dialog {
  border-radius: 20px !important;
  overflow: hidden;
}
.assign-dialog :deep(.el-dialog__header) {
  padding: 0;
  margin: 0;
}
.assign-dialog :deep(.el-dialog__body) {
  padding: 0;
}
.assign-dialog :deep(.el-dialog__footer) {
  padding: 0;
}
.assign-dialog .dialog-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 24px 28px;
  display: flex;
  align-items: center;
  gap: 16px;
}
.assign-dialog .dialog-header-icon {
  width: 52px;
  height: 52px;
  background: rgba(255,255,255,0.2);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
}
.assign-dialog .dialog-header-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.assign-dialog .dialog-title {
  font-size: 20px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.5px;
}
.assign-dialog .dialog-subtitle {
  font-size: 13px;
  color: rgba(255,255,255,0.75);
}
.assign-dialog .dialog-body {
  padding: 24px 28px;
  background: #f8f9fe;
}
.assign-dialog .dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 16px 28px 24px;
  background: #f8f9fe;
}
.assign-dialog .dialog-btn-cancel {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 20px;
  font-size: 14px;
  display: inline-flex;
  align-items: center;
  border: 1px solid #e4e7f0;
  background: #fff;
  transition: all 0.25s ease;
}
.assign-dialog .dialog-btn-cancel:hover {
  border-color: #667eea;
  color: #667eea;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
}
.assign-dialog .dialog-btn-save {
  border-radius: 10px !important;
  height: 38px;
  padding: 0 24px;
  font-size: 14px;
  display: inline-flex;
  align-items: center;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none;
  transition: all 0.25s ease;
}
.assign-dialog .dialog-btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}
</style>
