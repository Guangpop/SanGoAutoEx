# EncryptionManager.gd - 數據加密管理器
#
# 功能：
# - AES-256加密/解密存檔數據
# - 數據完整性驗證和校驗和
# - 安全密鑰管理和生成
# - 防篡改機制

extends Node
class_name EncryptionManager

# 加密配置
const ENCRYPTION_KEY_LENGTH := 32  # AES-256
const IV_LENGTH := 16              # 初始化向量長度
const HASH_LENGTH := 32            # SHA-256哈希長度
const MAGIC_HEADER := "SGX_SAVE"   # 文件標識符
const VERSION := 1                 # 加密版本

# 錯誤碼
enum EncryptionError {
	SUCCESS,
	INVALID_KEY,
	INVALID_DATA,
	CORRUPTION_DETECTED,
	VERSION_MISMATCH,
	DECRYPTION_FAILED,
	UNKNOWN_ERROR
}

# 加密上下文
var encryption_key: PackedByteArray
var device_id: String
var is_initialized: bool = false

func _ready() -> void:
	name = "EncryptionManager"
	LogManager.info("EncryptionManager", "加密管理器初始化")

	# 獲取或生成設備ID
	device_id = _get_or_create_device_id()

	# 初始化加密密鑰
	_initialize_encryption_key()

# === 初始化方法 ===

# 初始化加密密鑰
func _initialize_encryption_key() -> void:
	var stored_key = _load_stored_key()

	if stored_key.is_empty():
		# 生成新的加密密鑰
		encryption_key = _generate_encryption_key()
		_store_encryption_key(encryption_key)
		LogManager.info("EncryptionManager", "生成新的加密密鑰")
	else:
		encryption_key = stored_key
		LogManager.info("EncryptionManager", "載入現有加密密鑰")

	is_initialized = true

# 生成加密密鑰
func _generate_encryption_key() -> PackedByteArray:
	var key = PackedByteArray()
	var crypto = Crypto.new()

	# 使用設備ID和時間戳作為種子
	var seed_data = (device_id + str(Time.get_unix_time_from_system())).to_utf8_buffer()
	var random_bytes = crypto.generate_random_bytes(ENCRYPTION_KEY_LENGTH)

	# 結合種子數據和隨機字節
	for i in range(ENCRYPTION_KEY_LENGTH):
		var seed_byte = seed_data[i % seed_data.size()] if i < seed_data.size() else 0
		var random_byte = random_bytes[i] if i < random_bytes.size() else 0
		key.append((seed_byte ^ random_byte) & 0xFF)

	return key

# 獲取或創建設備ID
func _get_or_create_device_id() -> String:
	var config_file = ConfigFile.new()
	var config_path = "user://device_config.cfg"

	if config_file.load(config_path) == OK:
		var saved_id = config_file.get_value("device", "id", "")
		if saved_id != "":
			return saved_id

	# 生成新的設備ID
	var new_id = _generate_device_id()
	config_file.set_value("device", "id", new_id)
	config_file.save(config_path)

	LogManager.info("EncryptionManager", "生成新設備ID", {"device_id": new_id})
	return new_id

# 生成設備ID
func _generate_device_id() -> String:
	var crypto = Crypto.new()
	var random_bytes = crypto.generate_random_bytes(16)
	return random_bytes.hex_encode()

# === 密鑰存儲管理 ===

# 載入存儲的密鑰
func _load_stored_key() -> PackedByteArray:
	var key_file_path = "user://encryption.key"
	var file = FileAccess.open(key_file_path, FileAccess.READ)

	if file == null:
		return PackedByteArray()

	var encrypted_key = file.get_buffer(file.get_length())
	file.close()

	# 使用設備ID解密密鑰
	return _decrypt_key(encrypted_key)

# 存儲加密密鑰
func _store_encryption_key(key: PackedByteArray) -> void:
	var key_file_path = "user://encryption.key"
	var file = FileAccess.open(key_file_path, FileAccess.WRITE)

	if file == null:
		LogManager.error("EncryptionManager", "無法保存加密密鑰")
		return

	# 使用設備ID加密密鑰
	var encrypted_key = _encrypt_key(key)
	file.store_buffer(encrypted_key)
	file.close()

# 加密密鑰（使用設備ID作為額外保護）
func _encrypt_key(key: PackedByteArray) -> PackedByteArray:
	var device_bytes = device_id.to_utf8_buffer()
	var encrypted = PackedByteArray()

	for i in range(key.size()):
		var device_byte = device_bytes[i % device_bytes.size()]
		encrypted.append((key[i] ^ device_byte) & 0xFF)

	return encrypted

# 解密密鑰
func _decrypt_key(encrypted_key: PackedByteArray) -> PackedByteArray:
	var device_bytes = device_id.to_utf8_buffer()
	var decrypted = PackedByteArray()

	for i in range(encrypted_key.size()):
		var device_byte = device_bytes[i % device_bytes.size()]
		decrypted.append((encrypted_key[i] ^ device_byte) & 0xFF)

	return decrypted

# === 數據加密方法 ===

# 加密數據
func encrypt_data(data: String) -> Dictionary:
	if not is_initialized:
		LogManager.error("EncryptionManager", "加密管理器未初始化")
		return {"error": EncryptionError.INVALID_KEY}

	var crypto = Crypto.new()

	try:
		# 生成隨機IV
		var iv = crypto.generate_random_bytes(IV_LENGTH)

		# 轉換數據為字節數組
		var data_bytes = data.to_utf8_buffer()

		# 計算數據哈希
		var data_hash = crypto.sha256(data_bytes)

		# 準備加密載荷（數據 + 哈希）
		var payload = data_bytes + data_hash

		# AES-256-CBC 加密
		var encrypted_data = crypto.encrypt(Crypto.CIPHER_AES_256_CBC, encryption_key, iv, payload)

		# 創建完整的加密包
		var encrypted_package = _create_encrypted_package(encrypted_data, iv, data_hash)

		LogManager.debug("EncryptionManager", "數據加密成功", {
			"original_size": data.length(),
			"encrypted_size": encrypted_package.size()
		})

		return {
			"success": true,
			"data": encrypted_package,
			"error": EncryptionError.SUCCESS
		}

	except:
		LogManager.error("EncryptionManager", "數據加密失敗")
		return {"error": EncryptionError.UNKNOWN_ERROR}

# 解密數據
func decrypt_data(encrypted_package: PackedByteArray) -> Dictionary:
	if not is_initialized:
		LogManager.error("EncryptionManager", "加密管理器未初始化")
		return {"error": EncryptionError.INVALID_KEY}

	var crypto = Crypto.new()

	try:
		# 解析加密包
		var parse_result = _parse_encrypted_package(encrypted_package)
		if parse_result.has("error"):
			return parse_result

		var encrypted_data = parse_result.encrypted_data
		var iv = parse_result.iv
		var stored_hash = parse_result.hash

		# AES-256-CBC 解密
		var decrypted_payload = crypto.decrypt(Crypto.CIPHER_AES_256_CBC, encryption_key, iv, encrypted_data)

		# 分離數據和哈希
		if decrypted_payload.size() < HASH_LENGTH:
			LogManager.error("EncryptionManager", "解密數據太短")
			return {"error": EncryptionError.CORRUPTION_DETECTED}

		var data_size = decrypted_payload.size() - HASH_LENGTH
		var data_bytes = decrypted_payload.slice(0, data_size)
		var payload_hash = decrypted_payload.slice(data_size)

		# 驗證數據完整性
		var calculated_hash = crypto.sha256(data_bytes)
		if not _compare_hashes(payload_hash, calculated_hash):
			LogManager.error("EncryptionManager", "數據完整性驗證失敗")
			return {"error": EncryptionError.CORRUPTION_DETECTED}

		# 轉換回字符串
		var decrypted_string = data_bytes.get_string_from_utf8()

		LogManager.debug("EncryptionManager", "數據解密成功", {
			"decrypted_size": decrypted_string.length()
		})

		return {
			"success": true,
			"data": decrypted_string,
			"error": EncryptionError.SUCCESS
		}

	except:
		LogManager.error("EncryptionManager", "數據解密失敗")
		return {"error": EncryptionError.DECRYPTION_FAILED}

# === 加密包格式處理 ===

# 創建加密包
# 格式: [MAGIC_HEADER][VERSION][IV_LENGTH][IV][HASH][ENCRYPTED_DATA]
func _create_encrypted_package(encrypted_data: PackedByteArray, iv: PackedByteArray, hash: PackedByteArray) -> PackedByteArray:
	var package = PackedByteArray()

	# 添加魔法標頭
	package.append_array(MAGIC_HEADER.to_utf8_buffer())

	# 添加版本號
	package.append(VERSION)

	# 添加IV長度和IV
	package.append(IV_LENGTH)
	package.append_array(iv)

	# 添加哈希
	package.append_array(hash)

	# 添加加密數據
	package.append_array(encrypted_data)

	return package

# 解析加密包
func _parse_encrypted_package(package: PackedByteArray) -> Dictionary:
	var header_size = MAGIC_HEADER.length()
	var min_size = header_size + 1 + 1 + IV_LENGTH + HASH_LENGTH

	if package.size() < min_size:
		LogManager.error("EncryptionManager", "加密包太小")
		return {"error": EncryptionError.INVALID_DATA}

	var offset = 0

	# 檢查魔法標頭
	var header = package.slice(offset, offset + header_size).get_string_from_utf8()
	if header != MAGIC_HEADER:
		LogManager.error("EncryptionManager", "無效的文件標識符")
		return {"error": EncryptionError.INVALID_DATA}
	offset += header_size

	# 檢查版本
	var version = package[offset]
	if version != VERSION:
		LogManager.error("EncryptionManager", "不支持的加密版本")
		return {"error": EncryptionError.VERSION_MISMATCH}
	offset += 1

	# 讀取IV長度
	var iv_length = package[offset]
	if iv_length != IV_LENGTH:
		LogManager.error("EncryptionManager", "無效的IV長度")
		return {"error": EncryptionError.INVALID_DATA}
	offset += 1

	# 讀取IV
	var iv = package.slice(offset, offset + iv_length)
	offset += iv_length

	# 讀取哈希
	var hash = package.slice(offset, offset + HASH_LENGTH)
	offset += HASH_LENGTH

	# 讀取加密數據
	var encrypted_data = package.slice(offset)

	return {
		"encrypted_data": encrypted_data,
		"iv": iv,
		"hash": hash
	}

# === 實用工具方法 ===

# 比較哈希值
func _compare_hashes(hash1: PackedByteArray, hash2: PackedByteArray) -> bool:
	if hash1.size() != hash2.size():
		return false

	for i in range(hash1.size()):
		if hash1[i] != hash2[i]:
			return false

	return true

# 生成文件校驗和
func generate_file_checksum(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""

	var crypto = Crypto.new()
	var content = file.get_buffer(file.get_length())
	file.close()

	var hash = crypto.sha256(content)
	return hash.hex_encode()

# 驗證文件完整性
func verify_file_integrity(file_path: String, expected_checksum: String) -> bool:
	var actual_checksum = generate_file_checksum(file_path)
	return actual_checksum == expected_checksum

# === 公共API ===

# 檢查是否已初始化
func is_ready() -> bool:
	return is_initialized

# 獲取設備ID
func get_device_id() -> String:
	return device_id

# 重新生成加密密鑰（慎用！）
func regenerate_encryption_key() -> void:
	LogManager.warning("EncryptionManager", "重新生成加密密鑰")

	encryption_key = _generate_encryption_key()
	_store_encryption_key(encryption_key)

	LogManager.info("EncryptionManager", "加密密鑰已重新生成")

# 獲取加密統計信息
func get_encryption_stats() -> Dictionary:
	return {
		"is_initialized": is_initialized,
		"device_id": device_id,
		"encryption_version": VERSION,
		"key_length": ENCRYPTION_KEY_LENGTH,
		"iv_length": IV_LENGTH
	}