using UnityEngine;
using UnityEngine.VFX;

using NativeWebSocket;
using System;
using System.Collections;
using System.Collections.Generic;

public class Connection : MonoBehaviour
{
    WebSocket websocket;

    public struct Coordinate
    {
        public float x;
        public float y;
        public float z;
    }
    
    public List<Coordinate> coordinates;
    public VisualEffect particleVFX;
    

    

    // Start is called before the first frame update
    async void Start()
    {
        coordinates = new List<Coordinate>();
        websocket = new WebSocket("wss://superposition.herokuapp.com");
        particleVFX = new VisualEffect();
        websocket.OnOpen += () =>
        {
        Debug.Log("Connection open!");
        };

        websocket.OnError += (e) =>
        {
        Debug.Log("Error! " + e);
        };

        websocket.OnClose += (e) =>
        {
        Debug.Log("Connection closed!");
        };  

        websocket.OnMessage += (bytes) =>
        {
            Debug.Log("OnMessage!");

        
            
            int length = bytes.Length / sizeof(float);
            float[] floatArray = new float[length];
            Buffer.BlockCopy(bytes, 0, floatArray, 0, bytes.Length);

            int numCoords = floatArray.Length / 3;

            for (int i = 0, j = 0; i < floatArray.Length; i += 3, j++)
            {
                Coordinate coord1;
                coord1.x = floatArray[i];
                coord1.y = floatArray[i + 1];
                coord1.z = floatArray[i + 2];
                coordinates.Add(coord1);
            }

            foreach (Coordinate coord in coordinates)
            {
                Vector3 position = new Vector3(coord.x, coord.y, coord.z);
                VisualEffect particleInstance = Instantiate(particleVFX, position, Quaternion.identity);
                particleInstance.transform.parent = transform;
            }
        };

       

        // waiting for messages
        await websocket.Connect();
    }



    private async void OnApplicationQuit()
    {
        await websocket.Close();
    }

}