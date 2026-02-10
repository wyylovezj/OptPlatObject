<template>
  <div class="property-panel" v-if="selectedComponent">
    <h3>组件属性配置</h3>

    <el-form label-width="80px">
      <!-- 基础配置 -->
      <el-form-item label="标签文本">
        <el-input v-model="selectedComponent.label" />
      </el-form-item>

      <el-form-item label="字段标识">
        <el-input v-model="selectedComponent.modelKey" />
      </el-form-item>

      <!-- 属性配置 -->
      <el-form-item label="占位符">
        <el-input v-model="selectedComponent.props.placeholder" />
      </el-form-item>

      <el-form-item label="尺寸">
        <el-select v-model="selectedComponent.props.size">
          <el-option label="默认" value="default" />
          <el-option label="大号" value="large" />
          <el-option label="小号" value="small" />
        </el-select>
      </el-form-item>

      <!-- 验证规则 -->
      <el-form-item label="必填字段">
        <el-switch v-model="selectedComponent.required" />
      </el-form-item>

      <template v-if="selectedComponent.required">
        <el-form-item label="错误提示">
          <el-input v-model="selectedComponent.errorMessage" placeholder="必填字段提示信息" />
        </el-form-item>
      </template>

      <!-- 自定义输入框特有配置 -->
      <template v-if="selectedComponent.type === 'custom-input'">
        <el-form-item label="前缀图标">
          <el-input v-model="selectedComponent.props.prefixIcon" />
        </el-form-item>

        <el-form-item label="后缀图标">
          <el-input v-model="selectedComponent.props.suffixIcon" />
        </el-form-item>

        <el-form-item label="显示计数">
          <el-switch v-model="selectedComponent.props.showWordLimit" />
        </el-form-item>
      </template>
    </el-form>
  </div>
</template>

<script setup>
import { watch } from 'vue'

const props = defineProps({
  selectedComponent: {
    type: Object,
    default: null
  }
})

// 监听组件变化，确保响应式更新
watch(() => props.selectedComponent, (newVal) => {
  if (newVal) {
    // 确保必要的属性存在
    if (!newVal.props) {
      newVal.props = {}
    }
    if (!newVal.style) {
      newVal.style = {}
    }
  }
}, { immediate: true })
</script>

<style scoped>
.property-panel {
  padding: 20px;
  border-left: 1px solid #e0e0e0;
  height: 100%;
  overflow-y: auto;
}
</style>
