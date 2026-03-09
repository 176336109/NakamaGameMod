# Nakama 依赖接入

本包不内置 Nakama 客户端二进制或源码。请在你的 Unity 工程中先引入 Nakama Unity SDK，然后再引入本包。

## 方式 A：通过 Git URL 引入（推荐，不依赖额外包注册表）

在 Unity 工程的 `Packages/manifest.json` 中加入：

```json
{
  "dependencies": {
    "com.heroiclabs.nakama-unity": "https://github.com/heroiclabs/nakama-unity.git?path=/Packages/Nakama#<tag-or-commit>"
  }
}
```

将 `<tag-or-commit>` 替换为具体版本号标签或提交哈希。

## 方式 B：通过 OpenUPM 引入（需要配置作用域注册表 scoped registry）

1. 在 Unity 工程的 `Packages/manifest.json` 添加 OpenUPM 注册表（如你项目已有 OpenUPM，可跳过此步）
2. 在 `dependencies` 中加入：

```json
{
  "dependencies": {
    "com.heroiclabs.nakama-unity": "<version>"
  }
}
```

将 `<version>` 替换为你希望使用的版本号。

## 方式 C：导入发布版本产物（Release）

从官方 Release 获取 `.unitypackage` 或 `.tar`，通过 Unity 包管理器（Package Manager）或导入资源包的方式安装。

## 快速验证

在任意脚本中引用命名空间并创建客户端（Client）：

```csharp
using Nakama;

public static class NakamaBootstrap
{
    public static IClient CreateClient()
    {
        const string scheme = "http";
        const string host = "127.0.0.1";
        const int port = 7350;
        const string serverKey = "defaultkey";
        return new Client(scheme, host, port, serverKey, UnityWebRequestAdapter.Instance);
    }
}
```
