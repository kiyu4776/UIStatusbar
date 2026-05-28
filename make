#!/bin/sh
export THEOS=/var/jb/var/mobile/theos
# make clean
if make do package -j$(sysctl -n hw.ncpu) FINALPACKAGE=1 debug=0 MESSAGES=0 STRIP=1; then
    echo "完了！"
else
    echo "Build failed!"
    exit 1
fi
killall -9 SpringBoard
echo "Restarting SpringBoard..."