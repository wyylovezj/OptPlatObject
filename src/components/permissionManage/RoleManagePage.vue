<script setup>
import { useAuthStore } from '@/stores/authInfoStore.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { selectedNode } from '@/utils/publicDataTools.js'

/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 角色管理页面
 * @date: 2026-03-30 10:00:00
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-03-30 10:00:00
 */
import { ref, onMounted,computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  getAllRoles,
  assignRoleMenus,
  getMenuList,
  createRole,
  updateRole,
  deleteRole,
  getRoleMenus,
  enableRole,
  disableRole
} from '@/api/userPermisssion.js'



// 权限状态管理
const permissionStore = usePermissionStore()
const authStore = useAuthStore()

// 角色列表
const roleList = ref([])
const statusList = ref([
  {
    value: '1',
    label: '启用'
  },
  {
    value: '0',
    label: '禁用'
  }
])
// 菜单树形结构
const menuTree = ref([])
// 加载状态
const loading = ref(false)
// 分配角色对话框可见性
const dialogVisible = ref(false)
// 新增/修改角色对话框可见性
const roleVisible = ref(false)
// 当前编辑的角色
const currentRole = ref(null)
// 角色已选的叶子节点菜单
const selectedMenus = ref([])
// 查看菜单权限对话框可见性
const viewMenuDialogVisible = ref(false)
// 查看模式下的当前角色
const viewCurrentRole = ref(null)
// 查看模式下显示的菜单树
const viewMenuTree = ref([])
// 查看模式下已选中的菜单 ID（只读）
const viewCheckedMenus = ref([])
// 用于强制刷新 el-tree 组件的 key
const viewTreeKey = ref(0)
// 加载菜单树
const menuLoading = ref(false)
// 搜索条件
const searchForm = ref({
  roleCode: '', // 角色编码
  status: '', // 角色状态
})
// 重置搜索
const handleReset = () => {
  searchForm.value = {
    roleCode: '',
    status: ''
  }
  loadRoles()
}
// 搜索用户
const handleSearch = () => {
  loadRoles()
}
// 表单数据
const formData = ref({
  code: '',
  name: '',
  description: ''
})
// 分页配置
const currentPage = ref(1)
const pageSize = ref(12)
const message = ref(null)
// 计算当前页显示的数据的索引范围
const currentPageData = computed(() => {
  // 计算当前页的起始数据的索引：索引从0开始计算
  const start = (currentPage.value - 1) * pageSize.value
  // 计算当前页的结束数据的索引
  const end = start + pageSize.value
  // 返回当前页的数据的切片
  console.log('roleList',roleList.value)
  return roleList.value.slice(start, end)
})
// 表单验证规则
const formRules = ref({
  code: [
    { required: true, message: '请输入角色编码', trigger: 'blur' },
    { pattern: /^[a-z_]+$/, message: '角色编码只能包含小写字母和下划线', trigger: 'blur' }
  ],
  name: [
    { required: true, message: '请输入角色名称', trigger: 'blur' }
  ]
})
// Form ref
const formRef = ref(null)

// 加载角色列表
const loadRoles = async () => {
  loading.value = true
  try {
    const roles = await getAllRoles(searchForm.value)
    roleList.value = roles
  } catch (error) {
    ElMessage.error('加载角色列表失败：' + error.message)
  } finally {
    loading.value = false
  }
}

// 格式化菜单树为 Tree 组件所需格式
const formatMenuTree = (menus, disableCheckbox = false, disabledIds = []) => {
  return menus.map(menu => ({
    id: menu.id,
    label: menu.name,
    children: menu.children ? formatMenuTree(menu.children, disableCheckbox, disabledIds) : [],
    path: menu.path,
    permissionCode: menu.permissionCode,
    disabled: disableCheckbox || disabledIds.includes(menu.id),
  }))
}

// 打开分配菜单权限对话框
const openAssignDialog = async (role) => {
  currentRole.value = role
  selectedMenus.value = role.menus ? role.menus.map(m => m.id) : []
  dialogVisible.value = true
  try {
    // 并行请求：获取所有菜单和该角色的菜单权限
    const [allMenus, roleMenus] = await Promise.all([
      getMenuList(),
      getRoleMenus(role.code)
    ])

    // 提取该角色已拥有的叶子节点菜单 ID
    const ownedMenuIds = extractMenuIds(roleMenus)
    selectedMenus.value = ownedMenuIds

    // 如果是 admin 角色：已勾选的菜单禁止取消勾选，且自动勾选所有菜单
    if (currentRole.value.code === 'admin') {
      const allOwnedIds = extractAllMenuIds(roleMenus)
      // 自动勾选全部菜单（包含当前没有权限的菜单）
      const allMenuIds = extractMenuIds(allMenus)
      selectedMenus.value = allMenuIds
      menuTree.value = formatMenuTree(allMenus, false, allOwnedIds)
    } else {
      menuTree.value = formatMenuTree(allMenus, false)
    }

    console.log('所有菜单:', allMenus)
    console.log('角色拥有的菜单:', roleMenus)
    console.log('已选菜单 ID:', ownedMenuIds)
  } catch (error) {
    ElMessage.error('加载菜单权限失败：' + error.message)
    menuTree.value = []
    selectedMenus.value = []
  } finally {
    menuLoading.value = false
  }
}
const assignTreeRef = ref(null)
const commitSelectedMenus = ref([])
// 保存角色菜单权限
const saveRoleMenus = async () => {
  try {
    // 从 Tree 组件获取最新的选中状态（包括用户手动勾选的）
    if (assignTreeRef.value) {
      const checkedKeys = assignTreeRef.value.getCheckedKeys()
      const halfCheckedKeys = assignTreeRef.value.getHalfCheckedKeys()
      // 合并完全选中和半选中的节点
      const allMenuIds = [...new Set([...checkedKeys, ...halfCheckedKeys])]

      console.log('完全选中的节点:', checkedKeys)
      console.log('半选中的节点:', halfCheckedKeys)
      console.log('最终提交的菜单 ID:', allMenuIds)

      await assignRoleMenus(currentRole.value.code, allMenuIds)
    }
    ElMessage.success('分配菜单权限成功')
    dialogVisible.value = false
    loadRoles()
    // 关键修改：使用 authStore 的权限加载功能重新加载权限
    await refreshUserPermissions()
  } catch (error) {
    ElMessage.error('分配菜单权限失败：' + error.message)
  }
}
// 刷新用户权限并重新生成路由
const refreshUserPermissions = async () => {
  try {
    const currentUser = sessionStorage.getItem('user')
    if (!currentUser) return

    console.log('开始重新加载用户权限...')

    // 使用 authStore 中已有的 loadUserPermissions 方法
    await authStore.loadUserPermissions(currentUser)

    // 强制触发响应式更新（通过扩展数组触发 Vue 的响应式系统）
    setTimeout(() => {
      // 重新设置 accessibleMenus 以触发 SideBar 的 computed 更新
      if (permissionStore.accessibleMenus && permissionStore.accessibleMenus.length > 0) {
        permissionStore.setAccessibleMenus([...permissionStore.accessibleMenus])
      }
    }, 100)
  } catch (error) {
    console.error('刷新权限失败:', error)
    ElMessage.error('刷新权限失败：' + error.message)
  }
}
// 树形菜单选中事件处理
// const handleCheckMenu = (checkedNodeData, checkedKeysObj) => {
//   const allCheckedIds = checkedKeysObj.checkedKeys;
//   console.log('当前所有被选中的节点ID数组:', allCheckedIds);
//
//   // 你也可以获取半选中的节点ID数组
//   const halfCheckedIds = checkedKeysObj.halfCheckedKeys;
//   console.log('半选中的节点ID数组:', halfCheckedIds);
//   // 合并完全选中和半选中的节点
//   const allCheckedKeys = [...new Set([...allCheckedIds, ...halfCheckedIds])]
//
//   commitSelectedMenus.value = allCheckedKeys
// }
// 打开新增角色对话框
const openCreateDialog = () => {
  currentRole.value = null
  formData.value = {
    code: '',
    name: '',
    description: ''
  }
  roleVisible.value = true
}

// 打开编辑角色对话框
const openEditDialog = (role) => {
  currentRole.value = role
  formData.value = {
    code: role.code,
    name: role.name,
    description: role.description || ''
  }
  roleVisible.value = true
}

// 保存角色（新增或编辑）
const saveRole = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (!valid) return

    try {
      if (currentRole.value) {
        // 编辑角色
        await updateRole(formData.value.code, {
          name: formData.value.name,
          description: formData.value.description
        })
        ElMessage.success('更新角色成功')
      } else {
        // 新增角色
        await createRole(formData.value)
        ElMessage.success('创建角色成功')
      }
      roleVisible.value = false
      loadRoles()
    } catch (error) {
      ElMessage.error((currentRole.value ? '更新' : '创建') + '角色失败：' + error.message)
    }
  })
}
// 启用角色
const roleEnable = async (roleCode) => {
  try {
    const response = await enableRole(roleCode)
    if (response.code === 200) {
      loadRoles()
      if (message.value) {
        message.value.close()
      }
      message.value = ElMessage.success('启用角色成功')
    }
  } catch (error) {
    ElMessage.error('启用角色失败：' + error.message)
  }
}
const roleDisable = async (roleCode) => {
  try {
    const response = await disableRole(roleCode)
    if (response.code === 200) {
      loadRoles()
      if (message.value) {
        message.value.close()
      }
      message.value = ElMessage.success('禁用角色成功')
    }
  } catch (error) {
    ElMessage.error('禁用角色失败：' + error.message)
  }
}
// 删除角色
const handleDelete = async (role) => {
  try {
    await ElMessageBox.confirm(`确定要删除角色"${role.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteRole(role.code)
    ElMessage.success('删除角色成功')
    loadRoles()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除角色失败：' + error.message)
    }
  }
}
// 打开查看菜单权限对话框
const getRolesMenus = async (roleCode) => {
  viewCurrentRole.value = roleList.value.find(r => r.code === roleCode)
  viewMenuDialogVisible.value = true
  menuLoading.value = true

  try {
    // 调用接口获取该角色的菜单权限
    // 并行请求：获取所有菜单和该角色的菜单权限
    const [allMenus, roleMenus] = await Promise.all([
      getMenuList(),
      getRoleMenus(roleCode)
    ])

    // 格式化菜单树
    viewMenuTree.value = formatMenuTree(allMenus, true)

    // 提取该角色已拥有的菜单 ID
    const checkedMenuIds = extractMenuIds(roleMenus)
    viewCheckedMenus.value = checkedMenuIds

    // 强制刷新 el-tree 组件
    viewTreeKey.value++

    console.log('角色菜单权限:', allMenus)
    console.log('已选菜单 ID:', checkedMenuIds)
  } catch (error) {
    ElMessage.error('加载角色菜单权限失败：' + error.message)
    viewMenuTree.value = []
    viewCheckedMenus.value = []
  } finally {
    menuLoading.value = false
  }
}

// 递归提取所有菜单 ID（仅叶子节点）
const extractMenuIds = (menus) => {
  const ids = []
  const traverse = (menuList) => {
    if (!menuList || menuList.length === 0) return
    for (const menu of menuList) {
      // 只有没有子节点的才是叶子节点
      if (!menu.children || menu.children.length === 0) {
        if (menu.id) {
          ids.push(menu.id)  // ← 只保存叶子节点
        }
      } else {
        // 有子节点就递归处理
        traverse(menu.children)
      }
    }
  }
  traverse(menus)
  return ids
}

// 递归提取所有菜单 ID（包含父节点和叶子节点）
const extractAllMenuIds = (menus) => {
  const ids = []
  const traverse = (menuList) => {
    if (!menuList || menuList.length === 0) return
    for (const menu of menuList) {
      if (menu.id) {
        ids.push(menu.id)
      }
      traverse(menu.children)
    }
  }
  traverse(menus)
  return ids
}

onMounted(() => {
  loadRoles()
})
</script>

<template>
  <div class="role-manage-container">
    <div class="filter-bar">
      <el-form :model="searchForm" inline class="filter-form" autocomplete="off">
        <el-form-item class="filter-item">
          <el-input v-model="searchForm.roleCode" placeholder="角色编码" clearable style="width: 130px" spellcheck="false" @keyup.enter="handleSearch"/>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="searchForm.status" placeholder="状态" clearable style="width: 110px">
            <el-option v-for="status in statusList" :key="status.value" :label="status.label" :value="status.value"/>
          </el-select>
        </el-form-item>
        <span class="filter-sep"></span>
        <div class="filter-actions">
          <el-button class="search-btn" @click="handleSearch"><svg class="icon-svg sm" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>&nbsp;搜索</el-button>
          <el-button class="reset-btn" @click="handleReset"><svg class="icon-svg sm" viewBox="0 0 24 24"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;重置</el-button>
        </div>
      </el-form>
    </div>
    <el-card class="list-card" shadow="never">
      <div class="table-wrapper">
        <div class="table-toolbar">
          <div class="toolbar-left">
            <span class="toolbar-title">角色列表</span>
            <span class="toolbar-sep"></span>
          </div>
          <div class="toolbar-actions">
            <el-button v-if="permissionStore.hasPermission('alarm:createRole')" class="toolbar-btn-create" @click="openCreateDialog">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新增角色
            </el-button>
          </div>
        </div>
        <el-table
          :data="currentPageData"
          v-loading="loading"
          stripe
          style="width: 100%"
          empty-text="暂无角色数据"
          :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }"
        >
          <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" width="60" align="center"/>
          <el-table-column prop="code" label="角色编码" align="center"/>
          <el-table-column prop="name" label="角色名称" align="center"/>
          <el-table-column prop="description" label="描述" align="center" show-overflow-tooltip/>
          <el-table-column label="菜单权限" width="100" align="center">
            <template #default="{ row }">
              <el-button class="table-btn-primary" size="small" @click="getRolesMenus(row.code)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>&nbsp;查看
              </el-button>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small" effect="plain">{{ row.status === 1 ? '启用' : '禁用' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="300" align="center" fixed="right">
            <template #default="{ row }">
              <el-button v-if="permissionStore.hasPermission('system:assignMenus')" class="table-btn-primary" size="small" @click="openAssignDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>&nbsp;分配菜单
              </el-button>
              <el-button v-if="permissionStore.hasPermission('system:editRoles')" class="table-btn-warning" size="small" @click="openEditDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>&nbsp;编辑
              </el-button>
              <el-button v-if="row.status === 0 && permissionStore.hasPermission('system:enableRoles')" class="table-btn-success" size="small" @click="roleEnable(row.code)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;启用
              </el-button>
              <el-button v-if="row.status === 1 && permissionStore.hasPermission('system:diabledRoles')" class="table-btn-danger" size="small" @click="roleDisable(row.code)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;禁用
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="pagination-wrapper" v-if="roleList.length > 0">
        <span class="pagination-total">共 {{ roleList.length }} 条</span>
        <el-pagination v-model:current-page="currentPage" :page-size="pageSize" :total="roleList.length" layout="prev, pager, next" @current-change="() => {}" background />
      </div>
    </el-card>

    <!-- 分配菜单权限对话框 -->
    <el-dialog v-model="dialogVisible" width="700px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close @close="() => { selectedMenus = [] }">
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">分配菜单权限</span>
            <span class="dialog-subtitle">为角色分配可访问的菜单</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div style="margin-bottom: 16px;">
          <el-tag type="primary" size="large">角色：{{ currentRole?.code }} - {{ currentRole?.name }}</el-tag>
        </div>
        <el-scrollbar max-height="520px">
          <el-tree
            ref="assignTreeRef"
            :data="menuTree"
            show-checkbox
            node-key="id"
            :default-checked-keys="selectedMenus"
            :props="{ children: 'children', label: 'label' }"
            default-expand-all
          />
        </el-scrollbar>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="dialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveRoleMenus">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>
    <!--  新增/编辑角色  -->
    <el-dialog v-model="roleVisible" width="600px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">{{ currentRole ? '编辑角色' : '新增角色' }}</span>
            <span class="dialog-subtitle">{{ currentRole ? '修改角色信息' : '创建新的角色' }}</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <el-form ref="formRef" :model="formData" :rules="formRules" label-width="80px" autocomplete="off">
          <el-form-item label="角色编码" prop="code">
            <el-input v-model="formData.code" placeholder="请输入角色编码（如：admin, viewer）" :disabled="currentRole !== null" spellcheck="false"/>
          </el-form-item>
          <el-form-item label="角色名称" prop="name">
            <el-input v-model="formData.name" placeholder="请输入角色名称" spellcheck="false"/>
          </el-form-item>
          <el-form-item label="描述">
            <el-input v-model="formData.description" type="textarea" :rows="3" placeholder="请输入角色描述" spellcheck="false"/>
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="roleVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveRole">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>
    <!-- 查看菜单权限对话框 -->
    <el-dialog v-model="viewMenuDialogVisible" width="700px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">查看菜单权限</span>
            <span class="dialog-subtitle">{{ viewCurrentRole?.name }} 已拥有的菜单权限</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div v-if="viewCurrentRole">
          <div style="margin-bottom: 15px;">
            <el-tag type="primary" size="large">角色：{{ viewCurrentRole.name }}（{{ viewCurrentRole.code }}）</el-tag>
          </div>
          <div v-if="viewCurrentRole.description" style="margin-bottom: 15px; color: #909399; font-size: 13px;">描述：{{ viewCurrentRole.description }}</div>
          <el-scrollbar max-height="500px">
            <el-tree
              :key="viewTreeKey"
              :data="viewMenuTree"
              show-checkbox
              node-key="id"
              :default-checked-keys="viewCheckedMenus"
              :props="{ children: 'children', label: 'label' }"
              default-expand-all
              :expand-on-click-node="false"
              v-loading="menuLoading"
            >
              <template #default="{ node, data }">
              <span class="custom-tree-node">
                <span style="flex: 1;">
                  <el-icon v-if="data.icon" style="vertical-align: middle; margin-right: 5px;">
                    <component :is="data.icon" />
                  </el-icon>
                  {{ node.label }}
                </span>
                <span v-if="data.permissionCode" style="color: #909399; font-size: 12px; margin-left: 10px;">
                  ({{ data.permissionCode }})
                </span>
              </span>
              </template>
            </el-tree>
          </el-scrollbar>
        </div>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-save" type="primary" @click="viewMenuDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;关闭
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.role-manage-container {
  display: flex; flex-direction: column; height: 100%; box-sizing: border-box; user-select: none;
}

/* 过滤栏 */
.filter-bar {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.filter-form {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  width: 100%;
}
.filter-form :deep(.el-form-item) {
  margin-right: 0;
  margin-bottom: 0;
}
.filter-item {
  flex: 0 0 auto;
}
.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}
.filter-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}
.search-btn, .reset-btn {
  padding: 0 10px;
  min-width: auto;
  height: 32px;
  border-radius: 8px !important;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  font-size: 13px;
  font-weight: 500;
  border: none;
  color: #fff;
  transition: all 0.25s ease;
}
.search-btn {
  background: linear-gradient(135deg, #409eff, #337ecc);
}
.search-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(64, 158, 255, 0.4);
}
.reset-btn {
  background: linear-gradient(135deg, #e6a23c, #c68a2e);
}
.reset-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(230, 162, 60, 0.4);
}
.filter-bar :deep(.el-input__wrapper) {
  padding: 1px 8px !important;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  height: 32px;
}
.filter-bar :deep(.el-input__inner) {
  height: 32px;
  font-size: 13px;
}
.filter-bar :deep(.el-select__wrapper) {
  height: 32px;
  min-height: 32px;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
  border-radius: 6px;
  font-size: 13px;
}
.filter-bar :deep(.el-input__wrapper.is-focus),
.filter-bar :deep(.el-select__wrapper.is-focused) {
  box-shadow: 0 0 0 1px #2563eb inset, 0 0 0 3px rgba(37, 99, 235, 0.1) !important;
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
.table-wrapper :deep(.el-table__body-wrapper) {
  overflow-y: auto;
}

/* 分页 */
.pagination-wrapper {
  display: flex; justify-content: space-between; align-items: center;
  padding: 28px 16px 4px;
}
.pagination-total {
  font-size: 13px; color: #606266;
}

/* 图标 */
.icon-svg {
  width: 16px; height: 16px; fill: none; stroke: currentColor; stroke-width: 2;
  stroke-linecap: round; stroke-linejoin: round;
}
.icon-svg.sm {
  width: 14px; height: 14px;
}

/* 表格按钮 - 参照系统通知页面风格 */
:deep(.table-btn-primary) {
  height: 28px; padding: 0 10px; font-size: 12px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 4px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-primary:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.35);
}
:deep(.table-btn-warning) {
  height: 28px; padding: 0 10px; font-size: 12px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 4px;
  background: linear-gradient(135deg, #e6a23c, #cf9236);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-warning:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(230, 162, 60, 0.35);
}
:deep(.table-btn-success) {
  height: 28px; padding: 0 10px; font-size: 12px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 4px;
  background: linear-gradient(135deg, #67c23a, #529b2e);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-success:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(103, 194, 58, 0.35);
}
:deep(.table-btn-danger) {
  height: 28px; padding: 0 10px; font-size: 12px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 4px;
  background: linear-gradient(135deg, #f56c6c, #d95555);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-danger:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(245, 108, 108, 0.35);
}
:deep(.toolbar-btn-create) {
  padding: 0 16px; height: 34px; border-radius: 10px !important;
  display: inline-flex; align-items: center; gap: 5px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  border: none; color: #fff; font-size: 13px; font-weight: 600;
  transition: all 0.25s ease;
}
:deep(.toolbar-btn-create:hover) {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
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
