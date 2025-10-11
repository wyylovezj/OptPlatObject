<script setup>
import HeaderBar from '@/components/HeaderBar.vue'
import SideBar from '@/components/SideBar.vue'
</script>

<template>
    <!-- 页面总容器开始 -->
    <div class="common-layout">
      <!-- element 布局总容器开始 -->
      <el-container>
        <!-- 侧边栏开始 -->
        <el-aside width="200px">
          <div class="side-bar">
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
  background: rgb(51, 126, 204);
  height: 100%;
}
.el-header {
  height: 5%;
  background: rgb(51, 126, 204);
}
.side-bar {
  position: relative;
  height: 100%;
}
.side-menu {
  position: absolute;
  top: 5%;
  width: 100%;
}
.header-bar {
  height: 100%;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
