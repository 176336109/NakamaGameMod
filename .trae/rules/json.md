1.Json描述同一类对象时，禁止使用以 以下结构

```json
{
    "items": {
        "gold": { "type": "currency", "name": "金币", "itemDesc": "金币说明" },
        "gem": { "type": "currency", "name": "水晶", "itemDesc": "水晶说明" }
    }
}
```

应换成类似这样的结构

```json
{
    "items": {
        { "itemId": "gold","type": "currency", "name": "金币", "itemDesc": "金币说明" },
        { "itemId": "gem","type": "currency", "name": "水晶", "itemDesc": "水晶说明" }
    }
}
```

2.Json中带有type的字段，在创建C#对象时，要创建成对应的枚举

```json
{
    "items": {
        { "itemId": "gold","type": "currency", "name": "金币", "itemDesc": "金币说明" },
        { "itemId": "gem","type": "currency", "name": "水晶", "itemDesc": "水晶说明" }
    }
}
```

 像这段jso，创建的C#对象中，type应为枚举
