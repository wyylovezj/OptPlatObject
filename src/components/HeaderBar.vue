<script setup>
import { ref, useTemplateRef, onMounted  } from 'vue'
import { useCurrentDomStore } from '@/stores/counter.js'
import { ArrowRight } from '@element-plus/icons-vue'
const name = ref(null)
name.value = '魏阳阳'
const direction = ref(false)
const breadCrumb = useTemplateRef("breadCrumb")
const currentDom = useCurrentDomStore()
onMounted(() => {
  currentDom.setCurrentDom(breadCrumb.value)
})

function changeDirection(isVisible) {
  direction.value = isVisible
}
</script>

<template>
  <div class="bread-crumb">
    <el-breadcrumb :separator-icon="ArrowRight" ref="breadCrumb">
<!--      <el-breadcrumb-item :to="{ path: '/' }">homepage</el-breadcrumb-item>-->
<!--      <el-breadcrumb-item>promotion management</el-breadcrumb-item>-->
    </el-breadcrumb>
  </div>
  <div class="user">
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
            <use v-if="direction" xlink:href="#icon-xiajiantou"></use>
            <use v-else xlink:href="#icon-shangjiantou"></use>
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
          <el-dropdown-item>
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
</style>
