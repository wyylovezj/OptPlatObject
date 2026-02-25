function convertAlarmDataToTreeOptimized(alarmData) {
  // 辅助函数：比较严重级别
/**
 * 比较两个问题严重程度的函数
 * @param {Object} a - 第一个问题对象，包含严重程度属性
 * @param {Object} b - 第二个问题对象，包含严重程度属性
 * @returns {number} 返回比较结果的正值、负值或0
 *                 如果b的严重程度高于a，返回正值
 *                 如果a的严重程度高于b，返回负值
 *                 如果严重程度相同，返回0
 */
  function compareSeverity(a, b) {
    // 定义严重程度顺序映射，将文本转换为数值进行比较
    const severityOrder = { "严重": 2, "一般": 1 };
    // 通过比较数值来确定严重程度的顺序
    // 使用b减a是为了实现降序排列（严重程度高的排在前面）
    return severityOrder[b] - severityOrder[a];
  }

  // 辅助函数：比较时间
  function compareTime(a, b) {
    return new Date(b) - new Date(a);
  }

  // 辅助函数：排序子节点
  function sortChildren(children) {
    return children.sort((a, b) => {
      // 先按严重级别排序（严重 > 一般）
      const severityDiff = compareSeverity(b.severity, a.severity);
      if (severityDiff !== 0) return severityDiff;

      // 再按发生时间降序排序（最近的在前面）
      return compareTime(b.occurrenceTime, a.occurrenceTime);
    });
  }

  // 辅助函数：获取最高级别
  function getHighestSeverity(children) {
    return children.reduce((highest, alarm) => {
      if (alarm.severity === "严重") return "严重";
      if (highest === "严重") return "严重";
      return alarm.severity;
    }, "一般");
  }

  // 辅助函数：获取最近时间
  function getLatestTime(children) {
    return children.reduce((latest, alarm) => {
      const currentTime = new Date(alarm.occurrenceTime);
      const latestTime = new Date(latest);
      return currentTime > latestTime ? alarm.occurrenceTime : latest;
    }, "1970-01-01 00:00:00");
  }

  // 辅助函数：获取统计信息
  function getStatistics(children) {
    return {
      total: children.length,
      critical: children.filter((a) => a.severity === '严重').length,
      normal: children.filter((a) => a.severity === '一般').length,
      processed: children.filter((a) => a.state === '已分派' || a.state === '已关闭').length,
      unprocessed: children.filter((a) => a.state === '未处理').length,
    }
  }

  // 按主机名分组（不区分大小写）
  const hostGroups = {};

  alarmData.forEach(alarm => {
    // 处理主机名（统一转换为小写进行分组，但保留原始大小写显示）
    const originalHostName = alarm.object || "";
    const normalizedHostName = originalHostName.toLowerCase();

    if (!hostGroups[normalizedHostName]) {
      hostGroups[normalizedHostName] = {
        originalName: originalHostName,
        children: []
      };
    }

    // 添加到对应主机的子节点
    hostGroups[normalizedHostName].children.push({
      ...alarm,
      originalObject: alarm.object, // 保留原始大小写
      isHostNode: false
    });
  });

  // 构建树形结构
  const treeData = [];

  Object.keys(hostGroups).forEach(normalizedHostName => {
    const { originalName, children } = hostGroups[normalizedHostName];

    if (children.length === 0) return;

    // 排序子节点
    const sortedChildren = sortChildren(children);

    // 获取统计信息
    const stats = getStatistics(sortedChildren);

    // 构建根节点
    const rootNode = {
      event_id: `host-${normalizedHostName || 'empty'}`,
      severity: getHighestSeverity(sortedChildren),
      state: "/",
      system_name: "/",
      category: "/",
      object: originalName || "/",
      ip: "/",
      alarm_details: `主机: ${originalName || "未知"} (总计: ${stats.total}, 严重: ${stats.critical}, 一般: ${stats.normal})`,
      occurrenceTime: getLatestTime(sortedChildren),
      processingTime: "/",
      children: sortedChildren,
      isHostNode: true,
      statistics: stats
    };

    treeData.push(rootNode);
  });

  // 对根节点按主机名排序（空主机名放在最后）
  treeData.sort((a, b) => {
    if (a.object === "/" && b.object !== "/") return 1;
    if (a.object !== "/" && b.object === "/") return -1;
    if (a.object === "/" && b.object === "/") return 0;
    return a.object.localeCompare(b.object);
  });

  return treeData;
}

// 使用优化版本
const optimizedTreeData = convertAlarmDataToTreeOptimized(alarmData);
console.log("优化后的树形数据:", optimizedTreeData);
console.log("数据结构示例:", optimizedTreeData[0]);
