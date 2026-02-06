import { ref, reactive, computed } from 'vue'

export function useFormState(initialConfig = []) {
  // 表单组件配置
  const formConfig = ref(initialConfig)

  // 表单数据
  const formData = reactive({})

  // 错误信息
  const errors = reactive({})

  // 选中的组件
  const selectedComponent = ref(null)

  // 初始化表单数据
  const initializeFormData = () => {
    formConfig.value.forEach(field => {
      formData[field.modelKey] = field.defaultValue || ''
    })
  }

  // 添加新组件
  const addComponent = (type, config = {}) => {
    const newComponent = {
      id: `comp_${Date.now()}`,
      type,
      label: config.label || `字段${formConfig.value.length + 1}`,
      component: getComponentName(type),
      props: config.props || {},
      modelKey: config.modelKey || `field_${Date.now()}`,
      style: config.style || {},
      rules: config.rules || []
    }

    formConfig.value.push(newComponent)
    formData[newComponent.modelKey] = ''

    return newComponent
  }

  // 删除组件
  const removeComponent = (componentId) => {
    const index = formConfig.value.findIndex(comp => comp.id === componentId)
    if (index > -1) {
      const component = formConfig.value[index]
      delete formData[component.modelKey]
      formConfig.value.splice(index, 1)

      if (selectedComponent.value?.id === componentId) {
        selectedComponent.value = null
      }
    }
  }

  // 更新组件属性
  const updateComponentProps = (componentId, newProps) => {
    const component = formConfig.value.find(comp => comp.id === componentId)
    if (component) {
      component.props = { ...component.props, ...newProps }
    }
  }

  // 获取组件类型对应的组件名
  const getComponentName = (type) => {
    const componentMap = {
      'text-input': 'ElInput',
      'number-input': 'ElInputNumber',
      'select': 'ElSelect',
      'date': 'ElDatePicker',
      'custom-input': 'CustomInput'
    }
    return componentMap[type] || 'ElInput'
  }

  // 表单验证状态
  const isValid = computed(() => {
    return Object.keys(errors).length === 0
  })

  return {
    formConfig,
    formData,
    errors,
    selectedComponent,
    isValid,
    initializeFormData,
    addComponent,
    removeComponent,
    updateComponentProps
  }
}
