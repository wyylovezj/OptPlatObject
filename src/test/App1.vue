<template>
  <div class="form-designer-app">
    <!-- 顶部工具栏 -->
    <div class="toolbar">
      <el-button
        v-for="type in componentTypes"
        :key="type.value"
        @click="addNewComponent(type.value)"
      >
        {{ type.label }}
      </el-button>
    </div>

    <div class="designer-layout">
      <!-- 左侧组件库 -->
      <div class="component-library">
        <h3>组件库</h3>
        <div
          v-for="type in componentTypes"
          :key="type.value"
          class="library-item"
          draggable="true"
          @dragstart="handleLibraryDragStart($event, type.value)"
        >
          {{ type.label }}
        </div>
      </div>

      <!-- 中间设计区域 -->
      <div class="design-area">
        <DynamicFormRenderer
          :initial-config="formConfig"
          @submit="handleFormSubmit"
          @component-change="handleComponentChange"
          @component-edit="handleComponentEdit"
        />
      </div>

      <!-- 右侧属性面板 -->
      <div class="property-area">
        <PropertyPanel :selected-component="selectedComponent" />
      </div>
    </div>

    <!-- 数据预览 -->
    <div class="preview-panel">
      <h3>实时数据预览</h3>
      <pre>{{ JSON.stringify(formData, null, 2) }}</pre>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import DynamicFormRenderer from './DynamicFormRenderer.vue'
import PropertyPanel from './PropertyPanel.vue'
import { useFormState } from './useFormState.js'

// 使用表单状态
const { formConfig, formData, selectedComponent, addComponent } = useFormState()

// 可用组件类型
const componentTypes = ref([
  { label: '文本输入框', value: 'text-input' },
  { label: '数字输入框', value: 'number-input' },
  { label: '下拉选择框', value: 'select' },
  { label: '日期选择器', value: 'date' },
  { label: '自定义输入框', value: 'custom-input' }
])

// 添加新组件
const addNewComponent = (type) => {
  const newComponent = addComponent(type)
  selectedComponent.value = newComponent
}

// 处理库组件拖拽开始
const handleLibraryDragStart = (event, type) => {
  event.dataTransfer.setData('component-type', type)
}

// 处理表单提交
const handleFormSubmit = (formData) => {
  console.log('表单提交:', formData)
  alert('表单提交成功！')
}

// 处理组件变化
const handleComponentChange = ({ field, value }) => {
  console.log('组件值变化:', field.modelKey, value)
}

// 处理组件编辑
const handleComponentEdit = (component) => {
  selectedComponent.value = component
}
</script>

<style scoped>
.form-designer-app {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.toolbar {
  padding: 16px;
  border-bottom: 1px solid #e0e0e0;
  background: #f5f5f5;
}

.designer-layout {
  display: flex;
  flex: 1;
  overflow: hidden;
}

.component-library {
  width: 200px;
  border-right: 1px solid #e0e0e0;
  padding: 16px;
  background: #fafafa;
}

.library-item {
  padding: 12px;
  margin-bottom: 8px;
  background: white;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  cursor: grab;
}

.library-item:active {
  cursor: grabbing;
}

.design-area {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
}

.property-area {
  width: 300px;
  border-left: 1px solid #e0e0e0;
}

.preview-panel {
  padding: 20px;
  border-top: 1px solid #e0e0e0;
  background: #f9f9f9;
  max-height: 200px;
  overflow-y: auto;
}

pre {
  background: #f5f5f5;
  padding: 12px;
  border-radius: 4px;
  font-size: 12px;
  white-space: pre-wrap;
}
</style>
