<script setup>
import { Plus,Delete } from '@element-plus/icons-vue'
import { ref } from 'vue'

const toolsCarousel = ref(null)
const dialogTableVisible = ref(false)
const active = ref(0)
const stepOneDataRules = ref({
  toolName: [
    { required: true, message: '请输入工具名！', },
  ]
})
const stepOneData = ref({
  toolName: '',
  interfaceAddress: '',
  method: '',
})
const addTool = () => {
  dialogTableVisible.value = true
}
const next = () => {
  if (active.value <= 2) {
    active.value++
    toolsCarousel.value.setActiveItem(active.value)
  }
}
const before = () => {
  if (active.value > 0) {
    active.value--
    toolsCarousel.value.setActiveItem(active.value)
  }
}
const save = () => {
  if (active.value === 2) {
    active.value++
  }
}
</script>

<template>
  <div class="toolsHeader">
    <el-button size="large" round plain @click="addTool">
      <el-icon style="margin-right: 10px"><Plus /></el-icon>
      新增工具</el-button
    >
    <el-button size="large" round plain>
      <el-icon style="margin-right: 10px"><Delete /></el-icon>
      删除工具</el-button
    >
  </div>
  <!-- 新增工具模态框 -->
  <el-dialog
    destroy-on-close
    v-model="dialogTableVisible"
    title="新增工具步骤"
    center
  >
    <el-steps
      :active="active"
      finish-status="success"
      align-center>
      <el-step :title="active === 0 ? '进行中' : '已完成'" description="基本信息" />
      <el-step :title="active === 1 ? '进行中' : active >= 2 ? '已完成' : '步骤2'" description="连接信息" />
      <el-step :title="active === 2 ? '进行中' : active === 3 ? '已完成' : '步骤3'" description="请求参数" />
    </el-steps>
    <el-divider />
    <el-carousel ref="toolsCarousel" indicator-position="none" arrow="never" :autoplay="false" :loop="false">
      <el-carousel-item>
        <el-form
          :model="stepOneData"
          :rules="stepOneDataRules"
          label-width="200"
          status-icon
          label-suffix="："
        >
          <el-form-item label="工具名" prop="toolName">
            <el-input v-model="stepOneData.name" style="width: 450px"/>
          </el-form-item>
          <el-form-item label="工具分类" prop="toolClass">
            <el-input v-model="stepOneData.interfaceAddress" style="width: 450px"/>
          </el-form-item>
        </el-form>
      </el-carousel-item>
      <el-carousel-item>
        <el-form
          :model="stepOneData"
          :rules="stepOneDataRules"
          label-width="200"
          status-icon
          label-suffix="："
        >
          <el-form-item label="接口地址" prop="interfaceAddress" @click="rename">
            <el-input v-model="stepOneData.name" style="width: 450px"/>
          </el-form-item>
          <el-form-item label="请求方式" prop="method" style="width: 450px">
            <el-select v-model="stepOneData.method" clearable>
              <el-option label="GET" value="GET" />
              <el-option label="POST" value="POST" />
            </el-select>
          </el-form-item>
        </el-form>
      </el-carousel-item>
      <el-carousel-item>
        <el-form
          :model="stepOneData"
          :rules="stepOneDataRules"
          label-width="200"
          status-icon
          label-suffix="："
        >
          <el-form-item label="请求头" prop="toolName">
            <el-input v-model="stepOneData.name" style="width: 450px"/>
          </el-form-item>
        </el-form>
      </el-carousel-item>
    </el-carousel>
    <el-divider />
    <div>
      <el-button style="margin-top: 12px" @click="before" :disabled="active === 0 || active > 2">上一步</el-button>
      <el-button style="margin-top: 12px" @click="next" :disabled="active >=2">下一步</el-button>
      <el-button style="margin-top: 12px" @click="save" :disabled="active < 2">完成</el-button>
    </div>

  </el-dialog>
</template>

<style scoped>
.toolsHeader {
  display: flex;
  user-select: none;
  padding-bottom: 10px;
  border-radius: 10px;
  justify-content: flex-end;
}
</style>
