#!/bin/zsh
cd "$(dirname "$0")"
print 'UI 预览：http://127.0.0.1:8093/?ui=1'
print 'V05 古战场遗迹：http://127.0.0.1:8093/'
print 'Boss 动作看板：http://127.0.0.1:8093/boss-motions/'
print '资产与动作审阅：http://127.0.0.1:8093/asset-review/'
exec python3 -m http.server 8093 --bind 127.0.0.1 --directory builds/web
