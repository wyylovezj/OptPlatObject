import { ref } from 'vue'


const userGroup = ['weiyangyang']

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
// 接口地址
export const exportIp = ref(window.APP_CONFIG?.EXPORTER_IP || 'default-port');
// 当前选中的节点
export const selectedNode = ref({
      id: 1,
      label: '工具库',
      children: [
        {
          id: 2,
          label: '系统工具',
          children: [
            {
              id: 4,
              label: '工单导出'
            },
            {
              id: 5,
              label: '域账号解锁'
            }
          ]
        },
        {
          id: 3,
          label: '网络工具'
        }
      ]
})
// 目录树点击事件
export const handleNodeClick = (data) => {
  selectedNode.value = data
  // 可以在这里触发事件，通知父组件或其他组件
  console.log('选中的节点:', data)
}
// 定义一个函数，传入一个label名称，检查selectedNode.value中的label或children的label中是否包含该名称
export const containsLabel = (labelName) => {
  if (!selectedNode.value) return false;

  // 检查当前节点的label是否包含传入的label名称
  if (selectedNode.value.label.includes(labelName)) {
    return true;
  }

  // 递归检查子节点
  const checkChildren = (children) => {
    if (!children || !Array.isArray(children)) return false;
    for (let child of children) {
      if (child.label.includes(labelName)) {
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
