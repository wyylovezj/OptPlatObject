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

      <el-table :data="modules" row-key="id" border style="width: 100%" align="center" :header-cell-style="{ background: '#f5f7fa', color: '#303133', fontWeight: '600' }">
        <el-table-column label="排序" width="80" align="center">
          <template #default="{ $index }">
            <div class="sort-cell">
              <el-icon class="drag-handle"><Rank /></el-icon>
              <span class="sort-index">{{ $index + 1 }}</span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="模块名称" min-width="160" header-align="center">
          <template #default="{ row }">
            <div class="module-name-cell">
              <span class="color-dot" :style="{ background: row.color }"></span>
              <strong>{{ row.name }}</strong>
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="desc" label="描述" min-width="200" show-overflow-tooltip align="center" />

        <el-table-column label="子模块" width="100" align="center">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="openSubModuleDialog(row)">
              管理 ({{ getSubModuleCount(row.id) }})
            </el-button>
          </template>
        </el-table-column>

        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.active ? 'success' : 'info'" size="small" effect="light">
              {{ row.active ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column prop="created" label="创建时间" width="165" align="center" />

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
    <el-dialog v-model="dialogVisible" :title="editingModule ? '编辑模块' : '新增模块'" width="580px" :close-on-click-modal="false">
      <el-scrollbar max-height="600px">
      <el-form :model="moduleForm" label-width="90px" class="module-form">
        <el-form-item label="模块名称" required>
          <el-input v-model="moduleForm.name" placeholder="如：网络安全、数据库运维" maxlength="50" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="moduleForm.desc" type="textarea" :rows="3" placeholder="简要描述该模块的运维范围" maxlength="200" />
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
        <el-divider />
        <el-form-item label="综述模版">
          <div class="template-config">
            <div class="template-tip">
              如该模块的综述需要默认模版，请在下方输入。使用 <code>{变量名}</code> 作为占位符，<code>{A}</code> 可自动计算。<br>
              示例：本期共处理各类故障 {A} 起，其中 P1 级 {B} 起、P2 级 {C} 起、P3 级 {D} 起。
            </div>
            <el-input
              v-model="moduleForm.templateText"
              type="textarea"
              :rows="3"
              placeholder="模版文本，使用 {变量名} 作为占位符"
            />
            <div class="template-computed-row">
              <span class="template-computed-label">自动计算（可选）</span>
              <el-input
                v-model="moduleForm.templateComputed"
                placeholder="如：A=B+C+D+E+F，支持 +-*/ 运算"
                style="flex:1;"
              />
            </div>
          </div>
        </el-form-item>
        <el-divider />
        <el-form-item label="明细模版">
          <div class="template-config">
            <div class="template-tip">
              如该模块新增详细内容时需要默认模版（无子模块时有效），请在下方输入。使用 <code>{变量名}</code> 作为占位符。<br>
              示例：本期共完成日常巡检 {A} 次，处理告警 {B} 次。
            </div>
            <el-input
              v-model="moduleForm.detailTemplateText"
              type="textarea"
              :rows="3"
              placeholder="明细模版文本，使用 {变量名} 作为占位符"
            />
            <div class="template-computed-row">
              <span class="template-computed-label">自动计算（可选）</span>
              <el-input
                v-model="moduleForm.detailTemplateComputed"
                placeholder="如：A=B+C+D+E+F，支持 +-*/ 运算"
                style="flex:1;"
              />
            </div>
          </div>
        </el-form-item>
      </el-form>
      </el-scrollbar>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSaveModule">保存</el-button>
      </template>
    </el-dialog>

    <!-- 删除确认弹窗 -->
    <el-dialog v-model="deleteDialogVisible" title="确认删除" width="420px">
      <div class="delete-confirm">
        确认删除模块 <strong>"{{ deletingModule?.name }}"</strong>？<br>
        历史周报数据将保留。若本周已有人员提交该模块，则无法删除。
      </div>
      <template #footer>
        <el-button @click="deleteDialogVisible = false">取消</el-button>
        <el-button type="danger" @click="confirmDelete">确认删除</el-button>
      </template>
    </el-dialog>

    <!-- 子模块管理弹窗 -->
    <el-dialog v-model="subDialogVisible" :title="'子模块管理 — ' + (currentModule?.name || '')" width="760px" :close-on-click-modal="false">
      <div class="sub-module-section">
        <div class="sub-module-header">
          <span class="sub-module-title">子模块列表（共 {{ currentSubModules.length }} 个）</span>
          <el-button type="primary" size="small" @click="openAddSubDialog">
            <el-icon><Plus /></el-icon>&nbsp;新增子模块
          </el-button>
        </div>

        <el-table v-if="currentSubModules.length > 0" ref="subTableRef" :key="'sub-' + subTableKey" :data="currentSubModules" border size="small" style="width: 100%; margin-top: 10px;">
          <el-table-column label="排序" width="80" align="center">
            <template #default="{ $index, row }">
              <div class="sort-cell">
                <el-icon class="sub-drag-handle"><Rank /></el-icon>
                <span class="sort-index">{{ $index + 1 }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="子模块名称" min-width="150" align="center">
            <template #default="{ row }">
              <strong>{{ row.name }}</strong>
            </template>
          </el-table-column>
          <el-table-column prop="desc" label="描述" min-width="180" show-overflow-tooltip align="center" />
          <el-table-column prop="created" label="创建时间" width="160" align="center" />
          <el-table-column label="操作" width="140" align="center">
            <template #default="{ row }">
              <el-button type="primary" link size="small" @click="openEditSubDialog(row)">编辑</el-button>
              <el-button type="danger" link size="small" @click="handleDeleteSub(row)">删除</el-button>
            </template>
          </el-table-column>
        </el-table>
        <el-empty v-else description="暂无子模块，点击「新增子模块」创建" :image-size="60" style="padding: 20px;" />
      </div>
    </el-dialog>

    <!-- 新增/编辑子模块弹窗 -->
    <el-dialog v-model="subFormDialogVisible" :title="editingSubModule ? '编辑子模块' : '新增子模块'" width="580px" :close-on-click-modal="false">
      <el-scrollbar max-height="600px">
      <el-form :model="subModuleForm" label-width="90px">
        <el-form-item label="子模块名" required>
          <el-input v-model="subModuleForm.name" placeholder="如：运行时间、下周计划" maxlength="100" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="subModuleForm.desc" type="textarea" :rows="2" placeholder="简要描述" maxlength="200" />
        </el-form-item>
        <el-divider />
        <el-form-item label="填写模版">
          <div class="template-config">
            <div class="template-tip">
              如该子模块需要默认模版，请在下方输入。使用 <code>{变量名}</code> 作为占位符，<code>{A}</code> 可自动计算。<br>
              示例：本期共实时各类 IT 变更 {A} 项，其中系统变更 {B} 项、数据类变更 {C} 项、网络与安全变更 {D} 项、服务台实施变更 {E} 项、应用发布 {F} 项。
            </div>
            <el-input
              v-model="subModuleForm.templateText"
              type="textarea"
              :rows="3"
              placeholder="模版文本，使用 {变量名} 作为占位符，如：本期共实时各类 IT 变更 {A} 项..."
            />
            <div class="template-computed-row">
              <span class="template-computed-label">自动计算（可选）</span>
              <el-input
                v-model="subModuleForm.templateComputed"
                placeholder="如：A=B+C+D+E+F，支持 +-*/ 运算"
                style="flex:1;"
              />
            </div>
          </div>
        </el-form-item>
      </el-form>
      </el-scrollbar>
      <template #footer>
        <el-button @click="subFormDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSaveSubModule">保存</el-button>
      </template>
    </el-dialog>

    <!-- 删除子模块确认 -->
    <el-dialog v-model="deleteSubDialogVisible" title="确认删除子模块" width="420px">
      <div class="delete-confirm">
        确认删除子模块 <strong>"{{ deletingSubModule?.name }}"</strong>？<br>
        该子模块下的周报数据将保留。若本周已有人员提交该子模块，则无法删除。
      </div>
      <template #footer>
        <el-button @click="deleteSubDialogVisible = false">取消</el-button>
        <el-button type="danger" @click="confirmDeleteSub">确认删除</el-button>
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
  deleteReportModule, updateModuleSortOrder, toggleModuleStatus,
  getReportSubModules, addReportSubModule, updateReportSubModule,
  deleteReportSubModule, updateSubModuleSortOrder
} from '@/api/weeklyReportApi'
import { reportModules, moduleColorOptions } from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

// 模块列表
const modules = ref([])
let sortableInstance = null

// 弹窗状态
const dialogVisible = ref(false)
const deleteDialogVisible = ref(false)
const editingModule = ref(null)
const deletingModule = ref(null)
const subTableRef = ref(null)
const subTableKey = ref(0)  // 用于强制重建子模块表格

// 子模块状态
const subDialogVisible = ref(false)
const subFormDialogVisible = ref(false)
const deleteSubDialogVisible = ref(false)
const currentModule = ref(null)
const currentSubModules = ref([])
const editingSubModule = ref(null)
const deletingSubModule = ref(null)
let subSortableInstance = null

// 表单
const moduleForm = ref({
  name: '',
  desc: '后援中心运维周报',
  color: '#2563eb',
  templateText: '',
  templateComputed: '',
  detailTemplateText: '',
  detailTemplateComputed: ''
})
const subModuleForm = ref({
  name: '',
  desc: '',
  templateText: '',
  templateComputed: ''
})

// 获取模块的子模块数量（直接使用 allSubModules，确保实时更新）
const getSubModuleCount = (moduleId) => {
  return allSubModules.value.filter(sm => sm.moduleId === moduleId).length
}
const allSubModules = ref([])

// 加载所有子模块
const loadAllSubModules = async () => {
  try {
    allSubModules.value = await getReportSubModules()
  } catch {
    allSubModules.value = []
  }
}

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
        const list = modules.value
        const [moved] = list.splice(oldIndex, 1)
        list.splice(newIndex, 0, moved)
        modules.value.forEach((m, i) => m.order = i + 1)
        try {
          await updateModuleSortOrder(modules.value.map((m, i) => ({ id: m.id, order: i + 1 })))
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
    if (reportModules.value.length > 0) {
      modules.value = [...reportModules.value].sort((a, b) => (a.order || 0) - (b.order || 0))
    }
    console.warn('加载模块列表失败', e)
  }
  initSortable()
}

// 模块相关操作
const openAddDialog = () => {
  editingModule.value = null
  moduleForm.value = { name: '', desc: '后援中心运维周报', color: '#2563eb', templateText: '', templateComputed: '', detailTemplateText: '', detailTemplateComputed: '' }
  dialogVisible.value = true
}
const openEditDialog = (row) => {
  editingModule.value = row
  // 综述模版
  if (row.template) {
    const tpl = typeof row.template === 'string' ? JSON.parse(row.template) : row.template
    if (tpl) {
      moduleForm.value = {
        name: row.name,
        desc: row.desc || '',
        category: row.category || '基础设施',
        color: row.color || '#2563eb',
        templateText: tpl.text || '',
        templateComputed: Object.entries(tpl.computed || {}).map(([k, v]) => `${k}=${v}`).join('; ')
      }
    } else {
      moduleForm.value = { name: row.name, desc: row.desc || '', category: row.category || '基础设施', color: row.color || '#2563eb', templateText: '', templateComputed: '' }
    }
  } else {
    moduleForm.value = { name: row.name, desc: row.desc || '', category: row.category || '基础设施', color: row.color || '#2563eb', templateText: '', templateComputed: '' }
  }
  // 明细模版
  if (row.detailTemplate) {
    const dtpl = typeof row.detailTemplate === 'string' ? JSON.parse(row.detailTemplate) : row.detailTemplate
    moduleForm.value.detailTemplateText = dtpl.text || ''
    moduleForm.value.detailTemplateComputed = Object.entries(dtpl.computed || {}).map(([k, v]) => `${k}=${v}`).join('; ')
  } else {
    moduleForm.value.detailTemplateText = ''
    moduleForm.value.detailTemplateComputed = ''
  }
  dialogVisible.value = true
}
const handleSaveModule = async () => {
  if (!moduleForm.value.name || !moduleForm.value.name.trim()) { msg('warning', '请输入模块名称'); return }
  try {
    const templateData = buildModuleTemplateData('templateText', 'templateComputed')
    const detailTemplateData = buildModuleTemplateData('detailTemplateText', 'detailTemplateComputed')
    const formData = {
      name: moduleForm.value.name,
      desc: moduleForm.value.desc,
      category: moduleForm.value.category,
      color: moduleForm.value.color,
      template: templateData,
      detailTemplate: detailTemplateData
    }
    if (editingModule.value) {
      const res = await updateReportModule(editingModule.value.id, formData)
      if (res.status === 'success') msg('success', '模块已更新')
      else msg('error', res.message || '更新失败')
    } else {
      const res = await addReportModule(formData)
      if (res.status === 'success') msg('success', '模块已创建')
      else msg('error', res.message || '创建失败')
    }
    dialogVisible.value = false
    loadModules()
  } catch (e) { msg('error', e.message || '操作失败') }
}

// 构建模版 JSON 对象（通用，通过参数指定字段名）
const buildModuleTemplateData = (textField, computedField) => {
  const text = moduleForm.value[textField]
  const computedStr = moduleForm.value[computedField]
  if (!text && !computedStr) return null
  const computed = {}
  if (computedStr) {
    computedStr.split(';').forEach(part => {
      part = part.trim()
      if (!part) return
      const eqIdx = part.indexOf('=')
      if (eqIdx > 0) {
        const key = part.substring(0, eqIdx).trim()
        const formula = part.substring(eqIdx + 1).trim()
        if (key && formula) computed[key] = formula
      }
    })
  }
  return JSON.stringify({ text: text || '', computed: Object.keys(computed).length > 0 ? computed : undefined })
}
const handleToggleStatus = async (row) => {
  try {
    const res = await toggleModuleStatus(row.id, !row.active)
    if (res.status === 'success') { row.active = !row.active; msg('success', `模块已${row.active ? '启用' : '停用'}`) }
    else msg('error', res.message || '操作失败')
  } catch (e) { msg('error', e.message || '操作失败') }
}
const handleDelete = (row) => { deletingModule.value = row; deleteDialogVisible.value = true }
const confirmDelete = async () => {
  if (!deletingModule.value) return
  try {
    const res = await deleteReportModule(deletingModule.value.id)
    if (res.status === 'success') msg('success', '模块已删除')
    else msg('error', res.message || '删除失败')
    deleteDialogVisible.value = false; deletingModule.value = null; loadModules()
  } catch (e) { msg('error', e.message || '删除失败') }
}

// 子模块相关操作
const openSubModuleDialog = async (mod) => {
  currentModule.value = mod
  try {
    currentSubModules.value = await getReportSubModules(mod.id)
  } catch {
    currentSubModules.value = []
  }
  subDialogVisible.value = true
  // 等待弹窗渲染完成后初始化拖拽
  nextTick(() => initSubSortable())
}

// 初始化子模块拖拽排序
const initSubSortable = () => {
  if (subSortableInstance) {
    subSortableInstance.destroy()
    subSortableInstance = null
  }
  const el = document.querySelector('.sub-module-section')
  const tbody = el?.querySelector('.el-table__body-wrapper tbody')
  if (!tbody) return
  subSortableInstance = Sortable.create(tbody, {
    handle: '.sub-drag-handle',
    animation: 200,
    easing: 'cubic-bezier(0.25, 0.1, 0.25, 1)',
    delay: 100,
    delayOnTouchOnly: true,
    onEnd: async (evt) => {
      const { oldIndex, newIndex } = evt
      if (oldIndex === undefined || newIndex === undefined || oldIndex === newIndex) return
      // 创建新数组引用强制 Vue 重新渲染（Sortable 已移动 DOM，Vue 不会自动重算 $index）
      const list = [...currentSubModules.value]
      const [moved] = list.splice(oldIndex, 1)
      list.splice(newIndex, 0, moved)
      list.forEach((m, i) => m.order = i + 1)
      currentSubModules.value = list  // 替换引用触发重渲染
      subTableKey.value++              // 递增 key 强制重建表格，slot 重新求值
      await loadAllSubModules()       // 同步刷新主页面子模块计数
      try {
        await updateSubModuleSortOrder(list.map((m, i) => ({ id: m.id, order: i + 1 })))
        msg('success', '子模块排序已更新')
      } catch (e) {
        msg('error', e.message || '更新排序失败')
        currentSubModules.value = await getReportSubModules(currentModule.value.id)
      }
      nextTick(() => initSubSortable())  // 表格重建后重新初始化拖拽
    }
  })
}

const openAddSubDialog = () => {
  editingSubModule.value = null
  subModuleForm.value = { name: '', desc: '', templateText: '', templateComputed: '' }
  subFormDialogVisible.value = true
}

const openEditSubDialog = (row) => {
  editingSubModule.value = row
  if (row.template) {
    const tpl = typeof row.template === 'string' ? JSON.parse(row.template) : row.template
    if (tpl) {
      subModuleForm.value = {
        name: row.name,
        desc: row.desc || '',
        templateText: tpl.text || '',
        templateComputed: Object.entries(tpl.computed || {}).map(([k, v]) => `${k}=${v}`).join('; ')
      }
    } else {
      subModuleForm.value = { name: row.name, desc: row.desc || '', templateText: '', templateComputed: '' }
    }
  } else {
    subModuleForm.value = { name: row.name, desc: row.desc || '', templateText: '', templateComputed: '' }
  }
  subFormDialogVisible.value = true
}

// 构建模版 JSON 对象
const buildTemplateData = () => {
  const text = subModuleForm.value.templateText
  const computedStr = subModuleForm.value.templateComputed
  if (!text && !computedStr) return null
  const computed = {}
  if (computedStr) {
    computedStr.split(';').forEach(part => {
      part = part.trim()
      if (!part) return
      const eqIdx = part.indexOf('=')
      if (eqIdx > 0) {
        const key = part.substring(0, eqIdx).trim()
        const formula = part.substring(eqIdx + 1).trim()
        if (key && formula) computed[key] = formula
      }
    })
  }
  return JSON.stringify({ text: text || '', computed: Object.keys(computed).length > 0 ? computed : undefined })
}

const handleSaveSubModule = async () => {
  if (!subModuleForm.value.name || !subModuleForm.value.name.trim()) { msg('warning', '请输入子模块名称'); return }
  try {
    const templateData = buildTemplateData()
    const formData = {
      name: subModuleForm.value.name,
      desc: subModuleForm.value.desc,
      template: templateData
    }
    if (editingSubModule.value) {
      const res = await updateReportSubModule(editingSubModule.value.id, formData)
      if (res.status === 'success') msg('success', '子模块已更新')
      else msg('error', res.message || '更新失败')
    } else {
      const res = await addReportSubModule({ moduleId: currentModule.value.id, ...formData })
      if (res.status === 'success') msg('success', '子模块已创建')
      else msg('error', res.message || '创建失败')
    }
    subFormDialogVisible.value = false
    editingSubModule.value = null
    // 刷新子模块列表
    currentSubModules.value = await getReportSubModules(currentModule.value.id)
    await loadAllSubModules()
  } catch (e) { msg('error', e.message || '操作失败') }
}

const handleDeleteSub = (row) => {
  deletingSubModule.value = row
  deleteSubDialogVisible.value = true
}

const confirmDeleteSub = async () => {
  if (!deletingSubModule.value) return
  try {
    const res = await deleteReportSubModule(deletingSubModule.value.id)
    if (res.status === 'success') msg('success', '子模块已删除')
    else msg('error', res.message || '删除失败')
    deleteSubDialogVisible.value = false
    deletingSubModule.value = null
    currentSubModules.value = await getReportSubModules(currentModule.value.id)
    await loadAllSubModules()
  } catch (e) { msg('error', e.message || '删除失败') }
}

onMounted(() => {
  loadModules()
  loadAllSubModules()
})

onBeforeUnmount(() => {
  if (sortableInstance) { sortableInstance.destroy(); sortableInstance = null }
  if (subSortableInstance) { subSortableInstance.destroy(); subSortableInstance = null }
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
.drag-handle { cursor: grab; color: #c0c4cc; font-size: 16px; flex-shrink: 0; transition: color 0.15s; }
.drag-handle:hover { color: #409eff; }
.drag-handle:active { cursor: grabbing; }
.sub-drag-handle { cursor: grab; color: #c0c4cc; font-size: 14px; }
.sub-drag-handle:active { cursor: grabbing; }
.sort-index {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 20px; height: 20px; font-size: 12px; font-weight: 600;
  color: #909399; background: #f5f7fa; border-radius: 4px; padding: 0 4px;
}

.module-name-cell { display: flex; align-items: center; justify-content: flex-start; gap: 8px; }
.color-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; display: inline-block; }

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

/* 子模块管理 */
.sub-module-section { min-height: 200px; }
.sub-module-header {
  display: flex; justify-content: space-between; align-items: center;
}
.sub-module-title { font-size: 14px; font-weight: 600; color: #303133; }

/* 模版配置 */
.template-config { width: 100%; }
.template-tip { font-size: 12px; color: #909399; line-height: 1.6; margin-bottom: 8px; padding: 8px 10px; background: #f5f7fa; border-radius: 4px; }
.template-tip code { background: #e8e8e8; padding: 0 4px; border-radius: 2px; font-size: 12px; color: #e6a23c; }
.template-computed-row { display: flex; align-items: center; gap: 8px; margin-top: 8px; }
.template-computed-label { font-size: 12px; color: #909399; white-space: nowrap; flex-shrink: 0; }
</style>

<!-- 拖拽排序全局样式 -->
<style>
.report-modules-container .sortable-ghost > td {
  background-color: #ecf5ff !important;
  box-shadow: inset 0 0 0 2px #409eff;
}
.report-modules-container .sortable-drag { opacity: 0.8; }
.report-modules-container .sortable-drag > td {
  background: #fff !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}
</style>
