<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：应用根组件
 * @date： 2026-01-28 09:30:17
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:30:17
 */
import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import { computed,onMounted, onBeforeUnmount, watch } from 'vue'
import { useRoute } from 'vue-router'
import { messageInstance, refresh, stopSpeaking } from '@/utils/publicData.js'
import { ElMessageBox, ElMessage } from 'element-plus'


// 获取store实例
const authStore = useAuthStore()
const alarmStore = useSpeakStore()
// 获取当前路由实例
const route = useRoute()

const isAuthenticated = computed(() => authStore.isAuthenticated)
// 全局定时器
let searchTimer = null
let unwatch = null
// 在 onMounted 中添加 watch, 每60s 刷新一次数据并播报告警信息
onMounted(() => {
  unwatch = watch(
    () => authStore.isAuthenticated,
    (newValue) => {
      if (newValue) {
        // 检查是否是登录重定向，如果不是才启动定时器
        const wasLoginRedirect = sessionStorage.getItem('isLoginRedirect')
        // 检测页面是否是通过刷新加载的
        const navigationEntries = performance.getEntriesByType('navigation')
        const isRefresh = navigationEntries.length > 0 && navigationEntries[0].type === 'reload'
        if (isRefresh && !wasLoginRedirect) {
          ElMessageBox.confirm(
            '页面刷新会终止语音播报，请点击开启或关闭语音播报！',
            '提示',
            {
              showClose: false,
              confirmButtonText: '开启',
              cancelButtonText: '关闭',
              type: 'success',
              customClass: 'custom-message-box'
            }
          )
            .then(async () => {
              stopSpeaking.value = false
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
            })
            .catch(() => {
              stopSpeaking.value = true
            })
        }
        // 这是登录重定向，清除标记但不启动定时器
        sessionStorage.removeItem('isLoginRedirect')
        // 创建一个函数来重启定时器
        const restartTimer = () => {
          if (searchTimer) {
            clearInterval(searchTimer);
          }
          searchTimer = setInterval(() => {
            refresh()
          }, 60000) // 60秒刷新一次数据
        }
        // 首次启动定时器
        restartTimer()
        // 监听手动刷新事件，重置定时器
        // 需要在全局范围内暴露重置函数
        window.resetRefreshTimer = restartTimer
      } else if (searchTimer) {
        clearInterval(searchTimer)
        searchTimer = null
        window.resetRefreshTimer = null
      }
    },
    { immediate: true } //
  )
  // 初始化已播报队列
  alarmStore.initAlreadySpeakQueue()
  // 添加页面卸载事件监听
  window.addEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
})


onBeforeUnmount(() => {
  // 移除页面卸载事件监听
  window.removeEventListener('beforeunload', alarmStore.persistAlreadySpeakQueue())
  // 关闭页面时清除标记
  if (sessionStorage.getItem('isLoginRedirect')) {
    sessionStorage.removeItem('isLoginRedirect')
  }
  // 在组件卸载时取消监听
  if (unwatch) {
    unwatch()
  }
  // 清除全局定时器
  if (searchTimer) {
    clearInterval(searchTimer)
  }
  alarmStore.persistAlreadySpeakQueue()
})

</script>

<template>
  <div id="app">
    <router-view v-if="route.name === 'NotFound'" name="NotFound"></router-view>
    <router-view v-else-if="!isAuthenticated || route.name === 'LoginPage'" name="LoginPage"></router-view>
    <IndexPage v-else></IndexPage>
  </div>
</template>

<style>
/* 因element组件高度默认是内容高度，在此设置高度为页面高度 */
html, body {
  height: 100%;
  margin: 0;
  padding: 0;
  font-family: 'Helvetica Neue', Arial, sans-serif;
  box-sizing: border-box;
}
#app {
  height: 100%;
}
/* ElMessage字体大小样式 */
.el-message {
  font-size: 16px !important;
}

.el-message__content {
  font-size: 16px !important;
}
.custom-message-box {
  margin-top: -15% !important;
}

</style>
