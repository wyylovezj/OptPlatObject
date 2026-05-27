-- ----------------------------
-- Table structure for duty_handover（交接班记录主表）
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover`;
CREATE TABLE `duty_handover` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `personnel_type` tinyint NOT NULL COMMENT '值班类型：1-ECC, 2-系统运维, 3-网络运维, 4-甲方PM',
  `shift_type` tinyint NOT NULL COMMENT '交班类型：1-白班→夜班, 2-夜班→白班, 3-同组交接',
  `from_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '交班人user_code',
  `to_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '接班人user_code',
  `handover_time` datetime DEFAULT NULL COMMENT '交接时间',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '状态：0-待确认, 1-已完成',
  `confirm_time` datetime DEFAULT NULL COMMENT '确认时间',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '备注',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_schedule_date` (`schedule_date`) USING BTREE,
  KEY `idx_personnel_type` (`personnel_type`) USING BTREE,
  KEY `idx_shift_type` (`shift_type`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_from_personnel` (`from_personnel_id`) USING BTREE,
  KEY `idx_to_personnel` (`to_personnel_id`) USING BTREE,
  CONSTRAINT `fk_handover_from_personnel` FOREIGN KEY (`from_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_handover_to_personnel` FOREIGN KEY (`to_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for duty_handover_system_status（交接班系统运行状态子表）
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_system_status`;
CREATE TABLE `duty_handover_system_status` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` bigint NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '状态描述',
  `is_warn` tinyint NOT NULL DEFAULT '0' COMMENT '是否警告：0-否, 1-是',
  `is_danger` tinyint NOT NULL DEFAULT '0' COMMENT '是否危险：0-否, 1-是',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_status_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班系统运行状态表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for duty_handover_todo_item（交接班待跟进事项子表）
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_todo_item`;
CREATE TABLE `duty_handover_todo_item` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` bigint NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事项描述',
  `is_warn` tinyint NOT NULL DEFAULT '0' COMMENT '是否警告：0-否, 1-是',
  `is_danger` tinyint NOT NULL DEFAULT '0' COMMENT '是否危险：0-否, 1-是',
  `is_completed` tinyint NOT NULL DEFAULT '0' COMMENT '是否完成：0-未完成, 1-已完成',
  `completed_time` datetime DEFAULT NULL COMMENT '完成时间',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  KEY `idx_is_completed` (`is_completed`) USING BTREE,
  CONSTRAINT `fk_todo_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班待跟进事项表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for duty_handover_attachment（交接班附件表）
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_attachment`;
CREATE TABLE `duty_handover_attachment` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` bigint NOT NULL COMMENT '交接班记录ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件原始名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `file_size` bigint DEFAULT NULL COMMENT '文件大小(字节)',
  `content_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '文件类型(MIME)',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_attachment_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班附件表' ROW_FORMAT = Dynamic;
