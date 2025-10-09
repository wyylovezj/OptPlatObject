<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowRight } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth.js'
const authStore = useAuthStore()
const userData = JSON.parse(localStorage.getItem('user'))
const name = ref(null)
name.value = userData.username
// 顶部个人信息菜单后面的上下箭头翻转标志
const direction = ref(false)
// 面包屑过滤
const route = useRoute()
const router = useRouter()
const breadcrumbList = computed(() => {
  // 过滤掉没有breadcrumb的路由记录
  return route.matched.filter(item => item.meta && item.meta.breadcrumb)
})

function changeDirection(isVisible) {
  direction.value = isVisible
}
function logout() {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <div class="bread-crumb">
    <!-- 面包屑组件开始 -->
    <el-breadcrumb :separator-icon="ArrowRight" ref="breadCrumb">
      <el-breadcrumb-item
        v-for="(item, index) in breadcrumbList"
        :key="index"
        :to="item.path"
      >
        {{ item.meta.breadcrumb }}
      </el-breadcrumb-item>
    </el-breadcrumb>
    <!-- 面包屑组件结束 -->
  </div>
  <div class="user">
    <!-- 顶部个人信息下拉框组件开始 -->
    <el-icon style="font-size: 1.2em">
      <svg class="icon icon-user" aria-hidden="true">
        <use xlink:href="#icon-yonghuguanli"></use>
      </svg>
    </el-icon>
    <el-dropdown  @visible-change="changeDirection" trigger="click">
      <span class="el-dropdown-link">
        <span class="user-name" style="font-size: 1em">
          {{name}}
        </span>
        <el-icon  style="font-size: 0.9em">
          <svg class="icon" aria-hidden="true">
            <use v-show="direction" xlink:href="#icon-xiajiantou"></use>
            <use v-show="!direction" xlink:href="#icon-shangjiantou"></use>
          </svg>
        </el-icon>
      </span>
      <template #dropdown>
        <el-dropdown-menu>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(121, 187, 255)">
                <use xlink:href="#icon-gerenxinxi"></use>
              </svg>
            </el-icon>
            修改个人信息
          </el-dropdown-item>
          <el-dropdown-item>
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(121, 187, 255)">
                <use xlink:href="#icon-xiugaimima"></use>
              </svg>
            </el-icon>
            修改密码
          </el-dropdown-item>
          <el-dropdown-item @click="logout">
            <el-icon>
              <svg class="icon" aria-hidden="true" style="fill: rgb(121, 187, 255)">
                <use xlink:href="#icon-tcdl"></use>
              </svg>
            </el-icon>
            退出登录
          </el-dropdown-item>
        </el-dropdown-menu>
      </template>
    </el-dropdown>
    <!-- 顶部个人信息下拉框组件结束 -->
  </div>
</template>

<style scoped>
* {
  color: white;
  user-select: none;
}
.bread-crumb {
  flex: 1;
  justify-content: flex-start;
}
.user {
  flex: 1;
}
.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
.example-showcase .el-dropdown-link {
  cursor: pointer;
  color: var(--el-color-primary);
  display: flex;
  align-items: center;
}
.user {
  flex: 1;
  display: flex;
  justify-content: flex-end;
  align-items: center;
}
.user-name {
  font-size: 15px;
  margin-left: 8px;
  margin-right: 8px;
}
/* 面包屑组件样式 */
/* 不被选中时的颜色 */
.el-breadcrumb :deep(.el-breadcrumb__inner)  {
  color: #606868 !important;
  font-weight:400 !important;
}
.el-breadcrumb__item:hover :deep(.el-breadcrumb__inner)  {
  color: white !important;
  font-weight:400 !important;
}
/* 被选中时的颜色 */
.el-breadcrumb__item:last-child :deep(.el-breadcrumb__inner) {
  color: #606868 !important;
  font-weight:400 !important;
}
.el-breadcrumb__item :deep(.el-breadcrumb__separator) {
  color: white !important;
  font-weight:400 !important;
}
/* 面包屑组件样式 */
</style>
