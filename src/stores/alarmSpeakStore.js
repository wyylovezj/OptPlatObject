/**
 * @file alarmSpeakStore.js
 * @description 报警语音播报的Pinia store
 */
import { defineStore } from 'pinia'
import { ref } from 'vue'



/**
 * @description 存储告警数据的Pinia store
 */
export const useSpeakStore = defineStore('speak', () => {
  // 语音播报队列
  const speechQueue = ref([])
  // 已播报队列
  // 从本地存储初始化已播报队列
  const alreadySpeakQueue = ref([])
  // 新增告警数目：语音播报列表 - 已播报列表
  const count = ref(0)
  // 添加未处理告警数据到列表（去重）
  const addSpeechQueue =  (alarmData) => {
    // 检查是否已存在相同的事件ID
    const exists = speechQueue.value.some(item => item.event_id === alarmData.event_id)
    if (!exists && alarmData.state === '未处理') {
      // 如果未重复，则添加数据到列表
      speechQueue.value.push(alarmData)
      // 如果未重复，则返回true
      return true
    }
    // 如果重复，则返回false
    return false
  }
  // 未处理的新告警添加到已播报队列（去重）
  const addAlreadySpeakQueue =  () => {
    speechQueue.value.forEach((alertItem) => {
      // 检查语音播报队列和已播报队列中是否存在相同事件ID
      const exists = alreadySpeakQueue.value.some(item => item === alertItem.event_id)
      if (!exists) {
        // 如果事件ID在语音播报队列且不再已播报队列，则添加数据到已播报队列
        alreadySpeakQueue.value.push(alertItem.event_id)
        // 未播报告警数 +1
        count.value++
        persistAlreadySpeakQueue()
        // 返回true
        return true
      }
      // 如果相同，则返回false
      return false
    })
  }

  // 从已播报队列去除已播报且已处理告警
  const removeAlreadySpeakQueue =  () => {
    alreadySpeakQueue.value = alreadySpeakQueue.value.filter(alertItem => {
      // 只保留仍在语音播报队列中的项目
      return speechQueue.value.some(item => item.event_id === alertItem)
    })
    persistAlreadySpeakQueue()
  }
  // 清除列表中发生时间在2分钟以前的数据
  const removeSpeechQueue =  () => {
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000) // 2分钟前的时间戳
    speechQueue.value = speechQueue.value.filter(item => {
      // 检查发生时间是否在2分钟以内
      const itemTime = new Date(item.occurrenceTime)
      return itemTime > twoMinutesAgo
    })
  }
  // 初始化已播报队列
  const initAlreadySpeakQueue = () => {
    console.log("init",localStorage.getItem('alreadySpeakQueue'))
    if (localStorage.getItem('alreadySpeakQueue') !== 'undefined' && localStorage.getItem('alreadySpeakQueue') !== null) {
      alreadySpeakQueue.value = JSON.parse(localStorage.getItem('alreadySpeakQueue'))
    }
  }
  // 持久化已播报队列
  const persistAlreadySpeakQueue = () => {
    try {
      // 保存当前值的副本
      localStorage.setItem('alreadySpeakQueue', JSON.stringify([...alreadySpeakQueue.value]))
      console.log("持久化",alreadySpeakQueue.value)
      console.log("持久化本地存储",localStorage.getItem('alreadySpeakQueue'))
      console.log('已播报列表已保存到本地存储')
    } catch (error) {
      console.error('保存已播报队列到本地存储失败:', error)
    }
  }

  return {
    speechQueue,
    alreadySpeakQueue,
    count,
    addSpeechQueue,
    removeSpeechQueue,
    addAlreadySpeakQueue,
    removeAlreadySpeakQueue,
    initAlreadySpeakQueue,
    persistAlreadySpeakQueue
  }
})
