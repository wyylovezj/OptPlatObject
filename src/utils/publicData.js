import { ref, computed } from 'vue'


// 定义侧边栏折叠标志
export const isCollapse = ref(false)
// 表格数据源
export const tableData = ref([])
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

// 获取所有选中行的event_id放入数组中
export const selectedEventIds = computed(() => {
  return selectedRows.value?.map(row => row.event_id)
})

// 《关闭》按钮模态框显示标识符
export const DialogVisibleClose = ref(false)
// 《关闭》按钮模态框处理意见输入值
export const handleOpinion = ref('')

// 防抖函数
export const debounce = (fn, delay) => {
  let timer = null
  return function (...args) {
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      fn.apply(this, args)
    }, delay)
  }
}

// 节流函数
export const throttle = (fn, delay) => {
  let lastTime = 0
  return function (...args) {
    const now = Date.now()
    if (now - lastTime >= delay) {
      fn.apply(this, args)
      lastTime = now
    }
  }
}
