using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class WorleyNoiseGen : MonoBehaviour
{
    // Start is called before the first frame update
    public int TextureSize = 1;
    public int WorleyResolution = 1;

    readonly Vector3Int[] offsets =
    {
        // centre
        new Vector3Int(0,0,0),
        // front face
        new Vector3Int(0,0,1),
        new Vector3Int(-1,1,1),
        new Vector3Int(-1,0,1),
        new Vector3Int(-1,-1,1),
        new Vector3Int(0,1,1),
        new Vector3Int(0,-1,1),
        new Vector3Int(1,1,1),
        new Vector3Int(1,0,1),
        new Vector3Int(1,-1,1),
        // back face
        new Vector3Int(0,0,-1),
        new Vector3Int(-1,1,-1),
        new Vector3Int(-1,0,-1),
        new Vector3Int(-1,-1,-1),
        new Vector3Int(0,1,-1),
        new Vector3Int(0,-1,-1),
        new Vector3Int(1,1,-1),
        new Vector3Int(1,0,-1),
        new Vector3Int(1,-1,-1),
        // ring around centre
        new Vector3Int(-1,1,0),
        new Vector3Int(-1,0,0),
        new Vector3Int(-1,-1,0),
        new Vector3Int(0,1,0),
        new Vector3Int(0,-1,0),
        new Vector3Int(1,1,0),
        new Vector3Int(1,0,0),
        new Vector3Int(1,-1,0)
    };

    void Start()
    {
        var prng = new System.Random();
        var worley_points = CreateWorleyPoints(prng, WorleyResolution);
        Texture3D worley_tex = new Texture3D(TextureSize, TextureSize, TextureSize, TextureFormat.RGBA32, false);
        worley_tex.wrapMode = TextureWrapMode.Repeat;

        Color[] colors = new Color[TextureSize * TextureSize * TextureSize];

        for (int z = 0; z < TextureSize; z++)
        {
            int zOffset = z * TextureSize * TextureSize;
            for (int y = 0; y < TextureSize; y++)
            {
                int yOffset = y * TextureSize;
                for (int x = 0; x < TextureSize; x++)
                {
                    var sample_pos = new Vector3(x, y, z) / TextureSize;
                    float sample_result = 1 - SampleWorley(worley_points, sample_pos, WorleyResolution);
                    colors[x + yOffset + zOffset] = new Color(sample_result, sample_result, sample_result);
                }
            }
        }

        worley_tex.SetPixels(colors);
        worley_tex.Apply();
        AssetDatabase.CreateAsset(worley_tex, "Assets/TestWorleyNoiseTexture.asset");
    }

    float SampleWorley(Vector3[] points, Vector3 samplePos, int numCellsEachAxis)
    {
        float min_dist_sqr = 1;
        Vector3Int cell_id = Vector3Int.FloorToInt(samplePos * numCellsEachAxis);

        for (int adjCellOffsetIndx = 0; adjCellOffsetIndx < 27; adjCellOffsetIndx++)
        {
            Vector3Int adj_cell_id = cell_id + offsets[adjCellOffsetIndx];

            if (GetMinComponent(adj_cell_id) == -1 || GetMaxComponent(adj_cell_id) == numCellsEachAxis) //We wrap around if adjacent cell is outside of our range
            {
                int w_cell_id_x = (adj_cell_id.x + numCellsEachAxis) % numCellsEachAxis;
                int w_cell_id_y = (adj_cell_id.y + numCellsEachAxis) % numCellsEachAxis;
                int w_cell_id_z = (adj_cell_id.z + numCellsEachAxis) % numCellsEachAxis;

                int wrapped_cell_index = w_cell_id_x + numCellsEachAxis * (w_cell_id_y + w_cell_id_z * numCellsEachAxis);
                Vector3 wrapped_point = points[wrapped_cell_index];

                for (int wrapOffsetIndex = 0; wrapOffsetIndex < 27; wrapOffsetIndex++) //Try all offsets to find true distance of the wrapped point
                {
                    Vector3 vec_to_sample = samplePos - (wrapped_point + offsets[wrapOffsetIndex]);
                    min_dist_sqr = Mathf.Min(min_dist_sqr, vec_to_sample.sqrMagnitude);
                }
            }
            else //No need to wrap
            {
                int adj_cell_index = adj_cell_id.x + numCellsEachAxis * (adj_cell_id.y + adj_cell_id.z * numCellsEachAxis);
                Vector3 adj_point = points[adj_cell_index];
                Vector3 vec_to_sample = samplePos - adj_point;
                min_dist_sqr = Mathf.Min(min_dist_sqr, vec_to_sample.sqrMagnitude);
            }
        }

        return Mathf.Sqrt(min_dist_sqr);
    }

    int GetMinComponent(Vector3Int vec)
    {
        return Math.Min(vec.z, Math.Min(vec.x, vec.y));
    }

    int GetMaxComponent(Vector3Int vec)
    {
        return Math.Max(vec.z, Math.Max(vec.x, vec.y));
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
