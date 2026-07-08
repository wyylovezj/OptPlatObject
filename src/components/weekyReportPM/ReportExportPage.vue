<template>
  <div class="report-export-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">周报导出</h2>
    </div>

    <!-- 导出筛选 -->
    <div class="filter-bar">
      <div class="filter-group">
        <span class="filter-label">周次</span>
        <el-select v-model="exportWeek" size="default" style="width: 280px;" @change="updatePreview">
          <el-option
            v-for="opt in weekOptions"
            :key="opt.value"
            :label="opt.label"
            :value="opt.value"
          />
        </el-select>
      </div>
      <div class="filter-group">
        <span class="filter-label">模块</span>
        <el-select v-model="exportModule" size="default" style="width: 120px;" @change="updatePreview">
          <el-option label="全部模块" value="all" />
          <el-option
            v-for="mod in activeModules"
            :key="mod.id"
            :label="mod.name"
            :value="mod.id"
          />
        </el-select>
      </div>
<!--      <div class="filter-group">-->
<!--        <span class="filter-label">人员</span>-->
<!--        <el-select v-model="exportPerson" size="default" style="width: 120px;" @change="updatePreview">-->
<!--          <el-option label="全部人员" value="all" />-->
<!--          <el-option-->
<!--            v-for="p in personOptions"-->
<!--            :key="p.id"-->
<!--            :label="p.name"-->
<!--            :value="p.id"-->
<!--          />-->
<!--        </el-select>-->
<!--      </div>-->
    </div>

    <!-- 导出格式与操作 -->
    <div class="export-actions">
      <span class="format-label">导出格式：</span>
      <el-button size="small" class="export-btn btn-markdown" @click="handleExportMarkdown">
        <svg class="export-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" fill="#4A90D9" stroke="#4A90D9" stroke-width="1.5"/>
          <path d="M7 10v7h2v-4l2 3 2-3v4h2v-7h-2l-2 3-2-3H7z" fill="#fff"/>
          <rect x="7" y="7" width="10" height="1.5" rx="0.75" fill="#4A90D9"/>
        </svg>
        &nbsp;导出 Markdown
      </el-button>
      <el-button size="small" class="export-btn btn-html" @click="handleExportHTML">
        <svg class="export-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" fill="#E67E22" stroke="#E67E22" stroke-width="1.5"/>
          <path d="M8.5 9l-2.5 3 2.5 3" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M15.5 9l2.5 3-2.5 3" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M13 8l-2 8" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/>
        </svg>
        &nbsp;导出 HTML
      </el-button>
    </div>

    <!-- 预览区 -->
    <el-card shadow="never" class="preview-card">
      <template #header>
        <div class="preview-header">
          <span class="section-title">
            <el-icon><View /></el-icon>
            导出预览
          </span>
          <span class="preview-hint">按模块分类展示，每条内容子行独立编号，不含人员姓名</span>
        </div>
      </template>

      <el-scrollbar class="preview-scrollbar">
        <div class="export-preview">
          <div class="ep-title">运维周报</div>
          <div class="ep-subtitle">报告周期：{{ weekDateLabel }}（第{{ exportWeek }}周）</div>
          <el-divider />

          <template v-if="previewModules.length > 0">
            <template v-for="group in previewModules" :key="group.moduleId">
              <div class="ep-module">{{ group.name }}</div>
              <div v-for="(item, idx) in group.items" :key="idx" class="ep-item">
                {{ idx + 1 }}. {{ item }}
              </div>
              <el-divider />
            </template>
          </template>

          <div v-else class="ep-empty">该条件下暂无已提交的周报数据</div>
        </div>
      </el-scrollbar>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { View } from '@element-plus/icons-vue'
import { getReportModules, getSummaryReports, getWeekConfig } from '@/api/weeklyReportApi'
import { reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN, setWeekConfig } from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()

// 筛选
const exportWeek = ref(currentWeek)
const exportModule = ref('all')
const exportPerson = ref('all')

// 数据
const summaryData = ref(null)
const personOptions = ref([])

// 周次选项
const weekOptions = computed(() => {
  const opts = []
  for (let w = currentWeek; w >= Math.max(1, currentWeek - 4); w--) {
    const { monday, sunday } = getWeekDateRange(currentYear, w)
    opts.push({
      value: w,
      label: `${currentYear}年 第${w}周 (${fmtDateCN(monday)} ~ ${fmtDateCN(sunday)})`
    })
  }
  return opts
})

// 激活的模块
const activeModules = computed(() => reportModules.value.filter(m => m.active))

// 周日期标签
const weekDateLabel = computed(() => {
  const { monday, sunday } = getWeekDateRange(currentYear, exportWeek.value)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)}`
})

// 将内容解析为文本行数组（JSON 数组每个元素为一行，纯文本整段视为一行）
const extractContentLines = (content) => {
  if (!content || !content.trim()) return []
  try {
    const parsed = JSON.parse(content)
    if (Array.isArray(parsed)) {
      return parsed.filter(l => l && l.text).map(l => l.text.trim()).filter(Boolean)
    }
  } catch { /* 非 JSON，按纯文本处理 */ }
  return [content.trim()]
}

// 预览模块列表（将每条周报内容拆分为独立行，按顺序编号）
const previewModules = computed(() => {
  if (!summaryData.value || !summaryData.value.moduleGroups) return []
  let groups = summaryData.value.moduleGroups

  // 模块筛选
  if (exportModule.value !== 'all') {
    groups = groups.filter(g => g.moduleId === exportModule.value)
  }

  // 人员筛选
  if (exportPerson.value !== 'all') {
    groups = groups.map(g => ({
      ...g,
      entries: g.entries.filter(e => e.engineerId === exportPerson.value)
    }))
  }

  // 过滤空组，并将每条内容的子行展开为独立序号项
  return groups.filter(g => g.entries && g.entries.length > 0).map(g => {
    const lines = []
    for (const entry of g.entries) {
      lines.push(...extractContentLines(entry.content))
    }
    return {
      moduleId: g.moduleId,
      name: reportModules.value.find(m => m.id === g.moduleId)?.name || '未知模块',
      items: lines
    }
  })
})

// 更新预览
const updatePreview = async () => {
  try {
    summaryData.value = await getSummaryReports(exportWeek.value)
  } catch (e) {
    console.warn('加载汇总数据失败', e)
    summaryData.value = null
  }
}

// 下载辅助
const downloadBlob = (blob, filename) => {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

// 导出 Markdown
const handleExportMarkdown = () => {
  const lines = []
  lines.push(`# 运维周报`)
  lines.push(`> 报告周期：${weekDateLabel.value}（第${exportWeek.value}周）`)
  lines.push('')
  previewModules.value.forEach(g => {
    lines.push(`## ${g.name}`)
    g.items.forEach((item, idx) => {
      lines.push(`${idx + 1}. ${item}`)
    })
    lines.push('')
  })
  const text = lines.join('\n')
  const blob = new Blob([text], { type: 'text/markdown;charset=utf-8;' })
  downloadBlob(blob, `运维周报_第${exportWeek.value}周.md`)
  msg('success', 'Markdown 文件已下载')
}

// 导出 HTML
const handleExportHTML = () => {
  let html = `<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><title>运维周报 - 第${exportWeek.value}周</title>`
  html += `<style>body{font-family:"PingFang SC","Microsoft YaHei",sans-serif;max-width:800px;margin:40px auto;padding:20px;color:#1a1a1a;line-height:1.8;}`
  html += `.title{font-size:22px;font-weight:700;margin-bottom:4px;}`
  html += `.subtitle{font-size:14px;color:#666;margin-bottom:16px;}`
  html += `.module{font-size:16px;font-weight:700;color:#2563eb;margin:20px 0 8px;padding-bottom:4px;border-bottom:2px solid #bfdbfe;}`
  html += `.item{margin:4px 0 4px 16px;white-space:pre-wrap;word-break:break-all;}.divider{height:1px;background:#e2e8f0;margin:12px 0;}</style></head><body>`
  html += `<div class="title">运维周报</div>`
  html += `<div class="subtitle">报告周期：${weekDateLabel.value}（第${exportWeek.value}周）</div>`
  html += `<div class="divider"></div>`
  previewModules.value.forEach(g => {
    html += `<div class="module">${g.name}</div>`
    g.items.forEach((item, idx) => {
      html += `<div class="item">${idx + 1}. ${item.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>`
    })
    html += `<div class="divider"></div>`
  })
  html += `</body></html>`
  const blob = new Blob([html], { type: 'text/html;charset=utf-8;' })
  downloadBlob(blob, `运维周报_第${exportWeek.value}周.html`)
  msg('success', 'HTML 文件已下载')
}

onMounted(async () => {
  if (reportModules.value.length === 0) {
    try { reportModules.value = await getReportModules() } catch (e) { console.warn('加载模块列表失败', e) }
  }
  // 加载各周次的自定义配置
  try {
    for (let w = currentWeek; w >= Math.max(1, currentWeek - 4); w--) {
      const res = await getWeekConfig(w)
      if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) {
        setWeekConfig(w, res.data.startDate, res.data.endDate)
      }
    }
  } catch (e) { /* 静默处理 */ }
  updatePreview()
})
</script>

<style scoped>
.report-export-container {
  width: 100%; height: 100%; display: flex; flex-direction: column;
  background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box;
}
.page-header { margin-bottom: 12px; flex-shrink: 0; }
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }

/* 筛选栏 */
.filter-bar {
  background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed;
  display: flex; align-items: center; gap: 20px; flex-wrap: wrap; flex-shrink: 0; margin-bottom: 14px;
}
.filter-group { display: flex; align-items: center; gap: 8px; }
.filter-label { font-size: 13px; color: #909399; white-space: nowrap; }

/* 导出操作 */
.export-actions {
  display: flex; align-items: center; gap: 10px; margin-bottom: 14px; flex-shrink: 0;
}
.format-label { font-size: 13px; color: #909399; }

/* 彩色导出按钮 */
.export-btn {
  border: none !important;
  color: #fff !important;
  font-weight: 600;
  transition: all 0.25s ease;
}
.export-btn:hover {
  opacity: 0.85;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
.export-btn:active {
  transform: translateY(0);
}
.export-btn .export-icon {
  vertical-align: middle;
  flex-shrink: 0;
}
.btn-markdown {
  background: linear-gradient(135deg, #4A90D9, #357ABD) !important;
}
.btn-html {
  background: linear-gradient(135deg, #E67E22, #D35400) !important;
}

/* 预览区 */
.preview-card { flex: 1; display: flex; flex-direction: column; min-height: 0; }
.preview-card :deep(.el-card__body) {
  flex: 1; display: flex; flex-direction: column; min-height: 0; overflow: hidden;
}
.preview-scrollbar {
  flex: 1; min-height: 0;
}
.preview-header { display: flex; justify-content: space-between; align-items: center; }
.section-title { display: flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 600; color: #303133; }
.preview-hint { font-size: 12px; color: #909399; }

.export-preview {
  font-family: "PingFang SC", "Microsoft YaHei", -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 14px;
  line-height: 1.8;
  color: #303133;
  padding: 12px 16px;
  background: #fafafa;
  border-radius: 6px;
}
.ep-title { font-size: 18px; font-weight: 700; color: #1a1a1a; font-family: inherit; }
.ep-subtitle { font-size: 13px; color: #909399; margin-bottom: 16px; font-family: inherit; }
.ep-module {
  font-size: 15px; font-weight: 700; color: #2563eb;
  margin: 16px 0 8px; padding-bottom: 4px;
  border-bottom: 2px solid #bfdbfe; font-family: inherit;
}
.ep-item {
  margin: 3px 0 3px 20px;
  font-family: inherit;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-all;
}
.ep-empty {
  text-align: center;
  padding: 40px 20px;
  color: #e6a23c;
  font-size: 14px;
  font-weight: 500;
}
</style>
