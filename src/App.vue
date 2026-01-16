<script setup>
import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { computed,onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { refresh } from '@/utils/publicData.js'


const route = useRoute()
const authStore = useAuthStore()
const isAuthenticated = computed(() => authStore.isAuthenticated)

// 全局定时器
let searchTimer = null

// 在 onMounted 中添加 watch, 每60s 刷新一次数据并播报告警信息
onMounted(() => {
  const unwatch = watch(
    () => authStore.isAuthenticated,
    (newValue) => {
      if (newValue) {
        console.log('刷新数据')
        searchTimer = setInterval(() => {
          refresh()
        }, 5000) // 60秒刷新一次数据
      } else {
        if (searchTimer) {
          clearInterval(searchTimer)
          searchTimer = null
        }
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
