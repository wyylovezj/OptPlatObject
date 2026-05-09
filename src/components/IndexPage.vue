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
            <div class="logo-wrapper" @click="toggleCollapse">
              <svg class="logo-icon" viewBox="0 0 24 24">
                <path d="M12 2L2 7v10l10 5 10-5V7L12 2zm0 2.18l7 3.5v7.64l-7 3.5-7-3.5V7.68l7-3.5zM12 8a4 4 0 100 8 4 4 0 000-8zm0 2a2 2 0 110 4 2 2 0 010-4z"/>
              </svg>
              <span v-show="!isCollapse" class="logo-text">信维通</span>
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

.logo-wrapper {
  height: 50px;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  padding-left: 20px;
  gap: 8px;
  background-color: rgba(0, 0, 0, 0.2);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  cursor: pointer;
  transition: all 0.3s ease;
}

.logo-wrapper:hover {
  background-color: rgba(255, 255, 255, 0.05);
}

.logo-icon {
  width: 24px;
  height: 24px;
  fill: #1a73e8;
  flex-shrink: 0;
  transition: all 0.3s ease;
  vertical-align: middle;
  transform: skewX(-10deg);
}

.logo-text {
  font-size: 15px;
  font-weight: 500;
  font-style: italic;
  color: #409eff;
  white-space: nowrap;
  letter-spacing: 1px;
  line-height: 24px;
}

.side-menu {
  position: absolute;
  top: 50px;
  width: 100%;
  height: calc(100% - 50px);
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
