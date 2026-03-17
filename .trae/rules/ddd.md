# 关于Nakama的Lua模组编码规范,DDD范式

## 目录
`com.nakamaservermod.unity-sdk/NakamaServerMod`

## 规范
- data是相关配置
- domain层：domain文件夹，存放领域模型代码，领域之间不互相感知，不能相互调用，只能通过service层调用
- application层：service文件夹，存放业务层代码，业务层之间不互相感知，不能相互调用
- main的RPC注册，不能直接注册domain的内容