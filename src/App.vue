<script setup>
import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/auth.js'
const authStore = useAuthStore()
</script>

<template>
  <router-view v-if="!authStore.checkAuth()" name="LoginPage"></router-view>
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
