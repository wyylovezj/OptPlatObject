<script setup>
/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：登录页面
 * @date： 2026-01-28 09:29:26
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-01-28 09:29:26
 */
import { loginAuthentication } from '@/api/interface.js'
import { ref,onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { ElMessage } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { messageInstance, loginLoading, user } from '@/utils/publicData.js'

// 获取store实例
const authStore = useAuthStore()
const router = useRouter()
const loginFormRef = ref(null)
const loginForm = ref({
  username: '',
  password: '',
})
// 密码可见性控制
const passwordVisible = ref(false)
// 记住我状态
const rememberMe = ref(false)

// 页面加载时检查是否有保存的登录信息
onMounted(() => {
  const savedUsername = localStorage.getItem('rememberedUsername')
  const savedPassword = localStorage.getItem('rememberedPassword')

  if (savedUsername && savedPassword) {
    loginForm.value.username = savedUsername
    loginForm.value.password = savedPassword
    rememberMe.value = true
  }

  // 初始化粒子动画
  const container = document.getElementById('particles')
  if (container) {
    for (let i = 0; i < 30; i++) {
      const p = document.createElement('div')
      p.className = 'particle'
      p.style.left = Math.random() * 100 + '%'
      p.style.animationDuration = (15 + Math.random() * 20) + 's'
      p.style.animationDelay = Math.random() * 15 + 's'
      p.style.width = p.style.height = (1 + Math.random() * 2) + 'px'
      container.appendChild(p)
    }
  }
})

// 切换密码显示/隐藏
const togglePassword = () => {
  passwordVisible.value = !passwordVisible.value
}

// 清除用户名
const clearUsername = () => {
  loginForm.value.username = ''
}

// 清除密码
const clearPassword = () => {
  loginForm.value.password = ''
}
// 输入验证规则
const loginRules = ref({
  username: [
    { required: true, message: '请输入用户名' },
    { pattern: /^[a-zA-Z0-9]+$/, message: '用户名只能包含英文字母和数字' },
  ],
  password: [
    { required: true, message: '请输入密码' },
    { pattern: /^[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]+$/, message: '密码只能包含英文字母、数字和特殊字符' },
  ],
})

// 登录回调函数
const handleLogin = async () => {
  // 使用原生 HTML5 验证
  const formElement = loginFormRef.value?.$el
  if (formElement) {
    // 查找所有带有 required 属性的输入框
    const requiredInputs = formElement.querySelectorAll('input[required]')

    // 遍历检查每个必填字段
    for (const input of requiredInputs) {
      if (!input.value || input.value.trim() === '') {
        // 触发该字段的验证提示
        input.reportValidity()
        return
      }
    }
  }

  // 置加载标志位true，按钮显示加载动画
  loginLoading.value = true
  try {
    // 调用登录接口进行登录验证
    const userData = await loginAuthentication(loginForm.value.username, loginForm.value.password)

    // 处理"记住我"功能
    if (rememberMe.value) {
      // 保存用户名和密码到 localStorage
      localStorage.setItem('rememberedUsername', loginForm.value.username)
      localStorage.setItem('rememberedPassword', loginForm.value.password)
    } else {
      // 如果未勾选，清除已保存的信息
      localStorage.removeItem('rememberedUsername')
      localStorage.removeItem('rememberedPassword')
    }

    // 保存用户名到历史记录
    saveUsernameToHistory(loginForm.value.username)
    // 登录成功后，设置标记表示这是登录重定向
    sessionStorage.setItem('isLoginRedirect', 'true')
    // 存储登录状态到 pinia 仓库
    await authStore.loginInfoStorage(userData.username, userData.status)

    // 同步更新 publicData 中的 user 变量（用于 HeaderBar 显示）
    user.value = userData.username

    // 登录成功后重定向到所输入的url
    const redirect = router.currentRoute.value.query.redirect || '/home'
    await router.push(redirect)
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.success({
      message: '登录成功',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      },
    })
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.success({
      message: '登录成功',
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      },
    })
  } catch (error) {
    console.log(error)
    // 如果已有提示框在显示，先关闭它
    if (messageInstance.value) {
      // 关闭所有消息
      ElMessage.closeAll()
      // 等待消息关闭动画完成
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    messageInstance.value = ElMessage.error({
      message: '登录失败: ' + error.message,
      duration: 1000,
      onClose: () => {
        messageInstance.value = null
      },
    })
  } finally {
    loginLoading.value = false
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
  const results = queryString ? recentUsernames.value.filter(createFilter(queryString)) : recentUsernames.value
  cb(results.map((item) => ({ value: item })))
}

const createFilter = (queryString) => {
  return (username) => {
    return username.toLowerCase().indexOf(queryString.toLowerCase()) === 0
  }
}

const handleSelect = (item) => {
  loginForm.value.username = item.value
}

// SSO handler (placeholder)
const handleSSO = (provider) => {
  console.log(`SSO login with ${provider}`)
}
</script>

<template>
  <div class="login-container">
    <!-- Left: Branding Panel -->
    <div class="brand-panel">
      <div class="grid-overlay"></div>
      <div class="particles" id="particles"></div>

      <div class="brand-content">
        <div class="logo-icon">
          <svg viewBox="0 0 24 24">
            <path
              d="M12 2L2 7v10l10 5 10-5V7L12 2zm0 2.18l7 3.5v7.64l-7 3.5-7-3.5V7.68l7-3.5zM12 8a4 4 0 100 8 4 4 0 000-8zm0 2a2 2 0 110 4 2 2 0 010-4z"
            />
          </svg>
        </div>
        <h1 class="brand-title">信维通</h1>
        <p class="brand-subtitle">运维一体化平台</p>

        <div class="brand-features">
          <div class="feature-item">
            <div class="feature-icon blue">🛡️</div>
            <div class="feature-text">
              <h4>统一监控</h4>
              <p>全栈可观测，实时掌握系统健康状态</p>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon green">⚡</div>
            <div class="feature-text">
              <h4>智能运维</h4>
              <p>智能告警分析，故障自愈闭环</p>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon orange">📊</div>
            <div class="feature-text">
              <h4>高效协同</h4>
              <p>工单流转自动化，团队协作无缝衔接</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Right: Login Panel -->
    <div class="login-panel">
      <div class="login-box">
        <div class="login-header">
          <h2>欢迎回来</h2>
          <p>登录信维通运维一体化平台</p>
        </div>

        <el-form ref="loginFormRef" :model="loginForm" class="login-form" @keyup.enter="handleLogin">
          <el-form-item prop="username">
            <label class="form-label">用户名</label>
            <div class="input-wrapper">
              <svg
                class="input-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
              <el-input
                v-model="loginForm.username"
                placeholder="请输入用户名"
                autocomplete="off"
                spellcheck="false"
                required
                @invalid="($event) => { $event.target.setCustomValidity('请填写用户名') }"
                @input="($event) => { $event.target.setCustomValidity('') }"
              />
              <button v-if="loginForm.username" type="button" class="clear-btn" @click="clearUsername" aria-label="清除">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>
          </el-form-item>

          <el-form-item prop="password">
            <label class="form-label">密码</label>
            <div class="input-wrapper">
              <svg
                class="input-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
              <el-input
                v-model="loginForm.password"
                :type="passwordVisible ? 'text' : 'password'"
                placeholder="请输入密码"
                autocomplete="off"
                spellcheck="false"
                required
                @invalid="($event) => { $event.target.setCustomValidity('请填写密码') }"
                @input="($event) => { $event.target.setCustomValidity('') }"
              />
              <button v-if="loginForm.password" type="button" class="clear-btn" @click="clearPassword" aria-label="清除">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
              <button type="button" class="password-toggle-btn" @click="togglePassword" aria-label="显示密码">
                <svg
                  v-if="!passwordVisible"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
                <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <path
                    d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"
                  />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              </button>
            </div>
          </el-form-item>

          <div class="form-options">
            <label class="remember-me">
              <input v-model="rememberMe" type="checkbox" id="remember" />
              <span class="checkmark">
                <svg viewBox="0 0 24 24"><path d="M20 6L9 17l-5-5" /></svg>
              </span>
              记住我
            </label>
          </div>

          <el-form-item class="submit-item">
            <el-button type="primary" class="login-btn" :loading="loginLoading" @click="handleLogin">
              <span class="btn-text">登 录</span>
            </el-button>
          </el-form-item>
        </el-form>

        <!--        <div class="divider">-->
        <!--          <span>其他登录方式</span>-->
        <!--        </div>-->

        <!--        <div class="sso-options">-->
        <!--          <button class="sso-btn" @click="handleSSO('ldap')">-->
        <!--            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2a10 10 0 100 20 10 10 0 000-20z"/><path d="M2 12h20M12 2a15 15 0 014 10 15 15 0 01-4 10 15 15 0 01-4-10A15 15 0 0112 2z"/></svg>-->
        <!--            LDAP-->
        <!--          </button>-->
        <!--          <button class="sso-btn" @click="handleSSO('dingtalk')">-->
        <!--            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-.99-.65-.35-1.01.22-1.59.15-.15 2.71-2.48 2.76-2.69a.2.2 0 00-.05-.18c-.06-.05-.14-.03-.2-.02-.09.02-1.49.95-4.22 2.79-.4.27-.76.41-1.08.4-.36-.01-1.04-.2-1.55-.37-.63-.2-1.12-.31-1.08-.66.02-.18.27-.36.74-.55 2.92-1.27 4.86-2.11 5.83-2.51 2.78-1.16 3.35-1.36 3.73-1.36.08 0 .27.02.39.12.1.08.13.19.14.27-.01.06.01.24 0 .38z"/></svg>-->
        <!--            钉钉-->
        <!--          </button>-->
        <!--          <button class="sso-btn" @click="handleSSO('wechat')">-->
        <!--            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M8.69 2C4.45 2 1 4.97 1 8.65c0 2.16 1.13 4.09 2.88 5.44l-.72 2.16 2.52-1.26c.78.22 1.6.36 2.46.39a6.6 6.6 0 01-.23-1.74c0-3.79 3.43-6.87 7.09-6.87.34 0 .67.03 1 .07C15.33 3.87 12.29 2 8.69 2zm-2.87 4a.6.6 0 110-1.2.6.6 0 010 1.2zm5.74 0a.6.6 0 110-1.2.6.6 0 010 1.2z"/><path d="M23 12.82c0-3.22-3.06-5.84-6.83-5.84s-6.83 2.62-6.83 5.84 3.06 5.84 6.83 5.84c.76 0 1.49-.11 2.17-.31l1.93.97-.55-1.65c1.48-1.14 2.28-2.72 2.28-4.85zm-9.2-.82a.54.54 0 110-1.08.54.54 0 010 1.08zm4.74 0a.54.54 0 110-1.08.54.54 0 010 1.08z"/></svg>-->
        <!--            微信-->
        <!--          </button>-->
        <!--        </div>-->

        <div class="login-footer">
          <p>© 2026 信维通 · 运维一体化平台</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

.login-container {
  --primary: #1a73e8;
  --primary-dark: #1557b0;
  --primary-light: #e8f0fe;
  --accent: #00c9a7;
  --bg-dark: #0f1923;
  --bg-card: rgba(255, 255, 255, 0.04);
  --text: #e8eaed;
  --text-muted: #9aa0a6;
  --border: rgba(255, 255, 255, 0.08);
  --input-bg: rgba(255, 255, 255, 0.06);
  --shadow: 0 20px 60px rgba(0, 0, 0, 0.3);

  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
  display: flex;
  min-height: 100vh;
  background: var(--bg-dark);
  overflow: hidden;
  color: var(--text);
  user-select: none;
}

/* ── Left Panel: Branding ── */
.brand-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  position: relative;
  background: linear-gradient(135deg, #0f1923 0%, #162a3e 50%, #0f1923 100%);
  overflow: hidden;
}

.brand-panel::before {
  content: '';
  position: absolute;
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, rgba(26, 115, 232, 0.12) 0%, transparent 70%);
  top: -100px;
  left: -100px;
  animation: float 20s ease-in-out infinite;
}

.brand-panel::after {
  content: '';
  position: absolute;
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(0, 201, 167, 0.08) 0%, transparent 70%);
  bottom: -150px;
  right: -100px;
  animation: float 25s ease-in-out infinite reverse;
}

@keyframes float {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  33% {
    transform: translate(30px, -20px) scale(1.05);
  }
  66% {
    transform: translate(-20px, 15px) scale(0.95);
  }
}

.grid-overlay {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
  background-size: 60px 60px;
  pointer-events: none;
}

.brand-content {
  position: relative;
  z-index: 1;
  text-align: center;
  padding: 40px;
}

.logo-icon {
  width: 88px;
  height: 88px;
  margin: 0 auto 28px;
  background: linear-gradient(135deg, var(--primary) 0%, var(--accent) 100%);
  border-radius: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 32px rgba(26, 115, 232, 0.3);
  position: relative;
}

.logo-icon::after {
  content: '';
  position: absolute;
  inset: -3px;
  border-radius: 25px;
  background: linear-gradient(135deg, var(--primary), var(--accent));
  z-index: -1;
  opacity: 0.3;
  filter: blur(8px);
}

.logo-icon svg {
  width: 48px;
  height: 48px;
  fill: white;
}

.brand-title {
  font-size: 42px;
  font-weight: 700;
  letter-spacing: 6px;
  background: linear-gradient(135deg, #ffffff 0%, #a8c7fa 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 12px;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.brand-subtitle {
  font-size: 16px;
  color: var(--text-muted);
  letter-spacing: 8px;
  text-transform: uppercase;
  font-weight: 300;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.brand-features {
  margin-top: 60px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.feature-item {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 24px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 12px;
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.feature-item:hover {
  border-color: rgba(26, 115, 232, 0.3);
  background: rgba(26, 115, 232, 0.06);
  transform: translateX(4px);
}

.feature-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 20px;
}

.feature-icon.blue {
  background: rgba(26, 115, 232, 0.15);
}
.feature-icon.green {
  background: rgba(0, 201, 167, 0.15);
}
.feature-icon.orange {
  background: rgba(255, 165, 0, 0.15);
}

.feature-text {
  text-align: left;
}

.feature-text h4 {
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 2px;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.feature-text p {
  font-size: 12px;
  color: var(--text-muted);
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

/* ── Right Panel: Login ── */
.login-panel {
  width: 520px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px;
  background: linear-gradient(180deg, #141e2b 0%, #0f1923 100%);
  border-left: 1px solid var(--border);
  position: relative;
}

.login-panel::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 1px;
  height: 100%;
  background: linear-gradient(180deg, transparent, rgba(26, 115, 232, 0.3), transparent);
}

.login-box {
  width: 100%;
  max-width: 380px;
}

.login-header {
  margin-bottom: 40px;
}

.login-header h2 {
  font-size: 26px;
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.login-header p {
  color: var(--text-muted);
  font-size: 14px;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

/* Form Styles */
.login-form {
  width: 100%;
}

/* Remove default Element Plus form item margins */
.login-form :deep(.el-form-item) {
  margin-bottom: 22px !important;
}

.login-form :deep(.el-form-item__content) {
  display: block !important;
  line-height: normal !important;
  margin-left: 0 !important;
  width: 100% !important;
}

.form-label {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-muted);
  margin-bottom: 8px;
  letter-spacing: 0.5px;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.input-wrapper {
  position: relative;
  width: 100%;
}

.input-icon {
  position: absolute;
  left: 14px;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--text-muted);
  pointer-events: none;
  transition: color 0.2s;
  z-index: 2;
}

.input-wrapper:focus-within .input-icon {
  color: var(--primary);
}

/* Override Element Plus input styles */
.login-form :deep(.el-autocomplete),
.login-form :deep(.el-input) {
  width: 100%;
  display: block;
}

/* Reset Element Plus wrapper */
.login-form :deep(.el-input__wrapper) {
  width: 100% !important;
  padding: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  border-radius: 0 !important;
}

/* Style the actual input */
.login-form :deep(.el-autocomplete__inner),
.login-form :deep(.el-input__inner) {
  width: 100% !important;
  padding: 14px 14px 14px 44px !important;
  background: var(--input-bg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 12px !important;
  color: var(--text) !important;
  font-size: 15px !important;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif !important;
  outline: none !important;
  transition: all 0.25s ease !important;
  height: auto !important;
  min-height: auto !important;
  line-height: 1.5 !important;
  box-sizing: border-box !important;
  display: block !important;
}

.login-form :deep(.el-autocomplete__inner)::placeholder,
.login-form :deep(.el-input__inner)::placeholder {
  color: #5f6368 !important;
}

.login-form :deep(.el-autocomplete__inner):focus,
.login-form :deep(.el-input__inner):focus {
  border-color: var(--primary) !important;
  background: rgba(26, 115, 232, 0.06) !important;
  box-shadow: 0 0 0 3px rgba(26, 115, 232, 0.1) !important;
}

/* Remove Element Plus default icons */
.login-form :deep(.el-input__prefix),
.login-form :deep(.el-input__suffix),
.login-form :deep(.el-input__prefix-inner),
.login-form :deep(.el-input__suffix-inner) {
  display: none !important;
}

/* Custom password toggle button */
.password-toggle-btn {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
  transition: color 0.2s;
  z-index: 2;
}

.password-toggle-btn:hover {
  color: var(--text);
}

.password-toggle-btn svg {
  width: 18px;
  height: 18px;
}

/* Clear button */
.clear-btn {
  position: absolute;
  right: 40px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
  transition: color 0.2s;
  z-index: 2;
}

.clear-btn:hover {
  color: var(--text);
}

.clear-btn svg {
  width: 16px;
  height: 16px;
}

/* Form options */
.form-options {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 28px;
  margin-top: 0;
}

.remember-me {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 13px;
  color: var(--text-muted);
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.remember-me input[type='checkbox'] {
  display: none;
}

.checkmark {
  width: 18px;
  height: 18px;
  border: 1.5px solid var(--border);
  border-radius: 5px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  flex-shrink: 0;
}

.checkmark svg {
  width: 12px;
  height: 12px;
  opacity: 0;
  transform: scale(0.5);
  transition: all 0.2s;
  fill: white;
}

.remember-me input:checked + .checkmark {
  background: var(--primary);
  border-color: var(--primary);
}

.remember-me input:checked + .checkmark svg {
  opacity: 1;
  transform: scale(1);
}

.forgot-link {
  font-size: 13px;
  color: var(--primary);
  text-decoration: none;
  transition: opacity 0.2s;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

.forgot-link:hover {
  opacity: 0.8;
}

/* Submit button */
.login-form :deep(.submit-item) {
  margin-bottom: 0 !important;
}

.login-form :deep(.submit-item .el-form-item__content) {
  margin-top: 0 !important;
  line-height: normal !important;
}

.login-btn {
  width: 100%;
  padding: 15px !important;
  background: linear-gradient(135deg, var(--primary) 0%, #4285f4 100%) !important;
  border: none !important;
  border-radius: 12px !important;
  color: white !important;
  font-size: 16px !important;
  font-weight: 600 !important;
  cursor: pointer !important;
  transition: all 0.3s ease !important;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif !important;
  letter-spacing: 2px !important;
  position: relative !important;
  overflow: hidden !important;
  height: auto !important;
  min-height: auto !important;
  line-height: normal !important;
}

.login-btn::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(255, 255, 255, 0.1), transparent);
  opacity: 0;
  transition: opacity 0.3s;
}

.login-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 24px rgba(26, 115, 232, 0.35);
}

.login-btn:hover::before {
  opacity: 1;
}

.login-btn:active {
  transform: translateY(0);
}

.login-btn :deep(.el-icon) {
  display: none;
}

/* Divider */
.divider {
  display: flex;
  align-items: center;
  margin: 28px 0;
  gap: 16px;
}

.divider::before,
.divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border);
}

.divider span {
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

/* SSO buttons */
.sso-options {
  display: flex;
  gap: 12px;
}

.sso-btn {
  flex: 1;
  padding: 12px;
  background: var(--input-bg);
  border: 1px solid var(--border);
  border-radius: 10px;
  color: var(--text-muted);
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.sso-btn:hover {
  border-color: rgba(255, 255, 255, 0.15);
  background: rgba(255, 255, 255, 0.06);
  color: var(--text);
}

.sso-btn svg {
  width: 16px;
  height: 16px;
}

/* Footer */
.login-footer {
  margin-top: 40px;
  text-align: center;
  font-size: 12px;
  color: #5f6368;
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', sans-serif;
}

/* Particles */
.particles {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.particle {
  position: absolute;
  width: 2px;
  height: 2px;
  background: rgba(26, 115, 232, 0.4);
  border-radius: 50%;
  animation: drift linear infinite;
}

@keyframes drift {
  0% {
    transform: translateY(100vh) translateX(0);
    opacity: 0;
  }
  10% {
    opacity: 1;
  }
  90% {
    opacity: 1;
  }
  100% {
    transform: translateY(-10vh) translateX(30px);
    opacity: 0;
  }
}

/* Responsive */
@media (max-width: 960px) {
  .brand-panel {
    display: none;
  }

  .login-panel {
    width: 100%;
    max-width: 480px;
    border-left: none;
  }

  .login-panel::before {
    display: none;
  }
}

@media (max-width: 480px) {
  .login-panel {
    padding: 24px;
  }

  .login-box {
    max-width: 100%;
  }
}

/* Remove Element Plus default styles that conflict */
.login-form :deep(.el-form-item__content) {
  display: block !important;
}

.login-form :deep(.el-form-item__error) {
  padding-top: 4px;
  font-size: 12px;
}
</style>
