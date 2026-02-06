<template>
  <div class="dynamic-form-renderer" ref="formContainer">
    <el-form :model="formData" label-width="120px" @submit.prevent="handleSubmit">
      <div
        v-for="(field, index) in formConfig"
        :key="field.id"
        class="form-field-container"
        :class="{
          'selected': selectedComponent?.id === field.id,
          'drag-over': dropTarget?.id === field.id
        }"
        draggable="true"
        @dragstart="handleDragStart($event, field)"
        @dragover="handleDragOver($event, field)"
        @drop="handleDrop($event, formConfig)"
        @dragend="handleDragEnd"
        @click="selectComponent(field)"
      >
        <el-form-item :label="field.label" :prop="field.modelKey">
          <component
            :is="getDynamicComponent(field.component)"
            v-model="formData[field.modelKey]"
            v-bind="field.props"
            :style="field.style"
            @change="handleComponentChange(field, $event)"
            @input="handleInput(field, $event)"
          />

          <!-- 错误提示 -->
          <div v-if="errors[field.modelKey]" class="error-message">
            {{ errors[field.modelKey] }}
          </div>

          <!-- 自定义输入框操作 -->
          <div v-if="field.type === 'custom-input'" class="custom-actions">
            <el-button link @click="editCustomComponent(field)">
              自定义设置
            </el-button>
          </div>
        </el-form-item>

        <!-- 组件操作按钮 -->
        <div class="component-actions">
          <el-button size="small" @click.stop="removeComponent(field.id)">
            删除
          </el-button>
        </div>
      </div>

      <el-form-item>
        <el-button type="primary" native-type="submit" :disabled="!isValid">
          提交表单
        </el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script setup>
import { ElInput, ElSelect, ElDatePicker, ElInputNumber } from 'element-plus'
import CustomInput from './CustomInput.vue'
import { useFormState } from './useFormState.js'
import { useFormValidation } from './useFormValidation.js'
import { useDragAndDrop } from './useDragAndDrop.js'

// 接收初始配置
const props = defineProps({
  initialConfig: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits(['submit', 'componentChange', 'componentEdit'])

// 使用组合式函数
const { formConfig, formData, errors, selectedComponent, isValid, removeComponent } = useFormState(props.initialConfig)
const { validateForm, setupFieldWatchers } = useFormValidation(formData, formConfig)
const { handleDragStart, handleDragOver, handleDrop, handleDragEnd, dropTarget } = useDragAndDrop()

// 组件映射
const componentMap = {
  ElInput,
  ElSelect,
  ElDatePicker,
  ElInputNumber,
  CustomInput
}

// 获取动态组件
const getDynamicComponent = (componentName) => {
  return componentMap[componentName] || ElInput
}

// 选择组件
const selectComponent = (component) => {
  selectedComponent.value = component
}

// 编辑自定义组件
const editCustomComponent = (component) => {
  emit('componentEdit', component)
}

// 处理输入
const handleInput = (field, value) => {
  emit('componentChange', { field, value })
}

// 处理组件变化
const handleComponentChange = (field, event) => {
  emit('componentChange', { field, event })
}

// 提交表单
const handleSubmit = () => {
  if (validateForm()) {
    emit('submit', formData)
  }
}

// 初始化
const initialize = () => {
  setupFieldWatchers()
}

initialize()
</script>

<style scoped>
.form-field-container {
  position: relative;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 16px;
  margin-bottom: 16px;
  transition: all 0.3s ease;
}

.form-field-container:hover {
  border-color: #409eff;
}

.form-field-container.selected {
  border-color: #409eff;
  box-shadow: 0 0 0 2px rgba(64, 158, 255, 0.2);
}

.form-field-container.drag-over {
  background-color: #f0f9ff;
}

.component-actions {
  position: absolute;
  top: 8px;
  right: 8px;
}

.custom-actions {
  margin-top: 8px;
}

.error-message {
  color: #f56c6c;
  font-size: 12px;
  margin-top: 4px;
}
</style>
