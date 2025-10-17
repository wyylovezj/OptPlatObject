<script setup>
import HeaderBar from '@/components/HeaderBar.vue'
import SideBar from '@/components/SideBar.vue'
import { isCollapse } from '@/utils/publicData.js'

// 侧边栏折叠标志
const toggleCollapse = () => {
  isCollapse.value = !isCollapse.value
}
</script>

<template>
    <!-- 页面总容器开始 -->
    <div class="common-layout">
      <!-- element 布局总容器开始 -->
      <el-container>
        <!-- 侧边栏开始 -->
        <el-aside :width="isCollapse ? '64px' : '200px'">
          <div class="side-bar">
            <div style="height: 40px;width: 64px;display: flex;align-items: center;justify-content: center;">
              <el-button type="primary" @click="toggleCollapse">
                <el-icon>
                  <svg class="icon" aria-hidden="true" height="30px" width="30px">
                    <use xlink:href="#icon-menu-icon"></use>
                  </svg>
                </el-icon>
              </el-button>
            </div>
            <div class="side-menu">
              <SideBar></SideBar>
            </div>
          </div>
        </el-aside>
        <!-- 侧边栏结束 -->
        <el-container>
          <el-header>
            <div class="header-bar">
              <header-bar></header-bar>
            </div>
          </el-header>
          <el-main>
            <router-view></router-view>
          </el-main>
        </el-container>
      </el-container>
      <!-- element 布局总容器结束 -->
    </div>
    <!-- 页面总容器结束 -->
</template>

<style scoped>
.common-layout {
  height: 100%;
}
.el-container{
  height: 100%;
}
.el-aside {
  background: #EBEEF5;
  height: 100%;
  transition: width 0.4s ease;
}
.el-header {
  height: 40px;
  background: rgba(64, 158, 255,0.8);
}
.el-main {
  background-color: #F2F3F5;
}
.side-bar {
  position: relative;
  height: 100%;
}
.side-menu {
  position: absolute;
  top: 40px;
  width: 100%;
}
.header-bar {
  height: 100%;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
  color: greenyellow;
}
</style>
