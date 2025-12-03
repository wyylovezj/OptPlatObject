import { ref, computed } from 'vue'



// 侧边栏折叠标志：false为展开，true为折叠
export const isCollapse = ref(false)

// 表格数据模型数组：用于获取表格
export const tableData = ref([])

// 表格数据查询时加载图形状态标志：false为不显示，true为显示
export const loading = ref(false)

// 登录时加载图形状态标志：false为不显示，true为显示
export const loginLoading = ref(false)

// 严重告警图形闪烁动画的标志：false为不闪烁，true为闪烁
export const blinkTrigger = ref(true)

// 表格当前页码：默认值为第一页
export const currentPage = ref(1)

// 当前显示的提示框实例对象：用于控制提示框的开启与关闭，限制整个项目中同一时刻最多仅有一个提示框显示
export const messageInstance = ref(null)

// 数据查询参数的数据模型
export const Query = {
  category: '',      // 告警分类
  severity: '',      // 告警级别
  ip: '',            // IP地址
  object: '',        // 主机名
  system_name: '',   // 业务系统
  occurrenceTime: [], // 发生时间
  timeSelect: '',    // 快捷选择时间：今天，明天
  state:'',         // 告警状态
  source: ''         // 告警来源
}

// 表格当前选中行的数组：数组中的每一项代表一个选中的行
export const selectedRows = ref([])

// 表格当前选中行的event_id的数组：数组中的每一项代表一个选中的行的event_id
export const selectedEventIds = computed(() => {
  // 获取表格当前选中行的数组中每一项的event_id：
  // ？：该操作符号用于安全访问selectedRows.value，防止数组为空时抛出错误；
  // map：返回一个新数组，数组中的每一项是selectedRows.value中每一项的event_id
  return selectedRows.value?.map(row => row.event_id)
})

// 《关闭》按钮模态框显示标识符：false为不显示，true为显示
export const DialogVisibleClose = ref(false)

// 《关闭》按钮模态框处理意见输入值：同步获取用户输入
export const handleOpinion = ref('')

/**
 * 防抖函数
 * @param {Function} fn - 需要防抖的函数
 * @param {number} delay - 延迟时间，单位为毫秒
 * @returns {Function} - 返回一个经过防抖处理的函数
 */
export const debounce = (fn, delay) => {
  let timer = null // 用于存储定时器的变量
  return function (...args) {
    // 如果已经存在定时器，则清除之前的定时器
    if (timer) clearTimeout(timer)
    // 设置新的定时器，在指定的延迟时间后执行传入的函数
    timer = setTimeout(() => {
      // 使用apply调用原始函数，并传入正确的this上下文和参数
      fn.apply(this, args)
    }, delay)
  }
}

/**
 * 节流函数：确保函数在指定的时间间隔内最多执行一次
 * @param {Function} fn - 需要被节流的函数
 * @param {number} delay - 时间间隔，单位为毫秒
 * @returns {Function} - 返回被节流处理后的函数
 */
export const throttle = (fn, delay) => {
  let lastTime = 0  // 记录上次执行函数的时间戳
  return function (...args) {
    const now = Date.now()  // 获取当前时间戳
    // 如果当前时间与上次执行时间的差值大于等于设定的延迟时间
    if (now - lastTime >= delay) {
      fn.apply(this, args)  // 执行原函数
      lastTime = now  // 更新上次执行时间为当前时间
    }
  }
}
