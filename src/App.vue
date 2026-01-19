<script setup>

import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { computed,onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { refresh } from '@/utils/publicData.js'
import { ElMessageBox } from 'element-plus'



// 获取store实例
const authStore = useAuthStore()

// 获取当前路由实例
const route = useRoute()

const isAuthenticated = computed(() => authStore.isAuthenticated)
// 全局定时器
let searchTimer = null

// 在 onMounted 中添加 watch, 每60s 刷新一次数据并播报告警信息
onMounted(async () => {

  // 检测页面是否是通过刷新加载的
  const navigationEntries = performance.getEntriesByType('navigation')
  const isRefresh = navigationEntries.length > 0 && navigationEntries[0].type === 'reload'
  if (isRefresh) {
    ElMessageBox.confirm(
      '页面刷新会终止语音播报，请点击确定开启语音播报！',
      '提示',
      {
        showCancelButton: false,
        confirmButtonText: '确定',
        type: 'success',
      }
    )
  }
  const unwatch = watch(
    () => authStore.isAuthenticated,
    (newValue) => {
      if (newValue) {
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

  // 在组件卸载时取消监听
  onUnmounted(() => {
    unwatch()
    if (searchTimer) {
      clearInterval(searchTimer)
    }
  })
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
</style>
