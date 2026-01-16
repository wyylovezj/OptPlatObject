import { searchData } from '@/api/interface.js'
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
// 表格组件实例的引用
export const tableRef = ref(null)

// 侧边栏折叠标志：false为展开，true为折叠
export const isCollapse = ref(false)

// 表格数据模型数组：用于获取表格数据
export const tableData = ref([])

// 表格数据查询时加载图形状态标志：false为不显示，true为显示
export const loading = ref(false)

// 登录时加载图形状态标志：false为不显示，true为显示
export const loginLoading = ref(false)

// 严重告警图形闪烁动画的标志：false为不闪烁，true为闪烁
export const blinkTrigger = ref(true)

// 分页组件当前页码：默认值为第一页
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
  // timeSelect: '',    // 快捷选择时间：今天，明天
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

// 定时器
export const timer = ref(null)

// 语音播报状态：用于喇叭状态
export const voiceStatus = ref(false)

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
// 表单查询数据模型
export const searchQuery = ref(JSON.parse(JSON.stringify(Query)))
// 搜索按钮、刷新按钮查询数据,增加了节流控制
export const refresh = throttle(async () => {
  // 设置加载标志为true,控制表格加载动画
  loading.value = true
  // 关闭告警图形动画
  blinkTrigger.value = false
  // 为防止刷新数据过程太快导致加载动画不显示，设置一个最小延迟promise，确保异步过程至少是300 ms
  const minDelay = new Promise(resolve => setTimeout(resolve, 300))
  try {
    // 将Promise数组中第一个promise执行结果复制给data
    const [data] = await Promise.all([
      searchData(searchQuery.value),
      minDelay
    ])
    // 对获取的数据进行排序后再赋值给tableData
    tableData.value = data.sort(sortSeverity)
    // 重置表格组件中级别列的排序图标为默认状态
    if (tableRef.value) {
      tableRef.value.clearSort()
    }
    // 重新开启动画，确保动画开始时间相同，频率一致
    blinkTrigger.value = true
    currentPage.value = 1
  }
  finally {
    loading.value = false
  }
}, 300)

/**
 * 处理表格级别属性排序变化
 * @param order - 表格传入的界别字段排序参数，ascending为升序，descending为降序
 * @param param - 包含排序信息的对象
 */
export const handleSortChange = ({ order }) => {
  if (!order) {
    // 如果没有排序要求，恢复默认排序
    tableData.value = tableData.value.sort(sortSeverity)
  } else if (order === 'ascending') {
    // 升序：按严重程度升序（一般->重要->严重），时间升序
    tableData.value.sort((a, b) => {
      const severityOrder = { "一般": 1, "重要": 2, "严重": 3 }
      const severityDiff = severityOrder[a.severity] - severityOrder[b.severity]
      if (severityDiff === 0) {
        // 严重程度相同时，按时间升序排列（较早的时间在前）
        return new Date(a.occurrenceTime) - new Date(b.occurrenceTime)
      }
      return severityDiff
    })
  } else if (order === 'descending') {
    // 如果没有升序，恢复默认排序
    tableData.value = tableData.value.sort(sortSeverity)
  }
  // 重置到第一页以显示排序后的结果
  currentPage.value = 1
}

/**
 * 根据《告警级别 + 发生时间》对表格数据进行排序
 * @param a - 第一个比较对象，包含severity和occurrenceTime属性
 * @param b -- 第二个比较对象，包含severity和occurrenceTime属性
 * @returns {number}- 排序比较结果：
 *                   负数表示a应该排在b前面，
 *                   正数表示b应该排在a前面，
 *                   0表示两者顺序不变
 */
export const sortSeverity = (a, b) => {
  // 定义严重程度排序规则，数值越小表示优先级越高
  const severityOrder = { "严重": 1, "重要": 2, "一般": 3 }
  // 比较两个对象的严重程度（最严重的排在前面）
  const severityDiff = severityOrder[a.severity] - severityOrder[b.severity]
  // 如果严重程度相同，则按发生时间排序（时间最新的排在前面）
  if (severityDiff === 0) {
    // 将时间字符串转换为Date对象进行比较，b减去a实现降序排列（最新在前）
    return new Date(b.occurrenceTime) - new Date(a.occurrenceTime)
  }
  // 当严重程度不同，返回严重程度的比较结果
  return severityDiff
}


/**
 * 语音播报告警描述
 * @param {string} text - 要播报的文本内容
 */
export const speakText = async (text) => {
  // 检查浏览器是否支持语音合成API
  if ('speechSynthesis' in window) {
    // 未播报状态
    // 取消之前的语音合成
    window.speechSynthesis.cancel()

    // 创建语音合成实例
    const utterance = new SpeechSynthesisUtterance(text)

    // 设置语音参数
    utterance.rate = 1.0  // 语速
    utterance.pitch = 1.0 // 音调
    utterance.volume = 1  // 音量

    // 添加语音开始事件监听
    utterance.onstart = () => {
      voiceStatus.value = true
    }
    // 添加语音结束事件监听
    utterance.onend = () => {
      voiceStatus.value = false
    }
    // 添加语音错误事件监听
    utterance.onerror = () => {
      voiceStatus.value = false
    }
    // 开始语音合成
    window.speechSynthesis.speak(utterance)
    // 未播报状态
  } else {
    // 如果存在消息实例，先关闭所有消息
    if (messageInstance.value) {
      // 关闭所有显示的消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成，使用Promise确保时序
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    // 显示错误提示消息
    messageInstance.value = ElMessage.warning({
      message: '您的浏览器不支持语音合成功能',    // 错误信息内容
      duration: 1000,        // 显示持续时间(毫秒)
      offset: window.innerHeight / 2 - 20,   // 垂直偏移量，使消息垂直居中
      onClose: () => {       // 消息关闭时的回调
        messageInstance.value = null    // 清空消息实例引用
      }
    })
  }
}

/**
 * 表格中《操作》中播报按钮回调函数
 * @param row - 要播报的行数据对象
 */
export const handleSpeak = (row) => {
  // 播报告警描述
  const description = "你好" + row.alarm_details || '无告警描述'
  speakText(description)
}
/**
 * 暂停语音播报
 */
export const pauseSpeech = () => {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.pause()
  }
}

/**
 * 恢复语音播报
 */
export const resumeSpeech = () => {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.resume()
  }
}

/**
 * 停止语音播报
 */
export const stopSpeech = () => {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel()  // 使用cancel()完全停止所有语音
  }
}
