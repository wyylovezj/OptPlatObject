<template>
  <div class="custom-input" :class="customClasses" :style="containerStyle">
    <!-- 输入框标签 -->
    <div v-if="showLabel" class="custom-input-label">
      {{ label }}
      <span v-if="required" class="required-mark">*</span>
    </div>

    <!-- 主输入区域 -->
    <div class="input-wrapper" :class="wrapperClasses">
      <!-- 前缀内容 -->
      <div v-if="showPrefix" class="prefix-area">
        <span v-if="prefixText" class="prefix-text">{{ prefixText }}</span>
        <i v-if="prefixIcon" :class="['prefix-icon', prefixIcon]" @click="handlePrefixClick"></i>
      </div>

      <!-- 核心输入框 -->
      <el-input
        ref="inputRef"
        v-bind="inputAttrs"
        v-model="inputValue"
        :class="inputClasses"
        :style="inputStyle"
        :type="inputType"
        :placeholder="placeholder"
        :disabled="disabled"
        :readonly="readonly"
        :maxlength="maxlength"
        :show-word-limit="showWordLimit"
        :clearable="clearable"
        :show-password="showPassword"
        @input="handleInput"
        @change="handleChange"
        @focus="handleFocus"
        @blur="handleBlur"
        @keydown="handleKeydown"
        @keyup="handleKeyup"
      >
        <!-- 默认插槽，用于自定义前置内容 -->
        <template v-if="$slots.prepend" #prepend>
          <slot name="prepend"></slot>
        </template>

        <!-- 默认插槽，用于自定义后置内容 -->
        <template v-if="$slots.append" #append>
          <slot name="append"></slot>
        </template>
      </el-input>

      <!-- 后缀内容 -->
      <div v-if="showSuffix" class="suffix-area">
        <i v-if="suffixIcon" :class="['suffix-icon', suffixIcon]" @click="handleSuffixClick"></i>
        <span v-if="suffixText" class="suffix-text">{{ suffixText }}</span>
      </div>
    </div>

    <!-- 装饰元素 -->
    <div v-if="showDecorations" class="decorations">
      <span
        v-for="(decoration, index) in decorations"
        :key="index"
        class="decoration-item"
        :class="{ 'clickable': decoration.clickable }"
        :style="decoration.style"
        @click="decoration.clickable && handleDecorationClick(decoration)"
      >
        <i v-if="decoration.icon" :class="decoration.icon"></i>
        <span v-else>{{ decoration.text }}</span>
      </span>
    </div>

    <!-- 提示信息 -->
    <div v-if="hint" class="hint-text">{{ hint }}</div>

    <!-- 错误信息 -->
    <div v-if="error" class="error-text">
      <i class="el-icon-warning"></i>
      <span>{{ error }}</span>
    </div>

    <!-- 字数统计（如果使用内置的show-word-limit，可以移除这个） -->
    <div v-if="showCounter" class="character-counter">
      {{ currentLength }}/{{ maxlength }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'

// 定义组件属性
const props = defineProps({
  // 基础属性
  modelValue: {
    type: [String, Number],
    default: ''
  },
  label: {
    type: String,
    default: ''
  },
  placeholder: {
    type: String,
    default: '请输入内容'
  },
  type: {
    type: String,
    default: 'text',
    validator: (value) => ['text', 'password', 'textarea', 'number', 'email', 'tel', 'url'].includes(value)
  },

  // 状态属性
  disabled: {
    type: Boolean,
    default: false
  },
  readonly: {
    type: Boolean,
    default: false
  },
  required: {
    type: Boolean,
    default: false
  },

  // 样式配置
  size: {
    type: String,
    default: 'default',
    validator: (value) => ['large', 'default', 'small'].includes(value)
  },
  customClass: {
    type: String,
    default: ''
  },
  width: {
    type: String,
    default: '100%'
  },
  height: {
    type: String,
    default: ''
  },
  borderRadius: {
    type: String,
    default: '4px'
  },
  borderColor: {
    type: String,
    default: '#dcdfe6'
  },
  focusBorderColor: {
    type: String,
    default: '#409eff'
  },

  // 前缀/后缀配置
  prefixText: {
    type: String,
    default: ''
  },
  prefixIcon: {
    type: String,
    default: ''
  },
  suffixText: {
    type: String,
    default: ''
  },
  suffixIcon: {
    type: String,
    default: ''
  },

  // 验证与限制
  maxlength: {
    type: Number,
    default: null
  },
  minlength: {
    type: Number,
    default: null
  },
  pattern: {
    type: String,
    default: ''
  },
  validator: {
    type: Function,
    default: null
  },

  // 功能配置
  clearable: {
    type: Boolean,
    default: false
  },
  showPassword: {
    type: Boolean,
    default: false
  },
  showWordLimit: {
    type: Boolean,
    default: false
  },
  showLabel: {
    type: Boolean,
    default: true
  },
  showCounter: {
    type: Boolean,
    default: false
  },
  showDecorations: {
    type: Boolean,
    default: false
  },
  decorations: {
    type: Array,
    default: () => [
      { text: '★', clickable: true },
      { text: '☆', clickable: true },
      { text: '✓', clickable: true }
    ]
  },

  // 错误与提示
  error: {
    type: String,
    default: ''
  },
  hint: {
    type: String,
    default: ''
  },

  // Element Input 的其他属性
  inputAttrs: {
    type: Object,
    default: () => ({})
  }
})

// 定义事件
const emit = defineEmits([
  'update:modelValue',
  'input',
  'change',
  'focus',
  'blur',
  'keydown',
  'keyup',
  'clear',
  'prefix-click',
  'suffix-click',
  'decoration-click',
  'validate'
])

// 响应式数据
const inputRef = ref(null)
const isFocused = ref(false)
const currentLength = ref(0)

// 计算属性
const inputValue = computed({
  get: () => props.modelValue,
  set: (value) => {
    currentLength.value = value?.toString().length || 0
    emit('update:modelValue', value)
  }
})

const inputType = computed(() => {
  if (props.type === 'password' && props.showPassword) {
    return 'text'
  }
  return props.type
})

const showPrefix = computed(() => props.prefixText || props.prefixIcon)
const showSuffix = computed(() => props.suffixText || props.suffixIcon)

const customClasses = computed(() => ({
  'custom-input': true,
  [`size-${props.size}`]: true,
  'has-error': props.error,
  'is-disabled': props.disabled,
  'is-focused': isFocused.value,
  [props.customClass]: !!props.customClass
}))

const wrapperClasses = computed(() => ({
  'has-prefix': showPrefix.value,
  'has-suffix': showSuffix.value
}))

const inputClasses = computed(() => ({
  'has-error': props.error
}))

const containerStyle = computed(() => ({
  width: props.width,
  height: props.height
}))

const inputStyle = computed(() => ({
  '--border-radius': props.borderRadius,
  '--border-color': props.borderColor,
  '--focus-border-color': props.focusBorderColor
}))

// 生命周期
onMounted(() => {
  currentLength.value = props.modelValue?.toString().length || 0
})

// 监听值变化
watch(() => props.modelValue, (newValue) => {
  currentLength.value = newValue?.toString().length || 0
})

// 方法
const handleInput = (value) => {
  // 字数限制
  if (props.maxlength && value && value.length > props.maxlength) {
    inputValue.value = value.slice(0, props.maxlength)
    return
  }

  // 触发验证
  validate(value)

  // 发出事件
  emit('input', value)
}

const handleChange = (value) => {
  emit('change', value)
}

const handleFocus = (event) => {
  isFocused.value = true
  emit('focus', event)
}

const handleBlur = (event) => {
  isFocused.value = false
  emit('blur', event)

  // 失去焦点时进行完整验证
  validate(props.modelValue, true)
}

const handleKeydown = (event) => {
  emit('keydown', event)
}

const handleKeyup = (event) => {
  emit('keyup', event)
}

const handlePrefixClick = () => {
  emit('prefix-click', props.modelValue)
}

const handleSuffixClick = () => {
  emit('suffix-click', props.modelValue)
}

const handleDecorationClick = (decoration) => {
  emit('decoration-click', decoration)
}

// 验证函数
const validate = (value, isBlur = false) => {
  let isValid = true
  let errorMessage = ''

  // 必填验证
  if (props.required && (!value || value.toString().trim() === '')) {
    isValid = false
    errorMessage = '此字段为必填项'
  }

  // 最小长度验证
  if (isValid && props.minlength && value && value.length < props.minlength) {
    isValid = false
    errorMessage = `至少需要 ${props.minlength} 个字符`
  }

  // 最大长度验证
  if (isValid && props.maxlength && value && value.length > props.maxlength) {
    isValid = false
    errorMessage = `不能超过 ${props.maxlength} 个字符`
  }

  // 正则验证
  if (isValid && props.pattern && value) {
    const regex = new RegExp(props.pattern)
    if (!regex.test(value)) {
      isValid = false
      errorMessage = '格式不正确'
    }
  }

  // 自定义验证器
  if (isValid && props.validator && typeof props.validator === 'function') {
    const result = props.validator(value)
    if (result !== true) {
      isValid = false
      errorMessage = result || '验证失败'
    }
  }

  // 发出验证事件
  emit('validate', {
    isValid,
    errorMessage,
    value,
    isBlur
  })

  return isValid
}

// 暴露给父组件的方法
defineExpose({
  // 获取原生输入框引用
  getInputElement: () => inputRef.value?.inputRef || inputRef.value?.textareaRef,

  // 聚焦输入框
  focus: () => {
    if (inputRef.value) {
      inputRef.value.focus()
    }
  },

  // 失焦输入框
  blur: () => {
    if (inputRef.value) {
      inputRef.value.blur()
    }
  },

  // 选中文本
  select: () => {
    if (inputRef.value) {
      inputRef.value.select()
    }
  },

  // 验证输入
  validate: () => {
    return validate(props.modelValue)
  },

  // 清空输入
  clear: () => {
    inputValue.value = ''
    emit('clear')
  },

  // 获取当前值
  getValue: () => props.modelValue
})
</script>

<style scoped>
.custom-input {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  margin-bottom: 20px;
  transition: all 0.3s ease;
}

.custom-input-label {
  font-size: 14px;
  font-weight: 500;
  color: #606266;
  margin-bottom: 8px;
  display: flex;
  align-items: center;
}

.required-mark {
  color: #f56c6c;
  margin-left: 4px;
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  width: 100%;
  border: 1px solid var(--border-color, #dcdfe6);
  border-radius: var(--border-radius, 4px);
  transition: border-color 0.3s ease, box-shadow 0.3s ease;
  overflow: hidden;
}

.custom-input.is-focused .input-wrapper {
  border-color: var(--focus-border-color, #409eff);
  box-shadow: 0 0 0 2px rgba(64, 158, 255, 0.1);
}

.custom-input.has-error .input-wrapper {
  border-color: #f56c6c;
}

.custom-input.is-disabled .input-wrapper {
  background-color: #f5f7fa;
  border-color: #e4e7ed;
  cursor: not-allowed;
}

.custom-input.size-small .input-wrapper {
  height: 32px;
}

.custom-input.size-default .input-wrapper {
  height: 40px;
}

.custom-input.size-large .input-wrapper {
  height: 48px;
}

/* 前缀区域 */
.prefix-area {
  display: flex;
  align-items: center;
  padding: 0 12px;
  background: #f5f7fa;
  border-right: 1px solid #e4e7ed;
  height: 100%;
  white-space: nowrap;
}

.prefix-text {
  font-size: 14px;
  color: #909399;
}

.prefix-icon {
  color: #909399;
  font-size: 16px;
  cursor: pointer;
  transition: color 0.3s ease;
}

.prefix-icon:hover {
  color: #409eff;
}

/* 后缀区域 */
.suffix-area {
  display: flex;
  align-items: center;
  padding: 0 12px;
  background: #f5f7fa;
  border-left: 1px solid #e4e7ed;
  height: 100%;
  white-space: nowrap;
}

.suffix-text {
  font-size: 14px;
  color: #909399;
}

.suffix-icon {
  color: #909399;
  font-size: 16px;
  cursor: pointer;
  transition: color 0.3s ease;
}

.suffix-icon:hover {
  color: #409eff;
}

/* 输入框样式覆盖 */
:deep(.el-input) {
  flex: 1;
  height: 100%;
}

:deep(.el-input__wrapper) {
  border: none !important;
  box-shadow: none !important;
  height: 100%;
  border-radius: 0;
  padding: 0 12px;
}

:deep(.el-input__inner) {
  height: 100%;
  line-height: 1;
  border: none;
  outline: none;
  background: transparent;
  font-size: 14px;
  color: #303133;
}

:deep(.el-input__inner::placeholder) {
  color: #c0c4cc;
}

.custom-input.is-disabled :deep(.el-input__inner) {
  color: #c0c4cc;
  cursor: not-allowed;
  background: transparent;
}

/* 装饰区域 */
.decorations {
  display: flex;
  gap: 8px;
  margin-top: 8px;
  flex-wrap: wrap;
}

.decoration-item {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 2px 8px;
  background: #f0f2f5;
  border-radius: 4px;
  font-size: 12px;
  color: #606266;
  transition: all 0.3s ease;
  cursor: default;
  user-select: none;
}

.decoration-item.clickable {
  cursor: pointer;
}

.decoration-item.clickable:hover {
  background: #e4e7ed;
  color: #409eff;
  transform: translateY(-1px);
}

/* 提示与错误信息 */
.hint-text {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
  line-height: 1.5;
}

.error-text {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: #f56c6c;
  margin-top: 4px;
  line-height: 1.5;
}

.error-text i {
  font-size: 14px;
}

/* 字数统计 */
.character-counter {
  text-align: right;
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
</style>
