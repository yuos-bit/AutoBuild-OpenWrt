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
