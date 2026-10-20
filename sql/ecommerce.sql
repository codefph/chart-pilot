CREATE DATABASE IF NOT EXISTS chart_pilot_ecommerce
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE chart_pilot_ecommerce;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(254) NOT NULL,
  phone VARCHAR(32) NULL,
  display_name VARCHAR(100) NOT NULL,
  status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  KEY idx_users_status_created (status, created_at)
) ENGINE=InnoDB COMMENT='Registered storefront customers';

CREATE TABLE IF NOT EXISTS addresses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  recipient_name VARCHAR(100) NOT NULL,
  recipient_phone VARCHAR(32) NOT NULL,
  country_code CHAR(2) NOT NULL DEFAULT 'CN',
  province VARCHAR(80) NOT NULL,
  city VARCHAR(80) NOT NULL,
  district VARCHAR(80) NULL,
  postal_code VARCHAR(20) NULL,
  address_line VARCHAR(255) NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_addresses_user_default (user_id, is_default),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='Customer shipping addresses';

CREATE TABLE IF NOT EXISTS categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_id BIGINT UNSIGNED NULL,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_categories_slug (slug),
  KEY idx_categories_parent_status (parent_id, status),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB COMMENT='Hierarchical product catalog categories';

CREATE TABLE IF NOT EXISTS products (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(180) NOT NULL,
  brand VARCHAR(100) NOT NULL,
  description TEXT NULL,
  status ENUM('draft', 'active', 'inactive') NOT NULL DEFAULT 'active',
  list_price DECIMAL(12,2) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_products_category_status (category_id, status),
  KEY idx_products_status_created (status, created_at),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Sellable product listings';

CREATE TABLE IF NOT EXISTS product_skus (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  sku_code VARCHAR(64) NOT NULL,
  attributes JSON NULL,
  price DECIMAL(12,2) NULL,
  status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_product_skus_code (sku_code),
  KEY idx_product_skus_product_status (product_id, status),
  CONSTRAINT fk_product_skus_product FOREIGN KEY (product_id) REFERENCES products (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='Product variants and sellable SKU codes';

CREATE TABLE IF NOT EXISTS inventory (
  sku_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 0,
  reserved_quantity INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (sku_id),
  CONSTRAINT fk_inventory_sku FOREIGN KEY (sku_id) REFERENCES product_skus (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='On-hand and reserved inventory by SKU';

CREATE TABLE IF NOT EXISTS coupons (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(40) NOT NULL,
  discount_type ENUM('fixed', 'percent') NOT NULL,
  discount_value DECIMAL(10,2) NOT NULL,
  minimum_subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  starts_at DATETIME(3) NOT NULL,
  ends_at DATETIME(3) NOT NULL,
  usage_limit INT UNSIGNED NULL,
  status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_coupons_code (code),
  KEY idx_coupons_status_dates (status, starts_at, ends_at)
) ENGINE=InnoDB COMMENT='Promotional coupon definitions';

CREATE TABLE IF NOT EXISTS orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_no VARCHAR(40) NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  shipping_address_id BIGINT UNSIGNED NULL,
  status ENUM('pending_payment', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')
    NOT NULL DEFAULT 'pending_payment',
  payment_status ENUM('pending', 'paid', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
  fulfillment_status ENUM('unfulfilled', 'partial', 'fulfilled', 'returned')
    NOT NULL DEFAULT 'unfulfilled',
  currency CHAR(3) NOT NULL DEFAULT 'CNY',
  subtotal DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  shipping_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_amount DECIMAL(12,2) NOT NULL,
  customer_note VARCHAR(500) NULL,
  placed_at DATETIME(3) NOT NULL,
  paid_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_order_no (order_no),
  KEY idx_orders_user_placed (user_id, placed_at),
  KEY idx_orders_status_placed (status, placed_at),
  KEY idx_orders_payment_status_placed (payment_status, placed_at),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_shipping_address FOREIGN KEY (shipping_address_id) REFERENCES addresses (id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB COMMENT='Order headers and lifecycle status';

CREATE TABLE IF NOT EXISTS order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NULL,
  sku_id BIGINT UNSIGNED NULL,
  product_name_snapshot VARCHAR(180) NOT NULL,
  sku_code_snapshot VARCHAR(64) NULL,
  quantity INT UNSIGNED NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  line_amount DECIMAL(12,2) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_order_items_order (order_id),
  KEY idx_order_items_product (product_id),
  KEY idx_order_items_sku (sku_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders (id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_order_items_sku FOREIGN KEY (sku_id) REFERENCES product_skus (id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB COMMENT='Order line items with purchase-time snapshots';

CREATE TABLE IF NOT EXISTS order_coupons (
  order_id BIGINT UNSIGNED NOT NULL,
  coupon_id BIGINT UNSIGNED NOT NULL,
  discount_amount DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (order_id, coupon_id),
  KEY idx_order_coupons_coupon (coupon_id),
  CONSTRAINT fk_order_coupons_order FOREIGN KEY (order_id) REFERENCES orders (id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_coupons_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Coupons applied to orders';

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  payment_no VARCHAR(64) NOT NULL,
  provider_transaction_no VARCHAR(100) NULL,
  method ENUM('alipay', 'wechat_pay', 'bank_card', 'cash_on_delivery') NOT NULL,
  status ENUM('pending', 'succeeded', 'failed', 'refunded') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  paid_at DATETIME(3) NULL,
  refunded_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_payments_payment_no (payment_no),
  UNIQUE KEY uk_payments_provider_transaction (provider_transaction_no),
  KEY idx_payments_order_status (order_id, status),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Payment attempts, captures, and refunds';

CREATE TABLE IF NOT EXISTS shipments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  carrier VARCHAR(80) NOT NULL,
  tracking_no VARCHAR(100) NOT NULL,
  status ENUM('label_created', 'in_transit', 'delivered', 'exception', 'returned') NOT NULL,
  shipped_at DATETIME(3) NULL,
  delivered_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_shipments_tracking_no (tracking_no),
  KEY idx_shipments_order_status (order_id, status),
  CONSTRAINT fk_shipments_order FOREIGN KEY (order_id) REFERENCES orders (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Carrier and delivery tracking records';

CREATE TABLE IF NOT EXISTS reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  content VARCHAR(1000) NULL,
  status ENUM('pending', 'published', 'hidden') NOT NULL DEFAULT 'published',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_reviews_order_item (order_item_id),
  KEY idx_reviews_product_status_created (product_id, status, created_at),
  KEY idx_reviews_user_created (user_id, created_at),
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reviews_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='Verified-purchase product reviews';

INSERT IGNORE INTO users (id, email, phone, display_name, status, created_at) VALUES
  (1, 'lin.yu@example.test', '13800000001', '林宇', 'active', '2025-09-12 09:20:00.000'),
  (2, 'chen.mei@example.test', '13800000002', '陈梅', 'active', '2025-09-18 13:45:00.000'),
  (3, 'wang.hao@example.test', '13800000003', '王浩', 'active', '2025-10-02 11:12:00.000'),
  (4, 'zhou.qi@example.test', '13800000004', '周琪', 'active', '2025-10-08 16:30:00.000'),
  (5, 'zhao.an@example.test', '13800000005', '赵安', 'active', '2025-10-21 08:05:00.000'),
  (6, 'liu.xin@example.test', '13800000006', '刘欣', 'active', '2025-11-03 10:40:00.000'),
  (7, 'sun.jie@example.test', '13800000007', '孙杰', 'active', '2025-11-15 19:22:00.000'),
  (8, 'wu.tong@example.test', '13800000008', '吴桐', 'active', '2025-11-22 14:17:00.000'),
  (9, 'zheng.yi@example.test', '13800000009', '郑怡', 'active', '2025-12-01 12:00:00.000'),
  (10, 'feng.kai@example.test', '13800000010', '冯凯', 'active', '2025-12-09 18:31:00.000'),
  (11, 'he.qing@example.test', '13800000011', '何晴', 'active', '2025-12-18 09:48:00.000'),
  (12, 'xu.ming@example.test', '13800000012', '徐明', 'active', '2026-01-04 15:26:00.000'),
  (13, 'gao.yan@example.test', '13800000013', '高妍', 'active', '2026-02-10 10:03:00.000'),
  (14, 'tang.bo@example.test', '13800000014', '唐博', 'active', '2026-03-11 17:52:00.000'),
  (15, 'peng.le@example.test', '13800000015', '彭乐', 'active', '2026-04-06 12:44:00.000'),
  (16, 'ma.nuo@example.test', '13800000016', '马诺', 'active', '2026-05-19 20:16:00.000');

INSERT IGNORE INTO addresses
  (id, user_id, recipient_name, recipient_phone, country_code, province, city, district, postal_code, address_line, is_default)
VALUES
  (1, 1, '林宇', '13800000001', 'CN', '上海市', '上海市', '浦东新区', '200120', '世纪大道 100 号', 1),
  (2, 2, '陈梅', '13800000002', 'CN', '北京市', '北京市', '朝阳区', '100020', '建国路 88 号', 1),
  (3, 3, '王浩', '13800000003', 'CN', '广东省', '深圳市', '南山区', '518000', '科技园南区 12 号', 1),
  (4, 4, '周琪', '13800000004', 'CN', '浙江省', '杭州市', '西湖区', '310000', '文三路 188 号', 1),
  (5, 5, '赵安', '13800000005', 'CN', '江苏省', '南京市', '鼓楼区', '210000', '中山北路 66 号', 1),
  (6, 6, '刘欣', '13800000006', 'CN', '四川省', '成都市', '武侯区', '610000', '天府大道 500 号', 1),
  (7, 7, '孙杰', '13800000007', 'CN', '湖北省', '武汉市', '洪山区', '430070', '光谷大道 77 号', 1),
  (8, 8, '吴桐', '13800000008', 'CN', '陕西省', '西安市', '雁塔区', '710000', '科技二路 36 号', 1),
  (9, 9, '郑怡', '13800000009', 'CN', '山东省', '青岛市', '市南区', '266000', '香港中路 20 号', 1),
  (10, 10, '冯凯', '13800000010', 'CN', '福建省', '厦门市', '思明区', '361000', '湖滨南路 101 号', 1),
  (11, 11, '何晴', '13800000011', 'CN', '湖南省', '长沙市', '岳麓区', '410000', '麓谷街道 8 号', 1),
  (12, 12, '徐明', '13800000012', 'CN', '重庆市', '重庆市', '渝中区', '400010', '解放碑民权路 28 号', 1),
  (13, 13, '高妍', '13800000013', 'CN', '河南省', '郑州市', '金水区', '450000', '农业路 15 号', 1),
  (14, 14, '唐博', '13800000014', 'CN', '云南省', '昆明市', '五华区', '650000', '人民西路 203 号', 1),
  (15, 15, '彭乐', '13800000015', 'CN', '辽宁省', '沈阳市', '和平区', '110000', '青年大街 90 号', 1),
  (16, 16, '马诺', '13800000016', 'CN', '天津市', '天津市', '南开区', '300100', '卫津路 45 号', 1);

INSERT IGNORE INTO categories (id, parent_id, name, slug, sort_order, status) VALUES
  (1, NULL, '数码电子', 'digital-electronics', 1, 'active'),
  (2, NULL, '办公用品', 'office', 2, 'active'),
  (3, NULL, '户外运动', 'outdoor', 3, 'active'),
  (4, NULL, '食品饮料', 'food-drink', 4, 'active'),
  (5, 1, '电脑外设', 'computer-accessories', 1, 'active'),
  (6, 1, '影音设备', 'audio-video', 2, 'active'),
  (7, 2, '办公家具', 'office-furniture', 1, 'active'),
  (8, 3, '运动装备', 'sports-gear', 1, 'active');

INSERT IGNORE INTO products (id, category_id, name, brand, description, status, list_price, created_at) VALUES
  (1, 5, '无线机械键盘', 'KeyWorks', '87 键无线机械键盘，支持蓝牙与 USB-C。', 'active', 459.00, '2025-08-15 09:00:00.000'),
  (2, 5, '人体工学无线鼠标', 'KeyWorks', '可调 DPI 无线鼠标，适合办公与日常使用。', 'active', 129.00, '2025-08-18 09:00:00.000'),
  (3, 6, '主动降噪耳机', 'SoundPeak', '头戴式主动降噪耳机，支持多设备连接。', 'active', 799.00, '2025-08-20 09:00:00.000'),
  (4, 5, '4K 显示器 27 英寸', 'ViewMax', '4K 分辨率 IPS 显示器，支持高度调节。', 'active', 1299.00, '2025-08-24 09:00:00.000'),
  (5, 7, '人体工学办公椅', 'WorkWell', '网布靠背办公椅，支持腰靠和座高调节。', 'active', 1599.00, '2025-08-28 09:00:00.000'),
  (6, 5, 'USB-C 多功能扩展坞', 'ConnectPro', '八合一扩展坞，含 HDMI、USB-A 和读卡器。', 'active', 189.00, '2025-09-02 09:00:00.000'),
  (7, 6, '高清网络摄像头', 'ViewMax', '1080p 自动对焦摄像头，内置双麦克风。', 'active', 399.00, '2025-09-05 09:00:00.000'),
  (8, 6, 'USB 电容麦克风', 'SoundPeak', '适用于会议与直播的 USB 电容麦克风。', 'active', 699.00, '2025-09-08 09:00:00.000'),
  (9, 2, '铝合金笔记本支架', 'WorkWell', '可调节高度铝合金笔记本电脑支架。', 'active', 159.00, '2025-09-11 09:00:00.000'),
  (10, 2, 'LED 护眼台灯', 'BrightHome', '无频闪 LED 台灯，亮度和色温可调节。', 'active', 229.00, '2025-09-14 09:00:00.000'),
  (11, 1, '20,000mAh 快充充电宝', 'ConnectPro', '支持 USB-C 双向快充的便携充电宝。', 'active', 199.00, '2025-09-18 09:00:00.000'),
  (12, 6, '蓝牙桌面音箱', 'SoundPeak', '双单元桌面蓝牙音箱，支持立体声播放。', 'active', 549.00, '2025-09-22 09:00:00.000'),
  (13, 8, '轻量缓震跑步鞋', 'TrailWay', '轻量网面跑步鞋，适合日常训练。', 'active', 499.00, '2025-09-25 09:00:00.000'),
  (14, 3, '城市通勤双肩包', 'TrailWay', '带笔记本电脑隔层的防泼水通勤背包。', 'active', 359.00, '2025-09-28 09:00:00.000'),
  (15, 4, '精品烘焙咖啡豆 500g', 'DailyRoast', '中度烘焙阿拉比卡咖啡豆，净含量 500g。', 'active', 89.90, '2025-10-01 09:00:00.000'),
  (16, 5, '便携蓝牙鼠标', 'KeyWorks', '轻量便携蓝牙鼠标，适用于笔记本电脑。', 'inactive', 99.00, '2025-10-03 09:00:00.000');

INSERT IGNORE INTO product_skus (id, product_id, sku_code, attributes, price, status) VALUES
  (1, 1, 'KW-KB87-BLK', JSON_OBJECT('color', '黑色', 'layout', '87键'), 459.00, 'active'),
  (2, 2, 'KW-MOUSE-GR', JSON_OBJECT('color', '石墨灰'), 129.00, 'active'),
  (3, 3, 'SP-ANC-BLK', JSON_OBJECT('color', '曜石黑'), 799.00, 'active'),
  (4, 4, 'VM-4K27-BLK', JSON_OBJECT('color', '黑色', 'size', '27英寸'), 1299.00, 'active'),
  (5, 5, 'WW-CHAIR-GR', JSON_OBJECT('color', '深灰'), 1599.00, 'active'),
  (6, 6, 'CP-HUB-8IN1', JSON_OBJECT('color', '银色'), 189.00, 'active'),
  (7, 7, 'VM-CAM-1080', JSON_OBJECT('color', '黑色'), 399.00, 'active'),
  (8, 8, 'SP-MIC-USB', JSON_OBJECT('color', '黑色'), 699.00, 'active'),
  (9, 9, 'WW-STAND-SLV', JSON_OBJECT('color', '银色'), 159.00, 'active'),
  (10, 10, 'BH-LAMP-WHT', JSON_OBJECT('color', '白色'), 229.00, 'active'),
  (11, 11, 'CP-PB-20K', JSON_OBJECT('color', '深空灰'), 199.00, 'active'),
  (12, 12, 'SP-SPEAKER-BLK', JSON_OBJECT('color', '黑色'), 549.00, 'active'),
  (13, 13, 'TW-RUN-42', JSON_OBJECT('color', '蓝色', 'size', '42'), 499.00, 'active'),
  (14, 14, 'TW-BAG-20L', JSON_OBJECT('color', '海军蓝', 'capacity', '20L'), 359.00, 'active'),
  (15, 15, 'DR-COFFEE-500', JSON_OBJECT('roast', '中度烘焙', 'weight', '500g'), 89.90, 'active'),
  (16, 16, 'KW-MOUSE-TRV', JSON_OBJECT('color', '白色'), 99.00, 'inactive');

INSERT IGNORE INTO inventory (sku_id, quantity, reserved_quantity) VALUES
  (1, 85, 2), (2, 142, 4), (3, 38, 1), (4, 24, 1),
  (5, 12, 0), (6, 96, 3), (7, 57, 1), (8, 29, 0),
  (9, 118, 2), (10, 74, 1), (11, 103, 2), (12, 45, 1),
  (13, 33, 0), (14, 61, 2), (15, 210, 5), (16, 0, 0);

INSERT IGNORE INTO coupons
  (id, code, discount_type, discount_value, minimum_subtotal, starts_at, ends_at, usage_limit, status)
VALUES
  (1, 'WELCOME50', 'fixed', 50.00, 199.00, '2025-01-01 00:00:00.000', '2027-12-31 23:59:59.000', 1000, 'active'),
  (2, 'SPRING10', 'percent', 10.00, 300.00, '2026-03-01 00:00:00.000', '2026-05-31 23:59:59.000', 500, 'active'),
  (3, 'SUMMER30', 'fixed', 30.00, 500.00, '2026-06-01 00:00:00.000', '2026-08-31 23:59:59.000', 300, 'active');

INSERT IGNORE INTO orders
  (id, order_no, user_id, shipping_address_id, status, payment_status, fulfillment_status, currency,
   subtotal, discount_amount, shipping_fee, total_amount, placed_at, paid_at)
VALUES
  (1, 'CP202510050001', 1, 1, 'delivered', 'paid', 'fulfilled', 'CNY', 129.00, 0.00, 10.00, 139.00, '2025-10-05 10:12:00.000', '2025-10-05 10:14:00.000'),
  (2, 'CP202510120002', 2, 2, 'delivered', 'paid', 'fulfilled', 'CNY', 459.00, 50.00, 0.00, 409.00, '2025-10-12 15:32:00.000', '2025-10-12 15:34:00.000'),
  (3, 'CP202511020003', 3, 3, 'delivered', 'paid', 'fulfilled', 'CNY', 799.00, 0.00, 0.00, 799.00, '2025-11-02 11:05:00.000', '2025-11-02 11:06:00.000'),
  (4, 'CP202511110004', 4, 4, 'delivered', 'paid', 'fulfilled', 'CNY', 258.00, 0.00, 10.00, 268.00, '2025-11-11 19:42:00.000', '2025-11-11 19:44:00.000'),
  (5, 'CP202511260005', 5, 5, 'delivered', 'paid', 'fulfilled', 'CNY', 179.80, 0.00, 0.00, 179.80, '2025-11-26 09:18:00.000', '2025-11-26 09:20:00.000'),
  (6, 'CP202512030006', 6, 6, 'delivered', 'paid', 'fulfilled', 'CNY', 1299.00, 0.00, 0.00, 1299.00, '2025-12-03 14:21:00.000', '2025-12-03 14:23:00.000'),
  (7, 'CP202512120007', 7, 7, 'refunded', 'refunded', 'returned', 'CNY', 199.00, 0.00, 10.00, 209.00, '2025-12-12 16:07:00.000', '2025-12-12 16:08:00.000'),
  (8, 'CP202512240008', 8, 8, 'delivered', 'paid', 'fulfilled', 'CNY', 1599.00, 0.00, 0.00, 1599.00, '2025-12-24 20:31:00.000', '2025-12-24 20:33:00.000'),
  (9, 'CP202601050009', 9, 9, 'delivered', 'paid', 'fulfilled', 'CNY', 229.00, 0.00, 10.00, 239.00, '2026-01-05 08:51:00.000', '2026-01-05 08:53:00.000'),
  (10, 'CP202601170010', 10, 10, 'delivered', 'paid', 'fulfilled', 'CNY', 189.00, 0.00, 10.00, 199.00, '2026-01-17 12:26:00.000', '2026-01-17 12:28:00.000'),
  (11, 'CP202602040011', 11, 11, 'delivered', 'paid', 'fulfilled', 'CNY', 399.00, 0.00, 0.00, 399.00, '2026-02-04 18:15:00.000', '2026-02-04 18:18:00.000'),
  (12, 'CP202602200012', 12, 12, 'shipped', 'paid', 'fulfilled', 'CNY', 549.00, 0.00, 0.00, 549.00, '2026-02-20 10:44:00.000', '2026-02-20 10:46:00.000'),
  (13, 'CP202603030013', 1, 1, 'delivered', 'paid', 'fulfilled', 'CNY', 359.00, 0.00, 0.00, 359.00, '2026-03-03 13:09:00.000', '2026-03-03 13:11:00.000'),
  (14, 'CP202603140014', 2, 2, 'delivered', 'paid', 'fulfilled', 'CNY', 318.00, 0.00, 10.00, 328.00, '2026-03-14 17:55:00.000', '2026-03-14 17:57:00.000'),
  (15, 'CP202604010015', 3, 3, 'delivered', 'paid', 'fulfilled', 'CNY', 499.00, 0.00, 0.00, 499.00, '2026-04-01 09:33:00.000', '2026-04-01 09:35:00.000'),
  (16, 'CP202604180016', 4, 4, 'cancelled', 'failed', 'unfulfilled', 'CNY', 459.00, 0.00, 10.00, 469.00, '2026-04-18 21:14:00.000', NULL),
  (17, 'CP202605060017', 5, 5, 'delivered', 'paid', 'fulfilled', 'CNY', 129.00, 0.00, 10.00, 139.00, '2026-05-06 11:28:00.000', '2026-05-06 11:30:00.000'),
  (18, 'CP202605210018', 6, 6, 'delivered', 'paid', 'fulfilled', 'CNY', 1599.00, 100.00, 0.00, 1499.00, '2026-05-21 16:02:00.000', '2026-05-21 16:04:00.000'),
  (19, 'CP202606020019', 7, 7, 'paid', 'paid', 'unfulfilled', 'CNY', 89.90, 0.00, 10.00, 99.90, '2026-06-02 08:37:00.000', '2026-06-02 08:40:00.000'),
  (20, 'CP202606170020', 8, 8, 'processing', 'paid', 'unfulfilled', 'CNY', 699.00, 0.00, 0.00, 699.00, '2026-06-17 14:48:00.000', '2026-06-17 14:51:00.000'),
  (21, 'CP202607080021', 9, 9, 'delivered', 'paid', 'fulfilled', 'CNY', 549.00, 0.00, 0.00, 549.00, '2026-07-08 10:16:00.000', '2026-07-08 10:18:00.000'),
  (22, 'CP202608120022', 10, 10, 'paid', 'paid', 'unfulfilled', 'CNY', 398.00, 30.00, 0.00, 368.00, '2026-08-12 19:24:00.000', '2026-08-12 19:27:00.000'),
  (23, 'CP202609100023', 11, 11, 'pending_payment', 'pending', 'unfulfilled', 'CNY', 229.00, 0.00, 10.00, 239.00, '2026-09-10 12:03:00.000', NULL),
  (24, 'CP202610040024', 12, 12, 'delivered', 'paid', 'fulfilled', 'CNY', 2598.00, 0.00, 0.00, 2598.00, '2026-10-04 15:41:00.000', '2026-10-04 15:43:00.000');

INSERT IGNORE INTO order_items
  (id, order_id, product_id, sku_id, product_name_snapshot, sku_code_snapshot,
   quantity, unit_price, discount_amount, line_amount)
VALUES
  (1, 1, 2, 2, '人体工学无线鼠标', 'KW-MOUSE-GR', 1, 129.00, 0.00, 129.00),
  (2, 2, 1, 1, '无线机械键盘', 'KW-KB87-BLK', 1, 459.00, 0.00, 459.00),
  (3, 3, 3, 3, '主动降噪耳机', 'SP-ANC-BLK', 1, 799.00, 0.00, 799.00),
  (4, 4, 2, 2, '人体工学无线鼠标', 'KW-MOUSE-GR', 2, 129.00, 0.00, 258.00),
  (5, 5, 15, 15, '精品烘焙咖啡豆 500g', 'DR-COFFEE-500', 2, 89.90, 0.00, 179.80),
  (6, 6, 4, 4, '4K 显示器 27 英寸', 'VM-4K27-BLK', 1, 1299.00, 0.00, 1299.00),
  (7, 7, 11, 11, '20,000mAh 快充充电宝', 'CP-PB-20K', 1, 199.00, 0.00, 199.00),
  (8, 8, 5, 5, '人体工学办公椅', 'WW-CHAIR-GR', 1, 1599.00, 0.00, 1599.00),
  (9, 9, 10, 10, 'LED 护眼台灯', 'BH-LAMP-WHT', 1, 229.00, 0.00, 229.00),
  (10, 10, 6, 6, 'USB-C 多功能扩展坞', 'CP-HUB-8IN1', 1, 189.00, 0.00, 189.00),
  (11, 11, 7, 7, '高清网络摄像头', 'VM-CAM-1080', 1, 399.00, 0.00, 399.00),
  (12, 12, 12, 12, '蓝牙桌面音箱', 'SP-SPEAKER-BLK', 1, 549.00, 0.00, 549.00),
  (13, 13, 14, 14, '城市通勤双肩包', 'TW-BAG-20L', 1, 359.00, 0.00, 359.00),
  (14, 14, 9, 9, '铝合金笔记本支架', 'WW-STAND-SLV', 2, 159.00, 0.00, 318.00),
  (15, 15, 13, 13, '轻量缓震跑步鞋', 'TW-RUN-42', 1, 499.00, 0.00, 499.00),
  (16, 16, 1, 1, '无线机械键盘', 'KW-KB87-BLK', 1, 459.00, 0.00, 459.00),
  (17, 17, 2, 2, '人体工学无线鼠标', 'KW-MOUSE-GR', 1, 129.00, 0.00, 129.00),
  (18, 18, 5, 5, '人体工学办公椅', 'WW-CHAIR-GR', 1, 1599.00, 0.00, 1599.00),
  (19, 19, 15, 15, '精品烘焙咖啡豆 500g', 'DR-COFFEE-500', 1, 89.90, 0.00, 89.90),
  (20, 20, 8, 8, 'USB 电容麦克风', 'SP-MIC-USB', 1, 699.00, 0.00, 699.00),
  (21, 21, 12, 12, '蓝牙桌面音箱', 'SP-SPEAKER-BLK', 1, 549.00, 0.00, 549.00),
  (22, 22, 11, 11, '20,000mAh 快充充电宝', 'CP-PB-20K', 2, 199.00, 0.00, 398.00),
  (23, 23, 10, 10, 'LED 护眼台灯', 'BH-LAMP-WHT', 1, 229.00, 0.00, 229.00),
  (24, 24, 4, 4, '4K 显示器 27 英寸', 'VM-4K27-BLK', 2, 1299.00, 0.00, 2598.00);

INSERT IGNORE INTO order_coupons (order_id, coupon_id, discount_amount) VALUES
  (2, 1, 50.00),
  (18, 2, 100.00),
  (22, 3, 30.00);

INSERT IGNORE INTO payments
  (id, order_id, payment_no, provider_transaction_no, method, status, amount, paid_at, refunded_at)
VALUES
  (1, 1, 'PAY-CP-0001', 'WX-20251005-0001', 'wechat_pay', 'succeeded', 139.00, '2025-10-05 10:14:00.000', NULL),
  (2, 2, 'PAY-CP-0002', 'ALI-20251012-0002', 'alipay', 'succeeded', 409.00, '2025-10-12 15:34:00.000', NULL),
  (3, 3, 'PAY-CP-0003', 'WX-20251102-0003', 'wechat_pay', 'succeeded', 799.00, '2025-11-02 11:06:00.000', NULL),
  (4, 4, 'PAY-CP-0004', 'ALI-20251111-0004', 'alipay', 'succeeded', 268.00, '2025-11-11 19:44:00.000', NULL),
  (5, 5, 'PAY-CP-0005', 'WX-20251126-0005', 'wechat_pay', 'succeeded', 179.80, '2025-11-26 09:20:00.000', NULL),
  (6, 6, 'PAY-CP-0006', 'ALI-20251203-0006', 'alipay', 'succeeded', 1299.00, '2025-12-03 14:23:00.000', NULL),
  (7, 7, 'PAY-CP-0007', 'WX-20251212-0007', 'wechat_pay', 'refunded', 209.00, '2025-12-12 16:08:00.000', '2025-12-16 11:15:00.000'),
  (8, 8, 'PAY-CP-0008', 'ALI-20251224-0008', 'alipay', 'succeeded', 1599.00, '2025-12-24 20:33:00.000', NULL),
  (9, 9, 'PAY-CP-0009', 'WX-20260105-0009', 'wechat_pay', 'succeeded', 239.00, '2026-01-05 08:53:00.000', NULL),
  (10, 10, 'PAY-CP-0010', 'ALI-20260117-0010', 'alipay', 'succeeded', 199.00, '2026-01-17 12:28:00.000', NULL),
  (11, 11, 'PAY-CP-0011', 'WX-20260204-0011', 'wechat_pay', 'succeeded', 399.00, '2026-02-04 18:18:00.000', NULL),
  (12, 12, 'PAY-CP-0012', 'ALI-20260220-0012', 'alipay', 'succeeded', 549.00, '2026-02-20 10:46:00.000', NULL),
  (13, 13, 'PAY-CP-0013', 'WX-20260303-0013', 'wechat_pay', 'succeeded', 359.00, '2026-03-03 13:11:00.000', NULL),
  (14, 14, 'PAY-CP-0014', 'ALI-20260314-0014', 'alipay', 'succeeded', 328.00, '2026-03-14 17:57:00.000', NULL),
  (15, 15, 'PAY-CP-0015', 'WX-20260401-0015', 'wechat_pay', 'succeeded', 499.00, '2026-04-01 09:35:00.000', NULL),
  (16, 16, 'PAY-CP-0016', NULL, 'alipay', 'failed', 469.00, NULL, NULL),
  (17, 17, 'PAY-CP-0017', 'WX-20260506-0017', 'wechat_pay', 'succeeded', 139.00, '2026-05-06 11:30:00.000', NULL),
  (18, 18, 'PAY-CP-0018', 'ALI-20260521-0018', 'alipay', 'succeeded', 1499.00, '2026-05-21 16:04:00.000', NULL),
  (19, 19, 'PAY-CP-0019', 'WX-20260602-0019', 'wechat_pay', 'succeeded', 99.90, '2026-06-02 08:40:00.000', NULL),
  (20, 20, 'PAY-CP-0020', 'ALI-20260617-0020', 'alipay', 'succeeded', 699.00, '2026-06-17 14:51:00.000', NULL),
  (21, 21, 'PAY-CP-0021', 'WX-20260708-0021', 'wechat_pay', 'succeeded', 549.00, '2026-07-08 10:18:00.000', NULL),
  (22, 22, 'PAY-CP-0022', 'ALI-20260812-0022', 'alipay', 'succeeded', 368.00, '2026-08-12 19:27:00.000', NULL),
  (23, 23, 'PAY-CP-0023', NULL, 'wechat_pay', 'pending', 239.00, NULL, NULL),
  (24, 24, 'PAY-CP-0024', 'ALI-20261004-0024', 'alipay', 'succeeded', 2598.00, '2026-10-04 15:43:00.000', NULL);

INSERT IGNORE INTO shipments
  (id, order_id, carrier, tracking_no, status, shipped_at, delivered_at)
VALUES
  (1, 1, '顺丰速运', 'SF202510050001', 'delivered', '2025-10-06 09:00:00.000', '2025-10-07 14:20:00.000'),
  (2, 2, '京东物流', 'JD202510120002', 'delivered', '2025-10-13 10:00:00.000', '2025-10-14 16:35:00.000'),
  (3, 3, '中通快递', 'ZT202511020003', 'delivered', '2025-11-03 08:30:00.000', '2025-11-05 12:10:00.000'),
  (4, 4, '圆通速递', 'YT202511110004', 'delivered', '2025-11-12 11:00:00.000', '2025-11-14 17:40:00.000'),
  (5, 5, '韵达快递', 'YD202511260005', 'delivered', '2025-11-27 09:30:00.000', '2025-11-29 13:15:00.000'),
  (6, 6, '顺丰速运', 'SF202512030006', 'delivered', '2025-12-04 10:15:00.000', '2025-12-05 15:45:00.000'),
  (7, 7, '中通快递', 'ZT202512120007', 'returned', '2025-12-13 10:00:00.000', NULL),
  (8, 8, '京东物流', 'JD202512240008', 'delivered', '2025-12-25 08:20:00.000', '2025-12-26 11:30:00.000'),
  (9, 9, '圆通速递', 'YT202601050009', 'delivered', '2026-01-06 09:10:00.000', '2026-01-08 14:05:00.000'),
  (10, 10, '顺丰速运', 'SF202601170010', 'delivered', '2026-01-18 13:00:00.000', '2026-01-19 17:20:00.000'),
  (11, 11, '韵达快递', 'YD202602040011', 'delivered', '2026-02-05 09:45:00.000', '2026-02-07 12:30:00.000'),
  (12, 12, '京东物流', 'JD202602200012', 'in_transit', '2026-02-21 10:00:00.000', NULL),
  (13, 13, '中通快递', 'ZT202603030013', 'delivered', '2026-03-04 08:40:00.000', '2026-03-06 15:55:00.000'),
  (14, 14, '圆通速递', 'YT202603140014', 'delivered', '2026-03-15 11:25:00.000', '2026-03-17 16:10:00.000'),
  (15, 15, '顺丰速运', 'SF202604010015', 'delivered', '2026-04-02 09:00:00.000', '2026-04-03 13:40:00.000'),
  (16, 17, '韵达快递', 'YD202605060017', 'delivered', '2026-05-07 10:10:00.000', '2026-05-09 18:25:00.000'),
  (17, 18, '京东物流', 'JD202605210018', 'delivered', '2026-05-22 08:00:00.000', '2026-05-23 11:50:00.000'),
  (18, 21, '中通快递', 'ZT202607080021', 'delivered', '2026-07-09 09:30:00.000', '2026-07-11 14:45:00.000'),
  (19, 24, '顺丰速运', 'SF202610040024', 'delivered', '2026-10-05 10:00:00.000', '2026-10-06 16:30:00.000');

INSERT IGNORE INTO reviews
  (id, user_id, product_id, order_item_id, rating, content, status, created_at)
VALUES
  (1, 1, 2, 1, 5, '连接稳定，日常办公很顺手。', 'published', '2025-10-10 12:00:00.000'),
  (2, 2, 1, 2, 5, '键盘手感不错，续航也满意。', 'published', '2025-10-18 09:30:00.000'),
  (3, 3, 3, 3, 4, '降噪效果很好，佩戴舒适。', 'published', '2025-11-10 18:00:00.000'),
  (4, 4, 2, 4, 4, '做工扎实，性价比不错。', 'published', '2025-11-20 14:10:00.000'),
  (5, 5, 15, 5, 5, '香气浓郁，烘焙日期很新鲜。', 'published', '2025-12-04 10:20:00.000'),
  (6, 6, 4, 6, 5, '显示清晰，办公体验提升明显。', 'published', '2025-12-12 16:40:00.000'),
  (7, 8, 5, 8, 4, '安装方便，坐感支撑很好。', 'published', '2026-01-07 11:15:00.000'),
  (8, 9, 10, 9, 4, '亮度够用，外观简洁。', 'published', '2026-01-18 13:25:00.000'),
  (9, 11, 7, 11, 5, '视频画面清晰，自动对焦灵敏。', 'published', '2026-02-15 19:05:00.000'),
  (10, 1, 14, 13, 4, '容量合适，通勤背着很舒服。', 'published', '2026-03-16 10:50:00.000'),
  (11, 3, 13, 15, 5, '鞋子轻，跑步缓震不错。', 'published', '2026-04-10 17:30:00.000'),
  (12, 6, 5, 18, 5, '腰部支撑很好，久坐更舒服。', 'published', '2026-05-30 08:45:00.000');
