<template>
  <div class="report-fill-container">
    <!-- 标题栏 -->
    <div class="page-header">
      <h2 class="page-title">运维周报填写</h2>
      <el-button size="small" class="help-btn" @click="openHelpDoc">
        <span class="btn-icon">📖</span>操作指南
      </el-button>
    </div>

    <!-- Tab 切换 -->
    <el-tabs v-model="activeTab" class="report-tabs" @tab-change="handleTabChange">
      <el-tab-pane label="填写周报" name="fill" />
      <el-tab-pane label="周报记录" name="history" />
    </el-tabs>

    <!-- Tab - 填写周报 -->
    <div v-show="activeTab === 'fill'" class="tab-content">
      <!-- 筛选栏 -->
      <div class="filter-bar">
        <div class="period-switch">
          <el-radio-group v-model="fillWeekKey" size="small" @change="handleWeekChange">
            <el-radio-button :value="'current'">本周 (第{{ currentWeek }}周)</el-radio-button>
            <el-radio-button :value="'custom'">自定义</el-radio-button>
          </el-radio-group>
        </div>
        <el-button size="small" :icon="ArrowLeft" circle @click="navigateWeek(-1)" :disabled="fillWeek <= 1" />
        <el-tag type="primary" effect="light" class="week-tag">{{ weekDateLabel }}</el-tag>
        <el-button size="small" :icon="ArrowRight" circle @click="navigateWeek(1)" :disabled="fillWeek >= currentWeek" />
        <el-select v-if="fillWeekKey === 'custom'" v-model="customWeekNum" size="small" style="width:80px;margin-left:8px;" @change="handleCustomWeekChange">
          <el-option v-for="w in currentWeek" :key="w" :label="'第' + w + '周'" :value="w" />
        </el-select>
        <div class="fill-status-area">
          <el-tag :type="overallStatusType" size="small" effect="light">{{ overallStatusText }}</el-tag>
          <span class="deadline-hint">提交截止：每周五 18:00</span>
        </div>
        <el-button v-if="!editRecordId" type="primary" size="small" @click="openAddDialog" :disabled="fillWeekKey !== 'current'">
          <el-icon><Plus /></el-icon>&nbsp;新增周报
        </el-button>
        <el-button v-if="!editRecordId" type="success" size="small" @click="handleSubmitAllDrafts" :disabled="fillWeekKey !== 'current' || !hasDraftRecords">一键提交所有草稿</el-button>
        <el-button v-if="!editRecordId" type="danger" size="small" @click="handleDeleteAllDrafts" :disabled="fillWeekKey !== 'current' || !hasDraftRecords"><el-icon><Delete /></el-icon>&nbsp;一键删除所有草稿</el-button>
      </div>

      <!-- 文档内容区：展示所有模块，未选模块置灰不可跳转 -->
      <div v-if="activeModules.length === 0" class="doc-empty-hint">
        <el-empty description="本周无已保存的数据" :image-size="80" />
      </div>

      <div v-else-if="loading" class="loading-mask">
        <el-icon class="loading-icon" :size="32"><Loading /></el-icon>
        <span>数据加载中...</span>
      </div>
      <div v-else class="doc-layout">
        <!-- 目录侧边栏 -->
        <el-scrollbar class="doc-toc">
          <div class="toc-title">目 录</div>
          <div v-for="(sec, si) in docSections" :key="'toc-p'+si" class="toc-block">
            <div class="toc-parent"
                 :class="{ active: activeSectionKey === 'p'+si, disabled: !sec.hasRecord }"
                 @click="scrollTo('p'+si)">
              <!-- 无子模块的父模块：综述开启时两者都提交才显示提交色，否则按仅详细内容 -->
              <template v-if="!sec.hasSubModules">
                <template v-if="sec.record || sec.parentRecord">
                  <el-tooltip placement="right" trigger="hover" popper-class="toc-status-tip">
                    <template #content>
                      <span class="tip-label" style="flex-direction:column;align-items:flex-start;gap:2px;">
                        <span v-if="sec.record">
                          <span class="tip-dot" :style="{ background: sec.record.status === 'submitted' ? '#67c23a' : sec.record.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                          <span :style="{ color: sec.record.status === 'submitted' ? '#67c23a' : sec.record.status === 'returned' ? '#e6a23c' : '#909399' }">
                            详细内容: {{ sec.record.status === 'submitted' ? '✓ 已提交' : sec.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                          </span>
                        </span>
                        <span v-if="sec.parentRecord">
                          <span class="tip-dot" :style="{ background: sec.parentRecord.status === 'submitted' ? '#67c23a' : sec.parentRecord.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                          <span :style="{ color: sec.parentRecord.status === 'submitted' ? '#67c23a' : sec.parentRecord.status === 'returned' ? '#e6a23c' : '#909399' }">
                            综述: {{ sec.parentRecord.status === 'submitted' ? '✓ 已提交' : sec.parentRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                          </span>
                        </span>
                      </span>
                    </template>
                    <span class="toc-status-dot" :style="{ background: getParentModuleTocColor(sec) }"></span>
                  </el-tooltip>
                </template>
                <span v-else class="toc-status-dot" style="background:transparent"></span>
              </template>
              <!-- 有子模块的父模块：综合所有子模块+综述的状态 -->
              <template v-else>
                <template v-if="sec.parentRecord || sec.subs.some(s => s.hasRecord || s.hasSummaryRecord)">
                  <el-tooltip placement="right" trigger="hover" popper-class="toc-status-tip">
                    <template #content>
                      <span class="tip-label" style="flex-direction:column;align-items:flex-start;gap:2px;">
                        <span v-if="sec.parentRecord">
                          <span class="tip-dot" :style="{ background: sec.parentRecord.status === 'submitted' ? '#67c23a' : sec.parentRecord.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                          <span :style="{ color: sec.parentRecord.status === 'submitted' ? '#67c23a' : sec.parentRecord.status === 'returned' ? '#e6a23c' : '#909399' }">
                            综述: {{ sec.parentRecord.status === 'submitted' ? '✓ 已提交' : sec.parentRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                          </span>
                        </span>
                        <span v-for="(sub, ti) in sec.subs" :key="ti">
                          <span v-if="sub.hasRecord" class="tip-dot" :style="{ background: sub.record.status === 'submitted' ? '#67c23a' : sub.record.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                          <span v-if="sub.hasRecord" :style="{ color: sub.record.status === 'submitted' ? '#67c23a' : sub.record.status === 'returned' ? '#e6a23c' : '#909399' }">
                            {{ sub.subName }}: {{ sub.record.status === 'submitted' ? '✓ 已提交' : sub.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                          </span>
                          <span v-if="sub.hasSummaryRecord" class="tip-dot" :style="{ background: sub.summaryRecord.status === 'submitted' ? '#67c23a' : sub.summaryRecord.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                          <span v-if="sub.hasSummaryRecord" :style="{ color: sub.summaryRecord.status === 'submitted' ? '#67c23a' : sub.summaryRecord.status === 'returned' ? '#e6a23c' : '#909399' }">
                            {{ sub.subName }}综述: {{ sub.summaryRecord.status === 'submitted' ? '✓ 已提交' : sub.summaryRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                          </span>
                        </span>
                      </span>
                    </template>
                    <span class="toc-status-dot" :style="{ background: getParentModuleTocColor(sec) }"></span>
                  </el-tooltip>
                </template>
                <span v-else class="toc-status-dot" style="background:transparent"></span>
              </template>
              {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
            </div>
            <div v-for="(sub, sj) in sec.subs" :key="'toc-s'+si+'-'+sj"
                 class="toc-child" :class="{ active: activeSectionKey === 's'+si+'-'+sj, disabled: !sub.hasRecord && !sub.hasSummaryRecord }"
                 @click="scrollTo('s'+si+'-'+sj)">
              <el-tooltip v-if="sub.hasRecord || sub.hasSummaryRecord" placement="right" trigger="hover" popper-class="toc-status-tip">
                <template #content>
                  <span class="tip-label" style="flex-direction:column;align-items:flex-start;gap:2px;">
                    <span v-if="sub.record">
                      <span class="tip-dot" :style="{ background: sub.record.status === 'submitted' ? '#67c23a' : sub.record.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                      <span :style="{ color: sub.record.status === 'submitted' ? '#67c23a' : sub.record.status === 'returned' ? '#e6a23c' : '#909399' }">
                        详细内容: {{ sub.record.status === 'submitted' ? '✓ 已提交' : sub.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                      </span>
                    </span>
                    <span v-if="sub.summaryRecord">
                      <span class="tip-dot" :style="{ background: sub.summaryRecord.status === 'submitted' ? '#67c23a' : sub.summaryRecord.status === 'returned' ? '#e6a23c' : '#909399' }"></span>
                      <span :style="{ color: sub.summaryRecord.status === 'submitted' ? '#67c23a' : sub.summaryRecord.status === 'returned' ? '#e6a23c' : '#909399' }">
                        综述: {{ sub.summaryRecord.status === 'submitted' ? '✓ 已提交' : sub.summaryRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                      </span>
                    </span>
                  </span>
                </template>
                <span class="toc-status-dot" :style="{ background: getSubTocColor(sub) }"></span>
              </el-tooltip>
              <span v-else class="toc-status-dot" style="background:transparent"></span>
              （{{ chineseNum(sj + 1) }}）{{ sub.subName }}
            </div>
          </div>
        </el-scrollbar>

        <!-- 文档正文 -->
        <div class="doc-body" ref="docBodyRef">
          <el-scrollbar ref="docPagesScrollbar" class="doc-pages" view-class="doc-pages-view" @scroll="onDocScroll">
            <div v-for="(sec, si) in docSections" :key="'sec'+si"
                 :ref="el => { registerSection('p'+si, el) }" class="doc-section">

              <!-- ===== 无子模块的父模块：综述 + 序号行并列 ===== -->
              <template v-if="!sec.hasSubModules">
                <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                  {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
                </h2>

                <!-- ===== 模块综述（无序号） ===== -->
                <div v-if="summaryFillerEnabled || sec.hasParentRecord" class="doc-parent-content">
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !sec.parentRecord }">模块综述</h3>
                    <el-tag v-if="sec.parentRecord" :type="sec.parentRecord.status === 'submitted' ? 'success' : sec.parentRecord.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                      {{ sec.parentRecord.status === 'submitted' ? '✓ 已提交' : sec.parentRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                    </el-tag>
                    <el-tag v-if="sec.filledLastWeek" size="small" type="warning" effect="plain" style="margin-left:4px;">上周填写</el-tag>
                    <div v-if="sec.parentRecord && editRecordId !== sec.parentRecord.id && fillWeekKey === 'current'" class="doc-sub-actions">
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="primary" text @click="startInlineEdit(sec.parentRecord)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="success" text @click="handleSubmitSingleRecord(sec.parentRecord)" :disabled="!parseLines(sec.parentRecord.content).length"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交</el-button>
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="danger" text @click="handleDeleteRecord(sec.parentRecord.id)"><el-icon><Delete /></el-icon>&nbsp;删除</el-button>
                    </div>
                    <div v-if="sec.parentRecord && editRecordId === sec.parentRecord.id" class="doc-sub-actions">
                      <el-button size="small" @click="cancelInlineEdit">取消</el-button>
                      <el-button size="small" type="primary" @click="saveInlineEdit(sec.parentRecord.id)"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存</el-button>
                    </div>
                  </div>
                  <template v-if="sec.parentRecord">
                    <div class="doc-content-area">
                      <div v-if="editRecordId && editRecordId === sec.parentRecord.id" class="doc-editor">
                        <div class="record-content-lines no-line-num">
                          <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                            <div class="line-content" @click="onLineContentClick(li, $event)">
                              <el-icon class="drag-handle"><Rank /></el-icon>
                              <div
                                class="line-input-editable"
                                contenteditable="true"
                                v-contenteditable="line.text"
                                @input="onEditableInput(li, $event)"
                                @focus="activateLine(li)"
                                @blur="onEditableBlur(li)"
                                @keydown="handleLineKeydown($event, li)"
                              ></div>
                            </div>
                            <div class="line-right">
                              <div class="active-line-actions">
                                <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                              </div>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                          <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                        </div>
                      </div>
                      <div v-else class="doc-viewer">
                        <template v-if="parseLines(sec.parentRecord.content).length > 0">
                          <div v-for="(line, li) in parseLines(sec.parentRecord.content)" :key="li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.parentRecord, li)">
                            <div class="line-content">
                              <span class="line-text">{{ line.text }}</span>
                            </div>
                            <div class="line-right">
                              <span class="line-hover-actions">
                                <el-button size="small" text @click.stop="copyLineText(line.text)" title="复制"><el-icon><CopyDocument /></el-icon></el-button>
                              </span>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                        </template>
                        <span v-else class="doc-empty-text">暂未填写</span>
                      </div>
                    </div>
                  </template>
                  <template v-else>
                    <div v-if="fillWeekKey === 'current'" class="doc-viewer" style="cursor: pointer;" @click="quickAddParentModule(sec)">
                      <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加模块综述</span>
                    </div>
                    <div v-else class="doc-viewer">
                      <span class="doc-empty-text">暂未填写</span>
                    </div>
                  </template>
                </div>

                <!-- ===== 序号行周报 ===== -->
                <div class="doc-sub-section">
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !sec.record }">详细内容</h3>
                    <el-tag v-if="sec.record" :type="sec.record.status === 'submitted' ? 'success' : sec.record.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                      {{ sec.record.status === 'submitted' ? '✓ 已提交' : sec.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                    </el-tag>
                    <el-tag v-if="sec.filledLastWeek" size="small" type="warning" effect="plain" style="margin-left:4px;">上周填写</el-tag>
                    <div v-if="sec.record && editRecordId !== sec.record.id && fillWeekKey === 'current'" class="doc-sub-actions">
                      <el-button v-if="sec.record.status !== 'submitted'" size="small" type="primary" text @click="startInlineEdit(sec.record)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                      <el-button v-if="sec.record.status !== 'submitted'" size="small" type="success" text @click="handleSubmitSingleRecord(sec.record)" :disabled="!parseLines(sec.record.content).length"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交</el-button>
                      <el-button v-if="sec.record.status !== 'submitted'" size="small" type="danger" text @click="handleDeleteRecord(sec.record.id)"><el-icon><Delete /></el-icon>&nbsp;删除</el-button>
                    </div>
                    <div v-if="sec.record && editRecordId === sec.record.id" class="doc-sub-actions">
                      <el-button size="small" @click="cancelInlineEdit">取消</el-button>
                      <el-button size="small" type="primary" @click="saveInlineEdit(sec.record.id)"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存</el-button>
                    </div>
                  </div>
                  <template v-if="sec.record">
                    <div class="doc-content-area">
                      <div v-if="editRecordId && editRecordId === sec.record.id" class="doc-editor">
                        <div class="record-content-lines">
                          <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                            <div class="line-content" @click="onLineContentClick(li, $event)">
                              <el-icon class="drag-handle"><Rank /></el-icon>
                              <span class="line-num" v-if="editLines.length > 1">({{ li + 1 }})</span>
                              <div
                                class="line-input-editable"
                                contenteditable="true"
                                v-contenteditable="line.text"
                                @input="onEditableInput(li, $event)"
                                @focus="activateLine(li)"
                                @keydown="handleLineKeydown($event, li)"
                              ></div>
                            </div>
                            <div class="line-right">
                              <div class="active-line-actions">
                                <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                              </div>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                          <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                        </div>
                      </div>
                      <div v-else class="doc-viewer">
                        <template v-if="parseLines(sec.record.content).length > 0">
                          <div v-for="(line, li) in parseLines(sec.record.content)" :key="li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.record, li)">
                            <div class="line-content">
                              <span class="line-num" v-if="parseLines(sec.record.content).length > 1">({{ li + 1 }})</span>
                              <span class="line-text">{{ line.text }}</span>
                            </div>
                            <div class="line-right">
                              <span class="line-hover-actions">
                                <el-button size="small" text @click.stop="copyLineText(line.text)" title="复制"><el-icon><CopyDocument /></el-icon></el-button>
                              </span>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                        </template>
                        <span v-else class="doc-empty-text">暂未填写</span>
                      </div>
                    </div>
                  </template>
                  <template v-else>
                    <div v-if="fillWeekKey === 'current'" class="doc-viewer" style="cursor: pointer;" @click="quickAddModule(sec)">
                      <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加详细内容</span>
                    </div>
                    <div v-else class="doc-viewer">
                      <span class="doc-empty-text">暂未填写</span>
                    </div>
                  </template>
                </div>
              </template>

              <!-- ===== 有子模块的父模块 ===== -->
              <template v-else>
                <h2 class="doc-h2" :class="{ 'no-record': !sec.hasRecord }" :style="{ borderLeftColor: sec.moduleColor }">
                  {{ chineseNum(si + 1) }}、{{ sec.moduleName }}
                </h2>

                <!-- ===== 父模块自身内容区（与子模块并列，无序号） ===== -->
                <div v-if="summaryFillerEnabled || sec.hasParentRecord" class="doc-parent-content">
                  <!-- 父模块标题行 + 操作按钮 -->
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !sec.parentRecord }">
                      模块综述
                    </h3>
                    <el-tag v-if="sec.parentRecord" :type="sec.parentRecord.status === 'submitted' ? 'success' : sec.parentRecord.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                      {{ sec.parentRecord.status === 'submitted' ? '✓ 已提交' : sec.parentRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                    </el-tag>
                    <el-tag v-if="sec.parentFilledLastWeek" size="small" type="warning" effect="plain" style="margin-left:4px;">上周填写</el-tag>
                    <!-- 操作按钮：非编辑态 -->
                    <div v-if="sec.parentRecord && editRecordId !== sec.parentRecord.id && fillWeekKey === 'current'" class="doc-sub-actions">
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="primary" text @click="startInlineEdit(sec.parentRecord)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="success" text @click="handleSubmitSingleRecord(sec.parentRecord)" :disabled="!parseLines(sec.parentRecord.content).length"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交</el-button>
                      <el-button v-if="sec.parentRecord.status !== 'submitted'" size="small" type="danger" text @click="handleDeleteRecord(sec.parentRecord.id)"><el-icon><Delete /></el-icon>&nbsp;删除</el-button>
                    </div>
                    <!-- 操作按钮：编辑态 -->
                    <div v-if="sec.parentRecord && editRecordId === sec.parentRecord.id" class="doc-sub-actions">
                      <el-button size="small" @click="cancelInlineEdit">取消</el-button>
                      <el-button size="small" type="primary" @click="saveInlineEdit(sec.parentRecord.id)"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存</el-button>
                    </div>
                  </div>

                  <!-- 有记录：内容编辑/查看（无序号） -->
                  <template v-if="sec.parentRecord">
                    <div class="doc-content-area">
                      <!-- 编辑态 -->
                      <div v-if="editRecordId && editRecordId === sec.parentRecord.id" class="doc-editor">
                        <div class="record-content-lines no-line-num">
                          <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                            <div class="line-content" @click="onLineContentClick(li, $event)">
                              <el-icon class="drag-handle"><Rank /></el-icon>
                              <div
                                class="line-input-editable"
                                contenteditable="true"
                                v-contenteditable="line.text"
                                @input="onEditableInput(li, $event)"
                                @focus="activateLine(li)"
                                @blur="onEditableBlur(li)"
                                @keydown="handleLineKeydown($event, li)"
                              ></div>
                            </div>
                            <div class="line-right">
                              <div class="active-line-actions">
                                <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                              </div>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                          <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                        </div>
                      </div>

                      <!-- 非编辑态（无序号） -->
                      <div v-else class="doc-viewer">
                        <template v-if="parseLines(sec.parentRecord.content).length > 0">
                          <div v-for="(line, li) in parseLines(sec.parentRecord.content)" :key="li" class="content-line is-idle" @dblclick="onViewLineDblClick(sec.parentRecord, li)">
                            <div class="line-content">
                              <span class="line-text">{{ line.text }}</span>
                            </div>
                            <div class="line-right">
                              <span class="line-hover-actions">
                                <el-button size="small" text @click.stop="copyLineText(line.text)" title="复制"><el-icon><CopyDocument /></el-icon></el-button>
                              </span>
                              <span class="line-meta">{{ line.updatedAt }}</span>
                            </div>
                          </div>
                        </template>
                        <span v-else class="doc-empty-text">暂未填写</span>
                      </div>
                    </div>
                  </template>

                  <!-- 无记录：可添加 -->
                  <template v-else>
                    <div v-if="fillWeekKey === 'current'" class="doc-viewer" style="cursor: pointer;" @click="quickAddParentModule(sec)">
                      <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加模块综述</span>
                    </div>
                    <div v-else class="doc-viewer">
                      <span class="doc-empty-text">暂未填写</span>
                    </div>
                  </template>
                </div>

                <!-- 子模块 -->
                <div v-for="(sub, sj) in sec.subs" :key="'sub'+si+'-'+sj"
                     :ref="el => { registerSection('s'+si+'-'+sj, el) }" class="doc-sub-section">
                  <!-- 子模块标题行 -->
                  <div class="doc-sub-header">
                    <h3 class="doc-h3" :class="{ 'no-record': !sub.record }">
                      （{{ chineseNum(sj + 1) }}）{{ sub.subName }}
                    </h3>
                    <el-tag v-if="sub.record" :type="sub.record.status === 'submitted' ? 'success' : sub.record.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                      {{ sub.record.status === 'submitted' ? '✓ 已提交' : sub.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                    </el-tag>
                  </div>

                  <!-- ===== 子模块综述（无序号） ===== -->
                  <div v-if="summaryFillerEnabled || sub.hasSummaryRecord" class="doc-parent-content">
                    <div class="doc-sub-header">
                      <h3 class="doc-h3" :class="{ 'no-record': !sub.summaryRecord }">模块综述</h3>
                      <el-tag v-if="sub.summaryRecord" :type="sub.summaryRecord.status === 'submitted' ? 'success' : sub.summaryRecord.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                        {{ sub.summaryRecord.status === 'submitted' ? '✓ 已提交' : sub.summaryRecord.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                      </el-tag>
                      <el-tag v-if="sub.filledLastWeek" size="small" type="warning" effect="plain" style="margin-left:4px;">上周填写</el-tag>
                      <div v-if="sub.summaryRecord && editRecordId !== sub.summaryRecord.id && fillWeekKey === 'current'" class="doc-sub-actions">
                        <el-button v-if="sub.summaryRecord.status !== 'submitted'" size="small" type="primary" text @click="startInlineEdit(sub.summaryRecord)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                        <el-button v-if="sub.summaryRecord.status !== 'submitted'" size="small" type="success" text @click="handleSubmitSingleRecord(sub.summaryRecord)" :disabled="!parseLines(sub.summaryRecord.content).length"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交</el-button>
                        <el-button v-if="sub.summaryRecord.status !== 'submitted'" size="small" type="danger" text @click="handleDeleteRecord(sub.summaryRecord.id)"><el-icon><Delete /></el-icon>&nbsp;删除</el-button>
                      </div>
                      <div v-if="sub.summaryRecord && editRecordId === sub.summaryRecord.id" class="doc-sub-actions">
                        <el-button size="small" @click="cancelInlineEdit">取消</el-button>
                        <el-button size="small" type="primary" @click="saveInlineEdit(sub.summaryRecord.id)"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存</el-button>
                      </div>
                    </div>
                    <template v-if="sub.summaryRecord">
                      <div class="doc-content-area">
                        <div v-if="editRecordId && editRecordId === sub.summaryRecord.id" class="doc-editor">
                          <div class="record-content-lines no-line-num">
                            <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                              <div class="line-content" @click="onLineContentClick(li, $event)">
                                <el-icon class="drag-handle"><Rank /></el-icon>
                                <div
                                  class="line-input-editable"
                                  contenteditable="true"
                                  v-contenteditable="line.text"
                                  @input="onEditableInput(li, $event)"
                                  @focus="activateLine(li)"
                                  @blur="onEditableBlur(li)"
                                  @keydown="handleLineKeydown($event, li)"
                                ></div>
                              </div>
                              <div class="line-right">
                                <div class="active-line-actions">
                                  <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                                </div>
                                <span class="line-meta">{{ line.updatedAt }}</span>
                              </div>
                            </div>
                            <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                          </div>
                        </div>
                        <div v-else class="doc-viewer">
                          <template v-if="parseLines(sub.summaryRecord.content).length > 0">
                            <div v-for="(line, li) in parseLines(sub.summaryRecord.content)" :key="li" class="content-line is-idle" @dblclick="onViewLineDblClick(sub.summaryRecord, li)">
                              <div class="line-content">
                                <span class="line-text">{{ line.text }}</span>
                              </div>
                              <div class="line-right">
                                <span class="line-hover-actions">
                                  <el-button size="small" text @click.stop="copyLineText(line.text)" title="复制"><el-icon><CopyDocument /></el-icon></el-button>
                                </span>
                                <span class="line-meta">{{ line.updatedAt }}</span>
                              </div>
                            </div>
                          </template>
                          <span v-else class="doc-empty-text">暂未填写</span>
                        </div>
                      </div>
                    </template>
                    <template v-else>
                      <div v-if="fillWeekKey === 'current'" class="doc-viewer" style="cursor: pointer;" @click="quickAddSubSummary(sub)">
                        <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加子模块综述</span>
                      </div>
                      <div v-else class="doc-viewer">
                        <span class="doc-empty-text">暂未填写</span>
                      </div>
                    </template>
                  </div>

                  <!-- ===== 子模块详细内容（有序号） ===== -->
                  <div class="doc-sub-section">
                    <div class="doc-sub-header">
                      <h3 class="doc-h3" :class="{ 'no-record': !sub.record }">详细内容</h3>
                      <el-tag v-if="sub.record" :type="sub.record.status === 'submitted' ? 'success' : sub.record.status === 'returned' ? 'warning' : 'info'" size="small" effect="light">
                        {{ sub.record.status === 'submitted' ? '✓ 已提交' : sub.record.status === 'returned' ? '⚠ 已退回' : '草稿' }}
                      </el-tag>
                      <el-tag v-if="sub.filledLastWeek" size="small" type="warning" effect="plain" style="margin-left:4px;">上周填写</el-tag>
                      <div v-if="sub.record && editRecordId !== sub.record.id && fillWeekKey === 'current'" class="doc-sub-actions">
                        <el-button v-if="sub.record.status !== 'submitted'" size="small" type="primary" text @click="startInlineEdit(sub.record)"><el-icon><Edit /></el-icon>&nbsp;编辑</el-button>
                        <el-button v-if="sub.record.status !== 'submitted'" size="small" type="success" text @click="handleSubmitSingleRecord(sub.record)" :disabled="!parseLines(sub.record.content).length"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;提交</el-button>
                        <el-button v-if="sub.record.status !== 'submitted'" size="small" type="danger" text @click="handleDeleteRecord(sub.record.id)"><el-icon><Delete /></el-icon>&nbsp;删除</el-button>
                      </div>
                      <div v-if="sub.record && editRecordId === sub.record.id" class="doc-sub-actions">
                        <el-button size="small" @click="cancelInlineEdit">取消</el-button>
                        <el-button size="small" type="primary" @click="saveInlineEdit(sub.record.id)"><el-icon style="margin-right:2px;"><Select /></el-icon>&nbsp;保存</el-button>
                      </div>
                    </div>
                    <template v-if="sub.record">
                      <div class="doc-content-area">
                        <div v-if="editRecordId && editRecordId === sub.record.id" class="doc-editor">
                          <div class="record-content-lines">
                            <div v-for="(line, li) in editLines" :key="line._uid" class="content-line editing" :class="{ 'is-active': editingLineIdx === li }">
                              <div class="line-content" @click="onLineContentClick(li, $event)">
                                <el-icon class="drag-handle"><Rank /></el-icon>
                                <span class="line-num" v-if="editLines.length > 1">({{ li + 1 }})</span>
                                <div
                                  class="line-input-editable"
                                  contenteditable="true"
                                  v-contenteditable="line.text"
                                  @input="onEditableInput(li, $event)"
                                  @focus="activateLine(li)"
                                  @blur="onEditableBlur(li)"
                                  @keydown="handleLineKeydown($event, li)"
                                ></div>
                              </div>
                              <div class="line-right">
                                <div class="active-line-actions">
                                  <el-button size="small" text @click.stop="pasteLine(li)" title="粘贴"><el-icon><DocumentCopy /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="clearLine(li)" title="清空内容"><el-icon><Close /></el-icon></el-button>
                                  <el-button size="small" text @click.stop="deleteLine(li)" title="删除整行"><el-icon><Delete /></el-icon></el-button>
                                </div>
                                <span class="line-meta">{{ line.updatedAt }}</span>
                              </div>
                            </div>
                            <el-button size="small" text type="primary" class="add-line-btn" @click="addLineAfter(editLines.length - 1)" title="新增一行"><el-icon><Plus /></el-icon>&nbsp;添加行</el-button>
                          </div>
                        </div>

                        <div v-else class="doc-viewer">
                          <template v-if="parseLines(sub.record.content).length > 0">
                            <div v-for="(line, li) in parseLines(sub.record.content)" :key="li" class="content-line is-idle" @dblclick="onViewLineDblClick(sub.record, li)">
                              <div class="line-content">
                                <span class="line-num" v-if="parseLines(sub.record.content).length > 1">({{ li + 1 }})</span>
                                <span class="line-text">{{ line.text }}</span>
                              </div>
                              <div class="line-right">
                                <span class="line-hover-actions">
                                  <el-button size="small" text @click.stop="copyLineText(line.text)" title="复制"><el-icon><CopyDocument /></el-icon></el-button>
                                </span>
                                <span class="line-meta">{{ line.updatedAt }}</span>
                              </div>
                            </div>
                          </template>
                          <span v-else class="doc-empty-text">暂未填写</span>
                        </div>
                      </div>
                    </template>
                    <template v-else>
                      <div v-if="fillWeekKey === 'current'" class="doc-viewer" style="cursor: pointer;" @click="quickAddSub(sub)">
                        <span class="doc-empty-text" style="cursor: pointer;"><el-icon style="font-size:13px;vertical-align:-1px;margin-right:2px;"><Plus /></el-icon>点击添加详细内容</span>
                      </div>
                      <div v-else class="doc-viewer">
                        <span class="doc-empty-text">暂未填写</span>
                      </div>
                    </template>
                  </div>
                </div>
              </template>
            </div>
          </el-scrollbar>
        </div>
      </div>
    </div>

    <!-- Tab - 周报记录 -->
    <div v-show="activeTab === 'history'" class="tab-content history-content">
      <el-scrollbar class="history-scroll-wrap">
        <div class="history-stats">
          <el-card v-for="stat in historyStats" :key="stat.label" shadow="never" class="stat-card">
            <div class="stat-label">{{ stat.label }}</div>
            <div class="stat-value" :style="{ color: stat.color }">{{ stat.value }}</div>
            <div class="stat-sub">{{ stat.sub }}</div>
          </el-card>
        </div>

        <el-card shadow="never" class="history-list-card">
          <template #header>
            <div class="history-list-header">
              <span class="section-title"><el-icon><Clock /></el-icon>历史周报记录</span>
              <span class="history-count">共 {{ historyList.length }} 条记录</span>
            </div>
          </template>
          <div v-if="historyList.length === 0" class="history-empty"><el-empty description="暂无周报记录" :image-size="80" /></div>
          <el-timeline v-else>
            <el-timeline-item v-for="item in historyList" :key="item.weekNum" :type="item.hasSubmitted ? 'success' : 'warning'" :hollow="!item.hasSubmitted">
              <el-card shadow="hover" class="history-card">
                <div class="history-card-header">
                  <div class="history-week-info">
                    <span class="history-week-num">第{{ item.weekNum }}周</span>
                    <span class="history-week-date">{{ item.dateRange }}</span>
                    <el-tag v-if="item.weekNum === currentWeek" size="small" type="primary" effect="light">当前周</el-tag>
                  </div>
                  <div class="history-meta">
                    <el-tag :type="item.hasSubmitted ? 'success' : 'warning'" size="small" effect="light">{{ item.hasSubmitted ? '✓ 已提交' : '草稿' }}</el-tag>
                    <span class="module-count-badge">{{ item.records.length }} 条记录</span>
                    <el-button size="small" type="primary" @click.stop="goFillWeek(item.weekNum)">查看</el-button>
                  </div>
                </div>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-card>
      </el-scrollbar>
    </div>

    <!-- 新增周报对话框 -->
    <el-dialog v-model="addDialogVisible" title="新增周报" width="800px" :close-on-click-modal="false" @closed="resetAddForm">
      <el-scrollbar max-height="700px">
        <div class="add-form two-column-layout">
          <div class="add-form-column left-column">
            <div class="add-form-row">
              <div class="add-form-label-row">
                <span class="add-form-label">选择父模块</span>
                <el-button v-if="allSelectableModuleIds.length > 0" size="small" text type="primary" @click="toggleAllModules">{{ isAllModulesSelected ? '取消全选' : '全选' }}</el-button>
              </div>
              <div class="module-selector vertical">
                <div v-for="mod in activeModules" :key="mod.id" class="module-tag" :class="{ selected: addForm.moduleIds.includes(mod.id), disabled: isModuleFullySelected(mod.id) }" @click="!isModuleFullySelected(mod.id) && toggleAddModule(mod.id)">
                  <span class="tag-dot" :style="{ background: mod.color }"></span>
                  <span class="module-tag-name">{{ mod.name }}</span>
                  <el-tag v-if="isModuleFullySelected(mod.id)" size="small" type="info" effect="plain" style="margin-left:auto;">已有</el-tag>
                </div>
              </div>
            </div>
          </div>
          <div class="add-form-column right-column">
            <div class="add-form-row">
              <span class="add-form-label">选择子模块（可选）</span>
              <div v-if="selectedModuleSubs.length > 0" class="module-selector vertical">
                <div v-for="group in selectedModuleSubs" :key="'g_'+group.moduleId" class="sub-module-group">
                  <div class="sub-group-label">
                    <span class="tag-dot" :style="{ background: group.moduleColor }"></span>
                    {{ group.moduleName }}
                    <el-button size="small" text type="primary" class="sub-select-all-btn" @click="toggleAllSubModulesForModule(group.moduleId)">{{ isGroupAllSelected(group.moduleId) ? '取消全选' : '全选' }}</el-button>
                  </div>
                  <div v-for="sub in group.subs" :key="sub.id" class="module-tag sub-tag" :class="{ selected: addForm.subModuleIds.includes(sub.id), disabled: existingSubModuleIds.includes(sub.id) }" @click="!existingSubModuleIds.includes(sub.id) && toggleAddSubModule(sub.id)">
                    {{ sub.name }}
                    <el-tag v-if="existingSubModuleIds.includes(sub.id)" size="small" type="info" effect="plain" style="margin-left:auto;">已有</el-tag>
                  </div>
                </div>
              </div>
              <div v-else class="no-sub-hint">请先选择父模块</div>
            </div>
          </div>
        </div>
      </el-scrollbar>
      <template #footer>
        <el-button @click="addDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleAddConfirm">确认新增</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import Sortable from 'sortablejs'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Edit, Delete, Clock, CopyDocument, DocumentCopy, Select, Close, ArrowLeft, ArrowRight, Rank, Loading, Reading } from '@element-plus/icons-vue'
import { usePermissionStore } from '@/stores/permissionStore'
import { getReportModules, saveReport, getMyReports, updateReport, deleteReport, submitAllDrafts, getWeekConfig, getReportSubModules, getServerCurrentWeek } from '@/api/weeklyReportApi'
import { reportModules, getCurrentWeek, getWeekDateRange, fmtDateCN, setWeekConfig, serverCurrentWeek, fetchWeekDateRanges, summaryFillerEnabled } from '@/utils/weeklyReportData'
import { getSummaryFillerConfig } from '@/api/weeklyReportApi'
import { onBeforeRouteLeave } from 'vue-router'

const msg = (type, content) => { ElMessage.closeAll(); ElMessage[type](content) }
const openHelpDoc = () => window.open('/运维周报模块操作文档.html')
const permissionStore = usePermissionStore()
const username = computed(() => permissionStore.userInfo?.username || '')
const nickname = computed(() => permissionStore.userInfo?.nickname || '')

const currentWeek = getCurrentWeek()
const currentYear = new Date().getFullYear()
const fillWeekKey = ref('current')
const customWeekNum = ref(currentWeek)
const activeTab = ref('fill')
const records = ref([])
const loading = ref(true)

// 最近有效周的上周已提交记录，用于标记“上周填写”标签
const lastWeekRecords = ref([])
const lastWeekFilledModuleSet = computed(() => {
  const set = new Set()
  lastWeekRecords.value.forEach(r => { if (r.status === 'submitted') set.add(r.moduleId) })
  return set
})
const lastWeekFilledParentSet = computed(() => {
  const set = new Set()
  lastWeekRecords.value.forEach(r => { if (r.status === 'submitted' && !r.subModuleId) set.add(r.moduleId) })
  return set
})
const lastWeekFilledSubModuleSet = computed(() => {
  const set = new Set()
  lastWeekRecords.value.forEach(r => { if (r.status === 'submitted' && r.subModuleId) set.add(r.subModuleId) })
  return set
})
const addDialogVisible = ref(false)
const addForm = ref({ moduleIds: [], subModuleIds: [] })

const selectedModuleSubs = computed(() => {
  if (addForm.value.moduleIds.length === 0) return []
  return activeModules.value.filter(mod => addForm.value.moduleIds.includes(mod.id) && getSubModulesForModule(mod.id).length > 0).map(mod => ({ moduleId: mod.id, moduleName: mod.name, moduleColor: mod.color, subs: getSubModulesForModule(mod.id) }))
})

const editRecordId = ref(null)
const editingLineIdx = ref(null)
const editLines = ref([])
const clipboardText = ref('')

// 模版编辑状态(仅保留计算规则,用于失焦自动计算)
const editingTemplateInfo = ref(null)  // { text, computed }
let lineUid = 0
const sortableInstance = ref(null)

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
const docBodyRef = ref(null)
const tocRef = ref(null)
const docPagesScrollbar = ref(null)
const activeSectionKey = ref('')
const sectionRefs = {}

const registerSection = (key, el) => { if (el) sectionRefs[key] = el }

const scrollTo = (key, instant = false) => {
  autoSaveCurrentEdit()
  const el = sectionRefs[key]
  if (el) {
    if (instant) {
      // 新增后跳转: 直接用 scrollIntoView auto(无动画)
      el.scrollIntoView({ behavior: 'auto', block: 'start' })
    } else {
      // 目录点击: 跟周报汇总一致,直接设置 scrollTop 不产生滚动动画
      const container = docBodyRef.value?.querySelector('.el-scrollbar__wrap')
      if (container) {
        const containerRect = container.getBoundingClientRect()
        const elRect = el.getBoundingClientRect()
        container.scrollTop = container.scrollTop + (elRect.top - containerRect.top) - 60
      }
    }
    activeSectionKey.value = key
  }
}

const onDocScroll = () => {
  const container = docBodyRef.value?.querySelector('.el-scrollbar__wrap')
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

onUnmounted(() => { document.removeEventListener('mousedown', handleOutsideClick); window.removeEventListener('weekly-report-returned', handleReportReturned); window.removeEventListener('weekly-report-module-change', handleModuleChange) })

const historyList = ref([])
const activeModules = computed(() => reportModules.value.filter(m => m.active))
const subModules = ref([])
const loadSubModules = async () => { try { subModules.value = await getReportSubModules() } catch { subModules.value = [] } }
const getSubModulesForModule = (moduleId) => subModules.value.filter(sm => sm.moduleId === moduleId)
const getSubModuleName = (subId) => { if (!subId) return ''; const sm = subModules.value.find(s => s.id === subId); return sm ? sm.name : '' }

// 获取子模块的模版默认文本（如果有模版配置则返回模版文本,否则返回空字符串）
const getSubModuleTemplateText = (subId) => {
  if (!subId) return ''
  const sm = subModules.value.find(s => s.id === subId)
  if (!sm || !sm.template) return ''
  let tpl
  if (typeof sm.template === 'string') {
    try { tpl = JSON.parse(sm.template) } catch { return '' }
  } else {
    tpl = sm.template
  }
  if (!tpl.text) return ''
  // 将 {X} 占位符替换为 0,模版内容直接以具体数值显示
  return tpl.text.replace(/\{(\w+)\}/g, '0')
}

// 获取父模块的综述模版默认文本
const getParentModuleTemplateText = (moduleId) => {
  if (!moduleId) return ''
  const mod = reportModules.value.find(m => m.id === moduleId)
  if (!mod || !mod.template) return ''
  let tpl
  if (typeof mod.template === 'string') {
    try { tpl = JSON.parse(mod.template) } catch { return '' }
  } else {
    tpl = mod.template
  }
  if (!tpl.text) return ''
  return tpl.text.replace(/\{(\w+)\}/g, '0')
}

// 获取子模块的综述模版默认文本
const getSubModuleSummaryTemplateText = (subId) => {
  if (!subId) return ''
  const sm = subModules.value.find(s => s.id === subId)
  if (!sm || !sm.summaryTemplate) return ''
  let tpl
  if (typeof sm.summaryTemplate === 'string') {
    try { tpl = JSON.parse(sm.summaryTemplate) } catch { return '' }
  } else {
    tpl = sm.summaryTemplate
  }
  if (!tpl.text) return ''
  return tpl.text.replace(/\{(\w+)\}/g, '0')
}

// 获取子模块的综述模版计算规则
const getSubModuleSummaryTemplateComputed = (subId) => {
  if (!subId) return null
  const sm = subModules.value.find(s => s.id === subId)
  if (!sm || !sm.summaryTemplate) return null
  let tpl
  if (typeof sm.summaryTemplate === 'string') {
    try { tpl = JSON.parse(sm.summaryTemplate) } catch { return null }
  } else {
    tpl = sm.summaryTemplate
  }
  return tpl.computed || null
}

// 获取子模块的模版计算规则
const getSubModuleTemplateComputed = (subId) => {
  if (!subId) return null
  const sm = subModules.value.find(s => s.id === subId)
  if (!sm || !sm.template) return null
  let tpl
  if (typeof sm.template === 'string') {
    try { tpl = JSON.parse(sm.template) } catch { return null }
  } else {
    tpl = sm.template
  }
  return tpl.computed || null
}

// 获取父模块的综述模版计算规则
const getParentModuleTemplateComputed = (moduleId) => {
  if (!moduleId) return null
  const mod = reportModules.value.find(m => m.id === moduleId)
  if (!mod || !mod.template) return null
  let tpl
  if (typeof mod.template === 'string') {
    try { tpl = JSON.parse(mod.template) } catch { return null }
  } else {
    tpl = mod.template
  }
  return tpl.computed || null
}

// 获取父模块的明细模版默认文本（无子模块时的详细内容模版）
const getParentModuleDetailTemplateText = (moduleId) => {
  if (!moduleId) return ''
  const mod = reportModules.value.find(m => m.id === moduleId)
  if (!mod || !mod.detailTemplate) return ''
  let tpl
  if (typeof mod.detailTemplate === 'string') {
    try { tpl = JSON.parse(mod.detailTemplate) } catch { return '' }
  } else {
    tpl = mod.detailTemplate
  }
  if (!tpl.text) return ''
  return tpl.text.replace(/\{(\w+)\}/g, '0')
}

// 获取父模块的明细模版计算规则
const getParentModuleDetailTemplateComputed = (moduleId) => {
  if (!moduleId) return null
  const mod = reportModules.value.find(m => m.id === moduleId)
  if (!mod || !mod.detailTemplate) return null
  let tpl
  if (typeof mod.detailTemplate === 'string') {
    try { tpl = JSON.parse(mod.detailTemplate) } catch { return null }
  } else {
    tpl = mod.detailTemplate
  }
  return tpl.computed || null
}

const weekDateLabel = computed(() => {
  const weekNum = fillWeekKey.value === 'current' ? currentWeek : customWeekNum.value
  const { monday, sunday } = getWeekDateRange(currentYear, weekNum)
  return `${currentYear}年${fmtDateCN(monday)} — ${fmtDateCN(sunday)}`
})
const fillWeek = computed(() => fillWeekKey.value === 'current' ? currentWeek : customWeekNum.value)

const overallStatusType = computed(() => {
  if (records.value.some(r => r.status === 'submitted')) return 'success'
  if (records.value.some(r => r.status === 'returned')) return 'warning'
  if (records.value.length > 0) return 'info'
  return 'info'
})
const overallStatusText = computed(() => {
  const returnedCnt = records.value.filter(r => r.status === 'returned').length
  if (returnedCnt > 0) return `⚠ 已退回 ${returnedCnt} 条，请重新编辑提交`
  if (records.value.some(r => r.status === 'submitted')) return `✓ 已提交 ${records.value.filter(r => r.status === 'submitted').length} 条`
  if (records.value.length > 0) return `草稿 ${records.value.length} 条`
  return '未填写'
})

const getModuleName = (mid) => { const mod = reportModules.value.find(m => m.id === mid); return mod ? mod.name : '未知模块' }
const getModuleColor = (mid) => { const mod = reportModules.value.find(m => m.id === mid); return mod ? mod.color : '#2563eb' }
const getModuleCategory = (mid) => { const mod = reportModules.value.find(m => m.id === mid); return mod ? mod.category : '' }
const handleWeekChange = () => {
  if (fillWeekKey.value === 'custom' && customWeekNum.value === currentWeek) {
    customWeekNum.value = currentWeek - 1
  }
  loadFillData()
}

const handleCustomWeekChange = (val) => {
  if (val && val >= 1 && val <= currentWeek) {
    loadFillData()
  }
}

const navigateWeek = (delta) => {
  const current = fillWeek.value
  const target = current + delta
  if (target < 1 || target > currentWeek) return
  if (target === currentWeek) {
    fillWeekKey.value = 'current'
  } else {
    fillWeekKey.value = 'custom'
    customWeekNum.value = target
  }
  loadFillData()
}

const docSections = computed(() => {
  // 当前周仅显示已启用的模块；历史周显示所有模块（含已停用），确保用户能看到历史记录
  const modules = fillWeekKey.value === 'current'
    ? reportModules.value.filter(m => m.active)
    : reportModules.value
  return modules
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999))
    .map(mod => {
      const subModuleList = getSubModulesForModule(mod.id)
      // 无子模块的父模块：分别查找综述记录（isSummary=true）和序号行记录（isSummary!=true）
      if (subModuleList.length === 0) {
        const recordsForModule = records.value.filter(r => r.moduleId === mod.id && !r.subModuleId)
        const record = recordsForModule.find(r => !r.isSummary)
        const parentRecord = recordsForModule.find(r => r.isSummary)
        return {
          moduleId: mod.id,
          moduleName: mod.name,
          moduleColor: mod.color,
          moduleOrder: mod.order ?? 999,
          hasSubModules: false,
          hasRecord: !!record || !!parentRecord,
          record: record || null,
          parentRecord: parentRecord || null,
          hasParentRecord: !!parentRecord,
          filledLastWeek: lastWeekFilledModuleSet.value.has(mod.id),
          subs: []
        }
      }
      // 有子模块：同时查询父模块自身是否有记录（subModuleId=null）
      const parentRecord = records.value.find(r => r.moduleId === mod.id && !r.subModuleId)
      const subs = subModuleList
        .sort((a, b) => (a.order ?? 999) - (b.order ?? 999))
        .map(sub => {
          const recordsForSub = records.value.filter(r => r.subModuleId === sub.id)
          const record = recordsForSub.find(r => !r.isSummary)
          const summaryRecord = recordsForSub.find(r => r.isSummary)
          return {
            subName: sub.name,
            hasRecord: !!record,
            record: record || null,
            hasSummaryRecord: !!summaryRecord,
            summaryRecord: summaryRecord || null,
            filledLastWeek: lastWeekFilledSubModuleSet.value.has(sub.id),
            moduleId: mod.id,
            subModuleId: sub.id
          }
        })
      return {
        moduleId: mod.id,
        moduleName: mod.name,
        moduleColor: mod.color,
        moduleOrder: mod.order ?? 999,
        hasSubModules: true,
        hasRecord: subs.some(s => s.hasRecord || s.hasSummaryRecord) || !!parentRecord,
        parentRecord: parentRecord || null,
        parentFilledLastWeek: lastWeekFilledParentSet.value.has(mod.id),
        subs
      }
    })
})

const loadFillData = async (silent = false) => {
  // 保存当前滚动位置
  const container = docBodyRef.value?.querySelector('.el-scrollbar__wrap')
  const savedScrollTop = container?.scrollTop || 0
  if (!silent) loading.value = true
  if (!username.value) { if (!silent) loading.value = false; return }
  try {
    // 每次加载数据时重新获取模块/子模块列表
    // 当前周：用当前未删除的模块；历史周：传 weekNum 获取该周结束前创建的所有模块（含已删除）
    const weekNum = fillWeek.value
    if (fillWeekKey.value === 'current') {
      reportModules.value = await getReportModules()
      subModules.value = await getReportSubModules()
    } else {
      reportModules.value = await getReportModules(weekNum)
      subModules.value = await getReportSubModules(undefined, weekNum)
    }
    const data = await getMyReports(weekNum, username.value)
    records.value = data?.records || []
    // 当前周且不是第1周时，加载上周已提交记录用于标记“上周填写”
    if (fillWeekKey.value === 'current' && weekNum > 1) {
      try {
        const lastData = await getMyReports(weekNum - 1, username.value)
        lastWeekRecords.value = lastData?.records || []
      } catch { lastWeekRecords.value = [] }
    } else {
      lastWeekRecords.value = []
    }
  } catch { records.value = [] }
  if (!silent) loading.value = false
  // DOM 重建后恢复滚动位置
  if (savedScrollTop > 0) {
    nextTick(() => {
      const newContainer = docBodyRef.value?.querySelector('.el-scrollbar__wrap')
      if (newContainer) newContainer.scrollTop = savedScrollTop
    })
  }
}

const openAddDialog = () => { addForm.value = { moduleIds: [], subModuleIds: [] }; addDialogVisible.value = true }
const resetAddForm = () => { addForm.value = { moduleIds: [], subModuleIds: [] } }

const toggleAddModule = (mid) => {
  const idx = addForm.value.moduleIds.indexOf(mid)
  if (idx >= 0) { addForm.value.moduleIds.splice(idx, 1); addForm.value.subModuleIds = addForm.value.subModuleIds.filter(sid => { const sm = subModules.value.find(s => s.id === sid); return sm && addForm.value.moduleIds.includes(sm.moduleId) }) }
  else addForm.value.moduleIds.push(mid)
}

const allSelectableModuleIds = computed(() => activeModules.value.filter(m => !isModuleFullySelected(m.id)).map(m => m.id))
const isAllModulesSelected = computed(() => { if (allSelectableModuleIds.value.length === 0) return false; return allSelectableModuleIds.value.every(id => addForm.value.moduleIds.includes(id)) })
const toggleAllModules = () => {
  if (isAllModulesSelected.value) { addForm.value.moduleIds = []; addForm.value.subModuleIds = [] }
  else addForm.value.moduleIds = [...allSelectableModuleIds.value]
}
const isGroupAllSelected = (moduleId) => { const subs = getSubModulesForModule(moduleId); const sel = subs.filter(s => !existingSubModuleIds.value.includes(s.id)); if (sel.length === 0) return false; return sel.every(s => addForm.value.subModuleIds.includes(s.id)) }
const toggleAllSubModulesForModule = (moduleId) => {
  const subs = getSubModulesForModule(moduleId)
  const sel = subs.filter(s => !existingSubModuleIds.value.includes(s.id))
  if (sel.length === 0) return
  const ids = sel.map(s => s.id)
  if (ids.every(id => addForm.value.subModuleIds.includes(id))) addForm.value.subModuleIds = addForm.value.subModuleIds.filter(id => !ids.includes(id))
  else addForm.value.subModuleIds = [...new Set([...addForm.value.subModuleIds.filter(id => !ids.includes(id)), ...ids])]
}

const toggleAddSubModule = (subId) => { const idx = addForm.value.subModuleIds.indexOf(subId); idx >= 0 ? addForm.value.subModuleIds.splice(idx, 1) : addForm.value.subModuleIds.push(subId) }
const existingModuleIds = computed(() => records.value.filter(r => !r.subModuleId).map(r => r.moduleId))
const existingSubModuleIds = computed(() => records.value.filter(r => r.subModuleId && !r.isSummary).map(r => r.subModuleId))
const isModuleFullySelected = (moduleId) => { const subs = getSubModulesForModule(moduleId); if (subs.length === 0) return records.value.some(r => r.moduleId === moduleId && !r.subModuleId && !r.isSummary); return subs.every(s => existingSubModuleIds.value.includes(s.id)) }

const hasDraftRecords = computed(() => records.value.some(r => r.status !== 'submitted'))

const handleSubmitAllDrafts = async () => {
  try {
    await ElMessageBox.confirm('确认将当前所有草稿和已退回的周报一键提交？提交后不可撤回。', '一键提交确认', { confirmButtonText: '确认提交', cancelButtonText: '取消', type: 'warning' })
    const res = await submitAllDrafts(username.value)
    if (res.status === 'success') {
      // 先更新本地记录状态，确保 UI 即时响应
      records.value.forEach(r => { if (r.status !== 'submitted') r.status = 'submitted' })
      msg('success', '所有草稿周报已提交'); await loadFillData(true)
    }
    else msg('error', res.message || '一键提交失败')
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '一键提交失败') }
}

const handleDeleteAllDrafts = async () => {
  const draftRecords = records.value.filter(r => r.status !== 'submitted')
  if (draftRecords.length === 0) { msg('info', '没有草稿/已退回记录需要删除'); return }
  try {
    await ElMessageBox.confirm(`确认删除全部 ${draftRecords.length} 条草稿/已退回记录？删除后不可恢复。`, '一键删除确认', { confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning' })
    for (const rec of draftRecords) {
      await deleteReport(rec.id)
    }
    msg('success', `已删除 ${draftRecords.length} 条草稿记录`)
    await loadFillData(true)
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '删除失败') }
}

const handleAddConfirm = async () => {
  if (addForm.value.moduleIds.length === 0) { msg('warning', '请至少选择一个模块'); return }
  // 新增前刷新子模块数据，确保获取最新的模版配置
  try { subModules.value = await getReportSubModules() } catch { /* */ }
  try {
    const entries = []
    addForm.value.moduleIds.forEach(mid => {
      const subs = getSubModulesForModule(mid)
      if (subs.length > 0) {
        const selectedSubs = addForm.value.subModuleIds.length > 0 ? subs.filter(s => addForm.value.subModuleIds.includes(s.id) && !existingSubModuleIds.value.includes(s.id)) : subs.filter(s => !existingSubModuleIds.value.includes(s.id))
        selectedSubs.forEach(sub => {
          const tplText = getSubModuleTemplateText(sub.id)
          entries.push({ moduleId: mid, subModuleId: sub.id, content: tplText })
        })
      } else {
        const dtplText = getParentModuleDetailTemplateText(mid)
        entries.push({ moduleId: mid, content: dtplText })
      }
    })
    if (entries.length === 0) { msg('warning', '请选择子模块'); return }
    const res = await saveReport({ username: username.value, weekNum: fillWeek.value, entries, status: 'draft' })
    if (res.status === 'success') {
      addDialogVisible.value = false
      msg('success', `已新增 ${entries.length} 个模块周报`)
      await loadFillData(true)
      nextTick(() => {
        const first = entries[0]
        const si = docSections.value.findIndex(s => s.moduleId === first.moduleId)
        if (si >= 0) {
          if (first.subModuleId) {
            const sec = docSections.value[si]
            const sj = sec.subs.findIndex(s => s.subModuleId === first.subModuleId)
            if (sj >= 0) scrollTo('s' + si + '-' + sj, true)
          } else {
            scrollTo('p' + si, true)
          }
        }
      })
    }
    else msg('error', res.message || '新增失败')
  } catch (e) { msg('error', e.message || '新增失败') }
}

// 快捷添加单个子模块
const quickAddSub = async (sub) => {
  // 添加前刷新子模块数据，确保获取最新的模版配置
  try { subModules.value = await getReportSubModules() } catch { /* */ }
  const tplText = getSubModuleTemplateText(sub.subModuleId)
  const entries = [{ moduleId: sub.moduleId, subModuleId: sub.subModuleId, content: tplText }]
  try {
    const res = await saveReport({ username: username.value, weekNum: fillWeek.value, entries, status: 'draft' })
    if (res.status === 'success') {
      msg('success', '已添加')
      await loadFillData(true)
      nextTick(() => {
        const si = docSections.value.findIndex(s => s.moduleId === sub.moduleId)
        if (si >= 0) {
          const sec = docSections.value[si]
          const sj = sec.subs.findIndex(s => s.subModuleId === sub.subModuleId)
          if (sj >= 0) {
            scrollTo('s' + si + '-' + sj, true)
            if (sec.subs[sj].record) startInlineEdit(sec.subs[sj].record)
          }
        }
      })
    }
    else msg('error', res.message || '添加失败')
  } catch (e) { msg('error', e.message || '添加失败') }
}

// 快捷添加子模块综述
const quickAddSubSummary = async (sub) => {
  try { subModules.value = await getReportSubModules() } catch { /* */ }
  const tplText = getSubModuleSummaryTemplateText(sub.subModuleId)
  const entries = [{ moduleId: sub.moduleId, subModuleId: sub.subModuleId, content: tplText, isSummary: true }]
  try {
    const res = await saveReport({ username: username.value, weekNum: fillWeek.value, entries, status: 'draft' })
    if (res.status === 'success') {
      msg('success', '已添加')
      await loadFillData(true)
      nextTick(() => {
        const si = docSections.value.findIndex(s => s.moduleId === sub.moduleId)
        if (si >= 0) {
          const sec = docSections.value[si]
          const sj = sec.subs.findIndex(s => s.subModuleId === sub.subModuleId)
          if (sj >= 0) {
            scrollTo('s' + si + '-' + sj, true)
            if (sec.subs[sj].summaryRecord) startInlineEdit(sec.subs[sj].summaryRecord)
          }
        }
      })
    }
    else msg('error', res.message || '添加失败')
  } catch (e) { msg('error', e.message || '添加失败') }
}

// 快捷添加无子模块的父模块
const quickAddModule = async (sec) => {
  // 添加前刷新模块数据，确保获取最新的模版配置
  try { reportModules.value = await getReportModules() } catch { /* */ }
  const tplText = getParentModuleDetailTemplateText(sec.moduleId)
  const entries = [{ moduleId: sec.moduleId, content: tplText }]
  try {
    const res = await saveReport({ username: username.value, weekNum: fillWeek.value, entries, status: 'draft' })
    if (res.status === 'success') {
      msg('success', '已添加');
      await loadFillData(true)
      nextTick(() => {
        const si = docSections.value.findIndex(s => s.moduleId === sec.moduleId)
        if (si >= 0) {
          scrollTo('p' + si, true)
          if (docSections.value[si].record) startInlineEdit(docSections.value[si].record)
        }
      })
    }
    else msg('error', res.message || '添加失败')
  } catch (e) { msg('error', e.message || '添加失败') }
}

// 快捷添加有子模块的父模块自身内容（模块综述）
const quickAddParentModule = async (sec) => {
  // 添加前刷新模块数据，确保获取最新的模版配置
  try { reportModules.value = await getReportModules() } catch { /* */ }
  const tplText = getParentModuleTemplateText(sec.moduleId)
  const entries = [{ moduleId: sec.moduleId, content: tplText, isSummary: true }]
  try {
    const res = await saveReport({ username: username.value, weekNum: fillWeek.value, entries, status: 'draft' })
    if (res.status === 'success') {
      msg('success', '已添加')
      await loadFillData(true)
      nextTick(() => {
        const si = docSections.value.findIndex(s => s.moduleId === sec.moduleId)
        if (si >= 0) {
          const secData = docSections.value[si]
          if (secData.parentRecord) startInlineEdit(secData.parentRecord)
        }
      })
    }
    else msg('error', res.message || '添加失败')
  } catch (e) { msg('error', e.message || '添加失败') }
}

const autoSaveCurrentEdit = async () => {
  if (!editRecordId.value) return false
  // 保存前触发模版自动计算
  if (editingTemplateInfo.value) {
    autoCalcTemplateLine()
  }
  const recordId = editRecordId.value
  const ts = nowStr()
  const nonEmpty = editLines.value.filter(l => l.text.trim())
  // 所有行内容都为空时，删除该记录，使其变为未选择状态
  if (nonEmpty.length === 0) {
    try {
      await deleteReport(recordId)
      destroySortable(); editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null; document.removeEventListener('keydown', handleKeydownSave); document.removeEventListener('mousedown', handleOutsideClick); await loadFillData(true)
      return true
    } catch { return false }
  }
  nonEmpty.forEach(l => { if (!l.updatedBy || l.text !== l._origText) { l.updatedBy = displayName.value; l.updatedAt = ts } })
  const contentStr = JSON.stringify(nonEmpty)
  try {
    await updateReport(recordId, { content: contentStr })
    // 先更新本地 records 数据，使视图立即显示最新内容，避免先切查看态再刷新带来的视觉跳动
    const localRec = records.value.find(r => r.id === recordId)
    if (localRec) {
      localRec.content = contentStr
    }
    destroySortable();
    editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null;
    document.removeEventListener('keydown', handleKeydownSave);
    document.removeEventListener('mousedown', handleOutsideClick)
    await loadFillData(true)
    msg('success', '修改已自动保存')
    return true
  } catch { return false }
}

const startInlineEdit = async (rec, initialIdx = 0) => {
  await autoSaveCurrentEdit()
  editRecordId.value = rec.id
  const ts = nowStr()
  const lines = parseLines(rec.content)
  // 内容为空时检测是否有模版可自动填充
  if (lines.length === 0) {
    let tplText = ''
    if (rec.subModuleId && rec.isSummary) {
      tplText = getSubModuleSummaryTemplateText(rec.subModuleId)
    } else if (rec.subModuleId) {
      tplText = getSubModuleTemplateText(rec.subModuleId)
    } else if (rec.isSummary) {
      tplText = getParentModuleTemplateText(rec.moduleId)
    } else {
      tplText = getParentModuleDetailTemplateText(rec.moduleId)
    }
    if (tplText) {
      editLines.value = [{ text: tplText, updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }]
    } else {
      editLines.value = [{ text: '', updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }]
    }
  } else {
    editLines.value = lines.map(l => ({ ...l, _origText: l.text, updatedBy: displayName.value, updatedAt: ts, _uid: lineUid++ }))
  }
  editingLineIdx.value = initialIdx

  // 检测当前编辑行是否有模版,初始化计算规则(无需显示面板)
  editingTemplateInfo.value = null
  // 子模块综述：使用子模块的 summaryTemplate
  if (rec.subModuleId && rec.isSummary) {
    const sm = subModules.value.find(s => s.id === rec.subModuleId)
    if (sm && sm.summaryTemplate) {
      let tpl
      if (typeof sm.summaryTemplate === 'string') {
        try { tpl = JSON.parse(sm.summaryTemplate) } catch { tpl = null }
      } else {
        tpl = sm.summaryTemplate
      }
      if (tpl && tpl.computed && Object.keys(tpl.computed).length > 0) {
        editingTemplateInfo.value = { text: tpl.text || '', computed: tpl.computed }
      }
    }
  }
  // 子模块明细：使用子模块的 template
  if (!editingTemplateInfo.value && rec.subModuleId && !rec.isSummary) {
    const sm = subModules.value.find(s => s.id === rec.subModuleId)
    if (sm && sm.template) {
      let tpl
      if (typeof sm.template === 'string') {
        try { tpl = JSON.parse(sm.template) } catch { tpl = null }
      } else {
        tpl = sm.template
      }
      if (tpl && tpl.computed && Object.keys(tpl.computed).length > 0) {
        editingTemplateInfo.value = { text: tpl.text || '', computed: tpl.computed }
      }
    }
  }
  // 父模块综述（isSummary=true, subModuleId=null）检测父模块是否有模版
  if (!editingTemplateInfo.value && rec.isSummary && !rec.subModuleId) {
    const mod = reportModules.value.find(m => m.id === rec.moduleId)
    if (mod && mod.template) {
      let tpl
      if (typeof mod.template === 'string') {
        try { tpl = JSON.parse(mod.template) } catch { tpl = null }
      } else {
        tpl = mod.template
      }
      if (tpl && tpl.computed && Object.keys(tpl.computed).length > 0) {
        editingTemplateInfo.value = { text: tpl.text || '', computed: tpl.computed }
      }
    }
  }
  // 明细记录（无子模块的父模块详细内容）检测父模块是否有明细模版
  if (!editingTemplateInfo.value && !rec.subModuleId && !rec.isSummary) {
    const mod = reportModules.value.find(m => m.id === rec.moduleId)
    if (mod && mod.detailTemplate) {
      let tpl
      if (typeof mod.detailTemplate === 'string') {
        try { tpl = JSON.parse(mod.detailTemplate) } catch { tpl = null }
      } else {
        tpl = mod.detailTemplate
      }
      if (tpl && tpl.computed && Object.keys(tpl.computed).length > 0) {
        editingTemplateInfo.value = { text: tpl.text || '', computed: tpl.computed }
      }
    }
  }

  nextTick(() => {
    const inputs = document.querySelectorAll('.record-content-lines .line-input-editable')
    if (inputs.length > initialIdx) {
      const el = inputs[initialIdx]
      el.focus()
      const range = document.createRange()
      range.selectNodeContents(el)
      range.collapse(false)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
    }
    initSortable()
  })
  nextTick(() => {
    document.addEventListener('keydown', handleKeydownSave)
    document.addEventListener('mousedown', handleOutsideClick)
  })
}

const handleOutsideClick = (e) => {
  if (!editRecordId.value) return
  const docBody = docBodyRef.value
  if (docBody && !docBody.contains(e.target)) { if (editLines.value.every(l => !l.text.trim())) autoSaveAndExit() }
}

const autoSaveAndExit = async () => {
  if (!editRecordId.value) return
  const recordId = editRecordId.value
  try {
    await deleteReport(recordId)
    destroySortable();
    editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null;
    document.removeEventListener('keydown', handleKeydownSave);
    document.removeEventListener('mousedown', handleOutsideClick)
    await loadFillData(true)
  } catch { /* */ }
}

const onLineContentClick = (idx, e) => {
  const editable = e.currentTarget.querySelector('.line-input-editable')
  if (!editable) return
  if (editable.textContent === '' || editable.textContent === '\u200B') {
    // 空行：插入空白符并定位光标
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
    // 非空行：点击区域没有文本（序号/空白间隙），将光标定位到行尾
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
const onViewLineDblClick = async (rec, lineIdx) => {
  if (fillWeekKey.value !== 'current') return
  if (rec.status === 'submitted') return
  await startInlineEdit(rec, lineIdx)
}

// 阻止浏览器默认粘贴行为，用 execCommand 以纯文本插入，避免 DOM 块级拆分且支持 Ctrl+Z 撤销
const handleContentEditablePaste = (e) => {
  e.preventDefault()
  const text = (e.clipboardData || window.clipboardData).getData('text/plain')
  if (!text) return
  document.execCommand('insertText', false, text)
}

const activateLine = (idx) => { editingLineIdx.value = idx; setTimeout(() => focusLine(idx), 0) }
const focusLine = (idx) => {
  const inputs = document.querySelectorAll('.record-content-lines .line-input-editable')
  if (inputs.length > idx) {
    // 清除其他空行的零宽空格，使 :empty::before 占位文字恢复显示
    inputs.forEach((input, i) => {
      if (i !== idx && input.textContent === '\u200B') {
        input.textContent = ''
      }
    })
    const el = inputs[idx]
    if (document.activeElement !== el) {
      el.focus()
    }
    if (!el.textContent) {
      el.textContent = '\u200B'
    }
    // 将光标定位到行尾
    const range = document.createRange()
    range.selectNodeContents(el)
    range.collapse(false)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }
}
const onEditableInput = (idx, e) => {
  const el = e.target
  // 用户输入后将零宽空格清理掉，同时确保空输入框保留光标占位
  let text = (el.innerText || '').replace(/​/g, '').replace(/(\r?\n)+$/, '')
  editLines.value[idx].text = text
  if (!text && !el.textContent.replace(/​/g, '')) {
    el.textContent = '\u200B'
  }
}
const cancelInlineEdit = async () => {
  const recordId = editRecordId.value
  // 编辑内容全为空时，取消同样删除该空草稿，避免留下空内容记录
  const isEmpty = editLines.value.every(l => !l.text.trim())
  destroySortable(); editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null; document.removeEventListener('keydown', handleKeydownSave); document.removeEventListener('mousedown', handleOutsideClick)
  if (recordId && isEmpty) {
    try {
      await deleteReport(recordId)
      msg('success', '内容为空，已删除')
      await loadFillData(true)
    } catch (e) { msg('error', e.message || '删除失败') }
  }
}

const parseLines = (content) => {
  if (!content || !content.trim()) return []
  try { const p = JSON.parse(content); if (Array.isArray(p)) return p.filter(l => l && l.text !== undefined) } catch { /* */ }
  return content.split('\n').filter(t => t.trim()).map(t => ({ text: t, updatedBy: '', updatedAt: '' }))
}

const nowStr = () => { const d = new Date(); const pad = n => String(n).padStart(2, '0'); return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}` }
const displayName = computed(() => nickname.value || username.value)

const chineseNum = (n) => {
  const map = ['零','一','二','三','四','五','六','七','八','九','十','十一','十二','十三','十四','十五','十六','十七','十八','十九','二十']
  return (n >= 0 && n < map.length) ? map[n] : String(n)
}

// 父模块的 TOC 色点颜色：无子模块时判断详细内容和综述，有子模块时综合所有子模块+综述
const getParentModuleTocColor = (sec) => {
  const hasRecord = !!sec.record
  const hasParentRecord = !!sec.parentRecord

  // 有子模块：综合所有子模块记录 + 父模块综述的状态
  if (sec.hasSubModules) {
    if (!hasParentRecord && sec.subs.every(s => !s.hasRecord && !s.hasSummaryRecord)) return 'transparent'
    const allRecords = []
    if (sec.parentRecord) allRecords.push(sec.parentRecord)
    sec.subs.forEach(s => {
      if (s.record) allRecords.push(s.record)
      if (s.summaryRecord) allRecords.push(s.summaryRecord)
    })
    if (allRecords.length === 0) return 'transparent'
    // 已退回优先级最高
    if (allRecords.some(r => r.status === 'returned')) return '#e6a23c'
    // 全部已提交 → 提交色
    if (allRecords.every(r => r.status === 'submitted')) return '#67c23a'
    // 否则 → 草稿色
    return '#909399'
  }

  // 无子模块：根据综述开关状态分情况处理
  if (!summaryFillerEnabled.value) {
    // 综述关闭：只按详细内容的状态决定色点
    if (!hasRecord) return 'transparent'
    const r = sec.record?.status
    if (r === 'returned') return '#e6a23c'
    return r === 'submitted' ? '#67c23a' : '#909399'
  }
  // 综述开启：详细内容和综述都提交才显示提交色，否则草稿色
  if (!hasRecord && !hasParentRecord) return 'transparent'
  const rStatus = sec.record?.status
  const pStatus = sec.parentRecord?.status
  if (rStatus === 'returned' || pStatus === 'returned') return '#e6a23c'
  if (hasRecord && hasParentRecord && rStatus === 'submitted' && pStatus === 'submitted') return '#67c23a'
  return '#909399'
}

// 子模块的 TOC 色点颜色：综合详细内容和综述的状态
const getSubTocColor = (sub) => {
  const hasRecord = !!sub.record
  const hasSummary = !!sub.summaryRecord
  if (!hasRecord && !hasSummary) return 'transparent'
  const rStatus = sub.record?.status
  const sStatus = sub.summaryRecord?.status
  if (rStatus === 'returned' || sStatus === 'returned') return '#e6a23c'
  if (hasRecord && hasSummary && rStatus === 'submitted' && sStatus === 'submitted') return '#67c23a'
  if (hasRecord && !hasSummary && rStatus === 'submitted') return '#67c23a'
  if (!hasRecord && hasSummary && sStatus === 'submitted') return '#67c23a'
  if (hasRecord) return '#909399'
  return 'transparent'
}

const copyText = async (text) => { if (!text) return; clipboardText.value = text; try { await navigator.clipboard.writeText(text) } catch { /* */ }; msg('success', '已复制到剪贴板') }

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

const clearLine = (idx) => { editLines.value[idx].text = ''; nextTick(() => activateLine(idx)) }
const copyLineText = async (text) => { if (!text) return; try { await navigator.clipboard.writeText(text); clipboardText.value = text; msg('success', '已复制到剪贴板') } catch { /* */ } }

// ====== 模版变量处理逻辑 ======

// 计算简单算术表达式(仅支持 +-*/ 和数字)
const computeFormula = (formula, values) => {
  try {
    let expr = formula
    // 替换变量名为当前值
    for (const [key, val] of Object.entries(values)) {
      const num = parseFloat(val) || 0
      expr = expr.replace(new RegExp(key, 'g'), String(num))
    }
    // 安全计算(仅允许数字和 +-*/ 运算符)
    if (!/^[\d+\-*/.\s]+$/.test(expr)) return 0
    // eslint-disable-next-line no-new-func
    const result = new Function(`return (${expr})`)()
    return isNaN(result) ? 0 : result
  } catch { return 0 }
}

// 从模版文本中提取各变量当前值,重新计算计算型变量(如A),并更新行文本
const autoCalcTemplateLine = () => {
  if (!editingTemplateInfo.value || editingLineIdx.value === null) return
  const tplText = editingTemplateInfo.value.text
  const computed = editingTemplateInfo.value.computed
  if (!tplText || !computed) return

  const currentText = editLines.value[editingLineIdx.value]?.text
  if (!currentText) return

  // 按 {X} 分割模版得到各部分文本
  const varMatches = tplText.match(/\{(\w+)\}/g) || []
  const orderedVars = varMatches.map(m => m.replace(/[{}]/g, ''))
  if (orderedVars.length === 0) return
  const parts = tplText.split(/\{\w+\}/)

  // 从当前文本中提取每个变量的数值
  const values = {}
  let remaining = currentText
  for (let i = 0; i < orderedVars.length; i++) {
    const vn = orderedVars[i]
    const beforePart = parts[i]
    if (remaining.startsWith(beforePart)) {
      remaining = remaining.substring(beforePart.length)
    } else { return }

    if (i < orderedVars.length - 1) {
      const nextPart = parts[i + 1]
      const idx = remaining.indexOf(nextPart)
      if (idx > 0) {
        values[vn] = remaining.substring(0, idx)
        remaining = remaining.substring(idx)
      } else { return }
    } else {
      // 最后一个变量: 需要去掉末尾的固定文本部分
      const trailingPart = parts[i + 1]
      if (trailingPart && remaining.endsWith(trailingPart)) {
        values[vn] = remaining.substring(0, remaining.length - trailingPart.length)
      } else {
        values[vn] = remaining
      }
    }
  }

  // 计算计算型变量
  for (const [vn, formula] of Object.entries(computed)) {
    values[vn] = String(computeFormula(formula, values))
  }

  // 重新构建文本并更新
  let result = parts[0]
  for (let i = 0; i < orderedVars.length; i++) {
    result += (values[orderedVars[i]] || '0') + parts[i + 1]
  }
  editLines.value[editingLineIdx.value].text = result
  const input = document.querySelector('.record-content-lines .line-input-editable')
  if (input) input.textContent = result
}

// contenteditable 失焦时触发模版自动计算
const onEditableBlur = (idx) => {
  if (editingTemplateInfo.value) {
    autoCalcTemplateLine()
  }
}

const handleLineKeydown = (e, idx) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); handleSaveShortcut(); return }
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); addLineAfter(idx) }
  else if (e.key === 'ArrowUp' && !e.shiftKey) { e.preventDefault(); moveToPrevLine(idx) }
  else if (e.key === 'ArrowDown' && !e.shiftKey) { e.preventDefault(); moveToNextLine(idx) }
}

const handleSaveShortcut = () => {
  if (editRecordId.value) {
    saveInlineEdit(editRecordId.value)
  }
}

const handleKeydownSave = (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') {
    e.preventDefault()
    handleSaveShortcut()
  }
}

const saveInlineEdit = async (recordId) => {
  // 保存前触发模版自动计算
  if (editingTemplateInfo.value) {
    autoCalcTemplateLine()
  }
  const ts = nowStr()
  const nonEmpty = editLines.value.filter(l => l.text.trim())
  // 所有行内容都为空时，删除该记录，使其变为未选择状态
  if (nonEmpty.length === 0) {
    try {
      await deleteReport(recordId)
      destroySortable(); editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null; document.removeEventListener('keydown', handleKeydownSave); document.removeEventListener('mousedown', handleOutsideClick); msg('success', '内容为空，已删除'); await loadFillData(true)
    } catch (e) { msg('error', e.message || '删除失败') }
    return
  }
  nonEmpty.forEach(l => { if (!l.updatedBy || l.text !== l._origText) { l.updatedBy = displayName.value; l.updatedAt = ts } })
  const contentStr = JSON.stringify(nonEmpty)
  try {
    const updateData = { content: contentStr }
    const res = await updateReport(recordId, updateData)
    if (res.status === 'success') {
      // 先更新本地 records 数据，使视图立即显示最新内容，避免先切查看态再刷新带来的视觉跳动
      const localRec = records.value.find(r => r.id === recordId)
      if (localRec) {
        localRec.content = contentStr
      }
      destroySortable(); editRecordId.value = null; editingLineIdx.value = null; editLines.value = []; editingTemplateInfo.value = null; document.removeEventListener('keydown', handleKeydownSave); document.removeEventListener('mousedown', handleOutsideClick); msg('success', '修改已保存'); await loadFillData(true)
    }
    else msg('error', res.message || '更新失败')
  } catch (e) { msg('error', e.message || '更新失败') }
}

const handleSubmitSingleRecord = async (rec) => {
  if (!parseLines(rec.content).length) { msg('warning', '内容为空，无法提交'); return }
  try {
    await ElMessageBox.confirm(`确认提交「${getModuleName(rec.moduleId)}」模块周报？提交后不可撤回。`, '提交确认', { confirmButtonText: '确认提交', cancelButtonText: '取消', type: 'warning' })
    const res = await updateReport(rec.id, { status: 'submitted' })
    if (res.status === 'success') {
      // 先更新本地记录状态，确保 UI 即时响应（TOC 色点、状态标签等）
      const localRec = records.value.find(r => r.id === rec.id)
      if (localRec) localRec.status = 'submitted'
      msg('success', '已提交'); await loadFillData(true)
    }
    else msg('error', res.message || '提交失败')
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '提交失败') }
}

const handleDeleteRecord = async (reportId) => {
  try {
    await ElMessageBox.confirm('确认删除该条周报记录？删除后不可恢复。', '确认删除', { confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning' })
    const res = await deleteReport(reportId)
    if (res.status === 'success') { msg('success', '已删除'); loadFillData(true) }
    else msg('error', res.message || '删除失败')
  } catch (e) { if (e !== 'cancel') msg('error', e.message || '删除失败') }
}

const handleTabChange = (tabName) => { if (tabName === 'history') loadHistory() }

const historyStats = computed(() => {
  const submittedWeeks = historyList.value.filter(h => h.hasSubmitted)
  const total = submittedWeeks.length
  const drafts = historyList.value.filter(h => !h.hasSubmitted).length
  let totalRecords = 0
  submittedWeeks.forEach(h => { totalRecords += h.records.filter(r => r.status === 'submitted').length })
  const avg = total > 0 ? (totalRecords / total).toFixed(1) : '0'
  let streak = 0
  const weekNums = submittedWeeks.map(h => h.weekNum).sort((a, b) => b - a)
  for (let w = currentWeek; w >= 1; w--) { if (weekNums.includes(w)) streak++; else break }
  return [
    { label: '累计提交', value: total, sub: '周', color: '#303133' },
    { label: '草稿', value: drafts, sub: '周', color: '#e6a23c' },
    { label: '平均提交条目', value: avg, sub: '条/周', color: '#303133' },
    { label: '连续提交', value: streak, sub: '周', color: '#67c23a' },
  ]
})

const loadHistory = async () => {
  if (!username.value) return
  try {
    const weekPromises = []
    for (let w = currentWeek; w >= 1; w--) {
      weekPromises.push(
        getMyReports(w, username.value).then(data => {
          const recs = data?.records || []
          if (recs.length === 0) return null
          const { monday, sunday } = getWeekDateRange(currentYear, w)
          const hasSubmitted = recs.some(r => r.status === 'submitted')
          const latestSubmit = recs.filter(r => r.submitTime).sort((a, b) => new Date(b.submitTime) - new Date(a.submitTime))[0]?.submitTime || ''
          return { weekNum: w, dateRange: `${fmtDateCN(monday)} 至 ${fmtDateCN(sunday)}`, records: recs, hasSubmitted, submitTime: latestSubmit }
        }).catch(() => null)
      )
    }
    const results = await Promise.all(weekPromises)
    historyList.value = results.filter(r => r !== null).sort((a, b) => b.weekNum - a.weekNum)
  } catch (e) { console.warn('加载历史周报失败', e) }
}


const goFillWeek = (weekNum) => {
  if (weekNum === currentWeek) { fillWeekKey.value = 'current' }
  else { fillWeekKey.value = 'custom'; customWeekNum.value = weekNum }
  activeTab.value = 'fill'; loadFillData()
}

const handleReportReturned = (e) => { const { weekNum } = e.detail; if (weekNum !== fillWeek.value) return; loadFillData(true) }

// 周报状态变更（本人提交/系统自动提交）：本人记录被提交时静默刷新填写页
const handleStatusChange = (e) => {
  const { action, username: notifUser, weekNum } = e.detail || {}
  if (action === 'submitted' && notifUser === username.value && weekNum === fillWeek.value) {
    loadFillData(true)
  }
}

// 模块/子模块变更时静默刷新填写页数据（响应式更新模块列表和状态）
const handleModuleChange = () => { loadFillData(true) }

const handleBeforeUnload = () => { if (editRecordId.value) autoSaveCurrentEdit() }

// 路由离开时自动保存当前编辑
onBeforeRouteLeave(async (to, from, next) => {
  await autoSaveCurrentEdit()
  next()
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

onMounted(async () => {
  // 获取服务端当前周次（防止用户修改本地时间绕过限制）
  try { const sw = await getServerCurrentWeek(); if (sw.code === 200) serverCurrentWeek.value = sw.weekNum } catch { /* 使用本地时间兜底 */ }
  // 获取有效周范围
  await fetchWeekDateRanges(currentYear)
  // 获取综述填写开关
  try { const res = await getSummaryFillerConfig(); if (res.code === 200) summaryFillerEnabled.value = res.enabled } catch (e) { /* */ }
  try { const res = await getWeekConfig(currentWeek); if (res.code === 200 && res.data && res.data.startDate && res.data.endDate) setWeekConfig(currentWeek, res.data.startDate, res.data.endDate) } catch (e) { /* */ }
  loadFillData()  // 内部会重新加载 reportModules、subModules 和 records
  window.addEventListener('weekly-report-returned', handleReportReturned)
  window.addEventListener('weekly-report-status-change', handleStatusChange)
  window.addEventListener('weekly-report-module-change', handleModuleChange)
  window.addEventListener('beforeunload', handleBeforeUnload)
  // 默认选中第一个目录项
  nextTick(() => { if (docSections.value.length > 0) activeSectionKey.value = 'p0' })
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

// 组件卸载时移除事件监听
onUnmounted(() => {
  window.removeEventListener('weekly-report-returned', handleReportReturned)
  window.removeEventListener('weekly-report-status-change', handleStatusChange)
  window.removeEventListener('weekly-report-module-change', handleModuleChange)
  window.removeEventListener('beforeunload', handleBeforeUnload)
})
</script>

<style scoped>
.report-fill-container { width: 100%; height: 100%; display: flex; flex-direction: column; background: #fff; overflow: hidden; padding: 20px; box-sizing: border-box; }
.page-header { margin-bottom: 12px; flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; }
.help-btn {
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
.help-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 25px rgba(79,172,254,0.55) !important;
}
.help-btn:active {
  transform: translateY(0);
}
.help-btn .btn-icon {
  font-size: 16px;
  vertical-align: -2px;
  margin-right: 4px;
}
.page-title { font-size: 20px; font-weight: 700; color: #303133; margin: 0; }
.report-tabs { flex-shrink: 0; }
.tab-content { flex: 1; min-height: 0; overflow: hidden; display: flex; flex-direction: column; gap: 14px; padding-bottom: 16px; }
.filter-bar { background: #fff; padding: 10px 16px; border-radius: 10px; border: 1px solid #e4e7ed; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; flex-shrink: 0; }
.period-switch { display: flex; align-items: center; }
.fill-status-area { margin-left: auto; display: flex; align-items: center; gap: 10px; }
.week-tag { font-weight: 600; }
.deadline-hint { font-size: 12px; color: #909399; white-space: nowrap; }

.record-content-lines { min-height: 0; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; color: #606266; }

/* 共享基础：flex 布局，文本区 + 右侧按钮区完全分离 */
.content-line { display: flex; align-items: flex-start; padding: 4px 6px; border-radius: 4px; transition: background 0.15s; min-height: 32px; }

/* 文本内容区：flex占满，首行缩进 */
.line-content { flex: 1; min-width: 0; max-width: 60em; text-indent: 2em; overflow: hidden; position: relative; }

/* 拖拽手柄 */
.drag-handle { position: absolute; left: 0.1em; top: 5px; cursor: grab; color: #c0c4cc; font-size: 14px; z-index: 1; display: inline-flex; align-items: center; user-select: none; }
.drag-handle:active { cursor: grabbing; }
.sortable-ghost { opacity: 0.4; background: #e8f4ff !important; }

/* 右侧按钮 + 日期区：不缩放，顶部对齐，确保可点击 */
.line-right { flex-shrink: 0; display: flex; align-items: center; gap: 6px; margin-left: 12px; position: relative; z-index: 1; padding-top: 2px; }

/* 查看态 */
.content-line.is-idle { cursor: pointer; }
.content-line.is-idle .line-num { display: inline; margin-right: 6px; }
.content-line.is-idle .line-text { display: inline; }
.content-line.is-idle:hover { background: #f5f7fa; }

/* 编辑态 */
.content-line.editing .line-num { display: inline; margin-right: 6px; text-align: left; min-width: auto; }
.content-line.editing.is-active { background: #f0f7ff; }

/* contenteditable 编辑区：样式匹配查看态文本 */
.line-input-editable { display: inline; outline: none; color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; }
.line-input-editable:empty::before { content: '请输入内容'; color: #c0c4cc; }

/* 序号 */
.line-num { color: #909399; font-weight: 600; line-height: 1.6; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; }

/* 查看态文本 */
.line-text { color: #303133; line-height: 1.6; white-space: pre-wrap; word-break: break-word; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16px; min-height: 22px; }
.line-text.empty-hint { color: #c0c4cc; font-style: italic; margin-right: 10px; }

/* 修改时间 */
.line-meta { font-size: 11px; color: #c0c4cc; white-space: nowrap; line-height: 1.6; }

/* 无序号模式：隐藏序号 */
.no-line-num .line-num { display: none; }

/* 父模块自身内容区与子模块对齐 */
.doc-parent-content { padding-left: 16px; margin-bottom: 16px; }
.doc-parent-content .doc-sub-header { margin-bottom: 8px; }

/* 添加行按钮 */
.add-line-btn { display: block; margin-top: 4px; margin-left: 2em; }

/* 悬浮操作按钮 */
.line-hover-actions { display: none; align-items: center; gap: 0; }
.content-line.is-idle:hover .line-hover-actions { display: flex; }
.line-hover-actions .el-button { padding: 2px; }

/* 编辑态操作按钮 */
.active-line-actions { display: flex; align-items: center; gap: 0; }
.active-line-actions .el-button { padding: 2px; }
.doc-empty-hint {
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
.add-form { padding: 0 4px; }
.add-form-row { display: flex; flex-direction: column; gap: 6px; }
.add-form-label { font-size: 13px; font-weight: 600; color: #303133; margin-bottom: 4px; }
.add-form-label-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px; }
:deep(.el-dialog__title) { width: 100%; text-align: center; display: block; }
:deep(.el-dialog__footer) { display: flex; justify-content: center; }
:deep(.el-scrollbar__wrap) { overflow-x: hidden; }
:deep(.el-scrollbar__view) { overflow-x: hidden; }
.module-selector { display: flex; flex-wrap: wrap; gap: 8px; padding: 8px 0; }
.module-tag { display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer; transition: all 0.2s; border: 1px solid #e4e7ed; background: #fff; user-select: none; }
.module-tag:hover { border-color: #409eff; color: #409eff; }
.module-tag.selected { background: #ecf5ff; border-color: #409eff; color: #409eff; font-weight: 600; }
.module-tag.disabled { opacity: 0.5; cursor: not-allowed; background: #f5f7fa; border-color: #e4e7ed; color: #c0c4cc; }
.module-tag.disabled:hover { border-color: #e4e7ed; color: #c0c4cc; }
.history-content { overflow: hidden; }
.history-scroll-wrap { flex: 1; min-height: 0; }
.history-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; flex-shrink: 0; }
.stat-card { text-align: center; }
.stat-card :deep(.el-card__body) { padding: 16px; display: flex; flex-direction: column; gap: 4px; }
.stat-label { font-size: 12px; color: #909399; font-weight: 500; }
.stat-value { font-size: 24px; font-weight: 700; }
.stat-sub { font-size: 11px; color: #c0c4cc; }
.history-list-card { display: flex; flex-direction: column; min-height: 0; margin-top: 14px; }
.history-list-header { display: flex; justify-content: space-between; align-items: center; }
.history-count { font-size: 12px; color: #909399; }
.history-empty { padding: 40px; }
.history-card { cursor: pointer; transition: box-shadow 0.2s; }
.history-card:hover { box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06); }
.history-card :deep(.el-card__body) { padding: 0; }
.history-card-header { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; border-bottom: 1px solid #f0f0f0; }
.history-week-info { display: flex; align-items: center; gap: 10px; }
.history-week-num { font-size: 15px; font-weight: 700; color: #303133; }
.history-week-date { font-size: 12px; color: #909399; }
.history-meta { display: flex; align-items: center; gap: 10px; }
.module-count-badge { font-size: 12px; color: #909399; background: #f4f4f5; padding: 2px 10px; border-radius: 10px; }
.history-card-body { padding: 16px; }
.history-content-block { margin-bottom: 10px; padding: 10px 14px; background: #f5f7fa; border-radius: 8px; border-left: 3px solid #e4e7ed; }
.history-content-block:last-child { margin-bottom: 0; }
.history-content-module { font-size: 13px; font-weight: 600; color: #303133; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
.history-content-text { font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; font-size: 16pt; color: #606266; line-height: 1.7; white-space: pre-wrap; }
.history-card-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 12px; padding-top: 10px; border-top: 1px solid #f0f0f0; }
.history-time { font-size: 11px; color: #c0c4cc; }
.tag-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
.doc-layout { flex: 1; min-height: 0; display: flex; gap: 16px; overflow: hidden; }
.toc-parent.disabled { color: #c0c4cc; cursor: not-allowed; }
.toc-parent.disabled:hover { background: #f0f7ff; color: #c0c4cc; }
.toc-child.disabled { color: #d0d4d8; cursor: not-allowed; }
.toc-child.disabled:hover { background: #f0f7ff; color: #d0d4d8; }
.doc-h2.no-record { color: #d0d4d8; border-left-color: #e4e7ed !important; }
.doc-h3.no-record { color: #d0d4d8; }
.doc-toc { width: 240px; flex-shrink: 0; border-right: 1px solid #e4e7ed; overflow: hidden; font-family: '微软雅黑', 'Microsoft YaHei', sans-serif; }
.toc-title { font-size: 14px; font-weight: 700; color: #303133; padding: 8px 4px 12px; border-bottom: 2px solid #409eff; margin-bottom: 8px; letter-spacing: 4px; }
.toc-block { margin-bottom: 4px; }
.toc-parent { font-size: 12px; font-weight: 600; color: #303133; padding: 6px 4px; cursor: pointer; border-radius: 4px; display: flex; align-items: center; gap: 4px; transition: all 0.15s; white-space: nowrap; }
.toc-parent:hover { background: #f0f7ff; color: #409eff; }
.toc-parent.active { background: #ecf5ff; color: #409eff; font-weight: 700; }
.toc-child { font-size: 12px; color: #606266; padding: 4px 4px 4px 12px; cursor: pointer; border-radius: 4px; transition: all 0.15s; white-space: nowrap; }
.toc-child:hover { background: #f0f7ff; color: #409eff; }
.toc-child.active { background: #ecf5ff; color: #409eff; font-weight: 600; }
.toc-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
.toc-status-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; display: inline-block; margin-right: 6px; vertical-align: middle; }
.tip-label { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; }
.tip-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
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
.doc-content-area { min-height: 40px; }
.doc-editor { min-height: 32px; padding: 4px 0; }
.doc-viewer { min-height: 32px; padding: 4px 0; }
.doc-viewer-actions { display: flex; align-items: center; gap: 8px; margin-top: 8px; padding-top: 6px; border-top: 1px dashed #e4e7ed; }
.doc-empty-text { color: #c0c4cc; font-size: 13px; }
.two-column-layout { display: flex; flex-direction: row; gap: 20px; }
.add-form-column { flex: 1; min-width: 0; }
.left-column { border-right: 1px solid #e4e7ed; padding-right: 16px; }
.right-column { padding-left: 4px; }
.module-selector.vertical { display: flex; flex-direction: column; gap: 6px; padding: 4px 0; }
.module-selector.vertical .module-tag { width: 100%; box-sizing: border-box; justify-content: flex-start; }
.module-tag-name { flex: 1; min-width: 0; }
.sub-module-group { margin-bottom: 8px; }
.sub-module-group:last-child { margin-bottom: 0; }
.sub-group-label { font-size: 12px; font-weight: 600; color: #606266; padding: 4px 6px; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
.sub-select-all-btn { margin-left: auto; font-size: 12px; }
.sub-tag { margin-left: 8px; margin-bottom: 4px; }
.module-selector.vertical .sub-tag { width: calc(100% - 8px); }
.no-sub-hint { font-size: 13px; color: #c0c4cc; padding: 20px 6px; text-align: center; }
</style>
