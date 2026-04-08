<script setup>
/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: 权限管理主页
 * @date: 2026-03-30 10:00:00
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-03-30 10:00:00
 */
import { useRouter } from 'vue-router'

const router = useRouter()

// 导航到子页面
const navigateTo = (path) => {
  router.push(path)
}
</script>

<template>
  <div class="permission-container">
    <el-row :gutter="20">
      <el-col :span="8">
        <el-card class="permission-card" @click="navigateTo('/permissionManagement/userManage')">
          <div class="card-content">
            <el-icon size="60" color="#409EFF">
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-yonghuguanli"></use>
              </svg>
            </el-icon>
            <h3>用户管理</h3>
            <p>管理用户信息，分配用户角色</p>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="permission-card" @click="navigateTo('/permissionManagement/roleManage')">
          <div class="card-content">
            <el-icon size="60" color="#67C23A">
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-jiaoseguanli"></use>
              </svg>
            </el-icon>
            <h3>角色管理</h3>
            <p>创建角色，分配菜单权限</p>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="permission-card" @click="navigateTo('/permissionManagement/menuManage')">
          <div class="card-content">
            <el-icon size="60" color="#E6A23C">
              <svg class="icon" aria-hidden="true">
                <use xlink:href="#icon-caidan"></use>
              </svg>
            </el-icon>
            <h3>菜单管理</h3>
            <p>管理系统菜单和按钮权限</p>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.permission-container {
  padding: 20px;
}

.permission-card {
  cursor: pointer;
  transition: all 0.3s;
  min-height: 200px;
}

.permission-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}

.card-content {
  text-align: center;
  padding: 20px;
}

.card-content h3 {
  margin: 20px 0 10px;
  color: #303133;
}

.card-content p {
  color: #909399;
  font-size: 14px;
}

.icon {
  width: 1em;
  height: 1em;
  vertical-align: -0.15em;
  fill: currentColor;
  overflow: hidden;
}
</style>
