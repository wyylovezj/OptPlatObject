import { searchData } from '@/api/interface.js'
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'


// 表格组件实例的引用
export const tableRef = ref(null)

// 获取当前登录用户名
export const user = ref(null)

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

// 数据字典
export const dataDictionary = ref({
  category: [],      // 告警分类
  system_name: [],      // 业务系统
  userGroup: [],      // 用户组
  user: [],          // 用户
})
// 触发工单的数据模型
export const orderModel = ref({
  system_name: '',  // 业务系统
  eventId: '', // 事件ID
  createUser: '', // 创建人
  userGroup: '', // 用户组
  username: '', // 用户
  orderHandleOpinion: '', // 处理意见
})
// 表单查询数据模型
export const searchQuery = ref({
  category: [],      // 告警分类
  severity: '',      // 告警级别
  ip: '',            // IP地址
  object: '',        // 主机名
  system_name: [],   // 业务系统
  occurrenceTime: [], // 发生时间
  state:'',         // 告警状态
  source: ''         // 告警来源
})

// 下拉列表筛选功能开启标志
export const isFilter = ref(false)

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

// // 定时器
// const timer = ref(null)

// 控制开启和关闭告警播报
export const stopSpeaking = ref(false)

// 语音播报状态：用于喇叭状态和语音播报顺序控制
export const isSpeaking = ref(false)


// 修改 src/utils/publicData.js 中的 serverIp 定义
export const serverIp = ref(window.APP_CONFIG?.SERVER_IP || 'default-ip');

/**
 * 处理语音播报队列
 */
export const processSpeechQueue = async () => {
  // 获取告警数据的Pinia store
  const alarmStore = useSpeakStore()
  if (isSpeaking.value || alarmStore.speechQueue.length === 0) {
    return // 如果正在播报或队列为空，直接返回
  }
  // 判断每个在语音播报队列中的数据，是否已播报，若未播报，则播报的同时添加到已播报队列中
  alarmStore.addAlreadySpeakQueue()
  // 移除已播报列表中已处理的数据
  alarmStore.removeAlreadySpeakQueue()
  if (alarmStore.count > 0 && !stopSpeaking.value) {
    const text = `产生${alarmStore.count}条严重告警，当前未处理严重告警共${alarmStore.speechQueue.length}条，请及时处理！`
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel() // 清除之前的播报
      const utterance = new SpeechSynthesisUtterance(text)
      utterance.rate = 1.0
      utterance.pitch = 1.0
      utterance.volume = 1

      // 监听语音结束事件
      utterance.onend = () => {
        // 播报结束
        isSpeaking.value = false
      }

      // 监听语音错误事件
      utterance.onerror = () => {
        isSpeaking.value = false
      }

      // 监听语音开始事件
      utterance.onstart = () => {
        // 播报中
        isSpeaking.value = true
        console.log('开始播报')
      }
      // 开始播报
      window.speechSynthesis.speak(utterance)
      // 重置播报计数,表示当前新增告警已播报完毕
      alarmStore.count = 0
      console.log(alarmStore.count)
    } else {
      isSpeaking.value = false
      // 处理不支持语音合成的情况
      if (messageInstance.value) {
        ElMessage.closeAll()
        await new Promise(resolve => setTimeout(resolve, 0))
      }
      messageInstance.value = ElMessage.warning({
        message: '您的浏览器不支持语音合成功能',
        duration: 1000,
        offset: window.innerHeight / 2 - 20,
        onClose: () => {
          messageInstance.value = null
        }
      })
    }
  }
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
export const stopSpeak = () => {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel()  // 使用cancel()完全停止所有语音
  }
  // 重置播报状态
  isSpeaking.value = false
}

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

// 搜索按钮、刷新按钮查询数据,增加了节流控制
export const refresh = throttle(async () => {
  // 立刻停止上次告警
  stopSpeak()
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
    // 手动刷新完成后重置定时器
    if (window.resetRefreshTimer) {
      window.resetRefreshTimer()
    }
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
  const severityOrder = { "严重": 1, "重要": 2, "一般": 3, "普通": 4 }
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
 * 生成UUID
 * @returns {string} - 生成的UUID字符串
 */
export const generateUUIDModern = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  } else {
    // 降级处理
    return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
      (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
    );
  }
}
