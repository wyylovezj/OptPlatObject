/*
MySQL Backup
Database: rbac
Backup Time: 2026-06-16 14:38:22
*/

SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS `rbac`.`contact_exception`;
DROP TABLE IF EXISTS `rbac`.`daily_handover`;
DROP TABLE IF EXISTS `rbac`.`daily_handover_field_config`;
DROP TABLE IF EXISTS `rbac`.`daily_handover_item`;
DROP TABLE IF EXISTS `rbac`.`duty_handover`;
DROP TABLE IF EXISTS `rbac`.`duty_handover_attachment`;
DROP TABLE IF EXISTS `rbac`.`duty_handover_system_status`;
DROP TABLE IF EXISTS `rbac`.`duty_handover_todo_item`;
DROP TABLE IF EXISTS `rbac`.`duty_log`;
DROP TABLE IF EXISTS `rbac`.`duty_log_attachment`;
DROP TABLE IF EXISTS `rbac`.`duty_log_tag`;
DROP TABLE IF EXISTS `rbac`.`duty_note`;
DROP TABLE IF EXISTS `rbac`.`duty_personnel`;
DROP TABLE IF EXISTS `rbac`.`duty_schedule`;
DROP TABLE IF EXISTS `rbac`.`other_duty`;
DROP TABLE IF EXISTS `rbac`.`remote_record`;
DROP TABLE IF EXISTS `rbac`.`security_device_monitor`;
DROP TABLE IF EXISTS `rbac`.`sys_menu`;
DROP TABLE IF EXISTS `rbac`.`sys_role`;
DROP TABLE IF EXISTS `rbac`.`sys_role_menu`;
DROP TABLE IF EXISTS `rbac`.`sys_user`;
DROP TABLE IF EXISTS `rbac`.`sys_user_role`;
CREATE TABLE `contact_exception` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '序号（主键）',
  `record_date` date NOT NULL COMMENT '日期',
  `duty_person` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '当班人或负责人',
  `duty_person_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '当班人username',
  `second_contact` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '二次联系人',
  `second_contact_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '二次联系人username',
  `detail` text COLLATE utf8mb4_general_ci COMMENT '详细情况',
  `is_callback` varchar(10) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '是否回电',
  `remark` varchar(500) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '备注',
  `created_by` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '创建人',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '最后更新人',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ecc_contact_date` (`record_date`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='ECC联系异常情况';
CREATE TABLE `daily_handover` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_date` date NOT NULL COMMENT '交接日期 YYYY-MM-DD',
  `shift_type` tinyint NOT NULL DEFAULT '1' COMMENT '班次类型 1-白班 2-夜班',
  `duty_person` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '值班人（如 ecc-白班）',
  `remark1` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '备注1（与日期同行的附加备注）',
  `created_by` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建人',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '最后更新人',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_shift` (`handover_date`,`shift_type`),
  KEY `idx_handover_date` (`handover_date`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日常工作交接主表';
CREATE TABLE `daily_handover_field_config` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `field_key` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '字段标识（英文，如 inspection）',
  `field_label` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '列显示名称（如 机房巡检）',
  `is_visible` tinyint NOT NULL DEFAULT '1' COMMENT '是否显示 1-显示 0-隐藏',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '列排序号',
  `is_system` tinyint NOT NULL DEFAULT '0' COMMENT '是否系统预置 1-预置 0-自定义',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `field_key` (`field_key`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='交接字段列配置表';
CREATE TABLE `daily_handover_item` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` bigint unsigned NOT NULL COMMENT '关联主表 daily_handover.id',
  `field_key` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '字段标识（如 inspection, autoPhone）',
  `field_value` text COLLATE utf8mb4_unicode_ci COMMENT '字段文本值（status=other 时使用）',
  `field_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '状态：空=未填写, 正常, 其他',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '字段排序号（冗余，便于查询）',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_handover_field` (`handover_id`,`field_key`),
  KEY `idx_handover_id` (`handover_id`),
  CONSTRAINT `fk_item_handover` FOREIGN KEY (`handover_id`) REFERENCES `daily_handover` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=89 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='交接明细表（动态字段值）';
CREATE TABLE `duty_handover` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `handover_id` varchar(255) NOT NULL COMMENT '交接班记录ID',
  `personnel_type` tinyint NOT NULL COMMENT '值班类型：1-ECC, 2-系统运维, 3-网络运维, 4-甲方PM',
  `shift_type` tinyint NOT NULL COMMENT '交班类型：1-白班→夜班, 2-夜班→白班, 3-同组交接',
  `from_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '交班人user_code',
  `to_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '接班人user_code',
  `handover_time` datetime DEFAULT NULL COMMENT '交接时间',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '状态：0-待确认, 1-已完成',
  `confirm_time` datetime DEFAULT NULL COMMENT '确认时间',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_schedule_date` (`schedule_date`) USING BTREE,
  KEY `idx_personnel_type` (`personnel_type`) USING BTREE,
  KEY `idx_shift_type` (`shift_type`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_from_personnel` (`from_personnel_id`) USING BTREE,
  KEY `idx_to_personnel` (`to_personnel_id`) USING BTREE,
  CONSTRAINT `fk_handover_from_personnel` FOREIGN KEY (`from_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_handover_to_personnel` FOREIGN KEY (`to_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='交接班记录表';
CREATE TABLE `duty_handover_attachment` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) NOT NULL COMMENT '交接班记录ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件原始名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `file_size` bigint DEFAULT NULL COMMENT '文件大小(字节)',
  `content_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '文件类型(MIME)',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_attachment_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='交接班附件表';
CREATE TABLE `duty_handover_system_status` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '状态描述',
  `level` tinyint NOT NULL DEFAULT '0' COMMENT '级别：0-普通, 1-重要，2-严重''',
  `is_danger` tinyint NOT NULL DEFAULT '0' COMMENT '是否危险：0-否, 1-是',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_status_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='交接班系统运行状态表';
CREATE TABLE `duty_handover_todo_item` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `handover_id` varchar(255) NOT NULL COMMENT '交接班记录ID',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事项描述',
  `level` tinyint NOT NULL DEFAULT '0' COMMENT '级别：0-普通, 1-重要，2-严重''',
  `is_danger` tinyint NOT NULL DEFAULT '0' COMMENT '是否危险：0-否, 1-是',
  `is_completed` tinyint NOT NULL DEFAULT '0' COMMENT '是否完成：0-未完成, 1-已完成',
  `completed_time` datetime DEFAULT NULL COMMENT '完成时间',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_handover_id` (`handover_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  KEY `idx_is_completed` (`is_completed`) USING BTREE,
  CONSTRAINT `fk_todo_handover` FOREIGN KEY (`handover_id`) REFERENCES `duty_handover` (`handover_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='交接班待跟进事项表';
CREATE TABLE `duty_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务唯一标识(UUID)',
  `log_date` date NOT NULL COMMENT '日志日期',
  `log_time` time NOT NULL COMMENT '日志时间(HH:mm)',
  `dot_class` tinyint NOT NULL DEFAULT '0' COMMENT '事件级别：0-普通, 1-正常(success), 2-警告(warn), 3-危险(danger)',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '事件标题',
  `description` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '详细描述',
  `create_user` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '创建人中文名',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '状态：0-草稿, 1-已保存, 2-已确认',
  `confirm_time` datetime DEFAULT NULL COMMENT '确认时间',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号（按时间升序）',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_log_id` (`log_id`) USING BTREE,
  KEY `idx_log_date` (`log_date`) USING BTREE,
  KEY `idx_dot_class` (`dot_class`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='值班日志表';
CREATE TABLE `duty_log_attachment` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '日志业务ID',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件原始名称',
  `file_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件存储路径',
  `file_size` bigint DEFAULT NULL COMMENT '文件大小(字节)',
  `content_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '文件类型(MIME)',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_log_id` (`log_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_attachment_log` FOREIGN KEY (`log_id`) REFERENCES `duty_log` (`log_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='日志附件表';
CREATE TABLE `duty_log_tag` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `log_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '日志业务ID',
  `tag_text` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标签文本',
  `tag_class` tinyint NOT NULL DEFAULT '1' COMMENT '标签颜色：5-危急, 4-严重, 3-恢复正常, 2-日常记录, 1-普通信息',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_log_id` (`log_id`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE,
  CONSTRAINT `fk_tag_log` FOREIGN KEY (`log_id`) REFERENCES `duty_log` (`log_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='日志标签表';
CREATE TABLE `duty_note` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `note_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务唯一标识',
  `note_date` date NOT NULL COMMENT '备注日期',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '备注内容',
  `level` tinyint NOT NULL DEFAULT '0' COMMENT '严重级别：0-普通, 1-重要, 2-严重',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `create_user` varchar(100) NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) NOT NULL COMMENT '创建人中文名',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_note_id` (`note_id`) USING BTREE,
  KEY `idx_note_date` (`note_date`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='值班备注表';
CREATE TABLE `duty_personnel` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `personnel_type` tinyint NOT NULL COMMENT '人员类型：1-ECC, 2-系统运维, 3-网络运维, 4-甲方PM,5-运维服务台',
  `user_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '域账号',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '姓名',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '手机号',
  `service_group` int unsigned NOT NULL DEFAULT '0' COMMENT '服务台分组',
  `batch` int unsigned NOT NULL DEFAULT '0' COMMENT '批处理人员标志，0-非批处理人员；1-批处理人员',
  `department` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所属部门',
  `employee_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '工号',
  `status` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '状态：0-禁用, 1-启用',
  `group_sort_order` int unsigned NOT NULL DEFAULT '0' COMMENT '服务台各组内排序',
  `sort_order` int unsigned NOT NULL DEFAULT '0' COMMENT '排序号',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `created_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '创建人',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '更新人',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_code` (`user_code`) USING BTREE,
  KEY `idx_personnel_type` (`personnel_type`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_name` (`name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='值班人员信息表';
CREATE TABLE `duty_schedule` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `ecc_day_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ECC白班人员ID(09:00-18:00)',
  `ecc_night_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ECC夜班人员ID(18:00-09:00)',
  `sys_ops_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '系统运维人员ID(白班)',
  `net_ops_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '网络运维人员ID(白班)',
  `pm_personnel_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '甲方PM人员ID',
  `created_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '创建人',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '更新人',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_schedule_date` (`schedule_date`) USING BTREE,
  KEY `idx_ecc_day` (`ecc_day_personnel_id`) USING BTREE,
  KEY `idx_ecc_night` (`ecc_night_personnel_id`) USING BTREE,
  KEY `idx_sys_ops` (`sys_ops_personnel_id`) USING BTREE,
  KEY `idx_net_ops` (`net_ops_personnel_id`) USING BTREE,
  KEY `idx_pm` (`pm_personnel_id`) USING BTREE,
  CONSTRAINT `fk_ecc_day_personnel` FOREIGN KEY (`ecc_day_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ecc_night_personnel` FOREIGN KEY (`ecc_night_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_net_ops_personnel` FOREIGN KEY (`net_ops_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_pm_personnel` FOREIGN KEY (`pm_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_sys_ops_personnel` FOREIGN KEY (`sys_ops_personnel_id`) REFERENCES `duty_personnel` (`user_code`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='值班排班表';
CREATE TABLE `other_duty` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `schedule_date` date NOT NULL COMMENT '排班日期',
  `batch_A` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '跑批人员-A角',
  `batch_A_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '跑批人员-A角ID',
  `batch_B` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '跑批人员-B角',
  `batch_B_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '跑批人员-B角ID',
  `service_A` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-A角',
  `service_A_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-A角ID',
  `service_B` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-B角',
  `service_B_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-B角ID',
  `service_C` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-C角',
  `service_C_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '运维服务台人员-C角ID',
  `create_user` varchar(100) NOT NULL COMMENT '创建人',
  `create_user_nickname` varchar(100) NOT NULL COMMENT '创建人中文名',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_schedule_date` (`schedule_date`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
CREATE TABLE `remote_record` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '序号（主键）',
  `record_date` date NOT NULL COMMENT '日期',
  `apply_user` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '申请用户',
  `apply_user_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '申请用户username',
  `reason` varchar(500) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '使用缘由',
  `permission_type` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '添加权限类别',
  `start_time` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '开始时间',
  `end_time` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '结束时间',
  `ecc_duty_person` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT 'ECC值班人',
  `ecc_duty_person_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '' COMMENT 'ECC值班人username',
  `approver` varchar(100) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '审批人',
  `approver_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '审批人username',
  `email` varchar(200) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '邮件',
  `remark` varchar(500) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '备注',
  `created_by` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '创建人',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(50) COLLATE utf8mb4_general_ci DEFAULT '' COMMENT '最后更新人',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_moa_vpn_date` (`record_date`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='MOA及VPN权限使用记录';
CREATE TABLE `security_device_monitor` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '序号（主键）',
  `record_date` date NOT NULL COMMENT '日期',
  `alert_content` text COMMENT '告警内容',
  `ecc_duty_person` varchar(100) DEFAULT '' COMMENT 'ECC值班员',
  `ecc_duty_person_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '' COMMENT 'ECC值班员username',
  `ops_confirm_person` varchar(100) DEFAULT '' COMMENT '二线运维告警确认人',
  `ops_confirm_person_username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT '' COMMENT '二线运维告警确认人username',
  `remark` varchar(500) DEFAULT '' COMMENT '备注',
  `created_by` varchar(50) DEFAULT '' COMMENT '创建人',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` varchar(50) DEFAULT '' COMMENT '最后更新人',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_security_device_date` (`record_date`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='安全设备监控记录';
CREATE TABLE `sys_menu` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '菜单 ID',
  `parent_id` bigint DEFAULT '0' COMMENT '父菜单 ID（0 表示根菜单）',
  `menu_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '菜单名称',
  `menu_type` tinyint NOT NULL COMMENT '菜单类型：1-目录，2-菜单，3-按钮',
  `path` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '路由路径',
  `component` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '组件路径',
  `permission_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '权限标识（如：alarm:manage）',
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '菜单图标',
  `order_num` int DEFAULT '0' COMMENT '显示顺序',
  `visible` tinyint DEFAULT '1' COMMENT '是否可见：0-隐藏，1-显示',
  `keep_alive` tinyint DEFAULT '0' COMMENT '是否缓存：0-不缓存，1-缓存',
  `redirect` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '重定向地址',
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '备注',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_parent_id` (`parent_id`) USING BTREE,
  KEY `idx_menu_type` (`menu_type`) USING BTREE,
  KEY `idx_visible` (`visible`) USING BTREE,
  KEY `idx_order` (`order_num`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='系统菜单表';
CREATE TABLE `sys_role` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '角色 ID',
  `role_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色编码（如：admin, viewer）',
  `role_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '角色名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '角色描述',
  `role_type` tinyint DEFAULT '1' COMMENT '角色类型：1-系统角色，2-自定义角色',
  `data_scope` tinyint DEFAULT '1' COMMENT '数据范围：1-全部数据，2-本部门及以下，3-本部门，4-仅本人',
  `status` tinyint DEFAULT '1' COMMENT '状态：0-禁用，1-正常',
  `sort_order` int DEFAULT '0' COMMENT '排序号',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_role_code` (`role_code`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_sort` (`sort_order`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='系统角色表';
CREATE TABLE `sys_role_menu` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键 ID',
  `role_id` bigint NOT NULL COMMENT '角色 ID',
  `menu_id` bigint NOT NULL COMMENT '菜单 ID',
  `deleted` smallint NOT NULL COMMENT '删除标志：0-未删除，1-已删除',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id` DESC) USING BTREE,
  UNIQUE KEY `uk_role_menu` (`role_id`,`menu_id`) USING BTREE,
  KEY `idx_menu_id` (`menu_id`) USING BTREE,
  CONSTRAINT `fk_role_menu_menu` FOREIGN KEY (`menu_id`) REFERENCES `sys_menu` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_role_menu_role` FOREIGN KEY (`role_id`) REFERENCES `sys_role` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=485 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='角色菜单关联表';
CREATE TABLE `sys_user` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户 ID',
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '用户名（登录账号）',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '密码（加密存储）',
  `nickname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '昵称',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '手机号',
  `status` tinyint DEFAULT '1' COMMENT '状态：0-禁用，1-正常',
  `user_type` tinyint DEFAULT '1' COMMENT '用户类型：1-普通用户，2-管理员',
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '头像 URL',
  `last_login_time` datetime DEFAULT NULL COMMENT '最后登录时间',
  `last_login_ip` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL COMMENT '最后登录 IP',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint DEFAULT '0' COMMENT '删除标志：0-未删除，1-已删除',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_username` (`username`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_user_type` (`user_type`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='系统用户表';
CREATE TABLE `sys_user_role` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键 ID',
  `user_id` bigint NOT NULL COMMENT '用户 ID',
  `role_id` bigint NOT NULL COMMENT '角色 ID',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_role` (`user_id`,`role_id`) USING BTREE,
  KEY `idx_role_id` (`role_id`) USING BTREE,
  CONSTRAINT `fk_user_role_role` FOREIGN KEY (`role_id`) REFERENCES `sys_role` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_role_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='用户角色关联表';
BEGIN;
LOCK TABLES `rbac`.`contact_exception` WRITE;
DELETE FROM `rbac`.`contact_exception`;
INSERT INTO `rbac`.`contact_exception` (`id`,`record_date`,`duty_person`,`duty_person_username`,`second_contact`,`second_contact_username`,`detail`,`is_callback`,`remark`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES (1, '2026-06-16', '魏阳阳', 'weiyangyang', '钱文才', 'qianwencai', '', '是', '', '', '2026-06-16 10:21:49', '', '2026-06-16 10:35:35')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`daily_handover` WRITE;
DELETE FROM `rbac`.`daily_handover`;
INSERT INTO `rbac`.`daily_handover` (`id`,`handover_date`,`shift_type`,`duty_person`,`remark1`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES (1, '2026-06-11', 1, '赵六', '', '', '2026-06-11 09:40:23', '', '2026-06-11 09:40:23'),(2, '2026-06-11', 2, '王五', '', '', '2026-06-11 09:40:23', '', '2026-06-11 09:40:23'),(3, '2026-06-16', 1, '李润生', '', '', '2026-06-16 10:22:15', '', '2026-06-16 10:22:15'),(4, '2026-06-16', 2, '周厚奎', '', '', '2026-06-16 10:22:15', '', '2026-06-16 10:22:15')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`daily_handover_field_config` WRITE;
DELETE FROM `rbac`.`daily_handover_field_config`;
INSERT INTO `rbac`.`daily_handover_field_config` (`id`,`field_key`,`field_label`,`is_visible`,`sort_order`,`is_system`,`created_at`,`updated_at`) VALUES (1, 'inspection', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 1, 1, '2026-06-09 10:24:52', '2026-06-10 17:06:25'),(2, 'autoPhone', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 2, 1, '2026-06-09 10:24:52', '2026-06-11 09:47:52'),(3, 'netapp', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 3, 1, '2026-06-09 10:24:52', '2026-06-11 09:47:54'),(4, 'nbu', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 4, 1, '2026-06-09 10:24:52', '2026-06-11 09:47:56'),(5, 'controlM', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 5, 1, '2026-06-09 10:24:52', '2026-06-11 09:47:58'),(6, 'h3c', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 6, 1, '2026-06-09 10:24:52', '2026-06-11 09:48:00'),(7, 'newEmail', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 7, 1, '2026-06-09 10:24:52', '2026-06-11 09:48:03'),(8, 'remote', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 8, 1, '2026-06-09 10:24:52', '2026-06-11 09:48:05'),(9, 'serverPhone', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 10, 1, '2026-06-09 10:24:52', '2026-06-11 09:48:07'),(10, 'collaboration', '机房巡检发生的水电费水电费水电费是的是多少答复水电费水电费', 1, 11, 1, '2026-06-09 10:24:52', '2026-06-11 09:48:08'),(11, 'remark', '备注', 1, 12, 1, '2026-06-09 10:24:52', '2026-06-09 14:12:45')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`daily_handover_item` WRITE;
DELETE FROM `rbac`.`daily_handover_item`;
INSERT INTO `rbac`.`daily_handover_item` (`id`,`handover_id`,`field_key`,`field_value`,`field_status`,`sort_order`,`created_at`,`updated_at`) VALUES (23, 1, 'inspection', '', '正常', 1, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(24, 1, 'autoPhone', '', '正常', 2, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(25, 1, 'netapp', 'ewas aDADS ASD AASDAS DAsd aSD AS DA DSa da Da das dasd ads ad A D a ', '其他', 3, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(26, 1, 'nbu', '', '正常', 4, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(27, 1, 'controlM', '', '正常', 5, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(28, 1, 'h3c', '', '正常', 6, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(29, 1, 'newEmail', '', '正常', 7, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(30, 1, 'remote', '', '正常', 8, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(31, 1, 'serverPhone', '', '正常', 10, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(32, 1, 'collaboration', '', '正常', 11, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(33, 1, 'remark', '', '正常', 12, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(34, 2, 'inspection', '', '正常', 1, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(35, 2, 'autoPhone', '', '正常', 2, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(36, 2, 'netapp', '', '正常', 3, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(37, 2, 'nbu', '', '正常', 4, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(38, 2, 'controlM', '', '正常', 5, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(39, 2, 'h3c', '', '正常', 6, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(40, 2, 'newEmail', '', '正常', 7, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(41, 2, 'remote', '', '正常', 8, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(42, 2, 'serverPhone', '', '正常', 10, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(43, 2, 'collaboration', '', '正常', 11, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(44, 2, 'remark', '', '正常', 12, '2026-06-11 10:26:38', '2026-06-11 10:26:38'),(67, 3, 'inspection', '', '正常', 1, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(68, 3, 'autoPhone', '', '正常', 2, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(69, 3, 'netapp', '', '正常', 3, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(70, 3, 'nbu', '', '正常', 4, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(71, 3, 'controlM', '', '正常', 5, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(72, 3, 'h3c', '', '正常', 6, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(73, 3, 'newEmail', '', '正常', 7, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(74, 3, 'remote', '', '正常', 8, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(75, 3, 'serverPhone', '', '正常', 10, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(76, 3, 'collaboration', '', '正常', 11, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(77, 3, 'remark', '', '正常', 12, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(78, 4, 'inspection', '', '正常', 1, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(79, 4, 'autoPhone', '', '正常', 2, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(80, 4, 'netapp', '', '正常', 3, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(81, 4, 'nbu', '', '正常', 4, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(82, 4, 'controlM', '', '正常', 5, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(83, 4, 'h3c', '', '正常', 6, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(84, 4, 'newEmail', '', '正常', 7, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(85, 4, 'remote', '', '正常', 8, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(86, 4, 'serverPhone', '', '正常', 10, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(87, 4, 'collaboration', '', '正常', 11, '2026-06-16 10:22:32', '2026-06-16 10:22:32'),(88, 4, 'remark', '', '正常', 12, '2026-06-16 10:22:32', '2026-06-16 10:22:32')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_handover` WRITE;
DELETE FROM `rbac`.`duty_handover`;
INSERT INTO `rbac`.`duty_handover` (`id`,`schedule_date`,`handover_id`,`personnel_type`,`shift_type`,`from_personnel_id`,`to_personnel_id`,`handover_time`,`status`,`confirm_time`,`create_user`,`create_user_nickname`,`create_time`,`update_time`,`deleted`) VALUES (1, '2026-06-10', '52501139-1e1d-49aa-9f9d-9ec3bf4c1473', 1, 1, 'wangwu', 'lisi', '2026-06-10 14:20:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-10 14:20:52', '2026-06-10 14:20:51', 0),(2, '2026-06-10', '54d27eb7-e934-485a-8cec-1647e4d0acad', 1, 2, 'lisi', 'wangwu', '2026-06-10 14:40:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-10 14:40:28', '2026-06-10 14:40:27', 0),(3, '2026-06-11', 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', 1, 2, 'wangwu', 'zhangsan', '2026-06-11 10:16:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-11 10:18:00', '2026-06-11 16:01:56', 0),(4, '2026-06-15', 'e13089e8-acff-4155-b421-300c0a9557dd', 1, 1, 'zhangsan', 'lisi', '2026-06-15 20:41:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-15 20:41:48', '2026-06-15 18:19:00', 1),(5, '2026-06-15', '5f8c99c3-3173-4385-8119-2911553ddacb', 1, 2, 'lisi', 'lisi', '2026-06-15 08:47:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-15 08:48:03', '2026-06-15 18:18:53', 1),(6, '2026-06-15', 'c2be6685-cf1c-4c63-84fc-2565c51baee2', 1, 2, 'fangyongjun', 'lirunsheng', '2026-06-15 18:19:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-15 18:19:08', '2026-06-16 06:55:16', 1),(7, '2026-06-15', 'd9616f04-4254-4d81-b063-2a57ce9a7e34', 1, 2, 'fangyongjun', 'lirunsheng', '2026-06-16 06:55:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-16 06:55:22', '2026-06-16 06:55:21', 0),(8, '2026-06-16', '81913210-62fe-4cf0-a7d3-caedf0df4b0d', 1, 1, 'lirunsheng', 'zhouhoukui', '2026-06-16 10:22:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-16 10:22:23', '2026-06-16 10:22:23', 0),(9, '2026-06-16', '03171504-1060-44be-b59f-7983a5997dac', 1, 2, 'zhouhoukui', 'guobing', '2026-06-16 10:22:00', 0, NULL, 'weiyangyang', '魏阳阳', '2026-06-16 10:22:29', '2026-06-16 10:22:28', 0)
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_handover_attachment` WRITE;
DELETE FROM `rbac`.`duty_handover_attachment`;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_handover_system_status` WRITE;
DELETE FROM `rbac`.`duty_handover_system_status`;
INSERT INTO `rbac`.`duty_handover_system_status` (`id`,`handover_id`,`description`,`level`,`is_danger`,`sort_order`,`create_time`) VALUES (109, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。skill支持这些如恶化设计。从项目演示，运行到 项目水电费水电费水电费水电费水电费是收费', 1, 0, 1, '2026-06-11 16:46:22'),(110, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。', 0, 0, 2, '2026-06-11 16:46:22'),(111, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。', 0, 0, 3, '2026-06-11 16:46:22'),(112, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。', 0, 0, 4, '2026-06-11 16:46:22'),(113, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MCP、skill支持这些如恶化设计。', 0, 0, 5, '2026-06-11 16:46:22'),(114, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '从项目演示，运行到 项目实战：架构如何设计、环境怎么搭，Agent loop，上下文、可压缩、MC', 0, 0, 6, '2026-06-11 16:46:22'),(119, '5f8c99c3-3173-4385-8119-2911553ddacb', '委委屈屈我饿我去额温枪额温枪完全', 0, 0, 1, '2026-06-15 08:48:03'),(120, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问请问恶趣味恶趣味恶趣味请问', 0, 0, 2, '2026-06-15 08:48:03'),(121, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问q恶趣味恶趣味e王企鹅请问wq', 0, 0, 3, '2026-06-15 08:48:03'),(122, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问恶趣味厄齐尔去', 0, 0, 4, '2026-06-15 08:48:03'),(123, 'e13089e8-acff-4155-b421-300c0a9557dd', '委委屈屈我饿我去额温枪额温枪完全', 0, 0, 1, '2026-06-15 09:36:33'),(124, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问请问恶趣味恶趣味恶趣味请问', 0, 0, 2, '2026-06-15 09:36:33'),(125, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问q恶趣味恶趣味e王企鹅请问wq', 0, 0, 3, '2026-06-15 09:36:33'),(126, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问恶趣味厄齐尔去', 0, 0, 4, '2026-06-15 09:36:33'),(127, 'e13089e8-acff-4155-b421-300c0a9557dd', '委委屈屈我饿我去额温枪额温枪完全', 0, 0, 5, '2026-06-15 09:36:33'),(128, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问请问恶趣味恶趣味恶趣味请问', 0, 0, 6, '2026-06-15 09:36:33'),(129, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问q恶趣味恶趣味e王企鹅请问wq', 0, 0, 7, '2026-06-15 09:36:33'),(130, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问恶趣味厄齐尔去', 0, 0, 8, '2026-06-15 09:36:33'),(131, 'c2be6685-cf1c-4c63-84fc-2565c51baee2', '', 0, 0, 1, '2026-06-15 18:19:08'),(132, 'd9616f04-4254-4d81-b063-2a57ce9a7e34', '', 0, 0, 1, '2026-06-16 06:55:22'),(134, '03171504-1060-44be-b59f-7983a5997dac', '', 0, 0, 1, '2026-06-16 10:22:29'),(138, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '青蔷薇请问请问请问请问额我', 2, 1, 1, '2026-06-16 14:30:19'),(139, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '企鹅翁请问请问请问qw', 1, 0, 2, '2026-06-16 14:30:19'),(140, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '请问其味无穷', 0, 0, 3, '2026-06-16 14:30:19')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_handover_todo_item` WRITE;
DELETE FROM `rbac`.`duty_handover_todo_item`;
INSERT INTO `rbac`.`duty_handover_todo_item` (`id`,`handover_id`,`description`,`level`,`is_danger`,`is_completed`,`completed_time`,`sort_order`,`create_time`,`update_time`) VALUES (37, 'a69bf05a-a27e-44f0-8ab6-0ef6c8633cfc', '萨达奥迪阿是das', 0, 0, 0, NULL, 1, '2026-06-11 16:46:22', '2026-06-11 16:46:22'),(44, '5f8c99c3-3173-4385-8119-2911553ddacb', '我去额温枪恶趣味额温枪额温枪', 0, 0, 0, NULL, 1, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(45, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问完全', 0, 0, 0, NULL, 2, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(46, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问额温枪e', 0, 0, 0, NULL, 3, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(47, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问额温枪', 0, 0, 0, NULL, 4, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(48, '5f8c99c3-3173-4385-8119-2911553ddacb', '为请问王企鹅王企鹅王企鹅全额', 0, 0, 0, NULL, 5, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(49, '5f8c99c3-3173-4385-8119-2911553ddacb', '请问请问额温枪', 0, 0, 0, NULL, 6, '2026-06-15 08:48:03', '2026-06-15 08:48:03'),(50, 'e13089e8-acff-4155-b421-300c0a9557dd', '我去额温枪恶趣味额温枪额温枪', 0, 0, 0, NULL, 1, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(51, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问完全', 0, 0, 0, NULL, 2, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(52, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问额温枪e', 0, 0, 0, NULL, 3, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(53, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问额温枪', 0, 0, 0, NULL, 4, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(54, 'e13089e8-acff-4155-b421-300c0a9557dd', '为请问王企鹅王企鹅王企鹅全额 ', 0, 0, 0, NULL, 5, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(55, 'e13089e8-acff-4155-b421-300c0a9557dd', '请问请问额温枪', 0, 0, 0, NULL, 6, '2026-06-15 09:36:33', '2026-06-15 09:36:33'),(56, 'c2be6685-cf1c-4c63-84fc-2565c51baee2', '', 0, 0, 0, NULL, 1, '2026-06-15 18:19:08', '2026-06-15 18:19:07'),(57, 'd9616f04-4254-4d81-b063-2a57ce9a7e34', '', 0, 0, 0, NULL, 1, '2026-06-16 06:55:22', '2026-06-16 06:55:21'),(59, '03171504-1060-44be-b59f-7983a5997dac', '', 0, 0, 0, NULL, 1, '2026-06-16 10:22:29', '2026-06-16 10:22:28'),(61, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '青蔷薇请问请问请问请问额我', 2, 1, 0, NULL, 1, '2026-06-16 14:30:19', '2026-06-16 14:30:18'),(62, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '企鹅翁请问请问请问qw', 1, 0, 0, NULL, 2, '2026-06-16 14:30:19', '2026-06-16 14:30:18'),(63, '81913210-62fe-4cf0-a7d3-caedf0df4b0d', '请问其味无穷', 0, 0, 0, NULL, 3, '2026-06-16 14:30:19', '2026-06-16 14:30:18')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_log` WRITE;
DELETE FROM `rbac`.`duty_log`;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_log_attachment` WRITE;
DELETE FROM `rbac`.`duty_log_attachment`;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_log_tag` WRITE;
DELETE FROM `rbac`.`duty_log_tag`;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_note` WRITE;
DELETE FROM `rbac`.`duty_note`;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_personnel` WRITE;
DELETE FROM `rbac`.`duty_personnel`;
INSERT INTO `rbac`.`duty_personnel` (`id`,`personnel_type`,`user_code`,`name`,`phone`,`service_group`,`batch`,`department`,`employee_no`,`status`,`group_sort_order`,`sort_order`,`remark`,`created_by`,`created_time`,`updated_by`,`updated_time`) VALUES (1, 1, 'zhouhoukui', '周厚奎', '13122446565', 0, 0, NULL, NULL, 1, 0, 1, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:02:03'),(2, 1, 'lirunsheng', '李润生', '13122446565', 0, 0, NULL, NULL, 1, 0, 2, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:01'),(3, 1, 'guobing', '郭兵', '13122446565', 0, 0, NULL, NULL, 1, 0, 3, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:02'),(4, 1, 'fangyongjun', '方永君', '13122446565', 0, 0, NULL, NULL, 1, 0, 4, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:03'),(5, 2, 'weiyangyang', '魏阳阳', '13122446565', 0, 0, NULL, NULL, 1, 0, 1, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:02:03'),(6, 2, 'qianwencai', '钱文才', '13122446565', 0, 0, NULL, NULL, 1, 0, 2, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:04'),(7, 2, 'zhangkexin', '张可心', '13122446565', 0, 1, NULL, NULL, 1, 1, 3, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:36'),(8, 2, 'majilong', '马继龙', '13122446565', 0, 1, NULL, NULL, 1, 2, 4, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:40'),(9, 3, 'wangweiwei', '王维伟', '13122446565', 0, 0, NULL, NULL, 1, 0, 1, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:02:03'),(10, 3, 'wangzhiwen', '王志文', '13122446565', 0, 0, NULL, NULL, 1, 0, 2, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:07'),(11, 3, 'wangfan', '王帆', '13122446565', 0, 0, NULL, NULL, 1, 0, 3, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:08'),(12, 3, 'zegnxingyan', '曾星艳', '13122446565', 0, 0, NULL, NULL, 1, 0, 4, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:09'),(13, 4, 'xushimin', '徐世民', '13122446565', 0, 0, NULL, NULL, 1, 0, 1, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:02:03'),(14, 4, 'wengchao', '翁超', '13122446565', 0, 0, NULL, NULL, 1, 0, 2, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:10'),(15, 4, 'liutao', '刘涛', '13122446565', 0, 0, NULL, NULL, 1, 0, 3, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:11'),(16, 4, 'chenqiao', '陈巧', '13122446565', 0, 0, NULL, NULL, 1, 0, 4, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:13'),(17, 5, 'baoweifeng', '包伟峰', '13122446565', 1, 0, NULL, NULL, 1, 1, 1, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:10:01'),(18, 5, 'yangyang', '杨阳', '13122446565', 1, 0, NULL, NULL, 1, 2, 2, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:58'),(19, 5, 'lilei', '李磊', '13122446565', 1, 0, NULL, NULL, 1, 3, 3, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:58'),(20, 5, 'yufei', '余飞', '13122446565', 1, 0, NULL, NULL, 1, 4, 4, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:57'),(21, 5, 'xiewanqing', '谢婉晴', '13122446565', 2, 0, NULL, NULL, 1, 1, 5, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:56'),(22, 5, 'wangtiantian', '王甜甜', '13122446565', 2, 0, NULL, NULL, 1, 2, 6, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:56'),(23, 5, 'huangguan', '黄冠', '13122446565', 2, 0, NULL, NULL, 1, 3, 7, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:55'),(24, 5, 'wangcuiqiong', '王翠琼', '13122446565', 2, 0, NULL, NULL, 1, 4, 8, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:54'),(25, 5, 'wangwei', '王伟', '13122446565', 3, 0, NULL, NULL, 1, 1, 9, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:52'),(26, 5, 'sunyang', '孙阳', '13122446565', 3, 0, NULL, NULL, 1, 2, 10, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:53'),(27, 5, 'xuheying', '许和颖', '13122446565', 3, 0, NULL, NULL, 1, 3, 11, NULL, NULL, '2026-06-15 18:02:03', NULL, '2026-06-15 18:09:54')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`duty_schedule` WRITE;
DELETE FROM `rbac`.`duty_schedule`;
INSERT INTO `rbac`.`duty_schedule` (`id`,`schedule_date`,`ecc_day_personnel_id`,`ecc_night_personnel_id`,`sys_ops_personnel_id`,`net_ops_personnel_id`,`pm_personnel_id`,`created_by`,`created_time`,`updated_by`,`updated_time`) VALUES (1, '2026-06-15', 'zhouhoukui', 'fangyongjun', 'qianwencai', 'wangweiwei', 'xushimin', 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(2, '2026-06-16', 'lirunsheng', 'zhouhoukui', 'zhangkexin', 'wangzhiwen', 'wengchao', 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(3, '2026-06-17', 'guobing', 'lirunsheng', 'majilong', 'wangfan', 'liutao', 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(4, '2026-06-18', 'fangyongjun', 'guobing', 'weiyangyang', 'zegnxingyan', 'chenqiao', 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(5, '2026-06-19', 'zhouhoukui', 'fangyongjun', NULL, NULL, NULL, 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(6, '2026-06-20', 'lirunsheng', 'zhouhoukui', NULL, NULL, NULL, 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22'),(7, '2026-06-21', 'guobing', 'lirunsheng', NULL, NULL, NULL, 'system', '2026-06-15 18:15:22', NULL, '2026-06-15 18:15:22')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`other_duty` WRITE;
DELETE FROM `rbac`.`other_duty`;
INSERT INTO `rbac`.`other_duty` (`id`,`schedule_date`,`batch_A`,`batch_A_id`,`batch_B`,`batch_B_id`,`service_A`,`service_A_id`,`service_B`,`service_B_id`,`service_C`,`service_C_id`,`create_user`,`create_user_nickname`,`create_time`,`update_time`,`deleted`) VALUES (1, '2026-06-15', '马继龙', 'majilong', '张可心', 'zhangkexin', '余飞', 'yufei', '王翠琼', 'wangcuiqiong', '王伟', 'wangwei', 'system', 'system', '2026-06-15 18:12:05', '2026-06-16 06:55:21', 0),(2, '2026-06-16', '马继龙', 'majilong', '张可心', 'zhangkexin', '余飞', 'yufei', '王翠琼', 'wangcuiqiong', '王伟', 'wangwei', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0),(3, '2026-06-17', '张可心', 'zhangkexin', '马继龙', 'majilong', '包伟峰', 'baoweifeng', '谢婉晴', 'xiewanqing', '孙阳', 'sunyang', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0),(4, '2026-06-18', '马继龙', 'majilong', '张可心', 'zhangkexin', '杨阳', 'yangyang', '王甜甜', 'wangtiantian', '许和颖', 'xuheying', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0),(5, '2026-06-19', '张可心', 'zhangkexin', '马继龙', 'majilong', '李磊', 'lilei', '黄冠', 'huangguan', '王伟', 'wangwei', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0),(6, '2026-06-20', '马继龙', 'majilong', '张可心', 'zhangkexin', '余飞', 'yufei', '王翠琼', 'wangcuiqiong', '孙阳', 'sunyang', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0),(7, '2026-06-21', '张可心', 'zhangkexin', '马继龙', 'majilong', '包伟峰', 'baoweifeng', '谢婉晴', 'xiewanqing', '许和颖', 'xuheying', 'system', 'system', '2026-06-15 18:12:05', '2026-06-15 18:12:04', 0)
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`remote_record` WRITE;
DELETE FROM `rbac`.`remote_record`;
INSERT INTO `rbac`.`remote_record` (`id`,`record_date`,`apply_user`,`apply_user_username`,`reason`,`permission_type`,`start_time`,`end_time`,`ecc_duty_person`,`ecc_duty_person_username`,`approver`,`approver_username`,`email`,`remark`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES (1, '2026-06-15', '', '', '', 'VPN', '', '', '', '', '', '', '', '', '', '2026-06-16 07:08:39', '', '2026-06-16 07:08:39'),(2, '2026-06-16', '魏阳阳', 'weiyangyang', '', 'RA', '', '', '李润生', 'lirunsheng', '徐世民', 'xushimin', '未补发', '', '', '2026-06-16 10:20:05', '', '2026-06-16 10:35:15')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`security_device_monitor` WRITE;
DELETE FROM `rbac`.`security_device_monitor`;
INSERT INTO `rbac`.`security_device_monitor` (`id`,`record_date`,`alert_content`,`ecc_duty_person`,`ecc_duty_person_username`,`ops_confirm_person`,`ops_confirm_person_username`,`remark`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES (1, '2026-06-16', '', '周厚奎', 'zhouhoukui', '魏阳阳', 'weiyangyang', '', '', '2026-06-16 10:22:07', '', '2026-06-16 10:46:53')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`sys_menu` WRITE;
DELETE FROM `rbac`.`sys_menu`;
INSERT INTO `rbac`.`sys_menu` (`id`,`parent_id`,`menu_name`,`menu_type`,`path`,`component`,`permission_code`,`icon`,`order_num`,`visible`,`keep_alive`,`redirect`,`remark`,`create_time`,`update_time`,`deleted`) VALUES (1, 0, '告警管理', 1, '/alarmManagement', '', 'alarm:manage', 'icon-gaojingguanli', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-03-30 17:21:57', 0),(2, 1, '告警数据', 2, '/alarmManagement/alarmItem', 'components/alarmManage/AlarmPage.vue', 'alarm:view', '', 0, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-03 09:02:26', 0),(3, 0, '工具管理', 1, '/toolsManagement', '', 'tool:manage', 'icon-shijianguanli', 2, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-03-30 17:21:57', 0),(4, 3, '工具库', 2, '/toolsManagement/tools', 'components/toolsManage/ToolsPage.vue', 'tool:view', '', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:25', 0),(5, 0, '权限管理', 1, '/permissionManagement', '', 'system:permission', 'icon-zhanghaoquanxianguanli', 5, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-05-14 15:05:10', 0),(6, 5, '用户管理', 2, '/permissionManagement/userManage', 'components/permissionManage/UserManagePage.vue', 'system:user', '', 1, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:26', 0),(7, 5, '角色管理', 2, '/permissionManagement/roleManage', 'components/permissionManage/RoleManagePage.vue', 'system:role', '', 2, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:27', 0),(8, 5, '菜单管理', 2, '/permissionManagement/menuManage', 'components/permissionManage/MenuManagePage.vue', 'system:menu', '', 3, 1, 0, NULL, NULL, '2026-03-30 17:21:57', '2026-04-02 14:17:29', 0),(9, 2, '刷新', 3, '/alarmManagement/alarmItem', NULL, 'alarm:refresh', '', 1, 1, 0, NULL, NULL, '2026-04-02 14:22:57', '2026-04-03 14:17:07', 0),(10, 2, '搜索', 2, '/alarmManagement/alarmItem', NULL, 'alarm:search', '', 2, 1, 0, NULL, NULL, '2026-04-02 15:09:17', '2026-04-03 14:17:09', 0),(11, 2, '重置', 3, '/alarmManagement/alarmItem', NULL, 'alarm:reset', '', 0, 1, 0, NULL, NULL, '2026-04-02 16:39:36', '2026-04-03 14:17:11', 0),(12, 2, '批量关闭', 2, '/alarmManagement/alarmItem', NULL, 'alarm:batchClose', '', 3, 1, 0, NULL, NULL, '2026-04-02 16:43:54', '2026-04-03 14:17:13', 0),(13, 2, '告警聚合', 3, '/alarmManagement/alarmItem', NULL, 'alarm:aggregation', '', 4, 1, 0, NULL, NULL, '2026-04-02 16:52:17', '2026-04-03 14:17:17', 0),(14, 4, '工单导出', 3, '/toolsManagement/tools', NULL, 'tool:orderExport', '', 0, 1, 0, NULL, NULL, '2026-04-02 16:54:25', '2026-04-03 14:17:19', 0),(15, 4, '域账号管理', 3, '/toolsManagement/tools', NULL, 'tool:accountUnlock', '', 1, 1, 0, NULL, NULL, '2026-04-02 16:55:20', '2026-04-17 08:46:09', 0),(16, 4, '脚本下发', 3, '/toolsManagement/tools', NULL, 'tool:scriptDistribution', '', 2, 1, 0, NULL, NULL, '2026-04-02 16:57:03', '2026-04-03 14:17:24', 0),(17, 4, '堡垒机账号解锁', 3, '/toolsManagement/tools', NULL, 'tool:tokenUnlock', '', 3, 1, 0, NULL, NULL, '2026-04-02 16:58:17', '2026-04-03 14:17:27', 0),(18, 6, '分配角色', 3, '/permissionManagement/userManage', NULL, 'system:assignRoles', '', 0, 1, 0, NULL, NULL, '2026-04-02 17:00:13', '2026-04-03 14:17:31', 0),(19, 6, '启用', 3, '/permissionManagement/userManage', NULL, 'system:enableUser', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:02:21', '2026-04-03 14:17:36', 0),(20, 6, '禁用', 3, '/permissionManagement/userManage', NULL, 'system:disabledUser', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:02:58', '2026-04-03 14:17:41', 0),(21, 7, '分配菜单', 3, '/permissionManagement/roleManage', NULL, 'system:assignMenus', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:04:36', '2026-04-03 14:41:07', 0),(22, 7, '编辑', 3, '/permissionManagement/roleManage', NULL, 'system:editRoles', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:05:37', '2026-04-03 14:41:17', 0),(23, 7, '启用', 3, '/permissionManagement/roleManage', NULL, 'system:enableRoles', '', 3, 1, 0, NULL, NULL, '2026-04-02 17:06:02', '2026-04-03 14:41:20', 0),(24, 7, '禁用', 3, '/permissionManagement/roleManage', NULL, 'system:diabledRoles', '', 4, 1, 0, NULL, NULL, '2026-04-02 17:06:19', '2026-04-03 14:41:24', 0),(25, 8, '新增根菜单', 3, '/permissionManagement/menuManage', NULL, 'system:createRoot', '', 0, 1, 0, NULL, NULL, '2026-04-02 17:10:13', '2026-04-03 14:17:50', 0),(26, 8, '新增子项', 3, '/permissionManagement/menuManage', NULL, 'system:createChildNode', '', 1, 1, 0, NULL, NULL, '2026-04-02 17:11:05', '2026-04-03 14:17:57', 0),(27, 8, '编辑', 3, '/permissionManagement/menuManage', NULL, 'system:editMenus', '', 2, 1, 0, NULL, NULL, '2026-04-02 17:11:34', '2026-04-03 14:17:58', 0),(28, 8, '删除', 3, '/permissionManagement/menuManage', NULL, 'system:deleteMenus', '', 3, 1, 0, NULL, NULL, '2026-04-02 17:12:01', '2026-04-03 14:18:03', 0),(29, 7, '新增角色', 3, '/permissionManagement/roleManage', NULL, 'alarm:createRole', '', 0, 1, 0, NULL, NULL, '2026-04-03 14:40:58', '2026-04-03 14:41:47', 0),(39, 2, '导出', 3, '/alarmManagement/alarmItem', NULL, 'alarm:export', '', 5, 1, 0, NULL, NULL, '2026-04-09 16:54:12', '2026-04-09 16:54:12', 0),(40, 4, '邮箱账号管理', 3, '/toolsManagement/tools', NULL, 'tool:emailManage', '', 4, 1, 0, NULL, NULL, '2026-04-14 13:58:25', '2026-04-14 13:58:25', 0),(41, 0, '首页', 1, '/home', 'components/homePage/HomePage.vue', 'home:homePage', 'icon-shouye1', 0, 1, 0, NULL, NULL, '2026-04-21 17:40:46', '2026-04-21 18:00:13', 0),(42, 4, '主机密码修改', 3, '/toolsManagement/tools', NULL, 'tool:passwordModify', '', 5, 1, 0, NULL, NULL, '2026-05-11 18:10:18', '2026-05-11 18:10:18', 0),(43, 0, '值班管理', 1, '/dutyManagement', NULL, 'duty:manage', 'icon-zhibanguanli', 3, 1, 0, NULL, NULL, '2026-05-14 14:58:40', '2026-05-20 14:52:06', 0),(44, 43, '值班管理', 2, '/dutyManagement/dutyCalendar', NULL, 'duty:calendar', '', 0, 1, 0, NULL, NULL, '2026-05-20 14:54:17', '2026-05-21 14:17:45', 0),(45, 43, '值班人员', 2, '/dutyManagement/dutyUser', NULL, 'duty:user', '', 1, 1, 0, NULL, NULL, '2026-05-20 14:54:51', '2026-05-21 14:17:38', 1),(46, 43, '交接班记录', 2, '/dutyManagement/dutyHandover', NULL, 'duty:handover', '', 2, 1, 0, NULL, NULL, '2026-05-21 13:57:52', '2026-05-21 13:57:52', 0),(47, 43, '值班日志', 2, '/dutyManagement/dutyLog', NULL, 'duty:log', '', 7, 1, 0, NULL, NULL, '2026-05-21 13:58:19', '2026-06-12 10:07:17', 0),(48, 44, '新增排班', 3, '/a', NULL, '', '', 1, 1, 0, NULL, NULL, '2026-05-26 11:01:49', '2026-05-26 11:02:08', 1),(49, 44, '新增排版', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:create', '', 1, 1, 0, NULL, NULL, '2026-06-01 16:37:53', '2026-06-01 16:37:53', 0),(50, 44, '导出排班', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:export', '', 0, 1, 0, NULL, NULL, '2026-06-01 16:38:14', '2026-06-01 16:38:14', 0),(51, 44, '调班', 3, '/dutyManagement/dutyCalendar', NULL, 'duty:edit', '', 2, 1, 0, NULL, NULL, '2026-06-01 16:38:56', '2026-06-01 16:38:56', 0),(52, 46, '导出记录', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverExport', '', 0, 1, 0, NULL, NULL, '2026-06-01 16:56:24', '2026-06-01 16:56:24', 0),(53, 46, '新建交接班', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverCreate', '', 1, 1, 0, NULL, NULL, '2026-06-01 16:57:02', '2026-06-01 16:57:02', 0),(54, 46, '重置', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverReset', '', 2, 1, 0, NULL, NULL, '2026-06-01 16:57:22', '2026-06-01 16:57:22', 0),(55, 46, '查询', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverSearch', '', 3, 1, 0, NULL, NULL, '2026-06-01 16:57:44', '2026-06-01 16:57:44', 0),(56, 46, '编辑（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverEdit', '', 4, 1, 0, NULL, NULL, '2026-06-01 16:58:56', '2026-06-01 16:58:56', 0),(57, 46, '保存（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverSave', '', 5, 1, 0, NULL, NULL, '2026-06-01 17:01:06', '2026-06-01 17:01:06', 0),(58, 46, '确认交接（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverConfirm', '', 6, 1, 0, NULL, NULL, '2026-06-01 17:01:33', '2026-06-01 17:01:33', 0),(59, 46, '删除（卡片内）', 3, '/dutyManagement/dutyHandover', NULL, 'duty:handoverDelete', '', 7, 1, 0, NULL, NULL, '2026-06-01 17:03:21', '2026-06-01 17:03:21', 0),(60, 47, '导出日志', 3, '/dutyManagement/dutyLog', NULL, 'duty:logExport', '', 0, 1, 0, NULL, NULL, '2026-06-01 17:14:51', '2026-06-01 17:14:51', 0),(61, 47, '新增日志', 3, '/dutyManagement/dutyLog', NULL, 'duty:logCreate', '', 1, 1, 0, NULL, NULL, '2026-06-01 17:15:13', '2026-06-01 17:15:13', 0),(62, 47, '保存（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logSave', '', 2, 1, 0, NULL, NULL, '2026-06-01 17:15:50', '2026-06-01 17:15:50', 0),(63, 47, '编辑（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logEdit', '', 3, 1, 0, NULL, NULL, '2026-06-01 17:16:08', '2026-06-01 17:16:08', 0),(64, 47, '确认（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logConfirm', '', 4, 1, 0, NULL, NULL, '2026-06-01 17:16:36', '2026-06-01 17:16:36', 0),(65, 47, '删除（卡片内）', 3, '/dutyManagement/dutyLog', NULL, 'duty:logDelete', '', 5, 1, 0, NULL, NULL, '2026-06-01 17:17:10', '2026-06-01 17:17:10', 0),(66, 47, '保存（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteSave', '', 6, 1, 0, NULL, NULL, '2026-06-01 17:17:47', '2026-06-01 17:17:47', 0),(67, 47, '编辑（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteEdit', '', 7, 1, 0, NULL, NULL, '2026-06-01 17:17:58', '2026-06-01 17:17:58', 0),(68, 47, '新增（值班备注）', 3, '/dutyManagement/dutyLog', NULL, 'duty:noteAdd', '', 8, 1, 0, NULL, NULL, '2026-06-03 09:54:33', '2026-06-03 09:54:33', 0),(69, 43, '日常工作交接', 3, '/dutyManagement/dailyHandover', NULL, 'duty:dailyHandover', '', 3, 1, 0, NULL, NULL, '2026-06-08 15:56:40', '2026-06-08 16:00:34', 0),(70, 69, '保存', 3, '/dutyManagement/dailyHandover', NULL, 'daily:save', '', 0, 1, 0, NULL, NULL, '2026-06-10 14:55:59', '2026-06-10 14:55:59', 0),(71, 69, '加载', 3, '/dutyManagement/dailyHandover', NULL, 'daily:load', '', 1, 1, 0, NULL, NULL, '2026-06-10 14:56:10', '2026-06-10 14:56:10', 0),(72, 69, '导出', 3, '/dutyManagement/dailyHandover', NULL, 'daily:export', '', 2, 1, 0, NULL, NULL, '2026-06-10 14:56:19', '2026-06-10 14:56:19', 0),(73, 69, '新增行', 3, '/dutyManagement/dailyHandover', NULL, 'daily:addRow', '', 3, 1, 0, NULL, NULL, '2026-06-10 14:56:35', '2026-06-10 14:56:35', 0),(74, 69, '列管理', 3, '/dutyManagement/dailyHandover', NULL, 'daily:columnManage', '', 4, 1, 0, NULL, NULL, '2026-06-10 14:56:47', '2026-06-10 14:56:47', 0),(75, 69, '撤销', 3, '/dutyManagement/dailyHandover', NULL, 'daily:revoke', '', 5, 1, 0, NULL, NULL, '2026-06-10 17:57:37', '2026-06-10 17:57:37', 0),(76, 69, '合并导出', 3, '/dutyManagement/dailyHandover', NULL, 'daily:mergeExport', '', 6, 1, 0, NULL, NULL, '2026-06-10 17:57:52', '2026-06-10 17:57:52', 0),(77, 43, '远程记录', 2, '/dutyManagement/remoteRecord', NULL, 'duty:remoteRecord', '', 4, 1, 0, NULL, NULL, '2026-06-12 10:06:53', '2026-06-12 10:11:35', 0),(78, 43, '安全设备监控', 2, '/dutyManagement/securityDeviceMonitor', NULL, 'duty:securityDeviceMonitor', '', 5, 1, 0, NULL, NULL, '2026-06-12 16:09:29', '2026-06-12 16:09:29', 0),(79, 77, '保存（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:save', '', 0, 1, 0, NULL, NULL, '2026-06-15 10:09:12', '2026-06-15 10:16:27', 0),(80, 77, '加载（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:load', '', 1, 1, 0, NULL, NULL, '2026-06-15 10:09:20', '2026-06-15 10:16:30', 0),(81, 77, '导出（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:export', '', 2, 1, 0, NULL, NULL, '2026-06-15 10:09:28', '2026-06-15 10:16:34', 0),(82, 77, '合并导出（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:mergeExport', '', 3, 1, 0, NULL, NULL, '2026-06-15 10:10:47', '2026-06-15 10:16:37', 0),(83, 78, '保存', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'security:save', '', 0, 1, 0, NULL, NULL, '2026-06-15 10:10:58', '2026-06-15 10:15:21', 0),(84, 78, '加载', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'security:load', '', 1, 1, 0, NULL, NULL, '2026-06-15 10:11:07', '2026-06-15 10:15:28', 0),(85, 77, '新增行（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:addRow', '', 4, 1, 0, NULL, NULL, '2026-06-15 10:11:37', '2026-06-15 10:16:40', 0),(86, 77, '删除选中（使用记录）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:moaVpn:deleteRow', '', 5, 1, 0, NULL, NULL, '2026-06-15 10:11:46', '2026-06-15 10:16:43', 0),(87, 78, '导出', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'security:export', '', 2, 1, 0, NULL, NULL, '2026-06-15 10:13:31', '2026-06-15 10:15:33', 0),(88, 78, '合并导出', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'remote:eccContact:mergeExport', '', 3, 1, 0, NULL, NULL, '2026-06-15 10:13:44', '2026-06-15 10:15:37', 1),(89, 78, '新增行', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'security:addRow', '', 4, 1, 0, NULL, NULL, '2026-06-15 10:13:56', '2026-06-15 10:15:45', 0),(90, 78, '删除选中', 3, '/dutyManagement/securityDeviceMonitor', NULL, 'security:deleteRow', '', 5, 1, 0, NULL, NULL, '2026-06-15 10:14:09', '2026-06-15 10:15:51', 0),(91, 77, '保存（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:save', '', 6, 1, 0, NULL, NULL, '2026-06-15 10:16:53', '2026-06-15 10:17:00', 0),(92, 77, '加载（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:load', '', 7, 1, 0, NULL, NULL, '2026-06-15 10:17:17', '2026-06-15 10:18:41', 0),(93, 77, '导出（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:export', '', 8, 1, 0, NULL, NULL, '2026-06-15 10:17:31', '2026-06-15 10:17:31', 0),(94, 77, '合并导出（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:mergeExport', '', 9, 1, 0, NULL, NULL, '2026-06-15 10:17:44', '2026-06-15 10:17:44', 0),(95, 77, '新增行（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:addRow', '', 10, 1, 0, NULL, NULL, '2026-06-15 10:17:56', '2026-06-15 10:19:45', 0),(96, 77, '删除选中（联系异常）', 3, '/dutyManagement/remoteRecord', NULL, 'remote:eccContact:deleteRow', '', 11, 1, 0, NULL, NULL, '2026-06-15 10:18:11', '2026-06-15 10:18:11', 0)
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`sys_role` WRITE;
DELETE FROM `rbac`.`sys_role`;
INSERT INTO `rbac`.`sys_role` (`id`,`role_code`,`role_name`,`description`,`role_type`,`data_scope`,`status`,`sort_order`,`create_time`,`update_time`,`deleted`) VALUES (1, 'admin', '超级管理员', '系统所有权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-04-29 11:06:12', 0),(2, 'normal', '普通用户', '普通用户权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-05-19 17:43:36', 0)
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`sys_role_menu` WRITE;
DELETE FROM `rbac`.`sys_role_menu`;
INSERT INTO `rbac`.`sys_role_menu` (`id`,`role_id`,`menu_id`,`deleted`,`create_time`) VALUES (484, 1, 95, 0, '2026-06-15 10:18:19'),(483, 1, 94, 0, '2026-06-15 10:18:19'),(482, 1, 93, 0, '2026-06-15 10:18:19'),(481, 1, 92, 0, '2026-06-15 10:18:19'),(480, 1, 91, 0, '2026-06-15 10:18:19'),(479, 1, 96, 0, '2026-06-15 10:18:19'),(478, 1, 90, 0, '2026-06-15 10:14:15'),(477, 1, 89, 0, '2026-06-15 10:14:15'),(476, 1, 88, 1, '2026-06-15 10:14:15'),(475, 1, 87, 0, '2026-06-15 10:14:15'),(474, 1, 86, 0, '2026-06-15 10:14:15'),(473, 1, 85, 0, '2026-06-15 10:14:15'),(472, 1, 84, 0, '2026-06-15 10:14:15'),(471, 1, 83, 0, '2026-06-15 10:14:15'),(470, 1, 82, 0, '2026-06-15 10:14:15'),(469, 1, 81, 0, '2026-06-15 10:14:15'),(468, 1, 80, 0, '2026-06-15 10:14:15'),(467, 1, 79, 0, '2026-06-15 10:14:15'),(466, 1, 78, 0, '2026-06-12 16:14:36'),(465, 1, 77, 0, '2026-06-12 10:07:27'),(464, 1, 76, 0, '2026-06-10 17:57:57'),(463, 1, 75, 0, '2026-06-10 17:57:57'),(462, 1, 74, 0, '2026-06-10 14:56:52'),(461, 1, 73, 0, '2026-06-10 14:56:52'),(460, 1, 72, 0, '2026-06-10 14:56:52'),(459, 1, 71, 0, '2026-06-10 14:56:52'),(458, 1, 70, 0, '2026-06-10 14:56:52'),(457, 1, 69, 0, '2026-06-08 16:01:09'),(456, 1, 68, 0, '2026-06-03 10:05:08'),(455, 2, 63, 0, '2026-06-01 17:18:16'),(454, 2, 62, 0, '2026-06-01 17:18:16'),(453, 2, 61, 0, '2026-06-01 17:18:16'),(452, 2, 60, 0, '2026-06-01 17:18:16'),(451, 2, 67, 0, '2026-06-01 17:18:16'),(450, 2, 66, 0, '2026-06-01 17:18:16'),(449, 2, 65, 0, '2026-06-01 17:18:16'),(448, 2, 64, 0, '2026-06-01 17:18:16'),(447, 1, 63, 0, '2026-06-01 17:18:07'),(446, 1, 62, 0, '2026-06-01 17:18:07'),(445, 1, 61, 0, '2026-06-01 17:18:07'),(444, 1, 60, 0, '2026-06-01 17:18:07'),(443, 1, 59, 0, '2026-06-01 17:18:07'),(442, 1, 58, 0, '2026-06-01 17:18:07'),(441, 1, 57, 0, '2026-06-01 17:18:07'),(440, 1, 56, 0, '2026-06-01 17:18:07'),(439, 1, 55, 0, '2026-06-01 17:18:07'),(438, 1, 54, 0, '2026-06-01 17:18:07'),(437, 1, 53, 0, '2026-06-01 17:18:07'),(436, 1, 52, 0, '2026-06-01 17:18:07'),(435, 1, 67, 0, '2026-06-01 17:18:07'),(434, 1, 66, 0, '2026-06-01 17:18:07'),(433, 1, 65, 0, '2026-06-01 17:18:07'),(432, 1, 64, 0, '2026-06-01 17:18:07'),(431, 2, 59, 0, '2026-06-01 17:03:59'),(430, 2, 58, 0, '2026-06-01 17:03:59'),(429, 2, 57, 0, '2026-06-01 17:03:59'),(428, 2, 56, 0, '2026-06-01 17:03:59'),(427, 2, 55, 0, '2026-06-01 17:03:59'),(426, 2, 54, 0, '2026-06-01 17:03:59'),(425, 2, 53, 0, '2026-06-01 17:03:59'),(424, 2, 52, 0, '2026-06-01 17:03:59'),(423, 2, 51, 1, '2026-06-01 17:03:59'),(422, 2, 50, 0, '2026-06-01 16:42:41'),(421, 2, 49, 0, '2026-06-01 16:42:41'),(420, 2, 47, 0, '2026-06-01 16:42:41'),(419, 2, 46, 0, '2026-06-01 16:42:41'),(418, 2, 44, 0, '2026-06-01 16:42:41'),(417, 2, 43, 0, '2026-06-01 16:42:41'),(416, 1, 51, 0, '2026-06-01 16:39:01'),(415, 1, 50, 0, '2026-06-01 16:39:01'),(414, 1, 49, 0, '2026-06-01 16:39:01'),(413, 2, 17, 1, '2026-05-26 10:45:40'),(412, 2, 16, 1, '2026-05-26 10:45:40'),(411, 2, 15, 1, '2026-05-26 10:45:40'),(410, 2, 14, 1, '2026-05-26 10:45:40'),(409, 2, 4, 1, '2026-05-26 10:45:40'),(408, 2, 3, 1, '2026-05-26 10:45:40'),(407, 2, 41, 0, '2026-05-26 09:46:57'),(406, 1, 47, 0, '2026-05-21 13:58:32'),(405, 1, 46, 0, '2026-05-21 13:58:32'),(404, 1, 45, 1, '2026-05-20 14:55:12'),(403, 1, 44, 0, '2026-05-20 14:55:12'),(402, 1, 43, 0, '2026-05-14 15:04:51'),(401, 2, 42, 1, '2026-05-26 10:45:40'),(400, 1, 42, 0, '2026-05-11 18:12:16'),(399, 1, 41, 0, '2026-04-21 17:42:15'),(397, 2, 40, 1, '2026-05-26 10:45:40'),(396, 1, 40, 0, '2026-04-14 14:02:07'),(390, 2, 39, 0, '2026-04-09 16:55:27'),(389, 1, 39, 0, '2026-04-09 16:55:17'),(388, 1, 29, 0, '2026-04-03 14:42:02'),(387, 2, 13, 0, '2026-04-03 15:38:30'),(386, 2, 12, 0, '2026-04-03 15:38:30'),(385, 2, 11, 0, '2026-04-03 15:38:30'),(384, 2, 10, 0, '2026-04-03 15:38:30'),(383, 2, 9, 0, '2026-04-03 15:38:30'),(382, 2, 2, 0, '2026-04-03 15:38:30'),(381, 2, 1, 0, '2026-04-03 15:38:30'),(28, 1, 28, 0, '2026-04-03 11:34:56'),(27, 1, 27, 0, '2026-04-03 11:34:56'),(26, 1, 26, 0, '2026-04-03 11:34:56'),(25, 1, 25, 0, '2026-04-03 11:34:56'),(24, 1, 24, 0, '2026-04-03 14:39:28'),(23, 1, 23, 0, '2026-04-03 14:39:28'),(22, 1, 22, 0, '2026-04-03 11:34:56'),(21, 1, 21, 0, '2026-04-03 11:34:56'),(20, 1, 20, 0, '2026-04-03 11:34:56'),(19, 1, 19, 0, '2026-04-03 11:34:56'),(18, 1, 18, 0, '2026-04-03 11:34:56'),(17, 1, 17, 0, '2026-04-03 15:14:17'),(16, 1, 16, 0, '2026-04-03 15:14:17'),(15, 1, 15, 0, '2026-04-03 15:14:17'),(14, 1, 14, 0, '2026-04-03 15:14:17'),(13, 1, 13, 0, '2026-04-03 15:38:24'),(12, 1, 12, 0, '2026-04-03 15:38:24'),(11, 1, 11, 0, '2026-04-03 15:38:24'),(10, 1, 10, 0, '2026-04-03 15:38:24'),(9, 1, 9, 0, '2026-04-03 15:38:24'),(8, 1, 8, 0, '2026-04-03 11:34:56'),(7, 1, 7, 0, '2026-04-03 11:34:56'),(6, 1, 6, 0, '2026-04-03 11:34:56'),(5, 1, 5, 0, '2026-04-03 11:34:56'),(4, 1, 4, 0, '2026-04-03 15:14:17'),(3, 1, 3, 0, '2026-04-03 15:14:17'),(2, 1, 2, 0, '2026-04-03 15:38:24'),(1, 1, 1, 0, '2026-04-03 15:38:24')
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`sys_user` WRITE;
DELETE FROM `rbac`.`sys_user`;
INSERT INTO `rbac`.`sys_user` (`id`,`username`,`password`,`nickname`,`email`,`phone`,`status`,`user_type`,`avatar`,`last_login_time`,`last_login_ip`,`create_time`,`update_time`,`deleted`) VALUES (1, 'weiyangyang', '', '魏阳阳', NULL, NULL, 1, 1, NULL, NULL, NULL, '2026-03-30 17:27:10', '2026-04-03 18:00:45', 0)
;
UNLOCK TABLES;
COMMIT;
BEGIN;
LOCK TABLES `rbac`.`sys_user_role` WRITE;
DELETE FROM `rbac`.`sys_user_role`;
INSERT INTO `rbac`.`sys_user_role` (`id`,`user_id`,`role_id`,`create_time`) VALUES (1, 1, 1, '2026-06-03 16:36:39'),(2, 1, 2, '2026-06-03 16:36:39')
;
UNLOCK TABLES;
COMMIT;
