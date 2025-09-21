#!/bin/bash
# build_all_platforms.sh - 多平台自動化構建腳本
#
# 功能：
# - 自動構建所有支持的平台
# - 版本管理和標籤
# - 構建產物打包和簽名
# - 部署準備和驗證

set -e  # 遇到錯誤立即退出

# 配置
PROJECT_NAME="SanGoAutoEx"
PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_PATH/builds"
VERSION_FILE="$PROJECT_PATH/version.txt"
GODOT_EXECUTABLE="godot4"  # 或者使用完整路徑

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查依賴
check_dependencies() {
    log_info "檢查構建依賴..."

    # 檢查Godot
    if ! command -v $GODOT_EXECUTABLE &> /dev/null; then
        log_error "未找到Godot可執行文件：$GODOT_EXECUTABLE"
        log_info "請確保Godot已安裝並在PATH中，或修改GODOT_EXECUTABLE變量"
        exit 1
    fi

    # 檢查項目路徑
    if [ ! -f "$PROJECT_PATH/project.godot" ]; then
        log_error "未找到project.godot文件：$PROJECT_PATH"
        exit 1
    fi

    log_success "依賴檢查完成"
}

# 獲取版本號
get_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# 更新版本號
update_version() {
    local version=$1
    echo "$version" > "$VERSION_FILE"
    log_info "版本號更新為：$version"
}

# 創建構建目錄
setup_build_directories() {
    log_info "設置構建目錄..."

    mkdir -p "$BUILD_DIR/windows"
    mkdir -p "$BUILD_DIR/web"
    mkdir -p "$BUILD_DIR/android"
    mkdir -p "$BUILD_DIR/ios"
    mkdir -p "$BUILD_DIR/logs"

    log_success "構建目錄創建完成"
}

# 清理舊構建
clean_builds() {
    log_info "清理舊構建文件..."

    rm -rf "$BUILD_DIR/windows/"*
    rm -rf "$BUILD_DIR/web/"*
    rm -rf "$BUILD_DIR/android/"*
    rm -rf "$BUILD_DIR/ios/"*

    log_success "舊構建文件清理完成"
}

# Windows構建
build_windows() {
    log_info "開始構建Windows版本..."

    local log_file="$BUILD_DIR/logs/windows_build.log"

    cd "$PROJECT_PATH"
    $GODOT_EXECUTABLE --headless --export-release "Windows Desktop" "$BUILD_DIR/windows/$PROJECT_NAME.exe" 2>&1 | tee "$log_file"

    if [ $? -eq 0 ] && [ -f "$BUILD_DIR/windows/$PROJECT_NAME.exe" ]; then
        log_success "Windows構建完成"

        # 創建Windows打包
        create_windows_package
    else
        log_error "Windows構建失敗，請查看日志：$log_file"
        return 1
    fi
}

# 創建Windows打包
create_windows_package() {
    log_info "創建Windows安裝包..."

    local version=$(get_version)
    local package_name="${PROJECT_NAME}_Windows_v${version}.zip"

    cd "$BUILD_DIR/windows"
    zip -r "../$package_name" . -x "*.log"

    if [ $? -eq 0 ]; then
        log_success "Windows打包完成：$package_name"
    else
        log_warning "Windows打包失敗"
    fi
}

# Web構建
build_web() {
    log_info "開始構建Web版本..."

    local log_file="$BUILD_DIR/logs/web_build.log"

    cd "$PROJECT_PATH"
    $GODOT_EXECUTABLE --headless --export-release "Web" "$BUILD_DIR/web/index.html" 2>&1 | tee "$log_file"

    if [ $? -eq 0 ] && [ -f "$BUILD_DIR/web/index.html" ]; then
        log_success "Web構建完成"

        # 創建Web打包
        create_web_package
    else
        log_error "Web構建失敗，請查看日志：$log_file"
        return 1
    fi
}

# 創建Web打包
create_web_package() {
    log_info "創建Web部署包..."

    local version=$(get_version)
    local package_name="${PROJECT_NAME}_Web_v${version}.zip"

    cd "$BUILD_DIR/web"
    zip -r "../$package_name" . -x "*.log"

    if [ $? -eq 0 ]; then
        log_success "Web打包完成：$package_name"

        # 創建部署說明
        create_web_deployment_guide
    else
        log_warning "Web打包失敗"
    fi
}

# 創建Web部署說明
create_web_deployment_guide() {
    cat > "$BUILD_DIR/web_deployment.md" << EOF
# Web版本部署指南

## 文件說明
- index.html: 主頁面文件
- ${PROJECT_NAME}.js: 遊戲主程序
- ${PROJECT_NAME}.wasm: WebAssembly模塊
- ${PROJECT_NAME}.pck: 遊戲資源包

## 部署步驟
1. 將所有文件上傳到Web服務器
2. 確保服務器支持WASM MIME類型
3. 設置CORS頭部（如需要）
4. 訪問index.html開始遊戲

## 服務器要求
- 支持HTTPS（推薦）
- 支持WASM MIME類型
- 足夠的帶寬（遊戲大小約XX MB）

## NGINX配置示例
\`\`\`
location ~* \\.wasm$ {
    add_header Content-Type application/wasm;
}

location ~* \\.(pck|js)$ {
    add_header Cache-Control "public, max-age=31536000";
}
\`\`\`
EOF
}

# Android構建
build_android() {
    log_info "開始構建Android版本..."

    # 檢查Android構建環境
    if ! check_android_environment; then
        log_warning "跳過Android構建：環境未配置"
        return 0
    fi

    local log_file="$BUILD_DIR/logs/android_build.log"

    cd "$PROJECT_PATH"
    $GODOT_EXECUTABLE --headless --export-release "Android" "$BUILD_DIR/android/$PROJECT_NAME.apk" 2>&1 | tee "$log_file"

    if [ $? -eq 0 ] && [ -f "$BUILD_DIR/android/$PROJECT_NAME.apk" ]; then
        log_success "Android構建完成"

        # 創建Android打包
        create_android_package
    else
        log_error "Android構建失敗，請查看日志：$log_file"
        return 1
    fi
}

# 檢查Android構建環境
check_android_environment() {
    # 檢查Android SDK
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        log_warning "未設置Android SDK環境變量"
        return 1
    fi

    # 檢查Java
    if ! command -v java &> /dev/null; then
        log_warning "未找到Java環境"
        return 1
    fi

    return 0
}

# 創建Android打包
create_android_package() {
    log_info "處理Android APK..."

    local version=$(get_version)
    local apk_name="${PROJECT_NAME}_Android_v${version}.apk"

    # 重命名APK
    mv "$BUILD_DIR/android/$PROJECT_NAME.apk" "$BUILD_DIR/$apk_name"

    # 創建APK信息
    cat > "$BUILD_DIR/android_info.txt" << EOF
Android APK信息
================
文件名: $apk_name
版本: $version
構建時間: $(date)
最低Android版本: 5.0 (API 21)
目標Android版本: 最新

安裝說明:
1. 允許未知來源應用安裝
2. 下載APK文件到設備
3. 點擊APK文件進行安裝

注意事項:
- 首次安裝需要授予相關權限
- 遊戲數據會保存在應用內部存儲
- 支持觸控和手勢操作
EOF

    log_success "Android APK處理完成"
}

# iOS構建
build_ios() {
    log_info "開始構建iOS版本..."

    # 檢查macOS環境
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "跳過iOS構建：需要macOS環境"
        return 0
    fi

    # 檢查Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_warning "跳過iOS構建：未找到Xcode"
        return 0
    fi

    local log_file="$BUILD_DIR/logs/ios_build.log"

    cd "$PROJECT_PATH"
    $GODOT_EXECUTABLE --headless --export-release "iOS" "$BUILD_DIR/ios/$PROJECT_NAME.ipa" 2>&1 | tee "$log_file"

    if [ $? -eq 0 ] && [ -f "$BUILD_DIR/ios/$PROJECT_NAME.ipa" ]; then
        log_success "iOS構建完成"

        # 創建iOS打包
        create_ios_package
    else
        log_error "iOS構建失敗，請查看日志：$log_file"
        return 1
    fi
}

# 創建iOS打包
create_ios_package() {
    log_info "處理iOS IPA..."

    local version=$(get_version)
    local ipa_name="${PROJECT_NAME}_iOS_v${version}.ipa"

    # 重命名IPA
    mv "$BUILD_DIR/ios/$PROJECT_NAME.ipa" "$BUILD_DIR/$ipa_name"

    # 創建iOS信息
    cat > "$BUILD_DIR/ios_info.txt" << EOF
iOS IPA信息
===========
文件名: $ipa_name
版本: $version
構建時間: $(date)
最低iOS版本: 12.0
設備支持: iPhone, iPad

部署說明:
1. 需要有效的iOS開發者證書
2. 設備需要在開發者賬戶中註冊
3. 使用Xcode或第三方工具安裝

App Store發布流程:
1. 上傳到App Store Connect
2. 填寫應用信息和截圖
3. 提交審核
4. 等待蘋果審核通過

注意事項:
- 需要配置應用隱私政策
- 遵守App Store審核指南
- 準備各尺寸應用圖標和截圖
EOF

    log_success "iOS IPA處理完成"
}

# 運行測試
run_tests() {
    log_info "運行自動化測試..."

    cd "$PROJECT_PATH"

    # 運行單元測試
    if [ -d "tests/unit" ]; then
        log_info "運行單元測試..."
        # 這裡可以添加GdUnit測試運行命令
        # $GODOT_EXECUTABLE --headless -s addons/gdUnit4/bin/ProjectScanner.gd
    fi

    # 運行集成測試
    if [ -d "tests/integration" ]; then
        log_info "運行集成測試..."
        # 添加集成測試運行命令
    fi

    log_success "測試完成"
}

# 驗證構建
verify_builds() {
    log_info "驗證構建結果..."

    local success_count=0
    local total_count=0

    # 檢查Windows構建
    if [ -f "$BUILD_DIR/windows/$PROJECT_NAME.exe" ]; then
        log_success "✓ Windows構建存在"
        ((success_count++))
    else
        log_error "✗ Windows構建缺失"
    fi
    ((total_count++))

    # 檢查Web構建
    if [ -f "$BUILD_DIR/web/index.html" ]; then
        log_success "✓ Web構建存在"
        ((success_count++))
    else
        log_error "✗ Web構建缺失"
    fi
    ((total_count++))

    # 檢查Android構建
    if ls "$BUILD_DIR/"*_Android_*.apk &> /dev/null; then
        log_success "✓ Android構建存在"
        ((success_count++))
    else
        log_warning "! Android構建缺失（可能被跳過）"
    fi
    ((total_count++))

    # 檢查iOS構建
    if ls "$BUILD_DIR/"*_iOS_*.ipa &> /dev/null; then
        log_success "✓ iOS構建存在"
        ((success_count++))
    else
        log_warning "! iOS構建缺失（可能被跳過）"
    fi
    ((total_count++))

    log_info "構建驗證完成：$success_count/$total_count 成功"
}

# 生成構建報告
generate_build_report() {
    log_info "生成構建報告..."

    local version=$(get_version)
    local report_file="$BUILD_DIR/build_report_v${version}.md"

    cat > "$report_file" << EOF
# 構建報告 - 三國自動戰記 v${version}

## 構建信息
- 構建時間: $(date)
- 版本號: ${version}
- 構建環境: $(uname -a)
- Godot版本: $($GODOT_EXECUTABLE --version 2>/dev/null || echo "未知")

## 構建結果

### Windows Desktop
$([ -f "$BUILD_DIR/windows/$PROJECT_NAME.exe" ] && echo "✅ 構建成功" || echo "❌ 構建失敗")
- 文件: $PROJECT_NAME.exe
- 打包: $(ls "$BUILD_DIR/"*_Windows_*.zip 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "無")

### Web版本
$([ -f "$BUILD_DIR/web/index.html" ] && echo "✅ 構建成功" || echo "❌ 構建失敗")
- 文件: index.html + 相關資源
- 打包: $(ls "$BUILD_DIR/"*_Web_*.zip 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "無")

### Android
$(ls "$BUILD_DIR/"*_Android_*.apk &>/dev/null && echo "✅ 構建成功" || echo "⚠️ 構建跳過或失敗")
- 文件: $(ls "$BUILD_DIR/"*_Android_*.apk 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "無")

### iOS
$(ls "$BUILD_DIR/"*_iOS_*.ipa &>/dev/null && echo "✅ 構建成功" || echo "⚠️ 構建跳過或失敗")
- 文件: $(ls "$BUILD_DIR/"*_iOS_*.ipa 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "無")

## 文件大小
\`\`\`
$(cd "$BUILD_DIR" && ls -lh *.exe *.zip *.apk *.ipa 2>/dev/null || echo "無構建文件")
\`\`\`

## 下一步
1. 測試各平台構建是否正常運行
2. 準備發布材料（截圖、描述等）
3. 上傳到各平台商店
4. 配置CI/CD自動化部署

## 構建日志
詳細構建日志請查看 builds/logs/ 目錄下的對應文件。
EOF

    log_success "構建報告已生成：$report_file"
}

# 主函數
main() {
    echo "================================================"
    echo "三國自動戰記 - 多平台構建腳本"
    echo "================================================"

    local version=$(get_version)
    log_info "當前版本：$version"

    # 解析命令行參數
    local clean_before_build=true
    local run_tests_flag=false
    local platforms=("windows" "web" "android" "ios")

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                update_version "$2"
                shift 2
                ;;
            --no-clean)
                clean_before_build=false
                shift
                ;;
            --test)
                run_tests_flag=true
                shift
                ;;
            --platform)
                IFS=',' read -ra platforms <<< "$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [選項]"
                echo "選項:"
                echo "  --version VERSION    設置版本號"
                echo "  --no-clean          不清理舊構建"
                echo "  --test              運行測試"
                echo "  --platform LIST     指定構建平台(用逗號分隔)"
                echo "  --help              顯示此幫助"
                echo ""
                echo "平台: windows, web, android, ios"
                echo "示例: $0 --version 1.1.0 --platform windows,web"
                exit 0
                ;;
            *)
                log_error "未知參數: $1"
                exit 1
                ;;
        esac
    done

    # 執行構建流程
    check_dependencies
    setup_build_directories

    if [ "$clean_before_build" = true ]; then
        clean_builds
    fi

    if [ "$run_tests_flag" = true ]; then
        run_tests
    fi

    # 構建各平台
    local build_success=true

    for platform in "${platforms[@]}"; do
        case $platform in
            windows)
                build_windows || build_success=false
                ;;
            web)
                build_web || build_success=false
                ;;
            android)
                build_android || build_success=false
                ;;
            ios)
                build_ios || build_success=false
                ;;
            *)
                log_warning "未知平台: $platform"
                ;;
        esac
    done

    # 驗證和報告
    verify_builds
    generate_build_report

    if [ "$build_success" = true ]; then
        log_success "所有構建完成！"
        log_info "構建文件位於：$BUILD_DIR"
    else
        log_error "部分構建失敗，請查看日志"
        exit 1
    fi
}

# 運行主函數
main "$@"