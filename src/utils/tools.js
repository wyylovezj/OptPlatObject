import { ref, computed } from 'vue'

// 刷新按钮加载状态标志
export const loading = ref(false)

// 表格当前页
export const currentPage = ref(1)

// 初始化查询参数模型
export const Query = {
  category: '',
  severity: '',
  ip: '',
  object: '',
  system_name: '',
  occurrenceTime: [],
  timeSelect: '',
  state:'',
  source: ''
}

// 表格当前选中行的数组
export const selectedRows = ref([])

// 获取所有选中行的event_id数组
export const selectedEventIds = computed(() => {
  return selectedRows.value?.map(row => row.event_id)
})

// 《关闭》按钮模态框显示标识符
export const DialogVisibleClose = ref(false)
