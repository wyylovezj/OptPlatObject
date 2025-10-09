<script setup>
import IndexPage from '@/components/IndexPage.vue'
</script>

<template>
  <IndexPage></IndexPage>
</template>

<style>
/* 因element组件高度默认是内容高度，在此设置高度为页面高度 */
html, body {
  height: 100%;
  margin: 0;
  padding: 0;
  font-family: 'Helvetica Neue', Arial, sans-serif;
  box-sizing: border-box;
  font-size: 14px;
}
#app {
  height: 100%;
}
</style>
