<template>
  <div class="week-manage-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">周管理</h2>
      <el-tag type="info" effect="light">自定义当前周的起止范围，适配节假日等特殊场景</el-tag>
    </div>

    <!-- 配置卡片 -->
    <el-card shadow="never" class="config-card">
      <template #header>
        <div class="card-header">
          <span class="section-title">
            <el-icon><Calendar /></el-icon>
            当前周配置
          </span>
          <span class="config-week-info">第 {{ currentWeek }} 周</span>
        </div>
      </template>

      <!-- 当前周 ISO 标准日期范围 -->
      <div class="info-row">
        <span class="info-label">ISO 标准范围</span>
        <span class="info-value">{{ isoDateLabel }}</span>
      </div>

      <el-divider />

      <!-- 自定义配置 -->
      <div class="config-form">
        <div class="form-row">
          <span class="form-label">起始日期</span>
          <el-date-picker
            v-model="startDate"
            type="date"
            placeholder="选择起始日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width: 200px;"
            :disabled-date="disableStartDate"
          />
        </div>
        <div class="form-row">
          <span class="form-label">截止日期</span>
          <el-date-picker
            v-model="endDate"
            type="date"
            placeholder="选择截止日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width: 200px;"
            :disabled-date="disableEndDate"
          />
        </div>
        <div class="form-row" v-if="hasCustomConfig">
          <span class="form-label">当前配置</span>
          <el-tag type="warning" effect="light">已自定义</el-tag>
        </div>
      </div>

      <el-divider />

      <!-- 操作按钮 -->
      <div class="form-actions">
        <el-button type="primary" @click="handleSave" :loading="saving">
          <el-icon><Check /></el-icon>
          &nbsp;保存配置
        </el-button>
        <el-button v-if="hasCustomConfig" @click="handleClear" :loading="clearing">
          <el-icon><Close /></el-icon>
          &nbsp;恢复默认
        </el-button>
      </div>
    </el-card>

    <!-- 说明卡片 -->
    <el-card shadow="never" class="info-card">
      <template #header>
        <span class="section-title">
          <el-icon><InfoFilled /></el-icon>
          说明
        </span>
      </template>
      <ul class="info-list">
        <li>ISO 标准：周一是包含当年1月4日的那一周的周一，周日为周一+6天。</li>
        <li>自定义起止范围<strong>仅对当前周（第{{ currentWeek }}周）生效</strong>，不影响历史周次。</li>
        <li>起始日期不能早于上周结束日期的次日，避免与上一周重叠。</li>
        <li>修改后，周报填写页、汇总页、导出页的日期标签将使用自定义范围。</li>
        <li>点击「恢复默认」可回到 ISO 标准计算。</li>
      </ul>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Calendar, Check, Close, InfoFilled } from '@element-plus/icons-vue'
import { getWeekConfig, saveWeekConfig, clearWeekConfig } from '@/api/weeklyReportApi'
import { getCurrentWeek, getWeekDateRange, fmtDateCN, fmtDateFull, setWeekConfig, clearWeekConfigMap } from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()

const startDate = ref('')
const endDate = ref('')
const hasCustomConfig = ref(false)
const saving = ref(false)
const clearing = ref(false)

// ISO 标准日期标签
const isoDateLabel = computed(() => {
  const { monday, sunday } = getWeekDateRange(currentYear, currentWeek)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)}`
})

// ISO 标准字符串，用于显示最小可选日期
const isoPrevWeekEnd = computed(() => {
  if (currentWeek <= 1) return null
  const { sunday } = getWeekDateRange(currentYear, currentWeek - 1)
  return sunday
})

// 计算本周第一天（周一）的ISO日期，用作起始日期默认禁用下限
const isoMonday = computed(() => {
  const { monday } = getWeekDateRange(currentYear, currentWeek)
  return monday
})

// 起始日期禁用范围：不能选早于上周日+1的日期
const disableStartDate = (date) => {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  // 不能早于上周日+1
  if (isoPrevWeekEnd.value) {
    const minStart = new Date(isoPrevWeekEnd.value)
    minStart.setDate(minStart.getDate() + 1)
    if (d < minStart) return true
  }
  // 不能晚于今日+2个月
  const maxEnd = new Date(today)
  maxEnd.setMonth(maxEnd.getMonth() + 2)
  return d > maxEnd
}

// 截止日期禁用范围：不能早于起始日期，不能晚于起始日期+60天
const disableEndDate = (date) => {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  if (startDate.value) {
    const s = new Date(startDate.value)
    s.setHours(0, 0, 0, 0)
    if (d <= s) return true
    const maxEnd = new Date(s)
    maxEnd.setDate(maxEnd.getDate() + 60)
    if (d > maxEnd) return true
  } else {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const maxEnd = new Date(today)
    maxEnd.setMonth(maxEnd.getMonth() + 2)
    if (d > maxEnd) return true
  }
  return false
}

// 加载配置
const loadConfig = async () => {
  try {
    const res = await getWeekConfig(currentWeek, currentYear)
    if (res.code === 200 && res.data) {
      startDate.value = res.data.startDate || ''
      endDate.value = res.data.endDate || ''
      hasCustomConfig.value = true
      if (startDate.value && endDate.value) {
        setWeekConfig(currentWeek, startDate.value, endDate.value)
      }
    } else {
      startDate.value = ''
      endDate.value = ''
      hasCustomConfig.value = false
    }
  } catch (e) {
    console.warn('加载周配置失败', e)
  }
}

// 保存配置
const handleSave = async () => {
  if (!startDate.value || !endDate.value) {
    msg('warning', '请选择起始日期和截止日期')
    return
  }
  if (endDate.value <= startDate.value) {
    msg('warning', '截止日期必须晚于起始日期')
    return
  }
  // 校验起始日期是否早于上周结束日期的次日
  if (isoPrevWeekEnd.value) {
    const minStart = new Date(isoPrevWeekEnd.value)
    minStart.setDate(minStart.getDate() + 1)
    const s = new Date(startDate.value)
    if (s < minStart) {
      msg('warning', `起始日期不能早于上周结束日期的次日（${fmtDateFull(minStart)}）`)
      return
    }
  }
  saving.value = true
  try {
    await ElMessageBox.confirm(
      `确认将第${currentWeek}周的周报范围设置为 ${startDate.value} 至 ${endDate.value}？`,
      '保存配置确认',
      { confirmButtonText: '确认保存', cancelButtonText: '取消', type: 'warning' }
    )
    const res = await saveWeekConfig(currentWeek, startDate.value, endDate.value)
    if (res.status === 'success') {
      hasCustomConfig.value = true
      setWeekConfig(currentWeek, startDate.value, endDate.value)
      msg('success', '周配置已保存')
    } else {
      msg('error', res.message || '保存失败')
    }
  } catch (e) {
    msg('error', e.message || '保存失败')
  } finally {
    saving.value = false
  }
}

// 清除配置
const handleClear = async () => {
  try {
    await ElMessageBox.confirm(
      '确认清除当前周的自定义配置，恢复 ISO 标准计算？',
      '恢复默认确认',
      { confirmButtonText: '确认恢复', cancelButtonText: '取消', type: 'warning' }
    )
  } catch { return }
  clearing.value = true
  try {
    const res = await clearWeekConfig(currentWeek)
    if (res.status === 'success') {
      startDate.value = ''
      endDate.value = ''
      hasCustomConfig.value = false
      clearWeekConfigMap(currentWeek)
      msg('success', '已恢复 ISO 标准计算')
    } else {
      msg('error', res.message || '清除失败')
    }
  } catch (e) {
    msg('error', e.message || '清除失败')
  } finally {
    clearing.value = false
  }
}

onMounted(() => {
  loadConfig()
})
</script>

<style scoped>
.week-manage-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header {
  margin-bottom: 16px; flex-shrink: 0;
  display: flex; align-items: center; gap: 12px;
}
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

.config-card { flex-shrink: 0; margin-bottom: 16px; }
.config-card :deep(.el-card__body) { padding: 20px; }
.card-header {
  display: flex; justify-content: space-between; align-items: center;
}
.section-title { display: flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 600; color: #303133; }
.config-week-info { font-size: 13px; color: #909399; }

.info-row { display: flex; align-items: center; gap: 12px; padding: 4px 0; }
.info-label { font-size: 13px; color: #909399; min-width: 120px; }
.info-value { font-size: 14px; color: #303133; font-weight: 500; }

.config-form { display: flex; flex-direction: column; gap: 12px; }
.form-row { display: flex; align-items: center; gap: 12px; }
.form-label { font-size: 13px; color: #909399; min-width: 120px; }
.form-value { font-size: 14px; color: #303133; font-weight: 500; }

.form-actions { display: flex; gap: 10px; }

.info-card { flex-shrink: 0; }
.info-card :deep(.el-card__body) { padding: 16px 20px; }
.info-list {
  margin: 0; padding-left: 20px; font-size: 13px; color: #606266; line-height: 2;
}
.info-list li { margin-bottom: 2px; }
</style>
