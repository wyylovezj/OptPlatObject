<template>
  <div class="report-summary-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">周报汇总</h2>
      <div style="display:flex;align-items:center;gap:8px;">
        <el-button size="small" class="help-btn" @click="openHelpDoc">
          <span class="btn-icon">📖</span>操作指南
        </el-button>
        <el-button @click="goExportPage">
          <el-icon><Download /></el-icon>
          &nbsp;导出周报
        </el-button>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="period-switch">
        <el-radio-group v-model="summaryWeekKey" size="small" @change="handleSummaryWeekChange">
          <el-radio-button :value="'current'">本周 (第{{ currentWeek }}周)</el-radio-button>
          <el-radio-button :value="'custom'">自定义</el-radio-button>
        </el-radio-group>
      </div>
      <el-button size="small" :icon="ArrowLeft" circle @click="navigateSummaryWeek(-1)" :disabled="getSummaryWeek <= 1" />
      <el-tag type="primary" effect="light" class="week-tag">{{ summaryWeekLabel }}</el-tag>
      <el-button size="small" :icon="ArrowRight" circle @click="navigateSummaryWeek(1)" :disabled="getSummaryWeek >= currentWeek" />
      <el-select v-if="summaryWeekKey === 'custom'" v-model="customSummaryWeek" size="small" style="width:80px;" @change="handleCustomSummaryWeekChange">
        <el-option v-for="w in currentWeek" :key="w" :label="'第' + w + '周'" :value="w" />
      </el-select>
      <div style="margin-left:auto;display:flex;align-items:center;gap:8px;">
        <el-button type="warning" size="small" @click="handleRemindAll" :disabled="getSummaryWeek !== currentWeek">
          <el-icon><Bell /></el-icon>
          &nbsp;一键提醒
        </el-button>
        <el-button type="danger" size="small" @click="showBatchReturnDialog" :disabled="getSummaryWeek !== currentWeek">
          <el-icon><RefreshLeft /></el-icon>
          &nbsp;一键退回
        </el-button>
      </div>
    </div>

    <!-- 提交统计 -->
    <div class="summary-stats">
      <el-card
        v-for="stat in statsCards"
        :key="stat.label"
        shadow="never"
        class="stat-card"
        :class="{ 'clickable': true }"
        @click="showStatDialog(stat.label)"
      >
        <div class="stat-label">{{ stat.label }}</div>
        <transition name="stat-number" mode="out-in">
          <div :key="stat.value" class="stat-value" :style="{ color: stat.color }">{{ stat.value }}</div>
        </transition>
        <div class="stat-sub">{{ stat.sub }}</div>
      </el-card>
    </div>

    <!-- 人员名单对话框 -->
    <el-dialog v-model="peopleDialogVisible" :title="peopleDialogTitle" :width="peopleDialogType === '草稿' ? '900px' : '1050px'" :close-on-click-modal="true">
      <el-empty v-if="peopleList.length === 0" description="暂无数据" :image-size="80" />
      <div v-else style="width: 100%; overflow: hidden;">
        <el-table :data="peopleList" border size="small" style="width: 100%" max-height="400" :span-method="cellSpanMethod" :cell-style="{ textAlign: 'center' }">
        <el-table-column label="序号" width="60" align="center">
          <template #default="{ row }">
            <span v-if="row._rowSpan > 0">{{ row.seqIndex }}</span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="姓名" width="80" align="center" />
        <el-table-column label="提交状态" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.moduleStatus || 'pending')" size="small" effect="light" round>
              {{ getStatusText(row.moduleStatus || 'pending') }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="模块名" min-width="150" align="center">
          <template #default="{ row }">
            <span v-if="row.moduleName" class="mod-name-inline">
              <span class="mod-dot" :style="{ background: row.moduleColor || '#909399' }"></span>
              {{ row.moduleName }}
            </span>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column label="子模块" width="130" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.subModuleName" size="small" :color="row.moduleColor || '#409eff'" effect="plain" round style="color: #fff;">{{ row.subModuleName }}</el-tag>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType !== '草稿'" label="提交时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.submitTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="修改时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.moduleUpdateTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType === '草稿'" label="创建时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.createdTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType !== '草稿'" label="退回时间" width="130" align="center">
          <template #default="{ row }">
            <span style="font-size: 12px; color: #909399;">{{ row.moduleReturnedTime || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column v-if="peopleDialogType !== '已提交'" label="操作" width="80" align="center">
          <template #default="{ row }">
            <el-button
              v-if="row.userCode && row.status !== 'submitted'"
              type="warning" size="small" text
              :loading="remindingUser === row.userCode"
              :disabled="getSummaryWeek !== currentWeek"
              @click="handleRemindPerson(row.userCode, row.name)"
            >
              <el-icon><Bell /></el-icon>&nbsp;提醒
            </el-button>
            <span v-else style="color: #c0c4cc;">-</span>
          </template>
        </el-table-column>
      </el-table>
    </div>
    </el-dialog>

    <!-- 一键退回对话框 -->
    <el-dialog v-model="batchReturnDialogVisible" title="一键退回" width="550px" :close-on-click-modal="true">
      <el-empty v-if="batchReturnPeople.length === 0" description="暂无已提交/已退回的人员" :image-size="80" />
      <div v-else>
        <p style="margin-bottom:12px;font-size:13px;color:#606266;">选择人员后，该人员所有已提交和已退回的周报将被退回：</p>
        <el-scrollbar max-height="300px">
          <el-table :data="batchReturnPeople" border size="small" style="width:100%">
            <el-table-column type="index" label="序号" width="60" align="center" />
            <el-table-column prop="name" label="姓名" width="100" align="center" />
            <el-table-column prop="count" label="可退回条数" width="120" align="center" />
            <el-table-column label="操作" align="center">
              <template #default="{ row }">
                <el-button type="warning" size="small" @click.stop="handleBatchReturnPerson(row)">
                  <el-icon><RefreshLeft /></el-icon>&nbsp;退回
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-scrollbar>
      </div>
    </el-dialog>

    <!-- 文档内容区：左侧目录 + 右侧周报明细 -->
    <div class="doc-layout">
      <div v-if="loading" class="loading-mask">
        <el-icon class="loading-icon" :size="32"><Loading /></el-icon>
        <span>数据加载中...</span>
      </div>
      <template v-else-if="loaded && summaryData && summarySections.length > 0">
        <!-- 目录侧边栏 -->
      <el-scrollbar class="doc-toc">
        <div class="toc-title">目 录</div>
        <div v-for="(sec, si) in summarySections" :key="'toc-p'+si" class="toc-block">
          <div class="toc-parent" :class="{ active: activeSectionKey === 'p'+si, disabled: !sec.hasRecord }" @click="scrollTo('p'+si)">
            <span class="toc-dot" :style="{ background: sec.hasRecord ? (sec.hasEdited ? '#67c23a' : '#c0c4cc') : 'transparent' }" :title="sec.hasRecord ? (sec.hasEdited ? '已编辑' : '未编辑') : ''"></span>
            {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
          </div>
          <div v-for="(sub, sj) in sec.subs" :key="'toc-s'+si+'-'+sj"
               class="toc-child" :class="{ active: activeSectionKey === 's'+si+'-'+sj, disabled: !sub.hasRecord }"
               @click="scrollTo('s'+si+'-'+sj)">
            <span class="toc-dot" :style="{ background: getSubTocDotColor(sub) }" :title="sub.hasRecord ? (sub.hasEdited ? '已编辑' : '未编辑') : ''"></span>
            （{{ chineseNum(sj + 1) }}）{{ sub.subName }}
          </div>
        </div>
      </el-scrollbar>

      <!-- 文档正文 -->
      <div class="doc-body">
        <el-scrollbar ref="docPagesScrollbar" class="doc-pages" view-class="doc-pages-view" @scroll="onDocScroll">
          <div v-for="(sec, si) in summarySections" :key="'sec'+si"
               :ref="el => { registerSection('p'+si, el) }" class="doc-section">

            <!-- ===== 无子模块的父模块 ===== -->
            <template v-if="!sec.hasSubModules">
              <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
              </h2>

              <!-- ===== 模块综述（无序号） ===== -->
              <div class="doc-parent-content" v-if="sec.hasParentRecord || (getSummaryWeek === currentWeek)">
                <div class="doc-sub-header">
                  <h3 class="doc-h3" :class="{ 'no-record': !(sec.parentEntries && sec.parentEntries.length > 0) }">模块综述<el-tag v-if="sec.parentEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                  <template v-if="sec.parentEntries && sec.parentEntries.length > 0">
                    <template v-if="editingKey === 'batch-'+sec.moduleId+'-parent'">
                      <div class="doc-sub-actions">
                        <el-button size="small" @click="cancelEdit">取消</el-button>
                        <el-button type="primary" size="small" @click="saveBatchEdit">保存</el-button>
                      </div>
                    </template>
                    <template v-else-if="getSummaryWeek === currentWeek">
                      <div class="doc-sub-actions">
                        <el-button type="primary" size="small" text @click="startBatchEdit(sec.parentEntries, sec.moduleId, 'parent')"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                        <el-dropdown @command="handleReturn">
                          <el-button size="small" text type="warning"><el-icon><RefreshLeft /></el-icon>&nbsp;退回<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                          <template #dropdown>
                            <el-dropdown-menu>
                              <el-dropdown-item v-for="e in sec.parentEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                            </el-dropdown-menu>
                          </template>
                        </el-dropdown>
                        <el-dropdown @command="handleDeleteEntry">
                          <el-button size="small" text type="danger"><el-icon><Delete /></el-icon>&nbsp;删除<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                          <template #dropdown>
                            <el-dropdown-menu>
                              <el-dropdown-item v-for="e in sec.parentEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                            </el-dropdown-menu>
                          </template>
                        </el-dropdown>
                      </div>
                    </template>
                  </template>
                </div>
                <!-- 编辑态：批编辑 -->
                <template v-if="editingKey === 'batch-'+sec.moduleId+'-parent'">
                  <div class="edit-wrapper">
                    <div v-if="originalContentLines.length > 0" class="original-ref-panel">
                      <div class="original-ref-header"><el-icon><Reading /></el-icon><span>原始提交内容参考（按提交时间排序）</span></div>
                      <el-scrollbar max-height="200px">
                        <div class="original-ref-body">
                          <div v-for="(ol, oi) in originalContentLines" :key="oi" class="ref-content-line">
                            <span class="line-text">{{ ol.text }}</span>
                            <span style="margin-left:auto;font-size:11px;color:#c0c4cc;white-space:nowrap;flex-shrink:0;">{{ ol.name }} {{ ol.submitTime }}</span>
                          </div>
                        </div>
                      </el-scrollbar>
                    </div>
                    <div class="doc-editor">
                      <div class="record-content-lines no-line-num">
                        <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                          <div class="line-content" @click="onLineContentClick(li, $event)">
                            <el-icon class="drag-handle"><Rank /></el-icon>
                            <div class="line-input-editable" contenteditable="true"
                              v-contenteditable="line.text"
                              @input="onEditableInput(li, $event)"
                              @focus="activateLine(li)"
                              @keydown="handleLineKeydown($event, li)"></div>
                          </div>
                          <div class="line-right">
                            <div class="active-line-actions">
                              <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                              <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                              <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                            </div>
                            <span class="line-meta">{{ line.name }}</span>
                          </div>
                        </div>
                        </div>
                        <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                      </div>
                    </div>
                  </template>
                  <!-- 查看态：合并显示（无序号） -->
                  <template v-else-if="sec.parentEntries && sec.parentEntries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sec.parentEntries)" :key="'pml-'+si+'-'+li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.parentEntries, sec.moduleId, 'parent', li)">
                        <div class="line-content">
                          <span class="line-text">{{ line.text }}</span>
                        </div>
                        <div class="line-right">
                          <span class="line-meta">{{ line.name }}<span v-if="line.updatedAt" style="margin-left:5px;">{{ line.updatedAt }}</span></span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <!-- 查看态：内容为空 -->
                  <span v-else-if="sec.parentEntries && sec.parentEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                  <!-- 无综述：可添加 -->
                  <div v-else-if="getSummaryWeek === currentWeek" class="doc-viewer" style="cursor: pointer;" @click="quickAddParentSummary(sec)">
                    <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加模块综述</span>
                  </div>
                </div>

              <!-- ===== 详细内容（有序号） ===== -->
              <div class="doc-sub-section">
                <div class="doc-sub-header">
                  <h3 class="doc-h3" :class="{ 'no-record': !(sec.entries && sec.entries.length > 0) }">详细内容<el-tag v-if="sec.detailEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                  <template v-if="sec.entries && sec.entries.length > 0">
                    <template v-if="editingKey === 'batch-'+sec.moduleId">
                      <div class="doc-sub-actions">
                        <el-button size="small" @click="cancelEdit">取消</el-button>
                        <el-button type="primary" size="small" @click="saveBatchEdit">保存</el-button>
                      </div>
                    </template>
                    <template v-else-if="getSummaryWeek === currentWeek">
                      <div class="doc-sub-actions">
                        <el-button type="primary" size="small" text @click="startBatchEdit(sec.entries, sec.moduleId)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                        <el-dropdown @command="handleReturn">
                          <el-button size="small" text type="warning"><el-icon><RefreshLeft /></el-icon>&nbsp;退回<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                          <template #dropdown>
                            <el-dropdown-menu>
                              <el-dropdown-item v-for="e in sec.entries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                            </el-dropdown-menu>
                          </template>
                        </el-dropdown>
                      </div>
                    </template>
                  </template>
                </div>
                <template v-if="sec.entries && sec.entries.length > 0">
                  <!-- 编辑态：批编辑 -->
                  <template v-if="editingKey === 'batch-'+sec.moduleId">
                    <div class="edit-wrapper">
                      <div v-if="originalContentLines.length > 0" class="original-ref-panel">
                        <div class="original-ref-header"><el-icon><Reading /></el-icon><span>原始提交内容参考（按提交时间排序）</span></div>
                        <el-scrollbar max-height="200px">
                          <div class="original-ref-body">
                            <div v-for="(ol, oi) in originalContentLines" :key="oi" class="ref-content-line">
                              <span class="line-num">({{ oi + 1 }})</span>
                              <span class="line-text">{{ ol.text }}</span>
                              <span style="margin-left:auto;font-size:11px;color:#c0c4cc;white-space:nowrap;flex-shrink:0;">{{ ol.name }} {{ ol.submitTime }}</span>
                            </div>
                          </div>
                        </el-scrollbar>
                      </div>
                      <div class="doc-editor">
                        <div class="record-content-lines">
                          <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                            <div class="line-content" @click="onLineContentClick(li, $event)">
                              <el-icon class="drag-handle"><Rank /></el-icon>
                              <span class="line-num" v-if="editLines.length > 1">({{ li + 1 }})</span>
                              <div class="line-input-editable" contenteditable="true"
                                v-contenteditable="line.text"
                                @input="onEditableInput(li, $event)"
                                @focus="activateLine(li)"
                                @keydown="handleLineKeydown($event, li)"></div>
                            </div>
                            <div class="line-right">
                              <div class="active-line-actions">
                                <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                              </div>
                              <span class="line-meta">{{ line.name }}</span>
                            </div>
                          </div>
                          </div>
                          <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                        </div>
                      </div>
                    </template>
                    <!-- 查看态：合并显示 -->
                    <template v-else-if="sec.entries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sec.entries)" :key="'ml-'+si+'-'+li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.entries, sec.moduleId, undefined, li)">
                        <div class="line-content">
                          <span class="line-num" v-if="getMergedLines(sec.entries).length > 1">({{ li + 1 }})</span>
                          <span class="line-text">{{ line.text }}</span>
                        </div>
                        <div class="line-right">
                          <span class="line-meta">{{ line.name }}<span v-if="line.updatedAt" style="margin-left:5px;">{{ line.updatedAt }}</span></span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <!-- 查看态：内容为空（所有行被删除后保存） -->
                  <span v-else class="doc-empty-text" style="display:block;padding:8px 6px;">暂未填写</span>
                </template>
                <span v-else class="doc-empty-text" style="display:block;padding:8px 6px;">暂无人填写</span>
              </div>
            </template>

            <!-- ===== 有子模块的父模块 ===== -->
            <template v-else>
              <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
              </h2>

              <!-- ===== 父模块自身内容区（与子模块并列，无序号） ===== -->
              <div class="doc-parent-content" v-if="sec.hasParentRecord || (getSummaryWeek === currentWeek && sec.hasSubModules)">
                <div class="doc-sub-header">
                  <h3 class="doc-h3" :class="{ 'no-record': !(sec.parentEntries && sec.parentEntries.length > 0) }">模块综述<el-tag v-if="sec.parentEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                  <template v-if="sec.parentEntries && sec.parentEntries.length > 0">
                    <template v-if="editingKey === 'batch-'+sec.moduleId+'-parent'">
                      <div class="doc-sub-actions">
                        <el-button size="small" @click="cancelEdit">取消</el-button>
                        <el-button type="primary" size="small" @click="saveBatchEdit">保存</el-button>
                      </div>
                    </template>
                    <template v-else-if="getSummaryWeek === currentWeek">
                      <div class="doc-sub-actions">
                        <el-button type="primary" size="small" text @click="startBatchEdit(sec.parentEntries, sec.moduleId, 'parent')"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                        <el-dropdown @command="handleReturn">
                          <el-button size="small" text type="warning"><el-icon><RefreshLeft /></el-icon>&nbsp;退回<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                          <template #dropdown>
                            <el-dropdown-menu>
                              <el-dropdown-item v-for="e in sec.parentEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                            </el-dropdown-menu>
                          </template>
                        </el-dropdown>
                        <el-dropdown @command="handleDeleteEntry">
                          <el-button size="small" text type="danger"><el-icon><Delete /></el-icon>&nbsp;删除<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                          <template #dropdown>
                            <el-dropdown-menu>
                              <el-dropdown-item v-for="e in sec.parentEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                            </el-dropdown-menu>
                          </template>
                        </el-dropdown>
                      </div>
                    </template>
                  </template>
                </div>
                <!-- 编辑态：批编辑 -->
                <template v-if="editingKey === 'batch-'+sec.moduleId+'-parent'">
                  <div class="edit-wrapper">
                    <div v-if="originalContentLines.length > 0" class="original-ref-panel">
                      <div class="original-ref-header"><el-icon><Reading /></el-icon><span>原始提交内容参考（按提交时间排序）</span></div>
                      <el-scrollbar max-height="200px">
                        <div class="original-ref-body">
                          <div v-for="(ol, oi) in originalContentLines" :key="oi" class="ref-content-line">
                            <span class="line-text">{{ ol.text }}</span>
                            <span style="margin-left:auto;font-size:11px;color:#c0c4cc;white-space:nowrap;flex-shrink:0;">{{ ol.name }} {{ ol.submitTime }}</span>
                          </div>
                        </div>
                      </el-scrollbar>
                    </div>
                    <div class="doc-editor">
                      <div class="record-content-lines no-line-num">
                        <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                          <div class="line-content" @click="onLineContentClick(li, $event)">
                            <el-icon class="drag-handle"><Rank /></el-icon>
                            <div class="line-input-editable" contenteditable="true"
                              v-contenteditable="line.text"
                              @input="onEditableInput(li, $event)"
                              @focus="activateLine(li)"
                              @keydown="handleLineKeydown($event, li)"></div>
                          </div>
                          <div class="line-right">
                            <div class="active-line-actions">
                              <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                              <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                              <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                            </div>
                            <span class="line-meta">{{ line.name }}</span>
                          </div>
                        </div>
                        </div>
                        <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                      </div>
                    </div>
                  </template>
                  <!-- 查看态：合并显示（无序号） -->
                  <template v-else-if="sec.parentEntries && sec.parentEntries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sec.parentEntries)" :key="'pml-'+si+'-'+li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.parentEntries, sec.moduleId, 'parent', li)">
                        <div class="line-content">
                          <span class="line-text">{{ line.text }}</span>
                        </div>
                        <div class="line-right">
                          <span class="line-meta">{{ line.name }}<span v-if="line.updatedAt" style="margin-left:5px;">{{ line.updatedAt }}</span></span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <!-- 查看态：内容为空 -->
                  <span v-else-if="sec.parentEntries && sec.parentEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                  <!-- 无综述：可添加 -->
                  <div v-else-if="getSummaryWeek === currentWeek" class="doc-viewer" style="cursor: pointer;" @click="quickAddParentSummary(sec)">
                    <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加模块综述</span>
                  </div>
                </div>

              <!-- 子模块 -->
              <div v-for="(sub, sj) in sec.subs" :key="'sub'+si+'-'+sj"
                   :ref="el => { registerSection('s'+si+'-'+sj, el) }" class="doc-sub-section">
                <div class="doc-sub-header">
                  <h3 class="doc-h3" :class="{ 'no-record': !sub.hasRecord }">（{{ chineseNum(sj + 1) }}）{{ sub.subName }}<el-tag v-if="sub.hasEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                </div>

                <!-- ===== 子模块综述（无序号） ===== -->
                <div class="doc-parent-content" v-if="sub.summaryEntries.length > 0 || (getSummaryWeek === currentWeek)">
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !(sub.summaryEntries && sub.summaryEntries.length > 0) }">模块综述<el-tag v-if="sub.summaryEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                    <template v-if="sub.summaryEntries && sub.summaryEntries.length > 0">
                      <template v-if="editingKey === 'batch-'+sec.moduleId+'-'+sj+'-summary'">
                        <div class="doc-sub-actions">
                          <el-button size="small" @click="cancelEdit">取消</el-button>
                          <el-button type="primary" size="small" @click="saveBatchEdit">保存</el-button>
                        </div>
                      </template>
                      <template v-else-if="getSummaryWeek === currentWeek">
                        <div class="doc-sub-actions">
                          <el-button type="primary" size="small" text @click="startBatchEdit(sub.summaryEntries, sec.moduleId, sj+'-summary')"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                          <el-dropdown @command="handleReturn">
                            <el-button size="small" text type="warning"><el-icon><RefreshLeft /></el-icon>&nbsp;退回<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                            <template #dropdown>
                              <el-dropdown-menu>
                                <el-dropdown-item v-for="e in sub.summaryEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                              </el-dropdown-menu>
                            </template>
                          </el-dropdown>
                          <el-dropdown @command="handleDeleteEntry">
                            <el-button size="small" text type="danger"><el-icon><Delete /></el-icon>&nbsp;删除<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                            <template #dropdown>
                              <el-dropdown-menu>
                                <el-dropdown-item v-for="e in sub.summaryEntries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                              </el-dropdown-menu>
                            </template>
                          </el-dropdown>
                        </div>
                      </template>
                    </template>
                  </div>
                  <template v-if="editingKey === 'batch-'+sec.moduleId+'-'+sj+'-summary'">
                    <div class="edit-wrapper">
                      <div v-if="originalContentLines.length > 0" class="original-ref-panel">
                        <div class="original-ref-header"><el-icon><Reading /></el-icon><span>原始提交内容参考（按提交时间排序）</span></div>
                        <el-scrollbar max-height="200px">
                          <div class="original-ref-body">
                            <div v-for="(ol, oi) in originalContentLines" :key="oi" class="ref-content-line">
                              <span class="line-text">{{ ol.text }}</span>
                              <span style="margin-left:auto;font-size:11px;color:#c0c4cc;white-space:nowrap;flex-shrink:0;">{{ ol.name }} {{ ol.submitTime }}</span>
                            </div>
                          </div>
                        </el-scrollbar>
                      </div>
                      <div class="doc-editor">
                        <div class="record-content-lines no-line-num">
                          <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                            <div class="line-content" @click="onLineContentClick(li, $event)">
                              <el-icon class="drag-handle"><Rank /></el-icon>
                              <div class="line-input-editable" contenteditable="true"
                                v-contenteditable="line.text"
                                @input="onEditableInput(li, $event)"
                                @focus="activateLine(li)"
                                @keydown="handleLineKeydown($event, li)"></div>
                            </div>
                            <div class="line-right">
                              <div class="active-line-actions">
                                <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                              </div>
                              <span class="line-meta">{{ line.name }}</span>
                            </div>
                          </div>
                        </div>
                        <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                      </div>
                    </div>
                  </template>
                  <template v-else-if="sub.summaryEntries && sub.summaryEntries.some(e => parseLines(e.content).length > 0)">
                    <div class="doc-viewer">
                      <div v-for="(line, li) in getMergedLines(sub.summaryEntries)" :key="'sms-'+si+'-'+sj+'-'+li" class="content-line is-idle" @dblclick="onViewLineDblClick(sub.summaryEntries, sec.moduleId, sj+'-summary', li)">
                        <div class="line-content">
                          <span class="line-text">{{ line.text }}</span>
                        </div>
                        <div class="line-right">
                          <span class="line-meta">{{ line.name }}<span v-if="line.updatedAt" style="margin-left:5px;">{{ line.updatedAt }}</span></span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <span v-else-if="sub.summaryEntries && sub.summaryEntries.length > 0" class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                  <div v-else-if="getSummaryWeek === currentWeek" class="doc-viewer" style="cursor: pointer;" @click="quickAddSubSummaryInSummary(sub)">
                    <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加子模块综述</span>
                  </div>
                </div>

                <!-- ===== 子模块详细内容（有序号） ===== -->
                <div class="doc-sub-section">
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !(sub.entries && sub.entries.length > 0) }">详细内容<el-tag v-if="sub.detailEdited" size="small" type="success" effect="light" style="margin-left:6px;">已编辑</el-tag></h3>
                    <template v-if="sub.entries && sub.entries.length > 0">
                      <template v-if="editingKey === 'batch-'+sec.moduleId+'-'+sj">
                        <div class="doc-sub-actions">
                          <el-button size="small" @click="cancelEdit">取消</el-button>
                          <el-button type="primary" size="small" @click="saveBatchEdit">保存</el-button>
                        </div>
                      </template>
                      <template v-else-if="getSummaryWeek === currentWeek">
                        <div class="doc-sub-actions">
                          <el-button type="primary" size="small" text @click="startBatchEdit(sub.entries, sec.moduleId, sj)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                          <el-dropdown @command="handleReturn">
                            <el-button size="small" text type="warning"><el-icon><RefreshLeft /></el-icon>&nbsp;退回<el-icon class="el-icon--right"><ArrowDown /></el-icon></el-button>
                            <template #dropdown>
                              <el-dropdown-menu>
                                <el-dropdown-item v-for="e in sub.entries" :key="e.reportId" :command="e.reportId">{{ e.name }}</el-dropdown-item>
                              </el-dropdown-menu>
                            </template>
                          </el-dropdown>
                        </div>
                      </template>
                    </template>
                  </div>
                  <template v-if="sub.entries && sub.entries.length > 0">
                    <template v-if="editingKey === 'batch-'+sec.moduleId+'-'+sj">
                      <div class="edit-wrapper">
                        <div v-if="originalContentLines.length > 0" class="original-ref-panel">
                          <div class="original-ref-header"><el-icon><Reading /></el-icon><span>原始提交内容参考（按提交时间排序）</span></div>
                          <el-scrollbar max-height="200px">
                            <div class="original-ref-body">
                              <div v-for="(ol, oi) in originalContentLines" :key="oi" class="ref-content-line">
                                <span class="line-num">({{ oi + 1 }})</span>
                                <span class="line-text">{{ ol.text }}</span>
                                <span style="margin-left:auto;font-size:11px;color:#c0c4cc;white-space:nowrap;flex-shrink:0;">{{ ol.name }} {{ ol.submitTime }}</span>
                              </div>
                            </div>
                          </el-scrollbar>
                        </div>
                        <div class="doc-editor">
                          <div class="record-content-lines">
                            <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                              <div class="line-content" @click="onLineContentClick(li, $event)">
                                <el-icon class="drag-handle"><Rank /></el-icon>
                                <span class="line-num" v-if="editLines.length > 1">({{ li + 1 }})</span>
                                <div class="line-input-editable" contenteditable="true"
                                  v-contenteditable="line.text"
                                  @input="onEditableInput(li, $event)"
                                  @focus="activateLine(li)"
                                  @keydown="handleLineKeydown($event, li)"></div>
                              </div>
                              <div class="line-right">
                                <div class="active-line-actions">
                                  <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                                </div>
                                <span class="line-meta">{{ line.name }}</span>
                              </div>
                            </div>
                          </div>
                          <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                        </div>
                      </div>
                    </template>
                    <template v-else-if="sub.entries.some(e => parseLines(e.content).length > 0)">
                      <div class="doc-viewer">
                        <div v-for="(line, li) in getMergedLines(sub.entries)" :key="'ml-'+si+'-'+sj+'-'+li" class="content-line is-idle" @dblclick="onViewLineDblClick(sub.entries, sec.moduleId, sj, li)">
                          <div class="line-content">
                            <span class="line-num" v-if="getMergedLines(sub.entries).length > 1">({{ li + 1 }})</span>
                            <span class="line-text">{{ line.text }}</span>
                          </div>
                          <div class="line-right">
                            <span class="line-meta">{{ line.name }}<span v-if="line.updatedAt" style="margin-left:5px;">{{ line.updatedAt }}</span></span>
                          </div>
                        </div>
                      </div>
                    </template>
                    <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂未填写</span>
                  </template>
                  <span v-else class="doc-empty-text" style="display:block;padding:4px 6px;">暂无人填写</span>
                </div>
              </div>
            </template>
          </div>
        </el-scrollbar>
      </div>
      </template>
      <div v-else-if="loaded" class="empty-summary">
        <el-empty description="本周无已提交的周报数据" :image-size="80" />
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import Sortable from 'sortablejs'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Download, ArrowDown, ArrowLeft, ArrowRight, Bell, Edit, Plus, Delete, CopyDocument, DocumentCopy, Select, RefreshLeft, Close, Reading, Rank, Loading } from '@element-plus/icons-vue'
import { usePermissionStore } from '@/stores/permissionStore'
import { getReportModules, getSummaryReports, editSummaryContent, saveReport, remindUnsubmitted, remindPerson, deleteReport, returnReport, batchReturnReports, getWeekConfig, getReportSubModules, getServerCurrentWeek } from '@/api/weeklyReportApi'
import { reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN, setWeekConfig, serverCurrentWeek, fetchWeekDateRanges } from '@/utils/weeklyReportData'

const router = useRouter()
const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }
const openHelpDoc = () => window.open('/运维周报模块操作文档.html')
const permissionStore = usePermissionStore()
const username = computed(() => permissionStore.userInfo?.username || '')
const nickname = computed(() => permissionStore.userInfo?.nickname || '')

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()
const summaryWeekKey = ref('current')
const customSummaryWeek = ref(currentWeek)
const getSummaryWeek = computed(() => summaryWeekKey.value === 'current' ? currentWeek : customSummaryWeek.value)
const summaryData = ref(null)
const loaded = ref(false)
const loading = ref(true)
const docPagesScrollbar = ref(null)
const subModules = ref([])
const loadSubModules = async () => { try { subModules.value = await getReportSubModules() } catch { subModules.value = [] } }
const getSubModulesForModule = (moduleId) => subModules.value.filter(sm => sm.moduleId === moduleId)

  // 正在添加的模块ID
const addingModuleId = ref(null)

const editingKey = ref('')
const editingModuleId = ref(null)
const editLines = ref([])
const editingLineIdx = ref(null)
const editingReportIds = ref([])
const editingSubModuleId = ref(null)
const editingIsSummary = ref(false)
const clipboardText = ref('')
const originalContentLines = ref([])
let lineUid = 0
const sortableInstance = ref(null)
const displayName = computed(() => nickname.value || username.value)

const peopleDialogVisible = ref(false)
const peopleDialogType = ref('')
const peopleList = ref([])
const remindingUser = ref('')

const batchReturnDialogVisible = ref(false)
const batchReturnPeople = computed(() => {
  if (!summaryData.value?.moduleGroups) return []
  const personMap = new Map()
  const collect = (entries) => {
    (entries || []).forEach(entry => {
      if (entry.status === 'submitted' || entry.status === 'returned') {
        const key = entry.userCode || entry.name
        if (!personMap.has(key)) {
          personMap.set(key, { name: entry.name, userCode: entry.userCode || '', count: 0 })
        }
        personMap.get(key).count++
      }
    })
  }
  summaryData.value.moduleGroups.forEach(group => {
    collect(group.entries)
    ;(group.subGroups || []).forEach(sg => { collect(sg.entries); collect(sg.summaryEntries) })
  })
  return Array.from(personMap.values()).sort((a, b) => a.name.localeCompare(b.name, 'zh'))
})

const showBatchReturnDialog = () => {
  batchReturnDialogVisible.value = true
}

const handleBatchReturnPerson = async (person) => {
  try {
    await ElMessageBox.confirm(
      `确认将 ${person.name} 的全部 ${person.count} 条已提交/已退回周报退回？退回后需重新编辑后提交。`,
      '一键退回确认',
      { confirmButtonText: '确认退回', cancelButtonText: '取消', type: 'warning' }
    )
  } catch { return }
  batchReturnDialogVisible.value = false
  const entries = getAllPersonEntries(person)
  const reportIds = entries.map(e => e.reportId)
  try {
    skipNextStatusEvent = true
    const res = await batchReturnReports(reportIds)
    if (res.status === 'success') {
      msg('success', res.message || `已成功退回 ${person.name} 的 ${reportIds.length} 条周报`)
    } else {
      msg('error', res.message || '批量退回失败')
    }
  } catch (e) {
    msg('error', e.message || '批量退回失败')
  }
  loadSummary(true)
}

const getAllPersonEntries = (person) => {
  const entries = []
  if (!summaryData.value?.moduleGroups) return entries
  summaryData.value.moduleGroups.forEach(group => {
    const collect = (list) => {
      list.forEach(entry => {
        const key = entry.userCode || entry.name
        if (key === (person.userCode || person.name) && (entry.status === 'submitted' || entry.status === 'returned')) {
          entries.push(entry)
        }
      })
    }
    collect(group.entries || [])
    ;(group.subGroups || []).forEach(sg => { collect(sg.entries || []); collect(sg.summaryEntries || []) })
  })
  return entries
}

const summaryWeekLabel = computed(() => {
  const { monday, sunday } = getWeekDateRange(currentYear, getSummaryWeek.value)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)} · 第${getSummaryWeek.value}周`
})

const handleSummaryWeekChange = () => {
  if (summaryWeekKey.value === 'custom' && customSummaryWeek.value === currentWeek) {
    customSummaryWeek.value = currentWeek - 1
  }
  loadSummary()
}

const handleCustomSummaryWeekChange = (val) => {
  if (val && val >= 1 && val <= currentWeek) {
    loadSummary()
  }
}

const navigateSummaryWeek = (delta) => {
  const current = getSummaryWeek.value
  const target = current + delta
  if (target < 1 || target > currentWeek) return
  if (target === currentWeek) {
    summaryWeekKey.value = 'current'
  } else {
    summaryWeekKey.value = 'custom'
    customSummaryWeek.value = target
  }
  loadSummary()
}

const statsCards = computed(() => {
  const data = summaryData.value
  if (!data) return []
  return [
    { label: '团队成员', value: data.total || 0, sub: '人', color: '#303133' },
    { label: '已提交', value: data.submitted || 0, sub: '人', color: '#67c23a' },
    { label: '已退回', value: data.returned || 0, sub: '人', color: '#e6a23c' },
    { label: '部分提交', value: data.partial || 0, sub: '人', color: '#409eff' },
    { label: '草稿', value: data.draft || 0, sub: '人', color: '#909399' },
    { label: '未提交', value: data.pending || 0, sub: '人', color: '#f56c6c' },
  ]
})

const peopleDialogTitle = computed(() => {
  const titleMap = {
    '未提交': '未提交人员名单', '部分提交': '部分提交人员名单', '已退回': '已退回人员名单',
    '已提交': '已提交人员名单', '草稿': '草稿人员名单', '团队成员': '团队成员名单'
  }
  return titleMap[peopleDialogType.value] || '人员名单'
})

const getStatusType = (status) => {
  const statusMap = { 'submitted': 'success', 'returned': 'warning', 'partial': 'info', 'draft': 'info', 'pending': 'danger' }
  return statusMap[status] || 'info'
}
const getStatusText = (status) => {
  const textMap = { 'submitted': '已提交', 'returned': '已退回', 'partial': '部分提交', 'draft': '草稿', 'pending': '未提交' }
  return textMap[status] || status
}

const buildModuleEntriesFromDetails = (details) => {
  if (!details || details.length === 0) return []
  return details.map(d => {
    const mod = reportModules.value.find(m => m.name === d.moduleName)
    return {
      moduleName: d.moduleName || '', subModuleName: d.subModuleName || '',
      moduleStatus: d.status || 'draft', moduleColor: mod ? mod.color : '#2563eb',
      submitTime: d.submitTime || null, moduleUpdateTime: d.updateTime || null,
      moduleReturnedTime: d.returnedTime || null, createdTime: d.createdTime || null,
    }
  })
}

// 显示统计卡片对应的对话框
const showStatDialog = (label) => {
  peopleDialogType.value = label
  const rawList = []

  if (label === '未提交') {
    ;(summaryData.value?.pendingList || []).forEach(u => rawList.push({
      engineerId: u.engineerId, name: u.name, userCode: u.userCode, status: 'pending',
      submitTime: u.submitTime, updateTime: u.updateTime, moduleEntries: []
    }))
  } else if (label === '草稿') {
    ;(summaryData.value?.draftList || []).forEach(u => rawList.push({
      engineerId: u.engineerId, name: u.name, userCode: u.userCode, status: 'draft',
      submitTime: u.submitTime, updateTime: u.updateTime,
      moduleEntries: buildModuleEntriesFromDetails(u.statusDetails)
    }))
  } else if (label === '部分提交') {
    ;(summaryData.value?.partialList || []).forEach(u => rawList.push({
      engineerId: u.engineerId, name: u.name, userCode: u.userCode, status: 'partial',
      submitTime: u.submitTime, updateTime: u.updateTime,
      moduleEntries: buildModuleEntriesFromDetails(u.statusDetails)
    }))
  } else if (label === '已退回') {
    ;(summaryData.value?.returnedList || []).forEach(u => rawList.push({
      engineerId: u.engineerId, name: u.name, userCode: u.userCode, status: 'returned',
      submitTime: u.submitTime, updateTime: u.updateTime,
      moduleEntries: buildModuleEntriesFromDetails(u.statusDetails)
    }))
  } else if (label === '已提交') {
    // 排除有退回或部分提交记录的人员
    const returnedNames = new Set((summaryData.value?.returnedList || []).map(u => u.name))
    const partialNames = new Set((summaryData.value?.partialList || []).map(u => u.name))
    const excludedNames = new Set([...returnedNames, ...partialNames])
    const personMap = new Map()
    if (summaryData.value?.moduleGroups) {
      summaryData.value.moduleGroups.forEach(group => {
        group.entries.forEach(entry => {
          if (entry.status !== 'submitted' || excludedNames.has(entry.name)) return
          if (!personMap.has(entry.name)) {
            personMap.set(entry.name, { engineerId: entry.engineerId, name: entry.name, userCode: entry.userCode || '', entries: [] })
          }
          const person = personMap.get(entry.name)
          if (!person.entries.some(e => e.moduleName === entry.moduleName && (e.subModuleName || '') === (entry.subModuleName || ''))) {
            person.entries.push({ moduleName: entry.moduleName, subModuleName: entry.subModuleName || '', moduleColor: entry.color || '', moduleStatus: 'submitted', submitTime: entry.submitTime || null, moduleUpdateTime: entry.updateTime || null, moduleReturnedTime: entry.returnedTime || null })
          }
        })
      })
    }
    personMap.forEach(person => {
      rawList.push({ id: person.engineerId, name: person.name, userCode: person.userCode, status: 'submitted', submitTime: null, updateTime: null, moduleEntries: person.entries })
    })
  } else if (label === '团队成员') {
    const unsubmittedData = summaryData.value?.unsubmitted || []
    const seen = new Set()
    unsubmittedData.forEach(u => {
      if (!seen.has(u.name)) {
        seen.add(u.name)
        rawList.push({ engineerId: u.engineerId, name: u.name, userCode: u.userCode, status: u.status, submitTime: u.submitTime, updateTime: u.updateTime, moduleEntries: buildModuleEntriesFromDetails(u.statusDetails) })
      }
    })
    if (summaryData.value?.moduleGroups) {
      summaryData.value.moduleGroups.forEach(group => {
        group.entries.forEach(entry => {
          if (!seen.has(entry.name)) {
            seen.add(entry.name)
            rawList.push({ engineerId: entry.engineerId, name: entry.name, userCode: entry.userCode || '', status: entry.status, submitTime: entry.submitTime, updateTime: entry.updateTime, moduleEntries: entry.moduleName ? [{moduleName: entry.moduleName, subModuleName: entry.subModuleName || '', moduleColor: entry.color || '', moduleStatus: entry.status, submitTime: entry.submitTime || null, moduleUpdateTime: entry.updateTime || null, moduleReturnedTime: entry.returnedTime || null}] : [] })
          } else if (entry.moduleName) {
            const existing = rawList.find(e => e.name === entry.name)
            if (existing && !existing.moduleEntries.some(e => e.moduleName === entry.moduleName && (e.subModuleName || '') === (entry.subModuleName || ''))) {
              existing.moduleEntries.push({moduleName: entry.moduleName, subModuleName: entry.subModuleName || '', moduleColor: entry.color || '', moduleStatus: entry.status, submitTime: entry.submitTime || null, moduleUpdateTime: entry.updateTime || null, moduleReturnedTime: entry.returnedTime || null})
            }
          }
        })
      })
    }
    rawList.sort((a, b) => (a.engineerId || 0) - (b.engineerId || 0))
  }

  // 按模块编号顺序排序
  rawList.forEach(person => {
    if (person.moduleEntries && person.moduleEntries.length > 0) {
      person.moduleEntries.sort((a, b) => {
        const ma = reportModules.value.find(m => m.name === a.moduleName)
        const mb = reportModules.value.find(m => m.name === b.moduleName)
        return (ma ? ma.order || 999 : 999) - (mb ? mb.order || 999 : 999)
      })
    }
  })

  // 展平
  const flattened = []
  let seq = 0
  for (const person of rawList) {
    const entries = person.moduleEntries && person.moduleEntries.length > 0 ? person.moduleEntries : [{moduleName: null, moduleStatus: null}]
    const count = entries.length
    seq++
    const modSpans = new Array(entries.length).fill(1)
    for (let i = entries.length - 2; i >= 0; i--) {
      if (entries[i].moduleName && entries[i].moduleName === entries[i + 1].moduleName) {
        modSpans[i] = modSpans[i + 1] + 1
        modSpans[i + 1] = 0
      }
    }
    entries.forEach((entry, idx) => {
      flattened.push({
        ...person, _rowSpan: idx === 0 ? count : 0, _modRowSpan: modSpans[idx],
        moduleName: entry.moduleName, subModuleName: entry.subModuleName || '',
        moduleColor: entry.moduleColor || '', moduleStatus: entry.moduleStatus,
        submitTime: entry.submitTime || person.submitTime || null,
        moduleUpdateTime: entry.moduleUpdateTime || person.updateTime || null,
        moduleReturnedTime: entry.moduleReturnedTime || null,
        createdTime: entry.createdTime || null, seqIndex: idx === 0 ? seq : 0
      })
    })
  }
  peopleList.value = flattened
  peopleDialogVisible.value = true
}

const cellSpanMethod = ({ row, columnIndex }) => {
  if (columnIndex === 3) {
    if (row._modRowSpan > 0) return [row._modRowSpan, 1]
    return [0, 1]
  }
  if (peopleDialogType.value === '草稿') {
    if (columnIndex <= 1 || columnIndex === 7) {
      if (row._rowSpan > 0) return [row._rowSpan, 1]
      return [0, 1]
    }
    return [1, 1]
  }
  if (columnIndex <= 1 || columnIndex === 8) {
    if (row._rowSpan > 0) return [row._rowSpan, 1]
    return [0, 1]
  }
  return [1, 1]
}

const moduleGroups = computed(() => {
  if (!summaryData.value || !summaryData.value.moduleGroups) return []
  return summaryData.value.moduleGroups.map(g => ({
    ...g,
    color: reportModules.value.find(m => m.id === g.moduleId)?.color || '#2563eb',
    entries: sortEntries(g.entries || []),
    subGroups: (g.subGroups || []).map(sg => ({ ...sg, entries: sortEntries(sg.entries || []) }))
  })).filter(g => g.entries && g.entries.length > 0)
})

const sortEntries = (entries) => {
  return [...entries].sort((a, b) => {
    const ta = a.submitTime || ''
    const tb = b.submitTime || ''
    return ta.localeCompare(tb)
  })
}

const activeSectionKey = ref('')
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

const summarySections = computed(() => {
  // 直接使用 summaryData.moduleGroups 作为数据源（后端已包含所有模块，含停用/已删除的）
  const dataGroups = summaryData.value?.moduleGroups || []
  const isCurrentWeek = getSummaryWeek.value === currentWeek
  return dataGroups
    .filter(g => {
      // 历史周：显示所有模块（包括已停用、已删除的），确保历史数据完整可见
      if (!isCurrentWeek) return true
      // 当前周：仅显示已启用的模块；已删除的模块如有提交数据仍显示
      if (g.active === false) return false
      if (g.deleted && (!g.entries || g.entries.length === 0)) return false
      return true
    })
    .map(g => {
      const color = g.color || '#2563eb'
      // 分离有子模块ID的正式子分组（去重） 和 无子模块ID的孤儿条目
      const seenSubIds = new Set()
      const realSubGroups = (g.subGroups || []).filter(sg => {
        if (!sg.subModuleId) return false
        if (seenSubIds.has(sg.subModuleId)) return false
        seenSubIds.add(sg.subModuleId)
        return true
      })
      const orphanEntries = (g.subGroups || [])
        .filter(sg => !sg.subModuleId)
        .flatMap(sg => sg.entries || [])
      // 当前周：过滤掉已删除且无数据的子模块；历史周：显示所有子模块
      const activeSubGroups = realSubGroups.filter(sg => {
        // 历史周：显示所有子模块（包括已删除的）
        if (!isCurrentWeek) return true
        // 当前周：仅保留未删除或有数据的子模块
        if (sg.deleted && (!sg.entries || sg.entries.length === 0)) return false
        return true
      })
      // 合并主要条目 + 孤儿条目（按 reportId 去重，防止孤儿分组与主 entries 重复）
      const mergedEntries = [...(g.entries || []), ...orphanEntries]
      const seenReportIds = new Set()
      const allEntries = sortEntries(mergedEntries.filter(e => {
        if (seenReportIds.has(e.reportId)) return false
        seenReportIds.add(e.reportId)
        return true
      }))
      // 只有存在正式子分组时才走子模块展示路径；孤儿条目合并到主条目统一展示
      const hasSubModules = activeSubGroups.length > 0
      if (hasSubModules) {
        const subs = activeSubGroups.map(sg => {
          const summaryEntries = sg.summaryEntries || []
          const detailEntries = sg.entries || []
          return {
            subName: sg.subModuleName,
            hasRecord: detailEntries.length > 0 || summaryEntries.length > 0,
            hasEdited: (detailEntries.length > 0 && detailEntries.every(e => e.edited)) &&
                       (summaryEntries.length > 0 && summaryEntries.every(e => e.edited)),
            summaryEdited: summaryEntries.length > 0 && summaryEntries.every(e => e.edited),
            detailEdited: detailEntries.length > 0 && detailEntries.every(e => e.edited),
            summaryEntries,
            entries: sortEntries(detailEntries)
          }
        })
        // 父模块自身内容：g.entries 中 subModuleId=null 的条目
        const parentEntries = (g.entries || []).filter(e => !e.subModuleId)
        const parentEdited = parentEntries.length > 0 && parentEntries.every(e => e.edited)
        return {
          moduleId: g.moduleId,
          moduleName: g.name,
          moduleColor: color,
          hasSubModules: true,
          hasRecord: subs.some(s => s.hasRecord) || parentEntries.length > 0,
          hasEdited: parentEdited && subs.every(s => s.hasEdited),
          parentEdited,
          parentEntries,
          hasParentRecord: parentEntries.length > 0,
          entries: allEntries,
          hasOrphans: orphanEntries.length > 0,
          subs
        }
      } else {
        // 无子模块：分离综述（isSummary）和详细内容
        const parentEntries = allEntries.filter(e => e.isSummary)
        const detailEntries = allEntries.filter(e => !e.isSummary)
        const parentEdited = parentEntries.length > 0 && parentEntries.every(e => e.edited)
        const detailEdited = detailEntries.length > 0 && detailEntries.every(e => e.edited)
        return {
          moduleId: g.moduleId,
          moduleName: g.name,
          moduleColor: color,
          hasSubModules: false,
          hasRecord: allEntries.length > 0,
          hasEdited: parentEdited && detailEdited,
          parentEdited,
          detailEdited,
          parentEntries,
          hasParentRecord: parentEntries.length > 0,
          entries: detailEntries,
          subs: []
        }
      }
  })
})

// 子模块TOC色点：考量详细内容和综述的已编辑状态
const getSubTocDotColor = (sub) => {
  if (!sub.hasRecord) return 'transparent'
  if (sub.hasEdited) return '#67c23a'
  if (sub.summaryEdited || sub.detailEdited) return '#67c23a'
  return '#c0c4cc'
}

const chineseNum = (n) => {
  const map = ['零','一','二','三','四','五','六','七','八','九','十','十一','十二','十三','十四','十五','十六','十七','十八','十九','二十']
  return (n >= 0 && n < map.length) ? map[n] : String(n)
}

const loadSummary = async (silent = false) => {
  // 保存当前滚动位置
  const container = docPagesScrollbar.value?.$el?.querySelector('.el-scrollbar__wrap')
  const savedScrollTop = container?.scrollTop || 0
  if (!silent) loading.value = true
  try {
    try {
      const res = await getWeekConfig(getSummaryWeek.value)
      if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) {
        setWeekConfig(getSummaryWeek.value, res.data.startDate, res.data.endDate)
      }
    } catch (e) { /* 静默处理 */ }
    summaryData.value = await getSummaryReports(getSummaryWeek.value)
  } catch (e) {
    console.warn('加载汇总数据失败', e)
    summaryData.value = null
  } finally {
    if (!silent) {
      loaded.value = true
      loading.value = false
    }
    // DOM 重建后恢复滚动位置
    if (savedScrollTop > 0) {
      nextTick(() => {
        const newContainer = docPagesScrollbar.value?.$el?.querySelector('.el-scrollbar__wrap')
        if (newContainer) newContainer.scrollTop = savedScrollTop
      })
    }
  }
}

// 一键提醒
const handleRemindAll = async () => {
  try {
    await ElMessageBox.confirm('确认向所有未完全提交的人员发送周报提醒通知？', '一键提醒确认', { confirmButtonText: '确认发送', cancelButtonText: '取消', type: 'warning' })
  } catch { return }
  try {
    const res = await remindUnsubmitted(getSummaryWeek.value)
    if (res.status === 'success') {
      msg('success', '已向所有未提交人员发送提醒~')
    } else {
      msg('error', res.message || '发送提醒失败')
    }
  } catch (e) {
    msg('error', e.message || '发送提醒失败')
  }
}

// 向指定人员发送提醒
const handleRemindPerson = async (userCode, name) => {
  const personRows = peopleList.value.filter(p => p.userCode === userCode)
  const personStatus = personRows.length > 0 ? personRows[0].status : ''
  const moduleEntries = personRows.filter(p => p.moduleName).map(p => ({ moduleName: p.moduleName, moduleStatus: p.moduleStatus }))
  const missingModules = []
  const returnedModules = []
  if (moduleEntries.length > 0) {
    const dedupMap = new Map()
    moduleEntries.forEach(e => {
      if (!dedupMap.has(e.moduleName)) {
        dedupMap.set(e.moduleName, e.moduleStatus)
      } else {
        const current = dedupMap.get(e.moduleName)
        // 已退回优先级最高
        if (e.moduleStatus === 'returned') {
          dedupMap.set(e.moduleName, 'returned')
        } else if (current === 'submitted' && e.moduleStatus !== 'submitted') {
          // 当前是已提交，但新状态不是（草稿/部分提交），覆盖
          dedupMap.set(e.moduleName, e.moduleStatus)
        }
      }
    })
    dedupMap.forEach((status, modName) => {
      if (status === 'returned') returnedModules.push(modName)
      else if (status !== 'submitted') missingModules.push(modName)
    })
  } else if (personStatus === 'pending' || personStatus === 'draft') {
    const allActiveModules = reportModules.value.filter(m => m.active !== false && m.deleted !== 1).map(m => m.name)
    allActiveModules.forEach(m => missingModules.push(m))
  }
  if (missingModules.length === 0 && returnedModules.length === 0) {
    msg('info', `${name} 的所有模块已全部提交，无需提醒`)
    return
  }
  let confirmMsg = `确认向 <strong style="color:#e6a23c;font-size:16px;">${name}</strong> 发送周报提交提醒？`
  try {
    await ElMessageBox.confirm(confirmMsg, '发送提醒确认', { confirmButtonText: '确认发送', cancelButtonText: '取消', type: 'warning', dangerouslyUseHTMLString: true, customClass: 'remind-confirm-box' })
  } catch { return }
  remindingUser.value = userCode
  try {
    const res = await remindPerson(userCode, getSummaryWeek.value)
    if (res.status === 'success') {
      msg('success', `已向 ${name} 发送提醒~`)
    } else {
      msg('error', res.message || '发送提醒失败')
    }
  } catch (e) {
    msg('error', e.message || '发送提醒失败')
  } finally {
    remindingUser.value = ''
  }
}

const parseLines = (content) => {
  if (!content || !content.trim()) return []
  try {
    const parsed = JSON.parse(content)
    if (Array.isArray(parsed)) return parsed.filter(l => l && l.text !== undefined)
  } catch { /* 非 JSON */ }
  return content.split('\n').filter(t => t.trim()).map(t => ({ text: t, updatedBy: '', updatedAt: '' }))
}

// 将所有提交人的内容行按提交时间合并成一条列表
const getMergedLines = (entries) => {
  if (!entries || entries.length === 0) return []
  const lines = []
  // 按提交时间排序，与编辑态 startBatchEdit 保持一致
  const sorted = [...entries].sort((a, b) => (a.submitTime || '').localeCompare(b.submitTime || ''))
  sorted.forEach(entry => {
    const parsed = parseLines(entry.content)
    if (parsed.length === 0) {
      // 内容为空（如被清空时为 []），跳过不展示空行
      return
    }
    parsed.forEach(cl => {
      // 优先使用行级别的 updatedBy，新增强的行由汇总人员添加，应显示汇总人员姓名
      const displayName = (cl.updatedBy && cl.updatedBy.trim()) ? cl.updatedBy : entry.name
      lines.push({ text: cl.text, name: displayName, updatedAt: cl.updatedAt || entry.submitTime, submitTime: entry.submitTime, reportId: entry.reportId, engineerId: entry.engineerId, status: entry.status, content: entry.content, sortOrder: cl.sortOrder ?? Infinity })
    })
  })
  lines.sort((a, b) => (a.sortOrder ?? Infinity) - (b.sortOrder ?? Infinity))
  return lines
}

// 根据行信息查找原始 entry 对象
const findEntryByReportId = (reportId) => {
  if (!summaryData.value?.moduleGroups) return null
  for (const g of summaryData.value.moduleGroups) {
    let e = g.entries?.find(ee => ee.reportId === reportId)
    if (e) return e
    for (const sg of (g.subGroups || [])) {
      e = sg.entries?.find(ee => ee.reportId === reportId)
      if (e) return e
      e = (sg.summaryEntries || [])?.find(ee => ee.reportId === reportId)
      if (e) return e
    }
  }
  return null
}

// 初始化拖拽排序
const initSortable = () => {
  destroySortable()
  const el = document.querySelector('.record-content-lines')
  if (!el) return
  sortableInstance.value = Sortable.create(el, {
    handle: '.drag-handle',
    animation: 150,
    ghostClass: 'sortable-ghost',
    onEnd: (evt) => {
      const { oldIndex, newIndex } = evt
      if (oldIndex === undefined || newIndex === undefined || oldIndex === newIndex) return
      const item = editLines.value.splice(oldIndex, 1)[0]
      if (item) {
        editLines.value.splice(newIndex, 0, item)
      }
    }
  })
}
const destroySortable = () => {
  if (sortableInstance.value) {
    sortableInstance.value.destroy()
    sortableInstance.value = null
  }
}

const startEdit = (reportId, moduleId, content) => {
  if (editingKey.value === reportId) { editingKey.value = ''; return }
  editingKey.value = reportId
  editingModuleId.value = moduleId
  const ts = nowStr()
  const lines = parseLines(content)
  editLines.value = lines.length > 0 ? lines.map(l => ({ ...l, _origText: l.text, updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ })) : [{ text: '', updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }]
  editingLineIdx.value = 0
  originalContentLines.value = parseLines(content)
  nextTick(() => {
    const input = document.querySelector('.record-content-lines .line-input-editable')
    if (input) {
      input.focus()
      const range = document.createRange()
      range.selectNodeContents(input)
      range.collapse(false)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
  })
}

const activateLine = (idx) => { editingLineIdx.value = idx; setTimeout(() => focusLine(idx), 0) }
const focusLine = (idx) => {
  const inputs = document.querySelectorAll('.record-content-lines .line-input-editable')
  if (inputs.length > idx) {
    inputs.forEach((input, i) => {
      if (i !== idx && input.textContent === '\u200B') {
        input.textContent = ''
      }
    })
    const el = inputs[idx]
    if (!el.textContent) {
      el.focus()
      el.textContent = '\u200B'
      const range = document.createRange()
      range.selectNodeContents(el)
      range.collapse(false)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
  }
}
const onEditableInput = (idx, e) => {
  const el = e.target
  let text = (el.innerText || '').replace(/​/g, '').replace(/(\r?\n)+$/, '')
  editLines.value[idx].text = text
  if (!text && !el.textContent.replace(/​/g, '')) {
    el.textContent = '\u200B'
  }
}
const onLineContentClick = (idx, e) => {
  const editable = e.currentTarget.querySelector('.line-input-editable')
  if (!editable) return
  if (editable.textContent === '' || editable.textContent === '\u200B') {
    if (!editable.textContent) {
      editable.textContent = '\u200B'
    }
    const range = document.createRange()
    range.selectNodeContents(editable)
    range.collapse(false)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  } else if (e.target !== editable) {
    editable.focus()
    const range = document.createRange()
    range.selectNodeContents(editable)
    range.collapse(false)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }
}

// 双击查看态行，进入编辑态并定位光标到该行
const onViewLineDblClick = (entries, moduleId, subIdx, lineIdx) => {
  if (getSummaryWeek.value !== currentWeek) return
  if (!entries || entries.length === 0) return
  startBatchEdit(entries, moduleId, subIdx)
  editingLineIdx.value = lineIdx
  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input-editable')
    if (inputs.length > lineIdx) {
      const el = inputs[lineIdx]
      el.focus()
      const range = document.createRange()
      range.selectNodeContents(el)
      range.collapse(false)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
  })
}
// 阻止浏览器默认粘贴行为，用 execCommand 以纯文本插入，避免 DOM 块级拆分且支持 Ctrl+Z 撤销
const handleContentEditablePaste = (e) => {
  e.preventDefault()
  const text = (e.clipboardData || window.clipboardData).getData('text/plain')
  if (!text) return
  document.execCommand('insertText', false, text)
}

const cancelEdit = () => { destroySortable(); document.removeEventListener('keydown', handleKeydownSave); editingKey.value = ''; editingModuleId.value = null; editingLineIdx.value = null; editingReportIds.value = []; editingSubModuleId.value = null; editingIsSummary.value = false; editLines.value = []; originalContentLines.value = [] }

// 批量编辑：将子模块下所有提交人的内容合并编辑
const startBatchEdit = (entries, moduleId, subIdx) => {
  if (!entries || entries.length === 0) return
  editingKey.value = 'batch-' + moduleId + (subIdx !== undefined ? '-' + subIdx : '')
  editingModuleId.value = moduleId
  // 记录当前编辑上下文，供新增行保存时使用
  editingSubModuleId.value = entries[0].subModuleId || null
  editingIsSummary.value = subIdx === 'parent' || (typeof subIdx === 'string' && subIdx.endsWith('-summary'))
  const ts = nowStr()
  const sorted = [...entries].sort((a, b) => (a.submitTime || '').localeCompare(b.submitTime || ''))
  const allLines = []
  const origLines = []
  sorted.forEach(entry => {
    const parsed = parseLines(entry.content)
    const origParsed = parseLines(entry.originalContent)
    if (parsed.length === 0) {
      // 内容为空（如被清空时为 []），跳过不创建空行
    } else {
      parsed.forEach(cl => {
        allLines.push({ text: cl.text, name: entry.name, _reportId: entry.reportId, _engineerId: entry.engineerId, _origText: cl.text, updatedBy: displayName.value, updatedAt: ts, sortOrder: cl.sortOrder, _uid: lineUid++ })
      })
    }
    // 参考面板使用原始提交内容
    if (origParsed.length === 0) {
      origLines.push({ text: '', name: entry.name, submitTime: entry.submitTime })
    } else {
      origParsed.forEach(cl => {
        origLines.push({ text: cl.text, name: entry.name, submitTime: entry.submitTime })
      })
    }
  })
  // 按 sortOrder 排序（保留拖拽顺序，旧数据无 sortOrder 则保持原有顺序）
  allLines.sort((a, b) => (a.sortOrder ?? Infinity) - (b.sortOrder ?? Infinity))
  editLines.value = allLines.length > 0 ? allLines : [{ text: '', name: entries[0].name, _reportId: entries[0].reportId, _engineerId: entries[0].engineerId, _origText: '', updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }]
  editingLineIdx.value = 0
  originalContentLines.value = origLines
  // 记录所有涉及的 reportId，用于保存时处理被彻底删除的条目
  editingReportIds.value = [...new Set(sorted.map(e => e.reportId))]
  nextTick(() => {
    const input = document.querySelector('.record-content-lines .line-input-editable')
    if (input) { input.focus(); const r = document.createRange(); r.selectNodeContents(input); r.collapse(false); const s = window.getSelection(); s.removeAllRanges(); s.addRange(r) }
    document.addEventListener('keydown', handleKeydownSave)
    initSortable()
  })
}

// 批量保存
const saveBatchEdit = async () => {
  if (!editingKey.value || !editingKey.value.startsWith('batch-')) return
  const moduleId = editingModuleId.value
  // 记录当前拖拽排序后的全局顺序
  editLines.value.forEach((line, idx) => { line.sortOrder = idx })
  const groups = {}
  const newLines = []  // 无 _reportId 的新增行
  editLines.value.forEach(line => {
    if (line._reportId === undefined || line._reportId === null) {
      newLines.push(line)
      return
    }
    if (!groups[line._reportId]) groups[line._reportId] = { engineerId: line._engineerId, name: line.name, lines: [] }
    groups[line._reportId].lines.push({ text: line.text, updatedBy: line.updatedBy, updatedAt: line.updatedAt, sortOrder: line.sortOrder })
  })
  const ts = nowStr()
  let allSuccess = true
  // 处理已有行的修改
  for (const [reportId, group] of Object.entries(groups)) {
    const nonEmpty = group.lines.filter(l => l.text.trim())
    nonEmpty.forEach(l => { if (!l.updatedBy || l.text !== l._origText) { l.updatedBy = displayName.value; l.updatedAt = ts } })
    const contentStr = JSON.stringify(nonEmpty)
    try {
      const res = await editSummaryContent({ reportId: Number(reportId), content: contentStr, username: username.value })
      if (res.status === 'success') {
        const entry = findEntryByReportId(Number(reportId))
        if (entry) entry.content = contentStr
      } else { allSuccess = false }
    } catch { allSuccess = false }
  }
  // 处理被彻底删除的 reportId（行已全部删除，不在 groups 中），保存空内容
  const deletedReportIds = editingReportIds.value.filter(id => !groups[id])
  for (const reportId of deletedReportIds) {
    try {
      const res = await editSummaryContent({ reportId: Number(reportId), content: '[]', username: username.value })
      if (res.status === 'success') {
        const entry = findEntryByReportId(Number(reportId))
        if (entry) entry.content = '[]'
      } else { allSuccess = false }
    } catch { allSuccess = false }
  }
  // 处理新增行（无 _reportId），合并到已有记录中，避免 saveReport 去重删除冲突
  const newNonEmpty = newLines.filter(l => l.text.trim())
  if (newNonEmpty.length > 0) {
    // 找一个已有的 reportId 来合并新增行
    // 优先合并到汇总人员自己的提交行中，否则取第一个
    const adminGroupKey = Object.keys(groups).find(k => groups[k].name === displayName.value)
    const existingReportId = adminGroupKey || Object.keys(groups)[0]
    if (existingReportId) {
      const group = groups[existingReportId]
      newNonEmpty.forEach(l => {
        group.lines.push({ text: l.text, updatedBy: displayName.value, updatedAt: ts, sortOrder: l.sortOrder })
      })
      const mergedNonEmpty = group.lines.filter(l => l.text.trim())
      const mergedContentStr = JSON.stringify(mergedNonEmpty)
      try {
        const res = await editSummaryContent({ reportId: Number(existingReportId), content: mergedContentStr, username: username.value })
        if (res.status === 'success') {
          const entry = findEntryByReportId(Number(existingReportId))
          if (entry) entry.content = mergedContentStr
        } else { allSuccess = false }
      } catch { allSuccess = false }
    } else if (username.value) {
      // 无已有记录可合并，降级为新增（原有行全被删除，只剩新增行）
      const newContentStr = JSON.stringify(newNonEmpty.map(l => ({
        text: l.text, updatedBy: displayName.value, updatedAt: ts, sortOrder: l.sortOrder
      })))
      const entryData = { moduleId, content: newContentStr }
      if (editingSubModuleId.value) entryData.subModuleId = editingSubModuleId.value
      if (editingIsSummary.value) entryData.isSummary = true
      try {
        const res = await saveReport({
          username: username.value,
          weekNum: getSummaryWeek.value,
          entries: [entryData],
          status: 'submitted'
        })
        if (res.status !== 'success') allSuccess = false
      } catch { allSuccess = false }
    }
  }
  msg(allSuccess ? 'success' : 'error', allSuccess ? '内容已更新' : '部分条目更新失败')
  // 先刷新数据，再退出编辑态，确保查看态直接使用最新数据不跳动
  await loadSummary(true)
  destroySortable()
  document.removeEventListener('keydown', handleKeydownSave)
  editingKey.value = ''; editingModuleId.value = null; editingLineIdx.value = null; editingReportIds.value = []; editingSubModuleId.value = null; editingIsSummary.value = false; editLines.value = []; originalContentLines.value = []
}

// 在汇总页快捷添加模块综述
const quickAddParentSummary = async (sec) => {
  if (addingModuleId.value === sec.moduleId) return
  if (!username.value) { msg('warning', '无法获取当前用户'); return }
  addingModuleId.value = sec.moduleId
  try {
    skipNextStatusEvent = true
    const res = await saveReport({ username: username.value, weekNum: getSummaryWeek.value, entries: [{ moduleId: sec.moduleId, content: '', isSummary: true }], status: 'submitted' })
    if (res.status === 'success') {
      msg('success', '已添加模块综述')
      await loadSummary(true)
      nextTick(() => {
        const newSec = summarySections.value.find(s => s.moduleId === sec.moduleId)
        if (newSec && newSec.parentEntries && newSec.parentEntries.length > 0) {
          startBatchEdit(newSec.parentEntries, sec.moduleId, 'parent')
        }
      })
    } else {
      msg('error', res.message || '添加失败')
    }
  } catch (e) {
    msg('error', e.message || '添加失败')
  } finally {
    addingModuleId.value = null
  }
}

// 在汇总页快捷添加子模块综述
const quickAddSubSummaryInSummary = async (sub) => {
  // 通过查找 summarySections 找到父模块的 moduleId 和子模块索引 sj
  let moduleId = null
  let subModuleId = null
  let foundSj = -1
  for (const sec of summarySections.value) {
    const idx = sec.subs.findIndex(s => s === sub)
    if (idx >= 0) {
      moduleId = sec.moduleId
      foundSj = idx
      // 从 entries 或 summaryEntries 中取 subModuleId
      const firstEntry = (sub.entries && sub.entries[0]) || (sub.summaryEntries && sub.summaryEntries[0])
      if (firstEntry) subModuleId = firstEntry.subModuleId
      if (!subModuleId) {
        // 尝试从后端 subGroups 数据取 subModuleId
        const dataGroup = summaryData.value?.moduleGroups?.find(g => g.moduleId === sec.moduleId)
        if (dataGroup) {
          const dataSub = (dataGroup.subGroups || []).find(sg => sg.subModuleName === sub.subName)
          if (dataSub) subModuleId = dataSub.subModuleId
        }
      }
      break
    }
  }
  if (!moduleId || !subModuleId) { msg('warning', '无法获取模块信息'); return }
  if (!username.value) { msg('warning', '无法获取当前用户'); return }
  try {
    skipNextStatusEvent = true
    const res = await saveReport({ username: username.value, weekNum: getSummaryWeek.value, entries: [{ moduleId, subModuleId, content: '', isSummary: true }], status: 'submitted' })
    if (res.status === 'success') {
      msg('success', '已添加子模块综述')
      await loadSummary(true)
      nextTick(() => {
        const newSec = summarySections.value.find(s => s.moduleId === moduleId)
        if (newSec && newSec.subs[foundSj] && newSec.subs[foundSj].summaryEntries.length > 0) {
          startBatchEdit(newSec.subs[foundSj].summaryEntries, moduleId, foundSj + '-summary')
        }
      })
    } else {
      msg('error', res.message || '添加失败')
    }
  } catch (e) {
    msg('error', e.message || '添加失败')
  }
}

// 批量删除子模块下所有记录
const handleDeleteBatch = async (entries) => {
  if (!entries || entries.length === 0) return
  try {
    await ElMessageBox.confirm(`确认删除该模块下所有 ${entries.length} 条周报记录？删除后不可恢复。`, '确认删除', { confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning' })
    for (const entry of entries) { await deleteReport(entry.reportId) }
    msg('success', '已删除'); loadSummary(true)
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '删除失败') }
}
const addLineAfter = (idx) => {
  const ts = nowStr()
  editLines.value.splice(idx + 1, 0, { text: '', updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ })
  editingLineIdx.value = idx + 1
  nextTick(() => focusLine(idx + 1))
}
const moveToPrevLine = (idx) => { if (idx <= 0) return; editingLineIdx.value = idx - 1; nextTick(() => focusLine(idx - 1)) }
const moveToNextLine = (idx) => { if (idx >= editLines.value.length - 1) return; editingLineIdx.value = idx + 1; nextTick(() => focusLine(idx + 1)) }
const deleteLine = (idx) => {
  editLines.value.splice(idx, 1)
  if (editLines.value.length === 0) {
    const ts = nowStr()
    editLines.value.push({ text: '', updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ })
    editingLineIdx.value = 0
    nextTick(() => focusLine(0))
  }
}
const copyLine = async (idx) => { const text = editLines.value[idx].text; clipboardText.value = text; try { await navigator.clipboard.writeText(text) } catch { /* */ }; msg('success', '已复制到剪贴板') }
const pasteLine = async (idx) => {
  let text = clipboardText.value
  if (!text) { try { text = await navigator.clipboard.readText() } catch { /* */ } }
  if (!text) { msg('warning', '剪贴板为空，请先复制'); return }
  if (idx === editingLineIdx.value) {
    const existing = editLines.value[idx].text
    editLines.value[idx].text = existing ? existing + text : text
    msg('success', '已粘贴到当前行')
    nextTick(() => {
      const inputs = document.querySelectorAll('.record-content-lines .line-input-editable')
      if (inputs.length > idx) {
        const el = inputs[idx]
        el.focus()
        const range = document.createRange()
        range.selectNodeContents(el)
        range.collapse(false)
        const sel = window.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
      }
    })
  }
  else { const ts = nowStr(); editLines.value.splice(idx + 1, 0, { text, updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }) }
}

const handleSaveShortcut = () => {
  if (editingKey.value && editingKey.value.startsWith('batch-')) {
    saveBatchEdit()
  }
}

const handleKeydownSave = (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') {
    e.preventDefault()
    handleSaveShortcut()
  }
}

const clearLine = (idx) => { editLines.value[idx].text = ''; nextTick(() => activateLine(idx)) }
const copyLineText = async (text) => { if (!text) return; try { await navigator.clipboard.writeText(text); clipboardText.value = text; msg('success', '已复制到剪贴板') } catch { /* */ } }
const handleLineKeydown = (e, idx) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); handleSaveShortcut(); return }
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); addLineAfter(idx) }
  else if (e.key === 'ArrowUp' && !e.shiftKey) { e.preventDefault(); moveToPrevLine(idx) }
  else if (e.key === 'ArrowDown' && !e.shiftKey) { e.preventDefault(); moveToNextLine(idx) }
}
const saveEdit = async (reportId, engineerId) => {
  if (!editingKey.value) return
  const moduleId = editingModuleId.value
  const ts = nowStr()
  const nonEmpty = editLines.value.filter(l => l.text.trim())
  nonEmpty.forEach(l => { if (!l.updatedBy || l.text !== l._origText) { l.updatedBy = displayName.value; l.updatedAt = ts } })
  const contentStr = JSON.stringify(nonEmpty)
  try {
    const res = await editSummaryContent({ reportId, content: contentStr, username: username.value })
    if (res.status === 'success') {
      const group = summaryData.value?.moduleGroups?.find(g => g.moduleId === moduleId)
      if (group) { const entry = group.entries.find(e => e.engineerId === engineerId); if (entry) entry.content = contentStr }
      msg('success', '内容已更新')
    } else { msg('error', res.message || '更新失败') }
  } catch (e) { msg('error', e.message || '更新失败') }
  editingKey.value = ''; editingModuleId.value = null; editingLineIdx.value = null; editLines.value = []; originalContentLines.value = []
}

const handleDeleteEntry = async (reportId) => {
  try {
    await ElMessageBox.confirm('确认删除该条周报记录？删除后不可恢复。', '确认删除', { confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning' })
    const res = await deleteReport(reportId)
    if (res.status === 'success') { msg('success', '已删除'); loadSummary(true) }
    else { msg('error', res.message || '删除失败') }
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '删除失败') }
}

const handleReturn = async (reportId) => {
  try {
    await ElMessageBox.confirm('退回后该周报将返回给填报人重新编辑，确认退回？', '退回确认', { confirmButtonText: '确认退回', cancelButtonText: '取消', type: 'warning' })
    skipNextStatusEvent = true
    const res = await returnReport(reportId)
    if (res.status === 'success') { msg('success', '已成功退回该周报'); loadSummary(true) }
    else { msg('error', res.message || '退回失败') }
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '退回失败') }
}

const goExportPage = () => { router.push('/weeklyReport/reportExport') }

let summaryRefreshTimer = null
let skipNextStatusEvent = false
const handleSummaryStatusChange = (e) => {
  if (skipNextStatusEvent) { skipNextStatusEvent = false; return }
  const { weekNum } = e.detail
  if (weekNum !== getSummaryWeek.value) return
  if (summaryRefreshTimer) clearTimeout(summaryRefreshTimer)
  summaryRefreshTimer = setTimeout(() => { loadSummary(true); summaryRefreshTimer = null }, 500)
}

// 模块/子模块变更时静默刷新汇总页数据（响应式更新模块列表和状态）
const handleSummaryModuleChange = () => {
  if (summaryRefreshTimer) clearTimeout(summaryRefreshTimer)
  summaryRefreshTimer = setTimeout(() => { loadSummary(true); summaryRefreshTimer = null }, 500)
}

onMounted(async () => {
  // 获取服务端当前周次（防止用户修改本地时间绕过限制）
  try { const sw = await getServerCurrentWeek(); if (sw.code === 200) serverCurrentWeek.value = sw.weekNum } catch { /* 使用本地时间兜底 */ }
  // 获取有效周范围
  await fetchWeekDateRanges(currentYear)
  if (reportModules.value.length === 0) { try { reportModules.value = await getReportModules() } catch (e) { console.warn('加载模块列表失败', e) } }
  await loadSubModules()
  await loadSummary()
  // 默认选中第一个目录项
  nextTick(() => { if (summarySections.value.length > 0) activeSectionKey.value = 'p0' })
  window.addEventListener('weekly-report-status-change', handleSummaryStatusChange)
  window.addEventListener('weekly-report-module-change', handleSummaryModuleChange)
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

onUnmounted(() => {
  window.removeEventListener('weekly-report-status-change', handleSummaryStatusChange)
  window.removeEventListener('weekly-report-module-change', handleSummaryModuleChange)
  if (summaryRefreshTimer) clearTimeout(summaryRefreshTimer)
})

// contenteditable 自定义指令：仅在元素未聚焦时同步文本内容，避免编辑时光标被重置
const vContenteditable = {
  mounted(el, binding) {
    el.textContent = binding.value
    el.addEventListener('paste', handleContentEditablePaste)
  },
  updated(el, binding) {
    if (document.activeElement !== el) {
      el.textContent = binding.value
    }
  },
  unmounted(el) {
    el.removeEventListener('paste', handleContentEditablePaste)
  }
}

const nowStr = () => {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}
</script>

<style scoped>
.report-summary-container .help-btn {
  background: linear-gradient(135deg, #455a64 0%, #607d8b 100%) !important;
  color: #fff !important;
  border: none !important;
  border-radius: 20px !important;
  padding: 6px 20px !important;
  font-weight: 600 !important;
  letter-spacing: 0.5px;
  box-shadow: 0 4px 15px rgba(79,172,254,0.4) !important;
  transition: all 0.3s ease !important;
  font-size: 13px;
}
.report-summary-container .help-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 25px rgba(79,172,254,0.55) !important;
}
.report-summary-container .help-btn:active {
  transform: translateY(0);
}
.report-summary-container .help-btn .btn-icon {
  font-size: 16px;
  vertical-align: -2px;
  margin-right: 4px;
}

.report-summary-container { width: 100%; height: 100%; display: flex; flex-direction: column; background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-shrink: 0; }
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }
.filter-bar { background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed; display: flex; align-items: center; gap: 16px; flex-shrink: 0; margin-bottom: 14px; }
.period-switch { display: flex; align-items: center; }
.week-tag { font-weight: 600; white-space: nowrap; }
.summary-stats { display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; margin-bottom: 14px; min-height: 100px; }
.stat-card { text-align: center; cursor: default; }
.stat-card.clickable { cursor: pointer; }
.stat-card.clickable:hover { box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06); }
.stat-card :deep(.el-card__body) { padding: 14px; display: flex; flex-direction: column; gap: 2px; }
.stat-label { font-size: 12px; color: #909399; font-weight: 500; }
.stat-value { font-size: 26px; font-weight: 700; transition: all 0.3s; }
.stat-number-enter-active, .stat-number-leave-active { transition: all 0.2s; }
.stat-number-enter-from { opacity: 0; transform: translateY(-8px); }
.stat-number-leave-to { opacity: 0; transform: translateY(8px); }
.stat-sub { font-size: 11px; color: #c0c4cc; }
.mod-name-inline { display: inline-flex; align-items: center; gap: 6px; }
.mod-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
.summary-entry { display: flex; gap: 10px; align-items: flex-start; padding: 8px 12px; border-bottom: 1px solid #f5f5f5; }
.summary-entry:last-child { border-bottom: none; }
.entry-info { flex: 1; min-width: 0; }
.entry-toolbar { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.entry-name { display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 600; color: #303133; }
.entry-actions { display: flex; align-items: center; gap: 4px; }
.content-line { display: flex; align-items: flex-start; padding: 4px 6px; border-radius: 4px; transition: background 0.15s; min-height: 32px; }
.content-line.is-idle { cursor: pointer; }
.content-line.is-idle:hover { background: #f5f7fa; }
.content-line.editing.is-active { background: #f0f7ff; }
.line-content { flex: 1; min-width: 0; max-width: 40em; text-indent: 2em; overflow: hidden; position: relative; }
.line-right { flex-shrink: 0; display: flex; align-items: center; gap: 6px; margin-left: 12px; position: relative; z-index: 1; padding-top: 2px; }
.line-num { color: #909399; font-weight: 600; min-width: 24px; text-align: right; flex-shrink: 0; line-height: 1.6; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; margin-right: 6px; }
.line-text { color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; min-height: 22px; }
.line-text.empty-hint { color: #c0c4cc; font-style: italic; }
.line-input-editable { display: inline; outline: none; color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; }
.line-input-editable:empty::before { content: '请输入内容'; color: #c0c4cc; }
.drag-handle { position: absolute; left: 0.1em; top: 5px; cursor: grab; color: #c0c4cc; font-size: 14px; z-index: 1; display: inline-flex; align-items: center; user-select: none; }
.drag-handle:active { cursor: grabbing; }
.sortable-ghost { opacity: 0.4; background: #e8f4ff !important; }
.line-meta { font-size: 11px; color: #c0c4cc; white-space: nowrap; line-height: 1.6; }
.doc-viewer { min-height: 32px; padding: 4px 0; }
.doc-editor { min-height: 32px; padding: 4px 0; }
.doc-empty-text { color: #c0c4cc; font-size: 13px; }
.add-line-btn { display: block; margin-top: 4px; margin-left: 2em; }

/* 无序号模式：隐藏序号 */
.no-line-num .line-num { display: none; }

/* 父模块自身内容区与子模块对齐 */
.doc-parent-content { padding-left: 16px; margin-bottom: 16px; }
.doc-parent-content .doc-sub-header { margin-bottom: 8px; }
.line-hover-actions { display: none; align-items: center; gap: 0; }
.content-line.is-idle:hover .line-hover-actions { display: flex; }
.active-line-actions { display: flex; align-items: center; gap: 0; }
.line-hover-actions .el-button, .active-line-actions .el-button { padding: 2px; }
/* 原始数据参考面板 */
/* 原始数据参考面板：悬浮在编辑区正上方，不占用文档流 */
.edit-wrapper { position: relative; }
.original-ref-panel { position: absolute; top: 8px; right: 0; width: 670px; z-index: 10; background: rgba(255,255,255,0.78); backdrop-filter: blur(6px); border: 1px solid #e8eaed; border-left: 3px solid #bcc0c4; border-radius: 6px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.08); }
.original-ref-header { display: flex; align-items: center; gap: 4px; font-size: 11px; font-weight: 600; color: #909399; padding: 3px 8px; background: #f5f7fa; border-bottom: 1px solid #ebeef5; }
.original-ref-body { padding: 4px 8px; }
.ref-content-line { padding: 1px 0; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; color: #606266; max-width: 40em; text-indent: 2em; }
.ref-content-line > span { vertical-align: middle; }
.ref-content-line > span:last-child { margin-left: 10px !important; }
.ref-content-line .line-num { color: #c0c4cc; margin-right: 6px; display: inline; user-select: none; }
.ref-content-line .line-text { color: #606266; display: inline; }
.no-record { color: #d0d4d8; border-left-color: #e4e7ed !important; }
.doc-h3.no-record { color: #d0d4d8; }
:deep(.el-scrollbar__wrap) { overflow-x: hidden; }
:deep(.el-scrollbar__view) { overflow-x: hidden; }
.doc-layout { flex: 1; min-height: 0; display: flex; gap: 16px; overflow: hidden; }
.doc-toc { width: 240px; flex-shrink: 0; border-right: 1px solid #e4e7ed; overflow: hidden; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; }
.toc-title { font-size: 14px; font-weight: 700; color: #303133; padding: 8px 4px 12px; border-bottom: 2px solid #409eff; margin-bottom: 8px; letter-spacing: 4px; }
.toc-block { margin-bottom: 4px; }
.toc-parent { font-size: 12px; font-weight: 600; color: #303133; padding: 6px 4px; cursor: pointer; border-radius: 4px; display: flex; align-items: center; gap: 4px; transition: all 0.15s; white-space: nowrap; }
.toc-parent:hover { background: #f0f7ff; color: #409eff; }
.toc-parent.active { background: #ecf5ff; color: #409eff; font-weight: 700; }
.toc-child { font-size: 12px; color: #606266; padding: 4px 4px 4px 12px; cursor: pointer; border-radius: 4px; transition: all 0.15s; white-space: nowrap; }
.toc-child:hover { background: #f0f7ff; color: #409eff; }
.toc-child.active { background: #ecf5ff; color: #409eff; font-weight: 600; }
.toc-parent.disabled { color: #c0c4cc; }
.toc-parent.disabled:hover { background: #f0f7ff; color: #c0c4cc; }
.toc-child.disabled { color: #d0d4d8; }
.toc-child.disabled:hover { background: #f0f7ff; color: #d0d4d8; }
.doc-body { flex: 1; overflow: hidden; display: flex; flex-direction: column; }
.doc-pages { flex: 1; background: #fff; }
.doc-pages-view { max-width: 21cm; margin: 0 auto; padding: 0 2.6cm 40px 2.8cm; }
.doc-section { margin-bottom: 24px; }
.doc-h2 { font-size: 16px; font-weight: 700; color: #303133; margin: 0 0 12px; padding: 8px 0 8px 12px; border-left: 4px solid #409eff; line-height: 1.4; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; scroll-margin-top: 16px; }
.doc-h2-with-actions { display: flex; align-items: center; gap: 12px; }
.doc-h2-btns { display: flex; align-items: center; gap: 2px; }
.doc-sub-section { margin-bottom: 16px; padding-left: 16px; }
.doc-sub-header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.doc-sub-actions { margin-left: auto; display: flex; align-items: center; gap: 4px; flex-shrink: 0; }
.doc-h3 { font-size: 14px; font-weight: 600; color: #606266; margin: 0; padding: 4px 0; line-height: 1.5; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; scroll-margin-top: 16px; }
.empty-summary {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 40px;
}
.loading-mask { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; color: #909399; font-size: 14px; }
.loading-icon { animation: rotating 1.5s linear infinite; }
@keyframes rotating { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.toc-edited-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #67c23a; flex-shrink: 0; vertical-align: middle; margin-right: 4px; }
.toc-unedited-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #c0c4cc; flex-shrink: 0; vertical-align: middle; margin-right: 4px; }
.toc-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; vertical-align: middle; margin-right: 4px; }
</style>

<style>
.remind-confirm-box {
  border-radius: 12px;
  padding: 6px 0;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
}
.remind-confirm-box .el-message-box__header {
  padding: 18px 24px 12px;
}
.remind-confirm-box .el-message-box__title {
  font-size: 16px;
  font-weight: 700;
  color: #303133;
}
.remind-confirm-box .el-message-box__content {
  padding: 12px 24px 20px;
  font-size: 14px;
  line-height: 1.6;
  color: #606266;
}
.remind-confirm-box .el-message-box__btns {
  padding: 12px 24px 18px;
}
.remind-confirm-box .el-message-box__btns .el-button {
  border-radius: 8px;
  padding: 8px 20px;
  font-weight: 600;
}
.remind-confirm-box .el-message-box__btns .el-button--primary {
  background: #e6a23c;
  border-color: #e6a23c;
}
.remind-confirm-box .el-message-box__btns .el-button--primary:hover {
  background: #d4892a;
  border-color: #d4892a;
}
</style>
