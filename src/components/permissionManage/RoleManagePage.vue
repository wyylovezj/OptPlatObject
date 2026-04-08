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
const formatMenuTree = (menus,disableCheckbox = false) => {
  return menus.map(menu => ({
    id: menu.id,
    label: menu.name,
    children: menu.children ? formatMenuTree(menu.children,disableCheckbox) : [],
    path: menu.path,
    permissionCode: menu.permissionCode,
    disabled: disableCheckbox,
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

    // 格式化所有菜单树
    menuTree.value = formatMenuTree(allMenus, false)

    // 提取该角色已拥有的叶子节点菜单 ID
    const ownedMenuIds = extractMenuIds(roleMenus)
    selectedMenus.value = ownedMenuIds

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

// 递归提取所有菜单 ID
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

onMounted(() => {
  loadRoles()
})
</script>

<template>
  <div class="role-manage-container">
    <el-card class="search-card">
      <el-form :model="searchForm" :inline="true" autocomplete="off">
        <el-form-item label="角色">
          <el-input v-model="searchForm.roleCode" style="width: 200px" placeholder="请输入角色编码" clearable spellcheck="false"/>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="searchForm.status" style="width: 200px" placeholder="请选择角色状态" clearable
                     @visible-change="visible => {
                if (visible) {
                  loadRoles()
                }
              }"
          >
            <el-option
              v-for="status in statusList"
              :key="status.value"
              :label="status.label"
              :value="status.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    <el-card class="table-card" body-style="height: 85%;">
      <template #header>
        <div class="card-header">
          <span>角色列表</span>
          <el-button v-if="permissionStore.hasPermission('alarm:createRole')" type="primary" @click="openCreateDialog">新增角色</el-button>
        </div>
      </template>
      <div style="height: 100%; display: flex;flex-direction: column;user-select: none">
        <div style="flex: 1; overflow: hidden;display: flex;flex-direction: column;padding: 10px 0;">
          <el-table
            :data="currentPageData"
            v-loading="loading"
            stripe
            :row-style="{ height: '50px' }"
            style="width: 100%; font-size: 16px;"
            :cell-style="{ textAlign: 'center' }"
            :header-cell-style="{ textAlign: 'center' }"
            row-key="id"
          >
            <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" min-width="5%" :resizable="false"/>
            <el-table-column prop="code" label="角色编码" :resizable="false" min-width="10%"/>
            <el-table-column prop="name" label="角色名称" :resizable="false" min-width="10%"/>
            <el-table-column prop="description" label="描述" show-overflow-tooltip :resizable="false" min-width="20%"/>
            <el-table-column label="菜单权限" :resizable="false" min-width="10%">
              <template #default="{ row }">
                <el-button type="primary" size="small" @click="getRolesMenus(row.code)">
                  查看
                </el-button>
              </template>
            </el-table-column>
            <el-table-column prop="status" label="状态" :resizable="false" min-width="10%">
              <template #default="{ row }">
                <el-tag
                  :type="row.status === 1 ? 'success' : 'info'"
                  size="small"
                  effect="plain"
                >
                  {{ row.status === 1 ? '启用' : '禁用' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="300" fixed="right" :resizable="false" min-width="35%">
              <template #default="{ row }">
                <el-button v-if="permissionStore.hasPermission('system:assignMenus') && row.code !== 'admin' && row.code !== 'normal'" type="primary" size="small" @click="openAssignDialog(row)">
                  分配菜单
                </el-button>
                <el-button v-if="permissionStore.hasPermission('system:editRoles')" type="warning" size="small" @click="openEditDialog(row)">
                  编辑
                </el-button>
                <el-button v-if="row.status === 0 && permissionStore.hasPermission('system:enableRoles')" type="success" size="small" @click="roleEnable(row.code)">
                  启用
                </el-button>
                <el-button v-if="row.status === 1 && permissionStore.hasPermission('system:diabledRoles')" type="danger" size="small" @click="roleDisable(row.code)">
                  禁用
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center;user-select:none;">
          <!--  显示总数  -->
          <div style="display: flex; align-items: center;">
            <span style="line-height: 20px">共 {{ roleList.length }} 条</span>
          </div>
          <div style="display: flex; align-items: center;"><!--  页码导航  -->
            <div style="display: flex; align-items: center;">
              <el-pagination
                background
                v-model:current-page="currentPage"
                :page-size="pageSize"
                :total="roleList.length"
                layout="prev, pager, next"
              />
            </div>
          </div>
        </div>
      </div>

    </el-card>

    <!-- 分配菜单权限对话框 -->
    <el-dialog
      v-model="dialogVisible"
      :title="'分配菜单权限 - ' + currentRole?.code"
      width="700px"
      top="2%"
      center
      destroy-on-close
      style="user-select: none"
      @close="() => {
        selectedMenus = []
      }"
    >
      <el-form
        label-position="right"
        label-width="auto"
        autocomplete="off"
      >
        <el-form-item label="角色：">
          <el-tag
            type="primary"
            size="large"
          >
            {{ currentRole?.code }} - {{ currentRole?.name }}
          </el-tag>
        </el-form-item>
        <el-form-item label="菜单权限：">
          <el-scrollbar height="600px"  style="width: 600px">
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
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveRoleMenus">
          确定
        </el-button>
      </template>
    </el-dialog>
    <!--  新增/编辑角色  -->
    <el-dialog
      v-model="roleVisible"
      :title="currentRole ? '修改角色 - ' + currentRole?.code : '新增角色'"
      width="600px"
      center
      destroy-on-close
      style="user-select: none"
    >
      <el-form ref="formRef" :model="formData" :rules="formRules" label-width="80px" autocomplete="off">
        <el-form-item label="角色编码" prop="code">
          <el-input v-model="formData.code" placeholder="请输入角色编码（如：admin, viewer）" :disabled="currentRole !== null" spellcheck="false"/>
        </el-form-item>
        <el-form-item label="角色名称" prop="name">
          <el-input v-model="formData.name" placeholder="请输入角色名称" spellcheck="false"/>
        </el-form-item>
        <el-form-item label="描述">
          <el-input
            v-model="formData.description"
            type="textarea"
            :rows="3"
            placeholder="请输入角色描述"
            spellcheck="false"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="roleVisible = false">取消</el-button>
        <el-button type="primary" @click="saveRole">
          确定
        </el-button>
      </template>
    </el-dialog>
    <!-- 查看菜单权限对话框 -->
    <el-dialog
      v-model="viewMenuDialogVisible"
      :title="'查看菜单权限 - ' + (viewCurrentRole?.name || '')"
      width="700px"
      top="2%"
      center
      destroy-on-close
      style="user-select: none"
    >
      <div v-if="viewCurrentRole" style="padding: 10px 0;">
        <div style="margin-bottom: 15px; font-weight: bold; color: #606266;">
          角色信息：
        </div>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="角色名称">
            <el-tag type="primary">{{ viewCurrentRole.name }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="角色代码">
            <el-tag type="info">{{ viewCurrentRole.code }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="描述" :span="2">
            {{ viewCurrentRole.description || '无' }}
          </el-descriptions-item>
        </el-descriptions>

        <div style="margin-top: 20px; margin-bottom: 15px; font-weight: bold; color: #606266;">
          菜单权限（已拥有的权限显示为勾选状态，未拥有的权限显示为未勾选状态）：
        </div>
        <el-scrollbar height="500px">
          <el-tree
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
      <template #footer>
        <el-button type="primary" @click="viewMenuDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.role-manage-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  border-radius: 10px;
}
.search-card {
  margin-bottom: 15px;
  width: 100%;
  border-radius: 10px;
}
.table-card {
  flex: 1;
  border-radius: 10px;
  overflow: hidden;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
