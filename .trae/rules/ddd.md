# 关于Nakama的Lua模组编码规范,DDD范式

## 目录
`com.nakamaservermod.unity-sdk/NakamaServerMod`

## 规范
- **data**：相关配置
- **domain层**：domain文件夹，存放领域模型代码。**同层之间不互相感知，不能相互调用**
- **application层**：service文件夹，通过对domain的调用实现业务。**同层之间不互相感知，不能相互调用**
- **main的RPC注册**，通过暴露application层的函数，实现对业务的调用。