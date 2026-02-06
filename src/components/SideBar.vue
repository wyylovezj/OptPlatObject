<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：侧边栏组件
 * @date： 2026-01-28 09:29:43
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:29:43
 */
import '@/iconfonts/iconfont.js'
import { useRouter } from 'vue-router'
import { isCollapse } from '@/utils/publicData.js'
import { ref } from 'vue'

// 菜单展开状态
const expandedMenus = ref({state: '', index: '', isOpen:false})

const handleOpen = (key, keyPath) => {
  expandedMenus.value = {state: '',index: key, isOpen:true}
  console.log(key, keyPath)
}
const handleClose = (key, keyPath) => {
  expandedMenus.value = {state: '',index: key, isOpen:false}
  console.log(key, keyPath)
}
const router = useRouter()
function routeTo(path) {
  router.push(path)
}

</script>

<template>
  <el-row class="tac">
    <el-col :span="50">
      <el-menu
        class="el-menu-vertical"
        text-color="#fff"
        active-text-color="#ffd04b"
        @open="handleOpen"
        @close="handleClose"
        @collapse="false"
        :unique-opened="true"
        :collapse="isCollapse"
        :collapse-transition="false"
      >
        <el-sub-menu index="1">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-gaojingguanli"></use>
              </svg>
            </el-icon>
            <span class="menu">告警管理</span>
          </template>
          <el-menu-item @click="routeTo('/alarmManagement/alarmItem')" index="1-1">告警数据</el-menu-item>
        </el-sub-menu>
        <el-sub-menu index="2">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true" >
                <use xlink:href="#icon-shijianguanli"></use>
              </svg>
            </el-icon>
            <span class="menu">工具管理</span>
          </template>
          <el-menu-item @click="routeTo('/toolsManagement/tools')" index="2-1">工具库</el-menu-item>
        </el-sub-menu>
        <el-sub-menu index="3">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-xitongguanli"></use>
              </svg>
            </el-icon>
            <span class="menu">运维工具</span>
          </template>
          <el-menu-item @click="routeTo" index="3-1">参数配置</el-menu-item>
        </el-sub-menu>
      </el-menu>
    </el-col>
  </el-row>
</template>

<style scoped>
.tac {
  user-select: none;
  overflow: hidden;
}
.el-menu-vertical {
  border-right: none !important;
}

:deep(.el-sub-menu__title:hover) {
  background-color: rgba(42, 82, 152, 0.3) !important;
}
.el-divider {
  margin: 0;
}
:deep(.el-menu) {
  background-color: transparent !important;
  transition: all 0.3s ease;
}
:deep(.el-menu-item) {
  color: rgba(207, 211, 217, 1)  !important;
}
:deep(.el-menu-item:hover) {
  color: rgba(255, 255, 255, 1) !important;
  background-color: rgba(42, 82, 152, 0.3) !important;
}
.menu {
  font-size: 16px;
  font-weight: 400;
  color: rgba(255, 255, 255, 1);
}
/* 菜单箭头样式 */
:deep(.el-sub-menu__icon-arrow) {
  font-size: 16px !important;
  margin-top: -8px !important;
}

.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
  color: rgba(255, 255, 255, 1);;
}
</style>
