-- 医学科普原数据采集：来源、入口、批次和原数据记录。
-- 适用 MySQL 8.4。按依赖顺序建表；如果已有同名表，请先核对结构。
-- 原件保存到 OSS，数据库保存采集记录、出处和对象位置。
USE med_knowledge_graph;

-- 1. 来源：一个网站、平台或数据集只登记一次。
CREATE TABLE medkg_raw_source (
    source_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '来源ID',
    source_code   VARCHAR(64)  NOT NULL COMMENT '稳定的来源编码，例如 china_cdc',
    source_name   VARCHAR(128) NOT NULL COMMENT '来源名称，例如中国疾病预防控制中心',
    homepage_url  TEXT         NOT NULL COMMENT '官方网站或数据集主页',
    terms_url     TEXT                  COMMENT '版权、许可或数据使用说明地址',
    remark        VARCHAR(500)          COMMENT '来源说明',
    create_time   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '登记时间',
    update_time   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    PRIMARY KEY (source_id),
    UNIQUE KEY uk_raw_source_code (source_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='原数据来源';

-- 2. 入口：同一来源下的栏目、接口或下载地址可以分别启用。
CREATE TABLE medkg_raw_entry (
    entry_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '入口ID',
    source_id        BIGINT UNSIGNED NOT NULL COMMENT '所属来源ID',
    entry_code       VARCHAR(64)  NOT NULL COMMENT '来源内的入口编码',
    entry_name       VARCHAR(128) NOT NULL COMMENT '栏目、接口或数据包名称',
    entry_url        TEXT         NOT NULL COMMENT '起始页面、接口或下载地址',
    entry_type       ENUM('PAGE', 'API', 'FILE') NOT NULL
                     COMMENT '获取方式：网页、接口、文件下载',
    expected_format  VARCHAR(32) COMMENT '预期格式，例如JSON、PDF；混合入口可留空',
    entry_status     ENUM('PENDING', 'ENABLED', 'DISABLED') NOT NULL DEFAULT 'PENDING'
                     COMMENT '待确认、已启用、已停用',
    usage_note       VARCHAR(1000) COMMENT '该入口的使用条件、许可依据或采集范围说明',
    create_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    PRIMARY KEY (entry_id),
    UNIQUE KEY uk_raw_entry_code (source_id, entry_code),
    CONSTRAINT fk_raw_entry_source
        FOREIGN KEY (source_id) REFERENCES medkg_raw_source (source_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='原数据采集入口';

-- 3. 批次：一次运行对应一个入口。成功和失败的原件数量按明细状态统计。
CREATE TABLE medkg_raw_batch (
    batch_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '批次ID',
    entry_id       BIGINT UNSIGNED NOT NULL COMMENT '本轮采集的入口ID',
    batch_no       VARCHAR(64) NOT NULL COMMENT '唯一批次编号，供管理页面查询',
    trigger_type   ENUM('MANUAL', 'SCHEDULED') NOT NULL COMMENT '手动或定时触发',
    batch_status   ENUM('PENDING', 'RUNNING', 'SUCCESS', 'PARTIAL', 'FAILED', 'CANCELLED')
                   NOT NULL DEFAULT 'PENDING' COMMENT '批次状态，PARTIAL表示部分成功',
    started_at     DATETIME COMMENT '实际开始时间',
    finished_at    DATETIME COMMENT '结束时间',
    error_summary  VARCHAR(1000) COMMENT '批次级错误摘要',
    create_time    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    PRIMARY KEY (batch_id),
    UNIQUE KEY uk_raw_batch_no (batch_no),
    KEY idx_raw_batch_entry_time (entry_id, create_time),
    CONSTRAINT fk_raw_batch_entry
        FOREIGN KEY (entry_id) REFERENCES medkg_raw_entry (entry_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='原数据采集批次';

-- 4. 原数据：一个网页、一份附件或一页API响应各占一条记录。
-- 同批次重复请求复用原记录；跨批次保留历史。相同内容可复用同一个OSS对象。
-- 两个哈希字段均保存32字节摘要。若传入64位十六进制摘要，可用UNHEX()转换。
CREATE TABLE medkg_raw_item (
    item_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '原数据记录ID',
    batch_id         BIGINT UNSIGNED NOT NULL COMMENT '所属批次ID',
    parent_item_id   BIGINT UNSIGNED COMMENT '同批次父记录ID，例如首次发现附件的通知网页',

    origin_url       TEXT NOT NULL COMMENT '原始页面、附件或API地址，不含访问密钥',
    request_method   ENUM('GET', 'POST') NOT NULL DEFAULT 'GET' COMMENT '请求方式',
    request_params   JSON COMMENT '用于重试的业务参数，例如页码，不含访问凭据',
    request_hash     BINARY(32) NOT NULL COMMENT '请求方式、规范化地址和业务参数的SHA-256，用于同批次去重',

    title            VARCHAR(512) COMMENT '资料标题，能取得时填写',
    original_name    VARCHAR(512) COMMENT '来源提供的文件名',
    raw_format       VARCHAR(32)  COMMENT '实际原件格式，例如HTML、JSON、PDF、DOCX',
    content_type     VARCHAR(255) COMMENT '来源返回的Content-Type',

    item_status      ENUM('PENDING', 'RUNNING', 'STORED', 'FAILED')
                     NOT NULL DEFAULT 'PENDING' COMMENT '待采集、处理中、已存储、失败',
    attempt_count    INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '已尝试次数',
    last_error       VARCHAR(1000) COMMENT '最近一次失败原因',
    fetched_at       DATETIME COMMENT '取得原始内容的时间',

    oss_bucket       VARCHAR(63) CHARACTER SET ascii COLLATE ascii_bin COMMENT 'OSS Bucket名称',
    oss_object_key   VARCHAR(1023) COLLATE utf8mb4_bin COMMENT 'OSS原始文件的对象Key',
    file_size        BIGINT UNSIGNED COMMENT '原始文件字节数',
    content_sha256   BINARY(32) COMMENT '原始文件内容的SHA-256',

    create_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发现这份资料的时间',
    update_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP COMMENT '最近处理时间',

    PRIMARY KEY (item_id),
    UNIQUE KEY uk_raw_item_request (batch_id, request_hash),
    UNIQUE KEY uk_raw_item_batch_item (batch_id, item_id),
    KEY idx_raw_item_parent (batch_id, parent_item_id),
    KEY idx_raw_item_status (batch_id, item_status),
    KEY idx_raw_item_content (content_sha256),

    CONSTRAINT fk_raw_item_batch
        FOREIGN KEY (batch_id) REFERENCES medkg_raw_batch (batch_id),
    CONSTRAINT fk_raw_item_parent
        FOREIGN KEY (batch_id, parent_item_id)
        REFERENCES medkg_raw_item (batch_id, item_id),
    CONSTRAINT ck_raw_item_stored CHECK (
        item_status <> 'STORED' OR (
            fetched_at IS NOT NULL AND file_size IS NOT NULL
            AND content_sha256 IS NOT NULL
            AND raw_format IS NOT NULL AND CHAR_LENGTH(raw_format) > 0
            AND oss_bucket IS NOT NULL AND CHAR_LENGTH(oss_bucket) > 0
            AND oss_object_key IS NOT NULL
            AND OCTET_LENGTH(oss_object_key) BETWEEN 1 AND 1023
        )
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='原数据采集记录及OSS文件索引';
