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
    <el-card class="search-card">
      <el-form :model="searchForm" :inline="true">
        <el-form-item label="用户名">
          <el-input v-model="searchForm.username" style="width: 200px" placeholder="请输入用户名" clearable />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="searchForm.roleCode" style="width: 200px" placeholder="请选择角色" clearable
             @visible-change="visible => {
                if (visible) {
                  loadRoles()
                }
              }"
          >
            <el-option
              v-for="role in roleList"
              :key="role.code"
              :label="role.name"
              :value="role.code"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="searchForm.status" style="width: 200px" placeholder="请选择用户状态" clearable
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
          <span>用户列表</span>
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
            <el-table-column label="序号" type="index" :index="(index) => (currentPage - 1) * pageSize + index + 1" width="100"/>
            <el-table-column prop="username" label="用户名" />
            <el-table-column prop="nickname" label="昵称" />
            <el-table-column prop="status" label="状态">
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
            <el-table-column label="角色">
              <template #default="{ row }">
                <el-tag
                  v-for="role in row.roles"
                  :key="role.code"
                  size="small"
                  style="margin-right: 5px; margin-bottom: 5px;"
                >
                  {{ role.name }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200" fixed="right">
              <template #default="{ row }">
                <el-button v-if="permissionStore.hasPermission('system:assignRoles')" type="primary" size="small" @click="openAssignDialog(row)">
                  分配角色
                </el-button>
                <el-button v-if="row.status === 0 && permissionStore.hasPermission('system:enableUser')" type="success" size="small" @click="userEnable(row.username)">
                  启用
                </el-button>
                <el-button v-if="row.status === 1 && permissionStore.hasPermission('system:disabledUser')" type="danger" size="small" @click="userDisable(row.username)">
                  禁用
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center;user-select:none;">
          <!--  显示总数  -->
          <div style="display: flex; align-items: center;">
            <span style="line-height: 20px">共 {{ userList.length }} 条</span>
          </div>
          <div style="display: flex; align-items: center;"><!--  页码导航  -->
            <div style="display: flex; align-items: center;">
              <el-pagination
                background
                v-model:current-page="currentPage"
                :page-size="pageSize"
                :total="userList.length"
                layout="prev, pager, next"
              />
            </div>
          </div>
        </div>
      </div>
    </el-card>

    <!-- 分配角色对话框 -->
    <el-dialog
      v-model="dialogVisible"
      title="分配角色"
      width="500px"
      center
      destroy-on-close
      style="user-select: none"
    >
      <el-form
        label-position="right"
        label-width="auto"
      >
        <el-form-item label="用户名：">
            <el-tag
              type="primary"
              size="large"
            >
              {{ currentUser?.username }}
            </el-tag>
        </el-form-item>
        <el-form-item label="选择角色：">
          <el-checkbox-group v-model="selectedRoles">
            <el-checkbox
              v-for="role in roleList"
              :key="role.code"
              :label="role.code"
            >

              {{ role.code }} - {{ role.name}}
            </el-checkbox>
          </el-checkbox-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveUserRoles">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.user-manage-container {
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
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
