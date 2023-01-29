using UnityEngine;
using System;


public class Decoder : MonoBehaviour {
    List<byte[]> decodeWebsocketFrame(Byte[] bytes)
    {
        List<Byte[]> ret = new List<Byte[]>();
        int offset = 0;
        while (offset + 6 < bytes.Length)
        {
            // format: 0==ascii/binary 1=length-0x80, byte 2,3,4,5=key, 6+len=message, repeat with offset for next...
            int len = bytes[offset + 1] - 0x80;

            if (len <= 125)
            {

                //String data = Encoding.UTF8.GetString(bytes);
                //Debug.Log("len=" + len + "bytes[" + bytes.Length + "]=" + ByteArrayToString(bytes) + " data[" + data.Length + "]=" + data);
                Debug.Log("len=" + len + " offset=" + offset);
                Byte[] key = new Byte[] { bytes[offset + 2], bytes[offset + 3], bytes[offset + 4], bytes[offset + 5] };
                Byte[] decoded = new Byte[len];
                for (int i = 0; i < len; i++)
                {
                    int realPos = offset + 6 + i;
                    decoded[i] = (Byte)(bytes[realPos] ^ key[i % 4]);
                }
                offset += 6 + len;
                ret.Add(decoded);
            } else
            {
                int a = bytes[offset + 2];
                int b = bytes[offset + 3];
                len = (a << 8) + b;
                //Debug.Log("Length of ws: " + len);

                Byte[] key = new Byte[] { bytes[offset + 4], bytes[offset + 5], bytes[offset + 6], bytes[offset + 7] };
                Byte[] decoded = new Byte[len];
                for (int i = 0; i < len; i++)
                {
                    int realPos = offset + 8 + i;
                    decoded[i] = (Byte)(bytes[realPos] ^ key[i % 4]);
                }

                offset += 8 + len;
                ret.Add(decoded);
            }
        }
        return ret;
    }
}
