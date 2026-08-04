<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 用户管理页面
 * @date: 2026-03-30 10:00:00
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-03-30 10:00:00
 */
import { ref, onMounted,computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getAllRoles, assignUserRoles, getUserList, disableUser, enableUser } from '@/api/userPermisssion.js'
import { usePermissionStore } from '@/stores/permissionStore.js'



// 权限状态管理
const permissionStore = usePermissionStore()

// 用户列表
const userList = ref([])
// 角色列表
const roleList = ref([])
// 加载状态
const loading = ref(false)
// 搜索条件
const searchForm = ref({
  username: '',
  roleCode: '',
  status: '',
})
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
// 分页配置
const currentPage = ref(1)
const pageSize = ref(10)
const message = ref(null)
// 启用用户
const userEnable = async (username) => {
  const response = await enableUser(username)
  if (response.code === 200) {
    loadUsers()
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.success(`用户${ username }已启用`)
  }
}
// 禁用用户
const userDisable = async (username) => {
  const response = await disableUser(username)
  if (response.code === 200) {
    loadUsers()
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.warning(`用户${ username }已禁用`)
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
  return userList.value.slice(start, end)
})
// 对话框可见性
const dialogVisible = ref(false)
// 当前编辑的用户
const currentUser = ref(null)
// 用户已选角色
const selectedRoles = ref([])

// 计算属性：过滤出启用的角色列表（用于分配角色对话框）
const enabledRoleList = computed(() => {
  return roleList.value.filter(role => role.status === 1)
})

// 穿梭框数据：角色列表
const roleTransferData = computed(() => {
  return enabledRoleList.value.map(role => ({
    key: role.code,
    label: role.code + ' - ' + role.name
  }))
})

// 加载用户列表
const loadUsers = async () => {
  loading.value = true
  try {
    // TODO: 调用后端接口获取用户列表
    const response = await getUserList(searchForm.value)
    userList.value = response.data
  } catch (error) {
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.error('加载用户列表失败：' + error.message)
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
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.error('加载角色列表失败：' + error.message)
  }
}

// 打开分配角色对话框
const openAssignDialog = async (user) => {
  currentUser.value = user
  selectedRoles.value = user.roles ? user.roles.map(r => r.code) : []
  dialogVisible.value = true

  if (roleList.value.length === 0) {
    await loadRoles()
  }
}

// 保存用户角色
const saveUserRoles = async () => {
  try {
    await assignUserRoles(currentUser.value.username, selectedRoles.value)
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.success('分配角色成功')
    dialogVisible.value = false
    loadUsers()
  } catch (error) {
    if (message.value) {
      message.value.close()
    }
    message.value = ElMessage.error('分配角色失败：' + error.message)
  }
}

// 搜索用户
const handleSearch = () => {
  loadUsers()
}

// 重置搜索
const handleReset = () => {
  searchForm.value = {
    username: '',
    roleName: '',
    status: '',
  }
  loadUsers()
}

onMounted(() => {
  loadUsers()
})
</script>

<template>
  <div class="user-manage-container">
    <div class="filter-bar">
      <el-form :model="searchForm" inline class="filter-form">
        <el-form-item class="filter-item">
          <el-input v-model="searchForm.username" placeholder="用户名" clearable style="width: 130px" @keyup.enter="handleSearch" spellcheck="false"/>
        </el-form-item>
        <el-form-item class="filter-item">
          <el-select v-model="searchForm.roleCode" placeholder="角色" clearable style="width: 130px"
                     @visible-change="visible => { if (visible) { loadRoles() } }">
            <el-option v-for="role in enabledRoleList" :key="role.code" :label="role.name" :value="role.code"/>
          </el-select>
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
            <span class="toolbar-title">用户列表</span>
            <span class="toolbar-sep"></span>
          </div>
          <div class="toolbar-actions">
          </div>
        </div>
        <el-table
          :data="currentPageData"
          v-loading="loading"
          stripe
          style="width: 100%"
          empty-text="暂无用户数据"
          :header-cell-style="{ textAlign: 'center', background: '#f1f5f9', color: '#64748b', fontWeight: '600', fontSize: '12px' }"
        >
          <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" width="60" align="center"/>
          <el-table-column prop="username" label="用户名" align="center"/>
          <el-table-column prop="nickname" label="昵称" align="center"/>
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small" effect="plain">{{ row.status === 1 ? '启用' : '禁用' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="角色" align="center">
            <template #default="{ row }">
              <div style="display: flex; flex-wrap: wrap; gap: 4px; justify-content: center;">
                <el-tag v-for="role in row.roles" :key="role.code" size="small" effect="plain">{{ role.name }}</el-tag>
                <span v-if="!row.roles || row.roles.length === 0" style="color: #909399; font-size: 13px;">无</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="用户组" min-width="150" align="center">
            <template #default="{ row }">
              <div style="display: flex; flex-wrap: wrap; gap: 4px; justify-content: center;">
                <el-tag v-for="group in (row.groups || [])" :key="group.code" size="small" type="success" effect="plain">{{ group.name }}</el-tag>
                <span v-if="!row.groups || row.groups.length === 0" style="color: #909399; font-size: 13px;">无</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="230" align="center" fixed="right">
            <template #default="{ row }">
              <el-button v-if="permissionStore.hasPermission('system:assignRoles')" class="table-btn-primary" size="small" @click="openAssignDialog(row)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>&nbsp;分配角色
              </el-button>
              <el-button v-if="row.status === 0 && permissionStore.hasPermission('system:enableUser')" class="table-btn-success" size="small" @click="userEnable(row.username)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;启用
              </el-button>
              <el-button v-if="row.status === 1 && permissionStore.hasPermission('system:disabledUser')" class="table-btn-danger" size="small" @click="userDisable(row.username)">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;禁用
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="pagination-wrapper" v-if="userList.length > 0">
        <span class="pagination-total">共 {{ userList.length }} 条</span>
        <el-pagination v-model:current-page="currentPage" :page-size="pageSize" :total="userList.length" layout="prev, pager, next" @current-change="() => {}" background />
      </div>
    </el-card>

    <!-- 分配角色对话框 -->
    <el-dialog v-model="dialogVisible" width="760px" :show-close="false" class="assign-dialog" top="5vh" destroy-on-close>
      <template #header>
        <div class="dialog-header">
          <div class="dialog-header-icon">
            <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
          </div>
          <div class="dialog-header-text">
            <span class="dialog-title">分配角色</span>
            <span class="dialog-subtitle">为用户配置角色权限</span>
          </div>
        </div>
      </template>
      <div class="dialog-body">
        <div style="margin-bottom: 16px;">
          <el-tag type="primary" size="large">用户：{{ currentUser?.nickname || currentUser?.username }}（{{ currentUser?.username }}）</el-tag>
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
          <el-button class="dialog-btn-cancel" @click="dialogVisible = false">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>&nbsp;取消
          </el-button>
          <el-button class="dialog-btn-save" type="primary" @click="saveUserRoles">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>&nbsp;确定
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.user-manage-container {
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
