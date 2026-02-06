import { ref } from 'vue'

export function useDragAndDrop() {
  const draggedComponent = ref(null)
  const dropTarget = ref(null)

  // 开始拖拽
  const handleDragStart = (event, component) => {
    draggedComponent.value = component
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', component.id)
  }

  // 拖拽经过
  const handleDragOver = (event, targetComponent) => {
    event.preventDefault()
    dropTarget.value = targetComponent
  }

  // 放置
  const handleDrop = (event, formConfig) => {
    event.preventDefault()

    if (!draggedComponent.value || !dropTarget.value) return

    const fromIndex = formConfig.findIndex(comp => comp.id === draggedComponent.value.id)
    const toIndex = formConfig.findIndex(comp => comp.id === dropTarget.value.id)

    if (fromIndex !== -1 && toIndex !== -1 && fromIndex !== toIndex) {
      // 移动组件位置
      const [movedItem] = formConfig.splice(fromIndex, 1)
      formConfig.splice(toIndex, 0, movedItem)
    }

    // 重置状态
    draggedComponent.value = null
    dropTarget.value = null
  }

  // 拖拽结束
  const handleDragEnd = () => {
    draggedComponent.value = null
    dropTarget.value = null
  }

  return {
    draggedComponent,
    dropTarget,
    handleDragStart,
    handleDragOver,
    handleDrop,
    handleDragEnd
  }
}
