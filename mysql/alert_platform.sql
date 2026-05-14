/*
 Navicat Premium Dump SQL

 Source Server         : localhost_3306
 Source Server Type    : MySQL
 Source Server Version : 80045 (8.0.45)
 Source Host           : localhost:3306
 Source Schema         : alert_platform

 Target Server Type    : MySQL
 Target Server Version : 80045 (8.0.45)
 File Encoding         : 65001

 Date: 14/05/2026 17:57:36
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

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
) ENGINE = InnoDB AUTO_INCREMENT = 44 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统菜单表' ROW_FORMAT = Dynamic;

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
INSERT INTO `sys_menu` VALUES (43, 0, '值班管理', 1, '/dutyManagement', NULL, 'duty:management', 'icon-zhibanguanli', 3, 1, 0, NULL, NULL, '2026-05-14 14:58:40', '2026-05-14 14:58:40', 0);

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
) ENGINE = InnoDB AUTO_INCREMENT = 29 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统角色表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of sys_role
-- ----------------------------
INSERT INTO `sys_role` VALUES (1, 'admin', '超级管理员', '系统所有权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-04-29 11:06:12', 0);
INSERT INTO `sys_role` VALUES (2, 'normal', '普通用户', '普通用户权限', 1, 1, 1, 1, '2026-03-30 17:20:16', '2026-04-03 14:24:55', 0);

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
) ENGINE = InnoDB AUTO_INCREMENT = 403 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '角色菜单关联表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of sys_role_menu
-- ----------------------------
INSERT INTO `sys_role_menu` VALUES (402, 1, 43, 0, '2026-05-14 15:04:51');
INSERT INTO `sys_role_menu` VALUES (401, 2, 42, 0, '2026-05-11 18:12:26');
INSERT INTO `sys_role_menu` VALUES (400, 1, 42, 0, '2026-05-11 18:12:16');
INSERT INTO `sys_role_menu` VALUES (399, 1, 41, 0, '2026-04-21 17:42:15');
INSERT INTO `sys_role_menu` VALUES (397, 2, 40, 0, '2026-04-14 14:02:17');
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
) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统用户表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 37 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户角色关联表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of sys_user_role
-- ----------------------------
INSERT INTO `sys_user_role` VALUES (35, 1, 1, '2026-04-03 19:33:10');
INSERT INTO `sys_user_role` VALUES (36, 1, 2, '2026-04-03 19:33:10');

SET FOREIGN_KEY_CHECKS = 1;
