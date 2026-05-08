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
import { generateUUIDModern,isSsoLogin } from '@/utils/publicData.js'
import { createRouter, createWebHistory } from 'vue-router'
import ToolsPage from '@/components/toolsManage/ToolsPage.vue'
import { usePermissionStore } from '@/stores/permissionStore.js'
import HomePage from '@/components/homePage/HomePage.vue'


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
        return { path: '/home' }
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
     * 首页路由
     * @path /home
     * @name HomePage
     * @requiresAuth true - 不需要认证
     */
    {
      path: '/home',
      name: 'HomePage',
      component: HomePage,
      meta: {
        requiresAuth: true,
        title: '首页',
        breadcrumb: '首页',
        permission: 'home:homePage',
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
        permission: 'alarm:manage',
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
            permission: 'alarm:view',
          },
        },
      ],
    },
    /**
     * 事件管理模块路由
     * @path /toolsManagement
     * @name toolsManagement
     * @requiresAuth true - 需要认证
     * @title 登录
     * @breadcrumb 登录
     */
    {
      path: '/toolsManagement',
      name: 'toolsManagement',
      redirect: (to) => {
        // 该函数接收目标路由作为参数
        return to.path + '/tools'
      },
      meta: {
        requiresAuth: true,
        title: '工具管理',
        breadcrumb: '工具管理',
        permission: 'tool:manage',
      },
      children: [
        /**
         * 事件导出页面路由
         * @path tools
         * @name tools
         * @requiresAuth true - 需要认证
         * @title 告警
         * @breadcrumb 告警
         */
        {
          path: 'tools',
          name: 'tools',
          component: ToolsPage,
          meta: {
            requiresAuth: true,
            title: '工具库',
            breadcrumb: '工具库',
            permission: 'tool:view',
          },
        },
      ],
    },
    /**
     * 权限管理模块路由（新增）
     * @path /permissionManagement
     * @name PermissionManagement
     * @requiresAuth true - 需要认证
     * @title 权限管理
     * @breadcrumb 权限管理
     * @permission system:permission - 需要系统权限管理权限
     * @roles admin - 仅管理员可访问
     */
    {
      path: '/permissionManagement',
      name: 'PermissionManagement',
      meta: {
        requiresAuth: true,
        title: '权限管理',
        breadcrumb: '权限管理',
        permission: 'system:permission',
        roles: ['admin']
      },
      children: [
        {
          path: 'userManage',
          name: 'UserManage',
          component: () => import('@/components/permissionManage/UserManagePage.vue'),
          meta: {
            requiresAuth: true,
            title: '用户管理',
            breadcrumb: '用户管理',
            permission: 'system:user'
          }
        },
        {
          path: 'roleManage',
          name: 'RoleManage',
          component: () => import('@/components/permissionManage/RoleManagePage.vue'),
          meta: {
            requiresAuth: true,
            title: '角色管理',
            breadcrumb: '角色管理',
            permission: 'system:role'
          }
        },
        {
          path: 'menuManage',
          name: 'MenuManage',
          component: () => import('@/components/permissionManage/MenuManagePage.vue'),
          meta: {
            requiresAuth: true,
            title: '菜单管理',
            breadcrumb: '菜单管理',
            permission: 'system:menu'
          }
        }
      ]
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
 * 检查路由权限
 * @param {Object} to - 目标路由
 * @param {Object} permissionStore - 权限 store 实例
 * @returns {boolean} - 是否有权限访问
 */
const checkRoutePermission = (to, permissionStore) => {
  const meta = to.meta

  // 如果没有设置权限要求，则允许访问
  if (!meta.permission && !meta.roles) {
    return true
  }

  // 检查角色权限
  if (meta.roles && meta.roles.length > 0) {
    const hasRole = meta.roles.some(role => permissionStore.hasRole(role))
    if (!hasRole) {
      return false
    }
  }

  // 检查权限码
  if (meta.permission) {
    const hasPermission = permissionStore.hasPermission(meta.permission)
    if (!hasPermission) {
      return false
    }
  }

  return true
}
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
  // 获取store实例
  const authStore = useAuthStore()
  const permissionStore = usePermissionStore()
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
      // const router = useRouter()
      // SSO登录
      isSsoLogin.value = true
      // 存储登录状态到 pinia 仓库
      authStore.loginInfoStorage(username, "success")
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
    // 检查目标路由是否需要认证
    if (to.meta.requiresAuth) {
      // 如果用户已认证，允许访问
      if (authStore.isAuthenticated) {
        // 修复关键问题：移除异步 setTimeout，改为同步判断
        // 如果权限码为空且用户存在，说明是页面刷新，需要等待权限加载
        if (!permissionStore.permissionCodes.length && authStore.user) {
          // 检查是否正在加载权限
          if (authStore.isLoadingPermissions) {
            // 正在加载中，直接放行，让当前路由继续
            // 等权限加载完成后，用户点击菜单或手动刷新即可正常访问
            console.log('权限正在加载中，暂时允许访问（开发环境）')
            next()
            return
          } else if (!authStore.permissionsLoaded) {
            // 还未开始加载权限，触发加载
            console.log('检测到已登录用户，开始加载权限...')
            authStore.loadUserPermissions(authStore.user)
              .catch(error => {
                console.error('权限加载失败，清除登录状态', error)
                authStore.logoutInfoClear()
                next({ name: 'LoginPage', query: { redirect: to.fullPath } })
              })
            // 在权限加载完成前，暂时允许访问
            console.log('权限加载中，暂时允许访问')
            next()
            return
          }
        }
        if (checkRoutePermission(to, permissionStore)) {
          next()
        } else {
          // 无权限访问，重定向到 403 页面或首页
          console.warn('无权限访问:', to.path)
          next({
            name: 'NotFound',
            replace: true
          })
        }
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
          const redirectUri = 'https://100.18.16.225:8080/alarmManagement/alarmItem'
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
