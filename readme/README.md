# 云编译-各种版本的OpenWrt

## 捐贈

***
<center><b>如果你觉得此项目对你有帮助，可以捐助我，用爱发电也挺难的，哈哈。</b></center>

|  微信   | 支付宝  |
|  ----  | ----  |
| ![](https://pic.imgdb.cn/item/62502707239250f7c5b8ac3d.png) | ![](https://pic.imgdb.cn/item/62502707239250f7c5b8ac36.png) |

## 赞助名单

![](https://pic.imgdb.cn/item/625028c0239250f7c5bd102b.jpg)
感谢以上大佬的充电！

---

## 固件信息

* 网关：10.32.0.1
* 无线名称：设备型号+mac地址+频段
* 无线密码：1234567890

---

## 更新日志

### 20251019
* 1.修复passwall 中文汉化的问题

解决办法：先将目录`zh_cn`改成`zh_Hans`
![image.png](https://free.picui.cn/free/2025/10/19/68f45421c7e7e.png)
 再在 passwall.po抬头加上
```shell
msgid ""
msgstr ""
"openwrt/luciapplicationspasswall/zh_Hans/>\n"
"Language: zh_Hans\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"Plural-Forms: nplurals=1; plural=0;\n"
"X-Generator: Weblate 5.5-dev\n"
```
然后再编译即可，详见：https://github.com/xiaorouji/openwrt-passwall/issues/3051
* 2.解决passwall和Tailscale同时启用，H3C NX30PRO 内存占用率过高导致Tailscale 掉线或者路由卡死的问题，解决方案，降级xray和Tailscale版本
详见：
https://github.com/yuos-bit/other/commit/bf64f9c9fe2aacbda5b6b54e2694359de87682f1 
https://github.com/yuos-bit/other/commit/f9d0368be553c506bdf8ab0b3a68dafe91fec6e5

### 20251001

* 红米、小米AC2100超频1100mhz:CPU Clock: 1100MHz
  启动日志：
```shell
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] Memory: 120592K/131072K available (5938K kernel code, 202K rwdata, 1264K rodata, 1288K init, 229K bss, 10480K reserved, 0K cma-reserved, 0K highmem)
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] SLUB: HWalign=32, Order=0-3, MinObjects=0, CPUs=4, Nodes=1
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] rcu: Hierarchical RCU implementation.
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] rcu: RCU calculated value of scheduler-enlistment delay is 25 jiffies.
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] NR_IRQS: 256
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] CPU Clock: 1100MHz
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] clocksource: GIC: mask: 0xffffffffffffffff max_cycles: 0xfdb1960d81, max_idle_ns: 440795240157 ns
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000000] clocksource: MIPS: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 3475018995 ns
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.000008] sched_clock: 32 bits at 550MHz, resolution 1ns, wraps every 3904515583ns
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.007859] Calibrating delay loop... 731.13 BogoMIPS (lpj=1462272)
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.042047] pid_max: default: 32768 minimum: 301
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.046787] Mount-cache hash table entries: 1024 (order: 0, 4096 bytes, linear)
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.054002] Mountpoint-cache hash table entries: 1024 (order: 0, 4096 bytes, linear)
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.064234] rcu: Hierarchical SRCU implementation.
Mon Nov  6 20:30:21 2023 kern.info kernel: [    0.069676] smp: Bringing up secondary CPUs ...
```
### 20250930

* ,参阅[MT7621超频1100Mhz](https://github.com/yuos-bit/openwrt/commit/9cc5e7a9d3e3adcfeb8128abdd66e56e28ce85d8)
新增4.14内核红米AC2100、小米AC2100适配以及云编译

* 调整固件自动打包命名，命名格式`openwrt-分支名称`代码如下：

```shell
    - name: 重命名固件名
      if: steps.organize.outputs.status == 'success' && !cancelled()
      run: |
        cd $FIRMWARE
        for file in openwrt-*; do
          new_name="$(echo "$file" | sed "s/^openwrt-/${REPO_BRANCH}-/")"
          echo "重命名: $file -> $new_name"
          mv "$file" "$new_name"
        done
```

### 20250611

* 修复编译插件上传偶发性失败的问题，代码如下：

```
- name: 上传 packages 文件到 Cloudreve
  if: steps.organize.outputs.status == 'success' && github.event.inputs.UPLOAD_CLOUDREVE == 'true' && !cancelled()
  run: |
    echo "开始上传 packages 文件到 Cloudreve..."
    cd openwrt/bin/packages
    
    # 先创建所有需要的目录
    echo "创建所有需要的目录..."
    find . -type d | while read dir; do
      rel_dir=$(echo "$dir" | sed 's#^\./##')
      remote_path="${TARGET_DIR}/packages/${rel_dir}"
      echo "创建目录: $remote_path"
      curl --http1.1 -u "${{ secrets.WEBDAV_USERNAME }}:${{ secrets.WEBDAV_PASSWORD }}" -X MKCOL "${{ secrets.WEBDAV_URL }}/${remote_path}" || true
    done
    
    # 上传所有文件，添加重试机制
    echo "开始上传文件..."
    find . -type f | xargs -P 2 -I {} bash -c '
      file="{}"
      rel_dir=$(dirname "$file" | sed "s#^\./##")
      remote_path="${TARGET_DIR}/packages/${rel_dir}"
      filename=$(basename "$file")
      echo "上传文件: $file -> ${remote_path}/${filename}"
      
      # 添加超时和重试设置
      curl --http1.1 \
           --connect-timeout 30 \
           --max-time 300 \
           --retry 3 \
           --retry-delay 5 \
           -u "${{ secrets.WEBDAV_USERNAME }}:${{ secrets.WEBDAV_PASSWORD }}" \
           -T "$file" "${{ secrets.WEBDAV_URL }}/${remote_path}/${filename}" || {
        echo "错误: 上传文件 $file 失败，HTTP错误码 $?"
        exit 1
      }
    '
```

#### 20250327

* 适配zte,e8820v2 4.14内核

* 祛除zte,e8820v2 openwrt分支21.02支持

* 增加无线wifi按照设备型号+mac地址生成的规则，无线密码默认是`1234567890`

* 默认上传所有插件

---

Openwrt19.07编译全系更改阿里源

## 测试说明

* 1.经过测试，使用微软源在包更少的情况下所需时间更长，且会莫名报错。如图：
![](https://s3.bmp.ovh/imgs/2023/01/13/a8d21b205a7ecaa4.png)
![](https://s3.bmp.ovh/imgs/2023/01/13/1b45f00a0a8690fb.png)
![](https://s3.bmp.ovh/imgs/2023/01/13/832bfe8be9414f1b.jpg)

* 2.但是使用阿里源则不会。如图：
![](https://s3.bmp.ovh/imgs/2023/01/13/9d9d8f1ed37fd0e6.png)
![](https://s3.bmp.ovh/imgs/2023/01/13/1d68f4f06208d6af.png)

## 详情

见[2023.01.13提交](https://github.com/yuos-bit/AutoBuild-OpenWrt19.07/commit/3b0bcc5c7e5a4361e12e79ce8dc2c1988b859607)

## 修改语法

```shell
        sudo sed -i s@/azure.archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
        sudo -E apt -qq clean
        sudo -E apt-get -qq update
```
