/*
 Navicat Premium Dump SQL

 Source Server         : 告警平台
 Source Server Type    : MySQL
 Source Server Version : 80046 (8.0.46)
 Source Host           : localhost:3306
 Source Schema         : rbac

 Target Server Type    : MySQL
 Target Server Version : 80046 (8.0.46)
 File Encoding         : 65001

 Date: 10/06/2026 17:30:35
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for daily_handover
-- ----------------------------
DROP TABLE IF EXISTS `daily_handover`;
CREATE TABLE `daily_handover`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_date` date NOT NULL COMMENT '交接日期 YYYY-MM-DD',
  `shift_type` tinyint NOT NULL DEFAULT 1 COMMENT '班次类型 1-白班 2-夜班',
  `duty_person` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '值班人（如 ecc-白班）',
  `remark1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT '备注1（与日期同行的附加备注）',
  `created_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT '创建人',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT '最后更新人',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_date_shift`(`handover_date` ASC, `shift_type` ASC) USING BTREE,
  INDEX `idx_handover_date`(`handover_date` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 33 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '日常工作交接主表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of daily_handover
-- ----------------------------

-- ----------------------------
-- Table structure for daily_handover_field_config
-- ----------------------------
DROP TABLE IF EXISTS `daily_handover_field_config`;
CREATE TABLE `daily_handover_field_config`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `field_key` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '字段标识（英文，如 inspection）',
  `field_label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '列显示名称（如 机房巡检）',
  `is_visible` tinyint NOT NULL DEFAULT 1 COMMENT '是否显示 1-显示 0-隐藏',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '列排序号',
  `is_system` tinyint NOT NULL DEFAULT 0 COMMENT '是否系统预置 1-预置 0-自定义',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `field_key`(`field_key` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 14 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '交接字段列配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of daily_handover_field_config
-- ----------------------------

-- ----------------------------
-- Table structure for daily_handover_item
-- ----------------------------
DROP TABLE IF EXISTS `daily_handover_item`;
CREATE TABLE `daily_handover_item`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` bigint UNSIGNED NOT NULL COMMENT '关联主表 daily_handover.id',
  `field_key` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '字段标识（如 inspection, autoPhone）',
  `field_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '字段文本值（status=other 时使用）',
  `field_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '状态：空=未填写, 正常, 其他',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '字段排序号（冗余，便于查询）',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_handover_field`(`handover_id` ASC, `field_key` ASC) USING BTREE,
  INDEX `idx_handover_id`(`handover_id` ASC) USING BTREE,
  CONSTRAINT `fk_item_handover` FOREIGN KEY (`handover_id`) REFERENCES `daily_handover` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 597 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '交接明细表（动态字段值）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of daily_handover_item
-- ----------------------------

-- ----------------------------
-- Table structure for duty_handover
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover`;
CREATE TABLE `duty_handover`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `handover_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '交接班记录ID',
  `personnel_type` tinyint NOT NULL COMMENT '值班类型：1-ECC, 2-系统运维, 3-网络运维, 4-甲方PM',
  `shift_type` tinyint NOT NULL COMMENT '交班类型：1-白班→夜班, 2-夜班→白班, 3-同组交接',
  `from_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '交班人user_code',
  `to_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '接班人user_code',
  `handover_time` datetime NULL DEFAULT NULL COMMENT '交接时间',
  `status` tinyint NOT NULL DEFAULT 0 COMMENT '状态：0-待确认, 1-已完成',
  `confirm_time` datetime NULL DEFAULT NULL COMMENT '确认时间',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_handover_id`(`handover_id` ASC) USING BTREE,
  INDEX `idx_schedule_date`(`schedule_date` ASC) USING BTREE,
  INDEX `idx_personnel_type`(`personnel_type` ASC) USING BTREE,
  INDEX `idx_shift_type`(`shift_type` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_from_personnel`(`from_personnel_id` ASC) USING BTREE,
  INDEX `idx_to_personnel`(`to_personnel_id` ASC) USING BTREE,
  CONSTRAINT `fk_handover_from_personnel` FOREIGN KEY (`from_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_handover_to_personnel` FOREIGN KEY (`to_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班记录表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_handover
-- ----------------------------
INSERT INTO `duty_handover` VALUES (1, '2026-06-10', '52501139-1e1d-49aa-9f9d-9ec3bf4c1473', 1, 1, 'wangwu', 'lisi', '2026-06-10 14:20:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-10 14:20:52', '2026-06-10 14:20:51', 0);
INSERT INTO `duty_handover` VALUES (2, '2026-06-10', '54d27eb7-e934-485a-8cec-1647e4d0acad', 1, 2, 'lisi', 'wangwu', '2026-06-10 14:40:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-10 14:40:28', '2026-06-10 14:40:27', 0);

-- ----------------------------
-- Table structure for duty_handover_attachment
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_attachment`;
CREATE TABLE `duty_handover_attachment`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '交接班记录ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件原始名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `file_size` bigint NULL DEFAULT NULL COMMENT '文件大小(字节)',
  `content_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件类型(MIME)',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_handover_id`(`handover_id` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE,
  CONSTRAINT `fk_attachment_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班附件表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_handover_attachment
-- ----------------------------

-- ----------------------------
-- Table structure for duty_handover_system_status
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_system_status`;
CREATE TABLE `duty_handover_system_status`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '状态描述',
  `level` tinyint NOT NULL DEFAULT 0 COMMENT '级别：0-普通, 1-重要，2-严重\'',
  `is_danger` tinyint NOT NULL DEFAULT 0 COMMENT '是否危险：0-否, 1-是',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_handover_id`(`handover_id` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE,
  CONSTRAINT `fk_status_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班系统运行状态表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_handover_system_status
-- ----------------------------

-- ----------------------------
-- Table structure for duty_handover_todo_item
-- ----------------------------
DROP TABLE IF EXISTS `duty_handover_todo_item`;
CREATE TABLE `duty_handover_todo_item`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事项描述',
  `level` tinyint NOT NULL DEFAULT 0 COMMENT '级别：0-普通, 1-重要，2-严重\'',
  `is_danger` tinyint NOT NULL DEFAULT 0 COMMENT '是否危险：0-否, 1-是',
  `is_completed` tinyint NOT NULL DEFAULT 0 COMMENT '是否完成：0-未完成, 1-已完成',
  `completed_time` datetime NULL DEFAULT NULL COMMENT '完成时间',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_handover_id`(`handover_id` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE,
  INDEX `idx_is_completed`(`is_completed` ASC) USING BTREE,
  CONSTRAINT `fk_todo_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 11 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '交接班待跟进事项表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_handover_todo_item
-- ----------------------------

-- ----------------------------
-- Table structure for duty_log
-- ----------------------------
DROP TABLE IF EXISTS `duty_log`;
CREATE TABLE `duty_log`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务唯一标识(UUID)',
  `log_date` date NOT NULL COMMENT '日志日期',
  `log_time` time NOT NULL COMMENT '日志时间(HH:mm)',
  `dot_class` tinyint NOT NULL DEFAULT 0 COMMENT '事件级别：0-普通, 1-正常(success), 2-警告(warn), 3-危险(danger)',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事件标题',
  `description` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '详细描述',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `status` tinyint NOT NULL DEFAULT 0 COMMENT '状态：0-草稿, 1-已保存, 2-已确认',
  `confirm_time` datetime NULL DEFAULT NULL COMMENT '确认时间',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号（按时间升序）',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_log_id`(`log_id` ASC) USING BTREE,
  INDEX `idx_log_date`(`log_date` ASC) USING BTREE,
  INDEX `idx_dot_class`(`dot_class` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '值班日志表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_log
-- ----------------------------

-- ----------------------------
-- Table structure for duty_log_attachment
-- ----------------------------
DROP TABLE IF EXISTS `duty_log_attachment`;
CREATE TABLE `duty_log_attachment`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '日志业务ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件原始名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `file_size` bigint NULL DEFAULT NULL COMMENT '文件大小(字节)',
  `content_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件类型(MIME)',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_log_id`(`log_id` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE,
  CONSTRAINT `fk_attachment_log` FOREIGN KEY (`log_id`) REFERENCES `duty_log` (`log_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '日志附件表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_log_attachment
-- ----------------------------

-- ----------------------------
-- Table structure for duty_log_tag
-- ----------------------------
DROP TABLE IF EXISTS `duty_log_tag`;
CREATE TABLE `duty_log_tag`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '日志业务ID',
  `tag_text` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标签文本',
  `tag_class` tinyint NOT NULL DEFAULT 1 COMMENT '标签颜色：5-危急, 4-严重, 3-恢复正常, 2-日常记录, 1-普通信息',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_log_id`(`log_id` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE,
  CONSTRAINT `fk_tag_log` FOREIGN KEY (`log_id`) REFERENCES `duty_log` (`log_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '日志标签表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_log_tag
-- ----------------------------

-- ----------------------------
-- Table structure for duty_note
-- ----------------------------
DROP TABLE IF EXISTS `duty_note`;
CREATE TABLE `duty_note`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `note_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务唯一标识',
  `note_date` date NOT NULL COMMENT '备注日期',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '备注内容',
  `level` tinyint NOT NULL DEFAULT 0 COMMENT '严重级别：0-普通, 1-重要, 2-严重',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `deleted` tinyint NOT NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_note_id`(`note_id` ASC) USING BTREE,
  INDEX `idx_note_date`(`note_date` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '值班备注表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_note
-- ----------------------------

-- ----------------------------
-- Table structure for duty_personnel
-- ----------------------------
DROP TABLE IF EXISTS `duty_personnel`;
CREATE TABLE `duty_personnel`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `personnel_type` tinyint NOT NULL COMMENT '人员类型：1-ECC, 2-系统运维, 3-网络运维, 4-甲方PM,5-运维服务台',
  `user_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '域账号',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '姓名',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '手机号',
  `batch` int UNSIGNED NULL DEFAULT NULL COMMENT '批处理人员标志，0-非批处理人员；1-批处理人员',
  `department` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '所属部门',
  `employee_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '工号',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0-禁用, 1-启用',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序号',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `created_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '创建人',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '更新人',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_code`(`user_code` ASC) USING BTREE,
  INDEX `idx_personnel_type`(`personnel_type` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_name`(`name` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 18 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '值班人员信息表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_personnel
-- ----------------------------
INSERT INTO `duty_personnel` VALUES (1, 1, 'zhangsan', '张三', '13614286839', 0, NULL, NULL, 1, 1, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:39');
INSERT INTO `duty_personnel` VALUES (2, 1, 'lisi', '李四', '13614258164', 0, NULL, NULL, 1, 2, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:45');
INSERT INTO `duty_personnel` VALUES (3, 1, 'wangwu', '王五', '13614280002', 0, NULL, NULL, 1, 3, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:47');
INSERT INTO `duty_personnel` VALUES (4, 1, 'zhaoliu', '赵六', '13614250001', 0, NULL, NULL, 1, 4, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:49');
INSERT INTO `duty_personnel` VALUES (5, 2, 'weiyangyang', '魏阳阳', '18133677848', 0, NULL, NULL, 1, 1, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:49');
INSERT INTO `duty_personnel` VALUES (6, 2, 'qianwencai', '钱文才', '13614280324', 0, NULL, NULL, 1, 2, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:50');
INSERT INTO `duty_personnel` VALUES (7, 2, 'wangxue', '王学', '18133677848', 0, NULL, NULL, 1, 3, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:50');
INSERT INTO `duty_personnel` VALUES (8, 2, 'liuliang', '刘亮', '13614280324', 1, NULL, NULL, 1, 4, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:32:39');
INSERT INTO `duty_personnel` VALUES (9, 3, 'wangfan', '王帆', '13614203547', 1, NULL, NULL, 1, 1, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:32:44');
INSERT INTO `duty_personnel` VALUES (10, 3, 'duzeyu', '杜泽宇', '13721584965', 0, NULL, NULL, 1, 2, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:51');
INSERT INTO `duty_personnel` VALUES (11, 3, 'wangweiwei', '王维伟', '13614203547', 0, NULL, NULL, 1, 3, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:30:51');
INSERT INTO `duty_personnel` VALUES (12, 4, 'liutao', '刘涛', '13721584965', 0, NULL, NULL, 1, 1, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 13:58:23');
INSERT INTO `duty_personnel` VALUES (13, 4, 'xushimin', '徐世民', '13512215784', 0, NULL, NULL, 1, 2, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 13:58:24');
INSERT INTO `duty_personnel` VALUES (14, 4, 'wengchao', '翁超', '13954568415', 0, NULL, NULL, 1, 3, NULL, NULL, '2026-06-02 15:31:16', NULL, '2026-06-05 10:32:38');
INSERT INTO `duty_personnel` VALUES (15, 5, 'huangguan', '黄冠', '13125124545', 0, NULL, NULL, 1, 1, NULL, NULL, '2026-06-05 13:58:18', NULL, '2026-06-05 13:58:30');
INSERT INTO `duty_personnel` VALUES (16, 5, 'lilei', '李磊', '13125124545', 0, NULL, NULL, 1, 2, NULL, NULL, '2026-06-05 13:58:18', NULL, '2026-06-05 13:59:18');
INSERT INTO `duty_personnel` VALUES (17, 5, 'wangwei', '王伟', '13125124545', 0, NULL, NULL, 1, 3, NULL, NULL, '2026-06-05 13:58:18', NULL, '2026-06-05 13:59:22');

-- ----------------------------
-- Table structure for duty_schedule
-- ----------------------------
DROP TABLE IF EXISTS `duty_schedule`;
CREATE TABLE `duty_schedule`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `ecc_day_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT 'ECC白班人员ID(09:00-18:00)',
  `ecc_night_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT 'ECC夜班人员ID(18:00-09:00)',
  `sys_ops_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '系统运维人员ID(白班)',
  `net_ops_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '网络运维人员ID(白班)',
  `pm_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '甲方PM人员ID',
  `created_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '创建人',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '更新人',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_schedule_date`(`schedule_date` ASC) USING BTREE,
  INDEX `idx_ecc_day`(`ecc_day_personnel_id` ASC) USING BTREE,
  INDEX `idx_ecc_night`(`ecc_night_personnel_id` ASC) USING BTREE,
  INDEX `idx_sys_ops`(`sys_ops_personnel_id` ASC) USING BTREE,
  INDEX `idx_net_ops`(`net_ops_personnel_id` ASC) USING BTREE,
  INDEX `idx_pm`(`pm_personnel_id` ASC) USING BTREE,
  CONSTRAINT `fk_ecc_day_personnel` FOREIGN KEY (`ecc_day_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ecc_night_personnel` FOREIGN KEY (`ecc_night_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_net_ops_personnel` FOREIGN KEY (`net_ops_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_pm_personnel` FOREIGN KEY (`pm_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_sys_ops_personnel` FOREIGN KEY (`sys_ops_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB AUTO_INCREMENT = 22 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '值班排班表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of duty_schedule
-- ----------------------------
INSERT INTO `duty_schedule` VALUES (1, '2026-05-25', 'wangwu', 'lisi', 'qianwencai', 'wangweiwei', 'xushimin', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (2, '2026-05-26', 'zhaoliu', 'wangwu', 'wangxue', 'wangfan', 'wengchao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (3, '2026-05-27', 'zhangsan', 'zhaoliu', 'liuliang', 'duzeyu', 'liutao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (4, '2026-05-28', 'lisi', 'zhangsan', 'weiyangyang', 'wangweiwei', 'xushimin', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (5, '2026-05-29', 'wangwu', 'lisi', 'qianwencai', 'wangfan', 'wengchao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (6, '2026-05-30', 'zhaoliu', 'wangwu', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (7, '2026-05-31', 'zhangsan', 'zhaoliu', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (8, '2026-06-01', 'lisi', 'zhangsan', 'wangxue', 'duzeyu', 'liutao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (9, '2026-06-02', 'wangwu', 'lisi', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:44:50');
INSERT INTO `duty_schedule` VALUES (10, '2026-06-03', 'zhaoliu', 'wangwu', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:44:50');
INSERT INTO `duty_schedule` VALUES (11, '2026-06-04', 'zhangsan', 'zhaoliu', 'qianwencai', 'duzeyu', 'liutao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (12, '2026-06-05', NULL, NULL, 'wangxue', 'wangweiwei', 'xushimin', 'system', '2026-06-04 10:43:59', NULL, '2026-06-05 11:29:48');
INSERT INTO `duty_schedule` VALUES (13, '2026-06-06', 'wangwu', 'lisi', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (14, '2026-06-07', 'zhaoliu', 'wangwu', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (15, '2026-06-08', 'zhangsan', 'zhaoliu', 'liuliang', 'wangfan', 'wengchao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (16, '2026-06-09', 'lisi', 'zhangsan', 'weiyangyang', 'duzeyu', 'liutao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (17, '2026-06-10', 'wangwu', 'lisi', 'qianwencai', 'wangweiwei', 'xushimin', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (18, '2026-06-11', 'zhaoliu', 'wangwu', 'wangxue', 'wangfan', 'wengchao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (19, '2026-06-12', 'zhangsan', 'zhaoliu', 'liuliang', 'duzeyu', 'liutao', 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (20, '2026-06-13', 'lisi', 'zhangsan', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');
INSERT INTO `duty_schedule` VALUES (21, '2026-06-14', 'wangwu', 'lisi', NULL, NULL, NULL, 'system', '2026-06-04 10:43:59', NULL, '2026-06-04 10:43:59');

-- ----------------------------
-- Table structure for other_duty
-- ----------------------------
DROP TABLE IF EXISTS `other_duty`;
CREATE TABLE `other_duty`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `batch_A` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '跑批人员-A角',
  `batch_A_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '跑批人员-A角ID',
  `batch_B` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '跑批人员-B角',
  `batch_B_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '跑批人员-B角ID',
  `service_A` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-A角',
  `service_A_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-A角ID',
  `service_B` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-B角',
  `service_B_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-B角ID',
  `service_C` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-C角',
  `service_C_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '运维服务台人员-C角ID',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_schedule_date`(`schedule_date` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of other_duty
-- ----------------------------

-- ----------------------------
-- Table structure for sys_menu
-- ----------------------------
DROP TABLE IF EXISTS `sys_menu`;
CREATE TABLE `sys_menu`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '菜单 ID',
  `parent_id` bigint NULL DEFAULT 0 COMMENT '父菜单 ID（0 表示根菜单）',
  `menu_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '菜单名称',
  `menu_type` tinyint NOT NULL COMMENT '菜单类型：1-目录，2-菜单，3-按钮',
  `path` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '路由路径',
  `component` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '组件路径',
  `permission_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '权限标识（如：alarm:manage）',
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '菜单图标',
  `order_num` int NULL DEFAULT 0 COMMENT '显示顺序',
  `visible` tinyint NULL DEFAULT 1 COMMENT '是否可见：0-隐藏，1-显示',
  `keep_alive` tinyint NULL DEFAULT 0 COMMENT '是否缓存：0-不缓存，1-缓存',
  `redirect` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '重定向地址',
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '备注',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_parent_id`(`parent_id` ASC) USING BTREE,
  INDEX `idx_menu_type`(`menu_type` ASC) USING BTREE,
  INDEX `idx_visible`(`visible` ASC) USING BTREE,
  INDEX `idx_order`(`order_num` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 75 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统菜单表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of sys_menu
-- ----------------------------
INSERT INTO `sys_menu` VALUES (1, 0, '告警管理', 1, '/alarmManagement', '', 'alarm:manage', 'icon-gaojingguanli', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-03-30 17:21:57', 0);
INSERT INTO `sys_menu` VALUES (2, 1, '告警数据', 2, '/alarmManagement/alarmItem', 'components/alarmManage/AlarmPage.vue', 'alarm:view', '', 0, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-03 09:02:26', 0);
INSERT INTO `sys_menu` VALUES (3, 0, '工具管理', 1, '/toolsManagement', '', 'tool:manage', 'icon-shijianguanli', 2, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-03-30 17:21:57', 0);
INSERT INTO `sys_menu` VALUES (4, 3, '工具库', 2, '/toolsManagement/tools', 'components/toolsManage/ToolsPage.vue', 'tool:view', '', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:25', 0);
INSERT INTO `sys_menu` VALUES (5, 0, '权限管理', 1, '/permissionManagement', '', 'system:permission', 'icon-zhanghaoquanxianguanli', 5, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-05-14 15:05:10', 0);
INSERT INTO `sys_menu` VALUES (6, 5, '用户管理', 2, '/permissionManagement/userManage', 'components/permissionManage/UserManagePage.vue', 'system:user', '', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:26', 0);
INSERT INTO `sys_menu` VALUES (7, 5, '角色管理', 2, '/permissionManagement/roleManage', 'components/permissionManage/RoleManagePage.vue', 'system:role', '', 2, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:27', 0);
INSERT INTO `sys_menu` VALUES (8, 5, '菜单管理', 2, '/permissionManagement/menuManage', 'components/permissionManage/MenuManagePage.vue', 'system:menu', '', 3, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:29', 0);
INSERT INTO `sys_menu` VALUES (9, 2, '刷新', 3, '/alarmManagement/alarmItem', NULL, 'alarm:refresh', '', 1, 1, 0, NULL, NULL, '2026-04-02 14:22:57', '2026-04-03 14:17:07', 0);
INSERT INTO `sys_menu` VALUES (10, 2, '搜索', 2, '/alarmManagement/alarmItem', NULL, 'alarm:search', '', 2, 1, 0, NULL, NULL, '2026-04-02 15:09:17', '2026-04-03 14:17:09', 0);
INSERT INTO `sys_menu` VALUES (11, 2, '重置', 3, '/alarmManagement/alarmItem', NULL, 'alarm:reset', '', 0, 1, 0, NULL, NULL, '2026-04-02 16:39:36', '2026-04-03 14:17:11', 0);
INSERT INTO `sys_menu` VALUES (12, 2, '批量关闭', 2, '/alarmManagement/alarmItem', NULL, 'alarm:batchClose', '', 3, 1, 0, NULL, NULL, '2026-04-02 16:43:54', '2026-04-03 14:17:13', 0);
INSERT INTO `sys_menu` VALUES (13, 2, '告警聚合', 3, '/alarmManagement/alarmItem', NULL, 'alarm:aggregation', '', 4, 1, 0, NULL, NULL, '2026-04-02 16:52:17', '2026-04-03 14:17:17', 0);
INSERT INTO `sys_menu` VALUES (14, 4, '工单导出', 3, '/toolsManagement/tools', NULL, 'tool:orderExport', '', 0, 1, 0, NULL, NULL, '2026-04-02 16:54:25', '2026-04-03 14:17:19', 0);
INSERT INTO `sys_menu` VALUES (15, 4, '域账号管理', 3, '/toolsManagement/tools', NULL, 'tool:accountUnlock', '', 1, 1, 0, NULL, NULL, '2026-04-02 16:55:20', '2026-04-17 08:46:09', 0);
INSERT INTO `sys_menu` VALUES (16, 4, '脚本下发', 3, '/toolsManagement/tools', NULL, 'tool:scriptDistribution', '', 2, 1, 0, NULL, NULL, '2026-04-02 16:57:03', '2026-04-03 14:17:24', 0);
INSERT INTO `sys_menu` VALUES (17, 4, '堡垒机账号解锁', 3, '/toolsManagement/tools', NULL, 'tool:tokenUnlock', '', 3, 1, 0, NULL, NULL, '2026-04-02 16:58:17', '2026-04-03 14:17:27', 0);
INSERT INTO `sys_menu` VALUES (18, 6, '分配角色', 3, '/permissionManagement/userManage', NULL, 'system:assignRoles', '', 0, 1, 0, NULL, NULL, '2026-04-02 17:00:13', '2026-04-03 14:17:31', 0);
INSERT INTO `sys_menu` VALUES (19, 6, '启用', 3, '/permissionManagement/userManage', NULL, 'system:enableUser', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:02:21', '2026-04-03 14:17:36', 0);
INSERT INTO `sys_menu` VALUES (20, 6, '禁用', 3, '/permissionManagement/userManage', NULL, 'system:disabledUser', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:02:58', '2026-04-03 14:17:41', 0);
INSERT INTO `sys_menu` VALUES (21, 7, '分配菜单', 3, '/permissionManagement/roleManage', NULL, 'system:assignMenus', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:04:36', '2026-04-03 14:41:07', 0);
INSERT INTO `sys_menu` VALUES (22, 7, '编辑', 3, '/permissionManagement/roleManage', NULL, 'system:editRoles', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:05:37', '2026-04-03 14:41:17', 0);
INSERT INTO `sys_menu` VALUES (23, 7, '启用', 3, '/permissionManagement/roleManage', NULL, 'system:enableRoles', '', 3, 1, 0, NULL, NULL, '2026-04-02 17:06:02', '2026-04-03 14:41:20', 0);
INSERT INTO `sys_menu` VALUES (24, 7, '禁用', 3, '/permissionManagement/roleManage', NULL, 'system:diabledRoles', '', 4, 1, 0, NULL, NULL, '2026-04-02 17:06:19', '2026-04-03 14:41:24', 0);
INSERT INTO `sys_menu` VALUES (25, 8, '新增根菜单', 3, '/permissionManagement/menuManage', NULL, 'system:createRoot', '', 0, 1, 0, NULL, NULL, '2026-04-02 17:10:13', '2026-04-03 14:17:50', 0);
INSERT INTO `sys_menu` VALUES (26, 8, '新增子项', 3, '/permissionManagement/menuManage', NULL, 'system:createChildNode', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:11:05', '2026-04-03 14:17:57', 0);
INSERT INTO `sys_menu` VALUES (27, 8, '编辑', 3, '/permissionManagement/menuManage', NULL, 'system:editMenus', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:11:34', '2026-04-03 14:17:58', 0);
INSERT INTO `sys_menu` VALUES (28, 8, '删除', 3, '/permissionManagement/menuManage', NULL, 'system:deleteMenus', '', 3, 1, 0, NULL, NULL, '2026-04-02 17:12:01', '2026-04-03 14:18:03', 0);
INSERT INTO `sys_menu` VALUES (29, 7, '新增角色', 3, '/permissionManagement/roleManage', NULL, 'alarm:createRole', '', 0, 1, 0, NULL, NULL, '2026-04-03 14:40:58', '2026-04-03 14:41:47', 0);
INSERT INTO `sys_menu` VALUES (39, 2, '导出', 3, '/alarmManagement/alarmItem', NULL, 'alarm:export', '', 5, 1, 0, NULL, NULL, '2026-04-09 16:54:12', '2026-04-09 16:54:12', 0);
INSERT INTO `sys_menu` VALUES (40, 4, '邮箱账号管理', 3, '/toolsManagement/tools', NULL, 'tool:emailManage', '', 4, 1, 0, NULL, NULL, '2026-04-14 13:58:25', '2026-04-14 13:58:25', 0);
INSERT INTO `sys_menu` VALUES (41, 0, '首页', 1, '/home', 'components/homePage/HomePage.vue', 'home:homePage', 'icon-shouye1', 0, 1, 0, NULL, NULL, '2026-04-21 17:40:46', '2026-04-21 18:00:13', 0);
INSERT INTO `sys_menu` VALUES (42, 4, '主机密码修改', 3, '/toolsManagement/tools', NULL, 'tool:passwordModify', '', 5, 1, 0, NULL, NULL, '2026-05-11 18:10:18', '2026-05-11 18:10:18', 0);
INSERT INTO `sys_menu` VALUES (43, 0, '值班管理', 1, '/dutyManagement', NULL, 'duty:manage', 'icon-zhibanguanli', 3, 1, 0, NULL, NULL, '2026-05-14 14:58:40', '2026-05-20 14:52:06', 0);
INSERT INTO `sys_menu` VALUES (44, 43, '值班管理', 2, '/dutyManagement/dutyCalendar', NULL, 'duty:calendar', '', 0, 1, 0, NULL, NULL, '2026-05-20 14:54:17', '2026-05-21 14:17:45', 0);
INSERT INTO `sys_menu` VALUES (45, 43, '值班人员', 2, '/dutyManagement/dutyUser', NULL, 'duty:user', '', 1, 1, 0, NULL, NULL, '2026-05-20 14:54:51', '2026-05-21 14:17:38', 1);
INSERT INTO `sys_menu` VALUES (46, 43, '交接班记录', 2, '/dutyManagement/dutyHandover', NULL, 'duty:handover', '', 2, 1, 0, NULL, NULL, '2026-05-21 13:57:52', '2026-05-21 13:57:52', 0);
INSERT INTO `sys_menu` VALUES (47, 43, '值班日志', 2, '/dutyManagement/dutyLog', NULL, 'duty:log', '', 4, 1, 0, NULL, NULL, '2026-05-21 13:58:19', '2026-06-10 14:49:26', 0);
INSERT INTO `sys_menu` VALUES (48, 44, '新增排班', 3, '/a', NULL, '', '', 1, 1, 0, NULL, NULL, '2026-05-26 11:01:49', '2026-05-26 11:02:08', 1);
INSERT INTO `sys_menu` VALUES (49, 44, '新增排版', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:create', '', 1, 1, 0, NULL, NULL, '2026-06-01 16:37:53', '2026-06-01 16:37:53', 0);
INSERT INTO `sys_menu` VALUES (50, 44, '导出排班', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:export', '', 0, 1, 0, NULL, NULL, '2026-06-01 16:38:14', '2026-06-01 16:38:14', 0);
INSERT INTO `sys_menu` VALUES (51, 44, '调班', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:edit', '', 2, 1, 0, NULL, NULL, '2026-06-01 16:38:56', '2026-06-01 16:38:56', 0);
INSERT INTO `sys_menu` VALUES (52, 46, '导出记录', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverExport', '', 0, 1, 0, NULL, NULL, '2026-06-01 16:56:24', '2026-06-01 16:56:24', 0);
INSERT INTO `sys_menu` VALUES (53, 46, '新建交接班', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverCreate', '', 1, 1, 0, NULL, NULL, '2026-06-01 16:57:02', '2026-06-01 16:57:02', 0);
INSERT INTO `sys_menu` VALUES (54, 46, '重置', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverReset', '', 2, 1, 0, NULL, NULL, '2026-06-01 16:57:22', '2026-06-01 16:57:22', 0);
INSERT INTO `sys_menu` VALUES (55, 46, '查询', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverSearch', '', 3, 1, 0, NULL, NULL, '2026-06-01 16:57:44', '2026-06-01 16:57:44', 0);
INSERT INTO `sys_menu` VALUES (56, 46, '编辑（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverEdit', '', 4, 1, 0, NULL, NULL, '2026-06-01 16:58:56', '2026-06-01 16:58:56', 0);
INSERT INTO `sys_menu` VALUES (57, 46, '保存（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverSave', '', 5, 1, 0, NULL, NULL, '2026-06-01 17:01:06', '2026-06-01 17:01:06', 0);
INSERT INTO `sys_menu` VALUES (58, 46, '确认交接（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverConfirm', '', 6, 1, 0, NULL, NULL, '2026-06-01 17:01:33', '2026-06-01 17:01:33', 0);
INSERT INTO `sys_menu` VALUES (59, 46, '删除（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverDelete', '', 7, 1, 0, NULL, NULL, '2026-06-01 17:03:21', '2026-06-01 17:03:21', 0);
INSERT INTO `sys_menu` VALUES (60, 47, '导出日志', 3, '/dutyManagement/dutyLog', NULL, 'duty:logExport', '', 0, 1, 0, NULL, NULL, '2026-06-01 17:14:51', '2026-06-01 17:14:51', 0);
INSERT INTO `sys_menu` VALUES (61, 47, '新增日志', 3, '/dutyManagement/dutyLog', NULL, 'duty:logCreate', '', 1, 1, 0, NULL, NULL, '2026-06-01 17:15:13', '2026-06-01 17:15:13', 0);
INSERT INTO `sys_menu` VALUES (62, 47, '保存（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logSave', '', 2, 1, 0, NULL, NULL, '2026-06-01 17:15:50', '2026-06-01 17:15:50', 0);
INSERT INTO `sys_menu` VALUES (63, 47, '编辑（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logEdit', '', 3, 1, 0, NULL, NULL, '2026-06-01 17:16:08', '2026-06-01 17:16:08', 0);
INSERT INTO `sys_menu` VALUES (64, 47, '确认（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logConfirm', '', 4, 1, 0, NULL, NULL, '2026-06-01 17:16:36', '2026-06-01 17:16:36', 0);
INSERT INTO `sys_menu` VALUES (65, 47, '删除（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logDelete', '', 5, 1, 0, NULL, NULL, '2026-06-01 17:17:10', '2026-06-01 17:17:10', 0);
INSERT INTO `sys_menu` VALUES (66, 47, '保存（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteSave', '', 6, 1, 0, NULL, NULL, '2026-06-01 17:17:47', '2026-06-01 17:17:47', 0);
INSERT INTO `sys_menu` VALUES (67, 47, '编辑（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteEdit', '', 7, 1, 0, NULL, NULL, '2026-06-01 17:17:58', '2026-06-01 17:17:58', 0);
INSERT INTO `sys_menu` VALUES (68, 47, '新增（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteAdd', '', 8, 1, 0, NULL, NULL, '2026-06-03 09:54:33', '2026-06-03 09:54:33', 0);
INSERT INTO `sys_menu` VALUES (69, 43, '日常工作交接', 3, '/dutyManagement/dailyHandover', NULL, 'duty:dailyHandover', '', 3, 1, 0, NULL, NULL, '2026-06-08 15:56:40', '2026-06-08 16:00:34', 0);
INSERT INTO `sys_menu` VALUES (70, 69, '保存', 3, '/dutyManagement/dailyHandover', NULL, 'daily:save', '', 0, 1, 0, NULL, NULL, '2026-06-10 14:55:59', '2026-06-10 14:55:59', 0);
INSERT INTO `sys_menu` VALUES (71, 69, '加载', 3, '/dutyManagement/dailyHandover', NULL, 'daily:load', '', 1, 1, 0, NULL, NULL, '2026-06-10 14:56:10', '2026-06-10 14:56:10', 0);
INSERT INTO `sys_menu` VALUES (72, 69, '导出', 3, '/dutyManagement/dailyHandover', NULL, 'daily:export', '', 2, 1, 0, NULL, NULL, '2026-06-10 14:56:19', '2026-06-10 14:56:19', 0);
INSERT INTO `sys_menu` VALUES (73, 69, '新增行', 3, '/dutyManagement/dailyHandover', NULL, 'daily:addRow', '', 3, 1, 0, NULL, NULL, '2026-06-10 14:56:35', '2026-06-10 14:56:35', 0);
INSERT INTO `sys_menu` VALUES (74, 69, '列管理', 3, '/dutyManagement/dailyHandover', NULL, 'daily:columnManage', '', 4, 1, 0, NULL, NULL, '2026-06-10 14:56:47', '2026-06-10 14:56:47', 0);

-- ----------------------------
-- Table structure for sys_role
-- ----------------------------
DROP TABLE IF EXISTS `sys_role`;
CREATE TABLE `sys_role`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '角色 ID',
  `role_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色编码（如：admin, viewer）',
  `role_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '角色描述',
  `role_type` tinyint NULL DEFAULT 1 COMMENT '角色类型：1-系统角色，2-自定义角色',
  `data_scope` tinyint NULL DEFAULT 1 COMMENT '数据范围：1-全部数据，2-本部门及以下，3-本部门，4-仅本人',
  `status` tinyint NULL DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序号',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_role_code`(`role_code` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_sort`(`sort_order` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 29 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统角色表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of sys_role
-- ----------------------------
INSERT INTO `sys_role` VALUES (1, 'admin', '超级管理员', '系统所有权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-04-29 11:06:12', 0);
INSERT INTO `sys_role` VALUES (2, 'normal', '普通用户', '普通用户权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-05-19 17:43:36', 0);

-- ----------------------------
-- Table structure for sys_role_menu
-- ----------------------------
DROP TABLE IF EXISTS `sys_role_menu`;
CREATE TABLE `sys_role_menu`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键 ID',
  `role_id` bigint NOT NULL COMMENT '角色 ID',
  `menu_id` bigint NOT NULL COMMENT '菜单 ID',
  `deleted` smallint NOT NULL COMMENT '删除标志：0-未删除，1-已删除',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id` DESC) USING BTREE,
  UNIQUE INDEX `uk_role_menu`(`role_id` ASC, `menu_id` ASC) USING BTREE,
  INDEX `idx_menu_id`(`menu_id` ASC) USING BTREE,
  CONSTRAINT `fk_role_menu_menu` FOREIGN KEY (`menu_id`) REFERENCES `sys_menu` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_role_menu_role` FOREIGN KEY (`role_id`) REFERENCES `sys_role` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 463 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '角色菜单关联表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of sys_role_menu
-- ----------------------------
INSERT INTO `sys_role_menu` VALUES (462, 1, 74, 0, '2026-06-10 14:56:52');
INSERT INTO `sys_role_menu` VALUES (461, 1, 73, 0, '2026-06-10 14:56:52');
INSERT INTO `sys_role_menu` VALUES (460, 1, 72, 0, '2026-06-10 14:56:52');
INSERT INTO `sys_role_menu` VALUES (459, 1, 71, 0, '2026-06-10 14:56:52');
INSERT INTO `sys_role_menu` VALUES (458, 1, 70, 0, '2026-06-10 14:56:52');
INSERT INTO `sys_role_menu` VALUES (457, 1, 69, 0, '2026-06-08 16:01:09');
INSERT INTO `sys_role_menu` VALUES (456, 1, 68, 0, '2026-06-03 10:05:08');
INSERT INTO `sys_role_menu` VALUES (455, 2, 63, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (454, 2, 62, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (453, 2, 61, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (452, 2, 60, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (451, 2, 67, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (450, 2, 66, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (449, 2, 65, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (448, 2, 64, 0, '2026-06-01 17:18:16');
INSERT INTO `sys_role_menu` VALUES (447, 1, 63, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (446, 1, 62, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (445, 1, 61, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (444, 1, 60, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (443, 1, 59, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (442, 1, 58, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (441, 1, 57, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (440, 1, 56, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (439, 1, 55, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (438, 1, 54, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (437, 1, 53, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (436, 1, 52, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (435, 1, 67, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (434, 1, 66, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (433, 1, 65, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (432, 1, 64, 0, '2026-06-01 17:18:07');
INSERT INTO `sys_role_menu` VALUES (431, 2, 59, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (430, 2, 58, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (429, 2, 57, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (428, 2, 56, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (427, 2, 55, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (426, 2, 54, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (425, 2, 53, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (424, 2, 52, 0, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (423, 2, 51, 1, '2026-06-01 17:03:59');
INSERT INTO `sys_role_menu` VALUES (422, 2, 50, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (421, 2, 49, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (420, 2, 47, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (419, 2, 46, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (418, 2, 44, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (417, 2, 43, 0, '2026-06-01 16:42:41');
INSERT INTO `sys_role_menu` VALUES (416, 1, 51, 0, '2026-06-01 16:39:01');
INSERT INTO `sys_role_menu` VALUES (415, 1, 50, 0, '2026-06-01 16:39:01');
INSERT INTO `sys_role_menu` VALUES (414, 1, 49, 0, '2026-06-01 16:39:01');
INSERT INTO `sys_role_menu` VALUES (413, 2, 17, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (412, 2, 16, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (411, 2, 15, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (410, 2, 14, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (409, 2, 4, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (408, 2, 3, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (407, 2, 41, 0, '2026-05-26 09:46:57');
INSERT INTO `sys_role_menu` VALUES (406, 1, 47, 0, '2026-05-21 13:58:32');
INSERT INTO `sys_role_menu` VALUES (405, 1, 46, 0, '2026-05-21 13:58:32');
INSERT INTO `sys_role_menu` VALUES (404, 1, 45, 1, '2026-05-20 14:55:12');
INSERT INTO `sys_role_menu` VALUES (403, 1, 44, 0, '2026-05-20 14:55:12');
INSERT INTO `sys_role_menu` VALUES (402, 1, 43, 0, '2026-05-14 15:04:51');
INSERT INTO `sys_role_menu` VALUES (401, 2, 42, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (400, 1, 42, 0, '2026-05-11 18:12:16');
INSERT INTO `sys_role_menu` VALUES (399, 1, 41, 0, '2026-04-21 17:42:15');
INSERT INTO `sys_role_menu` VALUES (397, 2, 40, 1, '2026-05-26 10:45:40');
INSERT INTO `sys_role_menu` VALUES (396, 1, 40, 0, '2026-04-14 14:02:07');
INSERT INTO `sys_role_menu` VALUES (390, 2, 39, 0, '2026-04-09 16:55:27');
INSERT INTO `sys_role_menu` VALUES (389, 1, 39, 0, '2026-04-09 16:55:17');
INSERT INTO `sys_role_menu` VALUES (388, 1, 29, 0, '2026-04-03 14:42:02');
INSERT INTO `sys_role_menu` VALUES (387, 2, 13, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (386, 2, 12, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (385, 2, 11, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (384, 2, 10, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (383, 2, 9, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (382, 2, 2, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (381, 2, 1, 0, '2026-04-03 15:38:30');
INSERT INTO `sys_role_menu` VALUES (28, 1, 28, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (27, 1, 27, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (26, 1, 26, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (25, 1, 25, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (24, 1, 24, 0, '2026-04-03 14:39:28');
INSERT INTO `sys_role_menu` VALUES (23, 1, 23, 0, '2026-04-03 14:39:28');
INSERT INTO `sys_role_menu` VALUES (22, 1, 22, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (21, 1, 21, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (20, 1, 20, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (19, 1, 19, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (18, 1, 18, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (17, 1, 17, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (16, 1, 16, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (15, 1, 15, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (14, 1, 14, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (13, 1, 13, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (12, 1, 12, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (11, 1, 11, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (10, 1, 10, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (9, 1, 9, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (8, 1, 8, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (7, 1, 7, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (6, 1, 6, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (5, 1, 5, 0, '2026-04-03 11:34:56');
INSERT INTO `sys_role_menu` VALUES (4, 1, 4, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (3, 1, 3, 0, '2026-04-03 15:14:17');
INSERT INTO `sys_role_menu` VALUES (2, 1, 2, 0, '2026-04-03 15:38:24');
INSERT INTO `sys_role_menu` VALUES (1, 1, 1, 0, '2026-04-03 15:38:24');

-- ----------------------------
-- Table structure for sys_user
-- ----------------------------
DROP TABLE IF EXISTS `sys_user`;
CREATE TABLE `sys_user`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户 ID',
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '用户名（登录账号）',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '密码（加密存储）',
  `nickname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '昵称',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '手机号',
  `status` tinyint NULL DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
  `user_type` tinyint NULL DEFAULT 1 COMMENT '用户类型：1-普通用户，2-管理员',
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '头像 URL',
  `last_login_time` datetime NULL DEFAULT NULL COMMENT '最后登录时间',
  `last_login_ip` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '最后登录 IP',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NULL DEFAULT 0 COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_username`(`username` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_user_type`(`user_type` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统用户表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of sys_user
-- ----------------------------
INSERT INTO `sys_user` VALUES (1, 'weiyangyang', '', '魏阳阳', NULL, NULL, 1, 1, NULL, NULL, NULL, '2026-03-30 17:27:10', '2026-04-03 18:00:45', 0);

-- ----------------------------
-- Table structure for sys_user_role
-- ----------------------------
DROP TABLE IF EXISTS `sys_user_role`;
CREATE TABLE `sys_user_role`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键 ID',
  `user_id` bigint NOT NULL COMMENT '用户 ID',
  `role_id` bigint NOT NULL COMMENT '角色 ID',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_role`(`user_id` ASC, `role_id` ASC) USING BTREE,
  INDEX `idx_role_id`(`role_id` ASC) USING BTREE,
  CONSTRAINT `fk_user_role_role` FOREIGN KEY (`role_id`) REFERENCES `sys_role` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_role_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户角色关联表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of sys_user_role
-- ----------------------------
INSERT INTO `sys_user_role` VALUES (1, 1, 1, '2026-06-03 16:36:39');
INSERT INTO `sys_user_role` VALUES (2, 1, 2, '2026-06-03 16:36:39');

SET FOREIGN_KEY_CHECKS = 1;
