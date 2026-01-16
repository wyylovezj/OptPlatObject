/**
 * @file alarmSpeakStore.js
 * @description 报警语音播报的Pinia store
 */
import { defineStore } from 'pinia'
import { ref } from 'vue'
export const textToSpeakStore = defineStore('Text', () => {
  // 定义存储告警数据的数组
  const text = ref([])
  // 添加告警数据到列表（去重）
  const addAlarmIfNotExists = (alarmData) => {
    // 检查是否已存在相同的事件ID
    const exists = text.value.some(item => item.event_id === alarmData.event_id)
    if (!exists) {
      text.value.push(alarmData)
    }
  }
  // 清除列表中发生时间在2分钟以前的数据
  const clearAlarms = () => {
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000) // 2分钟前的时间戳
    text.value = text.value.filter(item => {
      // 如果没有 occurrenceTime 字段，则保留该项
      if (!item.occurrenceTime) {
        return true
      }
      // 检查发生时间是否在2分钟以内
      const itemTime = new Date(item.occurrenceTime)
      return itemTime > twoMinutesAgo
    })
  }
  return {
    addAlarmIfNotExists,
    clearAlarms,
  }
})
