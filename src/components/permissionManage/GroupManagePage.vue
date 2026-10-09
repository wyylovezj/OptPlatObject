<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 用户组管理页面
 * @date: 2026-07-24
 */
import { ref, onMounted, computed } from 'vue'
import { ElMessage } from 'element-plus'
import {
  getAllGroups, createGroup, updateGroup,
  enableGroup, disableGroup,
  getAllRoles, getGroupUsers, assignGroupUsers,
  assignGroupRoles, getGroupRoles, getUserList
} from '@/api/userPermisssion.js'
// 用户组列表
const groupList = ref([])
// 角色列表
const roleList = ref([])
// 所有用户列表（用于分配用户对话框）
const allUsers = ref([])
// 加载状态
const loading = ref(false)
// 搜索条件
const searchForm = ref({
  groupName: '',
  status: '',
})
const statusList = ref([
  { value: '1', label: '启用' },
  { value: '0', label: '禁用' }
])
// 分页配置
const currentPage = ref(1)
const pageSize = ref(12)
const message = ref(null)

// 计算当前页显示的数据
const currentPageData = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  const end = start + pageSize.value
  return groupList.value.slice(start, end)
})

// 新增/编辑对话框
const groupDialogVisible = ref(false)
const isEdit = ref(false)
const currentGroup = ref(null)
const formData = ref({
  groupCode: '',
  groupName: '',
  description: ''
})
const formRef = ref(null)
const formRules = ref({
  groupCode: [
    { required: true, message: '请输入用户组编码', trigger: 'blur' },
    { pattern: /^[a-zA-Z_]+$/, message: '用户组编码只能包含字母和下划线', trigger: 'blur' }
  ],
  groupName: [
    { required: true, message: '请输入用户组名称', trigger: 'blur' }
  ]
})

// 分配用户对话框
const userDialogVisible = ref(false)
const currentAssignGroup = ref(null)
const selectedUsers = ref([])

// 分配角色对话框
const roleDialogVisible = ref(false)
const currentRoleGroup = ref(null)
const selectedRoles = ref([])

// 查看用户对话框
const viewUserDialogVisible = ref(false)
const viewUserGroup = ref(null)
const viewGroupUsers = ref([])
const viewUsersLoading = ref(false)

const openViewUsersDialog = async (group) => {
  viewUserGroup.value = group
  viewUserDialogVisible.value = true
  viewUsersLoading.value = true
  viewGroupUsers.value = []
  try {
    const users = await getGroupUsers(group.groupCode)
    viewGroupUsers.value = users || []
  } catch (error) {
    ElMessage.error('加载用户组用户失败：' + error.message)
  } finally {
    viewUsersLoading.value = false
  }
}

// 加载用户组列表
const loadGroups = async () => {
  loading.value = true
  try {
    const groups = await getAllGroups(searchForm.value)
    groupList.value = groups
  } catch (error) {
    if (message.value) message.value.close()
    message.value = ElMessage.error('加载用户组列表失败：' + error.message)
  } finally {
    loading.value = false
  }
}

// 加载角色列表
const loadRoles = async () => {
  try {
    const roles = await getAllRoles('')
    roleList.value = roles
  } catch (error) {
    ElMessage.error('加载角色列表失败：' + error.message)
  }
}

// 加载所有用户
const loadAllUsers = async () => {
  try {
    const response = await getUserList({ username: '', roleCode: '', status: '' })
    allUsers.value = response.data || []
  } catch (error) {
    ElMessage.error('加载用户列表失败：' + error.message)
  }
}

// 启用用户组
const groupEnable = async (groupCode) => {
  try {
    const response = await enableGroup(groupCode)
    if (response.code === 200) {
      loadGroups()
      if (message.value) message.value.close()
      message.value = ElMessage.success(`用户组 ${groupCode} 已启用`)
    }
  } catch (error) {
    ElMessage.error('启用用户组失败：' + error.message)
  }
}

// 禁用用户组
const groupDisable = async (groupCode) => {
  try {
    const response = await disableGroup(groupCode)
    if (response.code === 200) {
      loadGroups()
      if (message.value) message.value.close()
      message.value = ElMessage.warning(`用户组 ${groupCode} 已禁用`)
    }
  } catch (error) {
    ElMessage.error('禁用用户组失败：' + error.message)
  }
}

// 搜索
const handleSearch = () => { loadGroups() }

// 重置搜索
const handleReset = () => {
  searchForm.value = { groupName: '', status: '' }
  loadGroups()
}

// 分页切换：遮罩过渡，避免换页瞬间旧数据闪现与行高跳动
let pageChangeTimer = null
const handlePageChange = (page) => {
  currentPage.value = page
  loading.value = true
  clearTimeout(pageChangeTimer)
  pageChangeTimer = setTimeout(() => {
    loading.value = false
  }, 200)
}

// 打开新增对话框
const openCreateDialog = () => {
  isEdit.value = false
  currentGroup.value = null
  formData.value = { groupCode: '', groupName: '', description: '' }
  groupDialogVisible.value = true
}

// 打开编辑对话框
const openEditDialog = (group) => {
  isEdit.value = true
  currentGroup.value = group
  formData.value = {
    groupCode: group.groupCode,
    groupName: group.groupName,
    description: group.description || ''
  }
  groupDialogVisible.value = true
}

// 保存用户组
const saveGroup = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    try {
      if (isEdit.value) {
        await updateGroup(formData.value.groupCode, {
          groupName: formData.value.groupName,
          description: formData.value.description
        })
        ElMessage.success('更新用户组成功')
      } else {
        await createGroup(formData.value)
        ElMessage.success('创建用户组成功')
      }
      groupDialogVisible.value = false
      loadGroups()
    } catch (error) {
      ElMessage.error((isEdit.value ? '更新' : '创建') + '用户组失败：' + error.message)
    }
  })
}

// 打开分配用户对话框
const openAssignUserDialog = async (group) => {
  currentAssignGroup.value = group
  selectedUsers.value = []
  userDialogVisible.value = true

  await Promise.all([
    loadAllUsers(),
    loadGroupCurrentUsers(group.groupCode)
  ])
}

// 加载用户组当前用户
const loadGroupCurrentUsers = async (groupCode) => {
  try {
    const users = await getGroupUsers(groupCode)
    selectedUsers.value = users.map(u => u.username)
  } catch (error) {
    ElMessage.error('加载用户组用户失败：' + error.message)
  }
}

// 保存用户组用户
const saveGroupUsers = async () => {
  try {
    await assignGroupUsers(currentAssignGroup.value.groupCode, selectedUsers.value)
    ElMessage.success('分配用户成功')
    userDialogVisible.value = false
    loadGroups()
  } catch (error) {
    ElMessage.error('分配用户失败：' + error.message)
  }
}

// 打开分配角色对话框
const openAssignRoleDialog = async (group) => {
  currentRoleGroup.value = group
  selectedRoles.value = []
  roleDialogVisible.value = true

  if (roleList.value.length === 0) {
    await loadRoles()
  }
  await loadGroupCurrentRoles(group.groupCode)
}

// 加载用户组当前角色
const loadGroupCurrentRoles = async (groupCode) => {
  try {
    const roles = await getGroupRoles(groupCode)
    selectedRoles.value = roles.map(r => r.code)
  } catch (error) {
    ElMessage.error('加载用户组角色失败：' + error.message)
  }
}

// 保存用户组角色
const saveGroupRoles = async () => {
  try {
    await assignGroupRoles(currentRoleGroup.value.groupCode, selectedRoles.value)
    ElMessage.success('分配角色成功')
    roleDialogVisible.value = false
    loadGroups()
  } catch (error) {
    ElMessage.error('分配角色失败：' + error.message)
  }
}

// 计算属性：过滤出启用的角色列表
const enabledRoleList = computed(() => {
  return roleList.value.filter(role => role.status === 1)
})

// 穿梭框数据：用户列表
const userTransferData = computed(() => {
  return allUsers.value.map(user => ({
    key: user.username,
    label: (user.nickname || user.username) + ' (' + user.username + ')'
  }))
})

// 穿梭框数据：角色列表
const roleTransferData = computed(() => {
  return enabledRoleList.value.map(role => ({
    key: role.code,
    label: role.code + ' - ' + role.name
  }))
})

onMounted(() => {
  loadGroups()
})
</script>

<template>
  <div class="group-manage-container">
    <div class="filter-bar">
      <el-form :model="searchForm" inline class="filter-form" autocomplete="off">
        <el-form-item class="filter-item">
          <el-input v-model="searchForm.groupName" placeholder="用户组名称" clearable style="width: 130px" spellcheck="false" @keyup.enter="handleSearch"/>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="searchForm.status" placeholder="状态" clearable style="width: 110px">
            <el-option v-for="s in statusList" :key="s.value" :label="s.label" :value="s.value"/>
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
            <span class="toolbar-title">用户组列表</span>
            <span class="toolbar-sep"></span>
          </div>
          <div class="toolbar-actions">
            <el-button class="toolbar-btn-create" @click="openCreateDialog">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>&nbsp;新增用户组
            </el-button>
          </div>
        </div>
        <el-table
          :key="currentPage"
          :data="currentPageData"
          v-loading="loading"
          stripe
          style="width: 100%"
          empty-text="暂无用户组数据"
          :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }"
        >
          <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" width="60" align="center"/>
          <el-table-column prop="groupCode" label="用户组编码" align="center"/>
          <el-table-column prop="groupName" label="用户组名称" align="center"/>
          <el-table-column prop="description" label="描述" align="center" show-overflow-tooltip/>
          <el-table-column label="用户数" width="80" align="center">
            <template #default="{ row }">
              <el-button class="table-btn-info" size="small" @click="openViewUsersDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>&nbsp;{{ row.userCount }}
              </el-button>
            </template>
          </el-table-column>
          <el-table-column label="角色" min-width="160" align="center">
            <template #default="{ row }">
              <div style="display: flex; flex-wrap: wrap; gap: 4px; justify-content: center;">
                <el-tag v-for="role in (row.roles || [])" :key="role.code" size="small" type="primary" effect="plain">{{ role.name }}</el-tag>
                <span v-if="!row.roles || row.roles.length === 0" style="color: #909399; font-size: 13px;">无</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small" effect="plain">{{ row.status === 1 ? '启用' : '禁用' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="380" align="center" fixed="right">
            <template #default="{ row }">
              <el-button class="table-btn-primary" size="small" @click="openAssignUserDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>&nbsp;分配用户
              </el-button>
              <el-button class="table-btn-success" size="small" @click="openAssignRoleDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>&nbsp;分配角色
              </el-button>
              <el-button class="table-btn-warning" size="small" @click="openEditDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>&nbsp;编辑
              </el-button>
              <el-button v-if="row.status === 0" class="table-btn-success" size="small" @click="groupEnable(row.groupCode)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;启用
              </el-button>
              <el-button v-if="row.status === 1" class="table-btn-danger" size="small" @click="groupDisable(row.groupCode)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;禁用
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="pagination-wrapper" v-if="groupList.length > 0">
        <span class="pagination-total">共 {{ groupList.length }} 条</span>
        <el-pagination v-model:current-page="currentPage" :page-size="pageSize" :total="groupList.length" layout="prev, pager, next" @current-change="handlePageChange" background />
      </div>
    </el-card>

    <!-- 新增/编辑用户组对话框 -->
    <el-dialog v-model="groupDialogVisible" width="600px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">{{ isEdit ? '编辑用户组' : '新增用户组' }}</span>
            <span class="dialog-subtitle">{{ isEdit ? '修改用户组信息' : '创建新的用户组' }}</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <el-form ref="formRef" :model="formData" :rules="formRules" label-width="100px" autocomplete="off">
          <el-form-item label="用户组编码" prop="groupCode">
            <el-input v-model="formData.groupCode" placeholder="请输入用户组编码（如：ops_team）" :disabled="isEdit" spellcheck="false"/>
          </el-form-item>
          <el-form-item label="用户组名称" prop="groupName">
            <el-input v-model="formData.groupName" placeholder="请输入用户组名称" spellcheck="false"/>
          </el-form-item>
          <el-form-item label="描述">
            <el-input v-model="formData.description" type="textarea" :rows="3" placeholder="请输入用户组描述" spellcheck="false"/>
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="groupDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveGroup">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 分配用户对话框 -->
    <el-dialog v-model="userDialogVisible" width="760px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">分配用户</span>
            <span class="dialog-subtitle">为用户组添加成员</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div style="margin-bottom: 16px;">
          <el-tag type="primary" size="large">用户组：{{ currentAssignGroup?.groupName }}（{{ currentAssignGroup?.groupCode }}）</el-tag>
        </div>
        <el-transfer
          v-model="selectedUsers"
          :data="userTransferData"
          filterable
          :filter-placeholder="'搜索用户...'"
          :titles="['可选用户', '已选用户']"
          :button-texts="['移除', '选择']"
        />
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="userDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveGroupUsers">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 分配角色对话框 -->
    <el-dialog v-model="roleDialogVisible" width="760px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">分配角色</span>
            <span class="dialog-subtitle">为用户组分配角色权限</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div style="margin-bottom: 16px;">
          <el-tag type="primary" size="large">用户组：{{ currentRoleGroup?.groupName }}（{{ currentRoleGroup?.groupCode }}）</el-tag>
        </div>
        <el-transfer
          v-model="selectedRoles"
          :data="roleTransferData"
          filterable
          :filter-placeholder="'搜索角色...'"
          :titles="['可选角色', '已选角色']"
          :button-texts="['移除', '选择']"
        />
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-cancel" @click="roleDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveGroupRoles">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 查看用户对话框 -->
    <el-dialog v-model="viewUserDialogVisible" width="600px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">查看用户</span>
            <span class="dialog-subtitle">{{ viewUserGroup?.groupName }}（{{ viewUserGroup?.groupCode }}）的成员列表</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div v-if="viewUsersLoading" style="text-align: center; padding: 40px 0; color: #909399;">加载中...</div>
        <div v-else-if="viewGroupUsers.length === 0" style="text-align: center; padding: 40px 0; color: #909399;">暂未分配用户</div>
        <el-scrollbar v-else max-height="400px">
          <el-table :data="viewGroupUsers" stripe style="width: 100%" :max-height="380" :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }">
            <el-table-column type="index" label="#" width="50" align="center"/>
            <el-table-column prop="nickname" label="姓名" align="center">
              <template #default="{ row }">{{ row.nickname || '-' }}</template>
            </el-table-column>
            <el-table-column prop="username" label="账号" align="center"/>
          </el-table>
        </el-scrollbar>
      </div>
      <template #footer>
        <div class="dialog-footer">
          <el-button class="dialog-btn-save" type="primary" @click="viewUserDialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;关闭
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.group-manage-container {
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
:deep(.table-btn-info) {
  height: 28px; padding: 0 10px; font-size: 12px; border-radius: 8px !important;
  display: inline-flex; align-items: center; gap: 4px;
  background: linear-gradient(135deg, #409eff, #337ecc);
  border: none; color: #fff; font-weight: 500;
  transition: all 0.25s ease;
}
:deep(.table-btn-info:hover) {
  filter: brightness(1.1);
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.35);
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

/* 穿梭框自适应宽度 */
:deep(.el-transfer) {
  display: flex;
  align-items: center;
  gap: 0;
}
:deep(.el-transfer-panel) {
  flex: 1;
  height: 360px;
}
:deep(.el-transfer-panel__body) {
  height: 280px;
}
:deep(.el-transfer__buttons) {
  padding: 0 12px;
  flex-shrink: 0;
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
