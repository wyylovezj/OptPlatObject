-- ============================================================
-- 日常工作交接表结构设计
-- 设计日期：2026-06-09
-- 运行环境：MySQL 8.0+
-- 使用方式：在 rbac 数据库下执行此脚本
-- ============================================================

USE rbac;

-- -----------------------------------------------------------
-- 1. 主表：daily_handover（交接主记录）
--    每一行代表一次交接（白班或夜班）
--    同一日期同一班次唯一（UNIQUE KEY uk_date_shift）
-- -----------------------------------------------------------
CREATE TABLE daily_handover (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  handover_date DATE          NOT NULL                    COMMENT '交接日期 YYYY-MM-DD',
  shift_type    TINYINT       NOT NULL DEFAULT 1          COMMENT '班次类型 1-白班 2-夜班',
  duty_person   VARCHAR(50)   NOT NULL DEFAULT ''         COMMENT '值班人（如 ecc-白班）',
  remark1       VARCHAR(255)  DEFAULT ''                  COMMENT '备注1（与日期同行的附加备注）',
  created_by    VARCHAR(50)   DEFAULT ''                  COMMENT '创建人',
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_by    VARCHAR(50)   DEFAULT ''                  COMMENT '最后更新人',
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_date_shift (handover_date, shift_type),
  KEY idx_handover_date (handover_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日常工作交接主表';


-- -----------------------------------------------------------
-- 2. 明细表：daily_handover_item（字段值存储，EAV模式）
--    每条主记录对应多个字段（如 inspection、autoPhone 等）
--    field_key 对应列配置表的 field_key
--    field_status 存储该字段的状态（normal=正常✓ / other=其他+文本 / 空=未填写）
-- -----------------------------------------------------------
CREATE TABLE daily_handover_item (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  handover_id   BIGINT UNSIGNED NOT NULL                  COMMENT '关联主表 daily_handover.id',
  field_key     VARCHAR(50)   NOT NULL                    COMMENT '字段标识（如 inspection, autoPhone）',
  field_value   TEXT          DEFAULT NULL                COMMENT '字段文本值（status=other 时使用）',
  field_status  ENUM('', 'normal', 'other') NOT NULL DEFAULT '' COMMENT '状态：空=未填写, normal=正常, other=其他',
  sort_order    INT           NOT NULL DEFAULT 0          COMMENT '字段排序号（冗余，便于查询）',
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_handover_field (handover_id, field_key),
  KEY idx_handover_id (handover_id),
  CONSTRAINT fk_item_handover FOREIGN KEY (handover_id)
    REFERENCES daily_handover(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='交接明细表（动态字段值）';


-- -----------------------------------------------------------
-- 3. 列配置表：daily_handover_field_config
--    定义表格中有哪些列，支持动态新增/隐藏
--    is_system=1 为系统预置字段，前端不允许删除
--    is_visible=0 时前端不显示该列，但数据保留
-- -----------------------------------------------------------
CREATE TABLE daily_handover_field_config (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  field_key     VARCHAR(50)   NOT NULL UNIQUE              COMMENT '字段标识（英文，如 inspection）',
  field_label   VARCHAR(100)  NOT NULL                     COMMENT '列显示名称（如 机房巡检）',
  is_visible    TINYINT       NOT NULL DEFAULT 1           COMMENT '是否显示 1-显示 0-隐藏',
  sort_order    INT           NOT NULL DEFAULT 0           COMMENT '列排序号',
  is_system     TINYINT       NOT NULL DEFAULT 0           COMMENT '是否系统预置 1-预置 0-自定义',
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='交接字段列配置表';


-- -----------------------------------------------------------
-- 4. 预置字段数据（初始化时执行）
-- -----------------------------------------------------------
INSERT INTO daily_handover_field_config
  (field_key, field_label, sort_order, is_system, is_visible)
VALUES
  ('inspection',    '机房巡检',       1,  1, 1),
  ('autoPhone',     '自动话平台',     2,  1, 1),
  ('netapp',        'netapp',         3,  1, 1),
  ('nbu',           'NBU',            4,  1, 1),
  ('controlM',      'control-m',      5,  1, 1),
  ('h3c',           'H3C',            6,  1, 1),
  ('newEmail',      '新邮件测试',     7,  1, 1),
  ('vpn',           'vpn',            8,  1, 1),
  ('serverPhone',   '服务器电话',     9,  1, 1),
  ('collaboration', '协同办公平台',  10,  1, 1),
  ('remark',        '备注',          11,  1, 1);
