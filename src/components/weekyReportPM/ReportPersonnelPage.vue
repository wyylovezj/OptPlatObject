<template>
  <div class="report-personnel-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">周报人员管理</h2>
      <el-button type="primary" @click="openAddDialog">
        <el-icon><Plus /></el-icon>
        &nbsp;新增人员
      </el-button>
    </div>

    <!-- 人员表格 -->
    <el-card shadow="never" class="personnel-card">
      <template #header>
        <div class="card-header">
          <span class="section-title">
            <el-icon><User /></el-icon>
            人员列表
          </span>
          <span class="personnel-count">共 {{ personnelList.length }} 人</span>
        </div>
      </template>

      <el-table :data="personnelList" row-key="id" border style="width: 100%"
        :header-cell-style="{ background: '#f5f7fa', color: '#303133', fontWeight: '600' }">
        <el-table-column label="序号" width="70" align="center">
          <template #default="{ $index }">{{ $index + 1 }}</template>
        </el-table-column>

        <el-table-column prop="name" label="姓名" width="120" align="center" />

        <el-table-column prop="userCode" label="域账号" min-width="160" align="center" />

        <el-table-column label="人员类型" width="130" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="row.personnelType === 1 ? 'primary' : 'success'" effect="plain">
              {{ row.personnelType === 1 ? '普通成员' : '领导' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.status ? 'success' : 'info'" size="small" effect="light">
              {{ row.status ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="160" align="center">
          <template #default="{ row }">
            <el-button :type="row.status ? 'warning' : 'success'" link size="small"
              :loading="togglingId === row.id"
              @click="handleToggleStatus(row)">
              {{ row.status ? '停用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 新增人员弹窗 -->
    <el-dialog v-model="dialogVisible" title="新增周报人员" width="480px" :close-on-click-modal="false">
      <el-form :model="addForm" label-width="100px" class="add-form">
        <el-form-item label="选择人员" required>
          <el-select v-model="addForm.selected" placeholder="请选择人员" style="width: 100%;"
            filterable :loading="loadingCandidates"
            @change="onCandidateChange">
            <el-option
              v-for="c in candidates"
              :key="c.userCode"
              :label="`${c.name}（${c.userCode}）`"
              :value="c.userCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="域账号">
          <el-input v-model="addForm.userCode" disabled />
        </el-form-item>
        <el-form-item label="姓名">
          <el-input v-model="addForm.name" disabled />
        </el-form-item>
        <el-form-item label="人员类型">
          <el-radio-group v-model="addForm.personnelType">
            <el-radio :value="1">普通成员</el-radio>
            <el-radio :value="2">领导</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleAdd">确认添加</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, User } from '@element-plus/icons-vue'
import {
  getReportPersonnel, getPersonnelCandidates,
  addReportPersonnel, togglePersonnelStatus
} from '@/api/weeklyReportApi'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

const personnelList = ref([])
const dialogVisible = ref(false)
const submitting = ref(false)
const togglingId = ref('')
const loadingCandidates = ref(false)
const candidates = ref([])

const addForm = ref({
  selected: '',
  userCode: '',
  name: '',
  personnelType: 1,
})

// 加载人员列表
const loadPersonnel = async () => {
  try {
    const res = await getReportPersonnel()
    if (res.code === 200) {
      personnelList.value = res.data || []
    }
  } catch (e) {
    msg('error', e.message || '加载人员列表失败')
  }
}

// 加载候选人
const loadCandidates = async () => {
  loadingCandidates.value = true
  try {
    const res = await getPersonnelCandidates()
    if (res.code === 200) {
      candidates.value = res.data || []
    }
  } catch (e) {
    msg('error', e.message || '加载候选人失败')
  } finally {
    loadingCandidates.value = false
  }
}

// 打开新增弹窗
const openAddDialog = async () => {
  addForm.value = { selected: '', userCode: '', name: '', personnelType: 1 }
  await loadCandidates()
  dialogVisible.value = true
}

// 候选人选中事件
const onCandidateChange = (val) => {
  const c = candidates.value.find(item => item.userCode === val)
  if (c) {
    addForm.value.userCode = c.userCode
    addForm.value.name = c.name
  }
}

// 新增人员
const handleAdd = async () => {
  if (!addForm.value.userCode || !addForm.value.name) {
    msg('warning', '请先选择人员')
    return
  }
  submitting.value = true
  try {
    const res = await addReportPersonnel({
      userCode: addForm.value.userCode,
      name: addForm.value.name,
      personnelType: addForm.value.personnelType,
    })
    if (res.status === 'success') {
      msg('success', '人员已添加')
      dialogVisible.value = false
      await loadPersonnel()
    } else {
      msg('error', res.message || '添加失败')
    }
  } catch (e) {
    msg('error', e.message || '添加失败')
  } finally {
    submitting.value = false
  }
}

// 启用/停用
const handleToggleStatus = async (row) => {
  togglingId.value = row.id
  const newActive = !row.status
  try {
    const res = await togglePersonnelStatus(row.id, newActive)
    if (res.status === 'success') {
      row.status = newActive ? 1 : 0
      msg('success', `人员已${newActive ? '启用' : '停用'}`)
    } else {
      msg('error', res.message || '操作失败')
    }
  } catch (e) {
    msg('error', e.message || '操作失败')
  } finally {
    togglingId.value = ''
  }
}

onMounted(() => {
  loadPersonnel()
})
</script>

<style scoped>
.report-personnel-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 12px; flex-shrink: 0;
}
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

.personnel-card { flex: 1; min-height: 0; overflow: auto; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.section-title { font-size: 15px; font-weight: 600; color: #303133; display: flex; align-items: center; gap: 6px; }
.personnel-count { font-size: 12px; color: #909399; }

.add-form .el-form-item { margin-bottom: 18px; }
</style>
