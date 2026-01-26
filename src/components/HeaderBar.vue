<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowRight } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '@/stores/authInfoStore.js'
import {
  messageInstance,
  stopSpeak,
  isSpeaking,
  stopSpeaking,
  user
} from '@/utils/publicData.js'


// 获取store实例
const authStore = useAuthStore()

// 控制喇叭提示框的隐藏与显示
const visible = ref(false)
// 控制告警图标提示框的隐藏与显示
const alarmVisible = ref(false)
const content = ref('')
// 顶部个人信息菜单后面的上下箭头翻转标志
const direction = ref(false)
// 面包屑过滤
const route = useRoute()
const router = useRouter()
const breadcrumbList = computed(() => {
  // 过滤掉没有breadcrumb的路由记录
  return route.matched.filter(item => item.meta && item.meta.breadcrumb)
})
// 侦听开启/关闭语音播报状态的更新
watch( stopSpeaking, async (newVal) => {
  if (newVal === false) {
    content.value = '点击关闭语音播报'
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.success({
      message: '已开启语音播报',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  } else {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel() // 清除之前的播报
    }
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    content.value = '点击开启语音播报'
    messageInstance.value = ElMessage.success({
      message: '已关闭语音播报',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  }
},
  { flush: 'sync' } // 立即触发回调函数
)

// 控制个人信息菜单的展开与收起
const changeDirection = (isVisible) => {
  direction.value = isVisible
}
const logout = async () =>{
  authStore.logoutInfoClear()
  router.push('/login')
  // 如果已有提示框在显示，先关闭它
  if (messageInstance.value) {
    // 关闭所有消息
    ElMessage.closeAll()
    // 等待消息关闭动画完成
    await new Promise(resolve => setTimeout(resolve, 0));
  }
  messageInstance.value = ElMessage.success({
    message: '退出登录',
    duration: 1000,
    onClose: () => {
      messageInstance.value = null
    }
  })
}
onMounted(() => {
  if (sessionStorage.getItem('user')) {
    user.value = sessionStorage.getItem('user')
  }
})
</script>

<template>
  <div class="bread-crumb">
    <!-- 面包屑组件开始 -->
    <el-breadcrumb :separator-icon="ArrowRight" ref="breadCrumb">
      <el-breadcrumb-item
        v-for="(item, index) in breadcrumbList"
        :key="index"
        :to="item.path"
      >
        {{ item.meta.breadcrumb }}
      </el-breadcrumb-item>
    </el-breadcrumb>
    <!-- 面包屑组件结束 -->
  </div>
  <div class="user">
    <!--  告警开关控制图标  -->
    <el-tooltip :visible="alarmVisible"
                :content="content"
    >
      <el-icon class="speak" @click="stopSpeaking = !stopSpeaking" @mouseenter="alarmVisible = true" @mouseleave="alarmVisible = false">
        <svg class="icon" aria-hidden="true" style="pointer-events: none">
          <use v-show="!stopSpeaking" xlink:href="#icon-lingdang_mian"></use>
          <use v-show="stopSpeaking" xlink:href="#icon-lingdang-jingyin_mian"></use>
        </svg>
      </el-icon>
    </el-tooltip>
    <!--  告警喇叭图标  -->
    <el-tooltip :visible="visible"
      content="停止语音播报"
    >
      <el-icon class="speak" @click="stopSpeak" @mouseenter="visible = true" @mouseleave="visible = false">
        <svg class="icon" aria-hidden="true" style="pointer-events: none">
          <use v-show="!isSpeaking" xlink:href="#icon-bobao-no"></use>
          <use v-show="isSpeaking" xlink:href="#icon-bobao"></use>
        </svg>
      </el-icon>
    </el-tooltip>
    <!-- 用户图标 -->
    <el-icon style="font-size: 1.2em">
      <svg class="icon" aria-hidden="true">
        <use xlink:href="#icon-yonghuguanli"></use>
      </svg>
    </el-icon>
    <!-- 顶部个人信息下拉框组件开始 -->
    <el-dropdown  @visible-change="changeDirection" trigger="click">
      <span class="el-dropdown-link">
        <span class="user-name" style="font-size: 1em">
          {{user}}
        </span>
        <el-icon  style="font-size: 0.9em; color: rgba(255, 255, 255, 1);">
          <svg class="icon" aria-hidden="true">
            <use v-show="direction" xlink:href="#icon-xiajiantou"></use>
            <use v-show="!direction" xlink:href="#icon-shangjiantou"></use>
          </svg>
        </el-icon>
      </span>
      <template #dropdown>
        <el-dropdown-menu>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-gerenxinxi"></use>
              </svg>
            </el-icon>
            修改个人信息
          </el-dropdown-item>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-xiugaimima"></use>
              </svg>
            </el-icon>
            修改密码
          </el-dropdown-item>
          <el-dropdown-item @click="logout">
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(0, 0, 0)">
                <use xlink:href="#icon-tcdl"></use>
              </svg>
            </el-icon>
            退出登录
          </el-dropdown-item>
        </el-dropdown-menu>
      </template>
    </el-dropdown>
    <!-- 顶部个人信息下拉框组件结束 -->
  </div>
</template>

<style scoped>
* {
  user-select: none;
}
.bread-crumb {
  flex: 1;
  justify-content: flex-start;
}
.user {
  flex: 1;
}
.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
.example-showcase .el-dropdown-link {
  cursor: pointer;
  color: var(--el-color-primary);
  display: flex;
  align-items: center;
}
.user {
  flex: 1;
  display: flex;
  justify-content: flex-end;
  align-items: center;
  color: rgba(207, 211, 217, 1);
}
.speak {
  font-size: 1.2em;
  cursor: pointer;
  margin-right: 20px;
}
.user-name {
  font-size: 15px;
  margin-left: 8px;
  margin-right: 8px;
  color: rgba(207, 211, 217, 1);
}
.user-name:hover {
  color: rgba(255, 255, 255, 1);
}
/* 面包屑组件样式 */
/* 可点击的上级面包屑 */
.el-breadcrumb :deep(.el-breadcrumb__inner)  {
  color: rgba(207, 211, 217, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
.el-breadcrumb__item:hover :deep(.el-breadcrumb__inner)  {
  color: rgba(255, 255, 255, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
/* 不可点击的当前级面包屑 */
.el-breadcrumb__item:last-child :deep(.el-breadcrumb__inner) {
  color: rgba(255, 255, 255, 1) !important;
  font-size: 15px;
  font-weight:400 !important;
}
/* 不可点击的面包屑分级符号 */
.el-breadcrumb__item :deep(.el-breadcrumb__separator) {
  color: rgba(255, 255, 255, 0.9) !important;
  font-size: 15px;
  font-weight:400 !important;
}

</style>
