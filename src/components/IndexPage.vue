<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：页面主体
 * @date： 2026-01-28 09:28:57
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:28:57
 */
import HeaderBar from '@/components/HeaderBar.vue'
import SideBar from '@/components/SideBar.vue'
import { isCollapse, debounce } from '@/utils/publicData.js'
import { Expand,Fold } from '@element-plus/icons-vue'
import { useRoute } from 'vue-router'

// 获取路由实例
const route = useRoute()

// 侧边栏折叠标志
const toggleCollapse = debounce(() => {
  isCollapse.value = !isCollapse.value
}, 150)
</script>

<template>
    <!-- 页面总容器开始 -->
    <div class="common-layout">
      <!-- element 布局总容器开始 -->
      <el-container>
        <!-- 侧边栏开始 -->
        <el-aside :width="isCollapse ? '64px' : '150px'">
          <div class="side-bar">
            <div style="height: 40px;width: 64px;display: flex;align-items: center;justify-content: center;">
              <el-button v-if="!isCollapse" style="font-size: 20px" type="primary"  color="#1a1f2e" :icon="Expand" @click="toggleCollapse"/>
              <el-button v-if="isCollapse" style="font-size: 20px" type="primary"  color="#1a1f2e" :icon="Fold" @click="toggleCollapse"/>
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
            <router-view v-slot="{ Component }">
              <transition name="slide-fade" mode="out-in" >
<!--                <keep-alive :exclude="['AlarmItemPage']" >-->
                  <component :is="Component" :key="route.fullPath"/>
<!--                </keep-alive>-->
              </transition>
            </router-view>
          </el-main>
        </el-container>
      </el-container>
      <!-- element 布局总容器结束 -->
    </div>
    <!-- 页面总容器结束 -->
</template>

<style scoped>
.slide-fade-enter-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-fade-leave-active {
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-fade-enter-from {
  transform: translateX(10px);
  opacity: 0;
}

.slide-fade-leave-to {
  transform: translateX(-10px);
  opacity: 0;
}

.common-layout {
  height: 100%;
  background-color: #f0f2f5;
}

.el-container{
  height: 100%;
}

.el-aside {
  background-color: #1a1f2e;
  height: 100%;
  transition: width 0.3s ease;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.1);
  position: relative;
  z-index: 10;
}

.el-header {
  height: 40px;
  background-color: #1a1f2e;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
}

.el-main {
  background-color: #f0f2f5;
  padding: 16px;
}

.side-bar {
  position: relative;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.collapse-btn-wrapper {
  height: 40px;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.2);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.collapse-btn {
  width: 32px;
  height: 32px;
  padding: 0;
  border: none;
  background-color: transparent;
  color: rgba(255, 255, 255, 0.65);
  font-size: 16px;
  transition: all 0.2s ease;
}

.collapse-btn:hover {
  background-color: rgba(255, 255, 255, 0.1);
  color: rgba(255, 255, 255, 0.9);
}

.collapse-btn:active {
  transform: scale(0.95);
}

.side-menu {
  position: absolute;
  top: 40px;
  width: 100%;
  height: calc(100% - 40px);
  overflow-y: auto;
  overflow-x: hidden;
}

.header-bar {
  height: 100%;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: width 0.3s ease;
}

.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
</style>
