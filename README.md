# 拾页

macOS 菜单栏小工具，用来暂存想反复查看的网页，不用一直开着一堆 Safari 标签页。

- **保存**：把网页地址（Safari 地址栏或链接）拖到菜单栏图标上。
- **打开**：点菜单里的条目，在 Safari 打开，条目保留在列表里。
- **删除**：鼠标移到条目上，点右侧的 ×，删除的网页会进入删除历史。
- **设置**：菜单里的「设置…」可以查看地址、自定义名称、恢复删除过的网页。
- **右键菜单**：登录时启动、退出。

## 安装

需要 macOS 14 或更高版本，以及 Xcode 或 Command Line Tools。

```bash
git clone https://github.com/coffeecoproject/shiye.git
cd shiye
bash build.sh
```

脚本会编译并安装到 `~/Applications/拾页.app`，然后启动。数据保存在 `~/Library/Application Support/拾页/`。

第一次拖入网页时，系统会询问是否允许拾页控制 Safari，用于读取网页标题。不允许也能保存，但会弹出提示，名称显示为地址。之后可以在「系统设置 → 隐私与安全性 → 自动化」里重新打开。

## 许可

MIT
