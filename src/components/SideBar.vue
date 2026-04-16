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
import { ref,computed } from 'vue'
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
        :text-color="isCollapse ? '#000' : '#fff'"
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
          <el-sub-menu v-if="menu.children && menu.children.length > 0" :index="menu.id">
            <template #title>
              <el-icon>
                <svg class="icon" aria-hidden="true">
                  <use :xlink:href="'#' + menu.icon"></use>
                </svg>
              </el-icon>
              <span class="menu">{{ menu.name }}</span>
            </template>
            <el-menu-item
              v-for="child in menu.children"
              :key="child.id"
              @click="routeTo(child.path)"
              :index="child.id"
            >
              {{ child.name }}
            </el-menu-item>
          </el-sub-menu>
          <el-menu-item
            v-else
            @click="routeTo(menu.path)"
            :index="menu.id"
          >
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use :xlink:href="'#' + menu.icon"></use>
              </svg>
            </el-icon>
            <span class="menu">{{ menu.name }}</span>
          </el-menu-item>
        </template>
<!--        <el-sub-menu index="1">-->
<!--          <template #title>-->
<!--            <el-icon>-->
<!--              <svg class="icon" aria-hidden="true">-->
<!--                <use xlink:href="#icon-gaojingguanli"></use>-->
<!--              </svg>-->
<!--            </el-icon>-->
<!--            <span class="menu">告警管理</span>-->
<!--          </template>-->
<!--          <el-menu-item @click="routeTo('/alarmManagement/alarmItem')" index="1-1">告警数据</el-menu-item>-->
<!--        </el-sub-menu>-->
<!--        <el-sub-menu index="2">-->
<!--          <template #title>-->
<!--            <el-icon>-->
<!--              <svg class="icon" aria-hidden="true" >-->
<!--                <use xlink:href="#icon-shijianguanli"></use>-->
<!--              </svg>-->
<!--            </el-icon>-->
<!--            <span class="menu">工具管理</span>-->
<!--          </template>-->
<!--          <el-menu-item @click="routeTo('/toolsManagement/tools')" index="2-1">工具库</el-menu-item>-->
<!--        </el-sub-menu>-->
<!--        <el-sub-menu index="3">
          <template #title>
            <el-icon>
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-xitongguanli"></use>
              </svg>
            </el-icon>
            <span class="menu">运维工具</span>
          </template>
          <el-menu-item @click="routeTo" index="3-1">参数配置</el-menu-item>
        </el-sub-menu>-->
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
  background: transparent !important;
}

:deep(.el-menu) {
  background-color: transparent !important;
}

:deep(.el-sub-menu__title) {
  transition: all 0.2s ease;
  margin: 2px 6px;
  border-radius: 4px;
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
  margin: 2px 6px;
  border-radius: 4px;
  height: 44px;
  line-height: 44px;
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
  margin: 0 6px;
  border-radius: 4px;
}

:deep(.el-menu--inline .el-menu-item) {
  padding-left: 48px !important;
  height: 40px;
  line-height: 40px;
  font-size: 13px;
  margin: 1px 4px;
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
