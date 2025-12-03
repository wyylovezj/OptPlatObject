import AlarmPage from '@/components/AlarmPage.vue'
import LoginPage from '@/components/LoginPage.vue'
import NotFound from '@/components/NotFound.vue'
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/authInfoStore.js'


// 创建路由实例
const router = createRouter({
  // 使用HTML5历史模式
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    /**
     * 登录页面路由
     * @path /login
     * @name LoginPage
     * @requiresAuth false - 不需要认证
     */
    {
      path: '/login',
      name: 'LoginPage',
      components: {
        LoginPage: LoginPage,
      },
      meta: {
        requiresAuth: false,
      },
    },
    /**
     * 根路径路由
     * @path /
     * @name IndexPage
     * @redirect 重定向到告警管理页面
     * @requiresAuth true - 需要认证
     */
    {
      path: '/',
      name: 'IndexPage',
      redirect: () => {
        // 该函数接收目标路由作为参数
        return { path: '/alarmManagement' }
      },
      meta: {
        requiresAuth: true,
      },
    },
    /**
     * 告警管理模块路由
     * @path /alarmManagement
     * @name AlarmPage
     * @redirect 重定向到告警项页面
     * @requiresAuth true - 需要认证
     * @title 告警管理
     * @breadcrumb 告警管理
     */
    {
      path: '/alarmManagement',
      name: 'AlarmPage',
      redirect: (to) => {
        // 该函数接收目标路由作为参数
        return to.path + '/alarmItem'
      },
      meta: {
        requiresAuth: true,
        title: '告警管理',
        breadcrumb: '告警管理',
      },
      children: [
        /**
         * 告警项页面路由
         * @path alarmItem
         * @name AlarmItemPage
         * @requiresAuth true - 需要认证
         * @title 告警
         * @breadcrumb 告警
         */
        {
          path: 'alarmItem',
          name: 'AlarmItemPage',
          component: AlarmPage,
          meta: {
            requiresAuth: true,
            title: '告警',
            breadcrumb: '告警',
          },
        },
      ],
    },
    /**
     * 404页面路由
     * @path /:pathMatch(.*)* - 匹配所有未定义的路径
     * @name NotFound
     */
    {
      path: '/:pathMatch(.*)*', // 使用自定义的regexp来匹配所有路径
      name: 'NotFound',
      components: {
        NotFound: NotFound,
      },
    },
  ],
  strict: true, // 开启严格模式
  sensitive: true, // 路由大小写敏感
})

/**
 * 全局前置守卫
 * 用于处理路由访问权限控制
 */
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  // 检查目标路由是否需要认证
  if (to.meta.requiresAuth) {
    // 如果用户已认证，允许访问
    if (authStore.isAuthenticated) {
      next()
    } else {
      // 清除登录信息
      authStore.logoutInfoClear()
      // 未认证用户重定向到登录页
      next({
        name: 'LoginPage',
        // 保存重定向路径
        query: { redirect: to.fullPath }
      })
    }
  }
  else {
    // 不需要认证的路由直接放行
    next()
  }
})
// 导出默认路由配置
// 使用 ES6 的 export default 语法导出 router 对象
// 这样在其他文件中可以通过 import 语句引入这个路由配置
export default router
