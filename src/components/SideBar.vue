<script setup>
import '@/iconfonts/iconfont.js'
import { useRouter } from 'vue-router'

const handleOpen = (key, keyPath) => {
  console.log(key, keyPath)
}
const handleClose = (key, keyPath) => {
  console.log(key, keyPath)
}
const router = useRouter()
function routeTo() {
  router.push('/alarmManagement/alarmItem')
}

</script>

<template>
  <el-row class="tac">
    <el-col>
      <el-menu
        active-text-color="#ffd04b"
        background-color="linear-gradient(180deg, #1e3c72 0%, #2a5298 100%)"
        class="el-menu-vertical"
        default-active="2"
        text-color="rgba(0, 0, 0, 0.9)"
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
          <el-menu-item @click="routeTo" index="1-1">告警</el-menu-item>
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
          <el-menu-item @click="routeTo" index="2-1">事件</el-menu-item>
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
          <el-menu-item @click="routeTo" index="3-1">参数配置</el-menu-item>
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
.el-menu-item:hover {
  background-color: rgba(255, 255, 255, 0.1) !important;
}
.el-sub-menu__title:hover {
  background-color: rgba(255, 255, 255, 0.1) !important;
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
