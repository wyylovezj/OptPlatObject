<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth.js'
import { ElMessage } from 'element-plus'

const router = useRouter()
const authStore = useAuthStore()

const loginForm = ref({
  username: '',
  password: ''
})

const loginRules = ref({
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' }
  ]
})

const loading = ref(false)

const handleLogin = async () => {
  loading.value = true

  try {
    // 模拟登录请求
    // 实际项目中替换为真实的API调用
    await new Promise(resolve => setTimeout(resolve, 1000))

    // 模拟登录成功响应
    const userData = {
      id: 1,
      username: loginForm.value.username,
      name: '管理员',
      roles: ['admin']
    }

    // 存储登录状态
    authStore.login(userData, 'mock-auth-token')

    // 登录成功后重定向
    const redirect = router.currentRoute.value.query.redirect || '/'
    router.push(redirect)

    ElMessage.success('登录成功')
  } catch (error) {
    ElMessage.error('登录失败: ' + error.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-container">
    <el-form ref="loginForm" :model="loginForm" :rules="loginRules" class="login-form">
      <h2 class="title">告警平台登录</h2>

      <el-form-item prop="username">
        <el-input
          v-model="loginForm.username"
          prefix-icon="el-icon-user"
          placeholder="用户名"
        />
      </el-form-item>

      <el-form-item prop="password">
        <el-input
          v-model="loginForm.password"
          prefix-icon="el-icon-lock"
          type="password"
          placeholder="密码"
          show-password
        />
      </el-form-item>

      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          :loading="loading"
          @click="handleLogin"
        >
          登录
        </el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: #2d3a4b;
}

.login-form {
  width: 400px;
  padding: 40px;
  background: #fff;
  border-radius: 6px;
  box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
}

.title {
  margin-bottom: 30px;
  text-align: center;
  color: #303133;
}

.login-btn {
  width: 100%;
}
</style>
