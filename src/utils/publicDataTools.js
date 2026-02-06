import { ref } from 'vue'

export const user = ref(sessionStorage.getItem('user') || null)
export const WorkOrder = ref(
  {
    OrderType: '',  // 工单类型
    startTime: '', // 开始时间
    endTime: '', // 结束时间
    username: user.value, // 操作用户
  }
)
export const exportIp = ref(window.APP_CONFIG?.EXPORTER_IP || 'default-port');
