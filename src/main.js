import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import 'element-plus/dist/index.css'


// 创建Vue应用实例
const app = createApp(App)
// 创建Pinia实例，用于状态管理
const pinia = createPinia()
// 将Pinia插件注册到应用中
app.use(pinia)
// 注册路由插件，用于页面导航
app.use(router)
// 注册Element Plus UI组件库，并配置中文语言包
app.use(ElementPlus, {
  locale: zhCn,
})
// 挂载应用到DOM中id为'app'的元素上
app.mount('#app')
