/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： Router 路由配置
 * @date： 2025-12-05 16:27:55
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime：  2025-12-05 16:27:55
 */
import { ssoLogin } from '@/api/interface.js'
import AlarmPage from '@/components/alarmManage/AlarmPage.vue'
import LoginPage from '@/components/LoginPage.vue'
import NotFound from '@/components/NotFound.vue'
import { useAuthStore } from '@/stores/authInfoStore.js'
import { generateUUIDModern } from '@/utils/publicData.js'
import { createRouter, createWebHistory } from 'vue-router'

// 创建路由实例
const router = createRouter({
  // 使用HTML5历史模式
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
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
 * @param to - 目标路由
 * @param from - 来源路由
 * @param next - 下一步操作
 */
router.beforeEach(async (to, from, next) => {
  // 检查URL中是否有code参数
  const urlParams = new URLSearchParams(to.fullPath.split('?')[1])
  const code = urlParams.get('code')
  if (code) {
    // 处理SSO回调逻辑
    // 例如交换code获取token
    try {
      const username = await ssoLogin(code)
      // 检查用户名是否有效
      if (!username || username === '') {
        console.error('单点登录失败：获取用户信息失败')
        return
      }
      const authStore = useAuthStore()
      // const router = useRouter()
      // 存储登录状态到 pinia 仓库
      authStore.loginInfoStorage(username, "success")
      // 登录成功后，设置标记表示这是登录重定向
      sessionStorage.setItem('isLoginRedirect', 'true')
      // 获取原始的 redirect_uri 或默认重定向到告警管理页面
      const redirectUri = urlParams.get('redirect_uri') || '/alarmManagement'
      // 移除查询参数，只保留路径部分
      const redirectPath = new URL(redirectUri, window.location.origin).pathname
      next({
        path: redirectPath,
        replace: true
      })
    }
    catch (error) {
      console.error('单点登录登录失败', error)
    }
  }
  else {
    // 获取store实例
    const authStore = useAuthStore()
    // 检查目标路由是否需要认证
    if (to.meta.requiresAuth) {
      // 如果用户已认证，允许访问
      if (authStore.isAuthenticated) {
        next()
      } else {
        // 清除登录信息
        authStore.logoutInfoClear()
        console.log('来源站点',document.referrer)
        console.log('当前站点',window.location.origin)
        console.log('uuid',generateUUIDModern(),typeof generateUUIDModern())
        // 检测是否从第三方站点跳转
        const isExternalReferrer = document.referrer &&
          !document.referrer.startsWith(window.location.origin)
        if (isExternalReferrer) {
          console.log('从第三方站点跳转')
          const baseUrl = 'https://100.18.16.180/next/auth/authorization'
          const authorizationUrl = 'http://100.18.16.180/api/v1/api_gateway/sso_server/oauth2/access_token'
          const accessType = 'online'
          const clientId = '0a9d7aa7c8c8595c2d44'
          const redirectUri = 'http://100.18.16.225:8080/alarmManagement/alarmItem'
          const state = generateUUIDModern()
          const scope = 'read'
          const responseType = 'code'
          // 从第三方站点跳转，重定向到第三方授权页面
          window.location.href = `${baseUrl}?authorization_url=${authorizationUrl}&redirect_uri=${redirectUri}&access_type=${accessType}&state=${state}&client_id=${clientId}&scope=${scope}&response_type=${responseType}`
        } else {
          // 未认证用户重定向到登录页
          next({
            name: 'LoginPage',
            // 保存重定向路径
            query: { redirect: to.fullPath },
          })
        }
      }
    } else {
      // 不需要认证的路由直接放行
      next()
    }
  }


})
// 导出默认路由配置
// 使用 ES6 的 export default 语法导出 router 对象
// 这样在其他文件中可以通过 import 语句引入这个路由配置
export default router
