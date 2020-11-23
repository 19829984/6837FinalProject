using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class WorleyNoiseGen : MonoBehaviour
{
    // Start is called before the first frame update
    public int tex_size;
    public int worley_res;
    void Start()
    {
        var prng = new System.Random();
        var worley_points = CreateWorleyPoints(prng, 2);
        Texture3D worley_tex = new Texture3D(tex_size, tex_size, tex_size, TextureFormat.RGBA32, false);
        worley_tex.wrapMode = TextureWrapMode.Repeat;

        Color[] colors = new Color[tex_size * tex_size * tex_size];
        
        
    }

    Vector3[] CreateWorleyPoints(System.Random prng, int numCellsPerAxis)
    {
        var return_points = new Vector3[numCellsPerAxis * numCellsPerAxis * numCellsPerAxis];
        float cellSize = 1f / numCellsPerAxis;
        for (int x = 0; x < numCellsPerAxis; x++)
        {
            for (int y = 0; y < numCellsPerAxis; y++)
            {
                for (int z = 0; z < numCellsPerAxis; z++)
                {
                    float randomX = (float)prng.NextDouble();
                    float randomY = (float)prng.NextDouble();
                    float randomZ = (float)prng.NextDouble();

                    Vector3 randomOffset = new Vector3(randomX, randomY, randomZ) * cellSize;
                    Vector3 cellCorner = new Vector3(x, y, z) * cellSize;

                    int cell_index = x + numCellsPerAxis * (y + numCellsPerAxis * z);
                    return_points[cell_index] = cellCorner + randomOffset;
                }
            }
        }
        return return_points;
    }
}
