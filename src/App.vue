<script setup>
import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/auth.js'
import { computed } from 'vue'
import { useRoute } from 'vue-router'
const route = useRoute()
const authStore = useAuthStore()
const isAuthenticated = computed(() => authStore.isAuthenticated)
// // 清除登录信息
// const clearSensitiveData = () => {
//   authStore.logout()
// };
//
// // 设置页面关闭监听器
// const setupBeforeUnloadListener = () => {
//   window.addEventListener('beforeunload', clearSensitiveData);
// };
//
// // 移除监听器
// const removeBeforeUnloadListener = () => {
//   window.removeEventListener('beforeunload', clearSensitiveData);
// };
//
// // 组件挂载时设置监听
// onMounted(() => {
//   setupBeforeUnloadListener();
// });
//
// // 组件卸载时移除监听
// onBeforeUnmount(() => {
//   removeBeforeUnloadListener();
// });

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
</style>
