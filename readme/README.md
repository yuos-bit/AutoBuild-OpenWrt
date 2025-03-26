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
