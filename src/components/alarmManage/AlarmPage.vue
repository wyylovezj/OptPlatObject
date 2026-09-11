<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 告警界面组件
 * @date： 2025-12-08 09:45:07
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-
 */
import AlarmItmPage from '@/components/alarmManage/AlarmItmPage.vue'
import AlarmSearchPage from '@/components/alarmManage/AlarmSearchPage.vue'
</script>

<template>
  <div class="alarm-page">
    <AlarmSearchPage></AlarmSearchPage>
    <AlarmItmPage></AlarmItmPage>
  </div>
</template>

<style scoped>
.alarm-page {
  display: flex;
  flex-direction: column;
  padding: 5px;
  height: 100%;
  box-sizing: border-box;
  background-color: transparent;
  border-radius: 10px;
}

</style>
