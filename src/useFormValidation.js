import { ref, watch } from 'vue'

export function useFormValidation(formData, formConfig) {
  const errors = ref({})

  // 验证规则映射
  const validationRules = {
    required: (value, field) => {
      if (field.required && (!value || value.toString().trim() === '')) {
        return `${field.label}是必填字段`
      }
      return null
    },

    minLength: (value, field) => {
      if (field.minLength && value && value.length < field.minLength) {
        return `${field.label}至少需要${field.minLength}个字符`
      }
      return null
    },

    maxLength: (value, field) => {
      if (field.maxLength && value && value.length > field.maxLength) {
        return `${field.label}不能超过${field.maxLength}个字符`
      }
      return null
    },

    pattern: (value, field) => {
      if (field.pattern && value) {
        const regex = new RegExp(field.pattern)
        if (!regex.test(value)) {
          return field.validationMessage || `${field.label}格式不正确`
        }
      }
      return null
    },

    email: (value, field) => {
      if (field.type === 'email' && value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        if (!emailRegex.test(value)) {
          return '请输入有效的电子邮件地址'
        }
      }
      return null
    }
  }

  // 验证单个字段
  const validateField = (field) => {
    const value = formData[field.modelKey]
    const fieldErrors = []

    // 应用所有验证规则
    Object.keys(validationRules).forEach(ruleKey => {
      if (field[ruleKey] !== undefined) {
        const error = validationRules[ruleKey](value, field)
        if (error) {
          fieldErrors.push(error)
        }
      }
    })

    // 自定义验证器
    if (field.validators && Array.isArray(field.validators)) {
      field.validators.forEach(validator => {
        const error = validator(value, field)
        if (error) {
          fieldErrors.push(error)
        }
      })
    }

    if (fieldErrors.length > 0) {
      errors.value[field.modelKey] = fieldErrors[0] // 只显示第一个错误
    } else {
      delete errors.value[field.modelKey]
    }

    return fieldErrors.length === 0
  }

  // 验证整个表单
  const validateForm = () => {
    let isValid = true

    formConfig.value.forEach(field => {
      if (!validateField(field)) {
        isValid = false
      }
    })

    return isValid
  }

  // 监听表单数据变化进行实时验证
  const setupFieldWatchers = () => {
    formConfig.value.forEach(field => {
      watch(() => formData[field.modelKey], () => {
        validateField(field)
      })
    })
  }

  // 清除所有错误
  const clearErrors = () => {
    errors.value = {}
  }

  return {
    errors,
    validateField,
    validateForm,
    setupFieldWatchers,
    clearErrors
  }
}
