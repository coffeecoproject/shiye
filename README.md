# 拾页

macOS 菜单栏小工具，用来暂存想反复查看的网页，不用一直开着一堆 Safari 标签页。

- **保存**：把网页地址（Safari 地址栏或链接）拖到菜单栏图标上。
- **打开**：点菜单里的条目，在 Safari 打开，条目保留在列表里。
- **删除**：鼠标移到条目上，点右侧的 ×，删除的网页会进入删除历史。
- **设置**：菜单里的「设置…」可以查看地址、自定义名称、恢复删除过的网页。
- **右键菜单**：登录时启动、退出。

## 安装

需要 macOS 14 或更高版本，Apple 芯片和 Intel 的 Mac 都能用。

### 下载安装

1. 在 [Releases](https://github.com/coffeecoproject/shiye/releases) 下载最新的 `Shiye-<版本>.zip`，双击解压。
2. 把 `拾页.app` 拖到「应用程序」文件夹。
3. 第一次打开时，系统会提示无法验证开发者（拾页没有经过苹果公证）。点「完成」，然后打开「系统设置 → 隐私与安全性」，在页面下方点「仍要打开」。之后就能正常打开了。

### 从源码编译

需要 Xcode 或 Command Line Tools。

```bash
git clone https://github.com/coffeecoproject/shiye.git
cd shiye
bash build.sh
```

脚本会编译并安装到 `~/Applications/拾页.app`，然后启动。

要打包发给别人，运行 `bash build.sh dist`，会在 `dist/` 里生成 Apple 芯片和 Intel 通用的 zip。

### 使用说明

数据保存在 `~/Library/Application Support/拾页/`。

第一次拖入网页时，系统会询问是否允许拾页控制 Safari，用于读取网页标题。不允许也能保存，但会弹出提示，名称显示为地址。之后可以在「系统设置 → 隐私与安全性 → 自动化」里重新打开。

## 许可

MIT
