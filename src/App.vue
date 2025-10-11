<script setup>
import IndexPage from '@/components/IndexPage.vue'
import { useAuthStore } from '@/stores/auth.js'
import { computed } from 'vue'
import { useRoute } from 'vue-router'
const route = useRoute()
const authStore = useAuthStore()
const isAuthenticated = computed(() => authStore.isAuthenticated)
console.log(isAuthenticated.value)
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
