<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const searchQuery = ref('')

// 生成星星样式
const stars = ref([])

// 初始化星星
const initStars = () => {
  const count = 150
  for (let i = 0; i < count; i++) {
    stars.value.push({
      size: Math.random() * 3,
      left: Math.random() * 100,
      top: Math.random() * 100,
      opacity: Math.random() * 0.8 + 0.2,
      animationDelay: Math.random() * 5
    })
  }
}

// 星星样式计算
const starStyle = (star) => {
  return {
    width: `${star.size}px`,
    height: `${star.size}px`,
    left: `${star.left}%`,
    top: `${star.top}%`,
    opacity: star.opacity,
    animationDelay: `${star.animationDelay}s`
  }
}

// 导航方法
const goHome = () => {
  router.push({ name: 'Home' })
}

const goBack = () => {
  router.go(-1)
}

const performSearch = () => {
  if (searchQuery.value.trim()) {
    // 在实际应用中，这里可以调用搜索API或导航到搜索结果页
    alert(`搜索: ${searchQuery.value}`)
    searchQuery.value = ''
  }
}

// 初始化星星
onMounted(() => {
  initStars()
})
</script>

<template>
  <div class="not-found-container">
    <div class="error-content">
      <div class="error-number">
        <span>4</span>
        <div class="planet">
          <div class="crater"></div>
          <div class="crater"></div>
          <div class="crater"></div>
        </div>
        <span>4</span>
      </div>

      <h1 class="error-title">页面未找到</h1>

      <p class="error-message">
        您访问的页面可能已被移除、重命名或暂时不可用。
      </p>

      <div class="action-buttons">
        <button class="home-button" @click="goHome">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M11.47 3.84a.75.75 0 011.06 0l8.69 8.69a.75.75 0 101.06-1.06l-8.689-8.69a2.25 2.25 0 00-3.182 0l-8.69 8.69a.75.75 0 001.061 1.06l8.69-8.69z" />
            <path d="M12 5.432l8.159 8.159c.03.03.06.058.091.086v6.198c0 1.035-.84 1.875-1.875 1.875H15a.75.75 0 01-.75-.75v-4.5a.75.75 0 00-.75-.75h-3a.75.75 0 00-.75.75V21a.75.75 0 01-.75.75H5.625a1.875 1.875 0 01-1.875-1.875v-6.198a2.29 2.29 0 00.091-.086L12 5.43z" />
          </svg>
          返回首页
        </button>

        <button class="back-button" @click="goBack">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path fill-rule="evenodd" d="M9.53 2.47a.75.75 0 010 1.06L5.81 7.25H21a.75.75 0 010 1.5H5.81l3.72 3.72a.75.75 0 11-1.06 1.06l-5-5a.75.75 0 010-1.06l5-5a.75.75 0 011.06 0z" clip-rule="evenodd" />
          </svg>
          返回上一页
        </button>
      </div>

      <div class="search-box">
        <input
          type="text"
          placeholder="搜索您需要的内容..."
          v-model="searchQuery"
          @keyup.enter="performSearch"
        >
        <button @click="performSearch">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path fill-rule="evenodd" d="M10.5 3.75a6.75 6.75 0 100 13.5 6.75 6.75 0 000-13.5zM2.25 10.5a8.25 8.25 0 1114.59 5.28l4.69 4.69a.75.75 0 11-1.06 1.06l-4.69-4.69A8.25 8.25 0 012.25 10.5z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
    </div>

    <div class="astronaut">
      <div class="helmet">
        <div class="visor"></div>
      </div>
      <div class="body">
        <div class="arm left"></div>
        <div class="arm right"></div>
      </div>
    </div>

    <div class="stars">
      <div v-for="(star, index) in stars" :key="index" class="star" :style="starStyle(star)"></div>
    </div>
  </div>
</template>

<style scoped>
.not-found-container {
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #1a2a6c, #b21f1f, #1a2a6c);
  background-size: 400% 400%;
  animation: gradientBG 15s ease infinite;
  overflow: hidden;
  padding: 2rem;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  color: white;
}

@keyframes gradientBG {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

.error-content {
  text-align: center;
  z-index: 10;
  max-width: 600px;
  padding: 2rem;
  background: rgba(0, 0, 0, 0.3);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

.error-number {
  display: flex;
  justify-content: center;
  align-items: center;
  font-size: 10rem;
  font-weight: 800;
  margin-bottom: 1rem;
  position: relative;
}

.error-number span {
  display: inline-block;
  text-shadow: 0 5px 15px rgba(0, 0, 0, 0.3);
}

.planet {
  position: relative;
  width: 120px;
  height: 120px;
  background: linear-gradient(135deg, #ff9d6c, #ff6b6b);
  border-radius: 50%;
  margin: 0 1rem;
  box-shadow: 0 0 30px rgba(255, 107, 107, 0.5);
  animation: float 6s ease-in-out infinite;
}

@keyframes float {
  0% { transform: translateY(0px); }
  50% { transform: translateY(-20px); }
  100% { transform: translateY(0px); }
}

.crater {
  position: absolute;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 50%;
}

.crater:nth-child(1) {
  width: 25px;
  height: 25px;
  top: 20px;
  left: 30px;
}

.crater:nth-child(2) {
  width: 15px;
  height: 15px;
  top: 50px;
  right: 25px;
}

.crater:nth-child(3) {
  width: 35px;
  height: 35px;
  bottom: 20px;
  left: 40px;
}

.error-title {
  font-size: 2.5rem;
  margin-bottom: 1rem;
  text-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
}

.error-message {
  font-size: 1.2rem;
  margin-bottom: 2rem;
  line-height: 1.6;
  max-width: 500px;
}

.action-buttons {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-bottom: 2rem;
  flex-wrap: wrap;
}

.home-button, .back-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.8rem 1.5rem;
  font-size: 1rem;
  font-weight: 600;
  border: none;
  border-radius: 50px;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
}

.home-button {
  background: #4e54c8;
  color: white;
}

.home-button:hover {
  background: #3f43a8;
  transform: translateY(-3px);
}

.back-button {
  background: rgba(255, 255, 255, 0.15);
  color: white;
  backdrop-filter: blur(5px);
}

.back-button:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateY(-3px);
}

.home-button svg, .back-button svg {
  width: 20px;
  height: 20px;
}

.search-box {
  position: relative;
  max-width: 500px;
  margin: 0 auto;
}

.search-box input {
  width: 100%;
  padding: 1rem 1.5rem;
  padding-right: 50px;
  border: none;
  border-radius: 50px;
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(5px);
  color: white;
  font-size: 1rem;
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
  transition: all 0.3s ease;
}

.search-box input:focus {
  outline: none;
  background: rgba(255, 255, 255, 0.25);
  box-shadow: 0 5px 20px rgba(0, 0, 0, 0.2);
}

.search-box input::placeholder {
  color: rgba(255, 255, 255, 0.7);
}

.search-box button {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  background: transparent;
  border: none;
  cursor: pointer;
  color: white;
}

.search-box button svg {
  width: 24px;
  height: 24px;
}

.astronaut {
  position: absolute;
  right: 10%;
  bottom: 10%;
  width: 150px;
  height: 200px;
  z-index: 5;
  animation: floatAstronaut 8s ease-in-out infinite;
}

@keyframes floatAstronaut {
  0% { transform: translateY(0px); }
  50% { transform: translateY(-30px); }
  100% { transform: translateY(0px); }
}

.helmet {
  position: absolute;
  width: 100px;
  height: 100px;
  background: white;
  border-radius: 50%;
  top: 0;
  left: 25px;
  overflow: hidden;
}

.visor {
  position: absolute;
  width: 70px;
  height: 40px;
  background: #4e54c8;
  border-radius: 20px;
  top: 30px;
  left: 15px;
}

.body {
  position: absolute;
  width: 80px;
  height: 100px;
  background: white;
  border-radius: 40px;
  top: 80px;
  left: 35px;
}

.arm {
  position: absolute;
  width: 20px;
  height: 60px;
  background: white;
  border-radius: 10px;
  top: 90px;
}

.arm.left {
  left: 10px;
  transform: rotate(-20deg);
}

.arm.right {
  right: 10px;
  transform: rotate(20deg);
}

.stars {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}

.star {
  position: absolute;
  background: white;
  border-radius: 50%;
  animation: twinkle 3s infinite ease-in-out;
}

@keyframes twinkle {
  0% { opacity: 0.2; }
  50% { opacity: 1; }
  100% { opacity: 0.2; }
}

/* 响应式设计 */
@media (max-width: 768px) {
  .error-number {
    font-size: 8rem;
  }

  .planet {
    width: 80px;
    height: 80px;
    margin: 0 0.5rem;
  }

  .error-title {
    font-size: 2rem;
  }

  .error-message {
    font-size: 1rem;
  }

  .action-buttons {
    flex-direction: column;
    align-items: center;
  }

  .astronaut {
    display: none;
  }
}

@media (max-width: 480px) {
  .error-number {
    font-size: 6rem;
  }

  .planet {
    width: 60px;
    height: 60px;
  }

  .error-title {
    font-size: 1.8rem;
  }
}
</style>
