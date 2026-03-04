/**
 * 将报警数据转换为树形结构，并进行优化处理
 * @param {Array} alarmData - 原始报警数据数组
 * @returns {Array} 返回处理后的树形结构数据
 */
export function convertAlarmDataToTreeOptimized(alarmData) {
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
    return severityOrder[a] - severityOrder[b];
  }

  // 辅助函数：比较时间
/**
 * 比较两个时间字符串的大小
 * @param {string} a - 第一个时间字符串
 * @param {string} b - 第二个时间字符串
 * @returns {number} 返回比较结果：
 *   - 如果b时间大于a时间，返回正数
 *   - 如果b时间等于a时间，返回0
 *   - 如果b时间小于a时间，返回负数
 */
  function compareTime(a, b) {
    // 将时间字符串转换为Date对象并进行减法运算
    // Date对象相减会返回两个日期之间的毫秒差
    return new Date(b) - new Date(a);
  }

  // 辅助函数：排序子节点
/**
 * 对子元素进行排序的函数
 * @param {Array} children - 需要排序的子元素数组
 * @returns {Array} 排序后的子元素数组
 */
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
/**
 * 获取子元素中最高严重级别的报警
 * @param {Array} children - 包含报警对象的数组，每个对象应有severity属性
 * @returns {string} 返回最高严重级别，可能的值为"严重"或"一般"
 */
  function getHighestSeverity(children) {
    // 使用reduce方法遍历数组，比较每个报警的严重级别
    return children.reduce((highest, alarm) => {
      // 如果当前报警级别为"严重"，直接返回"严重"
      if (alarm.severity === "严重") return "严重";
      // 如果当前最高级别已经是"严重"，保持返回"严重"
      if (highest === "严重") return "严重";
      // 否则返回当前报警的级别
      return alarm.severity;
    }, "一般"); // 初始最高级别设为"一般"
  }

  // 辅助函数：获取最近时间
/**
 * 获取一组时间中的最新时间
 * @param {Array} children - 包含时间对象的数组，每个对象应包含occurrenceTime属性
 * @returns {string} 返回最新时间的字符串表示，格式为"YYYY-MM-DD HH:mm:ss"
 */
  function getLatestTime(children) {
    // 使用reduce方法遍历数组，找出最新时间
    return children.reduce((latest, alarm) => {
      // 将当前警报的时间字符串转换为Date对象
      const currentTime = new Date(alarm.occurrenceTime);
      // 将最新时间字符串转换为Date对象
      const latestTime = new Date(latest);
      // 比较两个时间，返回较大的那个时间字符串
      return currentTime > latestTime ? alarm.occurrenceTime : latest;
    }, "1970-01-01 00:00:00"); // 初始值为1970年1月1日，确保任何有效时间都会大于这个初始值
  }

  // 辅助函数：获取统计信息
/**
 * 获取子项的统计信息
 * @param {Array} children - 需要统计的子项数组
 * @returns {Object} 返回包含统计结果的对象
 */
  function getStatistics(children) {
    // 使用函数式编程方法，通过filter方法筛选并统计不同状态的子项数量
    return {
      total: children.length, // 总子项数量
      critical: children.filter((a) => a.severity === '严重').length, // 严重级别的子项数量
      normal: children.filter((a) => a.severity === '一般').length, // 一般级别的子项数量
      processed: children.filter((a) => a.state === '已分派' || a.state === '已关闭').length, // 已处理状态的子项数量（包括已分派和已关闭）
      unprocessed: children.filter((a) => a.state === '未处理').length, // 未处理状态的子项数量
    }
  }

  // 按主机名分组（不区分大小写）
  const systemGroups = {};

  alarmData.forEach(alarm => {
    // 处理主机名（统一转换为小写进行分组，但保留原始大小写显示）
    const originalHostName = alarm.system_name || "";
    const normalizedHostName = originalHostName.toLowerCase();

    if (!systemGroups[normalizedHostName]) {
      systemGroups[normalizedHostName] = {
        originalName: originalHostName,
        children: []
      };
    }

    // 添加到对应主机的子节点
    systemGroups[normalizedHostName].children.push({
      ...alarm,
      originalObject: alarm.system_name, // 保留原始大小写
      isHostNode: false
    });
  });

  // 构建树形结构
  const treeData = [];

  Object.keys(systemGroups).forEach(normalizedHostName => {
    const { originalName, children } = systemGroups[normalizedHostName];

    if (children.length === 0) return;

    // 排序子节点
    const sortedChildren = sortChildren(children);

    // 获取统计信息
    const stats = getStatistics(sortedChildren);

    // 构建根节点
    const rootNode = {
      event_id: `聚合-${normalizedHostName || 'empty'}`,
      severity: getHighestSeverity(sortedChildren),
      state: "/",
      system_name: originalName || "/",
      category: "/",
      object: "/",
      ip: "/",
      alarm_details: `(总计: ${stats.total}, 严重: ${stats.critical}, 一般: ${stats.normal})`,
      occurrenceTime: getLatestTime(sortedChildren),
      processingTime: "/",
      hasChildren: sortedChildren.length > 0,
      // children: sortedChildren,
      isHostNode: true,
      statistics: stats
    };
    // 懒加载模式下不立即加载子节点
     // 保存子节点数据但不直接赋值
    rootNode._cachedChildren = sortedChildren;
    rootNode.children = undefined;
    treeData.push(rootNode);
  });

  // 对根节点按主机名排序（空主机名放在最后）
  treeData.sort((a, b) => {
    if (a.system_name === "/" && b.system_name !== "/") return 1;
    if (a.system_name !== "/" && b.system_name === "/") return -1;
    if (a.system_name === "/" && b.system_name === "/") return 0;
    return a.system_name.localeCompare(b.system_name);
  });

  return treeData;
}

/**
 * 懒加载子节点数据的函数
 * @param {Object} node - 根节点对象
 * @returns {Array} 子节点数组
 */
export function loadLazyChildren(node) {
  // 如果已经有缓存的子节点数据，直接返回
  if (node._cachedChildren && node._cachedChildren.length > 0) {
    // return node._cachedChildren;
    // 限制返回数量为前 50 条
    return node._cachedChildren.slice(0, 50)
  }

  // 如果没有缓存数据，返回空数组（理论上不应该发生）
  return [];
}
