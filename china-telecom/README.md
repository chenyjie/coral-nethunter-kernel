# 中国大陆电信（China Telecom）适配

Pixel 4 / 4 XL 的基带 MBN 里没有任何中国运营商，电信卡只能落到 2G，注册不上 4G。这里的 `cnmbn` 模块把中国运营商（移动 / 联通 / 电信 / 移动香港）的 MBN 叠加到 `/vendor`，让电信卡能注册 4G 并上网。

这是 **KernelSU 模块**，与内核本身无关。只有中国大陆电信用户需要它，其它运营商、其它地区不需要任何改动。

## 现状

| 项目 | 状态 |
|---|---|
| 移动数据（4G 上网） | ✅ 可用 |
| 4G 注册 / 信号 | ✅ 正常 |
| 拨打电话（VoLTE / IMS） | ❌ 不可用，拨号提示「无法连接到移动网络」 |

## 原理

基带不认识某家运营商时，靠 **MBN**（Qualcomm modem 配置）知道该用什么频段、怎么注册。Pixel 原厂的 `mbn_sw.txt` 只列 Pixel 自带的运营商（APAC / EU / NA / SEA），没有中国任何一家。本模块把小米 9T（同为骁龙 855）的中国运营商 MBN 叠加进去。

`post-fs-data.sh` 自己做 bind-mount：

1. 把原厂 `mcfg_sw` 整棵拷到 staging
2. 叠加本模块的 `mi9t` 子树 + `oem_sw.txt` + `mbn_sw.dig`
3. `chcon` 修 SELinux 标签
4. `mount --bind` staging 到 `/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw`

不走 meta-overlayfs 的常规挂载：它只把模块的 `system/` 叠到 `/system`，对顶层 `vendor/` 不做处理，`system/vendor -> ../vendor` 这种布局挂不上。自己 bind 最直接，也不依赖元模块。

## 安装

```bash
adb push cnmbn-1.0.zip /data/local/tmp/
adb shell "su -M -c 'ksud module install /data/local/tmp/cnmbn-1.0.zip'"
adb reboot
```

重启后验证：

```bash
adb shell "su -M -c 'ls /vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw/generic'"
# 应包含 mi9t
```

卸载：`adb shell "su -M -c 'ksud module uninstall cnmbn'"` + 重启。

> 系统更新 / 换 ROM 后如果 `/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw` 的路径或结构变了，改 `post-fs-data.sh` 里的 `DST` 即可，模块本身不用动。

## 目录

```
cnmbn/
├── module.prop
├── post-fs-data.sh
└── files/mcfg_sw/
    ├── oem_sw.txt                       # 只列这 5 条中国 MBN
    ├── mbn_sw.dig                       # 厂商摘要文件（32 B）
    └── generic/mi9t/china/
        ├── cmcc/commerci/volte_op/mcfg_sw.mbn
        ├── cu/commerci/volte/mcfg_sw.mbn
        ├── ct/commerci/volte_op/mcfg_sw.mbn
        ├── ct/commerci/hvolte_o/mcfg_sw.mbn
        └── cmhk/commerci/volte_op/mcfg_sw.mbn
```

`files/mcfg_sw/generic/mi9t/` 下的 `.mbn` 是高通 modem 配置二进制，提取自小米 9T 的厂商镜像。放进本仓库只为方便复现，其权利归原厂商；介意的话自行从对应机型镜像中提取。

## 电话（VoLTE / IMS）为什么还不行

语音走 VoLTE（IMS），需要 carrier config 里中国运营商的 IMS 配置，以及 Google `CarrierServices` 的支持列表——Pixel 出厂两者都不含中国电信。

诊断落点：

```
E RILJ: Unable to complete updateImsCallStatus because service IMS is not available. [PHONE0]
ImsPhoneCallTracker: state=DISCONNECTED cause=36
LteVopsSupportInfo: mVopsSupport = 2        # 网络侧报"不支持 VoPS"
```

即 IMS 服务没有向网络注册。这属于 ROM / 应用层的 IMS 集成缺口，不在内核范围。
