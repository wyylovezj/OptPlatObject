<script setup>
import { searchQuery } from '@/utils/publicData.js'
import { ref, computed } from 'vue'
import { WorkOrderDataModel, selectedNode, containsLabel, UnlockAccountDataModel } from '@/utils/publicDataTools.js'
import { exportOrderFile, unlockAccountInterface } from '@/api/interface.js'
import { CircleCheckFilled } from '@element-plus/icons-vue'

// 定义一个计算属性，判断是否有 el-card 需要显示
const hasVisibleCards = computed(() => {
  return containsLabel('工单导出') || containsLabel('账号解锁') // 可以继续添加其他卡片的判断条件
})
// 模态框可视状态
const dialogVisible = ref({
  OrderExporter: false, // 工单导出模态框可视状态
  unlockAccount: false, // 域账号解锁模态框可视状态
})
// 导出工单表单实例
const exporterForm = ref(null)
const responseData = ref({
  unlock: '',
})
// 解锁账号表单实例
const unlockAccountForm = ref(null)
// 导出按钮禁用
const exportDisabled = ref({
  exporterOrder: false, // 工单导出按钮禁用状态
  unlockAccount: false, // 域账号解锁按钮禁用状态
})
// 进度条可视状态
const percentageVisible = ref({
  exporterOrder: true, // 工单导出进度条可视状态
})
// 进度条百分比
const percentage = ref({
  exporterOrder: 0,
})
// 限制开始时间 不能早于结束时间30天
const disabledStartDate = (time) => {
  if (WorkOrderDataModel.value.endTime) {
    const endTime = new Date(WorkOrderDataModel.value.endTime)
    const thirtyOneDaysBefore = new Date(endTime)
    thirtyOneDaysBefore.setDate(thirtyOneDaysBefore.getDate() - 30) // 结束时间往前推31天
    return time.getTime() < thirtyOneDaysBefore.getTime() || time.getTime() > endTime.getTime()
  }
  return false // 如果没有设置结束时间，则不禁用任何日期
}
// 限制结束时间 不能晚于开始时间30天
const disabledEndDate = (time) => {
  if (WorkOrderDataModel.value.startTime) {
    const startTime = new Date(WorkOrderDataModel.value.startTime)
    const thirtyOneDaysAfter = new Date(startTime)
    thirtyOneDaysAfter.setDate(thirtyOneDaysAfter.getDate() + 30) // 结束时间往前推31天
    return time.getTime() > thirtyOneDaysAfter.getTime() || time.getTime() < startTime.getTime()
  }
  return false // 如果没有设置结束时间，则不禁用任何日期
}
// 导出工单模态框中确定按钮点击事件
const exportWorkOrder = async () => {
  if (!exporterForm.value) return
  await exporterForm.value.validate(async (valid, fields) => {
    if (valid) {
      exportDisabled.value.exporterOrder = true
      dialogVisible.value.OrderExporter = false
      percentageVisible.value.exporterOrder = true
      try {
        const status = await exportOrderFile(WorkOrderDataModel.value, percentage.value)
        if (status) {
          responseData.value.unlock = status.message
          console.log(responseData.value.unlock)
          exportDisabled.value.exporterOrder = false
          // percentageVisible.value.exporterOrder = false
        }
      }
      catch(error) {
        console.log(error)
      }

    } else {
      console.log('error submit!', fields)
    }
  })
}
//   导出工单模态框中表单校验规则
const exporterOrderRules = ref({
  OrderType: [
    {
      required: true,
      message: '请选择工单类型',
      trigger: 'change',
    },
  ],
  startTime: [
    {
      type: 'date',
      required: true,
      message: '请选择开始时间',
      trigger: 'change',
    },
  ],
})

// 导出工单模态框中下拉框数据模型
const OrderTypeModel = [
  {
    value: '1',
    label: '事件工单',
  },
  {
    value: '2',
    label: '变更工单',
  },
  {
    value: '3',
    label: '发布工单',
  },
  {
    value: '4',
    label: '问题工单',
  },
  {
    value: '5',
    label: '变更工单（含资源、网络）',
  },
]
// 账号解锁模态框中表单校验规则
const unlockAccountRules = ref({
  type: [
    {
      required: true,
      message: '请选择解锁类型',
      trigger: 'change',
    },
  ],
  username: [
    {
      required: true,
      message: '请输入需要解锁的账号',
      trigger: 'change',
    },
  ],
})
// 导出工单模态框中确定按钮点击事件
const unlockAccount = async () => {
  if (!unlockAccountForm.value) return
  await unlockAccountForm.value.validate(async (valid, fields) => {
    if (valid) {
      exportDisabled.value.unlockAccount = true
      dialogVisible.value.unlockAccount = false
      try {
        const status = await unlockAccountInterface(UnlockAccountDataModel.value)
        console.log(status)
        if (status) {
          exportDisabled.value.unlockAccount = false
          // percentageVisible.value.exporterOrder = false
        }
      } catch (error) {
        console.log(error.message)
      }
    } else {
      console.log('error submit!', fields)
    }
  })
}
const unlockTypeModel = [
  {
    value: '1',
    label: '域账号解锁',
  },
  {
    value: '2',
    label: '邮箱账号解锁',
  },
]
// 主机名输入处理函数
const handleAccountInput = (value) => {
  // 只允许输入英文字母和数字
  UnlockAccountDataModel.value.username = value.replace(/[^a-zA-Z0-9]/g, '')
}
</script>

<template>
  <div class="toolsItem">
    <el-card v-if="containsLabel('工单导出')" shadow="hover" body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;">
      <!-- 卡片主体内容 -->
      <div class="card-content">
        <!-- 上部分：2:1 比例 -->
        <div class="top-section">
          <!-- 左侧：1:2 比例 -->
          <div class="left-part">
            <div class="circle-image">
              <!-- 圆形框内显示 SVG 图片 -->
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-xiazaiwenjian_24"></use>
              </svg>
            </div>
          </div>
          <!-- 右侧：1:2 比例 -->
          <div class="right-part">
            <p>工单导出</p>
          </div>
        </div>
        <!-- 下部分：按钮 -->
        <div class="bottom-section">
          <div v-if="percentageVisible.exporterOrder" class="demo-progress" style="flex: 3; width: 100%">
            <el-progress
              :text-inside="true"
              :stroke-width="20"
              :percentage="percentage.exporterOrder"
              striped
              status="success"
              :striped-flow="percentage.exporterOrder > 0 && percentage.exporterOrder < 100"
            >
              <span v-if="percentage.exporterOrder === 0" style="color: #6cbc45; font-weight: bold">导出功能已就绪！</span>
              <span v-if="percentage.exporterOrder === 100">导出已完成！</span>
            </el-progress>
          </div>
          <div style="flex: 1; display: flex; justify-content: flex-end">
            <el-button
              type="primary"
              :disabled="exportDisabled.exporterOrder"
              @click="
                dialogVisible.OrderExporter = true;
                percentage.exporterOrder = 0;
              "
            >
              导出
            </el-button>
          </div>
        </div>
      </div>
    </el-card>
    <el-card v-if="containsLabel('账号解锁')" shadow="hover" body-style="background-color: #F5F7FA;height: 100%;box-sizing: border-box;">
      <!-- 卡片主体内容 -->
      <div class="card-content">
        <!-- 上部分：2:1 比例 -->
        <div class="top-section">
          <!-- 左侧：1:2 比例 -->
          <div class="left-part">
            <div class="circle-image">
              <!-- 圆形框内显示 SVG 图片 -->
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-zhanghaojiesuo"></use>
              </svg>
            </div>
          </div>
          <!-- 右侧：1:2 比例 -->
          <div class="right-part">
            <p>账号解锁</p>
          </div>
        </div>
        <!-- 下部分：按钮 -->
        <div class="bottom-section">
          <div style="flex: 3; width: 100%; font-size: 15px; color: #88cf64; text-align: center; margin-top: 5px">
            <span style="vertical-align: middle">{{ responseData.unlock }}</span>
            <el-icon :size="17" style="vertical-align: middle"><CircleCheckFilled /></el-icon>
          </div>
          <div style="flex: 1; display: flex; justify-content: flex-end">
            <el-button type="primary" :disabled="exportDisabled.unlockAccount" @click="dialogVisible.unlockAccount = true"> 解锁 </el-button>
          </div>
        </div>
      </div>
    </el-card>
    <el-empty v-if="!hasVisibleCards" description="无匹配数据" style="width: 100%; height: 100%" />

    <el-dialog
      v-model="dialogVisible.OrderExporter"
      top="10%"
      title="工单导出"
      width="20%"
      center
      :show-close="false"
      @close="
        () => {
          WorkOrderDataModel.OrderType = ''
          WorkOrderDataModel.startTime = ''
          WorkOrderDataModel.endTime = ''
          dialogVisible.OrderExporter = false
        }
      "
    >
      <el-form
        :model="WorkOrderDataModel"
        ref="exporterForm"
        label-position="right"
        label-width="auto"
        :rules="exporterOrderRules"
        style="display: flex; flex-direction: column; justify-content: center; flex-wrap: wrap; user-select: none"
      >
        <el-form-item label="工单类型" prop="OrderType">
          <el-select
            v-model="WorkOrderDataModel.OrderType"
            class="center-placeholder"
            clearable
            placeholder="请选择"
            style="width: 250px"
            @clear="WorkOrderDataModel.OrderType = ''"
          >
            <el-option v-for="item in OrderTypeModel" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="开始时间" prop="startTime">
          <el-date-picker
            v-model="WorkOrderDataModel.startTime"
            type="date"
            placeholder="开始时间"
            format="YYYY/MM/DD"
            value-format="YYYY-MM-DD"
            style="width: 250px"
            :disabled-date="disabledStartDate"
          />
        </el-form-item>
        <el-form-item label="结束时间" prop="endTime">
          <el-date-picker
            v-model="WorkOrderDataModel.endTime"
            type="date"
            style="width: 250px"
            format="YYYY/MM/DD"
            value-format="YYYY-MM-DD"
            placeholder="结束时间"
            :disabled-date="disabledEndDate"
          />
        </el-form-item>
        <el-form-item style="flex: none; margin-right: 5px">
          <div style="display: flex; justify-content: space-between; gap: 10px; flex-wrap: nowrap">
            <el-button type="primary" @click="exportWorkOrder">确认</el-button>
            <el-button
              type="primary"
              @click="
                dialogVisible.OrderExporter = false
                // 清空数据模型
              "
              >取消</el-button
            >
          </div>
        </el-form-item>
      </el-form>
    </el-dialog>
    <el-dialog
      v-model="dialogVisible.unlockAccount"
      top="10%"
      title="账号解锁"
      width="20%"
      center
      :show-close="false"
      @close="
        () => {
          UnlockAccountDataModel.type = ''
          UnlockAccountDataModel.username = ''
          dialogVisible.unlockAccount = false
        }
      "
    >
      <el-form
        :model="UnlockAccountDataModel"
        ref="unlockAccountForm"
        label-position="right"
        label-width="auto"
        :rules="unlockAccountRules"
        style="display: flex; flex-direction: column; justify-content: center; flex-wrap: wrap; user-select: none"
      >
        <el-form-item label="解锁类型" prop="type">
          <el-select
            v-model="UnlockAccountDataModel.type"
            class="center-placeholder"
            clearable
            placeholder="请选择"
            style="width: 250px"
            @clear="UnlockAccountDataModel.type = ''"
          >
            <el-option v-for="item in unlockTypeModel" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="解锁账号" prop="username">
          <el-input
            v-model="UnlockAccountDataModel.username"
            style="width: 250px"
            placeholder="请输入账号"
            maxlength="15"
            type="text"
            @input="handleAccountInput"
            clearable
          />
        </el-form-item>
        <el-form-item style="flex: none; margin-right: 5px">
          <div style="display: flex; justify-content: space-between; gap: 10px; flex-wrap: nowrap">
            <el-button type="primary" @click="unlockAccount">确认</el-button>
            <el-button
              type="primary"
              @click="
                dialogVisible.unlockAccount = false
                // 清空数据模型
              "
              >取消</el-button
            >
          </div>
        </el-form-item>
      </el-form>
    </el-dialog>
  </div>
</template>

<style scoped>
.toolsItem {
  flex: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: flex-start;
  user-select: none;
  border: #dcdfe6 solid 1px;
  padding: 15px 30px;
  background-color: #ffffff;
  border-radius: 10px;
}
.el-card {
  flex: 0 0 25%; /* 宽度为父容器的 1/5 */
  height: 25%; /* 高度为父容器的 1/4 */
  border: 1.5px solid #dcdfe6;
}

/* 整体卡片内容容器 */
.card-content {
  display: flex;
  flex-direction: column;
  height: 100%;
}

/* 上部分：占据 2/3 高度 */
.top-section {
  flex: 2;
  display: flex;
  gap: 10px; /* 左右间距 */
}

/* 左侧部分：占据 1/3 宽度 */
.left-part {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
}

/* 圆形框样式 */
.circle-image {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid #ccc;
  display: flex;
  justify-content: center;
  align-items: center;
}

.circle-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 右侧部分：占据 2/3 宽度 */
.right-part {
  flex: 2;
  display: flex;
  align-items: center;
}

.right-part p {
  margin: 0;
  font-size: 16px;
  color: #333;
  align-items: center;
}

/* 下部分：占据 1/3 高度 */
.bottom-section {
  flex: 1;
  display: flex;
  justify-content: center;
}
.icon {
  width: 35px;
  height: 35px;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
.demo-progress .el-progress--line {
  margin-top: 5px;
  max-width: 90%;
}
.el-progress__text {
  min-width: auto;
}
</style>
