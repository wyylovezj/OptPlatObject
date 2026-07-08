<template>
  <div class="report-modules-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">运维模块管理</h2>
      <el-button type="primary" @click="openAddDialog">
        <el-icon><Plus /></el-icon>
        &nbsp;新增模块
      </el-button>
    </div>

    <!-- 模块表格 -->
    <el-card shadow="never" class="modules-card">
      <template #header>
        <div class="card-header">
          <span class="section-title">
            <el-icon><Grid /></el-icon>
            模块列表
          </span>
          <span class="module-count">共 {{ modules.length }} 个模块</span>
        </div>
      </template>

      <el-table :data="modules" row-key="id" border style="width: 100%" :header-cell-style="{ background: '#f5f7fa', color: '#303133', fontWeight: '600' }">
        <el-table-column label="排序" width="80" align="center">
          <template #default="{ $index }">
            <div class="sort-cell">
              <el-icon class="drag-handle"><Rank /></el-icon>
              <span class="sort-index">{{ $index + 1 }}</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="模块名称" min-width="160">
          <template #default="{ row }">
            <div class="module-name-cell">
              <span class="color-dot" :style="{ background: row.color }"></span>
              <strong>{{ row.name }}</strong>
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="desc" label="描述" min-width="200" show-overflow-tooltip />

        <el-table-column label="类别" width="120" align="center">
          <template #default="{ row }">
            <el-tag size="small" type="info" effect="plain">{{ row.category }}</el-tag>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.active ? 'success' : 'info'" size="small" effect="light">
              {{ row.active ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="本周填报人数" width="130" align="center">
          <template #default="{ row }">
            <span class="fill-count">{{ row.fillCount || 0 }}/{{ totalEngineers }}</span>
          </template>
        </el-table-column>

        <el-table-column prop="created" label="创建时间" width="120" align="center" />

        <el-table-column label="操作" width="200" align="center">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="openEditDialog(row)">编辑</el-button>
            <el-button :type="row.active ? 'warning' : 'success'" link size="small" @click="handleToggleStatus(row)">
              {{ row.active ? '停用' : '启用' }}
            </el-button>
            <el-button type="danger" link size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 新增/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="editingModule ? '编辑模块' : '新增模块'" width="520px" :close-on-click-modal="false">
      <el-form :model="moduleForm" label-width="90px" class="module-form">
        <el-form-item label="模块名称" required>
          <el-input v-model="moduleForm.name" placeholder="如：网络安全、数据库运维" maxlength="50" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="moduleForm.desc" type="textarea" :rows="3" placeholder="简要描述该模块的运维范围" maxlength="200" />
        </el-form-item>
        <el-form-item label="类别">
          <el-select v-model="moduleForm.category" placeholder="选择类别" style="width: 100%;">
            <el-option v-for="cat in moduleCategories" :key="cat" :label="cat" :value="cat" />
          </el-select>
        </el-form-item>
        <el-form-item label="标识颜色">
          <div class="color-picker">
            <div
              v-for="color in moduleColorOptions"
              :key="color"
              class="color-option"
              :class="{ selected: moduleForm.color === color }"
              :style="{ background: color }"
              @click="moduleForm.color = color"
            />
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSaveModule">保存</el-button>
      </template>
    </el-dialog>

    <!-- 删除确认弹窗 -->
    <el-dialog v-model="deleteDialogVisible" title="确认删除" width="420px">
      <div class="delete-confirm">
        确认删除模块 <strong>"{{ deletingModule?.name }}"</strong>？<br>
        历史周报数据将保留但不再显示模块名称。
      </div>
      <template #footer>
        <el-button @click="deleteDialogVisible = false">取消</el-button>
        <el-button type="danger" @click="confirmDelete">确认删除</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, onBeforeUnmount } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, Grid, Rank } from '@element-plus/icons-vue'
import Sortable from 'sortablejs'
import {
  getReportModules, addReportModule, updateReportModule,
  deleteReportModule, updateModuleSortOrder, toggleModuleStatus
} from '@/api/weeklyReportApi'
import { reportModules, moduleColorOptions, moduleCategories } from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

// 模块列表（排序后的本地副本）
const modules = ref([])
const totalEngineers = ref(0)
let sortableInstance = null

// 弹窗状态
const dialogVisible = ref(false)
const deleteDialogVisible = ref(false)
const editingModule = ref(null)
const deletingModule = ref(null)

// 表单
const moduleForm = ref({
  name: '',
  desc: '',
  category: '基础设施',
  color: '#2563eb'
})

// 初始化拖拽排序
const initSortable = () => {
  nextTick(() => {
    if (sortableInstance) {
      sortableInstance.destroy()
      sortableInstance = null
    }

    const el = document.querySelector('.report-modules-container')
    const tbody = el?.querySelector('.el-table__body-wrapper tbody')
    if (!tbody) return

    sortableInstance = Sortable.create(tbody, {
      handle: '.drag-handle',
      animation: 200,
      easing: 'cubic-bezier(0.25, 0.1, 0.25, 1)',
      delay: 100,
      delayOnTouchOnly: true,
      onEnd: async (evt) => {
        const { oldIndex, newIndex } = evt
        if (oldIndex === undefined || newIndex === undefined || oldIndex === newIndex) return

        // 更新数据顺序
        const list = modules.value
        const [moved] = list.splice(oldIndex, 1)
        list.splice(newIndex, 0, moved)
        modules.value.forEach((m, i) => m.order = i + 1)

        try {
          await updateModuleSortOrder(
            modules.value.map((m, i) => ({ id: m.id, order: i + 1 }))
          )
          msg('success', '排序已更新')
        } catch (e) {
          msg('error', e.message || '更新排序失败')
          loadModules()
        }
      }
    })
  })
}

// 加载模块列表
const loadModules = async () => {
  try {
    const data = await getReportModules()
    if (data && Array.isArray(data)) {
      reportModules.value = data
      modules.value = [...data].sort((a, b) => (a.order || 0) - (b.order || 0))
    }
  } catch (e) {
    // 使用本地共享数据
    if (reportModules.value.length > 0) {
      modules.value = [...reportModules.value].sort((a, b) => (a.order || 0) - (b.order || 0))
    }
    console.warn('加载模块列表失败', e)
  }
  initSortable()
}

// 打开新增弹窗
const openAddDialog = () => {
  editingModule.value = null
  moduleForm.value = { name: '', desc: '', category: '基础设施', color: '#2563eb' }
  dialogVisible.value = true
}

// 打开编辑弹窗
const openEditDialog = (row) => {
  editingModule.value = row
  moduleForm.value = {
    name: row.name,
    desc: row.desc || '',
    category: row.category || '基础设施',
    color: row.color || '#2563eb'
  }
  dialogVisible.value = true
}

// 保存模块
const handleSaveModule = async () => {
  if (!moduleForm.value.name || !moduleForm.value.name.trim()) {
    msg('warning', '请输入模块名称')
    return
  }

  try {
    if (editingModule.value) {
      // 编辑
      const res = await updateReportModule(editingModule.value.id, moduleForm.value)
      if (res.status === 'success') {
        msg('success', '模块已更新')
      } else {
        msg('error', res.message || '更新失败')
      }
    } else {
      // 新增
      const res = await addReportModule(moduleForm.value)
      if (res.status === 'success') {
        msg('success', '模块已创建')
      } else {
        msg('error', res.message || '创建失败')
      }
    }
    dialogVisible.value = false
    loadModules()
  } catch (e) {
    msg('error', e.message || '操作失败')
  }
}

// 切换状态
const handleToggleStatus = async (row) => {
  try {
    const res = await toggleModuleStatus(row.id, !row.active)
    if (res.status === 'success') {
      row.active = !row.active
      msg('success', `模块已${row.active ? '启用' : '停用'}`)
    } else {
      msg('error', res.message || '操作失败')
    }
  } catch (e) {
    msg('error', e.message || '操作失败')
  }
}

// 删除
const handleDelete = (row) => {
  deletingModule.value = row
  deleteDialogVisible.value = true
}

const confirmDelete = async () => {
  if (!deletingModule.value) return
  try {
    const res = await deleteReportModule(deletingModule.value.id)
    if (res.status === 'success') {
      msg('success', '模块已删除')
    } else {
      msg('error', res.message || '删除失败')
    }
    deleteDialogVisible.value = false
    deletingModule.value = null
    loadModules()
  } catch (e) {
    msg('error', e.message || '删除失败')
  }
}

onMounted(() => {
  loadModules()
})

onBeforeUnmount(() => {
  if (sortableInstance) {
    sortableInstance.destroy()
    sortableInstance = null
  }
})
</script>

<style scoped>
.report-modules-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 14px; flex-shrink: 0;
}
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

.modules-card { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.section-title { display: flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 600; color: #303133; }
.module-count { font-size: 12px; color: #909399; }

.sort-cell {
  display: flex; align-items: center; justify-content: center; gap: 8px;
  cursor: default; user-select: none;
}
.drag-handle {
  cursor: grab; color: #c0c4cc; font-size: 16px; flex-shrink: 0;
  transition: color 0.15s;
}
.drag-handle:hover { color: #409eff; }
.drag-handle:active { cursor: grabbing; }
.sort-index {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 20px; height: 20px; font-size: 12px; font-weight: 600;
  color: #909399; background: #f5f7fa; border-radius: 4px; padding: 0 4px;
}

.module-name-cell { display: flex; align-items: center; gap: 8px; }
.color-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
.fill-count { font-weight: 600; }

/* 弹窗表单 */
.module-form { padding: 10px 0; }

.color-picker { display: flex; gap: 8px; flex-wrap: wrap; }
.color-option {
  width: 28px; height: 28px; border-radius: 50%; cursor: pointer;
  border: 3px solid transparent; transition: all 0.15s;
}
.color-option:hover { transform: scale(1.1); }
.color-option.selected { border-color: #303133; transform: scale(1.15); }

.delete-confirm { font-size: 13px; color: #606266; line-height: 1.8; }
</style>

<!-- 拖拽排序全局样式 -->
<style>
.report-modules-container .sortable-ghost > td {
  background-color: #ecf5ff !important;
  box-shadow: inset 0 0 0 2px #409eff;
}
.report-modules-container .sortable-drag {
  opacity: 0.8;
}
.report-modules-container .sortable-drag > td {
  background: #fff !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}
</style>
