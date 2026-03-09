namespace NakamaServerMod.UnitySdk
{
    public interface IJsonCodec
    {
        string ToJson<T>(T value);
        T FromJson<T>(string json);
    }
}
