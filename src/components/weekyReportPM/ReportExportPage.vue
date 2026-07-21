<template>
  <div class="report-export-container">
    <div class="page-header">
      <h2 class="page-title">周报导出</h2>
    </div>
    <div class="filter-bar">
      <div class="filter-group">
        <span class="filter-label">周次</span>
        <el-select v-model="exportWeek" size="default" style="width: 350px;" popper-class="report-export-week-popper" @change="updatePreview">
          <el-option v-for="opt in weekOptions" :key="opt.value" :label="opt.label" :value="opt.value" :disabled="opt.disabled" :class="opt.isHoliday ? 'holiday-week-option' : ''" />
        </el-select>
      </div>
    </div>
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
      <el-button size="small" class="export-btn btn-docx" @click="handleExportDocx">
        <svg class="export-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="4" y="4" width="16" height="16" rx="4" fill="#2B579A" stroke="#2B579A" stroke-width="1.5"/>
          <path d="M7.5 9L9 16L11 11.5L13 16L14.5 9" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
        </svg>
        &nbsp;导出 DOCX
      </el-button>
    </div>

    <div class="doc-layout">
      <el-scrollbar class="doc-toc">
        <div class="toc-title">目 录</div>
        <div v-for="(sec, si) in exportSections" :key="'toc-p'+si" class="toc-block">
          <div class="toc-parent" :class="{ active: activeSectionKey === 'p'+si }" @click="scrollTo('p'+si)">
            {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
          </div>
          <div v-for="(sub, sj) in sec.subs" :key="'toc-s'+si+'-'+sj"
               class="toc-child" :class="{ active: activeSectionKey === 's'+si+'-'+sj }"
               @click="scrollTo('s'+si+'-'+sj)">
            （{{ chineseNum(sj + 1) }}）{{ sub.subName }}
          </div>
        </div>
      </el-scrollbar>

      <div class="doc-body">
        <el-scrollbar ref="docPagesScrollbar" class="doc-pages" view-class="doc-pages-view" @scroll="onDocScroll">
          <div v-for="(sec, si) in exportSections" :key="'sec'+si"
               :ref="el => { registerSection('p'+si, el) }" class="doc-section">

            <!-- ===== 无子模块的父模块 ===== -->
            <template v-if="!sec.hasSubModules">
              <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
              </h2>

              <div class="doc-parent-content" v-if="sec.hasParentRecord">
                <template v-if="sec.parentEntries && sec.parentEntries.some(e => parseLines(e.content).length > 0)">
                  <div class="doc-viewer">
                    <div v-for="(line, li) in getMergedLines(sec.parentEntries)" :key="'pml-'+si+'-'+li" class="content-line is-idle">
                      <div class="line-content">
                        <span class="line-text">{{ line.text }}</span>
                      </div>

                    </div>
                  </div>
                </template>
                <span v-else-if="sec.parentEntries && sec.parentEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
              </div>

              <div class="doc-sub-section">
                <template v-if="sec.entries && sec.entries.length > 0">
                  <template v-if="sec.entries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sec.entries)" :key="'ml-'+si+'-'+li" class="content-line is-idle">
                        <div class="line-content">
                          <span class="line-num" v-if="getMergedLines(sec.entries).length > 1">({{ li + 1 }})</span>
                          <span class="line-text">{{ line.text }}</span>
                        </div>

                      </div>
                    </div>
                  </template>
                  <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                </template>
                <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂无</span>
              </div>
            </template>

            <!-- ===== 有子模块的父模块 ===== -->
            <template v-else>
              <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
              </h2>

              <div class="doc-parent-content" v-if="sec.hasParentRecord">
                <template v-if="sec.parentEntries && sec.parentEntries.some(e => parseLines(e.content).length > 0)">
                  <div class="doc-viewer">
                    <div v-for="(line, li) in getMergedLines(sec.parentEntries)" :key="'pml-'+si+'-'+li" class="content-line is-idle">
                      <div class="line-content">
                        <span class="line-text">{{ line.text }}</span>
                      </div>

                    </div>
                  </div>
                </template>
                <span v-else-if="sec.parentEntries && sec.parentEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
              </div>

              <!-- 子模块 -->
              <div v-for="(sub, sj) in sec.subs" :key="'sub'+si+'-'+sj"
                   :ref="el => { registerSection('s'+si+'-'+sj, el) }" class="doc-sub-section">
                <div class="doc-sub-header">
                  <h3 class="doc-h3" :class="{ 'no-record': !sub.hasRecord }">（{{ chineseNum(sj + 1) }}）{{ sub.subName }}</h3>
                </div>

                <div class="doc-parent-content" v-if="sub.hasSummaryRecord">
                  <template v-if="sub.summaryEntries && sub.summaryEntries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sub.summaryEntries)" :key="'sms-'+si+'-'+sj+'-'+li" class="content-line is-idle">
                        <div class="line-content">
                          <span class="line-text">{{ line.text }}</span>
                        </div>

                      </div>
                    </div>
                  </template>
                  <span v-else-if="sub.summaryEntries && sub.summaryEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                </div>

                <div class="doc-sub-section">
                  <template v-if="sub.entries && sub.entries.length > 0">
                    <template v-if="sub.entries.some(e => parseLines(e.content).length > 0)">
                      <div class="doc-viewer">
                        <div v-for="(line, li) in getMergedLines(sub.entries)" :key="'ml-'+si+'-'+sj+'-'+li" class="content-line is-idle">
                          <div class="line-content">
                            <span class="line-num" v-if="getMergedLines(sub.entries).length > 1">({{ li + 1 }})</span>
                            <span class="line-text">{{ line.text }}</span>
                          </div>

                        </div>
                      </div>
                    </template>
                    <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                  </template>
                  <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂无</span>
                </div>
              </div>
            </template>
          </div>
        </el-scrollbar>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getReportModules, getSummaryReports, getWeekConfig, exportReportDocx } from '@/api/weeklyReportApi'
import { reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN, setWeekConfig, fetchWeekDateRanges, weekDateRangesMap, weekDateRangesLoaded, weekConfigMap } from '@/utils/weeklyReportData'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()
const exportWeek = ref(currentWeek)
const exportModule = ref('all')
const summaryData = ref(null)

const activeSectionKey = ref('')
const docPagesScrollbar = ref(null)
const sectionRefs = {}
const registerSection = (key, el) => { if (el) sectionRefs[key] = el }
const scrollTo = (key) => {
  const el = sectionRefs[key]
  if (!el) return
  const container = docPagesScrollbar.value?.$el?.querySelector('.el-scrollbar__wrap')
  if (container) {
    const containerRect = container.getBoundingClientRect()
    const elRect = el.getBoundingClientRect()
    container.scrollTop = container.scrollTop + (elRect.top - containerRect.top) - 60
  }
  activeSectionKey.value = key
}
const onDocScroll = () => {
  const container = docPagesScrollbar.value?.$el?.querySelector('.el-scrollbar__wrap')
  if (!container) return
  const { scrollTop } = container
  const containerRect = container.getBoundingClientRect()
  // 找到最接近视口顶部的 section（向上找最近的）
  let bestKey = ''
  let bestDiff = Infinity
  for (const [key, el] of Object.entries(sectionRefs)) {
    if (!el) continue
    const elRect = el.getBoundingClientRect()
    // 跳过没有实际高度的元素（如空内容被 v-if 隐藏的）
    if (elRect.height === 0 && elRect.width === 0) continue
    const offset = elRect.top - containerRect.top + scrollTop
    const diff = scrollTop + 60 - offset
    if (diff >= 0 && diff < bestDiff) {
      bestDiff = diff
      bestKey = key
    }
  }
  if (bestKey) activeSectionKey.value = bestKey
}

const weekOptions = computed(() => {
  const opts = []
  for (let w = currentWeek; w >= 1; w--) {
    const { monday, sunday } = getWeekDateRange(currentYear, w)
    const isHoliday = weekDateRangesLoaded.value && !weekDateRangesMap.value[w] && !weekConfigMap.value[w]
    opts.push({
      value: w,
      label: `${currentYear}年 第${w}周 (${fmtDateCN(monday)} ~ ${fmtDateCN(sunday)})${isHoliday ? ' (全周假期)' : ''}`,
      disabled: false,
      isHoliday
    })
  }
  return opts
})

const activeModules = computed(() => reportModules.value.filter(m => m.active))

const weekDateLabel = computed(() => {
  const { monday, sunday } = getWeekDateRange(currentYear, exportWeek.value)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)}`
})

const moduleColor = (id) => reportModules.value.find(m => m.id === id)?.color || '#2563eb'

const chineseNum = (n) => {
  const map = ['零','一','二','三','四','五','六','七','八','九','十','十一','十二','十三','十四','十五','十六','十七','十八','十九','二十']
  return (n >= 0 && n < map.length) ? map[n] : String(n)
}

// 解析内容行（与汇总页完全一致）
const parseLines = (content) => {
  if (!content || !content.trim()) return []
  try {
    const parsed = JSON.parse(content)
    if (Array.isArray(parsed)) return parsed.filter(l => l && l.text !== undefined)
  } catch { /* 非 JSON */ }
  return content.split('\n').filter(t => t.trim()).map(t => ({ text: t, updatedBy: '', updatedAt: '' }))
}

// 合并多人提交内容行（与汇总页一致）
const getMergedLines = (entries) => {
  if (!entries || entries.length === 0) return []
  const lines = []
  const sorted = [...entries].sort((a, b) => (a.submitTime || '').localeCompare(b.submitTime || ''))
  sorted.forEach(entry => {
    const parsed = parseLines(entry.content)
    if (parsed.length === 0) return
    parsed.forEach(cl => {
      const displayName = (cl.updatedBy && cl.updatedBy.trim()) ? cl.updatedBy : (entry.name || '')
      lines.push({ text: cl.text, name: displayName, updatedAt: cl.updatedAt || entry.submitTime || '', sortOrder: cl.sortOrder ?? Infinity })
    })
  })
  lines.sort((a, b) => (a.sortOrder ?? Infinity) - (b.sortOrder ?? Infinity))
  return lines
}

// 导出用 sections（与汇总页 summarySections 结构一致）
const exportSections = computed(() => {
  const dataGroups = summaryData.value?.moduleGroups || []
  return dataGroups
    .filter(g => exportModule.value === 'all' || g.moduleId === exportModule.value)
    .map(g => {
      const color = moduleColor(g.moduleId)
      const seenSubIds = new Set()
      const realSubGroups = (g.subGroups || []).filter(sg => {
        if (!sg.subModuleId || seenSubIds.has(sg.subModuleId)) return false
        seenSubIds.add(sg.subModuleId)
        return true
      })
      const orphanEntries = (g.subGroups || []).filter(sg => !sg.subModuleId).flatMap(sg => sg.entries || [])
      const allEntries = [...(g.entries || []), ...orphanEntries]
      const seenIds = new Set()
      const merged = allEntries.filter(e => { if (seenIds.has(e.reportId)) return false; seenIds.add(e.reportId); return true })
      const sortFn = (arr) => [...arr].sort((a, b) => (a.submitTime || '').localeCompare(b.submitTime || ''))

      if (realSubGroups.length > 0) {
        const parentEntries = (g.entries || []).filter(e => !e.subModuleId)
        const subs = realSubGroups.map(sg => ({
          subName: sg.subModuleName,
          hasRecord: (sg.summaryEntries || []).some(e => parseLines(e.content).length > 0) ||
                     (sg.entries || []).some(e => parseLines(e.content).length > 0),
          hasSummaryRecord: (sg.summaryEntries || []).some(e => parseLines(e.content).length > 0),
          summaryEntries: sg.summaryEntries || [],
          entries: sortFn(sg.entries || [])
        }))
        return {
          moduleId: g.moduleId, moduleName: g.name, moduleColor: color,
          hasSubModules: true,
          hasRecord: parentEntries.some(e => parseLines(e.content).length > 0) || subs.some(s => s.hasRecord),
          hasParentRecord: parentEntries.some(e => parseLines(e.content).length > 0),
          parentEntries: sortFn(parentEntries),
          subs
        }
      } else {
        const parentEntries = merged.filter(e => e.isSummary)
        const detailEntries = merged.filter(e => !e.isSummary)
        return {
          moduleId: g.moduleId, moduleName: g.name, moduleColor: color,
          hasSubModules: false,
          hasRecord: merged.some(e => parseLines(e.content).length > 0),
          hasParentRecord: parentEntries.some(e => parseLines(e.content).length > 0),
          parentEntries: sortFn(parentEntries),
          entries: sortFn(detailEntries),
          subs: []
        }
      }
    })
})

const updatePreview = async () => {
  try {
    summaryData.value = await getSummaryReports(exportWeek.value)
  } catch (e) {
    console.warn('加载汇总数据失败', e)
    summaryData.value = null
  }
}

const downloadBlob = (blob, filename) => {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename
  document.body.appendChild(a); a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

const handleExportMarkdown = () => {
  const lines = []
  lines.push(`# 运维周报`)
  lines.push(`> 报告周期：${weekDateLabel.value}（第${exportWeek.value}周）`)
  lines.push('')
  exportSections.value.forEach((sec, si) => {
    lines.push(`## ${chineseNum(si + 1)}、${sec.moduleName}`)
    if (sec.hasParentRecord && sec.parentEntries.some(e => parseLines(e.content).length > 0)) {
      getMergedLines(sec.parentEntries).forEach(l => lines.push(`- ${l.text}`))
    }
    if (sec.hasSubModules) {
      sec.subs.forEach((sub, sj) => {
        lines.push(`### ${sj + 1}、${sub.subName}`)
        let hasSubContent = false
        if (sub.hasSummaryRecord && sub.summaryEntries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sub.summaryEntries).forEach(l => lines.push(`- ${l.text}`))
          hasSubContent = true
        }
        if (sub.entries && sub.entries.length > 0 && sub.entries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sub.entries).forEach((l, idx) => lines.push(`${idx + 1}. ${l.text}`))
          hasSubContent = true
        }
        if (!hasSubContent) {
          lines.push(`  暂无`)
        }
      })
    } else {
      if (!(sec.hasParentRecord && sec.parentEntries.some(e => parseLines(e.content).length > 0)) &&
          !(sec.entries && sec.entries.length > 0 && sec.entries.some(e => parseLines(e.content).length > 0))) {
        lines.push(`  暂无`)
      } else {
        if (sec.entries && sec.entries.length > 0 && sec.entries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sec.entries).forEach((l, idx) => lines.push(`${idx + 1}. ${l.text}`))
        }
      }
    }
    lines.push('')
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/markdown;charset=utf-8;' })
  downloadBlob(blob, `运维周报_第${exportWeek.value}周.md`)
  msg('success', 'Markdown 文件已下载')
}

const handleExportHTML = () => {
  let html = `<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><title>运维周报 - 第${exportWeek.value}周</title>`
  html += `<style>body{font-family:"PingFang SC","Microsoft YaHei",sans-serif;max-width:800px;margin:40px auto;padding:20px;color:#1a1a1a;line-height:1.8;}`
  html += `.title{font-size:22px;font-weight:700;margin-bottom:4px;}.subtitle{font-size:14px;color:#666;margin-bottom:16px;}`
  html += `.module{font-size:16px;font-weight:700;color:#2563eb;margin:20px 0 8px;padding-bottom:4px;border-bottom:2px solid #bfdbfe;}`
  html += `.sub-module{font-size:14px;font-weight:600;color:#409eff;margin:8px 0 4px 16px;}`
  html += `.summary-item{margin:4px 0 4px 16px;padding-left:4px;border-left:2px solid #e2e8f0;white-space:pre-wrap;word-break:break-all;color:#555;}`
  html += `.item{margin:4px 0 4px 16px;white-space:pre-wrap;word-break:break-all;}.empty-hint{margin:4px 0 4px 16px;color:#999;font-style:italic;}.divider{height:1px;background:#e2e8f0;margin:12px 0;}</style></head><body>`
  html += `<div class="title">运维周报</div>`
  html += `<div class="subtitle">报告周期：${weekDateLabel.value}（第${exportWeek.value}周）</div><div class="divider"></div>`
  exportSections.value.forEach((sec, si) => {
    html += `<div class="module">${chineseNum(si + 1)}、${sec.moduleName}</div>`
    if (sec.hasParentRecord && sec.parentEntries.some(e => parseLines(e.content).length > 0)) {
      getMergedLines(sec.parentEntries).forEach(l => html += `<div class="summary-item">${l.text.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>`)
    }
    if (sec.hasSubModules) {
      sec.subs.forEach((sub, sj) => {
        html += `<div class="sub-module">${sj + 1}、${sub.subName}</div>`
        let hasSubContent = false
        if (sub.hasSummaryRecord && sub.summaryEntries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sub.summaryEntries).forEach(l => html += `<div class="summary-item">${l.text.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>`)
          hasSubContent = true
        }
        if (sub.entries && sub.entries.length > 0 && sub.entries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sub.entries).forEach((l, idx) => html += `<div class="item">${idx + 1}. ${l.text.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>`)
          hasSubContent = true
        }
        if (!hasSubContent) {
          html += `<div class="empty-hint">暂无</div>`
        }
      })
    } else {
      if (!(sec.hasParentRecord && sec.parentEntries.some(e => parseLines(e.content).length > 0)) &&
          !(sec.entries && sec.entries.length > 0 && sec.entries.some(e => parseLines(e.content).length > 0))) {
        html += `<div class="empty-hint">暂无</div>`
      } else {
        if (sec.entries && sec.entries.length > 0 && sec.entries.some(e => parseLines(e.content).length > 0)) {
          getMergedLines(sec.entries).forEach((l, idx) => html += `<div class="item">${idx + 1}. ${l.text.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>`)
        }
      }
    }
    html += `<div class="divider"></div>`
  })
  html += `</body></html>`
  downloadBlob(new Blob([html], { type: 'text/html;charset=utf-8;' }), `运维周报_第${exportWeek.value}周.html`)
  msg('success', 'HTML 文件已下载')
}

const handleExportDocx = async () => {
  try {
    const res = await exportReportDocx(exportWeek.value)
    const { monday, sunday } = getWeekDateRange(currentYear, exportWeek.value)
    const fmtYMD = (d) => `${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}${String(d.getDate()).padStart(2,'0')}`
    let filename = `\u8fd0\u7ef4\u4e2d\u5fc3\u5de5\u4f5c\u5468\u62a5\uff08${fmtYMD(monday)}-${fmtYMD(sunday)}\uff09.docx`
    const disposition = res.headers['content-disposition']
    if (disposition) {
      // 优先使用 filename*=UTF-8'' 格式（支持中文），否则回退到 filename= 并去除引号
      const starMatch = disposition.match(/filename\*=(?:UTF-8'')?([^;\s]+)/i)
      if (starMatch) {
        filename = decodeURIComponent(starMatch[1])
      } else {
        const plainMatch = disposition.match(/filename=(?:([^;\s]+))/i)
        if (plainMatch) filename = plainMatch[1].replace(/^"|"$/g, '')
      }
    }
    downloadBlob(res.data, filename)
    msg('success', 'DOCX \u6587\u4ef6\u5df2\u4e0b\u8f7d')
  } catch (e) {
    msg('error', e.message || '\u5bfc\u51fa DOCX \u5931\u8d25')
  }
}

onMounted(async () => {
  await fetchWeekDateRanges(currentYear)
  if (reportModules.value.length === 0) {
    try { reportModules.value = await getReportModules() } catch (e) { console.warn('加载模块列表失败', e) }
  }
  try {
    for (let w = currentWeek; w >= Math.max(1, currentWeek - 4); w--) {
      const res = await getWeekConfig(w)
      if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) {
        setWeekConfig(w, res.data.startDate, res.data.endDate)
      }
    }
  } catch (e) { /* 静默处理 */ }
  await updatePreview()
  // 默认选中第一个目录项
  nextTick(() => { if (exportSections.value.length > 0) activeSectionKey.value = 'p0' })
})

// 左侧目录自动滚动，保持选中项可见
watch(activeSectionKey, (key) => {
  if (!key) return
  nextTick(() => {
    const tocWrap = document.querySelector('.doc-toc .el-scrollbar__wrap')
    if (!tocWrap) return
    const activeEl = tocWrap.querySelector('.toc-parent.active') || tocWrap.querySelector('.toc-child.active')
    if (!activeEl) return
    const wrapRect = tocWrap.getBoundingClientRect()
    const elRect = activeEl.getBoundingClientRect()
    if (elRect.top < wrapRect.top || elRect.bottom > wrapRect.bottom) {
      activeEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  })
})
</script>

<style scoped>
.report-export-container { width: 100%; height: 100%; display: flex; flex-direction: column; background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box; }
.page-header { margin-bottom: 12px; flex-shrink: 0; }
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }
.filter-bar { background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed; display: flex; align-items: center; gap: 20px; flex-shrink: 0; margin-bottom: 14px; }
.filter-group { display: flex; align-items: center; gap: 8px; }
.filter-label { font-size: 13px; color: #909399; white-space: nowrap; }
.export-actions { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; flex-shrink: 0; }
.format-label { font-size: 13px; color: #909399; }
.export-btn { border: none !important; color: #fff !important; font-weight: 600; transition: all 0.25s ease; }
.export-btn:hover { opacity: 0.85; transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
.export-btn:active { transform: translateY(0); }
.export-btn .export-icon { vertical-align: middle; flex-shrink: 0; }
.btn-markdown { background: linear-gradient(135deg, #4A90D9, #357ABD) !important; }
.btn-html { background: linear-gradient(135deg, #E67E22, #D35400) !important; }
.btn-docx { background: linear-gradient(135deg, #2B579A, #1E4076) !important; }
:deep(.el-scrollbar__wrap) { overflow-x: hidden; }
:deep(.el-scrollbar__view) { overflow-x: hidden; }
.doc-layout { flex: 1; min-height: 0; display: flex; gap: 16px; overflow: hidden; }
.doc-toc { width: 240px; flex-shrink: 0; border-right: 1px solid #e4e7ed; overflow: hidden; background: transparent; padding: 0; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; }
.toc-title { font-size: 14px; font-weight: 700; color: #303133; padding: 8px 4px 12px; border-bottom: 2px solid #409eff; margin-bottom: 8px; letter-spacing: 4px; }
.doc-toc .toc-block { margin-bottom: 4px; }
.doc-toc .toc-parent { font-size: 12px; font-weight: 600; color: #303133; padding: 6px 4px; cursor: pointer; border-radius: 4px; display: flex; align-items: center; gap: 4px; transition: all 0.15s; white-space: nowrap; border-left: none; background: transparent; }
.doc-toc .toc-parent:hover { background: #f0f7ff; color: #409eff; }
.doc-toc .toc-parent.active { background: #ecf5ff; color: #409eff; font-weight: 700; border-left: none; }
.doc-toc .toc-child { font-size: 12px; color: #606266; padding: 4px 4px 4px 12px; cursor: pointer; border-radius: 4px; transition: all 0.15s; white-space: nowrap; }
.doc-toc .toc-child:hover { background: #f0f7ff; color: #409eff; }
.doc-toc .toc-child.active { background: #ecf5ff; color: #409eff; font-weight: 600; }
.doc-body { flex: 1; overflow: hidden; display: flex; flex-direction: column; }
.doc-pages { flex: 1; background: #fff; }
.doc-pages-view { max-width: 21cm; margin: 0 auto; padding: 0 2.6cm 40px 2.8cm; }
.doc-section { margin-bottom: 24px; padding: 0; border-top: none; }
.doc-section + .doc-section { border-top: none; }
.doc-h2 { font-size: 16px; font-weight: 700; color: #303133; margin: 0 0 12px; padding: 8px 0 8px 12px; border-left: 4px solid #409eff; line-height: 1.4; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; scroll-margin-top: 16px; }
.doc-h2.no-record { border-left-color: #e4e7ed !important; }
.doc-sub-section { margin-bottom: 16px; padding-left: 16px; }
.doc-sub-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.doc-h3 { font-size: 14px; font-weight: 600; color: #606266; margin: 0; padding: 4px 0; line-height: 1.5; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; scroll-margin-top: 16px; }

.doc-parent-content { padding-left: 16px; margin-bottom: 4px; }
.doc-parent-content .doc-sub-header { margin-bottom: 8px; }
.doc-viewer { min-height: 32px; padding: 4px 0; }
.content-line { display: flex; align-items: flex-start; padding: 4px 6px; border-radius: 4px; transition: background 0.15s; min-height: 32px; }
.content-line.is-idle:hover { background: #f5f7fa; }
.line-content { flex: 1; min-width: 0; max-width: 40em; text-indent: 2em; overflow: hidden; position: relative; }
.line-right { flex-shrink: 0; display: flex; align-items: center; gap: 6px; margin-left: 12px; position: relative; z-index: 1; padding-top: 2px; }
.line-num { color: #909399; font-weight: 600; min-width: 24px; text-align: right; flex-shrink: 0; line-height: 1.6; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; margin-right: 6px; }
.line-text { color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; min-height: 22px; }
.doc-empty-text { color: #909399; font-size: 13px; }
</style>

<!-- 非 scoped：全假期周下拉选项的灰色样式（el-select 弹窗 teleport 到 body，scoped 样式无效） -->
<style>
.report-export-week-popper .holiday-week-option {
  color: #909399 !important;
}
.report-export-week-popper .holiday-week-option:hover {
  background-color: #f5f7fa !important;
}
</style>