import AlarmPage from '@/components/AlarmPage.vue'
import LoginPage from '@/components/LoginPage.vue'
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth.js'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'LoginPage',
      components: {
        LoginPage: LoginPage
      },
      meta: {
        requiresAuth: false
      }
    },
    {
      path: '/',
      name: 'IndexPage',
      redirect: () => {
        // 该函数接收目标路由作为参数
        return { path: '/alarmManagement/' }
      },
      meta: {
        requiresAuth: true,
      }
    },
    {
      path: '/alarmManagement',
      name: 'AlarmPage',
      redirect: to => {
        // 该函数接收目标路由作为参数
        return to.path.replace(/$/, 'alarmItem')
      },
      meta: {
        requiresAuth: true,
        title: '告警管理',
        breadcrumb: '告警管理'
      },
      children: [{
        path: 'alarmItem',
        name: 'AlarmItemPage',
        component: AlarmPage,
        meta: {
          requiresAuth: true,
          title: '告警',
          breadcrumb: '告警'
        }
      }]
    }

  ]
})
// 全局前置守卫
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  console.log("全局前置守卫")
  console.log(localStorage.getItem('user'))
  console.log(localStorage.getItem('token'))
  // 检查目标路由是否需要认证
  if (to.meta.requiresAuth) {
    // 如果用户已认证，允许访问
    console.log(to.meta.requiresAuth)
    if (authStore.isAuthenticated) {
      next()
    } else {
      // 未认证用户重定向到登录页
      next({
        name: 'Login',
        // 保存重定向路径
        query: { redirect: to.fullPath }
      })
    }
  } else {
    // 不需要认证的路由直接放行
    next()
  }
})
export default router
