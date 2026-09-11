import { ref } from 'vue'
export const RBAC_IP = ref(window.APP_CONFIG?.RBAC_IP || '127.0.0.1')
// 值班人员分类
export const dutyUserCategories = ['ECC', '信达', '外包']

// 值班人员数据模型
export const dutyUsers = ref([])

// 值班表数据模型 (按日期存储)
export const dutySchedule = ref({})

// 白班默认时间
export const dayShiftTime = ref({ start: '08:00', end: '22:00' })

// 夜班默认时间（跨天）
export const nightShiftTime = ref({ start: '22:00', end: '08:00' })

// 当前选中的日期
export const selectedDate = ref('')

// 选中的值班人员模型
export const selectedDutyModel = ref({
  date: '',
  dayShift: { ECC: '', xinda: '', waibao: '' },
  nightShift: { ECC: '', xinda: '', waibao: '' }
})

// ============ 排班相关数据模型 ============

// 排班数据模型（用于存储手动配置排班时录入的信息）
export const dutyScheduleData = ref({
  schedule_date: '',
  ecc_day_personnel_id: '',
  ecc_night_personnel_id: '',
  sys_ops_personnel_id: '',
  net_ops_personnel_id: '',
  pm_personnel_id: '',
  created_by: '',
  updated_by: ''
})

// ECC白班人员模型（用于存储ecc白班人员下拉框的选项数据）
export const eccDayPersonnel = ref([])

// ECC夜班人员模型（用于存储ecc夜班人员下拉框的选项数据）
export const eccNightPersonnel = ref([])

// 系统运维人员模型（用于存储系统运维人员下拉框的选项数据）
export const sysOpsPersonnel = ref([])

// 网络运维人员模型（用于存储网络运维人员下拉框的选项数据）
export const netOpsPersonnel = ref([])

// 甲方 PM 人员模型（用于存储甲方 PM 下拉框的选项数据）
export const pmPersonnel = ref([])

// 跑批人员模型（用于存储跑批人员下拉框的选项数据，包含 AB 角色）
export const batchPersonnel = ref([])

// 运维服务台人员模型（用于存储运维服务台人员下拉框的选项数据，包含业务组、财务组、办公组）
export const serviceDeskPersonnel = ref([])

// 重置排班相关数据模型的函数
export const resetDutyScheduleData = () => {
  dutyScheduleData.value = {
    schedule_date: '',
    ecc_day_personnel_id: '',
    ecc_night_personnel_id: '',
    sys_ops_personnel_id: '',
    net_ops_personnel_id: '',
    pm_personnel_id: '',
    created_by: '',
    updated_by: ''
  }
  eccDayPersonnel.value = []
  eccNightPersonnel.value = []
  sysOpsPersonnel.value = []
  netOpsPersonnel.value = []
  pmPersonnel.value = []
  batchPersonnel.value = []
  serviceDeskPersonnel.value = []
}
