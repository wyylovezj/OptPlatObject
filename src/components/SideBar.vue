<script setup>
import '@/iconfonts/iconfont.js'
const handleOpen = (key, keyPath) => {
  console.log(key, keyPath)
}
const handleClose = (key, keyPath) => {
  console.log(key, keyPath)
}

function createElement {

}
</script>

<template>
  <el-row class="tac">
    <el-col>
      <el-menu
        active-text-color="#ffd04b"
        background-color="rgb(121, 187, 255)"
        class="el-menu-vertical"
        default-active="2"
        text-color="#fff"
        @open="handleOpen"
        @close="handleClose"
        @collapse="false"
      >
        <el-divider></el-divider>
        <el-sub-menu index="1">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-gaojingguanli"></use>
              </svg>
            </el-icon>
            <span>告警管理</span>
          </template>
          <el-menu-item @click="createElement" index="1-1">云上告警</el-menu-item>
          <el-menu-item index="1-2">云下告警</el-menu-item>
        </el-sub-menu>
        <el-divider></el-divider>
        <el-sub-menu index="2">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true" >
                <use xlink:href="#icon-shijianguanli"></use>
              </svg>
            </el-icon>
            <span>事件管理</span>
          </template>
          <el-menu-item index="2-1">云上事件</el-menu-item>
          <el-menu-item index="2-2">云下事件</el-menu-item>
        </el-sub-menu>
        <el-divider></el-divider>
        <el-sub-menu index="3">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-xitongguanli"></use>
              </svg>
            </el-icon>
            <span>系统管理</span>
          </template>
          <el-menu-item index="3-1">云上事件</el-menu-item>
          <el-menu-item index="3-2">云下事件</el-menu-item>
        </el-sub-menu>
        <el-divider></el-divider>
      </el-menu>
    </el-col>
  </el-row>
</template>

<style scoped>
.tac {
  user-select: none;
}
.el-menu-vertical {
  border-right: none !important;
}
.el-divider {
  margin: 0;
}
.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
</style>
