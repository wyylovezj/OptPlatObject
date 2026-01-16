<script setup>
import AlarmItmPage from '@/components/AlarmItmPage.vue'
import AlarmSearchPage from '@/components/AlarmSearchPage.vue'
</script>

<template>
  <div class="alarm-page" style=">
">
    <AlarmSearchPage></AlarmSearchPage>
    <AlarmItmPage></AlarmItmPage>
  </div>

</template>

<style scoped>
.alarm-page {
  display: flex;
  flex-direction: column;
  border: #DCDFE6 solid 1px;
  padding: 15px 30px;
  height: 100%;
  box-sizing: border-box;
  background-color: #FFFFFF;
  border-radius: 10px;
}

</style>
