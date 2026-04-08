import { usePermissionStore } from '@/stores/permissionStore.js'
import { ref, computed } from 'vue'


const userGroup = ['weiyangyang']


// 卡片数组，新增的卡片放在这里
export const cards = ["工单导出", "账号解锁", "脚本下发","堡垒机账号解锁"]
// 目录树模式，新增的目录放在这里
export const toolSTree = [
  {
    id: 1,
    label: '工具库',
    children: [
      {
        id: 2,
        label: '系统工具',
        children: [
          {
            id: 21,
            label: '工单导出'
          },
          {
            id: 22,
            label: '账号解锁'
          },
          {
            id: 23,
            label: '堡垒机账号解锁'
          }
        ]
      },
      {
        id: 3,
        label: '网络工具',
        children: [
          {
            id: 31,
            label: '脚本下发'
          },
        ]
      },
    ],
  },
]
export const isAdmin = (user) => {
  console.log(user)
  return userGroup.includes(user);
}
// 导出工单请求的数据模型
export const WorkOrderDataModel = ref(
  {
    OrderType: '',  // 工单类型
    startTime: '', // 开始时间
    endTime: '', // 结束时间
    username:  '', // 操作用户
  }
)
// 账号解锁请求的数据模型
export const UnlockAccountDataModel = ref(
  {
    type: '', // 解锁类型
    username: '', // 用户名
  }
)
// 脚本下发请求的数据模型
export const fileUploadDataModel = ref(
  {
    bastionHostUser: '', // 堡垒机用户
    bastionHostPasswd: '', // 堡垒机用户密码
    fileList: [], // 文件列表
    netWorkDeviceIP: '', // 网络设备地址
    netWorkDeviceUser: '', // 设备用户
    netWorkDevicePasswd: '', // 设备密码
    createTaskTime: '', // 任务创建时间
    mobileToken: '', // 移动端令牌
    reset: function() {
      this.bastionHostUser = '';
      this.bastionHostPasswd = '';
      this.fileList = [];
      this.netWorkDeviceIP = '' ;
      this.netWorkDeviceUser = '';
      this.netWorkDevicePasswd = '';
      this.createTaskTime = '';
      this.mobileToken = '';
    }
  }
)

export const historyFileUploadDataModel = ref(
  {
    execUser: '',  // 执行人
    execTime: [], // 执行时间
    reset: function() {
      this.execUser = '';
      this.execTime = [];
    }
  }
)
// 接口地址
export const exportIp = ref(window.APP_CONFIG?.EXPORTER_IP || 'default-port');
// 当前选中的节点
export const selectedNode = ref(toolSTree[0])
// 统计所选中的 tree 中，最外层叶子节点的个数
export const countLeafNodes = (node) => {
  // 如果没有子节点，说明是叶子节点，返回 1
  if (!node.children || node.children.length === 0) {
    return 1
  }

  // 如果有子节点，递归统计所有子节点的叶子总数
  let count = 0
  for (const child of node.children) {
    count += countLeafNodes(child)
  }
  return count
}
// 统计最外层叶子节点个数的响应式数据
export const leafNodeCount = ref(countLeafNodes(toolSTree[0]))
// 目录树点击事件
export const handleNodeClick = (data) => {
  selectedNode.value = data
  // 可以在这里触发事件，通知父组件或其他组件
  console.log('选中的节点:', data)
  leafNodeCount.value = countLeafNodes(data)
  console.log('最外层叶子节点个数:', leafNodeCount.value)
}

// 定义一个函数，传入一个label名称，检查selectedNode.value中的label或children的label中是否包含该名称
export const containsLabel = (labelName) => {
  if (!selectedNode.value) return false;

  // 检查当前节点的label是否包含传入的label名称
  if (selectedNode.value.label === labelName) {
    return true;
  }

  // 递归检查子节点
  const checkChildren = (children) => {
    if (!children || !Array.isArray(children)) return false;
    for (let child of children) {
      if (child.label === labelName) {
        return true;
      }
      // 递归检查子节点的子节点
      if (checkChildren(child.children)) {
        return true;
      }
    }
    return false;
  };

  return checkChildren(selectedNode.value.children);
};
// 回显数据
export const echoData = ref([])
