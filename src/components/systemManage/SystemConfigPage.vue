<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：系统配置页面（告警语音播报参数配置）
 * @date： 2026-09-11 10:00:00
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-09-11 10:00:00
 */
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getAlarmConfig, updateAlarmConfig } from '@/api/userPermisssion.js'
import { applyAlarmConfig } from '@/utils/publicData.js'

// 告警播报参数值：0-关闭语音播报，1-开启语音播报（默认）
const configValue = ref(1)
// 加载状态
const loading = ref(false)
// 保存状态
const saving = ref(false)

const getUsername = () => sessionStorage.getItem('user') || ''

// 加载当前用户的告警播报配置
const loadConfig = async () => {
  const username = getUsername()
  if (!username) return
  loading.value = true
  try {
    const value = await getAlarmConfig(username)
    configValue.value = value === 0 ? 0 : 1
  } catch (e) {
    ElMessage.error('加载告警播报配置失败：' + e.message)
  } finally {
    loading.value = false
  }
}

// 保存配置：写入 sys_user.config_alarm_status，并立刻重新读取应用到告警播报
const handleSave = async () => {
  const username = getUsername()
  if (!username) return
  saving.value = true
  try {
    await updateAlarmConfig(username, configValue.value)
    // 保存成功后立刻重新读取该参数并应用到告警播报（静默应用，此处由页面提示结果）
    await applyAlarmConfig(username, true)
    ElMessage.success(configValue.value === 1 ? '配置已保存，已开启语音播报' : '配置已保存，已关闭语音播报')
  } catch (e) {
    ElMessage.error('保存配置失败：' + e.message)
  } finally {
    saving.value = false
  }
}

// 还原为已保存的配置值
const handleReset = () => {
  loadConfig()
}

onMounted(loadConfig)
</script>

<template>
  <div class="system-config-page">
    <el-card class="config-card" shadow="never" v-loading="loading">
      <!-- 卡片头部 -->
      <div class="config-header">
        <div class="config-header-left">
          <div class="config-header-icon">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z"/></svg>
          </div>
          <div class="config-header-text">
            <span class="config-title-text">系统配置</span>
            <span class="config-subtitle">个性化参数配置，保存后立即生效</span>
          </div>
        </div>
      </div>

      <!-- 配置内容 -->
      <div class="config-body">
        <div class="config-section">
          <div class="config-section-title">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#5b7fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
            告警播报设置
          </div>

          <div class="config-item">
            <div class="config-item-info">
              <span class="config-item-name">告警播报参数</span>
              <span class="config-item-desc">控制严重告警语音播报的开启与关闭，保存后写入当前用户配置</span>
            </div>
            <div class="config-item-control">
              <el-select v-model="configValue" class="config-select">
                <el-option :value="1" label="1（开启语音播报）" />
                <el-option :value="0" label="0（关闭语音播报）" />
              </el-select>
            </div>
          </div>

          <div class="config-notes">
            <div class="note-line"><span class="note-icon">✅</span><span class="note-text">参数值为 <strong>1</strong>（默认）：正常播报严重告警；告警数据页面刷新后，会提示“页面刷新会终止语音播报，请点击知道了继续语音播报”。</span></div>
            <div class="note-line"><span class="note-icon">🔕</span><span class="note-text">参数值为 <strong>0</strong>：关闭语音播报；告警数据页面刷新后不再弹出提示框。</span></div>
            <div class="note-line"><span class="note-icon">💡</span><span class="note-text">顶部导航栏的喇叭图标可快捷切换该配置，效果与在此保存一致。</span></div>
          </div>
        </div>
      </div>

      <!-- 底部操作 -->
      <div class="config-footer">
        <el-button class="config-btn-save" :loading="saving" @click="handleSave">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>&nbsp;保存配置
        </el-button>
        <el-button class="config-btn-reset" @click="handleReset">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 102.13-9.36L1 10"/></svg>&nbsp;还原
        </el-button>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.system-config-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  user-select: none;
}

.config-card {
  flex: 1;
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.config-card :deep(.el-card__body) {
  display: flex;
  flex-direction: column;
  flex: 1;
  padding: 0;
  overflow: hidden;
}

/* 卡片头部 */
.config-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px 24px;
  border-bottom: 1px solid #f0f2f5;
}

.config-header-left {
  display: flex;
  align-items: center;
  gap: 14px;
}

.config-header-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.config-header-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.config-title-text {
  font-size: 17px;
  font-weight: 700;
  color: #303133;
  line-height: 1.4;
}

.config-subtitle {
  font-size: 12px;
  color: #909399;
  line-height: 1.4;
}

/* 配置内容 */
.config-body {
  flex: 1;
  padding: 20px 24px;
  overflow-y: auto;
}

.config-section {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 16px 20px;
}

.config-section-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 16px;
}

.config-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  background: #ffffff;
  border: 1px solid #ebeef5;
  border-radius: 8px;
  padding: 14px 18px;
}

.config-item-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.config-item-name {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  line-height: 1.5;
}

.config-item-desc {
  font-size: 12px;
  color: #909399;
  line-height: 1.6;
}

.config-item-control {
  flex-shrink: 0;
  display: flex;
  align-items: center;
}

/* 下拉框：宽度精准适配选项文本，选中项水平居中 */
.config-select {
  width: 210px;
}

.config-select :deep(.el-select__wrapper),
.config-select :deep(.el-input__wrapper) {
  justify-content: center;
  border-radius: 6px;
  box-shadow: 0 0 0 1px #e2e8f0 inset !important;
}

.config-select :deep(.el-select__wrapper.is-focused) {
  box-shadow: 0 0 0 1px #2563eb inset, 0 0 0 3px rgba(37, 99, 235, 0.1) !important;
}

/* 参数说明 */
.config-notes {
  margin-top: 14px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.note-line {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  font-size: 12px;
  color: #606266;
  line-height: 1.7;
}

.note-icon {
  flex-shrink: 0;
  line-height: 1.7;
}

.note-text strong {
  color: #5b7fff;
  font-weight: 700;
}

/* 底部操作 */
.config-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 14px 24px;
  border-top: 1px solid #f0f2f5;
}

.config-btn-save,
.config-btn-reset {
  height: 32px;
  padding: 0 16px;
  border-radius: 8px !important;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  font-size: 13px;
  font-weight: 500;
  border: none;
  color: #fff;
  transition: all 0.25s ease;
}

.config-btn-save {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.config-btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(102, 126, 234, 0.4);
}

.config-btn-reset {
  background: linear-gradient(135deg, #e6a23c, #c68a2e);
}

.config-btn-reset:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(230, 162, 60, 0.4);
}
</style>
