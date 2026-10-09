<script setup>


import ToolDirectory from '@/components/toolsManage/ToolDirectory.vue'
import ToolItem from '@/components/toolsManage/ToolItem.vue'
// import ToolsHeader from '@/components/toolsManage/ToolsHeader.vue'
</script>

<template>
  <div class="tools-page">
    <ToolDirectory></ToolDirectory>
    <ToolItem></ToolItem>
<!--    <div class="toolsItemPage">-->
<!--      <ToolsHeader></ToolsHeader>-->
<!--      <ToolItem></ToolItem>-->
<!--    </div>-->
  </div>
</template>

<style scoped>
.tools-page {
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  box-sizing: border-box;
  height: 100%;
}
.toolsItemPage {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 100%;
  box-sizing: border-box;
}
</style>
