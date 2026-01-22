<script setup>

import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import { computed,onMounted, onBeforeUnmount, watch } from 'vue'
import { useRoute } from 'vue-router'
import { refresh, stopSpeaking } from '@/utils/publicData.js'
import { ElMessageBox } from 'element-plus'



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
        // 检测页面是否是通过刷新加载的
        const navigationEntries = performance.getEntriesByType('navigation')
        const isRefresh = navigationEntries.length > 0 && navigationEntries[0].type === 'reload'
        if (isRefresh) {
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
            .then(() => {
              stopSpeaking.value = false
            })
            .catch(() => {
              stopSpeaking.value = true
            })
        }
        searchTimer = setInterval(() => {
          refresh()
        }, 50000) // 60秒刷新一次数据
      } else if (searchTimer) {
          clearInterval(searchTimer)
          searchTimer = null
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
  <router-view v-if="route.name === 'NotFound'" name="NotFound"></router-view>
  <router-view v-else-if="!isAuthenticated || route.name === 'LoginPage'" name="LoginPage"></router-view>
  <IndexPage v-else></IndexPage>
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
