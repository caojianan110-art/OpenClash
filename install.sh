#!/bin/sh
set -e

echo "=========================================="
echo "      祥祥加速器 - 软路由一键全自动安装"
echo "=========================================="

# 1. 检测路由器架构与包管理器
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64) CORE_ARCH="arm64" ;;
  x86_64)        CORE_ARCH="amd64" ;;
  *) echo "[错误] 不支持的架构: $ARCH"; exit 1 ;;
esac

if command -v opkg >/dev/null 2>&1; then
  MGR="opkg"
elif command -v apk >/dev/null 2>&1; then
  MGR="apk"
else
  echo "[错误] 未找到 opkg 或 apk 包管理器"; exit 1
fi
echo ">>> [1/4] 系统环境: $CORE_ARCH ($MGR)"

# 2. 自动补全必备网络依赖
echo ">>> [2/4] 正在安装系统依赖..."
if [ "$MGR" = "opkg" ]; then
  opkg update >/dev/null 2>&1 || true
  opkg install bash curl ca-bundle ip-full kmod-tun coreutils-nohup kmod-nft-tproxy >/dev/null 2>&1 || true
else
  apk update >/dev/null 2>&1 || true
  apk add bash curl ca-bundle ip-full kmod-tun coreutils-nohup kmod-nft-tproxy >/dev/null 2>&1 || true
fi

# 3. 下载并安装你之前已经编译好的【祥祥加速器】网页控制面板
echo ">>> [3/4] 正在安装【祥祥加速器】网页后台..."
IPK_URL="https://ghfast.top"
curl -fL --retry 3 -o /tmp/xiangxiang.ipk "$IPK_URL" || wget -qO /tmp/xiangxiang.ipk "$IPK_URL"

if [ ! -s /tmp/xiangxiang.ipk ]; then
  echo "[错误] 请先确保你已在 GitHub Releases (v1.0) 上传了 luci-app-openclash_0.48.006-xiangxiang_all.ipk"
  exit 1
fi

if [ "$MGR" = "opkg" ]; then
  opkg install --force-reinstall /tmp/xiangxiang.ipk
else
  apk add --allow-untrusted /tmp/xiangxiang.ipk
fi
rm -f /tmp/xiangxiang.ipk

# 4. 从官方源自动拉取匹配当前架构的最新 Mihomo 内核
echo ">>> [4/4] 正在安装 $CORE_ARCH 运行内核..."
mkdir -p /etc/openclash/core
CORE_API="https://github.com"
REAL_URL=$(curl -fsSL "$CORE_API" | grep "browser_download_url" | grep "mihomo-linux-${CORE_ARCH}-v1" | head -n 1 | cut -d '"' -f 4)
[ -z "$REAL_URL" ] && REAL_URL="https://github.com{CORE_ARCH}-alpha.gz"

curl -fL --retry 3 -o /tmp/mihomo.gz "https://ghfast.top{REAL_URL}" || wget -qO /tmp/mihomo.gz "https://ghfast.top{REAL_URL}"
if [ -s /tmp/mihomo.gz ]; then
  gzip -d -c /tmp/mihomo.gz > /etc/openclash/core/clash_meta
  chmod 755 /etc/openclash/core/clash_meta
  rm -f /tmp/mihomo.gz
  echo "  -> 运行内核部署成功！"
fi

# 刷新后台菜单缓存
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
/etc/init.d/rpcd restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

echo "=========================================="
echo "  安装全部完成！请刷新路由器网页后台"
echo "  菜单位置：服务 -> 祥祥加速器"
echo "=========================================="
