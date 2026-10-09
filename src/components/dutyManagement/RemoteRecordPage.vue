<template>
  <div class="moa-vpn-ecc-container">
    <!-- 标签页切换 -->
    <el-tabs v-model="activeTab" class="main-tabs" @tab-change="handleTabChange" @before-leave="handleBeforeTabLeave">
      <!-- ==================== Tab1: R及VPN权限使用记录 ==================== -->
      <el-tab-pane label="RA及VPN权限使用记录" name="moaVpn">
        <div class="tab-content">
          <!-- 标题栏 -->
          <div class="header-bar">
            <div class="page-title">{{ moaVpnTitle }}</div>
          </div>
          <!-- 工具栏 -->
          <div class="toolbar">
            <div class="toolbar-left">
              <el-date-picker
                v-model="moaVpnDateRange"
                type="daterange"
                range-separator="至"
                start-placeholder="开始日期"
                end-placeholder="结束日期"
                format="YYYY-MM-DD"
                value-format="YYYY-MM-DD"
                :shortcuts="dateShortcuts"
                @change="handleMoaVpnDateChange"
                @clear="handleMoaVpnClear"
              />
            </div>
            <span class="filter-sep"></span>
            <div class="toolbar-filter">
              <span class="filter-label">邮件：</span>
              <el-select v-model="moaVpnEmailFilter" size="small" clearable placeholder="全部" style="width: 100px">
                <el-option label="未补发" value="未补发" />
                <el-option label="已补发" value="已补发" />
              </el-select>
            </div>
            <span class="filter-sep"></span>
            <div class="toolbar-right">
              <div class="toolbar-actions-left">
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:save')" type="success" size="small" @click="handleMoaVpnSave">
                  <el-icon><Check /></el-icon>&nbsp;保存
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:load')" size="small" @click="loadMoaVpnData">
                  <el-icon><Refresh /></el-icon>&nbsp;加载
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:export')" size="small" type="warning" @click="handleMoaVpnExport">
                  <el-icon><Download /></el-icon>&nbsp;导出
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:mergeExport')" size="small" type="warning" @click="handleMergedExport">
                  <el-icon><Files /></el-icon>&nbsp;合并导出
                </el-button>
              </div>
              <div class="toolbar-actions-right">
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:addRow')" type="primary" plain size="small" @click="handleMoaVpnAddRow">
                  <el-icon><Plus /></el-icon>&nbsp;新增行
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:moaVpn:deleteRow')" type="danger" plain size="small" @click="handleMoaVpnDeleteRow">
                  <el-icon><Delete /></el-icon>&nbsp;删除选中
                </el-button>
              </div>
            </div>
          </div>
          <!-- 表格 -->
          <div v-loading="isLoadingData" element-loading-text="加载中..." class="table-wrapper" ref="moaVpnTableRef">
            <el-table
              :data="paginatedMoaVpnData"
              border
              style="width: 100%"
              :max-height="tableMaxHeight"
              :header-cell-style="{ background: '#5B9BD5', color: '#FFFFFF', fontWeight: '600', textAlign: 'center' }"
              :cell-style="{ textAlign: 'center' }"
              @selection-change="handleMoaVpnSelectionChange"
            >
              <el-table-column type="selection" width="40" />
              <el-table-column type="index" label="序号" width="60" :index="(i) => (moaVpnPage - 1) * moaVpnPageSize + i + 1" />
              <el-table-column label="日期" width="130">
                <template #default="{ row }">
                  <el-date-picker v-model="row.record_date" type="date" placeholder="日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" size="small" style="width: 100%" @change="onMoaVpnDateChange(row)" />
                </template>
              </el-table-column>
              <el-table-column label="申请用户" width="115">
                <template #default="{ row }">
                  <el-select v-model="row.apply_user" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onUserSelectVisibleChange">
                    <template #header>
                      <el-input v-model="userSearchKeyword" size="small" placeholder="搜索用户" clearable @click.stop @input="() => {}" style="width: 100%" />
                    </template>
                    <el-option v-for="u in filteredUserList" :key="u.username" :label="`${u.nickname || u.username}`" :value="u.nickname || u.username">
                      <span>{{ u.nickname || u.username }}</span>
                      <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ u.username }}</span>
                    </el-option>
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="使用缘由" min-width="140">
                <template #default="{ row }">
                  <el-input v-model="row.reason" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
                </template>
              </el-table-column>
              <el-table-column label="权限类别" width="100">
                <template #default="{ row }">
                  <el-select v-model="row.permission_type" size="small" clearable placeholder="请选择" style="width: 100%">
                    <el-option label="RA" value="RA" />
                    <el-option label="VPN" value="VPN" />
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="开始时间" width="140">
                <template #default="{ row }">
                  <el-date-picker v-model="row.start_time" type="datetime" format="MM-DD HH:mm" value-format="MM-DD HH:mm" placeholder="开始" size="small" style="width: 100%" />
                </template>
              </el-table-column>
              <el-table-column label="结束时间" width="140">
                <template #default="{ row }">
                  <el-date-picker v-model="row.end_time" type="datetime" format="MM-DD HH:mm" value-format="MM-DD HH:mm" placeholder="结束" size="small" style="width: 100%" />
                </template>
              </el-table-column>
              <el-table-column label="ECC值班人" width="110">
                <template #default="{ row }">
                  <el-select v-model="row.ecc_duty_person" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onEccSelectVisibleChange(row, $event)">
                    <template #header>
                      <el-input v-model="eccSearchKeyword" size="small" placeholder="搜索" clearable @click.stop @input="() => {}" style="width: 100%" />
                    </template>
                    <el-option v-for="p in filteredEccDutyList" :key="p.userCode" :label="p.name" :value="p.name">
                      <span>{{ p.name }}</span>
                      <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
                    </el-option>
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="审批人" width="110">
                <template #default="{ row }">
                  <el-select v-model="row.approver" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onPmSelectVisibleChange">
                    <template #header>
                      <el-input v-model="pmSearchKeyword" size="small" placeholder="搜索PM" clearable @click.stop @input="() => {}" style="width: 100%" />
                    </template>
                    <el-option v-for="p in filteredPmList" :key="p.userCode" :label="p.name" :value="p.name">
                      <span>{{ p.name }}</span>
                      <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
                    </el-option>
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="邮件" width="95">
                <template #default="{ row }">
                  <el-select v-model="row.email" size="small" clearable placeholder="请选择" style="width: 100%">
                    <el-option label="已补发" value="已补发" />
                    <el-option label="未补发" value="未补发" />
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="备注" min-width="120">
                <template #default="{ row }">
                  <el-input v-model="row.remark" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
                </template>
              </el-table-column>
            </el-table>
          </div>
          <div class="pagination-bar" v-if="displayMoaVpnTableData.length > 0">
            <span class="pagination-total">共 {{ displayMoaVpnTableData.length }} 条</span>
            <el-pagination
              v-model:current-page="moaVpnPage"
              :page-size="moaVpnPageSize"
              :total="displayMoaVpnTableData.length"
              layout="prev, pager, next"
              small
              background
            />
          </div>
        </div>
      </el-tab-pane>

      <!-- ==================== Tab2: ECC联系异常情况 ==================== -->
      <el-tab-pane label="ECC联系异常情况" name="eccContact">
        <div class="tab-content">
          <!-- 标题栏 -->
          <div class="header-bar">
            <div class="page-title">{{ eccContactTitle }}</div>
          </div>
          <!-- 工具栏 -->
          <div class="toolbar">
            <div class="toolbar-left">
              <el-date-picker
                v-model="eccContactDateRange"
                type="daterange"
                range-separator="至"
                start-placeholder="开始日期"
                end-placeholder="结束日期"
                format="YYYY-MM-DD"
                value-format="YYYY-MM-DD"
                :shortcuts="dateShortcuts"
                @change="handleEccContactDateChange"
                @clear="handleEccContactClear"
              />
            </div>
            <span class="filter-sep"></span>
            <div class="toolbar-right">
              <div class="toolbar-actions-left">
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:save')" type="success" size="small" @click="handleEccContactSave">
                  <el-icon><Check /></el-icon>&nbsp;保存
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:load')" size="small" @click="loadEccContactData">
                  <el-icon><Refresh /></el-icon>&nbsp;加载
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:export')" size="small" type="warning" @click="handleEccContactExport">
                  <el-icon><Download /></el-icon>&nbsp;导出
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:mergeExport')" size="small" type="warning" @click="handleMergedExport">
                  <el-icon><Files /></el-icon>&nbsp;合并导出
                </el-button>
              </div>
              <div class="toolbar-actions-right">
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:addRow')" type="primary" plain size="small" @click="handleEccContactAddRow">
                  <el-icon><Plus /></el-icon>&nbsp;新增行
                </el-button>
                <el-button v-if="permissionStore.hasPermission('remote:eccContact:deleteRow')" type="danger" plain size="small" @click="handleEccContactDeleteRow">
                  <el-icon><Delete /></el-icon>&nbsp;删除选中
                </el-button>
              </div>
            </div>
          </div>
          <!-- 表格 -->
          <div v-loading="isLoadingData" element-loading-text="加载中..." class="table-wrapper" ref="eccContactTableRef">
            <el-table
              :data="paginatedEccContactData"
              border
              style="width: 100%"
              :max-height="tableMaxHeight"
              :header-cell-style="{ background: '#5B9BD5', color: '#FFFFFF', fontWeight: '600', textAlign: 'center' }"
              :cell-style="{ textAlign: 'center' }"
              @selection-change="handleEccContactSelectionChange"
            >
              <el-table-column type="selection" width="40" />
              <el-table-column type="index" label="序号" width="60" :index="(i) => (eccContactPage - 1) * eccContactPageSize + i + 1" />
              <el-table-column label="日期" width="120">
                <template #default="{ row }">
                  <el-date-picker v-model="row.record_date" type="date" placeholder="选择日期" format="YYYY-MM-DD" value-format="YYYY-MM-DD" size="small" style="width: 100%" />
                </template>
              </el-table-column>
              <el-table-column label="当班人或负责人" width="150">
                <template #default="{ row }">
                  <el-select v-model="row.duty_person" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onDutyPersonSelectVisibleChange">
                    <template #header>
                      <el-input v-model="dutyPersonSearchKw" size="small" placeholder="搜索" clearable @click.stop @input="() => {}" style="width: 100%" />
                    </template>
                    <el-option v-for="p in filteredDutyPersonList" :key="p.userCode" :label="p.name" :value="p.name">
                      <span>{{ p.name }}</span>
                      <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
                    </el-option>
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="二次联系人" width="150">
                <template #default="{ row }">
                  <el-select v-model="row.second_contact" size="small" clearable placeholder="请选择" style="width: 100%" @visible-change="onSecondContactSelectVisibleChange">
                    <template #header>
                      <el-input v-model="secondContactSearchKw" size="small" placeholder="搜索" clearable @click.stop @input="() => {}" style="width: 100%" />
                    </template>
                    <el-option v-for="p in filteredSecondContactList" :key="p.userCode" :label="p.name" :value="p.name">
                      <span>{{ p.name }}</span>
                      <span style="float: right; color: #909399; font-size: 12px; margin-left: 8px;">{{ p.userCode }}</span>
                    </el-option>
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="详细情况" min-width="260">
                <template #default="{ row }">
                  <el-input v-model="row.detail" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
                </template>
              </el-table-column>
              <el-table-column label="是否回电" width="110">
                <template #default="{ row }">
                  <el-select v-model="row.is_callback" size="small" placeholder="请选择" clearable style="width: 100%">
                    <el-option label="是" value="是" />
                    <el-option label="否" value="否" />
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="备注" min-width="160">
                <template #default="{ row }">
                  <el-input v-model="row.remark" type="textarea" :autosize="{ minRows: 1, maxRows: 4 }" size="small" placeholder="请输入" spellcheck="false" resize="none" />
                </template>
              </el-table-column>
            </el-table>
          </div>
          <div class="pagination-bar" v-if="eccContactTableData.length > 0">
            <span class="pagination-total">共 {{ eccContactTableData.length }} 条</span>
            <el-pagination
              v-model:current-page="eccContactPage"
              :page-size="eccContactPageSize"
              :total="eccContactTableData.length"
              layout="prev, pager, next"
              small
              background
            />
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Check, Refresh, Download, Delete, Files } from '@element-plus/icons-vue'
import {
  saveMoaVpnRecord, getMoaVpnRecord, deleteMoaVpnRecord, exportMoaVpnRecord,
  saveEccContactException, getEccContactException, deleteEccContactException, exportEccContactException,
  exportMergedRemoteRecord,
  getDuty
} from '@/api/contactApi.js'
import { getUserList } from '@/api/userPermisssion'
import { getPM, getSys, getNet } from '@/api/dutyPageInterface'
import { usePermissionStore } from '@/stores/permissionStore.js'

// 统一消息提示
const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }
const permissionStore = usePermissionStore()

// 当前激活的标签页
const activeTab = ref('moaVpn')

// 表格容器引用
const moaVpnTableRef = ref(null)
const eccContactTableRef = ref(null)
const tableMaxHeight = ref(0)

// 日期快捷选项
const getLocalDateStr = () => {
  const d = new Date()
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
}
const today = getLocalDateStr()
const lastWeek = (() => { const d = new Date(); d.setDate(d.getDate() - 6); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0') })()
const dateShortcuts = [
  {
    text: '本月',
    value: () => {
      const now = new Date()
      const first = new Date(now.getFullYear(), now.getMonth(), 1)
      return [first, now]
    },
  },
  {
    text: '上月',
    value: () => {
      const now = new Date()
      const first = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const last = new Date(now.getFullYear(), now.getMonth(), 0)
      return [first, last]
    },
  },
]

// ==================== MOA及VPN权限使用记录 ====================
const moaVpnDateRange = ref([lastWeek, today])
const moaVpnEmailFilter = ref('未补发')
const moaVpnTableData = ref([])

// 表格显示数据（由源数据按当前邮件筛选值过滤得到，仅在点击"加载"/新增/删除时更新）
const displayMoaVpnTableData = ref([])

// 应用邮件筛选到显示数据
const applyMoaVpnFilter = () => {
  if (!moaVpnEmailFilter.value) {
    displayMoaVpnTableData.value = [...moaVpnTableData.value]
  } else {
    displayMoaVpnTableData.value = moaVpnTableData.value.filter(r => r.email === moaVpnEmailFilter.value)
  }
}

// 源数据变化时（加载/新增/删除），同步到显示数据
watch(() => moaVpnTableData.value, () => {
  applyMoaVpnFilter()
  // 跳到最后一页（数据追加在末尾）
  const totalPages = Math.ceil(displayMoaVpnTableData.value.length / moaVpnPageSize.value)
  moaVpnPage.value = totalPages || 1
})

// MoaVpn分页
const moaVpnPage = ref(1)
const moaVpnPageSize = ref(15)
const paginatedMoaVpnData = computed(() => {
  const start = (moaVpnPage.value - 1) * moaVpnPageSize.value
  return displayMoaVpnTableData.value.slice(start, start + moaVpnPageSize.value)
})

const moaVpnSelectedRows = ref([])

// 下拉数据源
const userList = ref([])
const eccDutyMap = ref({}) // 按日期缓存ECC值班人员 { 'YYYY-MM-DD': [{name, userCode}] }
const eccCurrentRow = ref(null) // 当前打开下拉框的行
const pmList = ref([])

// 下拉框搜索关键词
const userSearchKeyword = ref('')
const eccSearchKeyword = ref('')
const pmSearchKeyword = ref('')

// 过滤后的下拉列表
const filteredUserList = computed(() => {
  const kw = userSearchKeyword.value.trim().toLowerCase()
  if (!kw) return userList.value
  return userList.value.filter(u =>
    (u.nickname || '').toLowerCase().includes(kw) ||
    u.username.toLowerCase().includes(kw)
  )
})

const filteredEccDutyList = computed(() => {
  const date = eccCurrentRow.value?.record_date
  const list = date ? (eccDutyMap.value[date] || []) : []
  const kw = eccSearchKeyword.value.trim().toLowerCase()
  if (!kw) return list
  return list.filter(p =>
    p.name.toLowerCase().includes(kw) ||
    (p.userCode || '').toLowerCase().includes(kw)
  )
})

const filteredPmList = computed(() => {
  const kw = pmSearchKeyword.value.trim().toLowerCase()
  if (!kw) return pmList.value
  return pmList.value.filter(p =>
    p.name.toLowerCase().includes(kw) ||
    (p.userCode || '').toLowerCase().includes(kw)
  )
})

// 下拉展开/收起时清空搜索
const onUserSelectVisibleChange = (visible) => { if (!visible) userSearchKeyword.value = '' }
const onEccSelectVisibleChange = async (row, visible) => {
  if (visible) {
    eccCurrentRow.value = row
    if (row.record_date && !eccDutyMap.value[row.record_date]) {
      await fetchEccDutyForDate(row.record_date)
    }
  } else {
    eccSearchKeyword.value = ''
    eccCurrentRow.value = null
  }
}
const onPmSelectVisibleChange = (visible) => { if (!visible) pmSearchKeyword.value = '' }

// username 反查辅助函数
const getUserUsername = (nickname) => {
  if (!nickname) return ''
  const user = userList.value.find(u => (u.nickname || u.username) === nickname)
  return user?.username || ''
}
const getEccPersonUsername = (name) => {
  if (!name) return ''
  for (const date in eccDutyMap.value) {
    const person = eccDutyMap.value[date]?.find(p => p.name === name)
    if (person) return person.userCode || ''
  }
  return ''
}
const getPmUsername = (name) => {
  if (!name) return ''
  const pm = pmList.value.find(p => p.name === name)
  return pm?.userCode || ''
}
const getOpsPersonUsername = (name) => {
  if (!name) return ''
  const person = opsPersonnelList.value.find(p => p.name === name)
  return person?.userCode || ''
}

// 日期变化时清空ECC值班人（因为值班人列表按日期加载）
const onMoaVpnDateChange = (row) => {
  row.ecc_duty_person = ''
}

// ==================== 未保存提示 ====================
const moaVpnDirty = ref(false)
const eccContactDirty = ref(false)
const isDirty = computed(() => moaVpnDirty.value || eccContactDirty.value)
const isLoadingData = ref(false) // 加载数据时抑制watch
let _lastLoadTime = 0

// 浏览器关闭/刷新提示
const handleBeforeUnload = (e) => {
  if (isDirty.value) {
    e.preventDefault()
    e.returnValue = ''
  }
}

// 路由离开前提示
onBeforeRouteLeave(async () => {
  if (isDirty.value) {
    try {
      await ElMessageBox.confirm('当前有未保存的修改，确定要离开吗？', '未保存提示', {
        confirmButtonText: '离开', cancelButtonText: '取消', type: 'warning',
      })
      return true
    } catch { return false }
  }
  return true
})

// Tab 切换前检查
const handleBeforeTabLeave = async (newTab, oldTab) => {
  const dirty = (oldTab === 'moaVpn' && moaVpnDirty.value) || (oldTab === 'eccContact' && eccContactDirty.value)
  if (dirty) {
    try {
      await ElMessageBox.confirm('当前标签页有未保存的修改，切换后将丢失更改，是否继续？', '未保存提示', {
        confirmButtonText: '继续切换', cancelButtonText: '取消', type: 'warning',
      })
      return true
    } catch { return false }
  }
  return true
}

const moaVpnTitle = computed(() => {
  if (!moaVpnDateRange.value || moaVpnDateRange.value.length !== 2) return 'RA及VPN权限使用记录'
  const [start] = moaVpnDateRange.value
  const d = new Date(start)
  return `${d.getFullYear()}年${d.getMonth() + 1}月RA及VPN权限使用记录`
})

const handleMoaVpnSelectionChange = (rows) => { moaVpnSelectedRows.value = rows }
const handleMoaVpnDateChange = () => { loadMoaVpnData() }
const handleMoaVpnClear = () => { moaVpnDateRange.value = [lastWeek, today]; loadMoaVpnData() }

const handleMoaVpnAddRow = () => {
  moaVpnTableData.value.push({
    _isNew: true,
    record_date: today,
    apply_user: '',
    reason: '',
    permission_type: '',
    start_time: '',
    end_time: '',
    ecc_duty_person: '',
    approver: '',
    email: '未补发',
    remark: '',
  })
  applyMoaVpnFilter()
  // 新增后跳转到最后一页
  const totalPages = Math.ceil(moaVpnTableData.value.length / moaVpnPageSize.value)
  moaVpnPage.value = totalPages || 1
  loadEccDutyByTableDates()
}

const handleMoaVpnDeleteRow = async () => {
  if (moaVpnSelectedRows.value.length === 0) {
    msg('warning', '请先选中要删除的行')
    return
  }
  try {
    await ElMessageBox.confirm(`确定要删除选中的 ${moaVpnSelectedRows.value.length} 条记录吗？`, '删除确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'warning',
    })
  } catch { return }

  const newRows = moaVpnSelectedRows.value.filter(r => r._isNew)
  const savedRows = moaVpnSelectedRows.value.filter(r => !r._isNew && r.id)

  isLoadingData.value = true
  newRows.forEach(r => {
    const idx = moaVpnTableData.value.indexOf(r)
    if (idx !== -1) moaVpnTableData.value.splice(idx, 1)
  })

  for (const r of savedRows) {
    try {
      const res = await deleteMoaVpnRecord(r.id)
      if (res.status === 'success') {
        const idx = moaVpnTableData.value.findIndex(item => item.id === r.id)
        if (idx !== -1) moaVpnTableData.value.splice(idx, 1)
      } else {
        msg('error', res.message || '删除失败')
      }
    } catch (e) { msg('error', e.message || '删除失败') }
  }
  await nextTick()
  applyMoaVpnFilter()
  isLoadingData.value = false
  moaVpnDirty.value = false
  msg('success', '删除完成')
}

const handleMoaVpnSave = async () => {
  const noDateRows = moaVpnTableData.value.filter(r => !r.record_date)
  if (noDateRows.length > 0) {
    msg('warning', '存在未填写日期的行，请补充后再保存')
    return
  }
  try {
    await ElMessageBox.confirm('确定要保存当前数据吗？', '保存确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'info',
    })
  } catch { return }

  const records = moaVpnTableData.value.map(r => ({
    id: r._isNew ? null : r.id,
    record_date: r.record_date,
    apply_user: r.apply_user || '',
    apply_user_username: getUserUsername(r.apply_user),
    reason: r.reason || '',
    permission_type: r.permission_type || '',
    start_time: r.start_time || '',
    end_time: r.end_time || '',
    ecc_duty_person: r.ecc_duty_person || '',
    ecc_duty_person_username: getEccPersonUsername(r.ecc_duty_person),
    approver: r.approver || '',
    approver_username: getPmUsername(r.approver),
    email: r.email || '',
    remark: r.remark || '',
  }))

  try {
    const res = await saveMoaVpnRecord(records)
    if (res.status === 'success') {
      msg('success', '保存成功')
      moaVpnDirty.value = false
      loadMoaVpnData()
      loadEccDutyByTableDates()
    } else {
      msg('error', res.message || '保存失败')
    }
  } catch (e) { msg('error', e.message || '保存失败') }
}

const loadMoaVpnData = async () => {
  const _now = Date.now()
  if (_now - _lastLoadTime < 500) return
  _lastLoadTime = _now
  if (moaVpnDirty.value) {
    try {
      await ElMessageBox.confirm('当前有未保存的修改，重新加载将丢失更改，是否继续？', '未保存提示', {
        confirmButtonText: '继续加载', cancelButtonText: '取消', type: 'warning',
      })
    } catch { return }
  }
  if (!moaVpnDateRange.value || moaVpnDateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  isLoadingData.value = true
  await nextTick()
  const loadStart = Date.now()
  // await new Promise(resolve => setTimeout(resolve, 1000))
  try {
    const res = await getMoaVpnRecord(moaVpnDateRange.value)
    if (res.status === 'success' && res.data) {
      moaVpnTableData.value = res.data.map(r => ({ ...r, _isNew: false }))
      await nextTick()
      moaVpnDirty.value = false
    } else {
      moaVpnTableData.value = []
      await nextTick()
      moaVpnDirty.value = false
    }
  } catch (e) { msg('error', e.message || '加载数据失败') }
  const elapsed = Date.now() - loadStart
  if (elapsed < 200) await new Promise(r => setTimeout(r, 200 - elapsed))
  isLoadingData.value = false
  if (moaVpnTableData.value.length > 0) {
    msg('success', `已加载 ${displayMoaVpnTableData.value.length} 条记录`)
    loadEccDutyByTableDates()
  }
}

// 加载用户列表（sys_user）
const loadUserList = async () => {
  try {
    const result = await getUserList({})
    if (result.data) {
      userList.value = result.data.filter(u => u.status === 1)
    }
  } catch (e) { console.error('加载用户列表失败', e) }
}

// 加载甲方PM列表
const loadPmList = async () => {
  try {
    const data = await getPM()
    pmList.value = data || []
  } catch (e) { console.error('加载PM列表失败', e) }
}

// 加载ECC排班人员（前一天 + 当天，合并去重）
const fetchEccDutyForDate = async (date) => {
  try {
    const d = new Date(date + 'T00:00:00')
    d.setDate(d.getDate() - 1)
    const pad = n => String(n).padStart(2, '0')
    const prevDay = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

    const data = await getDuty([prevDay, date])
    const list = []
    const seen = new Set()
    if (data && data.length > 0) {
      for (const schedule of data) {
        if (schedule.eccDayPersonnelName && schedule.eccDayPersonnelId && !seen.has(schedule.eccDayPersonnelId)) {
          seen.add(schedule.eccDayPersonnelId)
          list.push({ name: schedule.eccDayPersonnelName, userCode: schedule.eccDayPersonnelId })
        }
        if (schedule.eccNightPersonnelName && schedule.eccNightPersonnelId && !seen.has(schedule.eccNightPersonnelId)) {
          seen.add(schedule.eccNightPersonnelId)
          list.push({ name: schedule.eccNightPersonnelName, userCode: schedule.eccNightPersonnelId })
        }
      }
    }
    eccDutyMap.value[date] = list
  } catch (e) { console.error('加载ECC排班失败', e) }
}

// 根据表格中的日期批量加载ECC值班人员
const loadEccDutyByTableDates = async () => {
  const dates = [...new Set(moaVpnTableData.value.map(r => r.record_date).filter(Boolean))]
  const newDates = dates.filter(d => !eccDutyMap.value[d])
  await Promise.all(newDates.map(d => fetchEccDutyForDate(d)))
}

const handleMoaVpnExport = async () => {
  if (!moaVpnDateRange.value || moaVpnDateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  try {
    const response = await exportMoaVpnRecord(moaVpnDateRange.value)
    const [startDate] = moaVpnDateRange.value
    const d = new Date(startDate)
    let filename = `${d.getFullYear()}年${d.getMonth() + 1}月RA及VPN权限使用记录.xlsx`
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '导出成功')
  } catch (e) { msg('error', e.message || '导出失败') }
}

const handleMergedExport = async () => {
  // 使用当前激活Tab的日期范围作为两个Tab的导出日期范围
  const activeDateRange = activeTab.value === 'moaVpn' ? moaVpnDateRange.value : eccContactDateRange.value
  if (!activeDateRange || activeDateRange.length !== 2) {
    msg('warning', '请先在当前Tab中选择日期范围')
    return
  }
  try {
    const response = await exportMergedRemoteRecord(activeDateRange, activeDateRange)
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    const [startDate] = moaVpnDateRange.value
    const d = new Date(startDate)
    link.setAttribute('download', `${d.getFullYear()}年${d.getMonth() + 1}月联系异常和远程权限使用记录表.xlsx`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '合并导出成功')
  } catch (e) { msg('error', e.message || '合并导出失败') }
}

// ==================== ECC联系异常情况 ====================
const eccContactDateRange = ref([lastWeek, today])
const eccContactTableData = ref([])
const eccContactSelectedRows = ref([])

// 当班人/二次联系人下拉数据源（系统运维 + 网络运维）
const opsPersonnelList = ref([])
const dutyPersonSearchKw = ref('')
const secondContactSearchKw = ref('')

const filteredDutyPersonList = computed(() => {
  const kw = dutyPersonSearchKw.value.trim().toLowerCase()
  if (!kw) return opsPersonnelList.value
  return opsPersonnelList.value.filter(p =>
    p.name.toLowerCase().includes(kw) || (p.userCode || '').toLowerCase().includes(kw)
  )
})
const filteredSecondContactList = computed(() => {
  const kw = secondContactSearchKw.value.trim().toLowerCase()
  if (!kw) return opsPersonnelList.value
  return opsPersonnelList.value.filter(p =>
    p.name.toLowerCase().includes(kw) || (p.userCode || '').toLowerCase().includes(kw)
  )
})
const onDutyPersonSelectVisibleChange = (v) => { if (!v) dutyPersonSearchKw.value = '' }
const onSecondContactSelectVisibleChange = (v) => { if (!v) secondContactSearchKw.value = '' }

const loadOpsPersonnelList = async () => {
  try {
    const [sysList, netList] = await Promise.all([getSys(), getNet()])
    const sysItems = (sysList || []).filter(p => p.status === 1).map(p => ({ name: p.name, userCode: p.userCode }))
    const netItems = (netList || []).filter(p => p.status === 1).map(p => ({ name: p.name, userCode: p.userCode }))
    const seen = new Set()
    const merged = []
    for (const item of [...sysItems, ...netItems]) {
      if (!seen.has(item.userCode)) {
        seen.add(item.userCode)
        merged.push(item)
      }
    }
    opsPersonnelList.value = merged
  } catch (e) { console.error('加载运维人员列表失败', e) }
}

// 监听数据变化，标记未保存状态（放在两个表数据都声明之后）
watch(moaVpnTableData, () => { if (!isLoadingData.value) moaVpnDirty.value = true }, { deep: true })
watch(eccContactTableData, () => { if (!isLoadingData.value) eccContactDirty.value = true }, { deep: true })

const eccContactTitle = computed(() => {
  if (!eccContactDateRange.value || eccContactDateRange.value.length !== 2) return 'ECC联系异常情况'
  const [start] = eccContactDateRange.value
  const d = new Date(start)
  return `${d.getFullYear()}年${d.getMonth() + 1}月ECC联系异常情况`
})

const handleEccContactSelectionChange = (rows) => { eccContactSelectedRows.value = rows }
const handleEccContactDateChange = () => { loadEccContactData() }
const handleEccContactClear = () => { eccContactDateRange.value = [lastWeek, today]; loadEccContactData() }

const handleEccContactAddRow = () => {
  eccContactTableData.value.push({
    _isNew: true,
    record_date: today,
    duty_person: '',
    second_contact: '',
    detail: '',
    is_callback: '',
    remark: '',
  })
  // 新增后跳转到最后一页
  const totalPages = Math.ceil(eccContactTableData.value.length / eccContactPageSize.value)
  eccContactPage.value = totalPages || 1
}

// ECC联系异常分页
const eccContactPage = ref(1)
const eccContactPageSize = ref(15)
const paginatedEccContactData = computed(() => {
  const start = (eccContactPage.value - 1) * eccContactPageSize.value
  return eccContactTableData.value.slice(start, start + eccContactPageSize.value)
})

watch(() => eccContactTableData.value, () => {
  // 跳到最后一页（数据追加在末尾）
  const totalPages = Math.ceil(eccContactTableData.value.length / eccContactPageSize.value)
  eccContactPage.value = totalPages || 1
})

const handleEccContactDeleteRow = async () => {
  if (eccContactSelectedRows.value.length === 0) {
    msg('warning', '请先选中要删除的行')
    return
  }
  try {
    await ElMessageBox.confirm(`确定要删除选中的 ${eccContactSelectedRows.value.length} 条记录吗？`, '删除确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'warning',
    })
  } catch { return }

  const newRows = eccContactSelectedRows.value.filter(r => r._isNew)
  const savedRows = eccContactSelectedRows.value.filter(r => !r._isNew && r.id)

  isLoadingData.value = true
  newRows.forEach(r => {
    const idx = eccContactTableData.value.indexOf(r)
    if (idx !== -1) eccContactTableData.value.splice(idx, 1)
  })

  for (const r of savedRows) {
    try {
      const res = await deleteEccContactException(r.id)
      if (res.status === 'success') {
        const idx = eccContactTableData.value.findIndex(item => item.id === r.id)
        if (idx !== -1) eccContactTableData.value.splice(idx, 1)
      } else {
        msg('error', res.message || '删除失败')
      }
    } catch (e) { msg('error', e.message || '删除失败') }
  }
  await nextTick()
  isLoadingData.value = false
  eccContactDirty.value = false
  msg('success', '删除完成')
}

const handleEccContactSave = async () => {
  const noDateRows = eccContactTableData.value.filter(r => !r.record_date)
  if (noDateRows.length > 0) {
    msg('warning', '存在未填写日期的行，请补充后再保存')
    return
  }
  try {
    await ElMessageBox.confirm('确定要保存当前数据吗？', '保存确认', {
      confirmButtonText: '确定', cancelButtonText: '取消', type: 'info',
    })
  } catch { return }

  const records = eccContactTableData.value.map(r => ({
    id: r._isNew ? null : r.id,
    record_date: r.record_date,
    duty_person: r.duty_person || '',
    duty_person_username: getOpsPersonUsername(r.duty_person),
    second_contact: r.second_contact || '',
    second_contact_username: getOpsPersonUsername(r.second_contact),
    detail: r.detail || '',
    is_callback: r.is_callback || '',
    remark: r.remark || '',
  }))

  try {
    const res = await saveEccContactException(records)
    if (res.status === 'success') {
      msg('success', '保存成功')
      eccContactDirty.value = false
      loadEccContactData()
    } else {
      msg('error', res.message || '保存失败')
    }
  } catch (e) { msg('error', e.message || '保存失败') }
}

const loadEccContactData = async () => {
  const _now = Date.now()
  if (_now - _lastLoadTime < 500) return
  _lastLoadTime = _now
  if (eccContactDirty.value) {
    try {
      await ElMessageBox.confirm('当前有未保存的修改，重新加载将丢失更改，是否继续？', '未保存提示', {
        confirmButtonText: '继续加载', cancelButtonText: '取消', type: 'warning',
      })
    } catch { return }
  }
  if (!eccContactDateRange.value || eccContactDateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  isLoadingData.value = true
  await nextTick()
  const loadStart = Date.now()
  // await new Promise(resolve => setTimeout(resolve, 1000))
  try {
    const res = await getEccContactException(eccContactDateRange.value)
    if (res.status === 'success' && res.data) {
      eccContactTableData.value = res.data.map(r => ({ ...r, _isNew: false }))
      await nextTick()
      eccContactDirty.value = false
    } else {
      eccContactTableData.value = []
      await nextTick()
      eccContactDirty.value = false
    }
  } catch (e) { msg('error', e.message || '加载数据失败') }
  const elapsed = Date.now() - loadStart
  if (elapsed < 200) await new Promise(r => setTimeout(r, 200 - elapsed))
  isLoadingData.value = false
  if (eccContactTableData.value.length > 0) {
    msg('success', `已加载 ${eccContactTableData.value.length} 条记录`)
  }
}

const handleEccContactExport = async () => {
  if (!eccContactDateRange.value || eccContactDateRange.value.length !== 2) {
    msg('warning', '请先选择日期范围')
    return
  }
  try {
    const response = await exportEccContactException(eccContactDateRange.value)
    const [startDate] = eccContactDateRange.value
    const d = new Date(startDate)
    let filename = `${d.getFullYear()}年${d.getMonth() + 1}月ECC联系异常情况.xlsx`
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    msg('success', '导出成功')
  } catch (e) { msg('error', e.message || '导出失败') }
}

// ==================== 标签页切换 ====================
const handleTabChange = () => {
  nextTick(() => { calcTableHeight() })
}

// ==================== 动态计算表格高度 ====================
let resizeObserver = null
const calcTableHeight = () => {
  const activeRef = activeTab.value === 'moaVpn' ? moaVpnTableRef.value : eccContactTableRef.value
  if (activeRef) {
    tableMaxHeight.value = activeRef.clientHeight
  }
}

onMounted(() => {
  loadMoaVpnData()
  loadEccContactData()
  loadUserList()
  loadPmList()
  loadOpsPersonnelList()
  window.addEventListener('beforeunload', handleBeforeUnload)
  nextTick(() => {
    calcTableHeight()
    const container = document.querySelector('.moa-vpn-ecc-container')
    if (container) {
      resizeObserver = new ResizeObserver(calcTableHeight)
      resizeObserver.observe(container)
    }
  })
})

onUnmounted(() => {
  if (resizeObserver) resizeObserver.disconnect()
  window.removeEventListener('beforeunload', handleBeforeUnload)
  ElMessage.closeAll()
})
</script>

<style scoped>
.moa-vpn-ecc-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  background-color: #fff;
  overflow: hidden;
  padding: 20px;
  box-sizing: border-box;
  user-select: none;
}

.main-tabs {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.main-tabs :deep(.el-tabs__header) {
  margin-bottom: 12px;
}

.main-tabs :deep(.el-tabs__content) {
  flex: 1;
  overflow: hidden;
}

.main-tabs :deep(.el-tab-pane) {
  height: 100%;
}

.tab-content {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.header-bar {
  text-align: center;
  margin-bottom: 12px;
  flex-shrink: 0;
}

.page-title {
  font-size: 18px;
  font-weight: bold;
  color: #303133;
}

/* 工具栏 */
.toolbar {
  display: flex;
  align-items: center;
  margin-bottom: 12px;
  flex-shrink: 0;
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 14px 18px;
  gap: 12px;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.toolbar-right {
  display: flex;
  align-items: center;
  flex: 1;
  gap: 8px;
  flex-shrink: 0;
  flex-wrap: wrap;
}

.toolbar-actions-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.toolbar-actions-right {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}

.filter-sep {
  width: 1px;
  height: 24px;
  background: #e2e8f0;
  flex-shrink: 0;
  margin: 0 4px;
}

.toolbar-filter {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.filter-label {
  font-size: 13px;
  color: #606266;
  white-space: nowrap;
}

/* 日期选择器 */
.moa-vpn-ecc-container :deep(.el-range-editor) {
  height: 28px !important;
  padding: 0 6px !important;
  border: 1.5px solid #c0c4cc !important;
  border-radius: 6px !important;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06) !important;
  max-width: 240px !important;
}

.moa-vpn-ecc-container :deep(.el-range-editor .el-range-separator) {
  padding: 0 2px !important;
  line-height: 24px !important;
  font-size: 12px !important;
  color: #909399 !important;
}

.moa-vpn-ecc-container :deep(.el-range-editor .el-range-input) {
  font-size: 12px !important;
}

/* 表格容器 */
.table-wrapper {
  flex: 1;
  overflow: hidden;
  min-height: 0;
  position: relative;
}

/* 分页栏：固定在底部，左右分离 */
.pagination-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
  padding: 8px 0 0 0;
  user-select: none;
}

.pagination-total {
  font-size: 13px;
  color: #606266;
  line-height: 24px;
}

/* 输入框样式 */
:deep(.el-input__wrapper) {
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 0 4px;
  transition: border-color 0.2s;
  justify-content: center;
}

:deep(.el-table__body tr:hover .el-input__wrapper) {
  border-color: var(--el-border-color) !important;
}

:deep(.el-input__wrapper.is-focus) {
  border-color: var(--el-color-primary) !important;
}

:deep(.el-input__inner) {
  text-align: center;
  padding: 4px 8px;
}

/* 多行文本框居中 */
:deep(.el-textarea__inner) {
  text-align: center;
  box-shadow: none !important;
  border: 1px solid transparent !important;
  background: transparent !important;
  padding: 4px 8px;
  resize: none;
}

:deep(.el-table__body tr:hover .el-textarea__inner) {
  border-color: var(--el-border-color) !important;
}

:deep(.el-textarea__inner:focus) {
  border-color: var(--el-color-primary) !important;
}

/* 下拉选择框 */
:deep(.el-select .el-select__wrapper) {
  border: 1px solid var(--el-border-color) !important;
  padding: 0 8px !important;
}

:deep(.el-select .el-select__input) {
  text-align: center !important;
  flex: 1;
  min-width: 0;
}

:deep(.el-select .el-select__suffix) {
  display: inline-flex !important;
  flex-shrink: 0;
}

:deep(.el-select .el-select__placeholder) {
  text-align: center !important;
}

:deep(.el-select .el-select__selected-item) {
  justify-content: center;
}

/* 下拉面板搜索框 - 仅对非teleport生效 */
:deep(.el-select .el-select-dropdown__header) {
  padding: 6px 8px 4px !important;
}

:deep(.el-select .el-select-dropdown__header .el-input__wrapper) {
  border: 1px solid var(--el-border-color) !important;
  box-shadow: none !important;
  background: #fff !important;
  justify-content: flex-start !important;
}

:deep(.el-select .el-select-dropdown__header .el-input__inner) {
  text-align: left !important;
}

/* 时间选择器 */
:deep(.el-time-picker .el-input__wrapper) {
  border: 1px solid var(--el-border-color) !important;
}

:deep(.el-date-editor .el-input__wrapper) {
  justify-content: center;
}

/* 隐藏日期/时间组件前缀图标 */
:deep(.el-date-editor .el-input__prefix),
:deep(.el-time-picker .el-input__prefix) {
  display: none !important;
}

/* 隐藏下拉框箭头图标（不影响清除按钮，两者共用 .el-select__caret 类） */
:deep(.el-select .el-select__caret:not(.el-select__clear)) {
  display: none !important;
}

/* 表格行hover */
:deep(.el-table__body tr:hover td) {
  background-color: #f0f7ff !important;
}

/* 滚动条 */
.table-wrapper :deep(.el-scrollbar__bar.is-horizontal) {
  height: 8px;
}
.table-wrapper :deep(.el-scrollbar__bar.is-vertical) {
  width: 8px;
}
.table-wrapper :deep(.el-scrollbar__thumb) {
  background-color: #c1c1c1 !important;
  border-radius: 4px !important;
}

/* 工具栏按钮 */
.toolbar-right .el-button {
  display: flex;
  align-items: center;
  gap: 4px;
}

/* Tab样式 */
:deep(.el-tabs__nav-wrap::after) {
  height: 1px;
}
:deep(.el-tabs__item) {
  font-size: 15px;
  font-weight: 600;
}
:deep(.el-tabs__item.is-active) {
  color: #409eff;
}
</style>

<style>
/* 全局样式：下拉弹出面板宽度控制（teleported内容不受scoped影响） */
.el-select-dropdown {
  max-width: 200px !important;
}

.el-select-dropdown__header {
  padding: 6px 8px 4px !important;
}

.el-select-dropdown__header .el-input__wrapper {
  border: 1px solid var(--el-border-color) !important;
  box-shadow: none !important;
  background: #fff !important;
  justify-content: flex-start !important;
}

.el-select-dropdown__header .el-input__inner {
  text-align: left !important;
}

.el-select-dropdown__item {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
