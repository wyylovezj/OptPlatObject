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
import { useRouter, useRoute } from 'vue-router'
import { isCollapse } from '@/utils/publicData.js'
import { ref, computed } from 'vue'
import { usePermissionStore } from '@/stores/permissionStore.js'

// 获取权限 store 实例
const permissionStore = usePermissionStore()

// 动态菜单列表
const dynamicMenus = computed(() => {
  const menus = permissionStore.accessibleMenus
  if (menus && menus.length > 0) {
    return menus
  }
  // 如果没有动态菜单，返回默认菜单结构
  return defaultMenus.value
})
// 默认菜单（当没有权限数据时使用）
const defaultMenus = ref([])

// 菜单展开状态
const expandedMenus = ref({ state: '', index: '', isOpen: false })

const handleOpen = (key, keyPath) => {
  expandedMenus.value = { state: '', index: key, isOpen: true }
  console.log(key, keyPath)
}
const handleClose = (key, keyPath) => {
  expandedMenus.value = { state: '', index: key, isOpen: false }
  console.log(key, keyPath)
}
const router = useRouter()
function routeTo(path) {
  console.log('routeTo', path)
  router.push(path)
}
const route = useRoute()
// 获取当前应该激活的菜单ID
const activeMenuId = computed(() => {
  // 遍历所有菜单，找到与当前路由匹配的菜单ID
  for (const menu of dynamicMenus.value) {
    if (menu.children && menu.children.length > 0) {
      // 检查子菜单
      const matchedChild = menu.children.find((child) => route.path === child.path || route.path.startsWith(child.path + '/'))
      if (matchedChild) {
        return matchedChild.id
      }
    } else {
      // 检查一级菜单
      if (route.path === menu.path) {
        return menu.id
      }
    }
  }
  return ''
})
// 判断当前路由是否属于某个菜单或其子菜单
const isActiveMenu = (menu) => {
  // 如果菜单有 path 且当前路由完全匹配
  if (menu.path && route.path === menu.path) {
    return true
  }
  // 如果菜单有子菜单，检查当前路由是否以子菜单路径开头
  if (menu.children && menu.children.length > 0) {
    return menu.children.some((child) => route.path.startsWith(child.path))
  }
  return false
}
</script>

<template>
  <el-row class="tac">
    <el-col :span="24">
      <el-menu
        class="el-menu-vertical"
        :text-color="isCollapse ? '#000' : '#fff'"
        :default-active="activeMenuId"
        active-text-color="#ffd04b"
        @open="handleOpen"
        @close="handleClose"
        @collapse="false"
        :unique-opened="true"
        :collapse="isCollapse"
        :collapse-transition="false"
      >
        <!-- 动态渲染菜单 -->
        <template v-for="menu in dynamicMenus" :key="menu.id">
          <el-sub-menu v-if="menu.children && menu.children.length > 0" :index="menu.id" :class="{ 'is-active': isActiveMenu(menu) }">
            <template #title>
              <el-icon>
                <svg class="icon" aria-hidden="true">
                  <use :xlink:href="'#' + menu.icon"></use>
                </svg>
              </el-icon>
              <span class="menu">{{ menu.name }}</span>
            </template>
            <el-menu-item v-for="child in menu.children" :key="child.id" @click="routeTo(child.path)" :index="child.id">
              {{ child.name }}
            </el-menu-item>
          </el-sub-menu>
          <el-menu-item v-else @click="routeTo(menu.path)" :index="menu.id" :class="{ 'is-active': route.path === menu.path }">
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use :xlink:href="'#' + menu.icon"></use>
              </svg>
            </el-icon>
            <span class="menu">{{ menu.name }}</span>
          </el-menu-item>
        </template>
      </el-menu>
    </el-col>
  </el-row>
</template>

<style scoped>
.tac {
  user-select: none;
  overflow: hidden;
  width: 100%;
  max-width: 100%;
}

.el-menu-vertical {
  border-right: none !important;
  background: transparent !important;
  width: 100%;
  max-width: 100%;
  overflow-x: hidden;
}

:deep(.el-menu) {
  background-color: transparent !important;
}

:deep(.el-sub-menu__title) {
  transition: all 0.2s ease;
  margin: 2px 4px;
  border-radius: 4px;
  padding: 0 8px !important;
}

:deep(.el-sub-menu__title .el-icon) {
  flex-shrink: 0;
}

:deep(.el-sub-menu__title:hover) {
  background-color: rgba(255, 255, 255, 0.08) !important;
}

:deep(.el-sub-menu.is-active > .el-sub-menu__title) {
  background-color: rgba(255, 255, 255, 0.1) !important;
  color: #fff !important;
}

:deep(.el-menu-item) {
  color: rgba(255, 255, 255, 0.65) !important;
  transition: all 0.2s ease;
  margin: 2px 4px;
  border-radius: 4px;
  height: 44px;
  line-height: 44px;
  padding: 0 8px !important;
}

:deep(.el-menu-item:hover) {
  color: rgba(255, 255, 255, 0.95) !important;
  background-color: rgba(255, 255, 255, 0.08) !important;
}

:deep(.el-menu-item.is-active) {
  color: #409eff !important;
  background-color: rgba(64, 158, 255, 0.15) !important;
  font-weight: 500;
}

.menu {
  font-size: 14px;
  font-weight: 400;
  color: rgba(255, 255, 255, 0.9);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;
  min-width: 0;
}

:deep(.el-sub-menu__icon-arrow) {
  font-size: 14px !important;
  color: rgba(255, 255, 255, 0.5);
  transition: transform 0.2s ease !important;
}

.icon {
  width: 16px;
  height: 16px;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.75);
  transition: all 0.2s ease;
  flex-shrink: 0;
}
:deep(.el-sub-menu.is-active > .el-sub-menu__title) .icon {
  color: #409eff !important;
}
:deep(.el-menu-item:hover) .icon,
:deep(.el-sub-menu__title:hover) .icon {
  color: rgba(255, 255, 255, 0.95);
}

:deep(.el-menu-item.is-active) .icon {
  color: #409eff;
}

:deep(.el-menu--collapse) {
  width: 64px;
}

:deep(.el-menu--collapse .el-menu-item),
:deep(.el-menu--collapse .el-sub-menu__title) {
  margin: 2px 4px;
  justify-content: center;
  padding: 0 !important;
}

:deep(.el-menu--collapse .menu) {
  display: none;
}

:deep(.el-menu--inline) {
  background-color: rgba(0, 0, 0, 0.15) !important;
  margin: 0 4px;
  border-radius: 4px;
}

:deep(.el-menu--inline .el-menu-item) {
  padding-left: 40px !important;
  height: 40px;
  line-height: 40px;
  font-size: 13px;
  margin: 1px 4px;
  padding-right: 8px !important;
}

:deep(.el-menu)::-webkit-scrollbar {
  width: 4px;
}

:deep(.el-menu)::-webkit-scrollbar-track {
  background: transparent;
}

:deep(.el-menu)::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
  border-radius: 2px;
}

:deep(.el-menu)::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.25);
}
</style>
