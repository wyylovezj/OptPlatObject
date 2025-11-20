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
  padding: 10px;
  height:calc(100% - 22px);
  box-sizing: border-box;
}

</style>
