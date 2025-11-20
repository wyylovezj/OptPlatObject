<script setup>
import { loginAuthentication } from '@/api/interface.js'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { messageInstance, loading } from '@/utils/publicData.js'


const router = useRouter()
const authStore = useAuthStore()
const loginForm = ref({
  username: '',
  password: ''
})
// 输入验证规则
const loginRules = ref({
  username: [
    { required: true, message: '请输入用户名' },
    { pattern: /^[a-zA-Z0-9]+$/, message: '用户名只能包含英文字母和数字' }
  ],
  password: [
    { required: true, message: '请输入密码'},
    { pattern: /^[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]+$/, message: '密码只能包含英文字母、数字和特殊字符' }
  ]
})

// 登录回调函数
const handleLogin = async () => {
  // 置加载标志位true，按钮显示加载动画
  loading.value = true
  try {
    // 调用登录接口进行登录验证
    const userData = await loginAuthentication(loginForm.value.username, loginForm.value.password)
    console.log(userData)
    // 保存用户名到历史记录
    saveUsernameToHistory(loginForm.value.username)
    // 存储登录状态到 pinia 仓库
    authStore.loginInfoStorage(userData.username, userData.status)

    // 登录成功后重定向到所输入的url
    const redirect = router.currentRoute.value.query.redirect || '/'
    await router.push(redirect)
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));

    }
    messageInstance.value = ElMessage.success({
      message: '登录成功',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  } catch (error) {
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    messageInstance.value = ElMessage.error({
      message: '登录失败: ' + error.message,
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      }
    })
  } finally {
    loading.value = false
  }
}
// 保存用户名到历史记录
const recentUsernames = ref(JSON.parse(localStorage.getItem('recentUsernames') || '[]'))

const saveUsernameToHistory = (username) => {
  const usernames = recentUsernames.value
  if (!usernames.includes(username)) {
    usernames.unshift(username)
    if (usernames.length > 1) {
      usernames.pop()
    }
    recentUsernames.value = usernames
    localStorage.setItem('recentUsernames', JSON.stringify(usernames))
  }
}

const querySearch = (queryString, cb) => {
  const results = queryString
    ? recentUsernames.value.filter(createFilter(queryString))
    : recentUsernames.value
  cb(results.map(item => ({ value: item })))
}

const createFilter = (queryString) => {
  return (username) => {
    return username.toLowerCase().indexOf(queryString.toLowerCase()) === 0
  }
}

const handleSelect = (item) => {
  loginForm.value.username = item.value
}

</script>

<template>
  <div class="login-container">
    <el-form :model="loginForm" :rules="loginRules" class="login-form" @keyup.enter="handleLogin">
      <h2 class="title">告警管理平台</h2>
      <el-form-item prop="username">
        <el-autocomplete
          v-model="loginForm.username"
          :fetch-suggestions="querySearch"
          :prefix-icon="User"
          placeholder="用户名"
          autocomplete="on"
          @select="handleSelect"
          clearable
          @input="loginForm.username = loginForm.username.replace(/\s/g, '')"
        />
      </el-form-item>

      <el-form-item prop="password">
        <el-input
          v-model="loginForm.password"
          type="password"
          placeholder="密码"
          show-password
          :prefix-icon="Lock"
          clearable
          @input="loginForm.password = loginForm.password.replace(/\s/g, '')"
        />
      </el-form-item>

      <el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          :loading="loading"
          @click="handleLogin"
        >
          登 录
        </el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<style scoped>
* {
  user-select: none;
}
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
